;;; scs-frame-state.el --- Save and restore frame geometry  -*- lexical-binding: t; -*-

;; Author: SCS
;; Keywords: frames, convenience
;; Package-Requires: ((emacs "29.1"))

;;; Commentary:
;;
;; Problem:
;;   desktop.el and session managers save a lot of state.  Here we only need
;;   window size, position, and fullscreen so a laptop/external monitor layout
;;   can be recalled after restart without dragging frames by hand.
;;
;; Solution:
;;   Capture a small alist (left, top, pixel-width, pixel-height, fullscreen),
;;   store labeled entries in var/frame-state.el under user-emacs-directory,
;;   and restore with a fixed order that avoids fullscreen fighting resize.
;;
;; Typical use:
;;   Before quitting: `scs/frame-state-save' with a label like \"1440x900+0+25\".
;;   After restart: `scs/frame-state-restore' and pick a saved label.
;;
;; How to check:
;;   M-x scs/frame-state-capture RET prints the alist in *Messages*.  Save,
;;   restart Emacs, restore; the frame should match within pixel rounding.

;;; Code:

(require 'scs-cl)
(require 'pp)

;;;###autoload
(defgroup scs-frame-state nil
  "Save and restore minimal Emacs frame geometry."
  :group 'frames
  :prefix "scs/frame-state-")

(defcustom scs/frame-state-file
  (expand-file-name "var/frame-state.el" user-emacs-directory)
  "File where `scs/frame-state-save' writes frame geometry.

The file lives under the configuration's var/ directory because it is
generated local state, not source configuration."
  :group 'scs-frame-state
  :type 'file)

(defconst scs/frame-state-keys
  '(left top pixel-width pixel-height fullscreen)
  "Symbol list of alist keys written by `scs/frame-state-capture'.

Keeping this list in one place lets validation and legacy migration stay aligned.")

(defcustom scs/frame-state-default-label "default"
  "Label used when wrapping a legacy single-state file with no stored name."
  :group 'scs-frame-state
  :type 'string)

(defun scs/frame-state--read-file-name (prompt file mustmatch)
  "Read a frame-state FILE name with PROMPT.

When MUSTMATCH is non-nil, require the chosen file to exist."
  (read-file-name prompt
                  (file-name-directory file)
                  file
                  mustmatch
                  (file-name-nondirectory file)))

(defun scs/frame-state--validate (state)
  "Signal `user-error' unless STATE contains the expected geometry keys and types."
  (let ((missing (cl-loop for key in scs/frame-state-keys
                          unless (assq key state)
                          collect key)))
    (when missing
      (user-error "Frame state missing keys: %S" missing)))
  (cl-loop for key in '(left top pixel-width pixel-height)
           for value = (alist-get key state)
           unless (integerp value)
           do (user-error "Frame state %S is not an integer: %S"
                          key value)))

(defun scs/frame-state--state-p (object)
  "Return non-nil when OBJECT looks like one frame geometry alist."
  (and (listp object)
       (cl-every (lambda (key) (assq key object)) scs/frame-state-keys)))

(defun scs/frame-state-label (state)
  "Return a generated label for frame geometry STATE.

The label uses pixel geometry in the usual WIDTHxHEIGHT+LEFT+TOP shape,
with the saved fullscreen value appended when present."
  (scs/frame-state--validate state)
  (let ((label (format "%dx%d%+d%+d"
                       (alist-get 'pixel-width state)
                       (alist-get 'pixel-height state)
                       (alist-get 'left state)
                       (alist-get 'top state)))
        (fullscreen (alist-get 'fullscreen state)))
    (if fullscreen
        (format "%s %s" label fullscreen)
      label)))

(defun scs/frame-state--entry-p (entry)
  "Return non-nil when ENTRY is (LABEL-STRING . STATE-ALIST)."
  (and (consp entry)
       (stringp (car entry))
       (scs/frame-state--state-p (cdr entry))))

(defun scs/frame-state--read-file (file)
  "Return the first Lisp object read from FILE, or nil when FILE is missing."
  (when (file-readable-p file)
    (condition-case nil
        (with-temp-buffer
          (insert-file-contents file)
          (goto-char (point-min))
          (read (current-buffer)))
      (end-of-file nil))))

(defun scs/frame-state--normalize-store (object)
  "Return OBJECT as a labeled frame geometry store.

The current format is an alist of (LABEL . STATE) entries.  A legacy
single STATE alist is accepted and wrapped with a generated label."
  (cond
   ((null object) nil)
   ((scs/frame-state--state-p object)
    ;; Older saves wrote one bare alist; wrap it so load/save paths stay uniform.
    (scs/frame-state--validate object)
    (list (cons (or (scs/frame-state-label object)
                    scs/frame-state-default-label)
                object)))
   ((and (listp object)
         (cl-every #'scs/frame-state--entry-p object))
    (cl-loop for (label . state) in object
             do (scs/frame-state--validate state)
             collect (cons label state)))
   (t (user-error "File does not contain frame geometry entries"))))

(defun scs/frame-state-load-all (&optional file)
  "Read all saved frame geometry entries from FILE.

FILE defaults to `scs/frame-state-file'.  The return value is an alist of
(LABEL . STATE) entries.  Missing files return nil."
  (scs/frame-state--normalize-store
   (scs/frame-state--read-file (or file scs/frame-state-file))))

(defun scs/frame-state--write-all (entries file)
  "Write labeled frame geometry ENTRIES to FILE atomically via with-temp-file."
  (make-directory (file-name-directory file) t)
  (with-temp-file file
    (insert ";;; frame-state.el --- Generated frame geometry -*- mode: emacs-lisp; -*-\n")
    (insert ";;; Generated by `scs/frame-state-save'.  Do not edit by hand.\n\n")
    (let ((print-length nil)
          (print-level nil))
      ;; pp keeps the file human-readable for debugging without print-length truncation.
      (pp entries (current-buffer)))))

(defun scs/frame-state--read-label (prompt entries &optional default)
  "Read a frame geometry label with PROMPT.

ENTRIES provides existing labels for completion.  DEFAULT is used when the
user accepts an empty answer."
  (let* ((answer (completing-read prompt (mapcar #'car entries)
                                  nil nil nil nil default)))
    (if (string= answer "")
        default
      answer)))

(defun scs/frame-state--read-existing-label (prompt entries &optional file)
  "Read an existing frame geometry label with PROMPT from ENTRIES.

Signals if ENTRIES is empty so the caller gets a clear error, not an empty list."
  (unless entries
    (user-error "No saved frame geometries in %s"
                (abbreviate-file-name
                 (or file scs/frame-state-file))))
  (completing-read prompt (mapcar #'car entries) nil t))

;;;###autoload
(defun scs/frame-state-capture (&optional frame)
  "Return minimal geometry state for FRAME.

FRAME defaults to the selected frame.  The return value is an alist with
only these keys: `left', `top', `pixel-width', `pixel-height', and
`fullscreen'."
  (interactive)
  (let* ((frame (or frame (selected-frame)))
         (_ (unless (frame-live-p frame)
              (signal 'wrong-type-argument (list 'live-frame-p frame))))
         (position (frame-position frame))
         (state `((left . ,(car position))
                  (top . ,(cdr position))
                  (pixel-width . ,(frame-pixel-width frame))
                  (pixel-height . ,(frame-pixel-height frame))
                  (fullscreen . ,(frame-parameter frame 'fullscreen)))))
    (when (called-interactively-p 'interactive)
      (message "%S" state))
    state))

;;;###autoload
(defun scs/frame-state-save (&optional label file frame)
  "Capture FRAME geometry and save it under LABEL in FILE.

FRAME defaults to the selected frame.  FILE defaults to
`scs/frame-state-file', normally var/frame-state.el under
`user-emacs-directory'.  LABEL defaults to a generated geometry label
such as \"1440x900+0+25\".

When called interactively, prompt for LABEL.  With a prefix argument,
also prompt for FILE."
  (interactive
   (let* ((file (when current-prefix-arg
                  (scs/frame-state--read-file-name
                   "Save frame geometry file: " scs/frame-state-file nil)))
          (file (or file scs/frame-state-file))
          (entries (scs/frame-state-load-all file))
          (state (scs/frame-state-capture))
          (label (scs/frame-state--read-label
                  "Save frame geometry as: " entries
                  (scs/frame-state-label state))))
     (list label file)))
  (let* ((file (or file scs/frame-state-file))
         (state (scs/frame-state-capture frame))
         (label (or label (scs/frame-state-label state))))
    (unless (stringp label)
      (user-error "Frame geometry label must be a string: %S" label))
    (when (string= label "")
      (user-error "Frame geometry label must not be empty"))
    (let* (;; Same label replaces the previous entry instead of duplicating.
           (entries (cl-remove label (scs/frame-state-load-all file)
                               :key #'car :test #'string=))
           (entries (cons (cons label state) entries)))
      (scs/frame-state--write-all entries file)
      (when (called-interactively-p 'interactive)
        (message "Saved frame geometry %S to %s"
                 label (abbreviate-file-name file)))
      state)))

;;;###autoload
(defun scs/frame-state-load (&optional label file)
  "Read frame geometry LABEL from FILE.

FILE defaults to `scs/frame-state-file'.  When LABEL is nil and there is
more than one saved entry, choose a label with `completing-read'."
  (interactive
   (let* ((file (when current-prefix-arg
                  (scs/frame-state--read-file-name
                   "Load frame geometry file: " scs/frame-state-file t)))
          (file (or file scs/frame-state-file))
          (entries (scs/frame-state-load-all file)))
     (list (scs/frame-state--read-existing-label
            "Load frame geometry: " entries file)
           file)))
  (let* ((file (or file scs/frame-state-file))
         (entries (scs/frame-state-load-all file))
         (label (or label
                    (if (= 1 (length entries))
                        (caar entries)
                      (scs/frame-state--read-existing-label
                       "Load frame geometry: " entries))))
         (state (cdr (assoc label entries))))
    (unless state
      (user-error "No frame geometry labeled %S in %s"
                  label (abbreviate-file-name file)))
    (scs/frame-state--validate state)
    (when (called-interactively-p 'interactive)
      (message "%S: %S" label state))
    state))

;;;###autoload
(defun scs/frame-state-restore (&optional state frame file)
  "Restore FRAME geometry from STATE.

STATE defaults to the contents of `scs/frame-state-file'.  FRAME defaults
to the selected frame.  When called interactively, choose a saved label
with `completing-read'.  With a prefix argument, also prompt for FILE.
The restore order is:

1. clear current fullscreen state;
2. restore left/top position;
3. restore pixel width/height;
4. restore saved fullscreen state, when non-nil."
  (interactive
   (let* ((file (when current-prefix-arg
                  (scs/frame-state--read-file-name
                   "Restore frame geometry file: " scs/frame-state-file t)))
          (file (or file scs/frame-state-file))
          (entries (scs/frame-state-load-all file)))
     (list (scs/frame-state-load
            (scs/frame-state--read-existing-label
             "Restore frame geometry: " entries file)
            file)
           nil
           file)))
  (let* ((state (or state (scs/frame-state-load nil file)))
         (frame (or frame (selected-frame)))
         (_ (unless (frame-live-p frame)
              (signal 'wrong-type-argument (list 'live-frame-p frame))))
         (left (alist-get 'left state))
         (top (alist-get 'top state))
         (pixel-width (alist-get 'pixel-width state))
         (pixel-height (alist-get 'pixel-height state))
         (fullscreen (alist-get 'fullscreen state)))
    (scs/frame-state--validate state)
    ;; Fullscreen first cleared: otherwise set-frame-size often has no visible effect.
    (when (frame-parameter frame 'fullscreen)
      (set-frame-parameter frame 'fullscreen nil))
    (set-frame-position frame left top)
    (set-frame-size frame pixel-width pixel-height t)
    (when fullscreen
      (set-frame-parameter frame 'fullscreen fullscreen))
    (when (called-interactively-p 'interactive)
      (message "Restored frame geometry"))
    frame))

(provide 'scs-frame-state)
;;; scs-frame-state.el ends here
