;;; scs-copy-path-test.el --- Tests for contextual path copying  -*- lexical-binding: t; -*-

;; Filename: scs-copy-path-test.el
;; Description: ERT regressions for lisp/scs-copy-path.el
;; Author: SCS
;; Copyright: Copyright (C) 2026, SCS, all rights reserved.
;; Created: 2026-07-31 Fri 14:50
;; Version: 0.1.0
;; Last-Updated: 2026-07-31 Fri 14:50
;; Update #: 0

;;; Commentary:
;;
;; These tests protect the context that a plain path string cannot carry:
;; whether a Dired entry is itself a directory, and where point resides in
;; the full file while the current buffer is narrowed.
;;
;; Batch run (from the repository root):
;;
;;   emacs -Q --batch -L lisp -l ert -l test/scs-copy-path-test.el \
;;     -f ert-run-tests-batch-and-exit

;;; Change Log:
;; Newest first.  File-local so readers need not dig through VCS.
;; add: 2026-07-31 -- cover Dired directories and absolute narrowed positions

;;; Code:

(require 'ert)
(require 'dired)
(require 'scs-copy-path)

(ert-deftest scs/copy-path-directory-keeps-dired-directory ()
  "Copy a selected Dired directory, not its parent directory."
  (let* ((root (make-temp-file "scs-copy-path-test-" t))
         (child (expand-file-name "child" root))
         (dired-buffer nil))
    (unwind-protect
        (progn
          (make-directory child)
          (setq dired-buffer (dired-noselect root))
          (with-current-buffer dired-buffer
            (should (dired-goto-file child))
            (let ((interprogram-cut-function nil)
                  (kill-ring nil)
                  (kill-ring-yank-pointer nil))
              (scs/copy-path 'directory)
              (should (equal (current-kill 0)
                             (file-name-as-directory child))))))
      (when (buffer-live-p dired-buffer)
        (kill-buffer dired-buffer))
      (delete-directory root t))))

(ert-deftest scs/copy-path-position-formats-ignore-narrowing ()
  "Report full-file line and column coordinates in a narrowed buffer."
  (with-temp-buffer
    (setq buffer-file-name "/tmp/scs-copy-path-narrowed.txt")
    (insert "one\ntwo\nabcdef\nfour\n")
    (goto-char (point-min))
    (forward-line 2)
    (forward-char 2)
    (narrow-to-region (point) (point-max))
    (forward-char 2)
    (should (equal (scs/copy-path--transform buffer-file-name 'line)
                   "/tmp/scs-copy-path-narrowed.txt:3"))
    (should (equal (scs/copy-path--transform buffer-file-name 'line-column)
                   "/tmp/scs-copy-path-narrowed.txt:3:5"))))

(provide 'scs-copy-path-test)

;;; scs-copy-path-test.el ends here
