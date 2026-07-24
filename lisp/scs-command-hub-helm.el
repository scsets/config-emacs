;;; scs-command-hub-helm.el --- Nice Helm UI for the command hub catalog  -*- lexical-binding: t; -*-

;; Filename: scs-command-hub-helm.el
;; Description: Sectioned, aligned, colored Helm catalog for scs-command-hub
;; Author: SCS
;; Copyright: Copyright (C) 2026, SCS, all rights reserved.
;; Created: 2026-07-24 Fri 18:05
;; Version: 0.1.0
;; Last-Updated: 2026-07-24 Fri 18:05
;; Update #: 1
;; Keywords: convenience, helm
;; Package-Requires: ((emacs "29.1") (helm "3.0"))

;;; Commentary:
;;
;; Problem:
;;   A flat "title -- summary" Helm list is hard to scan.  Discoverability
;;   wants section headers, aligned columns, and gentle color.
;;
;; Solution:
;;   This file owns only the Helm *presentation* of
;;   `scs/command-hub-catalog'.  Catalog data, Transient portal, and
;;   run/describe helpers stay in `scs-command-hub.el'.
;;
;;   Kept as a separate module so the try/command-hub-hydra experiments
;;   (Hydra, Embark trials, etc.) can be dropped without losing the
;;   catalog UI.  Load order: hub defines the catalog, then this file
;;   is required from the hub (or autoloaded via browse-catalog).
;;
;; Verify:
;;   C-c / then c -- section headers, aligned title/keys/summary.
;;   Batch: emacs -batch -L lisp -l ert -l lisp/scs-command-hub.el \
;;     -l lisp/scs-command-hub-helm.el -l test/scs-command-hub-test.el \
;;     -f ert-run-tests-batch-and-exit

;;; Change Log:
;; Newest first.  File-local so readers need not dig through VCS.
;; add: 2026-07-24 -- extract nice Helm catalog UI for clean trunk land

;;; Code:

(require 'cl-lib)

;; Catalog accessors and run/describe live in the hub module.  Do not
;; (require 'scs-command-hub) here: the hub loads this file at the end
;; of its own body, and a reverse require would recurse.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Section order and faces
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Group order becomes Helm source headers.  Favorites first so the
;; eye lands on the commands people reach for most.
(defconst scs/command-hub-group-order
  '((favorite . "Favorites")
    (org . "Org / notes")
    (tramp . "TRAMP")
    (frame . "Frames")
    (config . "Config")
    (demo . "Demos")
    (other . "Other"))
  "Alist of (GROUP-SYMBOL . HELM-HEADER) for catalog sections.")

(defface scs/command-hub-candidate-title
  '((((class color) (min-colors 88) (background light))
     :foreground "#005faf" :weight bold)
    (((class color) (min-colors 88) (background dark))
     :foreground "#7dcfff" :weight bold)
    (t :weight bold))
  "Face for catalog command titles in the Helm list.")

(defface scs/command-hub-candidate-keys
  '((((class color) (min-colors 88) (background light))
     :foreground "#875f00")
    (((class color) (min-colors 88) (background dark))
     :foreground "#e0af68")
    (t :inherit shadow))
  "Face for binding hints in the Helm catalog.")

(defface scs/command-hub-candidate-summary
  '((((class color) (min-colors 88) (background light))
     :foreground "#5f5f5f")
    (((class color) (min-colors 88) (background dark))
     :foreground "#a9b1d6")
    (t :inherit shadow))
  "Face for one-line summaries in the Helm catalog.")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Grouping and column layout
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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
  "Return a colored, column-aligned Helm DISPLAY string for ENTRY."
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

(defun scs/command-hub--group-entries (entries)
  "Return an alist of (GROUP . ENTRY-LIST) preserving catalog order."
  (let ((table ()))
    (dolist (entry entries)
      (let ((group (scs/command-hub-entry-group entry)))
        (push entry (alist-get group table))))
    (dolist (cell table)
      (setcdr cell (nreverse (cdr cell))))
    table))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Helm sources and browse command
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun scs/command-hub-copy-command-name (entry)
  "Copy ENTRY's command symbol name to the kill ring."
  (let ((name (scs/command-hub-entry-name entry)))
    (kill-new (symbol-name name))
    (message "Copied %s" name)))

(defun scs/command-hub--helm-actions ()
  "Shared Helm actions for every catalog section."
  (helm-make-actions
   "Run" (lambda (entry) (scs/command-hub-run-entry entry))
   "Describe" (lambda (entry)
                (scs/command-hub-describe-command
                 (scs/command-hub-entry-name entry)))
   "Copy command name" #'scs/command-hub-copy-command-name))

(defun scs/command-hub--helm-sources ()
  "Build one Helm source per non-empty catalog section."
  (let* ((entries scs/command-hub-catalog)
         (widths (scs/command-hub--column-widths entries))
         (title-w (nth 0 widths))
         (keys-w (nth 1 widths))
         (grouped (scs/command-hub--group-entries entries))
         (actions (scs/command-hub--helm-actions))
         (known (mapcar #'car scs/command-hub-group-order))
         sources)
    (dolist (cell scs/command-hub-group-order)
      (let* ((group (car cell))
             (header (cdr cell))
             (group-entries (alist-get group grouped)))
        (when group-entries
          (push (helm-build-sync-source header
                  :candidates
                  (mapcar (lambda (entry)
                            (cons (scs/command-hub--format-candidate
                                   entry title-w keys-w)
                                  entry))
                          group-entries)
                  :fuzzy-match t
                  :action actions)
                sources))))
    ;; Any tag not listed in group-order still gets a section.
    (dolist (cell grouped)
      (let ((group (car cell)))
        (unless (memq group known)
          (push (helm-build-sync-source (format "%s" group)
                  :candidates
                  (mapcar (lambda (entry)
                            (cons (scs/command-hub--format-candidate
                                   entry title-w keys-w)
                                  entry))
                          (cdr cell))
                  :fuzzy-match t
                  :action actions)
                sources))))
    (nreverse sources)))

;;;###autoload
(defun scs/command-hub-browse-catalog ()
  "Browse the curated command catalog with Helm and run or describe.

Candidates are grouped under tagged section headers with aligned
title, keys, and summary columns."
  (interactive)
  (require 'helm)
  ;; When this command is autoloaded alone, pull in catalog data.
  (unless (boundp 'scs/command-hub-catalog)
    (require 'scs-command-hub))
  (helm :sources (scs/command-hub--helm-sources)
        :buffer "*helm SCS catalog*"
        :prompt "Command hub: "))

(provide 'scs-command-hub-helm)
;;; scs-command-hub-helm.el ends here
