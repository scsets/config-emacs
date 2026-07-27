;;; scs-org-capture-test.el --- Tests for focused Org capture policy  -*- lexical-binding: t; -*-

;; Filename: scs-org-capture-test.el
;; Description: ERT tests for lisp/scs-org-capture.el
;; Author: SCS
;; Copyright: Copyright (C) 2026, SCS, all rights reserved.
;; Created: 2026-07-27 Mon 07:54
;; Version: 0.1.0
;; Last-Updated: 2026-07-27 Mon 07:58
;; Update #: 0

;;; Commentary:
;;
;; Run from the repository root:
;;
;;   bin/test run
;;
;; Tests redirect every target to a fresh temporary directory.  They verify
;; both the configured data records and real Org capture/finalize behavior;
;; no entry reaches the live notes tree.

;;; Change Log:
;; Newest first.  File-local so readers need not dig through VCS.
;; add: 2026-07-27 -- verify policy data and all four capture destinations

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'org-protocol)
(require 'scs-org-capture)

(defun scs-org-capture-test--write-file (file body)
  "Create FILE containing BODY for an isolated capture test."
  (with-temp-file file
    (insert body)))

(defun scs-org-capture-test--contents (file)
  "Return the complete contents of FILE."
  (with-temp-buffer
    (insert-file-contents file)
    (buffer-string)))

(defun scs-org-capture-test--capture-string (body key answer)
  "Capture BODY with template KEY, answering string prompts with ANSWER."
  (cl-letf (((symbol-function 'org-completing-read)
             (lambda (&rest _) answer)))
    (org-capture-string body key)
    (org-capture-finalize)))

(ert-deftest scs/org-capture-configure-installs-focused-policy ()
  "Configuration owns four templates and preserves existing agenda files."
  (let* ((dir (make-temp-file "scs-org-capture-policy-" t))
         (scs/org-capture-inbox-file (expand-file-name "inbox.org" dir))
         (scs/org-capture-todo-file (expand-file-name "todo.org" dir))
         (scs/org-capture-work-log-file (expand-file-name "work-log.org" dir))
         (org-agenda-files '("/existing/agenda.org"))
         org-capture-templates
         org-default-notes-file
         org-protocol-default-template-key)
    (unwind-protect
        (progn
          (scs/org-capture-configure)
          ;; A reload must not duplicate the TODO agenda file.
          (scs/org-capture-configure)
          (should (equal (mapcar #'car org-capture-templates)
                         '("i" "t" "w" "l")))
          (should (equal org-default-notes-file
                         scs/org-capture-inbox-file))
          (should (equal org-protocol-default-template-key "w"))
          (should (equal org-agenda-files
                         (list scs/org-capture-todo-file
                               "/existing/agenda.org")))
          (should
           (equal (nth 3 (assoc "t" org-capture-templates))
                  `(file+headline ,scs/org-capture-todo-file "TO BE DONE")))
          (should
           (equal (nth 3 (assoc "l" org-capture-templates))
                  `(file+olp+datetree
                    ,scs/org-capture-work-log-file "Log"))))
      (delete-directory dir t))))

(ert-deftest scs/org-capture-templates-write-intended-entry-shapes ()
  "Finalize inbox, task, web, and work-log entries under their targets."
  (let* ((dir (make-temp-file "scs-org-capture-write-" t))
         (scs/org-capture-inbox-file (expand-file-name "inbox.org" dir))
         (scs/org-capture-todo-file (expand-file-name "todo.org" dir))
         (scs/org-capture-work-log-file (expand-file-name "work-log.org" dir))
         (org-agenda-files nil)
         (org-stored-links nil)
         org-capture-templates
         org-default-notes-file
         org-protocol-default-template-key)
    (unwind-protect
        (progn
          (scs-org-capture-test--write-file
           scs/org-capture-inbox-file
           "* Inbox\n\n* Web captures\n")
          (scs-org-capture-test--write-file
           scs/org-capture-todo-file
           "* TO BE DONE\n")
          (scs-org-capture-test--write-file
           scs/org-capture-work-log-file
           "* Log\n")
          (scs/org-capture-configure)

          (scs-org-capture-test--capture-string
           "An unclassified observation." "i" "Inbox thought")
          (scs-org-capture-test--capture-string
           "Completion means the check passes." "t" "Run the check")
          (scs-org-capture-test--capture-string
           "The operation completed normally." "l" "Logged operation")

          ;; Exercise the same Org Protocol path used by Scrim and Captee.
          (org-protocol-capture
           '(:url "https://example.com/reference"
             :title "Reference title"
             :body "Quoted web body."))
          (org-capture-finalize)

          (let ((inbox (scs-org-capture-test--contents
                        scs/org-capture-inbox-file))
                (todo (scs-org-capture-test--contents
                       scs/org-capture-todo-file))
                (log (scs-org-capture-test--contents
                      scs/org-capture-work-log-file)))
            (should (string-match-p
                     "\\*\\* Inbox thought\\(?:.\\|\n\\)*An unclassified observation\\."
                     inbox))
            (should (string-match-p
                     "\\*\\* Reference title\\(?:.\\|\n\\)*\\[\\[https://example\\.com/reference\\]\\[Reference title\\]\\]\\(?:.\\|\n\\)*Quoted web body\\."
                     inbox))
            (should (string-match-p
                     "\\*\\* TODO Run the check\\(?:.\\|\n\\)*Completion means the check passes\\."
                     todo))
            (should (string-match-p
                     "\\*+ [0-9][0-9]:[0-9][0-9] Logged operation\\(?:.\\|\n\\)*The operation completed normally\\."
                     log))
            (dolist (contents (list inbox todo log))
              (should (string-match-p ":CREATED: \\[" contents)))))
      (dolist (buffer (buffer-list))
        (with-current-buffer buffer
          (when (bound-and-true-p org-capture-mode)
            (org-capture-kill))))
      (delete-directory dir t))))

(provide 'scs-org-capture-test)

;;; scs-org-capture-test.el ends here
