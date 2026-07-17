;;; scs-org-tools.el --- Reusable Org helpers for SCS  -*- lexical-binding: t; -*-

;; Author: SCS
;; Keywords: org, convenience
;; Package-Requires: ((emacs "29.1") (org "9.0"))

;;; Commentary:
;;
;; Reusable Org-mode helpers for howm notes and other Org files in this
;; config.  Provides `scs/org-insert-creation-date' and
;; `scs/org-append-zwsp-markers'; additional commands can be added here
;; over time.
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

;;; Code:

(require 'org)
(require 'scs-cl)

(defun scs/org--paragraph-in-list-item-p (paragraph)
  "Return non-nil if PARAGRAPH is nested inside an Org list item."
  (let ((parent (org-element-property :parent paragraph)))
    (and parent (eq (org-element-type parent) 'item))))

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
    ;; cl-case on (null bounds): non-nil bounds => nil => match ((nil) …)
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
elements of type `paragraph' whose `:begin' is at or after point, and
that are not nested inside a list item, are updated.  An existing
trailing \\\\zwsp{}_[0-9]+ is replaced.  Sentence punctuation is left
unchanged.

Signals `user-error' if called outside Org mode."
  (interactive "p")
  (unless (derived-mode-p 'org-mode)
    (user-error "Not in Org mode"))
  (let* ((start (or start 1))
         (origin (point))
         (paragraphs
          (org-element-map (org-element-parse-buffer) 'paragraph
            (lambda (p)
              (when (and (>= (org-element-property :begin p) origin)
                         (not (scs/org--paragraph-in-list-item-p p)))
                p))))
         (n start)
         (jobs nil))
    (dolist (p paragraphs)
      (push (cons (org-element-property :contents-end p) n) jobs)
      (setq n (1+ n)))
    ;; `push' built jobs last→first already; edit in that order.
    (dolist (job jobs)
      (scs/org--set-zwsp-marker-at (car job) (cdr job)))
    (message "Updated %d paragraph%s"
             (length jobs)
             (if (= (length jobs) 1) "" "s"))))

(provide 'scs-org-tools)

;;; scs-org-tools.el ends here
