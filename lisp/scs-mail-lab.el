;;; scs-mail-lab.el --- mu4e and notmuch on ~/mail  -*- lexical-binding: t; -*-

;; Filename: scs-mail-lab.el
;; Description: Shared Maildir lab -- mu4e, notmuch, msmtp, BBDB, org-msg
;; Author: SCS
;; Copyright: Copyright (C) 2026, SCS, all rights reserved.
;; Created: 2026-07-20 Sun 10:00
;; Version: 0.1.0
;; Last-Updated: 2026-07-24 Fri 06:49
;; Update #: 1
;; Keywords: mail, mu4e, notmuch, bbdb
;; Package-Requires: ((emacs "29.1"))
;; add: 2026-07-20 -- shared Maildir vault UI comparison
;; fix: 2026-07-20 -- matched split layouts, threading, multi-account send
;; fix: 2026-07-20 -- drop Gnus lab UI (keep mu4e + notmuch)
;; add: 2026-07-20 -- BBDB contacts (mu cfind) + org-msg compose
;; fix: 2026-07-24 -- teachable Commentary and docstrings for SCS team

;;; Commentary:
;;
;; Operator guide: docs/2026-07-20-emacs-mail-lab.org
;;
;; Problem
;; -------
;; Two mail UIs (mu4e and notmuch) should read the same ~/mail vault,
;; share compose/send settings, and feel similar (list on top, message
;; below).  Sync and indexing stay in the shell; Emacs only configures
;; paths, hooks, and keybindings.
;;
;; Solution
;; --------
;; One Maildir root (`scs/mail-lab-root`), three account dirs, msmtp
;; selected from the message From: header, BBDB for completion, org-msg
;; for HTML-friendly bodies.  Entry point: `C-c m' -> `scs/mail-lab-prefix-map'.
;;
;; Data (inspectable on disk)
;; --------------------------
;;   ~/mail/           shared Maildir (mbsync)
;;   mu / notmuch      indexes built in the terminal
;;   BBDB file         contacts (default via no-littering)
;;
;; Sync stays in the shell (Emacs does not run these automatically):
;;   mbsync -a
;;   mu index
;;   notmuch new
;;
;; UIs (list on top / message below where possible):
;;   mu4e              C-c m m
;;   notmuch.el        C-c m n
;;   search            C-c m s
;;   compose           C-c m c
;;   BBDB              C-c m b
;;   export contacts   C-c m e
;;
;; Send path: message-mode -> msmtp (-a From) via ~/.msmtprc (mailcow :465).
;; Compose embellishment: org-msg (HTML-friendly Org body).
;;
;; How to check
;; ------------
;; From Emacs: `M-x scs/mail-lab-install-keys RET', then `C-c m m' or `C-c m n'
;; after a successful `mbsync -a' and index update in ~/mail.

;;; Code:

(require 'subr-x)
(require 'cl-lib)

(defconst scs/mail-lab-root (expand-file-name "~/mail")
  "Shared Maildir vault root used by mbsync, mu, and notmuch.
All account paths and Fcc folders are under this directory.")

(defconst scs/mail-lab-account-dir "scs@scs.re"
  "Default account directory name under `scs/mail-lab-root'.
Used for compose defaults and mu4e folder paths when no context matches.")

(defconst scs/mail-lab-accounts
  '(("scs" . "scs@scs.re")
    ("priya" . "priyadarshan@goldenboat.in")
    ("vsm" . "mail@vsm.in"))
  "Alist of (SHORT-LABEL . ACCOUNT-DIR) under `scs/mail-lab-root'.
Labels are for humans; ACCOUNT-DIR is the Maildir folder name on disk.")

(defconst scs/mail-lab-smtp-by-address
  '(("scs@scs.re" . ("mail.dp.gy" "scs@scs.re" "SCS"))
    ("priyadarshan@goldenboat.in"
     . ("mail.ck.gy" "priyadarshan@goldenboat.in" "Priyadarshan"))
    ("mail@vsm.in" . ("mail.eb.gy" "mail@vsm.in" "VSM")))
  "Alist of (ADDRESS . (SMTP-HOST SMTP-USER FULL-NAME)).
SMTP is mailcow SMTPS on port 465; passwords come from ~/.authinfo
via msmtprc passwordeval, not from this file.")

(defun scs/mail-lab--account-path (&optional account-dir)
  "Return absolute Maildir path for ACCOUNT-DIR.
When ACCOUNT-DIR is nil, use `scs/mail-lab-account-dir'."
  (file-name-as-directory
   (expand-file-name (or account-dir scs/mail-lab-account-dir)
                     scs/mail-lab-root)))

(defun scs/mail-lab--brew-site-lisp (binary relative)
  "Return site-lisp directory for Homebrew BINARY with RELATIVE path.
Tries the real path of the installed binary first, then /opt/homebrew
and /usr/local opt layouts.  Returns nil when no directory exists."
  (or
   (when-let* ((exe (executable-find binary))
               (real (file-chase-links exe))
               (prefix (expand-file-name "../.." (file-name-directory real)))
               (dir (expand-file-name relative prefix)))
     (and (file-directory-p dir) dir))
   (let ((dir (expand-file-name relative
                                (format "/opt/homebrew/opt/%s" binary))))
     (and (file-directory-p dir) dir))
   (let ((dir (expand-file-name relative
                                (format "/usr/local/opt/%s" binary))))
     (and (file-directory-p dir) dir))))

(defun scs/mail-lab-ensure-load-path ()
  "Add Homebrew mu4e and notmuch Lisp directories to `load-path'."
  (dolist (dir (list
                (scs/mail-lab--brew-site-lisp
                 "mu" "share/emacs/site-lisp/mu/mu4e")
                (scs/mail-lab--brew-site-lisp
                 "notmuch" "share/emacs/site-lisp/notmuch")))
    (when dir
      (add-to-list 'load-path dir))))

(defun scs/mail-lab--account-folder (account-dir name)
  "Return mu4e folder path NAME under ACCOUNT-DIR."
  (format "/%s/%s" account-dir name))

;;;; Sending (shared by mu4e, notmuch, message-mode)
;;
;; Outgoing: Homebrew msmtp + ~/.msmtprc (SMTPS :465, passwordeval ->
;; authinfo-pass).  Account id matches the From address.  If GnuTLS push
;; errors return (msmtp exit 76), fall back to bin/mail-lab-sendmail.

(defun scs/mail-lab--msmtp-program ()
  "Return the msmtp executable, or nil if missing."
  (executable-find "msmtp"))

(defun scs/mail-lab--set-msmtp-account ()
  "Choose msmtp -a ACCOUNT from the message From: header.

Account names in ~/.msmtprc are the bare addresses (e.g. scs@scs.re)."
  (let ((addr (scs/mail-lab--address-from-header)))
    (unless (and addr (assoc addr scs/mail-lab-smtp-by-address))
      (user-error "No msmtp account mapped for From: %s" addr))
    (setq message-sendmail-extra-arguments (list "-a" addr))))

(defun scs/mail-lab-configure-send ()
  "Configure outgoing mail via msmtp and ~/.msmtprc (port 465).

Account is selected from the message From: header (-a ADDRESS).
Passwords come from ~/.authinfo through authinfo-pass (passwordeval).
Also ensures BBDB completion and org-msg compose are ready."
  (require 'message)
  (require 'sendmail)
  (let ((prog (scs/mail-lab--msmtp-program)))
    (unless prog
      (user-error "msmtp not found on PATH (brew install msmtp)"))
    (setq
     send-mail-function #'message-send-mail-with-sendmail
     message-send-mail-function #'message-send-mail-with-sendmail
     sendmail-program prog
     message-sendmail-envelope-from 'header
     mail-specify-envelope-from t
     mail-envelope-from 'header
     message-sendmail-extra-arguments nil
     message-sendmail-f-is-evil t
     message-kill-buffer-on-exit t
     mail-user-agent 'message-user-agent))
  (add-hook 'message-send-mail-hook #'scs/mail-lab--set-msmtp-account)
  ;; Older configs used smtpmail From: hook; remove so msmtp -a wins.
  (remove-hook 'message-send-hook #'scs/mail-lab--apply-smtp-from-header)
  (scs/mail-lab-configure-bbdb)
  (scs/mail-lab-configure-org-msg))

;;;; BBDB contacts (shared by mu4e and notmuch compose)

(defun scs/mail-lab--bbdb-file ()
  "Return the BBDB file path used by the mail lab.

Prefer the live `bbdb-file' (no-littering sets var/bbdb/bbdb.el).
Fall back to ~/.bbdb when BBDB is not loaded yet."
  (if (boundp 'bbdb-file)
      (expand-file-name bbdb-file)
    (expand-file-name "~/.bbdb")))

(defun scs/mail-lab-configure-bbdb ()
  "Load BBDB and hook it into message / mu4e / notmuch lightly.

Completion: M-TAB (`bbdb-complete-mail') in message-mode headers.
Does not enable auto-create-on-read; use `scs/mail-lab-export-contacts'."
  (require 'bbdb)
  (require 'bbdb-message)
  (require 'bbdb-migrate) ; mu cfind dumps file-version 6; migrate to 9
  ;; Ensure no-littering directory exists when that path is in use.
  (let ((dir (file-name-directory (scs/mail-lab--bbdb-file))))
    (when dir
      (make-directory dir t)))
  (setq bbdb-complete-mail t
        bbdb-complete-mail-allow-cycling t
        bbdb-message-all-addresses t)
  ;; message always; mu4e/notmuch when their Lisp is on load-path.
  (apply #'bbdb-initialize
         (append '(message)
                 (when (locate-library "mu4e") '(mu4e))
                 (when (locate-library "notmuch") '(notmuch)))))

(defun scs/mail-lab--mu-contacts-json ()
  "Return a list of contact alists from `mu cfind --format=json'.

Each element has keys email and name (name may be nil).  Using JSON
avoids broken Lisp from mu's --format=bbdb when a display-name contains
quotes."
  (with-temp-buffer
    (unless (zerop (call-process "mu" nil t nil "cfind" "--format=json" ""))
      (user-error "mu cfind --format=json failed; is the mu index ready?"))
    (goto-char (point-min))
    (let ((json-object-type 'alist)
          (json-array-type 'list)
          (json-key-type 'symbol)
          (json-false nil)
          (json-null nil))
      (require 'json)
      (json-read))))

;;;###autoload
(defun scs/mail-lab-export-contacts (&optional force)
  "Export vault contacts from mu into the BBDB file.

Harvests via `mu cfind --format=json' (safer than --format=bbdb when
names contain quotes), then creates BBDB records programmatically.
Writes `bbdb-file'.  Prompts before overwrite unless FORCE (prefix arg)."
  (interactive "P")
  (unless (executable-find "mu")
    (user-error "mu not found on PATH (brew install mu)"))
  (require 'bbdb-com)
  (scs/mail-lab-configure-bbdb)
  (let* ((file (scs/mail-lab--bbdb-file))
         (dir (file-name-directory file))
         (contacts (scs/mail-lab--mu-contacts-json))
         (count 0)
         (bbdb-allow-duplicates t)
         (bbdb-silent t))
    (when dir
      (make-directory dir t))
    (when (and (file-exists-p file)
               (not force)
               (not (yes-or-no-p
                     (format "Overwrite BBDB file %s? " file))))
      (user-error "Export cancelled"))
    (when (file-exists-p file)
      (copy-file file (concat file ".bak") t))
    ;; Fresh format-9 file; avoid mu's file-version 6 dump.
    (with-temp-file file
      (insert ";; -*-coding: utf-8-emacs;-*-\n"
              ";;; file-format: 9\n"))
    (set-file-modes file #o600)
    (when (and (boundp 'bbdb-buffer) (buffer-live-p bbdb-buffer))
      (with-current-buffer bbdb-buffer
        (set-buffer-modified-p nil)
        (kill-buffer (current-buffer))))
    (setq bbdb-buffer nil
          bbdb-records nil)
    (bbdb-buffer)
    (dolist (c contacts)
      (let* ((email (alist-get 'email c))
             (name (alist-get 'name c)))
        (when (and email (stringp email) (not (string-empty-p email)))
          (condition-case err
              (progn
                (bbdb-create-internal
                 :name (and name (stringp name) (not (string-empty-p name))
                            name)
                 :mail (list email))
                (setq count (1+ count)))
            (error
             (message "BBDB skip %s: %s" email (error-message-string err)))))))
    (bbdb-save nil t)
    (message "Exported %d contacts to %s" count file)))

;;;###autoload
(defun scs/mail-lab-bbdb ()
  "Open BBDB (after ensuring mail-lab BBDB config)."
  (interactive)
  (scs/mail-lab-configure-bbdb)
  (call-interactively #'bbdb))

;;;; org-msg (shared HTML-friendly compose)

(defun scs/mail-lab-configure-org-msg ()
  "Enable org-msg for message-mode / mu4e / notmuch compose.

Keeps msmtp as the send path; org-msg only changes how the body is
edited and exported to multipart alternatives."
  (require 'org-msg)
  (setq org-msg-options "html-postamble:nil toc:nil author:nil email:nil"
        org-msg-startup nil
        org-msg-greeting-fmt "\nHi%s,\n\n"
        org-msg-recipient-names nil
        org-msg-default-alternatives
        '((new . (text html))
          (reply-to-html . (text html))
          (reply-to-text . (text)))
        org-msg-signature
        (concat "\n#+begin_signature\n-- \n"
                "SCS\n"
                "#+end_signature"))
  (unless org-msg-mode
    (org-msg-mode 1)))

(defun scs/mail-lab--address-from-header ()
  "Return the bare email address from the current message From: header."
  (when-let* ((from (message-fetch-field "From"))
              (parsed (mail-extract-address-components from)))
    (downcase (or (cadr parsed) ""))))

(defun scs/mail-lab--apply-smtp-from-header ()
  "Obsolete smtpmail helper; kept so old hooks can be removed cleanly."
  nil)

(defun scs/mail-lab--read-from-address ()
  "Prompt for which lab address to send as."
  (completing-read
   "Send as: "
   (mapcar #'car scs/mail-lab-smtp-by-address)
   nil t nil nil scs/mail-lab-account-dir))

;;;###autoload
(defun scs/mail-lab-compose (&optional address)
  "Compose a message as ADDRESS (prompt when nil).

Works for mu4e/notmuch: shared message-mode + msmtp.
Does not contact SMTP until `C-c C-c' (send)."
  (interactive)
  (scs/mail-lab-configure-send)
  (let* ((addr (or address (scs/mail-lab--read-from-address)))
         (info (cdr (assoc addr scs/mail-lab-smtp-by-address)))
         (name (nth 2 info)))
    (unless info
      (user-error "Unknown address %s" addr))
    (setq user-mail-address addr
          user-full-name name)
    (compose-mail nil nil nil nil nil
                  (list (cons "From" (format "%s <%s>" name addr))))
    (message-add-header
     (format "Fcc: %s"
             (expand-file-name
              (format "%s/Sent" addr) scs/mail-lab-root)))))

;;;; Layout helpers

(defun scs/mail-lab-configure-layouts ()
  "Match list-on-top / message-below across mu4e and notmuch."
  (setq mu4e-split-view 'horizontal
        mu4e-headers-visible-lines 18
        mu4e-search-include-related t)
  (advice-add #'notmuch-show :around #'scs/mail-lab--notmuch-show-split))

(defun scs/mail-lab--notmuch-show-split (orig &rest args)
  "Open notmuch-show below the search/tree list (list top, body bottom).
When not in search or tree mode, delegate unchanged.  When the frame
has only one window, split below first so the advice stays predictable."
  (if (not (derived-mode-p 'notmuch-search-mode 'notmuch-tree-mode))
      (apply orig args)
    (when (one-window-p t)
      (select-window (split-window-below)))
    (apply orig args)))

;;;; mu4e

(defun scs/mail-lab--mu4e-context (label address host full-name)
  "Build a `mu4e-context' named LABEL for ADDRESS via HOST."
  (make-mu4e-context
   :name label
   :match-func
   (lambda (msg)
     (when msg
       (string-prefix-p (concat "/" address)
                        (mu4e-message-field msg :maildir))))
   :vars
   `((user-mail-address . ,address)
     (user-full-name . ,full-name)
     (smtpmail-smtp-server . ,host)
     (smtpmail-smtp-user . ,address)
     (smtpmail-smtp-service . 465)
     (smtpmail-stream-type . ssl)
     (mu4e-drafts-folder . ,(scs/mail-lab--account-folder address "Drafts"))
     (mu4e-sent-folder . ,(scs/mail-lab--account-folder address "Sent"))
     (mu4e-trash-folder . ,(scs/mail-lab--account-folder address "Trash"))
     (mu4e-refile-folder . ,(scs/mail-lab--account-folder address "Archive")))))

(defun scs/mail-lab-configure-mu4e ()
  "Apply mu4e settings: vault, contexts, split view, send."
  (scs/mail-lab-ensure-load-path)
  (scs/mail-lab-configure-send)
  (require 'mu4e-context)
  (setq
   user-mail-address "scs@scs.re"
   user-full-name "SCS"
   mu4e-mu-binary (or (executable-find "mu") "mu")
   mu4e-get-mail-command "mbsync -a"
   mu4e-change-filenames-when-moving t
   mu4e-update-interval nil
   mu4e-confirm-quit nil
   mu4e-split-view 'horizontal
   mu4e-headers-visible-lines 18
   mu4e-search-include-related t
   mu4e-compose-context-policy 'ask-if-none
   mu4e-context-policy 'pick-first
   ;; Contact completion talks to the mu server.  If `mu index' holds the
   ;; Xapian lock, Emacs looks "stalled" on compose.  Keep completion
   ;; light for the lab; raise later if you want richer To: completion.
   mu4e-compose-complete-addresses t
   mu4e-compose-complete-max 200
   mu4e-compose-complete-only-after "2024-01-01"
   mu4e-contexts
   (list
    (scs/mail-lab--mu4e-context
     "scs" "scs@scs.re" "mail.dp.gy" "SCS")
    (scs/mail-lab--mu4e-context
     "priya" "priyadarshan@goldenboat.in" "mail.ck.gy" "Priyadarshan")
    (scs/mail-lab--mu4e-context
     "vsm" "mail@vsm.in" "mail.eb.gy" "VSM"))
   mu4e-drafts-folder (scs/mail-lab--account-folder "scs@scs.re" "Drafts")
   mu4e-sent-folder (scs/mail-lab--account-folder "scs@scs.re" "Sent")
   mu4e-trash-folder (scs/mail-lab--account-folder "scs@scs.re" "Trash")
   mu4e-refile-folder (scs/mail-lab--account-folder "scs@scs.re" "Archive")
   mu4e-maildir-shortcuts
   `((:maildir ,(scs/mail-lab--account-folder "scs@scs.re" "INBOX") :key ?i)
     (:maildir ,(scs/mail-lab--account-folder
                 "priyadarshan@goldenboat.in" "INBOX")
               :key ?p)
     (:maildir ,(scs/mail-lab--account-folder "mail@vsm.in" "INBOX") :key ?v)
     (:maildir ,(scs/mail-lab--account-folder "scs@scs.re" "Sent") :key ?s)
     (:maildir ,(scs/mail-lab--account-folder "scs@scs.re" "Drafts") :key ?d)
     (:maildir ,(scs/mail-lab--account-folder "scs@scs.re" "Archive") :key ?a)
     (:maildir ,(scs/mail-lab--account-folder "scs@scs.re" "Trash") :key ?t))
   mu4e-bookmarks
   `((:name "Global INBOX (all accounts)"
            :query ,(mapconcat
                     #'identity
                     '("maildir:/scs@scs.re/INBOX"
                       "maildir:/priyadarshan@goldenboat.in/INBOX"
                       "maildir:/mail@vsm.in/INBOX")
                     " OR ")
            :key ?g
            :favorite t)
     (:name "All vault mail"
            :query "not flag:trashed"
            :key ?A)
     (:name "scs@scs.re INBOX"
            :query "maildir:/scs@scs.re/INBOX"
            :key ?i)
     (:name "priyadarshan INBOX"
            :query "maildir:/priyadarshan@goldenboat.in/INBOX"
            :key ?p)
     (:name "mail@vsm.in INBOX"
            :query "maildir:/mail@vsm.in/INBOX"
            :key ?v)
     (:name "Unread"
            :query "flag:unread AND NOT flag:trashed"
            :key ?u))))

;;;; notmuch

(defun scs/mail-lab-configure-notmuch ()
  "Apply notmuch identities, Fcc, and list/show split."
  (scs/mail-lab-ensure-load-path)
  (scs/mail-lab-configure-send)
  (setq
   user-mail-address "scs@scs.re"
   user-full-name "SCS"
   notmuch-identities
   '("SCS <scs@scs.re>"
     "Priyadarshan <priyadarshan@goldenboat.in>"
     "VSM <mail@vsm.in>")
   notmuch-fcc-dirs
   '(("scs@scs.re" . "scs@scs.re/Sent")
     ("priyadarshan@goldenboat.in" . "priyadarshan@goldenboat.in/Sent")
     ("mail@vsm.in" . "mail@vsm.in/Sent"))
   notmuch-search-oldest-first nil)
  (advice-add #'notmuch-show :around #'scs/mail-lab--notmuch-show-split))

(defun scs/mail-lab--notmuch-refresh ()
  "Run `notmuch new' so file paths match Maildir flag renames."
  (when (executable-find "notmuch")
    (call-process "notmuch" nil nil nil "new")))

;;;###autoload
(defun scs/mail-lab-mu4e ()
  "Open mu4e on the shared ~/mail vault."
  (interactive)
  (scs/mail-lab-ensure-load-path)
  (require 'mu4e)
  (scs/mail-lab-configure-mu4e)
  (mu4e))

;;;###autoload
(defun scs/mail-lab-notmuch ()
  "Open notmuch hello on the shared ~/mail vault."
  (interactive)
  (scs/mail-lab-ensure-load-path)
  (require 'notmuch)
  (scs/mail-lab-configure-notmuch)
  (scs/mail-lab--notmuch-refresh)
  (notmuch))

;;;###autoload
(defun scs/mail-lab-search (&optional query)
  "Reliable search: notmuch UI on the shared vault."
  (interactive)
  (scs/mail-lab-ensure-load-path)
  (require 'notmuch)
  (scs/mail-lab-configure-notmuch)
  (scs/mail-lab--notmuch-refresh)
  (let ((q (or query
               (read-string "notmuch search: " "* "))))
    (notmuch-search q)))

(defun scs/mail-lab--make-prefix-map ()
  "Build the mail-lab prefix keymap."
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "m") #'scs/mail-lab-mu4e)
    (define-key map (kbd "n") #'scs/mail-lab-notmuch)
    (define-key map (kbd "s") #'scs/mail-lab-search)
    (define-key map (kbd "c") #'scs/mail-lab-compose)
    (define-key map (kbd "b") #'scs/mail-lab-bbdb)
    (define-key map (kbd "e") #'scs/mail-lab-export-contacts)
    map))

(defvar scs/mail-lab-prefix-map
  (scs/mail-lab--make-prefix-map)
  "Prefix map bound to `C-c m' by `scs/mail-lab-install-keys'.
Keys: m mu4e, n notmuch, s search, c compose, b BBDB, e export contacts.")

;;;###autoload
(defun scs/mail-lab-install-keys ()
  "Bind C-c m to `scs/mail-lab-prefix-map'."
  (unless (keymapp scs/mail-lab-prefix-map)
    (setq scs/mail-lab-prefix-map (scs/mail-lab--make-prefix-map)))
  ;; Refresh bindings when the map was built before b/e existed.
  (define-key scs/mail-lab-prefix-map (kbd "b") #'scs/mail-lab-bbdb)
  (define-key scs/mail-lab-prefix-map (kbd "e") #'scs/mail-lab-export-contacts)
  (define-key global-map (kbd "C-c m") scs/mail-lab-prefix-map)
  (message "mail-lab keys: C-c m m/n/s/c/b/e"))

(provide 'scs-mail-lab)

;;; scs-mail-lab.el ends here
