;;; scs-backward-kill-word.el --- Kill a word without eating the blank line  -*- lexical-binding: t; -*-

;; Filename: scs-backward-kill-word.el
;; Description: M-DEL kills a word, then a blank line, then the word above
;; Author: SCS
;; Copyright: Copyright (C) 2026, SCS, all rights reserved.
;; Created: 2026-08-29 Sat 16:34
;; Version: 0.1.0
;; Last-Updated: 2026-08-29 Sat 16:34
;; Update #: 0
;; Keywords: convenience, editing, kill
;; Package-Requires: ((emacs "29.1"))

;;; Commentary:
;;
;; Problem
;; -------
;; Stock `backward-kill-word' (M-DEL / C-<backspace>) is not "delete the
;; previous word".  It kills from point to the start of a word, and
;; `forward-word' first skips every non-word character -- spaces, parens,
;; and newlines -- to find that word.  So with:
;;
;;   word1 word2
;;
;;   word3 word4|
;;
;; the first two M-DEL presses take word4 and word3, but the third skips
;; the blank line and takes word2 as well.  The blank line never gets its
;; own keystroke.
;;
;; Solution
;; --------
;; `scs/backward-kill-word' uses the characters immediately before point as
;; the data, not "the previous word wherever it is":
;;
;; 1. Two or more newlines: kill one newline (collapse one blank line).
;;    Point sits on the line below the previous content.
;; 2. Otherwise: kill the previous word, plus same-line spaces, plus at
;;    most one joining newline.  Punctuation is a separate syntax class,
;;    so `foo)' takes two presses.
;;
;; How to check
;; ------------
;;   emacs -Q --batch -L lisp -l ert -l test/scs-backward-kill-word-test.el \
;;     -f ert-run-tests-batch-and-exit
;;
;; Documented helpers used
;; -----------------------
;; `skip-chars-backward' (Elisp: Motion and Syntax / Character Motion),
;; `skip-syntax-backward' (Elisp: Motion and Syntax), `char-syntax'
;; (Elisp: Syntax Table Internals), `kill-region' (so consecutive
;; presses still append on the kill ring, same as stock M-DEL).

;;; Code:

(defun scs/backward-kill-word--newlines-before ()
  "Return how many consecutive newlines sit immediately before point.

Two or more means there is at least one empty line between point
and the previous content.  A single newline is only the end of
the previous line, not a blank line of its own."
  (let ((end (point)))
    (save-excursion
      (skip-chars-backward "\n")
      (- end (point)))))

(defun scs/backward-kill-word--once ()
  "Kill one backward unit at point.

See `scs/backward-kill-word' for the unit list.  This helper is
the one-press step; the command repeats it for a prefix argument."
  (cond
   ((bobp)
    (message "Beginning of buffer"))
   ;; Extra newline(s) between content: collapse one blank line and
   ;; stop.  Do not skip them to hunt for a word above.
   ((>= (scs/backward-kill-word--newlines-before) 2)
    (kill-region (1- (point)) (point)))
   (t
    (let ((end (point)))
      ;; One joining newline is the same unit as the word above it,
      ;; so after the blank line is gone the next press takes word2
      ;; rather than leaving an empty line as a fourth step.
      (when (eq (char-before) ?\n)
        (forward-char -1))
      (skip-chars-backward " \t")
      (unless (or (bobp) (eq (char-before) ?\n))
        (if (eq (char-syntax (char-before)) ?w)
            (skip-syntax-backward "w")
          ;; Punctuation, parens, Lisp hyphens (`_' syntax): one class.
          (skip-syntax-backward
           (char-to-string (char-syntax (char-before))))))
      (kill-region (point) end)))))

(defun scs/backward-kill-word (&optional arg)
  "Kill backward by a small visible unit; do not skip a blank line.

With ARG (default 1), repeat that many times.  Stock
`backward-kill-word' would skip a blank line and eat the word above
it; this command kills the blank line first.

If the region is active and `delete-active-region' allows it,
kill the region instead."
  (interactive "p")
  (cond
   ((and (use-region-p) delete-active-region)
    (kill-region (region-beginning) (region-end)))
   (t
    (dotimes (_ (max (prefix-numeric-value arg) 0))
      (scs/backward-kill-word--once)))))

(provide 'scs-backward-kill-word)

;;; scs-backward-kill-word.el ends here
