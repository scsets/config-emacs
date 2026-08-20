;;; scs-sort-line-fields-test.el --- Tests for pipe-field line sort  -*- lexical-binding: t; -*-

;; Filename: scs-sort-line-fields-test.el
;; Description: ERT regressions for lisp/scs-sort-line-fields.el
;; Author: SCS
;; Copyright: Copyright (C) 2026, SCS, all rights reserved.
;; Created: 2026-08-20 Thu 14:19
;; Version: 0.1.0
;; Last-Updated: 2026-08-20 Thu 14:19
;; Update #: 0

;;; Commentary:
;;
;; Protect the data shape: a line is a list of `|'-separated strings,
;; sorted, then joined with ` | '.  Lines with no pipe must stay put.
;;
;; Batch run (from the repository root):
;;
;;   emacs -Q --batch -L lisp -l ert -l test/scs-sort-line-fields-test.el \
;;     -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'scs-sort-line-fields)

(defconst scs/sort-line-fields-test-input
  "poetry | answer | aphorism | song | talk | letter | fragment | dialogue"
  "The motivating unsorted line from the original request.")

(defconst scs/sort-line-fields-test-sorted
  "answer | aphorism | dialogue | fragment | letter | poetry | song | talk"
  "Expected alphabetical rewrite of `scs/sort-line-fields-test-input'.")

(ert-deftest scs/sort-line-fields-sorts-pipe-fields ()
  "The original pipe-separated line sorts alphabetically."
  (should (equal (scs/sort-line-fields--sorted-string
                  scs/sort-line-fields-test-input)
                 scs/sort-line-fields-test-sorted)))

(ert-deftest scs/sort-line-fields-ignores-lines-without-pipe ()
  "Ordinary prose is not trimmed or rewritten."
  (should (equal (scs/sort-line-fields--sorted-string "poetry")
                 "poetry"))
  (should (equal (scs/sort-line-fields--sorted-string "  keep spaces  ")
                 "  keep spaces  "))
  (should (equal (scs/sort-line-fields--sorted-string "")
                 "")))

(ert-deftest scs/sort-line-fields-trims-separator-space ()
  "Spaces around the pipe are separator, not field text."
  (should (equal (scs/sort-line-fields--sorted-string "song|answer|poetry")
                 "answer | poetry | song"))
  (should (equal (scs/sort-line-fields--sorted-string "  b  |  a  |  c  ")
                 "a | b | c")))

(ert-deftest scs/sort-line-fields-reverse ()
  "REVERSE non-nil writes descending order."
  (should (equal (scs/sort-line-fields--sorted-string
                  scs/sort-line-fields-test-input t)
                 "talk | song | poetry | letter | fragment | dialogue | aphorism | answer")))

(ert-deftest scs/sort-line-fields-respects-sort-fold-case ()
  "FOLD-CASE t compares Song and aphorism without regard to case."
  (should (equal (scs/sort-line-fields--sorted-string
                  "Song | aphorism | letter" nil t)
                 "aphorism | letter | Song"))
  (should (equal (scs/sort-line-fields--sorted-string
                  "Song | aphorism | letter" nil nil)
                 "Song | aphorism | letter")))

(ert-deftest scs/sort-line-fields-rewrites-current-line ()
  "The interactive command rewrites the line point is on."
  (with-temp-buffer
    (insert scs/sort-line-fields-test-input)
    (goto-char (point-min))
    (scs/sort-line-fields)
    (should (equal (buffer-string) scs/sort-line-fields-test-sorted))))

(ert-deftest scs/sort-line-fields-command-reads-sort-fold-case ()
  "The command passes `sort-fold-case' through as FOLD-CASE."
  (require 'sort)
  (with-temp-buffer
    (insert "Song | aphorism | letter")
    (goto-char (point-min))
    (let ((sort-fold-case t))
      (scs/sort-line-fields)
      (should (equal (buffer-string) "aphorism | letter | Song")))))

(ert-deftest scs/sort-line-fields-region-sorts-each-line ()
  "An active region sorts each touched line independently."
  (with-temp-buffer
    (transient-mark-mode 1)
    (insert "c | a | b\npoetry | answer\nleave me\n")
    (goto-char (point-min))
    (set-mark (point))
    (forward-line 2)
    (setq mark-active t)
    (scs/sort-line-fields)
    (should (equal (buffer-string)
                   "a | b | c\nanswer | poetry\nleave me\n"))))

(provide 'scs-sort-line-fields-test)

;;; scs-sort-line-fields-test.el ends here
