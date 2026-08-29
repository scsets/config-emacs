;;; scs-startup-state.el --- Curated GUI startup buffers and frame  -*- lexical-binding: t; -*-

;; Filename: scs-startup-state.el
;; Description: GUI-only curated file list + frame-state label at startup
;; Author: SCS
;; Copyright: Copyright (C) 2026, SCS, all rights reserved.
;; Created: 2026-08-04 Tue 18:27
;; Version: 0.1.1
;; Last-Updated: 2026-08-22 Sat 17:51
;; Update #: 1
;; Package-Requires: ((emacs "29.1"))

;;; Commentary:
;;
;; Problem:
;;   desktop-save-mode restores whatever was open last time.  That is
;;   heavy for terminal Emacs and unpredictable for a daily GUI home
;;   screen.  We want a small, explicit list instead.
;;
;; Solution:
;;   On graphic frames only, restore one scs-frame-state label, show
;;   *scratch* in a single window (`delete-other-windows'), and skip the
;;   old left/right file split on normal startup.  Prefix arg to
;;   `scs/startup-state-apply' still opens `scs/startup-state-files' in
;;   the curated split for manual recall.  Terminal Emacs skips this module.
;;
;; How to check:
;;   GUI: M-x scs/startup-state-apply RET (or restart Emacs).
;;   Batch: see test/scs-startup-state-test.el commentary for the
;;   emacs -batch ert command.

;;; Change Log:
;; Newest first.  File-local so readers need not dig through VCS.
;; fix: 2026-08-22 -- scratch-buffer for welcome text; drop initial-scratch-message nil
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
  "Files to open when `scs/startup-state-apply' is called with a prefix arg.

Normal GUI startup shows *scratch* in one window only.  Use
\\[scs/startup-state-apply] with a prefix argument to restore this
curated split: first file left, second right, further files noselect."
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

(defun scs/startup-state--show-scratch-window ()
  "Select *scratch* as the only window in the selected frame.

Uses `scratch-buffer' so `initial-scratch-message' is inserted on a new
buffer, not `get-buffer-create' which leaves *scratch* empty."
  (scratch-buffer)
  (delete-other-windows))

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
unless FORCE is non-nil (interactive prefix argument forces re-apply).

Normal apply: restore frame label when configured, then *scratch* in one
window.  Interactive prefix arg: also open `scs/startup-state-files' in the
legacy left/right split."
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
    (if (and (called-interactively-p 'interactive) force)
        (scs/startup-state--apply-layout
         (scs/startup-state--resolve-files scs/startup-state-files))
      (scs/startup-state--show-scratch-window))
    (setq scs/startup-state--applied t)
    t)))

(defun scs/startup-state--on-frame (frame)
  "Run `scs/startup-state-apply' when FRAME is a live graphic frame."
  (when (and (frame-live-p frame) (display-graphic-p frame))
    (with-selected-frame frame
      (scs/startup-state-apply))))

(defun scs/startup-state--ensure-scratch-solo ()
  "After init finishes, keep the curated GUI layout at one *scratch* window.

Some init hooks run after `window-setup-hook' and can split the frame;
this runs once at the end of startup to collapse back."
  (when (and (display-graphic-p) scs/startup-state--applied)
    (scs/startup-state--show-scratch-window)))

;;;###autoload
(defun scs/startup-state-enable ()
  "Install hooks so curated startup runs once on graphic Emacs."
  (add-hook 'window-setup-hook #'scs/startup-state-apply)
  (add-hook 'emacs-startup-hook #'scs/startup-state--ensure-scratch-solo 999)
  (add-hook 'after-make-frame-functions #'scs/startup-state--on-frame))

(provide 'scs-startup-state)
;;; scs-startup-state.el ends here
