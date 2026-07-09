;;; scs-org-tools.el --- Reusable Org helpers for SCS  -*- lexical-binding: t; -*-

;; Author: SCS
;; Keywords: org, convenience
;; Package-Requires: ((emacs "29.1") (org "9.0"))

;;; Commentary:
;;
;; Reusable Org-mode helpers for howm notes and other Org files in this
;; config.  Currently provides `scs/org-insert-creation-date'; additional
;; commands can be added here over time.
;;
;; `scs/org-insert-creation-date' sets the :creation-date: property on the
;; current Org headline to today's date in ISO 8601 format (YYYY-MM-DD).  If
;; the headline has no property drawer, one is created.  The entire drawer
;; is then normalized to lowercase -- :properties:, :end:, and every
;; property key -- so the new key always lands in a clean, consistent drawer
;; regardless of what was there before.

;;; Code:

(require 'org)
(require 'cl-lib)

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
    (cl-cond
     (bounds
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
              (forward-line 1))))))))

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

(provide 'scs-org-tools)

;;; scs-org-tools.el ends here
