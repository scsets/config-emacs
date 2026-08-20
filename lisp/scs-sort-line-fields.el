;;; scs-sort-line-fields.el --- Sort pipe-separated fields on a line  -*- lexical-binding: t; -*-

;; Filename: scs-sort-line-fields.el
;; Description: Alphabetically sort | fields on the current line or region
;; Author: SCS
;; Copyright: Copyright (C) 2026, SCS, all rights reserved.
;; Created: 2026-08-20 Thu 14:19
;; Version: 0.1.0
;; Last-Updated: 2026-08-20 Thu 14:19
;; Update #: 0
;; Keywords: convenience, editing, sort
;; Package-Requires: ((emacs "29.1"))

;;; Commentary:
;;
;; Problem
;; -------
;; Emacs sort commands work on lines (`sort-lines', `sort-fields').  They
;; do not sort the pieces *inside* one line.  A line such as:
;;
;;   poetry | answer | aphorism | song
;;
;; stays in author order unless you split it by hand.
;;
;; Solution
;; --------
;; `scs/sort-line-fields' treats the current line as a list of fields
;; separated by `|', with optional spaces around each pipe.  It sorts
;; that list as strings and writes it back joined with ` | '.  That list
;; of strings is the data; the command only reads, sorts, and writes it.
;;
;; A line with no pipe is left unchanged, so a stray call does not trim
;; or rewrite ordinary prose.  An empty line stays empty.
;;
;; If the region is active, each full line the region touches is sorted
;; independently (one undo record for the whole region).
;;
;; With a prefix argument, sort in reverse.  `sort-fold-case' is
;; respected, same policy as `sort-lines'.
;;
;; How to check
;; ------------
;;   M-x scs/sort-line-fields RET
;;   on:  poetry | answer | aphorism
;;   ->   answer | aphorism | poetry
;;
;;   emacs -Q --batch -L lisp -l ert -l test/scs-sort-line-fields-test.el \
;;     -f ert-run-tests-batch-and-exit
;;
;; Documented helpers used
;; -----------------------
;; `split-string' (STRING SEPARATORS OMIT-EMPTY TRIM), `string-join',
;; `string<', `sort', `use-region-p', `atomic-change-group'.

;;; Code:

(require 'subr-x)

(defconst scs/sort-line-fields-split-regexp " *| *"
  "Regexp that splits fields for `scs/sort-line-fields'.

A pipe with optional spaces on either side.  The spaces are separator,
not field text, so `answer | aphorism' and `answer|aphorism' split the
same way.")

(defconst scs/sort-line-fields-join " | "
  "String used to rejoin sorted fields on one line.")

(defun scs/sort-line-fields--lessp (a b fold-case)
  "Return non-nil if field A sorts before field B.

Uses `string<' (code-point order), which is inspectable and matches
the usual ASCII alphabet.  When FOLD-CASE is non-nil, compare
downcased copies so the command can agree with `sort-lines'."
  (if fold-case
      (string< (downcase a) (downcase b))
    (string< a b)))

(defun scs/sort-line-fields--sorted-string (line &optional reverse fold-case)
  "Return LINE with pipe-separated fields sorted alphabetically.

LINE is a string without a trailing newline.  REVERSE non-nil means
descending order.  FOLD-CASE non-nil means ignore alphabetic case
(the same idea as `sort-fold-case' on `sort-lines').

Empty strings and strings with no `|' are returned unchanged.  Empty
pieces after the split (a doubled pipe, leftover spaces) are dropped.

FOLD-CASE is an argument rather than a free read of `sort-fold-case'
so a test can pass t or nil without fighting lexical-binding."
  (if (or (string-empty-p line)
          (not (string-match-p "|" line)))
      line
    (let* ((fields (split-string line scs/sort-line-fields-split-regexp
                                 t "[ \t]+"))
           (ordered (sort fields
                          (lambda (a b)
                            (scs/sort-line-fields--lessp a b fold-case)))))
      (when reverse
        ;; One comparator, then reverse: keeps the fold-case rule in
        ;; one place.
        (setq ordered (nreverse ordered)))
      (string-join ordered scs/sort-line-fields-join))))

(defun scs/sort-line-fields--current-line (&optional reverse)
  "Replace the current line with its pipe-separated fields sorted.

Does not move to another line.  Leaves the terminating newline alone.
Reads `sort-fold-case' once here and passes it down as data."
  (let* ((beg (line-beginning-position))
         (end (line-end-position))
         (line (buffer-substring-no-properties beg end))
         (fold (and (boundp 'sort-fold-case) sort-fold-case))
         (sorted (scs/sort-line-fields--sorted-string line reverse fold)))
    (unless (string-equal line sorted)
      (delete-region beg end)
      (insert sorted))))

(defun scs/sort-line-fields--region (beg end &optional reverse)
  "Sort pipe-separated fields on each full line from BEG to END.

BEG and END may fall mid-line; the command expands to the whole lines
they touch.  If END sits at the beginning of a line, that next line is
not included (same idea as a typical linewise region)."
  (let* ((beg (save-excursion
                (goto-char beg)
                (line-beginning-position)))
         (end (save-excursion
                (goto-char end)
                (if (and (bolp) (/= beg end))
                    end
                  (line-end-position)))))
    (save-excursion
      (save-restriction
        (narrow-to-region beg end)
        (goto-char (point-min))
        (while (not (eobp))
          (scs/sort-line-fields--current-line reverse)
          (forward-line 1))))))

;;;###autoload
(defun scs/sort-line-fields (&optional reverse)
  "Sort pipe-separated fields on this line alphabetically.

Fields are the pieces between `|'.  Spaces around the pipe are
separator, not field text.  The sorted fields are written back joined
with ` | '.

Example:

  poetry | answer | aphorism | song | talk | letter | fragment | dialogue

becomes:

  answer | aphorism | dialogue | fragment | letter | poetry | song | talk

A line with no pipe is left unchanged.

With a prefix argument, sort in reverse.  If the region is active,
sort each line in the region independently.

The variable `sort-fold-case' controls whether alphabetic case affects
the order, same as `sort-lines'."
  (interactive "P")
  (if (use-region-p)
      (atomic-change-group
        (scs/sort-line-fields--region (region-beginning) (region-end)
                                      reverse))
    (scs/sort-line-fields--current-line reverse)))

(provide 'scs-sort-line-fields)

;;; scs-sort-line-fields.el ends here
