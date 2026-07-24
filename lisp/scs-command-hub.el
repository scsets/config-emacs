;;; scs-command-hub.el --- Curated command hub (Transient + Helm)  -*- lexical-binding: t; -*-

;; Filename: scs-command-hub.el
;; Description: C-c ? home base: catalog, workflows, describe
;; Author: SCS
;; Copyright: Copyright (C) 2026, SCS, all rights reserved.
;; Created: 2026-07-24 Fri 12:07
;; Version: 0.1.1
;; Last-Updated: 2026-07-24 Fri 13:22
;; Update #: 2
;; Keywords: convenience, helm, transient
;; Package-Requires: ((emacs "29.1") (transient "0.5") (helm "3.0"))

;;; Commentary:
;;
;; Problem:
;;   Custom and favorite commands grow faster than memory.  Prefix maps
;;   and which-key help with the next key after a prefix, but not with
;;   "does this command exist?", sticky multi-step workflows, or richer
;;   docs beside a short summary.
;;
;; Solution:
;;   A Transient home on C-c ? over a curated plist catalog.  Helm
;;   browses the catalog; nested Transients hold small workflows;
;;   helpful/describe opens deep docs.  Catalog data is the source of
;;   truth for titles and summaries.  :keys is a display hint only --
;;   real bindings stay in prefix maps and bind-key.
;;
;; Verify:
;;   C-c ? or C-c / then c -- search a seeded title and RET to run.
;;   Batch: emacs -batch -L lisp -l ert -l lisp/scs-command-hub.el \
;;     -l test/scs-command-hub-test.el -f ert-run-tests-batch-and-exit

;;; Change Log:
;; Newest first.  File-local so readers need not dig through VCS.
;; add: 2026-07-24 -- C-c / twin binding (documented in Commentary)
;; add: 2026-07-24 -- catalog, Helm browse, Transient home, workflows

;;; Code:

(require 'cl-lib)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Catalog data
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defconst scs/command-hub-catalog
  '((:name scs/reload-config
     :title "Reload config"
     :summary "Reload init.el; prefix also re-applies early-init runtime bits"
     :tags (config favorite)
     :keys "C-c r")
    (:name scs/frame-state-save
     :title "Save frame geometry"
     :summary "Store the selected frame size/position under a label"
     :tags (frame favorite)
     :keys "M-x scs/frame-state-save")
    (:name scs/frame-state-restore
     :title "Restore frame geometry"
     :summary "Reload a labeled frame size/position from var/frame-state.el"
     :tags (frame favorite)
     :keys "M-x scs/frame-state-restore")
    (:name scs/tramp-find-file
     :title "TRAMP find file"
     :summary "Find a file on a known SSH host"
     :tags (tramp favorite)
     :keys "C-c t f")
    (:name scs/tramp-dired
     :title "TRAMP dired"
     :summary "Open dired on a known SSH host"
     :tags (tramp)
     :keys "C-c t d")
    (:name scs/tramp-cleanup
     :title "TRAMP cleanup"
     :summary "Clean up TRAMP connections"
     :tags (tramp)
     :keys "C-c t c")
    (:name scs/tramp-reopen
     :title "TRAMP reopen"
     :summary "Revert the current remote buffer from the host"
     :tags (tramp)
     :keys "C-c t r")
    (:name scs/org-id-rebuild
     :title "Rebuild Org IDs"
     :summary "Full org-id rescan after external note moves"
     :tags (org notes)
     :keys "M-x scs/org-id-rebuild")
    (:name scs/org-id-report-duplicates
     :title "Report duplicate Org IDs"
     :summary "List duplicate id: values under notes"
     :tags (org notes)
     :keys "M-x scs/org-id-report-duplicates")
    (:name scs/org-insert-creation-date
     :title "Insert Org creation date"
     :summary "Insert a creation-date stamp for the current Org note"
     :tags (org notes favorite)
     :keys "H-c d")
    (:name scs/el-get-report
     :title "el-get report"
     :summary "Show package name, source, and installed revision"
     :tags (config)
     :keys "M-x scs/el-get-report"))
  "Curated command catalog for the SCS command hub.

Each entry is a plist with :name, :title, :summary, and optional
:tags and :keys.  :keys is a display hint only; prefix maps and
bind-key remain authoritative for real bindings.

Grow this list when a command is forgotten once -- that is the signal
it belongs here.")

(defun scs/command-hub-entry-get (entry key)
  "Return KEY from catalog ENTRY plist."
  (plist-get entry key))

(defun scs/command-hub-entry-name (entry)
  "Return the command symbol for ENTRY."
  (scs/command-hub-entry-get entry :name))

(defun scs/command-hub-entry-title (entry)
  "Return the short title for ENTRY."
  (scs/command-hub-entry-get entry :title))

(defun scs/command-hub-entry-summary (entry)
  "Return the one-line summary for ENTRY."
  (scs/command-hub-entry-get entry :summary))

(defun scs/command-hub-entry-candidate (entry)
  "Return a Helm candidate string for ENTRY (title + summary)."
  (format "%s -- %s"
          (or (scs/command-hub-entry-title entry) "?")
          (or (scs/command-hub-entry-summary entry) "")))

(defun scs/command-hub-find-by-name (name)
  "Return the catalog entry whose :name is NAME, or nil."
  (cl-find name scs/command-hub-catalog
           :key #'scs/command-hub-entry-name :test #'eq))

(defun scs/command-hub-validate-entry (entry)
  "Return ENTRY if it has :name and :title; else signal `user-error'."
  (unless (and (plist-get entry :name) (plist-get entry :title))
    (user-error "Catalog entry needs :name and :title: %S" entry))
  entry)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Describe and run
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun scs/command-hub-describe-command (command)
  "Describe COMMAND with helpful when available, else `describe-function'."
  (interactive
   (list (intern-soft
          (completing-read "Describe command: " obarray #'commandp t))))
  (unless (and command (commandp command))
    (user-error "Not a command: %S" command))
  (cond
   ((fboundp 'helpful-command) (helpful-command command))
   ((fboundp 'helpful-callable) (helpful-callable command))
   (t (describe-function command))))

(defun scs/command-hub-run-entry (entry)
  "Call the interactive command named by ENTRY."
  (let ((name (scs/command-hub-entry-name entry)))
    (unless (and name (commandp name))
      (user-error "Catalog :name is not an interactive command: %S" name))
    (call-interactively name)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Helm catalog
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun scs/command-hub--helm-candidates ()
  "Build Helm candidate alist (DISPLAY . ENTRY) from the catalog."
  (mapcar (lambda (entry)
            (cons (scs/command-hub-entry-candidate entry) entry))
          scs/command-hub-catalog))

;;;###autoload
(defun scs/command-hub-browse-catalog ()
  "Browse the curated command catalog with Helm and run or describe."
  (interactive)
  (require 'helm)
  (helm :sources
        (helm-build-sync-source "SCS command catalog"
          :candidates #'scs/command-hub--helm-candidates
          :fuzzy-match t
          :action
          (helm-make-actions
           "Run" (lambda (entry) (scs/command-hub-run-entry entry))
           "Describe" (lambda (entry)
                        (scs/command-hub-describe-command
                         (scs/command-hub-entry-name entry)))))
        :buffer "*helm SCS catalog*"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Transient workflows
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(require 'transient)

(transient-define-prefix scs/command-hub-workflow-org ()
  "Org and notes helpers."
  [["Dates"
    ("d" "Insert creation date" scs/org-insert-creation-date)]
   ["Org ID"
    ("r" "Rebuild org-id locations" scs/org-id-rebuild)
    ("u" "Report duplicate org-ids" scs/org-id-report-duplicates)]])

(transient-define-prefix scs/command-hub-workflow-tramp ()
  "TRAMP helpers (same commands as C-c t)."
  [["Remote"
    ("f" "Find file on host" scs/tramp-find-file)
    ("d" "Dired on host" scs/tramp-dired)
    ("c" "Cleanup connections" scs/tramp-cleanup)
    ("r" "Revert / reopen remote buffer" scs/tramp-reopen)]])

(transient-define-prefix scs/command-hub-workflow-frames ()
  "Frame geometry save/restore."
  [["Geometry"
    ("s" "Save frame geometry" scs/frame-state-save)
    ("r" "Restore frame geometry" scs/frame-state-restore)]])

(transient-define-prefix scs/command-hub-workflows ()
  "Sticky workflow panels for related command clusters."
  [["Org / notes"
    ("o" "Org / notes workflows" scs/command-hub-workflow-org)]
   ["TRAMP"
    ("t" "TRAMP workflows" scs/command-hub-workflow-tramp)]
   ["Frames"
    ("f" "Frame geometry workflows" scs/command-hub-workflow-frames)]])

;;;###autoload
(transient-define-prefix scs/command-hub ()
  "SCS command hub home base."
  [["Browse"
    ("c" "Catalog (curated commands)" scs/command-hub-browse-catalog)
    ("d" "Describe command" scs/command-hub-describe-command)]
   ["Workflows"
    ("w" "Workflow panels..." scs/command-hub-workflows)]])

(provide 'scs-command-hub)
;;; scs-command-hub.el ends here
