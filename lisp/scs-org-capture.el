;;; scs-org-capture.el --- Focused Org capture policy  -*- lexical-binding: t; -*-

;; Filename: scs-org-capture.el
;; Description: Capture templates for inbox, tasks, web material, and work logs
;; Author: SCS
;; Copyright: Copyright (C) 2026, SCS, all rights reserved.
;; Created: 2026-07-27 Mon 07:54
;; Version: 0.1.0
;; Last-Updated: 2026-07-27 Mon 07:58
;; Update #: 0
;; Keywords: outlines, convenience
;; Package-Requires: ((emacs "29.1") (org "9.8"))

;;; Commentary:
;;
;; This library gives quick capture a deliberately narrower role than howm:
;;
;;   i  an unclassified thought for later review
;;   t  an actionable item in the canonical TODO file
;;   w  a link or text clipping received through Org Protocol
;;   l  evidence or an outcome recorded in a chronological work log
;;
;; Standalone, developed knowledge still belongs in a howm note.  Keeping
;; capture to four destinations avoids asking for a filing decision while the
;; user is trying to preserve a thought.
;;
;; `scs/org-capture-configure' owns `org-capture-templates' and makes the web
;; template Org Protocol's default.  It preserves any existing agenda files
;; while adding the canonical TODO file once.
;;
;; Capture remains transactional: `C-c C-c' commits, `C-c C-k' aborts, and
;; `C-c C-w' refiles.  None of these templates uses `:immediate-finish', so a
;; capture can be corrected before it reaches the durable target.

;;; Change Log:
;; Newest first.  File-local so readers need not dig through VCS.
;; add: 2026-07-27 -- define focused inbox, task, web, and work-log captures

;;; Code:

(require 'org-capture)

(defgroup scs-org-capture nil
  "SCS policy for capturing small Org entries."
  :group 'org-capture
  :prefix "scs/org-capture-")

(defcustom scs/org-capture-inbox-file
  (expand-file-name "~/notes/inbox.org")
  "Org file that receives unclassified and web captures."
  :type 'file
  :group 'scs-org-capture)

(defcustom scs/org-capture-todo-file
  (expand-file-name "~/notes/todo.org")
  "Org file containing the canonical TO BE DONE task tree."
  :type 'file
  :group 'scs-org-capture)

(defcustom scs/org-capture-work-log-file
  (expand-file-name "~/notes/work-log.org")
  "Org file containing chronological records of completed work."
  :type 'file
  :group 'scs-org-capture)

(defvar org-protocol-default-template-key)

(defun scs/org-capture-configure ()
  "Install the SCS capture templates and return their definitions.

The resulting `org-capture-templates' data has four records:

  i  Inbox entry under \"Inbox\".
  t  TODO entry under \"TO BE DONE\".
  w  Org Protocol entry under \"Web captures\".
  l  Work-log entry under a date tree rooted at \"Log\".

Set `org-default-notes-file' to the inbox, add the TODO file to
`org-agenda-files', and make \"w\" the Org Protocol fallback key.
Existing agenda files are preserved.  Repeated calls are idempotent."
  (setq org-default-notes-file scs/org-capture-inbox-file)
  (add-to-list 'org-agenda-files scs/org-capture-todo-file)
  (setq org-protocol-default-template-key "w")
  (setq org-capture-templates
        `(("i" "Inbox" entry
           (file+headline ,scs/org-capture-inbox-file "Inbox")
           "* %^{Title}\n:PROPERTIES:\n:CREATED: %U\n:END:\n%i\n%?"
           :prepend t
           :empty-lines 1
           :kill-buffer t)
          ("t" "Task" entry
           (file+headline ,scs/org-capture-todo-file "TO BE DONE")
           "* TODO %^{Task}\n:PROPERTIES:\n:CREATED: %U\n:END:\n%a\n%i\n%?"
           :prepend t
           :empty-lines 1
           :kill-buffer t)
          ("w" "Web capture" entry
           (file+headline ,scs/org-capture-inbox-file "Web captures")
           "* %:description\n:PROPERTIES:\n:CREATED: %U\n:END:\n%:annotation\n\n%i\n%?"
           :prepend t
           :empty-lines 1
           :kill-buffer t)
          ("l" "Work log" entry
           (file+olp+datetree ,scs/org-capture-work-log-file "Log")
           "* %<%H:%M> %^{Summary}\n:PROPERTIES:\n:CREATED: %U\n:END:\n%a\n%i\n%?"
           :prepend t
           :empty-lines 1
           :kill-buffer t)))
  org-capture-templates)

(provide 'scs-org-capture)

;;; scs-org-capture.el ends here
