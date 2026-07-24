;;; scs-convert.el --- Region/buffer convert via Pandoc  -*- lexical-binding: t; -*-

;; Filename: scs-convert.el
;; Description: Convert region or buffer between markup formats via Pandoc
;; Author: SCS
;; Copyright: Copyright (C) 2026, SCS, all rights reserved.
;; Created: 2026-07-22 Wed 14:09
;; Version: 0.1.0
;; Last-Updated: 2026-07-24 Fri 06:49
;; Update #: 1
;; Keywords: convenience, pandoc, org, markdown
;; Package-Requires: ((emacs "29.1"))
;; add: 2026-07-22 -- scs/convert markdown->org with tidy Lua filter

;;; Commentary:
;;
;; Problem:
;;   Pandoc converts markup well, but Emacs has no built-in "turn this snippet
;;   into Org" command.  Guessing format from major-mode fails when Markdown
;;   lives inside an Org buffer or the visited file extension does not match
;;   what you selected.
;;
;; Solution:
;;   `scs/convert' runs Pandoc on the region or whole buffer.  From/to formats
;;   come only from `scs/convert-formats', never from major-mode.  v1 ships
;;   markdown -> org with tidy-org.lua so Pandoc does not emit CUSTOM_ID
;;   property drawers.  Add more alist entries for new pairs without new
;;   commands.  Design notes: docs/2026-07-22-scs-convert-design.org
;;
;; How to check:
;;   Mark a Markdown region in any buffer, M-x scs/convert RET; the region
;;   should become Org in place.  Whole-buffer conversion switches to org-mode
;;   and can offer to rename .md to .org.  Requires `pandoc' on PATH (or set
;;   `scs/convert-pandoc-program').

;;; Code:

(require 'cl-lib)
(require 'subr-x)

(defgroup scs-convert nil
  "Convert buffer or region text with Pandoc."
  :group 'convenience
  :prefix "scs/convert-")

(defcustom scs/convert-pandoc-program "pandoc"
  "Pandoc executable name or absolute path."
  :type 'string
  :group 'scs-convert)

(defcustom scs/convert-formats
  '(((markdown . org)
     :from "markdown"
     :to "org"
     :extra-args ("--wrap=none")
     :lua-filters ("tidy-org.lua")))
  "Convert pairs for `scs/convert'.

Each entry is ((FROM . TO) :from FROM-STR :to TO-STR :extra-args ARGS
:lua-filters FILES).  FROM and TO are symbols.  FROM-STR and TO-STR are
Pandoc -f/-t values.  ARGS is a list of extra Pandoc arguments.
FILES are Lua filter basenames resolved under `scs/convert--directory'."
  :type '(alist :key-type (cons symbol symbol) :value-type plist)
  :group 'scs-convert)

(defconst scs/convert--directory
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory containing scs-convert.el and sibling Lua filter files.

load-file-name is set when the file is loaded; buffer-file-name covers eval
in a visiting buffer during development.")

(defun scs/convert--format-plist (from to)
  "Return the plist for convert pair FROM -> TO, or signal `user-error'."
  (or (cdr (assoc (cons from to) scs/convert-formats))
      (user-error "No convert pair for %s -> %s" from to)))

(defun scs/convert--resolve-lua-filter (name)
  "Return absolute path for Lua filter NAME under the package directory."
  (let ((path (expand-file-name name scs/convert--directory)))
    (unless (file-readable-p path)
      (user-error "Missing Pandoc Lua filter: %s" path))
    path))

(defun scs/convert--pandoc-args (plist)
  "Build Pandoc argv list from convert PLIST."
  (let ((from (plist-get plist :from))
        (to (plist-get plist :to))
        (extra (plist-get plist :extra-args))
        (filters (plist-get plist :lua-filters))
        args)
    (unless (and from to)
      (user-error "Convert pair missing :from or :to"))
    ;; Pandoc reads stdin when no input file appears in ARGS; we use call-process-region.
    (setq args (list "-f" from "-t" to))
    (dolist (arg extra)
      (setq args (append args (list arg))))
    (dolist (filter filters)
      (setq args (append args
                         (list "--lua-filter"
                               (scs/convert--resolve-lua-filter filter)))))
    args))

(defun scs/convert--run (text plist)
  "Convert TEXT with Pandoc using convert PLIST; return Org string.
Signals `user-error' if Pandoc is missing or exits non-zero.  Does not
modify the caller's buffer."
  (let* ((program (or (executable-find scs/convert-pandoc-program)
                      (user-error "Pandoc not found: %s"
                                  scs/convert-pandoc-program)))
         (args (scs/convert--pandoc-args plist))
         ;; Separate stderr file: call-process-region merges stdout into the temp buffer only.
         (err-file (make-temp-file "scs-convert-err-")))
    (unwind-protect
        (with-temp-buffer
          (insert text)
          (let ((exit (apply #'call-process-region
                             (point-min) (point-max)
                             program
                             t
                             (list t err-file)
                             nil
                             args)))
            (unless (eq exit 0)
              (user-error "Pandoc failed (%s): %s"
                          exit
                          (string-trim
                           (with-temp-buffer
                             (insert-file-contents err-file)
                             (buffer-string)))))
            (buffer-string)))
      (when (file-exists-p err-file)
        (delete-file err-file)))))

(defun scs/convert--markdown-filename-p (filename)
  "Return non-nil if FILENAME has a Markdown extension."
  (when filename
    (member (downcase (file-name-extension filename t))
            '(".md" ".markdown"))))

(defun scs/convert--maybe-rename-to-org ()
  "If visiting a Markdown file, prompt to rename/save as .org."
  (when-let* ((file buffer-file-name)
              ((scs/convert--markdown-filename-p file))
              ((yes-or-no-p
                (format "Rename %s to .org? "
                        (file-name-nondirectory file)))))
    (let* ((default (concat (file-name-sans-extension file) ".org"))
           (new (read-file-name "Save Org as: "
                                (file-name-directory default)
                                default
                                nil
                                (file-name-nondirectory default))))
      (when (and new (not (string-empty-p new)))
        (set-visited-file-name (expand-file-name new) t t)))))

;;;###autoload
(defun scs/convert (&optional from to)
  "Convert region or buffer from FROM to TO via Pandoc.

FROM and TO are symbols naming a pair in `scs/convert-formats'
(default: markdown -> org).  If the region is active, only that text
is replaced; major mode and visited file are left alone.  If there is
no region, the whole buffer is replaced.  When converting the whole
buffer to Org, enable `org-mode'.  When the visited file looks like
Markdown by extension, prompt to rename it to .org.

Never infers FROM/TO from `major-mode'."
  (interactive)
  (let* ((from (or from 'markdown))
         (to (or to 'org))
         (plist (scs/convert--format-plist from to))
         (whole (not (use-region-p)))
         (start (if whole (point-min) (region-beginning)))
         (end (if whole (point-max) (region-end)))
         (input (buffer-substring-no-properties start end)))
    (when (string-empty-p (string-trim input))
      (user-error "Nothing to convert"))
    (let ((output (scs/convert--run input plist)))
      ;; atomic-change-group keeps undo as one step for the replace (and mode switch).
      (atomic-change-group
        (delete-region start end)
        (goto-char start)
        (insert output))
      (when (and whole (eq to 'org))
        (org-mode)
        (scs/convert--maybe-rename-to-org))
      (message "Converted %s -> %s (%s)"
               from to
               (if whole "buffer" "region")))))

(provide 'scs-convert)

;;; scs-convert.el ends here
