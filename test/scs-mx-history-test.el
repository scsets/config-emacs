;;; scs-mx-history-test.el --- Tests for M-x history pinning  -*- lexical-binding: t; -*-

;; Filename: scs-mx-history-test.el
;; Description: ERT regressions for lisp/scs-mx-history.el
;; Author: SCS
;; Copyright: Copyright (C) 2026, SCS, all rights reserved.
;; Created: 2026-09-03 Thu 09:36
;; Version: 0.1.0
;; Last-Updated: 2026-09-03 Thu 09:36
;; Update #: 0

;;; Commentary:
;;
;; The data is `extended-command-history': newest command-name string
;; first.  These tests protect the pin policy, not Vertico's sort.
;;
;; Batch run (from the repository root):
;;
;;   emacs -Q --batch -L lisp -l ert -l test/scs-mx-history-test.el \
;;     -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'scs-mx-history)

(ert-deftest scs/mx-history-remember-pins-missing ()
  "A name that is not already first is prepended."
  (let ((extended-command-history '("older")))
    (scs/mx-history-remember "failed")
    (should (equal (car extended-command-history) "failed"))
    (should (equal (cadr extended-command-history) "older"))))

(ert-deftest scs/mx-history-remember-accepts-symbol ()
  "A command symbol is stored as its name string."
  (let ((extended-command-history '("older")))
    (scs/mx-history-remember 'failed-cmd)
    (should (equal (car extended-command-history) "failed-cmd"))))

(ert-deftest scs/mx-history-remember-does-not-duplicate-car ()
  "Already-first names are not copied; extra copies would inflate frequency."
  (let ((extended-command-history '("failed" "older")))
    (scs/mx-history-remember "failed")
    (should (equal extended-command-history '("failed" "older")))))

(ert-deftest scs/mx-history-remember-ignores-nil-and-empty ()
  "Quit-shaped values must not invent a history entry."
  (let ((extended-command-history '("older")))
    (scs/mx-history-remember nil)
    (scs/mx-history-remember "")
    (should (equal extended-command-history '("older")))))

(ert-deftest scs/mx-history-around-keeps-name-when-command-errors ()
  "An error from ORIG still leaves COMMAND-NAME first."
  (let ((extended-command-history '("older")))
    (should-error
     (scs/mx-history-around-execute
      (lambda (&rest _) (error "boom"))
      nil "broken-cmd" nil)
     :type 'error)
    (should (equal (car extended-command-history) "broken-cmd"))))

(ert-deftest scs/mx-history-around-success-pins-if-missing ()
  "A successful ORIG that did not prepend still gets a first-place entry."
  (let ((extended-command-history '("older")))
    (scs/mx-history-around-execute (lambda (&rest _) t) nil "ok" nil)
    (should (equal (car extended-command-history) "ok"))
    (should (equal (cadr extended-command-history) "older"))))

(ert-deftest scs/mx-history-around-success-no-extra-copy ()
  "A successful ORIG that already prepended is not counted twice."
  (let ((extended-command-history '("ok")))
    (scs/mx-history-around-execute (lambda (&rest _) t) nil "ok" nil)
    (should (equal extended-command-history '("ok")))))

(provide 'scs-mx-history-test)

;;; scs-mx-history-test.el ends here
