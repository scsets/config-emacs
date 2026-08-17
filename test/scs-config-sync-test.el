;;; scs-config-sync-test.el --- Tests for config git/el-get sync helpers  -*- lexical-binding: t; -*-

;; Filename: scs-config-sync-test.el
;; Description: ERT tests for lisp/scs-config-sync.el wanted/orphan helpers
;; Author: SCS
;; Copyright: Copyright (C) 2026, SCS, all rights reserved.
;; Created: 2026-08-17 Mon 12:45
;; Version: 0.1.0
;; Last-Updated: 2026-08-17 Mon 13:47
;; Update #: 2

;;; Commentary:
;;
;; Batch run (from repo root):
;;
;;   emacs -batch -L lisp -l ert -l lisp/scs-config-sync.el \
;;     -l test/scs-config-sync-test.el -f ert-run-tests-batch-and-exit

;;; Change Log:
;; Newest first.  File-local so readers need not dig through VCS.
;; add: 2026-08-17 -- git -C ROOT ERT
;; add: 2026-08-17 -- wanted-package and orphan-checkout ERT

;;; Code:

(require 'ert)
(require 'scs-config-sync)

(ert-deftest scs/el-get-source-symbol-plist ()
  "Recipe plists contribute their :name symbol."
  (should (eq (scs/el-get-source-symbol '(:name helm :type github)) 'helm))
  (should (eq (scs/el-get-source-symbol 'wgrep) 'wgrep))
  (should (eq (scs/el-get-source-symbol "avy") 'avy)))

(ert-deftest scs/el-get-wanted-package-symbols-merges-lists ()
  "Wanted set is local recipes plus extra-keep, always including el-get."
  (let ((scs/el-get-local-sources '((:name vertico :type github)
                                    (:name consult :type github)))
        (scs/el-get-extra-keep-packages '(wgrep avy)))
    (let ((wanted (scs/el-get-wanted-package-symbols)))
      (should (memq 'el-get wanted))
      (should (memq 'vertico wanted))
      (should (memq 'consult wanted))
      (should (memq 'wgrep wanted))
      (should (memq 'avy wanted))
      (should-not (memq 'helm wanted)))))

(ert-deftest scs/el-get-orphan-checkout-name-p-skips-manager-and-dotfiles ()
  "Never treat el-get or dot entries as leftovers."
  (let ((wanted '("vertico" "consult")))
    (should-not (scs/el-get-orphan-checkout-name-p "el-get" wanted))
    (should-not (scs/el-get-orphan-checkout-name-p "." wanted))
    (should-not (scs/el-get-orphan-checkout-name-p ".." wanted))
    (should-not (scs/el-get-orphan-checkout-name-p ".status.el" wanted))
    (should-not (scs/el-get-orphan-checkout-name-p "vertico" wanted))
    (should (scs/el-get-orphan-checkout-name-p "helm" wanted))
    (should (scs/el-get-orphan-checkout-name-p "wfnames" wanted))))

(ert-deftest scs/emacs-config-git-uses-minus-c ()
  "git -C a non-repo fails even when default-directory is a git tree.

Without `-C', `call-process' would use `default-directory' and this
would succeed if Emacs was started from the config repo."
  (skip-unless (executable-find "git"))
  (let ((default-directory (expand-file-name user-emacs-directory))
        (empty (make-temp-file "scs-git-c-" t)))
    (unwind-protect
        (with-temp-buffer
          (should-not
           (zerop (scs/emacs-config-git empty "rev-parse"
                                        "--is-inside-work-tree"))))
      (delete-directory empty t))))

(provide 'scs-config-sync-test)
;;; scs-config-sync-test.el ends here
