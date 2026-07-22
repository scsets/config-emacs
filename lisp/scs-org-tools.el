;;; scs-org-tools.el --- Reusable Org helpers for SCS  -*- lexical-binding: t; -*-

;; Author: SCS
;; Keywords: org, convenience
;; Package-Requires: ((emacs "29.1") (org "9.0"))

;;; Commentary:
;;
;; Reusable Org-mode helpers for howm notes and other Org files in this
;; config.  Provides `scs/org-insert-creation-date',
;; `scs/org-append-zwsp-markers', and `scs/org-ensure-buffer-header';
;; additional commands can be added here over time.
;;
;; `scs/org-insert-creation-date' sets the :creation-date: property on the
;; current Org headline to today's date in ISO 8601 format (YYYY-MM-DD).  If
;; the headline has no property drawer, one is created.  The entire drawer
;; is then normalized to lowercase -- :properties:, :end:, and every
;; property key -- so the new key always lands in a clean, consistent drawer
;; regardless of what was there before.
;;
;; `scs/org-append-zwsp-markers' appends sequential \zwsp{}_N markers to
;; Org paragraphs from point onward, replacing any existing trailing marker.
;;
;; `scs/org-ensure-buffer-header' inserts or completes the SCS Org file
;; header from `scs/org-buffer-header-template-file', keeping existing
;; values, filling defaults for missing keywords, and reordering to match
;; the template.

;;; Code:

(require 'org)
(require 'scs-cl)
(require 'subr-x)

(defcustom scs/org-buffer-header-template-file
  (expand-file-name "scs_org-buffer-template.org"
                    (file-name-directory
                     (or load-file-name
                         (bound-and-true-p byte-compile-current-file)
                         (buffer-file-name))))
  "Org file that defines the SCS buffer-header keyword order.
Each non-blank `#+KEYWORD:' line contributes one keyword, in order."
  :type 'file
  :group 'org)

(defconst scs/org--header-keyword-re
  "^[ \t]*#\\+\\([^:\n]+\\):[ \t]*\\(.*\\)$"
  "Regexp matching an Org keyword line; groups are KEY and VALUE.")

(defconst scs/org--header-comment-re
  "^#[^+].*$"
  "Regexp matching a leading # comment that is not an Org #+keyword.")

(defun scs/org--header-stamp ()
  "Return the SCS header timestamp string (local time with weekday)."
  (format-time-string "%Y-%m-%d %a %H:%M"))

(defun scs/org--header-basename ()
  "Return the basename used for FILENAME / TITLE defaults."
  (if buffer-file-name
      (file-name-nondirectory buffer-file-name)
    (buffer-name)))

(defun scs/org--title-from-filename (basename)
  "Turn BASENAME into a sentence-case TITLE.
Strip a trailing .org, replace - and _ with spaces, upcase the first
character and downcase the rest."
  (let* ((name (if (string-suffix-p ".org" basename t)
                   (substring basename 0 -4)
                 basename))
         (spaced (replace-regexp-in-string "[-_]+" " " name))
         (trimmed (string-trim spaced)))
    (if (string-empty-p trimmed)
        ""
      (concat (upcase (substring trimmed 0 1))
              (downcase (substring trimmed 1))))))

(defun scs/org--load-header-template-keywords ()
  "Return the ordered list of header keywords from the template file.
Signals `user-error' if the template is missing or has no keywords."
  (let ((file scs/org-buffer-header-template-file))
    (unless (and file (file-readable-p file))
      (user-error "Header template not readable: %s" file))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (let ((keys nil))
        (while (not (eobp))
          (when (looking-at scs/org--header-keyword-re)
            (push (upcase (match-string 1)) keys))
          (forward-line 1))
        (setq keys (nreverse keys))
        (when (null keys)
          (user-error "Header template has no #+KEYWORD lines: %s" file))
        keys))))

(defun scs/org--header-default (keyword basename stamp)
  "Return the default VALUE for KEYWORD given BASENAME and STAMP."
  (pcase (upcase keyword)
    ("TITLE" (scs/org--title-from-filename basename))
    ("FILENAME" basename)
    ("DESCRIPTION" "")
    ("AUTHOR" "SCS")
    ("COPYRIGHT"
     (format "Copyright (C) %s, SCS, all rights reserved."
             (format-time-string "%Y")))
    ("DATE" stamp)
    ("VERSION" "0.1.0")
    ("LAST-UPDATED" stamp)
    ("UPDATE" "0")
    (_ "")))

(defun scs/org--parse-buffer-preamble (template-keys)
  "Parse the Org buffer preamble against TEMPLATE-KEYS.
Return (END LEADING-COMMENTS KNOWN UNKNOWN).  END is the buffer
position after the preamble, including trailing blank lines that sit
before the first body line.  LEADING-COMMENTS is a list of # comment
lines.  KNOWN is an alist of (KEY . VALUE) for template keys (first
wins).  UNKNOWN is a list of full keyword lines not in the template."
  (save-excursion
    (goto-char (point-min))
    (let ((known nil)
          (unknown nil)
          (comments nil)
          (template-set (mapcar #'upcase template-keys)))
      (cl-block done
        (while (not (eobp))
          (cond
           ((looking-at "^[ \t]*$")
            (forward-line 1))
           ((looking-at scs/org--header-comment-re)
            (push (buffer-substring-no-properties
                   (line-beginning-position) (line-end-position))
                  comments)
            (forward-line 1))
           ((looking-at scs/org--header-keyword-re)
            (let* ((key (upcase (match-string-no-properties 1)))
                   (value (match-string-no-properties 2))
                   (line (buffer-substring-no-properties
                          (line-beginning-position) (line-end-position))))
              (if (member key template-set)
                  (unless (assoc key known)
                    (push (cons key value) known))
                (push line unknown)))
            (forward-line 1))
           (t
            (cl-return-from done)))))
      (list (point)
            (nreverse comments)
            (nreverse known)
            (nreverse unknown)))))

(defun scs/org--header-value (known keyword basename stamp)
  "Return non-empty value for KEYWORD from KNOWN, else a default."
  (let* ((key (upcase keyword))
         (existing (cdr (assoc key known))))
    (if (and existing (not (string-empty-p (string-trim existing))))
        existing
      (scs/org--header-default key basename stamp))))

(defun scs/org--format-header-block (template-keys known comments unknown
                                                  basename stamp)
  "Build the replacement preamble string for the buffer header.
Always ends with a blank line after the canonical keywords (and after
any unknown keywords), so the following body keeps a clear separator."
  (with-temp-buffer
    (dolist (c comments)
      (insert c "\n"))
    (dolist (key template-keys)
      (insert (format "#+%s: %s\n"
                      key
                      (scs/org--header-value known key basename stamp))))
    (insert "\n")
    (dolist (u unknown)
      (insert u "\n"))
    (when unknown
      (insert "\n"))
    (buffer-string)))

;;;###autoload
(defun scs/org-ensure-buffer-header ()
  "Ensure this Org buffer has a full SCS file header.
Reads keyword order from `scs/org-buffer-header-template-file'.  Keeps
existing non-empty values, fills defaults for missing keywords, and
rewrites the preamble in template order.  Leading # comments are kept
above the header.  Unknown #+ keywords are placed after the canonical
block.  Signals `user-error' outside Org mode."
  (interactive)
  (unless (derived-mode-p 'org-mode)
    (user-error "Not in Org mode"))
  (let* ((template-keys (scs/org--load-header-template-keywords))
         (basename (scs/org--header-basename))
         (stamp (scs/org--header-stamp))
         (parsed (scs/org--parse-buffer-preamble template-keys))
         (end (nth 0 parsed))
         (comments (nth 1 parsed))
         (known (nth 2 parsed))
         (unknown (nth 3 parsed))
         (old (buffer-substring-no-properties (point-min) end))
         (new (scs/org--format-header-block
               template-keys known comments unknown basename stamp))
         (added 0))
    (dolist (key template-keys)
      (let ((existing (cdr (assoc (upcase key) known))))
        (when (or (null existing)
                  (string-empty-p (string-trim existing)))
          (setq added (1+ added)))))
    (if (string-equal old new)
        (message "Org buffer header already complete")
      (save-excursion
        (goto-char (point-min))
        (delete-region (point-min) end)
        (insert new))
      (message "Org buffer header: added %d, %s"
               added
               (if (zerop added) "reordered" "filled/reordered")))))

(defun scs/org--property-drawer-bounds ()
  "Return (START END INDENT) of the property drawer on the current heading, or nil.
START and END are buffer positions spanning :properties: through :end:.
INDENT is the leading whitespace shared by every drawer line.

Searches the entire entry between this headline and the next, so a drawer
is found even when body text or other lines precede it."
  (save-excursion
    (org-back-to-heading t)
    (let ((limit (org-entry-end-position)))
      (goto-char (line-beginning-position))
      (when (re-search-forward
             "^\\([ \t]*\\):\\(?:properties\\|PROPERTIES\\):[ \t]*$"
             limit t)
        (let ((start (match-beginning 0))
              (indent (match-string 1)))
          (when (re-search-forward
                 (concat "^" (regexp-quote indent)
                         ":\\(?:end\\|END\\):[ \t]*$")
                 limit t)
            (list start (line-end-position) indent)))))))

(defun scs/org--downcase-property-drawer ()
  "Downcase the property drawer on the current headline.
Converts :properties:, :end:, and every property :KEY: to lowercase.
Property values are left untouched.  Does nothing if the headline has
no drawer.

Locates the drawer with `scs/org--property-drawer-bounds'.  Iteration
stops at the :end: marker so text beyond the drawer is never touched."
  (let ((bounds (scs/org--property-drawer-bounds)))
    ;; cl-case on (null bounds): non-nil bounds => nil => match ((nil) ...)
    (cl-case (null bounds)
      ((nil)
       (cl-destructuring-bind (start end _indent) bounds
         (save-restriction
           (narrow-to-region start end)
           (goto-char (point-min))
           (cl-block done
             (while (not (eobp))
               (when (looking-at "^\\([ \t]*\\):\\([^:\n]+\\):")
                 (downcase-region (match-beginning 2) (match-end 2))
                 (when (string= (match-string 2) "end")
                   (cl-return-from done)))
               (forward-line 1)))))))))

;;;###autoload
(defun scs/org-insert-creation-date ()
  "Set the :creation-date: property on the current headline to today's date.
The date is stored in ISO 8601 format (YYYY-MM-DD).  If the headline has
no property drawer, one is created automatically by `org-entry-put'.
The entire drawer is then normalized to lowercase -- :properties:,
:end:, and all property keys -- so the result is always clean and
consistent.

Signals `user-error' if called outside Org mode."
  (interactive)
  (unless (derived-mode-p 'org-mode)
    (user-error "Not in Org mode"))
  (org-back-to-heading t)
  (org-entry-put nil "creation-date" (format-time-string "%Y-%m-%d"))
  (scs/org--downcase-property-drawer))

(defun scs/org--paragraph-in-list-item-p (paragraph)
  "Return non-nil if PARAGRAPH is nested inside an Org list item."
  (let ((parent (org-element-property :parent paragraph)))
    (and parent (eq (org-element-type parent) 'item))))

(defconst scs/org-zwsp-marker-re "\\\\zwsp{}_[0-9]+"
  "Regexp matching a trailing Org paragraph \\\\zwsp{}_N marker.")

(defun scs/org--set-zwsp-marker-at (contents-end n)
  "At paragraph CONTENTS-END, set trailing marker to N.
Removes an existing match of `scs/org-zwsp-marker-re' immediately before
CONTENTS-END, then inserts \\\\zwsp{}_N.  CONTENTS-END is an Org
`:contents-end' position (text end, not `:end' which includes blank
lines)."
  (save-excursion
    (goto-char contents-end)
    (skip-chars-backward " \t\n")
    (when (looking-back scs/org-zwsp-marker-re
                        (max (point-min) (- (point) 80)))
      (delete-region (match-beginning 0) (match-end 0)))
    (insert (format "\\zwsp{}_%d" n))))

;;;###autoload
(defun scs/org-append-zwsp-markers (&optional start)
  "Append sequential \\\\zwsp{}_N markers to Org paragraphs from point.
START (prefix arg; default 1) is the first number used.  Only Org
elements of type `paragraph' that contain point or lie after it are
updated; at a paragraph boundary the prior paragraph is skipped.  List
item paragraphs are never updated.  An existing trailing
\\\\zwsp{}_[0-9]+ is replaced.  Sentence punctuation is left unchanged.

Signals `user-error' if called outside Org mode."
  (interactive "p")
  (unless (derived-mode-p 'org-mode)
    (user-error "Not in Org mode"))
  (let* ((start (or start 1))
         (origin (point))
         (paragraphs
          (org-element-map (org-element-parse-buffer) 'paragraph
            (lambda (p)
              (when (and (not (scs/org--paragraph-in-list-item-p p))
                         (or (> (org-element-property :end p) origin)
                             (and (<= (org-element-property :begin p) origin)
                                  (< origin (org-element-property :end p)))))
                p))))
         (n start)
         (jobs nil))
    (dolist (p paragraphs)
      (push (cons (org-element-property :contents-end p) n) jobs)
      (setq n (1+ n)))
    ;; `push' built jobs last->first already; edit in that order.
    (dolist (job jobs)
      (scs/org--set-zwsp-marker-at (car job) (cdr job)))
    (message "Updated %d paragraph%s"
             (length jobs)
             (if (= (length jobs) 1) "" "s"))))

(provide 'scs-org-tools)

;;; scs-org-tools.el ends here
