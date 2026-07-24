;;; scs-file-header.el --- Refresh LAST-UPDATED on save  -*- lexical-binding: t; -*-

;; Filename: scs-file-header.el
;; Description: before-save-hook to refresh existing LAST-UPDATED / Last-Updated
;; Author: SCS
;; Copyright: Copyright (C) 2026, SCS, all rights reserved.
;; Created: 2026-07-23 Thu 13:44
;; Version: 0.1.1
;; Last-Updated: 2026-07-24 Fri 06:43
;; Update #: 2
;; Keywords: convenience, files
;; Package-Requires: ((emacs "29.1"))
;; fix: 2026-07-24 -- teachable Commentary and why-comments for SCS team

;;; Commentary:
;;
;; Team-owned helper (not a personal snippet).  Design:
;;   docs/2026-07-23-update-last-updated-on-save-design.org
;;
;; Problem
;; -------
;; SCS file headers carry a LAST-UPDATED / Last-Updated stamp.  Without a
;; save-time refresh, that stamp drifts and stops meaning "last material
;; write".  Juniors then cannot trust the header as an inspectable clock.
;;
;; Solution
;; --------
;; `scs/update-last-updated-on-save' on `before-save-hook' rewrites the
;; first existing timestamp field inside the file preamble only:
;;
;;   Org:   #+LAST-UPDATED: YYYY-MM-DD Day HH:MM
;;   Lisp:  ;; Last-Updated: YYYY-MM-DD Day HH:MM
;;          (also ;;; Last-Updated: ...)
;;
;; Modes: org-mode, emacs-lisp-mode, lisp-mode (and derived).
;;
;; Policy (why these limits exist)
;; -------------------------------
;; - Missing field => no-op.  We never invent a header; that is a separate
;;   ensure-header workflow (see `scs/org-ensure-buffer-header' for Org).
;; - Do not bump VERSION or UPDATE / Update #.  Those are human/release
;;   counters, not "every save" clocks.
;; - Search only the preamble so examples in body text or after
;;   `;;; Code:' are not clobbered.
;; - Never signal an error that aborts the save.  A broken regexp must not
;;   strand an SCS engineer mid-edit.
;;
;; How to verify
;; -------------
;;   emacs -batch -L lisp -l ert -l lisp/scs-file-header.el \
;;     -l test/scs-file-header-test.el -f ert-run-tests-batch-and-exit
;;
;; TODO (future): consider MELPA `header2' for broader header insert/update
;; machinery, although we do not like the author's posture.  Keep this
;; narrow hook until a team review decides otherwise.  Built-in
;; `time-stamp' is a related alternative that needs cookies / local
;; patterns and was rejected for v1.

;;; Code:

(require 'subr-x)

(defgroup scs-file-header nil
  "SCS file-header timestamp helpers.

Customize group for the save-hook that refreshes LAST-UPDATED /
Last-Updated.  Prefix for related symbols: `scs/file-header-'."
  :group 'files
  :prefix "scs/file-header-")

(defun scs/file-header--default-stamp ()
  "Return the SCS header timestamp string (local time with weekday).

Format is `YYYY-MM-DD Day HH:MM', e.g. `2026-07-24 Fri 06:43'.
Same shape as Org header stamps in `scs-org-tools.el'.  Local zone,
24-hour clock, English weekday abbreviation from `format-time-string'."
  (format-time-string "%Y-%m-%d %a %H:%M"))

;; Indirection so ERT can force a fixed stamp without mocking the clock.
;; Production keeps the default; tests `let'-bind a lambda.
(defvar scs/file-header-stamp-function #'scs/file-header--default-stamp
  "Zero-arg function returning the stamp string written into headers.

Default is `scs/file-header--default-stamp'.  Tests may let-bind this
to a lambda that returns a fixed string so assertions stay deterministic.")

;; Character classes encode case-insensitivity without depending on
;; `case-fold-search', so a buffer-local fold setting cannot break saves.
;; Group 1 = prefix through colon (preserved).  Whitespace after the colon
;; is outside group 1 so rewrite can normalize to a single space.
(defconst scs/file-header--org-last-updated-re
  "^\\([ \t]*#\\+[Ll][Aa][Ss][Tt]-[Uu][Pp][Dd][Aa][Tt][Ee][Dd]:\\)[ \t]*\\(.*\\)$"
  "Regexp for an Org LAST-UPDATED keyword line.

Group 1 is the line prefix through the colon (keep spelling/indent).
Group 2 is the old value (discarded on rewrite).")

(defconst scs/file-header--lisp-last-updated-re
  "^\\([ \t]*;;+[ \t]*[Ll][Aa][Ss][Tt]-[Uu][Pp][Dd][Aa][Tt][Ee][Dd]:\\)[ \t]*\\(.*\\)$"
  "Regexp for a Lisp Last-Updated comment line.

Requires at least two leading semicolons so both `;;' and `;;;' match.
Group 1 is the prefix through the colon; group 2 is the old value.")

(defun scs/file-header--org-preamble-end ()
  "Return buffer position after the Org file preamble.

Walks from `point-min' over blank lines, `#...' comments that are not
`#+' keywords, and `#+KEYWORD:' lines.  Stops at the first Org headline
(`*...') or any other non-blank body line.  That bound is the exclusive
search limit for LAST-UPDATED so body examples stay untouched."
  (save-excursion
    (goto-char (point-min))
    (catch 'done
      (while (not (eobp))
        (cond
         ((looking-at-p "^[ \t]*$")
          (forward-line 1))
         ;; `# $Id$' and similar; not `#+KEYWORD:'.
         ((looking-at-p "^#[^+].*$")
          (forward-line 1))
         ((looking-at-p "^[ \t]*#\\+[^:\n]+:")
          (forward-line 1))
         ((looking-at-p "^\\*")
          (throw 'done (point)))
         (t
          (throw 'done (point)))))
      (point))))

(defun scs/file-header--lisp-preamble-end ()
  "Return buffer position after the Lisp / Elisp file preamble.

Walks blank lines and `;' comment lines from `point-min'.  Stops at
`;;; Code:' (conventional end of library header) or at the first
non-comment, non-blank line.  Commentary examples after Code: are
outside this region on purpose."
  (save-excursion
    (goto-char (point-min))
    (catch 'done
      (while (not (eobp))
        (cond
         ((looking-at-p "^[ \t]*$")
          (forward-line 1))
         ;; Check Code: before the generic comment arm, else ;;; Code:
         ;; would be swallowed as just another comment line.
         ((looking-at-p "^[ \t]*;;;[ \t]*Code:")
          (throw 'done (point)))
         ((looking-at-p "^[ \t]*;")
          (forward-line 1))
         (t
          (throw 'done (point)))))
      (point))))

(defun scs/file-header--rewrite-first (regexp end)
  "Rewrite the first REGEXP match before END with a fresh stamp.

REGEXP must expose group 1 as the preserved prefix through the colon.
Replaces the whole match with that prefix, one space, and the stamp from
`scs/file-header-stamp-function'.  Returns non-nil if a rewrite happened.

Why whole-match replace: leaving old `[ \\t]*' after the colon and only
replacing group 2 produced a double space (`:  stamp')."
  (save-excursion
    (goto-char (point-min))
    (when (re-search-forward regexp end t)
      (let* ((stamp (funcall scs/file-header-stamp-function))
             (prefix (match-string-no-properties 1)))
        (replace-match (concat prefix " " stamp) t t)
        t))))

;;;###autoload
(defun scs/update-last-updated-on-save ()
  "Refresh an existing LAST-UPDATED / Last-Updated field in the preamble.

Intended for `before-save-hook'.  Safe no-op when:
- `buffer-file-name' is nil (temporary / non-file buffers),
- major mode is not Org / Emacs Lisp / Lisp (or derived),
- or the preamble has no matching field.

Never inserts a missing field.  Never touches VERSION or UPDATE.
Wraps work in `condition-case' so a failure becomes a message instead of
aborting the save."
  (condition-case err
      (when (and buffer-file-name
                 (derived-mode-p 'org-mode 'emacs-lisp-mode 'lisp-mode))
        (cond
         ((derived-mode-p 'org-mode)
          (scs/file-header--rewrite-first
           scs/file-header--org-last-updated-re
           (scs/file-header--org-preamble-end)))
         ;; emacs-lisp-mode is not derived from lisp-mode; list both.
         ((derived-mode-p 'emacs-lisp-mode 'lisp-mode)
          (scs/file-header--rewrite-first
           scs/file-header--lisp-last-updated-re
           (scs/file-header--lisp-preamble-end)))))
    (error
     (message "scs/update-last-updated-on-save: %s"
              (error-message-string err))
     nil)))

(provide 'scs-file-header)

;;; scs-file-header.el ends here
