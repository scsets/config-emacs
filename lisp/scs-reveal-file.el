;;; scs-reveal-file.el --- Reveal the current file in the OS or Dired  -*- lexical-binding: t; -*-

;; Filename: scs-reveal-file.el
;; Description: Reveal a visited file in Finder or Dired; copy absolute path
;; Author: SCS
;; Copyright: Copyright (C) 2026, SCS, all rights reserved.
;; Created: 2026-08-29 Sat 15:00
;; Version: 0.1.0
;; Last-Updated: 2026-08-29 Sat 15:00
;; Update #: 0
;; Keywords: convenience, files, dired
;; Package-Requires: ((emacs "29.1"))

;;; Commentary:
;;
;; Problem
;; -------
;; Jumping from an Emacs buffer to the file in the desktop file manager is
;; useful on GUI frames, but terminal Emacs cannot launch Finder sensibly.
;; Remote (TRAMP) paths need Dired even on macOS.  The path should land on
;; the kill ring and, when the platform allows, the system clipboard too.
;;
;; Solution
;; --------
;; `scs/reveal-file' resolves the file for the current buffer (or Dired line),
;; checks that it exists, copies its absolute path, then either:
;;
;; - TTY frame or TRAMP path: open Dired on the containing directory with
;;   point on the file (`dired' with a (DIR . FILES) argument).
;; - GUI local path: reveal in the OS file navigator (Finder on macOS,
;;   Explorer on Windows, FileManager1 D-Bus or common tools on GNU/Linux).
;;
;; Keys (after init wires the autoload)
;; ------------------------------------
;;   C-c M-v    `scs/reveal-file'
;;
;; Documented helpers used
;; -----------------------
;; `buffer-file-name', `dired-get-filename', `expand-file-name',
;; `file-exists-p', `file-remote-p', `file-name-directory',
;; `file-name-nondirectory', `directory-file-name', `display-graphic-p',
;; `call-process', `kill-new', `dired', `dbus-call-method', `url-hexify-string'.
;;
;; How to check
;; ------------
;;   M-x scs/reveal-file RET     ; GUI: Finder highlights the file
;;   emacs -nw ...               ; same command opens Dired on the file
;;   emacs -Q --batch -L lisp -l ert -l test/scs-reveal-file-test.el \
;;     -f ert-run-tests-batch-and-exit

;;; Change Log:
;; Newest first.  File-local so readers need not dig through VCS.
;; add: 2026-08-29 -- scs/reveal-file: OS reveal, TTY Dired, copy path

;;; Code:

(require 'subr-x)

(declare-function dired-get-filename "dired" (&optional localp no-error-if-not-filep))
(declare-function dbus-call-method "dbus"
                  (&rest args))
(declare-function url-hexify-string "url" (string &optional allow-chars))

(defvar url-unreserved-chars)

(defgroup scs-reveal-file nil
  "Reveal the current file in the OS file manager or in Dired.

Interactive entry point: `scs/reveal-file'.  Related symbols use the
`scs/reveal-file-' prefix."
  :group 'files
  :prefix "scs/reveal-file-")


;;; Path resolution and clipboard

(defun scs/reveal-file--target ()
  "Return the absolute, existing file path for the current context.

Uses `buffer-file-name' in a file-visiting buffer.  In Dired, uses the
file name on the current line.  Signals `user-error' when there is no
file or it does not exist."
  (let ((raw
         (cond
          (buffer-file-name buffer-file-name)
          ((derived-mode-p 'dired-mode)
           (require 'dired)
           (dired-get-filename nil t))
          (t nil))))
    (unless raw
      (user-error "Current buffer is not visiting a file"))
    (let ((abs (expand-file-name raw)))
      (unless (file-exists-p abs)
        (user-error "File does not exist: %s" abs))
      abs)))

(defun scs/reveal-file--copy-path (path)
  "Put absolute PATH on the kill ring and system clipboard when configured.

Uses `kill-new', which calls `interprogram-cut-function' when
`select-enable-clipboard' is non-nil.  Returns PATH."
  (kill-new path)
  path)

(defun scs/reveal-file--use-dired-p (path)
  "Return non-nil when PATH should be opened in Dired instead of the OS UI.

Terminal frames have no desktop file manager to reveal into.  TRAMP paths
are not meaningful for Finder, Explorer, or xdg-open selection APIs."
  (or (not (display-graphic-p))
      (file-remote-p path)))


;;; Dired and OS backends

(defun scs/reveal-file--open-dired (path)
  "Open Dired on the directory of PATH with point on PATH."
  (require 'dired)
  (let ((dir (file-name-as-directory (file-name-directory path)))
        (base (file-name-nondirectory path)))
    (dired (cons (directory-file-name dir) (list base)))))

(defun scs/reveal-file--file-uri (path)
  "Return a file:// URI string for local absolute PATH."
  (concat "file://" (url-hexify-string path url-unreserved-chars)))

(defun scs/reveal-file--reveal-linux (path)
  "Reveal PATH in a GNU/Linux file manager, best effort.

Try the freedesktop FileManager1 D-Bus ShowItems API first.  Fall back to
a short list of CLI tools, then open the parent directory with xdg-open."
  (let ((uri (scs/reveal-file--file-uri path))
        (dir (file-name-directory path)))
    (unless
        (or (and (require 'dbus nil t)
                 (ignore-errors
                   (dbus-call-method
                    :session "org.freedesktop.FileManager1"
                    "/org/freedesktop/FileManager1"
                    "org.freedesktop.FileManager1" "ShowItems"
                    (list (vector uri)) "")))
            (when (executable-find "nautilus")
              (call-process "nautilus" nil 0 nil "--select" path)
              t)
            (when (executable-find "dolphin")
              (call-process "dolphin" nil 0 nil "--select" path)
              t)
            (when (executable-find "thunar")
              (call-process "thunar" nil 0 nil path)
              t)
            (when (executable-find "xdg-open")
              (call-process "xdg-open" nil 0 nil dir)
              t))
      (user-error "No file manager found to reveal %s" path))))

(defun scs/reveal-file--reveal-in-os (path)
  "Reveal local PATH in the platform file navigator."
  (pcase system-type
    ('darwin
     (call-process "/usr/bin/open" nil 0 nil "-R" path))
    ('windows-nt
     (call-process "explorer" nil 0 nil (concat "/select," path)))
    ((or 'gnu/linux 'linux)
     (scs/reveal-file--reveal-linux path))
    (_
     (when (executable-find "xdg-open")
       (call-process "xdg-open" nil 0 nil (file-name-directory path))
       (message "Opened directory for %s (no OS-specific reveal on %s)"
                path system-type)
       t)
     (unless (executable-find "xdg-open")
       (user-error "No file manager found to reveal %s on %s"
                   path system-type)))))


;;; Command

;;;###autoload
(defun scs/reveal-file ()
  "Reveal the current file and copy its absolute path.

When the frame is a TTY, or the path is remote (TRAMP), open Dired on
the file.  Otherwise reveal it in the OS file navigator (Finder on macOS).

The absolute path is always placed on the kill ring and, when Emacs is
configured for it, the system clipboard."
  (interactive)
  (let ((path (scs/reveal-file--target)))
    (scs/reveal-file--copy-path path)
    (if (scs/reveal-file--use-dired-p path)
        (progn
          (scs/reveal-file--open-dired path)
          (message "Copied and opened Dired on: %s" path))
      (scs/reveal-file--reveal-in-os path)
      (message "Copied and revealed: %s" path))))

(provide 'scs-reveal-file)

;;; scs-reveal-file.el ends here
