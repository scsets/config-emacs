;;; scs-startup-state-test.el --- Tests for scs-startup-state  -*- lexical-binding: t; -*-

;; Filename: scs-startup-state-test.el
;; Description: ERT tests for lisp/scs-startup-state.el
;; Author: SCS
;; Copyright: Copyright (C) 2026, SCS, all rights reserved.
;; Created: 2026-08-04 Tue 18:27
;; Version: 0.1.0
;; Last-Updated: 2026-08-04 Tue 18:27
;; Update #: 0

;;; Commentary:
;;
;; Batch run (from repo root):
;;
;;   emacs -batch -L lisp -l ert -l lisp/scs-frame-state.el \
;;     -l lisp/scs-startup-state.el -l test/scs-startup-state-test.el \
;;     -f ert-run-tests-batch-and-exit
;;
;; Path tests use temporary files so the suite does not depend on
;; ~/notes or a graphic display.

;;; Change Log:
;; Newest first.  File-local so readers need not dig through VCS.
;; add: 2026-08-04 -- ERT for resolve-files and once-flag

;;; Code:

(require 'ert)
(require 'scs-startup-state)

(ert-deftest scs/startup-state-resolve-files-skips-missing-keeps-order ()
  "Existing paths expand and keep order; missing paths are dropped."
  (let* ((a (make-temp-file "scs-startup-a-"))
         (b (make-temp-file "scs-startup-b-"))
         (missing (expand-file-name
                   "definitely-missing-scs-startup.el"
                   temporary-file-directory))
         (got (scs/startup-state--resolve-files
               (list a missing b))))
    (unwind-protect
        (progn
          (should (equal got
                         (list (expand-file-name a)
                               (expand-file-name b))))
          (should (= 2 (length got))))
      (delete-file a)
      (delete-file b))))

(ert-deftest scs/startup-state-resolve-files-empty ()
  "Nil or empty input yields nil."
  (should (eq nil (scs/startup-state--resolve-files nil)))
  (should (eq nil (scs/startup-state--resolve-files '()))))

(ert-deftest scs/startup-state-apply-respects-once-flag ()
  "When already applied, `scs/startup-state-apply' is a no-op."
  (let ((scs/startup-state--applied t)
        (scs/startup-state-files nil)
        (scs/startup-state-frame-label nil)
        (calls 0))
    (cl-letf (((symbol-function 'display-graphic-p)
               (lambda (&optional _frame) t))
              ((symbol-function 'scs/startup-state--apply-layout)
               (lambda (_files) (cl-incf calls))))
      (scs/startup-state-apply)
      (should (= 0 calls)))))

(provide 'scs-startup-state-test)
;;; scs-startup-state-test.el ends here
