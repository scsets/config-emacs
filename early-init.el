;;; early-init.el --- Early initialization  -*- lexical-binding: t; no-byte-compile: t; -*-
;;
;; $Id: early-init.el,v 1.1 2026/03/23 07:36:04 scs Exp $
;;
;;; Commentary:
;;  Startup performance tweaks, UI defaults, and package setup.
;;  Loaded before init.el by Emacs 27+.
;;  fix: 2026-07-10 — no-byte-compile cookie; do not leave early-init.elc around
;;
;;; Code:


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Startup performance
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Temporarily increase the garbage collection threshold.  These
;; changes help shave off about half a second of startup time.  The
;; `most-positive-fixnum' is DANGEROUS AS A PERMANENT VALUE.  See the
;; `emacs-startup-hook' a few lines below for what I actually use.
(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.5)

;; Same idea as above for the `file-name-handler-alist' and the
;; `vc-handled-backends' with regard to startup speed optimisation.
;; Here I am storing the default value with the intent of restoring it
;; via the `emacs-startup-hook'.

;; Saved default value of file-name-handler-alist for post-init restore.
(defvar scs--file-name-handler-alist file-name-handler-alist)

;; Saved default value of vc-handled-backends for post-init restore.
(defvar scs--vc-handled-backends vc-handled-backends)

(setq file-name-handler-alist nil
      vc-handled-backends nil)

(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 1024 1024 20)
                  gc-cons-percentage 0.2
                  file-name-handler-alist scs--file-name-handler-alist
                  vc-handled-backends scs--vc-handled-backends)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Warnings and compilation
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(require 'cl-lib)

;; add: 2026-07-10
(defun scs/brew-executable ()
  "Return a usable Homebrew `brew' executable, or nil."
  (or (executable-find "brew")
      (cl-loop for candidate in '("/opt/homebrew/bin/brew"
                                  "/usr/local/bin/brew")
               when (file-executable-p candidate)
               return candidate)))

;; add: 2026-07-10
(defun scs/brew-prefix (package &optional brew)
  "Return Homebrew prefix for PACKAGE using BREW, or nil."
  (when-let* ((brew (or brew (scs/brew-executable)))
              (out (string-trim
                    (shell-command-to-string
                     (format "%s --prefix %s" brew package)))))
    (and (file-directory-p out) out)))

;; fix: 2026-07-10 — portable brew; fewer subprocesses
(defun scs/native-comp-library-paths ()
  "Library dirs Homebrew GCC/libgccjit need for native compilation."
  (let ((brew (scs/brew-executable))
        paths)
    (when brew
      (let ((gcc-prefix (scs/brew-prefix "gcc" brew))
            (jit-prefix (scs/brew-prefix "libgccjit" brew)))
        (dolist (prefix (delq nil (list gcc-prefix jit-prefix)))
          (let ((lib-current (expand-file-name "lib/gcc/current" prefix)))
            (when (file-directory-p lib-current)
              (push lib-current paths))))
        (when gcc-prefix
          (let* ((gcc-current (expand-file-name "lib/gcc/current" gcc-prefix))
                 (arch-dirs (file-expand-wildcards
                             (expand-file-name "gcc/*-apple-darwin*/*"
                                               gcc-current))))
            (when arch-dirs
              (push (expand-file-name (car (sort arch-dirs #'string>))
                                      gcc-current)
                    paths))))))
    (delete-dups (nreverse paths))))

;; add: 2026-07-10
(defun scs/homebrew-gcc-driver (&optional brew)
  "Return the newest Homebrew GCC driver executable, or nil."
  (when-let* ((prefix (scs/brew-prefix "gcc" brew))
              (drivers (file-expand-wildcards
                        (expand-file-name "bin/gcc-[0-9]*" prefix)))
              (drivers (cl-remove-if-not #'file-executable-p drivers)))
    (car (sort drivers #'string>))))

;; fix: 2026-07-10 — dynamic gcc-* instead of hard-coded gcc-16
(defun scs/setup-macos-native-comp ()
  "Set env vars Emacs needs before libgccjit runs (macOS GUI)."
  (when (eq system-type 'darwin)
    (let* ((brew (scs/brew-executable))
           (paths (scs/native-comp-library-paths))
           (gcc (scs/homebrew-gcc-driver brew)))
      (when paths
        (setenv "LIBRARY_PATH" (mapconcat #'identity paths ":")))
      (when gcc
        (setenv "CC" gcc)))))

;; Must run before package-native-compile / libgccjit is invoked.
(scs/setup-macos-native-comp)

(setq warning-minimum-level :emergency)
(setq byte-compile-warnings '(not free-vars obsolete cl-functions lexical))
;; Set this early so every subsequent `load' during startup prefers edited
;; source over stale local bytecode when both are present.  This matters after
;; changing files under lisp/: an old ignored .elc should never shadow a fixed
;; .el during init.
(setq load-prefer-newer t)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Frame / UI
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(setq frame-resize-pixelwise t
      frame-inhibit-implied-resize t
      frame-title-format '("%b")
      ring-bell-function 'ignore
      use-dialog-box t ; only for mouse events, which I seldom use
      use-file-dialog nil
      use-short-answers t
      inhibit-splash-screen t
      inhibit-startup-screen t
      inhibit-x-resources t
      inhibit-startup-echo-area-message user-login-name ; read the docstring
      inhibit-startup-buffer-menu t)

;; I do not use those graphical elements by default, but I do enable
;; them from time-to-time for testing purposes or to demonstrate
;; something.  NEVER tell a beginner to disable any of these.  They
;; are helpful.

;(menu-bar-mode -1)
;(scroll-bar-mode -1)
(when (display-graphic-p) (tool-bar-mode -1))

(when (eq system-type 'darwin)
  (add-to-list 'default-frame-alist '(undecorated-round . t))
  (add-to-list 'default-frame-alist '(font . "Menlo-18"))
  ;; Must be set before window-system init (daemon/emacsclient too).
  (setq mac-command-modifier 'control) ; Command sends Control
  (setq mac-option-modifier 'meta)     ; Option sends Meta
  (setq mac-control-modifier 'super)   ; Control sends Super
  (setq ns-function-modifier 'hyper))  ; Fn (via Karabiner) sends Hyper

(when (display-graphic-p)
  (add-hook 'after-init-hook (lambda () (set-frame-name "home"))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Package setup
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(setq user-emacs-directory (file-name-directory (or load-file-name buffer-file-name)))

(require 'package)
;; Allow archive packages to upgrade bundled dependencies.
(setq package-install-upgrade-built-in t)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(when (string-match "NATIVE_COMP" system-configuration-features)
  (setq package-native-compile t))

(package-initialize)

;;; early-init.el ends here
