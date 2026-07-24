;;; scs-file-header-test.el --- Tests for scs-file-header  -*- lexical-binding: t; -*-

(require 'ert)
(require 'org)
(require 'scs-file-header)

(defun scs-file-header-test--call (stamp)
  "Call the save hook with STAMP forced via stamp-function."
  (let ((scs/file-header-stamp-function (lambda () stamp)))
    (scs/update-last-updated-on-save)))

(ert-deftest scs/update-last-updated-org-updates-header-only ()
  "Org preamble LAST-UPDATED updates; later lookalike stays."
  (with-temp-buffer
    (org-mode)
    (setq buffer-file-name "/tmp/stamp-test.org")
    (insert (concat "#+TITLE: Stamp test\n"
                    "#+LAST-UPDATED: 2000-01-01 Sat 00:00\n"
                    "#+UPDATE: 0\n"
                    "\n"
                    "* Body\n"
                    "#+LAST-UPDATED: 1999-01-01 Fri 00:00\n"))
    (scs-file-header-test--call "2099-01-01 Wed 12:00")
    (let ((s (buffer-string)))
      (should (string-match-p
               "#\\+LAST-UPDATED: 2099-01-01 Wed 12:00\n"
               s))
      (should (string-match-p
               "#\\+LAST-UPDATED: 1999-01-01 Fri 00:00\n"
               s))
      (should-not (string-match-p
                   "#\\+LAST-UPDATED: 2000-01-01 Sat 00:00\n"
                   s)))))

(ert-deftest scs/update-last-updated-org-missing-field-noop ()
  "Org buffer without LAST-UPDATED is unchanged."
  (with-temp-buffer
    (org-mode)
    (setq buffer-file-name "/tmp/no-stamp.org")
    (insert "#+TITLE: No stamp\n\n* Body\n")
    (let ((before (buffer-string)))
      (scs-file-header-test--call "2099-01-01 Wed 12:00")
      (should (equal (buffer-string) before)))))

(ert-deftest scs/update-last-updated-elisp-header ()
  "Elisp header Last-Updated updates."
  (with-temp-buffer
    (emacs-lisp-mode)
    (setq buffer-file-name "/tmp/stamp-test.el")
    (insert (concat ";;; stamp-test.el --- demo  -*- lexical-binding: t; -*-\n"
                    ";; Filename: stamp-test.el\n"
                    ";; Last-Updated: 2000-01-01 Sat 00:00\n"
                    ";; Update #: 0\n"
                    "\n"
                    ";;; Code:\n"
                    "\n"
                    "(provide 'stamp-test)\n"))
    (scs-file-header-test--call "2099-01-01 Wed 12:00")
    (should (string-match-p
             ";; Last-Updated: 2099-01-01 Wed 12:00\n"
             (buffer-string)))
    (should-not (string-match-p
                 ";; Last-Updated: 2000-01-01 Sat 00:00\n"
                 (buffer-string)))))

(ert-deftest scs/update-last-updated-elisp-after-code-noop ()
  "Elisp Last-Updated after ;;; Code: is outside preamble."
  (with-temp-buffer
    (emacs-lisp-mode)
    (setq buffer-file-name "/tmp/late-stamp.el")
    (insert (concat ";;; late-stamp.el --- demo  -*- lexical-binding: t; -*-\n"
                    "\n"
                    ";;; Code:\n"
                    "\n"
                    ";; Last-Updated: 2000-01-01 Sat 00:00\n"
                    "(provide 'late-stamp)\n"))
    (let ((before (buffer-string)))
      (scs-file-header-test--call "2099-01-01 Wed 12:00")
      (should (equal (buffer-string) before)))))

(ert-deftest scs/update-last-updated-lisp-header ()
  "lisp-mode header Last-Updated updates."
  (with-temp-buffer
    (lisp-mode)
    (setq buffer-file-name "/tmp/stamp-test.lisp")
    (insert (concat ";;; stamp-test.lisp -- demo\n"
                    ";; Last-Updated: 2000-01-01 Sat 00:00\n"
                    "\n"
                    "(defun demo () nil)\n"))
    (scs-file-header-test--call "2099-01-01 Wed 12:00")
    (should (string-match-p
             ";; Last-Updated: 2099-01-01 Wed 12:00\n"
             (buffer-string)))))

(ert-deftest scs/update-last-updated-nontarget-mode-noop ()
  "Non-target major mode is a no-op."
  (with-temp-buffer
    (text-mode)
    (setq buffer-file-name "/tmp/stamp-test.txt")
    (insert "#+LAST-UPDATED: 2000-01-01 Sat 00:00\n")
    (let ((before (buffer-string)))
      (scs-file-header-test--call "2099-01-01 Wed 12:00")
      (should (equal (buffer-string) before)))))

(ert-deftest scs/update-last-updated-no-file-name-noop ()
  "Buffers without buffer-file-name are skipped."
  (with-temp-buffer
    (org-mode)
    (setq buffer-file-name nil)
    (insert "#+LAST-UPDATED: 2000-01-01 Sat 00:00\n")
    (let ((before (buffer-string)))
      (scs-file-header-test--call "2099-01-01 Wed 12:00")
      (should (equal (buffer-string) before)))))

(provide 'scs-file-header-test)

;;; scs-file-header-test.el ends here
