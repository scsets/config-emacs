;;; scs-backward-kill-word-test.el --- Tests for blank-line-aware M-DEL  -*- lexical-binding: t; -*-

;; Filename: scs-backward-kill-word-test.el
;; Description: ERT regressions for lisp/scs-backward-kill-word.el
;; Author: SCS
;; Copyright: Copyright (C) 2026, SCS, all rights reserved.
;; Created: 2026-08-29 Sat 16:34
;; Version: 0.1.0
;; Last-Updated: 2026-08-29 Sat 16:34
;; Update #: 0

;;; Commentary:
;;
;; The scene these tests protect: four M-DEL presses on
;;
;;   word1 word2
;;
;;   word3 word4
;;
;; must take word4, word3, the blank line, then word2 -- never word2
;; together with the blank line.
;;
;; Batch run (from the repository root):
;;
;;   emacs -Q --batch -L lisp -l ert -l test/scs-backward-kill-word-test.el \
;;     -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'scs-backward-kill-word)

(defun scs/backward-kill-word-test--buffer (text)
  "Insert TEXT in a temp buffer, move to the end, and return that buffer.
The caller owns the `with-current-buffer' and any kills."
  (let ((buf (generate-new-buffer " *scs-bkw-test*")))
    (with-current-buffer buf
      (insert text)
      (goto-char (point-max)))
    buf))

(ert-deftest scs/backward-kill-word-blank-line-is-own-unit ()
  "Three presses take word4, word3, and the blank line; the fourth takes word2."
  (let ((buf (scs/backward-kill-word-test--buffer "word1 word2\n\nword3 word4"))
        (kill-ring nil)
        (kill-ring-yank-pointer nil))
    (unwind-protect
        (with-current-buffer buf
          (scs/backward-kill-word)
          (should (equal (buffer-string) "word1 word2\n\nword3 "))
          (scs/backward-kill-word)
          (should (equal (buffer-string) "word1 word2\n\n"))
          (scs/backward-kill-word)
          (should (equal (buffer-string) "word1 word2\n"))
          (should (eq (point) (point-max)))
          (scs/backward-kill-word)
          (should (equal (buffer-string) "word1 ")))
      (kill-buffer buf))))

(ert-deftest scs/backward-kill-word-prefix-repeats-units ()
  "A prefix of 3 is the same as three presses: sit below word1 word2."
  (let ((buf (scs/backward-kill-word-test--buffer "word1 word2\n\nword3 word4"))
        (kill-ring nil)
        (kill-ring-yank-pointer nil))
    (unwind-protect
        (with-current-buffer buf
          (scs/backward-kill-word 3)
          (should (equal (buffer-string) "word1 word2\n"))
          (should (eq (point) (point-max))))
      (kill-buffer buf))))

(ert-deftest scs/backward-kill-word-punctuation-is-own-class ()
  "A closing paren is not swept up with the word before it."
  (let ((buf (scs/backward-kill-word-test--buffer "baz ()"))
        (kill-ring nil)
        (kill-ring-yank-pointer nil))
    (unwind-protect
        (with-current-buffer buf
          (scs/backward-kill-word)
          (should (equal (buffer-string) "baz (")))
      (kill-buffer buf))))

(ert-deftest scs/backward-kill-word-stock-would-eat-word2 ()
  "Document why this command exists: stock M-DEL 3 takes word2 too."
  (with-temp-buffer
    (insert "word1 word2\n\nword3 word4")
    (goto-char (point-max))
    (backward-kill-word 3)
    (should (equal (buffer-string) "word1 "))))

(provide 'scs-backward-kill-word-test)

;;; scs-backward-kill-word-test.el ends here
