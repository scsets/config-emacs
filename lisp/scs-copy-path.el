;;; scs-copy-path.el --- Copy buffer/Dired/TRAMP paths to kill ring  -*- lexical-binding: t; -*-

;; Filename: scs-copy-path.el
;; Description: DWIM path copy for file buffers, Dired, TRAMP, and formats
;; Author: SCS
;; Copyright: Copyright (C) 2026, SCS, all rights reserved.
;; Created: 2026-07-31 Fri 10:38
;; Version: 0.1.0
;; Last-Updated: 2026-07-31 Fri 14:50
;; Update #: 1
;; Keywords: convenience, files, dired, tramp
;; Package-Requires: ((emacs "29.1"))

;;; Commentary:
;;
;; Problem
;; -------
;; Copying "the current path" is not one case.  File-visiting buffers,
;; Dired (current line or marks), TRAMP remote names, symlinks, and
;; project-relative forms all need different helpers.  A bare
;; `(kill-new (buffer-file-name))' is right only for the simplest case.
;;
;; Solution
;; --------
;; `scs/copy-path' resolves source path(s) from context, transforms them
;; into a chosen format, and places the result on the kill ring (and the
;; system clipboard when `select-enable-clipboard' is non-nil, which is
;; the GUI default).
;;
;; Context resolution (first match wins)
;; -------------------------------------
;; 1. Dired: marked files if any; else file on the current line; else the
;;    current Dired directory (`dired-current-directory').
;; 2. File-visiting buffer: `buffer-file-name'.
;; 3. Fallback: `default-directory' (shell, eshell, help, magit, etc.).
;;
;; Formats (see `scs/copy-path-formats')
;; -------------------------------------
;; absolute, abbreviated (~), directory, basename, relative,
;; project-relative, truename (resolve symlinks), local-name (strip
;; TRAMP method/user/host), remote-id (TRAMP prefix only), shell-quoted,
;; path:line, path:line:column.
;;
;; Keys (after init wires the autoload)
;; ------------------------------------
;;   H-c p      `scs/copy-path' with `scs/copy-path-default-format'
;;   C-u H-c p  prompt for format
;;
;; Documented helpers used
;; -----------------------
;; `buffer-file-name', `dired-get-marked-files', `dired-get-filename',
;; `dired-current-directory', `expand-file-name', `abbreviate-file-name',
;; `file-relative-name', `file-truename', `file-local-name',
;; `file-remote-p', `file-directory-p', `file-name-directory',
;; `file-name-nondirectory',
;; `file-name-as-directory', `directory-name-p', `project-current',
;; `project-root', `shell-quote-argument', `kill-new',
;; `line-number-at-pos', `current-column'.
;;
;; How to check
;; ------------
;;   M-x scs/copy-path RET          ; absolute of visited file
;;   C-u M-x scs/copy-path RET      ; pick format
;;   In Dired: mark two files, H-c p  ; newline-separated list
;;   On TRAMP: C-u H-c p, local-name  ; remote-local path only
;;   Symlink file: C-u H-c p, truename

;;; Change Log:
;; Newest first.  File-local so readers need not dig through VCS.
;; fix: 2026-07-31 -- preserve Dired directories; use absolute file positions
;; add: 2026-07-31 -- scs/copy-path DWIM path copy for buffer/Dired/TRAMP

;;; Code:

(require 'subr-x)
(require 'project)

;; Dired is loaded on demand inside `scs/copy-path--dired-paths'.  These
;; declarations keep the byte compiler quiet without forcing dired at load.
(declare-function dired-get-marked-files "dired"
                  (&optional localp arg filter distinguish-one-marked error))
(declare-function dired-get-filename "dired" (&optional localp no-error-if-not-filep))
(declare-function dired-current-directory "dired" (&optional localp))

(defgroup scs-copy-path nil
  "Copy file and directory paths from the current Emacs context.

Interactive entry point: `scs/copy-path'.  Related symbols use the
`scs/copy-path-' prefix."
  :group 'files
  :prefix "scs/copy-path-")

(defcustom scs/copy-path-default-format 'absolute
  "Default path format for `scs/copy-path' without a prefix argument.

Must be a key from `scs/copy-path-formats'.  Use \\[universal-argument]
before `scs/copy-path' to choose a different format interactively."
  :type '(choice
          (const absolute)
          (const abbreviated)
          (const directory)
          (const basename)
          (const relative)
          (const project)
          (const truename)
          (const local-name)
          (const remote-id)
          (const shell)
          (const line)
          (const line-column))
  :group 'scs-copy-path)

(defcustom scs/copy-path-separator "\n"
  "String used to join multiple paths (e.g. several Dired marks).

Newline is convenient for pasting into shells, tickets, and chat."
  :type 'string
  :group 'scs-copy-path)

(defconst scs/copy-path-formats
  '((absolute    . "Absolute path")
    (abbreviated . "Abbreviated path (~ and directory-abbrev-alist)")
    (directory   . "Containing directory (or path if already a directory)")
    (basename    . "Basename only")
    (relative    . "Relative to default-directory")
    (project     . "Relative to project root")
    (truename    . "Truename (resolve symbolic links)")
    (local-name  . "Local name (strip TRAMP method/user/host)")
    (remote-id   . "Remote connection id only (TRAMP prefix)")
    (shell       . "Shell-quoted absolute path")
    (line        . "Absolute path:line")
    (line-column . "Absolute path:line:column"))
  "Alist of (FORMAT . DESCRIPTION) offered by `scs/copy-path'.

FORMAT is a symbol accepted by `scs/copy-path--transform'.
DESCRIPTION is shown in the completing-read prompt.")


;;; Source resolution

(defun scs/copy-path--dired-paths ()
  "Return a list of path strings from the current Dired buffer.

Prefer marked files.  With no marks, use the file on the current line
(`dired-get-filename' with NO-ERROR-IF-NOT-FILEP).  On an empty or
non-file line (including after failed lookup), fall back to
`dired-current-directory'.

Requires `dired' features; caller must ensure `dired-mode'."
  (require 'dired)
  (let ((marked (dired-get-marked-files nil 'marked)))
    (cond
     (marked marked)
     ((when-let* ((file (dired-get-filename nil t)))
        (list file)))
     (t (list (dired-current-directory))))))

(defun scs/copy-path--sources ()
  "Return a non-empty list of raw path strings for the current context.

Order of preference:
1. Dired marks / current line / current Dired directory
2. `buffer-file-name' of the selected window's buffer
3. `default-directory' (always available)

Never returns nil; the fallback is expanded `default-directory'."
  (cond
   ((derived-mode-p 'dired-mode)
    (scs/copy-path--dired-paths))
   (buffer-file-name
    (list buffer-file-name))
   (t
    (list (expand-file-name default-directory)))))


;;; Format transforms

(defun scs/copy-path--project-root ()
  "Return the absolute project root for `default-directory', or nil.

Uses `project-current' with MAYBE-PROMPT nil so this never prompts.
Requires the built-in `project' library (Emacs 29+)."
  (when-let* ((proj (project-current nil)))
    (project-root proj)))

(defun scs/copy-path--directory-of (path)
  "Return the directory represented by or containing PATH.

If PATH names an existing directory, return it with a trailing slash via
`file-name-as-directory'.  Otherwise return its parent from
`file-name-directory', or PATH itself when there is no parent component.

This is the only format that asks the filesystem what PATH represents.
For a TRAMP path, `file-directory-p' may therefore contact the remote
host; the other formats remain string-only unless their own documented
operation requires filesystem access."
  (let ((abs (expand-file-name path)))
    (file-name-as-directory
     (if (or (directory-name-p abs)
             (file-directory-p abs))
         abs
       (or (file-name-directory abs) abs)))))

(defun scs/copy-path--file-position ()
  "Return point's absolute one-based (LINE . COLUMN) in the file.

Ignore narrowing so copied locations still identify the same place when
opened in an unrestricted buffer."
  (save-restriction
    (widen)
    (cons (line-number-at-pos nil t)
          (1+ (current-column)))))

(defun scs/copy-path--require-file-buffer (format)
  "Signal `user-error' when FORMAT needs a file-visiting buffer.

`line' and `line-column' encode the point in the selected buffer; they
are meaningless for pure Dired selections or directory fallbacks."
  (unless buffer-file-name
    (user-error "Format `%s' needs a file-visiting buffer" format)))

(defun scs/copy-path--transform (path format)
  "Return PATH rewritten according to FORMAT.

PATH is a raw filesystem or TRAMP name.  FORMAT is a key from
`scs/copy-path-formats'.  Signals `user-error' for formats that cannot
apply (e.g. project with no root, remote-id on a local path)."
  (let ((abs (expand-file-name path)))
    (pcase format
      ('absolute abs)
      ('abbreviated (abbreviate-file-name abs))
      ('directory (scs/copy-path--directory-of abs))
      ('basename (file-name-nondirectory (directory-file-name abs)))
      ('relative (file-relative-name abs default-directory))
      ('project
       (if-let* ((root (scs/copy-path--project-root)))
           (file-relative-name abs root)
         (user-error "Not inside a project (no `project-current' root)")))
      ('truename (file-truename abs))
      ('local-name (file-local-name abs))
      ('remote-id
       (or (file-remote-p abs)
           (user-error "Not a remote (TRAMP) path: %s" abs)))
      ('shell (shell-quote-argument abs))
      ('line
       (scs/copy-path--require-file-buffer format)
       (format "%s:%d" abs (car (scs/copy-path--file-position))))
      ('line-column
       (scs/copy-path--require-file-buffer format)
       (pcase-let* ((`(,line . ,column) (scs/copy-path--file-position)))
         (format "%s:%d:%d" abs line column)))
      (_ (error "Unknown scs/copy-path format: %S" format)))))

(defun scs/copy-path--read-format ()
  "Read a format key from `scs/copy-path-formats' via completing-read.

Returns a symbol.  Requires an exact match from the known keys."
  (let* ((collection
          (mapcar (lambda (cell)
                    (cons (format "%s — %s" (car cell) (cdr cell))
                          (car cell)))
                  scs/copy-path-formats))
         (choice
          (completing-read "Copy path as: " collection nil t nil nil
                           (format "%s — %s"
                                   scs/copy-path-default-format
                                   (alist-get scs/copy-path-default-format
                                              scs/copy-path-formats)))))
    (or (alist-get choice collection nil nil #'string=)
        (user-error "Unknown path format choice: %s" choice))))

(defun scs/copy-path--kill (string)
  "Put STRING on the kill ring and echo a short confirmation.

Uses `kill-new', which also hands STRING to
`interprogram-cut-function' (system clipboard) when that is configured.
Returns STRING."
  (kill-new string)
  (message "Copied: %s"
           (if (string-match-p "\n" string)
               (format "%d paths (%d chars)"
                       (length (split-string string "\n" t))
                       (length string))
             string))
  string)


;;; Commands

;;;###autoload
(defun scs/copy-path (&optional format)
  "Copy path(s) for the current context to the kill ring and clipboard.

Without a prefix argument, FORMAT defaults to
`scs/copy-path-default-format' (normally absolute).

With \\[universal-argument], prompt for FORMAT among
`scs/copy-path-formats'.

Sources:
- Dired: marked files, else file at point, else current Dired directory
- File buffer: `buffer-file-name'
- Otherwise: `default-directory'

Multiple paths are joined with `scs/copy-path-separator' (default newline).

FORMAT may also be passed from Lisp as a symbol key from
`scs/copy-path-formats'."
  (interactive
   (list (if current-prefix-arg
             (scs/copy-path--read-format)
           scs/copy-path-default-format)))
  (let* ((fmt (or format scs/copy-path-default-format))
         (sources (scs/copy-path--sources))
         (rendered (mapcar (lambda (p) (scs/copy-path--transform p fmt))
                           sources))
         (payload (string-join rendered scs/copy-path-separator)))
    (scs/copy-path--kill payload)))

;;;###autoload
(defun scs/copy-path-absolute ()
  "Copy absolute path(s); same as `scs/copy-path' with format absolute."
  (interactive)
  (scs/copy-path 'absolute))

;;;###autoload
(defun scs/copy-path-relative ()
  "Copy path(s) relative to `default-directory'."
  (interactive)
  (scs/copy-path 'relative))

;;;###autoload
(defun scs/copy-path-project ()
  "Copy path(s) relative to the current project root."
  (interactive)
  (scs/copy-path 'project))

;;;###autoload
(defun scs/copy-path-truename ()
  "Copy truename path(s), resolving symbolic links via `file-truename'."
  (interactive)
  (scs/copy-path 'truename))

;;;###autoload
(defun scs/copy-path-local-name ()
  "Copy local-name path(s); strips TRAMP method/user/host."
  (interactive)
  (scs/copy-path 'local-name))

(provide 'scs-copy-path)

;;; scs-copy-path.el ends here
