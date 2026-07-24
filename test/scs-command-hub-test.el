;;; scs-command-hub-test.el --- Tests for command hub catalog  -*- lexical-binding: t; -*-

;; Filename: scs-command-hub-test.el
;; Description: ERT tests for lisp/scs-command-hub.el catalog helpers
;; Author: SCS
;; Copyright: Copyright (C) 2026, SCS, all rights reserved.
;; Created: 2026-07-24 Fri 12:07
;; Version: 0.1.0
;; Last-Updated: 2026-07-24 Fri 12:07
;; Update #: 1

;;; Commentary:
;;
;; Batch run (from repo root):
;;
;;   emacs -batch -L lisp -l ert -l lisp/scs-command-hub.el \
;;     -l test/scs-command-hub-test.el -f ert-run-tests-batch-and-exit

;;; Change Log:
;; Newest first.  File-local so readers need not dig through VCS.
;; add: 2026-07-24 -- catalog accessor and validation ERT

;;; Code:

(require 'ert)
(require 'scs-command-hub)

(ert-deftest scs/command-hub-entry-accessors ()
  "Title, summary, and candidate string come from plist fields."
  (let ((entry '(:name scs/reload-config
                 :title "Reload config"
                 :summary "Reload init.el"
                 :tags (config)
                 :keys "C-c r")))
    (should (eq (scs/command-hub-entry-name entry) 'scs/reload-config))
    (should (equal (scs/command-hub-entry-title entry) "Reload config"))
    (should (equal (scs/command-hub-entry-summary entry) "Reload init.el"))
    (should (string-match-p "Reload config"
                            (scs/command-hub-entry-candidate entry)))
    (should (string-match-p "Reload init.el"
                            (scs/command-hub-entry-candidate entry)))))

(ert-deftest scs/command-hub-find-by-name ()
  "Lookup returns the seeded entry for a known command symbol."
  (let ((entry (scs/command-hub-find-by-name 'scs/reload-config)))
    (should entry)
    (should (equal (scs/command-hub-entry-title entry) "Reload config"))))

(ert-deftest scs/command-hub-validate-entry-rejects-incomplete ()
  "Missing :name or :title is a user-error."
  (should-error (scs/command-hub-validate-entry '(:title "x" :summary "y"))
                :type 'user-error)
  (should-error (scs/command-hub-validate-entry '(:name scs/reload-config))
                :type 'user-error))

(provide 'scs-command-hub-test)
;;; scs-command-hub-test.el ends here
