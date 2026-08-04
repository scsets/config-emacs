;;; scs-startup-state.el --- Curated GUI startup buffers and frame  -*- lexical-binding: t; -*-

;; Filename: scs-startup-state.el
;; Description: GUI-only curated file list + frame-state label at startup
;; Author: SCS
;; Copyright: Copyright (C) 2026, SCS, all rights reserved.
;; Created: 2026-08-04 Tue 18:27
;; Version: 0.1.0
;; Last-Updated: 2026-08-04 Tue 18:27
;; Update #: 0
;; Package-Requires: ((emacs "29.1"))

;;; Commentary:
;;
;; Problem:
;;   desktop-save-mode restores whatever was open last time.  That is
;;   heavy for terminal Emacs and unpredictable for a daily GUI home
;;   screen.  We want a small, explicit list instead.
;;
;; Solution:
;;   On graphic frames only, restore one scs-frame-state label, visit
;;   `scs/startup-state-files', split left/right for the first two,
;;   and load any further files with find-file-noselect.  Terminal
;;   Emacs skips this module entirely.
;;
;; How to check:
;;   GUI: M-x scs/startup-state-apply RET (or restart Emacs).
;;   Batch: see test/scs-startup-state-test.el commentary for the
;;   emacs -batch ert command.

;;; Change Log:
;; Newest first.  File-local so readers need not dig through VCS.
;; add: 2026-08-04 -- curated GUI startup; desktop-save-mode retired

;;; Code:

(require 'scs-cl)
(require 'scs-frame-state)

(defgroup scs-startup-state nil
  "Curated GUI startup: frame geometry label and file list."
  :group 'frames
  :prefix "scs/startup-state-")

(defcustom scs/startup-state-files
  '("~/notes/progress-todo.org"
    "~/.config/emacs/init.el")
  "Files to open on graphic Emacs startup.

The first existing file is shown on the left; the second on the right.
Further existing entries are loaded with `find-file-noselect' only.
Missing paths are skipped with a message."
  :group 'scs-startup-state
  :type '(repeat file))

(defcustom scs/startup-state-frame-label "2048x1127+0+25"
  "Label in `scs/frame-state-file' restored on graphic startup.

When nil or empty, skip geometry restore.  When the label is missing
from the frame-state store, skip with a message and still open files."
  :group 'scs-startup-state
  :type '(choice (const :tag "None" nil) string))

(defvar scs/startup-state--applied nil
  "Non-nil after a successful GUI startup-state apply in this session.

Daemon/emacsclient can create many graphic frames; we apply the curated
layout once so later clients do not re-split an already arranged frame.")

(defun scs/startup-state--resolve-files (files)
  "Return absolute paths from FILES that exist on disk, in order.

Each entry is expanded with `expand-file-name'.  Missing files are
skipped and reported with `message' so startup can continue."
  (cl-loop for raw in files
           for path = (and (stringp raw) (expand-file-name raw))
           if (and path (file-exists-p path))
           collect path
           else if (stringp raw)
           do (message "scs-startup-state: skip missing file %s" raw)))

(defun scs/startup-state--restore-frame ()
  "Best-effort restore of `scs/startup-state-frame-label'.

Never signals to the caller: missing label or load errors become
`message' lines so init can continue."
  (let ((label scs/startup-state-frame-label))
    (cond
     ((or (null label) (and (stringp label) (string= label "")))
      nil)
     (t
      (condition-case err
          (scs/frame-state-restore
           (scs/frame-state-load label)
           (selected-frame))
        (error
         (message "scs-startup-state: skip frame label %S (%s)"
                  label (error-message-string err))))))))

(defun scs/startup-state--apply-layout (files)
  "Show FILES in the selected frame: left/right for the first two.

FILES must already be resolved existing absolute paths.  Extra entries
are visited with `find-file-noselect' only."
  (when files
    (let ((left (car files))
          (right (cadr files))
          (rest (cddr files)))
      (find-file left)
      (when right
        ;; One vertical split only: first file stays selected on the left.
        (let ((new-win (split-window-right)))
          (with-selected-window new-win
            (find-file right))))
      (dolist (path rest)
        (find-file-noselect path)))))

;;;###autoload
(defun scs/startup-state-apply (&optional force)
  "Apply curated GUI startup state to the selected frame.

No-op on non-graphic frames.  No-op if already applied in this session
unless FORCE is non-nil (interactive prefix argument forces re-apply)."
  (interactive "P")
  (cond
   ((not (display-graphic-p))
    (when (called-interactively-p 'interactive)
      (user-error "scs-startup-state applies only on graphic frames"))
    nil)
   ((and scs/startup-state--applied (not force))
    nil)
   (t
    (scs/startup-state--restore-frame)
    (scs/startup-state--apply-layout
     (scs/startup-state--resolve-files scs/startup-state-files))
    (setq scs/startup-state--applied t)
    t)))

(defun scs/startup-state--on-frame (frame)
  "Run `scs/startup-state-apply' when FRAME is a live graphic frame."
  (when (and (frame-live-p frame) (display-graphic-p frame))
    (with-selected-frame frame
      (scs/startup-state-apply))))

;;;###autoload
(defun scs/startup-state-enable ()
  "Install hooks so curated startup runs once on graphic Emacs."
  (add-hook 'window-setup-hook #'scs/startup-state-apply)
  (add-hook 'after-make-frame-functions #'scs/startup-state--on-frame))

(provide 'scs-startup-state)
;;; scs-startup-state.el ends here
