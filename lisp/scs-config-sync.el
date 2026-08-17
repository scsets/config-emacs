;;; scs-config-sync.el --- Pull this Emacs git repo and prune leftover el-get  -*- lexical-binding: t; -*-

;; Filename: scs-config-sync.el
;; Description: Git pull, el-get leftover removal, optional Emacs restart
;; Author: SCS
;; Copyright: Copyright (C) 2026, SCS, all rights reserved.
;; Created: 2026-08-17 Mon 12:45
;; Version: 0.1.1
;; Last-Updated: 2026-08-17 Mon 13:47
;; Update #: 2
;; Keywords: convenience, el-get, tools
;; Package-Requires: ((emacs "29.1"))

;;; Commentary:
;;
;; Problem:
;;   After git pull, init.el may have dropped packages (Helm, trial UIs)
;;   while el-get still has checkouts, .status.el rows, autoloads, and
;;   native-comp .eln files.  Reload (C-c r) cannot unload that disk
;;   state.  Leftovers also survive `scs/el-get-prune-status-orphans'
;;   because .status.el still stores the old recipe.
;;
;; Solution:
;;   Wanted packages are `scs/el-get-local-sources' plus
;;   `scs/el-get-extra-keep-packages' (use-package :el-get with stock
;;   recipes).  `el-get-cleanup' keeps those and their dependencies,
;;   then leftover checkout dirs and matching .eln files go away.
;;   `scs/sync-emacs-config' pulls this git repo first; a prefix
;;   argument restarts Emacs so early-init and in-memory features match.
;;
;; Verify:
;;   M-x scs/el-get-cleanup-unwanted  -- prune only (no git).
;;   M-x scs/sync-emacs-config        -- pull then prune.
;;   C-u M-x scs/sync-emacs-config    -- pull, prune, restart.
;;   Batch: emacs -batch -L lisp -l ert -l lisp/scs-config-sync.el \
;;     -l test/scs-config-sync-test.el -f ert-run-tests-batch-and-exit

;;; Change Log:
;; Newest first.  File-local so readers need not dig through VCS.
;; add: 2026-08-17 -- git -C ROOT so pull does not use the output buffer cwd
;; add: 2026-08-17 -- git pull, el-get leftover cleanup, optional restart

;;; Code:

(require 'cl-lib)

(defvar scs/el-get-local-sources nil
  "Recipe plists owned by init.el.  Defined for real in init.el.")

(defvar scs/el-get-extra-keep-packages nil
  "el-get names kept besides `scs/el-get-local-sources'.  Set in init.el.")

(defconst scs/el-get-checkout-skip-names
  '("." ".." "el-get")
  "Directory names under `el-get-dir' that cleanup must never delete.

`el-get' is the package manager checkout.  Dot files (.status.el,
.loaddefs.el) are skipped separately because they are not directories.")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Wanted set and leftover detection (pure enough to ERT)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun scs/el-get-source-symbol (source)
  "Return the package symbol for SOURCE (plist, symbol, or string)."
  (cond
   ((symbolp source) source)
   ((stringp source) (intern source))
   ((and (consp source) (keywordp (car source)))
    (let ((name (plist-get source :name)))
      (cond ((symbolp name) name)
            ((stringp name) (intern name))
            (t nil))))
   (t nil)))

(defun scs/el-get-wanted-package-symbols ()
  "Return symbols this profile still wants el-get to keep.

Local recipes plus `scs/el-get-extra-keep-packages'.  `el-get' itself
is always kept.  Dependencies are added later by `el-get-cleanup'."
  (let ((names (list 'el-get)))
    (dolist (src scs/el-get-local-sources)
      (let ((sym (scs/el-get-source-symbol src)))
        (when sym (push sym names))))
    (dolist (extra scs/el-get-extra-keep-packages)
      (let ((sym (scs/el-get-source-symbol extra)))
        (when sym (push sym names))))
    (cl-delete-duplicates names)))

(defun scs/el-get-orphan-checkout-name-p (name wanted-names)
  "Return non-nil when checkout directory NAME is leftover.

WANTED-NAMES is a list of strings (package directory names).  Dot
entries, `el-get', and names in WANTED-NAMES are kept."
  (and (stringp name)
       (not (member name scs/el-get-checkout-skip-names))
       (not (string-prefix-p "." name))
       (not (member name wanted-names))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Disk cleanup
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun scs/native-comp-cache-directories ()
  "Return existing native-comp cache directories for this Emacs."
  (let ((dirs '()))
    (when (boundp 'native-comp-eln-load-path)
      (dolist (d native-comp-eln-load-path)
        (when (stringp d)
          (let ((abs (expand-file-name d)))
            (when (file-directory-p abs)
              (push abs dirs))))))
    (dolist (d (list (expand-file-name "eln-cache/" user-emacs-directory)))
      (when (file-directory-p d)
        (push d dirs)))
    (cl-delete-duplicates dirs :test #'file-equal-p)))

(defun scs/native-comp-purge-package (package)
  "Delete native-comp .eln files whose basename starts with PACKAGE."
  (let* ((prefix (concat (format "%s" package) "-"))
         (re (concat "\\`" (regexp-quote prefix) ".*\\.eln\\'")))
    (dolist (root (scs/native-comp-cache-directories))
      (dolist (file (directory-files-recursively root "\\.eln\\'"))
        (when (string-match-p re (file-name-nondirectory file))
          (ignore-errors (delete-file file)))))))

(defun scs/el-get-remove-orphan-checkouts (wanted-symbols)
  "Delete `el-get-dir' subdirs not in WANTED-SYMBOLS (and not el-get).

Catches ghost checkouts that are gone from `.status.el' but still on
disk.  Never deletes `el-get' or dot files."
  (require 'el-get)
  (let ((wanted-names
         (mapcar (lambda (s) (format "%s" s)) wanted-symbols))
        (removed '()))
    (dolist (name (directory-files el-get-dir))
      (when (scs/el-get-orphan-checkout-name-p name wanted-names)
        (let ((path (expand-file-name name el-get-dir)))
          (when (file-directory-p path)
            (message "el-get: removing leftover checkout %s" name)
            (ignore-errors (delete-directory path t))
            (scs/native-comp-purge-package name)
            (push name removed)))))
    (nreverse removed)))

;;;###autoload
(defun scs/el-get-cleanup-unwanted (&optional interactive)
  "Remove el-get packages this profile no longer declares.

Keeps `scs/el-get-local-sources', `scs/el-get-extra-keep-packages',
their dependencies, and el-get itself.  Then deletes leftover
checkout directories and matching native-comp .eln files.

When INTERACTIVE is non-nil, confirm before removing anything.
Called from init without a prompt so leftovers go away on restart.

Return the list of package symbols `el-get-cleanup' removed, or nil."
  (interactive "p")
  (require 'el-get)
  (cl-labels
      ((has-recipe-p (package)
         (condition-case nil
             (progn (el-get-package-def package) t)
           (error nil))))
    (let* ((wanted
            (cl-remove-if-not #'has-recipe-p
                              (scs/el-get-wanted-package-symbols)))
         ;; Same keep set as `el-get-cleanup': declared packages plus
         ;; every dependency, plus el-get.  Preview this so we do not
         ;; offer to delete htmlize when org-msg still needs it.
         (keep (el-get-dependencies
                (mapcar #'el-get-as-symbol wanted)))
         (installed
          (mapcar #'el-get-as-symbol
                  (el-get-list-package-names-with-status
                   "installed" "required")))
         (to-remove (cl-set-difference installed keep))
         (removed-status nil))
    (when to-remove
      (when interactive
        (unless (y-or-n-p
                 (format "Remove leftover el-get packages %s? "
                         (mapconcat (lambda (s) (format "%s" s))
                                    to-remove ", ")))
          (user-error "Cleanup cancelled")))
      (message "el-get: removing leftover packages %s"
               (mapconcat (lambda (s) (format "%s" s)) to-remove ", "))
      ;; el-get-cleanup keeps WANTED plus dependencies plus el-get,
      ;; and calls el-get-remove (checkout, status, autoloads).
      (el-get-cleanup wanted)
      (setq removed-status to-remove)
      (dolist (pkg to-remove)
        (scs/native-comp-purge-package pkg)))
    (when (fboundp 'scs/el-get-prune-status-orphans)
      (scs/el-get-prune-status-orphans))
    (let ((ghosts (scs/el-get-remove-orphan-checkouts wanted)))
      (when ghosts
        (message "el-get: removed leftover checkouts: %s"
                 (mapconcat #'identity ghosts ", "))))
    (if removed-status
        (progn
          (message "el-get: pruned %d leftover package(s)"
                   (length removed-status))
          removed-status)
      (message "el-get: no leftover packages in status")
      nil))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Git pull
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun scs/emacs-config-git (root &rest args)
  "Run git -C ROOT ARGS and insert output in the current buffer.

Return the process exit status.  Always pass `-C' so the working
directory is ROOT.  `call-process' otherwise uses the current
buffer's `default-directory', which is buffer-local -- the
`*scs config git*' output buffer is not the config tree."
  (apply #'call-process "git" nil t nil "-C"
         (directory-file-name (expand-file-name root))
         args))

(defun scs/emacs-config-git-root ()
  "Return `user-emacs-directory' if it is a git working tree, else nil."
  (let* ((root (file-name-as-directory
                (expand-file-name user-emacs-directory)))
         (git (expand-file-name ".git" root)))
    (when (or (file-directory-p git) (file-exists-p git))
      root)))

(defun scs/emacs-config-git-dirty-p (root)
  "Return non-nil when git ROOT has uncommitted changes."
  (with-temp-buffer
    (let ((status (scs/emacs-config-git root "status" "--porcelain")))
      (unless (zerop status)
        (user-error "git status failed in %s" root))
      (> (buffer-size) 0))))

(defun scs/emacs-config-git-pull ()
  "Fast-forward pull this Emacs config repo.  Signal `user-error' on failure.

Does not stash or commit.  If the tree is dirty, ask before pulling;
local edits stay in the worktree."
  (unless (executable-find "git")
    (user-error "git is not on PATH"))
  (let ((root (scs/emacs-config-git-root)))
    (unless root
      (user-error "Not a git repo: %s" user-emacs-directory))
    (when (and (scs/emacs-config-git-dirty-p root)
               (not (y-or-n-p
                     "Config worktree has local changes.  git pull --ff-only anyway? ")))
      (user-error "Pull cancelled (dirty worktree)"))
    (let ((buf (get-buffer-create "*scs config git*"))
          (root-arg (directory-file-name (expand-file-name root))))
      (with-current-buffer buf
        (let ((inhibit-read-only t))
          (erase-buffer)
          (insert (format "git -C %s pull --ff-only\n\n" root-arg)))
        (let ((status (scs/emacs-config-git root "pull" "--ff-only")))
          (unless (zerop status)
            (display-buffer buf)
            (user-error "git pull failed (exit %s); see %s"
                        status (buffer-name buf))))
        (goto-char (point-min)))
      (message "git pull --ff-only OK in %s" (abbreviate-file-name root))
      root)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Restart
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun scs/restart-emacs ()
  "Exit this Emacs after spawning a waiter that starts a new process.

The waiter polls until this PID is gone, then runs the same binary.
A daemon is restarted with --daemon; a GUI session is started in the
background.  Unsaved buffers are offered via `save-some-buffers'."
  (interactive)
  (save-some-buffers)
  (let* ((bin (expand-file-name invocation-name invocation-directory))
         (pid (emacs-pid))
         (script (make-temp-file "scs-restart-emacs-" nil ".sh")))
    (unless (file-executable-p bin)
      (user-error "Cannot restart: Emacs binary not executable: %s" bin))
    (with-temp-file script
      (insert "#!/bin/sh\n"
              "pid=" (number-to-string pid) "\n"
              "bin=" (shell-quote-argument bin) "\n"
              "while kill -0 \"$pid\" 2>/dev/null; do\n"
              "  sleep 0.2\n"
              "done\n"
              (if (daemonp)
                  "\"$bin\" --daemon\n"
                "\"$bin\" &\n")
              "rm -f \"$0\"\n"))
    (set-file-modes script #o700)
    (call-process "/bin/sh" nil 0 nil script)
    (kill-emacs)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Operator command
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;###autoload
(defun scs/sync-emacs-config (&optional restart)
  "git pull this Emacs repo, prune leftover el-get packages, maybe restart.

With prefix argument RESTART (C-u), restart Emacs after a successful
pull and prune so early-init and in-memory features match the tree.

Without prefix, reload init.el after pull so the wanted-package list
is current, then prune.  A restart is still the honest next step after
dropping a minibuffer UI.

Does not commit, stash, or push."
  (interactive "P")
  (scs/emacs-config-git-pull)
  ;; Disk init.el may have a new recipe list.  Loading it refreshes
  ;; `scs/el-get-local-sources' and runs `scs/el-get-safe-sync', which
  ;; prunes leftovers without a second prompt.
  (load user-init-file nil t)
  (if restart
      (progn
        (message "Restarting Emacs...")
        (scs/restart-emacs))
    (message
     "Synced.  Restart Emacs if packages or early-init changed (C-u M-x scs/sync-emacs-config)")))

(provide 'scs-config-sync)
;;; scs-config-sync.el ends here
