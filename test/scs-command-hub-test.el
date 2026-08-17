;;; scs-command-hub-test.el --- Tests for command hub catalog  -*- lexical-binding: t; -*-

;; Filename: scs-command-hub-test.el
;; Description: ERT tests for lisp/scs-command-hub.el catalog helpers
;; Author: SCS
;; Copyright: Copyright (C) 2026, SCS, all rights reserved.
;; Created: 2026-07-24 Fri 12:07
;; Version: 0.1.1
;; Last-Updated: 2026-07-24 Fri 18:05
;; Update #: 2

;;; Commentary:
;;
;; Batch run (from repo root):
;;
;;   emacs -batch -L lisp -l ert -l lisp/scs-command-hub.el \
;;     -l test/scs-command-hub-test.el -f ert-run-tests-batch-and-exit

;;; Change Log:
;; Newest first.  File-local so readers need not dig through VCS.
;; add: 2026-07-24 -- group/format ERT for catalog UI
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

(ert-deftest scs/command-hub-entry-group-favorites-first ()
  "Favorite tag wins the section even when domain tags are present."
  (should (eq (scs/command-hub-entry-group
               '(:name x :title "t" :tags (org favorite)))
              'favorite))
  (should (eq (scs/command-hub-entry-group
               '(:name x :title "t" :tags (tramp)))
              'tramp)))

(ert-deftest scs/command-hub-format-candidate-columns ()
  "Formatted candidate keeps title, keys, and summary text."
  (let* ((entry '(:name scs/reload-config
                  :title "Reload config"
                  :summary "Reload init.el"
                  :keys "C-c r"
                  :tags (config favorite)))
         (display (scs/command-hub--format-candidate entry 20 8)))
    (should (string-match-p "Reload config" display))
    (should (string-match-p "C-c r" display))
    (should (string-match-p "Reload init.el" display))))

(provide 'scs-command-hub-test)
;;; scs-command-hub-test.el ends here
