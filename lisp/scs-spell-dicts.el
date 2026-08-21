;;; scs-spell-dicts.el --- Install versioned personal spell word lists  -*- lexical-binding: t; -*-

;; Filename: scs-spell-dicts.el
;; Description: Sync spell/ word lists into Enchant and aspell home paths
;; Author: SCS
;; Copyright: Copyright (C) 2026, SCS, all rights reserved.
;; Created: 2026-08-21 Fri 12:48
;; Version: 0.1.0
;; Last-Updated: 2026-08-21 Fri 12:48
;; Update #: 0
;; Keywords: convenience, spelling, jinx
;; Package-Requires: ((emacs "29.1"))

;;; Commentary:
;;
;; Problem
;; -------
;; Personal spell words for jinx/Enchant/aspell used to live only under
;; the home directory.  That data is easy to lose and hard to review.
;;
;; Solution
;; --------
;; Canonical lists live in `user-emacs-directory'/spell/ as plain
;; Enchant-style .dic files (one word per line).  This library installs
;; them for the running host:
;;
;;   - Symlink ~/.config/enchant/<lang>.dic -> spell/<lang>.dic so that
;;     jinx "save to personal dictionary" edits the Git working tree.
;;   - Rewrite ~/.aspell.<lang>.pws from the same words (Aspell header),
;;     because Enchant's English backend is Aspell and still loads those
;;     files.
;;   - Rewrite ~/.aspell.en.prepl from spell/en.prepl when present.
;;
;; How to check
;; ------------
;;   M-x scs/spell-dicts-install
;;   ls -l ~/.config/enchant/en_GB-ise.dic   ; should point into spell/
;;   head ~/.aspell.en.pws                  ; personal_ws header + words

;;; Change Log:
;; Newest first.  File-local so readers need not dig through VCS.
;; add: 2026-08-21 -- install spell/ lists into Enchant and aspell paths

;;; Code:

(require 'cl-lib)
(require 'subr-x)

(defgroup scs-spell-dicts nil
  "Install versioned personal spell dictionaries from spell/."
  :group 'jinx
  :prefix "scs/spell-dicts-")

(defcustom scs/spell-dicts-directory
  (expand-file-name "spell" user-emacs-directory)
  "Directory of canonical personal word lists (Enchant .dic files)."
  :type 'directory
  :group 'scs-spell-dicts)

(defcustom scs/spell-dicts-languages
  '(("en_GB-ise" . "en")
    ("it_IT" . "it"))
  "Alist of (ENCHANT-TAG . ASPELL-LANG) for personal word lists.

ENCHANT-TAG names spell/ENCHANT-TAG.dic and the Enchant personal file.
ASPELL-LANG is the language code in ~/.aspell.ASPELL-LANG.pws (Aspell
uses the master language, e.g. en, not en_GB-ise)."
  :type '(alist :key-type string :value-type string)
  :group 'scs-spell-dicts)

(defun scs/spell-dicts--enchant-dir ()
  "Return ~/.config/enchant, creating it when missing."
  (let ((dir (expand-file-name "enchant" (expand-file-name ".config" "~"))))
    (make-directory dir t)
    dir))

(defun scs/spell-dicts--read-words (dic-file)
  "Return non-comment words from Enchant-style DIC-FILE.

Skips blank lines and lines whose first non-space character is `#'.
Preserves order after deleting exact duplicate lines."
  (unless (file-readable-p dic-file)
    (user-error "Missing spell dictionary: %s" dic-file))
  (with-temp-buffer
    (insert-file-contents dic-file)
    (let ((words nil))
      (goto-char (point-min))
      (while (not (eobp))
        (let* ((raw (buffer-substring-no-properties
                     (line-beginning-position) (line-end-position)))
               (line (string-trim raw)))
          (unless (or (string-empty-p line)
                      (string-prefix-p "#" line))
            (push line words)))
        (forward-line 1))
      (cl-delete-duplicates (nreverse words) :test #'string=))))

(defun scs/spell-dicts--ensure-symlink (target link)
  "Make LINK a symlink to TARGET.

If LINK already points at TARGET, do nothing.  If LINK exists as a
regular file, move it aside with a `.bak' suffix before linking.
TARGET must exist."
  (unless (file-exists-p target)
    (user-error "Spell dict target missing: %s" target))
  (let* ((target-true (file-truename target))
         (link-dir (file-name-directory link)))
    (make-directory link-dir t)
    (cond
     ((and (file-symlink-p link)
           (string= (file-truename link) target-true))
      nil)
     ((or (file-symlink-p link) (file-exists-p link))
      ;; Keep the previous home copy for recovery; do not delete silently.
      (rename-file link (concat link ".bak") t)
      (make-symbolic-link target link t))
     (t
      (make-symbolic-link target link t)))))

(defun scs/spell-dicts--write-aspell-pws (aspell-lang words)
  "Write ~/.aspell.ASPELL-LANG.pws from WORDS with a personal_ws header."
  (let ((path (expand-file-name (format ".aspell.%s.pws" aspell-lang) "~")))
    (with-temp-file path
      (insert (format "personal_ws-1.1 %s %d\n" aspell-lang (length words)))
      (dolist (w words)
        (insert w "\n")))
    path))

(defun scs/spell-dicts--write-aspell-prepl ()
  "Write ~/.aspell.en.prepl from spell/en.prepl when that file exists."
  (let ((src (expand-file-name "en.prepl" scs/spell-dicts-directory))
        (dst (expand-file-name ".aspell.en.prepl" "~")))
    (when (file-readable-p src)
      (let ((pairs nil))
        (with-temp-buffer
          (insert-file-contents src)
          (goto-char (point-min))
          (while (not (eobp))
            (let* ((raw (buffer-substring-no-properties
                         (line-beginning-position) (line-end-position)))
                   (line (string-trim raw)))
              (unless (or (string-empty-p line)
                          (string-prefix-p "#" line)
                          (string-prefix-p "personal_repl-" line))
                (push line pairs)))
            (forward-line 1)))
        (setq pairs (nreverse pairs))
        (with-temp-file dst
          (insert "personal_repl-1.1 en 0\n")
          (dolist (p pairs)
            (insert p "\n")))
        dst))))

;;;###autoload
(defun scs/spell-dicts-install ()
  "Install `scs/spell-dicts-directory' lists into Enchant and aspell paths.

See Commentary for the symlink vs aspell-pws split.  Return a list of
paths written or linked.  Interactive calls message a short summary."
  (interactive)
  (unless (file-directory-p scs/spell-dicts-directory)
    (user-error "No spell/ directory at %s" scs/spell-dicts-directory))
  (let ((enchant-dir (scs/spell-dicts--enchant-dir))
        (done nil))
    (dolist (pair scs/spell-dicts-languages)
      (let* ((tag (car pair))
             (aspell-lang (cdr pair))
             (dic (expand-file-name (concat tag ".dic")
                                    scs/spell-dicts-directory))
             (link (expand-file-name (concat tag ".dic") enchant-dir))
             (words (scs/spell-dicts--read-words dic)))
        (scs/spell-dicts--ensure-symlink dic link)
        (push link done)
        (push (scs/spell-dicts--write-aspell-pws aspell-lang words) done)))
    (when-let* ((prepl (scs/spell-dicts--write-aspell-prepl)))
      (push prepl done))
    (setq done (nreverse done))
    (when (called-interactively-p 'interactive)
      (message "Spell dicts installed (%d paths)" (length done)))
    done))

(provide 'scs-spell-dicts)
;;; scs-spell-dicts.el ends here
