;;; scs-tramp.el --- TRAMP hosts, safety, and no-trace policy  -*- lexical-binding: t; -*-

;; Author: SCS
;; Keywords: tramp, remote-files, convenience
;; Package-Requires: ((emacs "29.1"))

;;; Commentary:
;;
;; Problem:
;;   Remote editing via TRAMP is convenient but easy to misconfigure: backup
;;   files and autosaves on shared servers clutter disks, lock files annoy
;;   other users, and dired on FreeBSD defaults to ls flags Emacs does not
;;   expect.
;;
;; Solution:
;;   Central host list (names from ~/.ssh/config), local-only backup and
;;   autosave directories under this config's var/ and temp, connection-local
;;   profiles for async TRAMP and GNU ls on FreeBSD hosts, and a small key
;;   map for find-file, dired, cleanup, and revert.
;;
;; Hosts: fido, dasfrp, ganafrp, ckg1 (SSH name; spoken "ck1"), ckg2.
;;
;; Keys (after `scs/tramp-setup'):
;;   C-c t f  find file on a known host
;;   C-c t d  dired on a known host
;;   C-c t c  clean up TRAMP connections
;;   C-c t r  revert buffer from remote
;;
;; How to check:
;;   C-c t f, pick a host, open a file; confirm backup copies land under
;;   var/tramp-backup/ locally, not on the remote.  On dasfrp/ganafrp, dired
;;   should list directories when gls is installed.

;;; Code:

(require 'tramp)
(require 'scs-cl)

(defconst scs/tramp-hosts
  '("fido" "dasfrp" "ganafrp" "ckg1" "ckg2")
  "SSH config Host names offered in TRAMP completing-read prompts.

Keep this list in sync with ~/.ssh/config Host stanzas you actually use.")

(defconst scs/tramp-freebsd-hosts
  '("dasfrp" "ganafrp")
  "Subset of `scs/tramp-hosts' running FreeBSD.

These machines get a connection-local dired profile that prefers GNU ls (gls)
when TRAMP connects, because BSD ls options differ from what Emacs expects.")

(defvar scs/tramp-prefix-map nil
  "Sparse keymap bound to C-c t after `scs/tramp-setup'.

Nil until setup builds the map once; avoids rebuilding keys on every init pass.")

(defun scs/tramp--backup-directory ()
  "Return the local directory where TRAMP stores backup copies of remote files.

Uses no-littering so the path stays under this config's var/ tree, not $HOME."
  (no-littering-expand-var-file-name "tramp-backup/"))

(defun scs/tramp--default-directory (host)
  "Return a TRAMP default directory string for SSH HOST (/ssh:HOST:/)."
  (file-name-as-directory (format "/ssh:%s:/" host)))

(defun scs/tramp--read-host (prompt)
  "Read one host from `scs/tramp-hosts' with completing-read PROMPT.

Third argument nil and fourth t require an exact match from the known list."
  (completing-read prompt scs/tramp-hosts nil t))

(defun scs/tramp--apply-connection-profiles ()
  "Register connection-local variables for known TRAMP hosts.

Profiles apply when TRAMP opens a remote buffer; they do not change local files."
  (connection-local-set-profile-variables
   'remote-direct-async-process
   '((tramp-direct-async-process . t)))

  ;; ssh and scp methods both benefit from direct async subprocesses on remote.
  (connection-local-set-profiles
   '(:application tramp :protocol "ssh")
   'remote-direct-async-process)

  (connection-local-set-profiles
   '(:application tramp :protocol "scp")
   'remote-direct-async-process)

  (connection-local-set-profile-variables
   'remote-bsd-process
   '((insert-directory-program . "gls")))

  (cl-loop for host in scs/tramp-freebsd-hosts
           do (connection-local-set-profiles
               `(:application tramp :machine ,host)
               'remote-bsd-process)))

(defun scs/tramp--configure-no-trace ()
  "Route TRAMP backups and autosaves locally and drop connections on exit.

Remote hosts should not accumulate Emacs backup~, #autosave#, or lock files;
see also init.el use-package tramp and no-littering-theme-backups."
  (let ((backup-dir (scs/tramp--backup-directory)))
    (make-directory backup-dir #o700)
    ;; Catch-all alist: every remote path backs up under backup-dir on this machine.
    (setq tramp-backup-directory-alist `((".*" . ,backup-dir))))

  (let ((autosave-dir (expand-file-name "tramp-autosave"
                                        temporary-file-directory)))
    (make-directory autosave-dir #o700)
    (setq tramp-auto-save-directory autosave-dir))

  ;; Stale TRAMP processes otherwise linger after Emacs exits.
  (add-hook 'kill-emacs-hook #'tramp-cleanup-all-connections))

;;;###autoload
(defun scs/tramp-setup ()
  "Apply no-trace policy, connection profiles, and C-c t key bindings.

Call once from init after TRAMP is loaded."
  (scs/tramp--configure-no-trace)
  (scs/tramp--apply-connection-profiles)

  (unless scs/tramp-prefix-map
    (setq scs/tramp-prefix-map (make-sparse-keymap))
    (define-key scs/tramp-prefix-map (kbd "f") #'scs/tramp-find-file)
    (define-key scs/tramp-prefix-map (kbd "d") #'scs/tramp-dired)
    ;; fix: 2026-07-10 -- bind scs/tramp-* (was my/tramp-*)
    (define-key scs/tramp-prefix-map (kbd "c") #'scs/tramp-cleanup)
    (define-key scs/tramp-prefix-map (kbd "r") #'scs/tramp-reopen))
  (define-key global-map (kbd "C-c t") scs/tramp-prefix-map))

;;;###autoload
(defun scs/tramp-find-file (path)
  "Open PATH on a known SSH host via TRAMP.
When called interactively, read the host from `scs/tramp-hosts' and
PATH from the minibuffer."
  (interactive
   (let* ((host (scs/tramp--read-host "TRAMP host: "))
          (default (scs/tramp--default-directory host)))
     (list (read-file-name (format "File on %s: " host) default))))
  (find-file path))

;;;###autoload
(defun scs/tramp-dired (directory)
  "Open dired on DIRECTORY at a known SSH host via TRAMP.
When called interactively, read the host from `scs/tramp-hosts' and
DIRECTORY from the minibuffer."
  (interactive
   (let* ((host (scs/tramp--read-host "TRAMP host: "))
          (default (scs/tramp--default-directory host)))
     (list (read-directory-name (format "Directory on %s: " host)
                                 default))))
  (dired directory))

;;;###autoload
;; fix: 2026-07-10 -- rename my/tramp-cleanup -> scs/tramp-cleanup
(defun scs/tramp-cleanup ()
  "Drop all TRAMP network connections and kill associated buffers.

Useful when a remote session hangs or you want a clean slate before reconnecting."
  (interactive)
  (tramp-cleanup-all-connections)
  (tramp-cleanup-all-buffers)
  (message "TRAMP: all connections and buffers cleaned up"))

;;;###autoload
;; fix: 2026-07-10 -- rename my/tramp-reopen -> scs/tramp-reopen
(defun scs/tramp-reopen ()
  "Revert the current buffer from its remote file (when default-directory is remote).

No-op locally: only runs revert-buffer when `file-remote-p' says we are on TRAMP."
  (interactive)
  (when (file-remote-p default-directory)
    (revert-buffer t t)
    (message "Refreshed from remote")))

;; add: 2026-07-10 -- compatibility aliases for older keybinding docs / muscle memory
(defalias 'my/tramp-cleanup #'scs/tramp-cleanup)
(defalias 'my/tramp-reopen #'scs/tramp-reopen)

(provide 'scs-tramp)
;;; scs-tramp.el ends here
