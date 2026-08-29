;;; scs-reveal-file-test.el --- Tests for contextual file reveal  -*- lexical-binding: t; -*-

;; Filename: scs-reveal-file-test.el
;; Description: ERT regressions for lisp/scs-reveal-file.el
;; Author: SCS
;; Copyright: Copyright (C) 2026, SCS, all rights reserved.
;; Created: 2026-08-29 Sat 15:00
;; Version: 0.1.0
;; Last-Updated: 2026-08-29 Sat 15:00
;; Update #: 0

;;; Commentary:
;;
;; Batch run (from the repository root):
;;
;;   emacs -Q --batch -L lisp -l ert -l test/scs-reveal-file-test.el \
;;     -f ert-run-tests-batch-and-exit

;;; Change Log:
;; Newest first.  File-local so readers need not dig through VCS.
;; add: 2026-08-29 -- cover target resolution, clipboard, and Dired branch

;;; Code:

(require 'ert)
(require 'dired)
(require 'scs-reveal-file)

(ert-deftest scs/reveal-file-target-from-visited-file ()
  "Resolve an existing visited file to its absolute path."
  (let ((file (make-temp-file "scs-reveal-file-test-")))
    (unwind-protect
        (with-temp-buffer
          (setq buffer-file-name file)
          (should (equal (scs/reveal-file--target) file)))
      (delete-file file))))

(ert-deftest scs/reveal-file-target-errors-without-file ()
  "Signal when the buffer is not visiting a file."
  (with-temp-buffer
    (should-error (scs/reveal-file--target) :type 'user-error)))

(ert-deftest scs/reveal-file-target-errors-when-missing ()
  "Signal when buffer-file-name points at a deleted file."
  (with-temp-buffer
    (setq buffer-file-name "/tmp/scs-reveal-file-missing-should-not-exist")
    (should-error (scs/reveal-file--target) :type 'user-error)))

(ert-deftest scs/reveal-file-copy-path-uses-kill-ring ()
  "Copy the absolute path onto the kill ring."
  (let ((interprogram-cut-function nil)
        (kill-ring nil)
        (kill-ring-yank-pointer nil)
        (path "/tmp/scs-reveal-file-copy-test"))
    (should (eq (scs/reveal-file--copy-path path) path))
    (should (equal (current-kill 0) path))))

(ert-deftest scs/reveal-file-use-dired-p-on-tty ()
  "Prefer Dired when Emacs is not on a graphic display."
  (let ((path "/tmp/scs-reveal-file-local"))
    (let ((display-graphic-p-backup (symbol-function 'display-graphic-p)))
      (unwind-protect
          (progn
            (defun display-graphic-p (&optional display) (declare (ignore display)) nil)
            (should (scs/reveal-file--use-dired-p path)))
        (if display-graphic-p-backup
            (fset 'display-graphic-p display-graphic-p-backup)
          (fmakunbound 'display-graphic-p))))))

(ert-deftest scs/reveal-file-use-dired-p-on-tramp ()
  "Prefer Dired for remote paths even on GUI frames."
  (let ((path "/ssh:example.com:/tmp/remote-file.txt"))
    (let ((display-graphic-p-backup (symbol-function 'display-graphic-p)))
      (unwind-protect
          (progn
            (defun display-graphic-p (&optional display) (declare (ignore display)) t)
            (should (scs/reveal-file--use-dired-p path)))
        (if display-graphic-p-backup
            (fset 'display-graphic-p display-graphic-p-backup)
          (fmakunbound 'display-graphic-p))))))

(ert-deftest scs/reveal-file-open-dired-jumps-to-file ()
  "Open Dired with point on the requested file."
  (let* ((root (make-temp-file "scs-reveal-file-dired-" t))
         (file (expand-file-name "child.txt" root)))
    (unwind-protect
        (progn
          (write-region "hello" nil file)
          (scs/reveal-file--open-dired file)
          (should (derived-mode-p 'dired-mode))
          (should (dired-goto-file file)))
      (delete-directory root t))))

(provide 'scs-reveal-file-test)

;;; scs-reveal-file-test.el ends here
