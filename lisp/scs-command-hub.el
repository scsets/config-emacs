;;; scs-command-hub.el --- Curated command hub (Transient + completing-read)  -*- lexical-binding: t; -*-

;; Filename: scs-command-hub.el
;; Description: C-c ? home base: catalog, workflows, describe
;; Author: SCS
;; Copyright: Copyright (C) 2026, SCS, all rights reserved.
;; Created: 2026-07-24 Fri 12:07
;; Version: 0.1.6
;; Last-Updated: 2026-08-20 Thu 14:19
;; Update #: 7
;; Keywords: convenience, transient, completion
;; Package-Requires: ((emacs "29.1") (transient "0.5"))

;;; Commentary:
;;
;; Problem:
;;   Custom and favorite commands grow faster than memory.  Prefix maps
;;   and which-key help with the next key after a prefix, but not with
;;   "does this command exist?", sticky multi-step workflows, or richer
;;   docs beside a short summary.
;;
;; Solution:
;;   A Transient home on C-c ? over a curated plist catalog.
;;   completing-read (Vertico) browses the catalog; nested Transients
;;   hold small workflows; helpful/describe opens deep docs.  Catalog
;;   data is the source of truth for titles and summaries.  :keys is a
;;   display hint only -- real bindings stay in prefix maps and bind-key.
;;
;; Verify:
;;   C-c ? or C-c / then c -- catalog; RET to run.
;;   Batch: emacs -batch -L lisp -l ert -l lisp/scs-command-hub.el \
;;     -l test/scs-command-hub-test.el -f ert-run-tests-batch-and-exit

;;; Change Log:
;; Newest first.  File-local so readers need not dig through VCS.
;; add: 2026-08-20 -- catalog entry for scs/sort-line-fields
;; add: 2026-08-17 -- catalog entry for scs/sync-emacs-config
;; add: 2026-08-17 -- catalog uses completing-read (Vertico); drop Helm UI
;; add: 2026-07-24 -- require scs-command-hub-helm for catalog UI
;; add: 2026-07-24 -- q quits whole hub stack from every panel
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
     :keys "M-x scs/el-get-report")
    (:name scs/sync-emacs-config
     :title "Sync Emacs config"
     :summary "git pull this repo, prune leftover el-get packages; prefix restarts"
     :tags (config favorite)
     :keys "M-x scs/sync-emacs-config")
    (:name scs/sort-line-fields
     :title "Sort line fields"
     :summary "Sort pipe-separated fields on this line; prefix reverses"
     :tags (edit)
     :keys "M-x scs/sort-line-fields"))
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
  "Return a completion candidate string for ENTRY (title + summary)."
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
;; Catalog presentation (completing-read / Vertico)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defconst scs/command-hub-group-order
  '((favorite . "Favorites")
    (org . "Org / notes")
    (tramp . "TRAMP")
    (frame . "Frames")
    (config . "Config")
    (demo . "Demos")
    (other . "Other"))
  "Alist of (GROUP-SYMBOL . SECTION-HEADER) for catalog sections.")

(defface scs/command-hub-candidate-title
  '((((class color) (min-colors 88) (background light))
     :foreground "#005faf" :weight bold)
    (((class color) (min-colors 88) (background dark))
     :foreground "#7dcfff" :weight bold)
    (t :weight bold))
  "Face for catalog command titles.")

(defface scs/command-hub-candidate-keys
  '((((class color) (min-colors 88) (background light))
     :foreground "#875f00")
    (((class color) (min-colors 88) (background dark))
     :foreground "#e0af68")
    (t :inherit shadow))
  "Face for binding hints in the catalog.")

(defface scs/command-hub-candidate-summary
  '((((class color) (min-colors 88) (background light))
     :foreground "#5f5f5f")
    (((class color) (min-colors 88) (background dark))
     :foreground "#a9b1d6")
    (t :inherit shadow))
  "Face for one-line summaries in the catalog.")

(defun scs/command-hub-entry-keys (entry)
  "Return the display :keys hint for ENTRY, or an empty string."
  (or (scs/command-hub-entry-get entry :keys) ""))

(defun scs/command-hub-entry-group (entry)
  "Return the section symbol for ENTRY.

Favorites win when `:tags' includes `favorite', so starred commands
gather under one header.  Otherwise the first known domain tag wins."
  (let ((tags (scs/command-hub-entry-get entry :tags)))
    (cond
     ((memq 'favorite tags) 'favorite)
     ((memq 'org tags) 'org)
     ((memq 'notes tags) 'org)
     ((memq 'tramp tags) 'tramp)
     ((memq 'frame tags) 'frame)
     ((memq 'config tags) 'config)
     ((or (memq 'demo tags) (memq 'hydra tags)) 'demo)
     ((car tags) (car tags))
     (t 'other))))

(defun scs/command-hub--pad (string width)
  "Pad STRING with spaces on the right to at least WIDTH columns."
  (let* ((string (or string ""))
         (pad (max 0 (- width (string-width string)))))
    (concat string (make-string pad ?\s))))

(defun scs/command-hub--column-widths (entries)
  "Return (TITLE-WIDTH KEYS-WIDTH) for ENTRIES column alignment."
  (list
   (apply #'max 10
          (mapcar (lambda (e)
                    (string-width (or (scs/command-hub-entry-title e) "")))
                  entries))
   (apply #'max 6
          (mapcar (lambda (e)
                    (string-width (scs/command-hub-entry-keys e)))
                  entries))))

(defun scs/command-hub--format-candidate (entry title-width keys-width)
  "Return a colored, column-aligned DISPLAY string for ENTRY."
  (let* ((title (or (scs/command-hub-entry-title entry) "?"))
         (keys (scs/command-hub-entry-keys entry))
         (summary (or (scs/command-hub-entry-summary entry) "")))
    (concat
     (propertize (scs/command-hub--pad title title-width)
                 'face 'scs/command-hub-candidate-title)
     "  "
     (propertize (scs/command-hub--pad keys keys-width)
                 'face 'scs/command-hub-candidate-keys)
     "  "
     (propertize summary 'face 'scs/command-hub-candidate-summary))))

(defun scs/command-hub--group-header (entry)
  "Return the section header string for ENTRY."
  (or (cdr (assq (scs/command-hub-entry-group entry)
                 scs/command-hub-group-order))
      "Other"))

;;;###autoload
(defun scs/command-hub-browse-catalog ()
  "Browse the curated command catalog and run the chosen command.

Uses `completing-read' so Vertico and Orderless own the UI.  RET
runs the command.  Section headers come from catalog :tags."
  (interactive)
  (let* ((entries scs/command-hub-catalog)
         (widths (scs/command-hub--column-widths entries))
         (title-w (nth 0 widths))
         (keys-w (nth 1 widths))
         (table (make-hash-table :test #'equal))
         (cands
          (mapcar (lambda (entry)
                    (let ((s (scs/command-hub--format-candidate
                              entry title-w keys-w)))
                      (puthash s entry table)
                      s))
                  entries))
         (group-fn
          (lambda (cand transform)
            (if transform
                cand
              (scs/command-hub--group-header (gethash cand table)))))
         (choice
          (completing-read
           "Command hub: "
           (lambda (string pred action)
             (if (eq action 'metadata)
                 `(metadata (category . scs-command-hub)
                            (group-function . ,group-fn))
               (complete-with-action action cands string pred)))
           nil t)))
    (when (and choice (not (string= choice "")))
      (scs/command-hub-run-entry
       (or (gethash choice table)
           (user-error "Unknown catalog candidate"))))))

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
    ("u" "Report duplicate org-ids" scs/org-id-report-duplicates)]]
  [["Quit"
    ("q" "Quit hub (all levels)" transient-quit-all)]])

(transient-define-prefix scs/command-hub-workflow-tramp ()
  "TRAMP helpers (same commands as C-c t)."
  [["Remote"
    ("f" "Find file on host" scs/tramp-find-file)
    ("d" "Dired on host" scs/tramp-dired)
    ("c" "Cleanup connections" scs/tramp-cleanup)
    ("r" "Revert / reopen remote buffer" scs/tramp-reopen)]]
  [["Quit"
    ("q" "Quit hub (all levels)" transient-quit-all)]])

(transient-define-prefix scs/command-hub-workflow-frames ()
  "Frame geometry save/restore."
  [["Geometry"
    ("s" "Save frame geometry" scs/frame-state-save)
    ("r" "Restore frame geometry" scs/frame-state-restore)]]
  [["Quit"
    ("q" "Quit hub (all levels)" transient-quit-all)]])

(transient-define-prefix scs/command-hub-workflows ()
  "Sticky workflow panels for related command clusters."
  [["Org / notes"
    ("o" "Org / notes workflows" scs/command-hub-workflow-org)]
   ["TRAMP"
    ("t" "TRAMP workflows" scs/command-hub-workflow-tramp)]
   ["Frames"
    ("f" "Frame geometry workflows" scs/command-hub-workflow-frames)]]
  [["Quit"
    ("q" "Quit hub (all levels)" transient-quit-all)]])

;;;###autoload
(transient-define-prefix scs/command-hub ()
  "SCS command hub home base."
  [["Browse"
    ("c" "Catalog (curated commands)" scs/command-hub-browse-catalog)
    ("d" "Describe command" scs/command-hub-describe-command)]
   ["Workflows"
    ("w" "Workflow panels..." scs/command-hub-workflows)]]
  [["Quit"
    ("q" "Quit hub (all levels)" transient-quit-all)]])

(provide 'scs-command-hub)
;;; scs-command-hub.el ends here
