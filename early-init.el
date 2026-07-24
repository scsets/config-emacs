;;; early-init.el --- Early Emacs initialization  -*- lexical-binding: t; no-byte-compile: t; -*-
;;
;; $Id: early-init.el,v 1.1 2026/03/23 07:36:04 scs Exp $
;;
;; Filename: early-init.el
;; Description: Performance, UI, packages, and macOS native-comp setup before init.el.
;; Author: SCS
;; Copyright: Copyright (C) 2026, SCS, all rights reserved.
;;
;;; Commentary:
;;
;; Emacs 27 and later load this file automatically *before* init.el.  Think of
;; it as the "bootstrap" phase: things here run while Emacs is still waking up,
;; so we can defer expensive work and set environment variables that must exist
;; before libraries like libgccjit load.
;;
;; What lives here (in order):
;;   - Temporary GC and handler tweaks for faster startup, restored on
;;     emacs-startup-hook
;;   - Homebrew paths for native compilation on macOS (LIBRARY_PATH, CC)
;;   - Quiet warnings during normal startup (use bin/emacs-diagnostic to debug)
;;   - Frame defaults, macOS modifier remapping, package.el archives
;;
;; The no-byte-compile cookie is intentional: do not leave early-init.elc in
;; the tree; stale bytecode here is painful to diagnose.
;;
;;; Change Log:
;;
;; Newest first.  File-local so readers need not dig through VCS.
;;
;; fix: 2026-07-24 -- teachable Commentary for SCS team
;; fix: 2026-07-10 -- Homebrew GCC discovery; no-byte-compile; scs-cl load path notes as relevant
;; fix: 2026-07-09 -- load-prefer-newer; startup hygiene
;; add: 2026-07-08 -- Homebrew native-comp paths; macOS modifiers; server launchers support
;; fix: 2026-04-30 -- package archive safeguards
;; add: 2026-03-23 -- initial early-init
;;
;;; Code:


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Startup performance
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; During init, Emacs allocates and throws away a lot of short-lived Lisp
;; objects.  Raising gc-cons-threshold briefly reduces how often GC runs in
;; that window (often shaving noticeable time off startup).  We restore sane
;; values on emacs-startup-hook below -- leaving most-positive-fixnum in place
;; forever would let heap growth get out of hand.
(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.5)

;; file-name-handler-alist and vc-handled-backends add hooks around file I/O
;; and version control.  Disabling them for init avoids extra work on every
;; path operation while packages load.  Save the defaults first so we can put
;; them back once startup finishes.

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

;; Portable Common Lisp helpers (cl-lib and friends) live in lisp/scs-cl.el.
(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))
(require 'scs-cl)

(defun scs/brew-executable ()
  "Return a usable Homebrew `brew' executable, or nil.

Homebrew installs to /opt/homebrew on Apple Silicon and /usr/local on Intel.
`executable-find' respects PATH; the fallback list covers GUI Emacs launches
where PATH is often minimal."
  (or (executable-find "brew")
      (cl-loop for candidate in '("/opt/homebrew/bin/brew"
                                  "/usr/local/bin/brew")
               when (file-executable-p candidate)
               return candidate)))

(defun scs/brew-prefix (package &optional brew)
  "Return Homebrew installation prefix for PACKAGE, or nil.

Uses BREW when given; otherwise `scs/brew-executable'.  Prefix paths feed
native-comp library discovery (gcc, libgccjit)."
  (when-let* ((brew (or brew (scs/brew-executable)))
              (out (string-trim
                    (shell-command-to-string
                     (format "%s --prefix %s" brew package)))))
    (and (file-directory-p out) out)))

(defun scs/native-comp-library-paths ()
  "Return list of directories for LIBRARY_PATH before libgccjit runs.

Emacs native compilation on macOS expects Homebrew GCC and libgccjit layout:
lib/gcc/current, plus the newest arch-specific gcc/*-apple-darwin* subtree.
Returns nil when Homebrew or those packages are absent (native comp may still
work with system tools, or fail with a clear error)."
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
              ;; Prefer the lexicographically greatest dir name (newest gcc-N).
              (push (expand-file-name (car (sort arch-dirs #'string>))
                                      gcc-current)
                    paths))))))
    (delete-dups (nreverse paths))))

(defun scs/homebrew-gcc-driver (&optional brew)
  "Return the newest Homebrew `gcc-N' driver executable, or nil.

Picks gcc-[0-9]* under the gcc formula prefix so we do not hard-code a major
version that Homebrew may rename on upgrade."
  (when-let* ((prefix (scs/brew-prefix "gcc" brew))
              (drivers (file-expand-wildcards
                        (expand-file-name "bin/gcc-[0-9]*" prefix)))
              (drivers (cl-remove-if-not #'file-executable-p drivers)))
    (car (sort drivers #'string>))))

(defun scs/setup-macos-native-comp ()
  "Set LIBRARY_PATH and CC for Emacs native compilation on macOS.

Called once during early-init, before `package-native-compile' or any code
path loads libgccjit.  No-op on non-Darwin systems."
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

;; Normal interactive sessions stay quiet; bin/emacs-diagnostic lowers this to
;; :warning when you need to see compile or init warnings.
(setq warning-minimum-level :emergency)
(setq byte-compile-warnings '(not free-vars obsolete cl-functions lexical))
;; Prefer newer source over stale .elc during init (especially under lisp/).
(setq load-prefer-newer t)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Frame / UI
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(setq frame-resize-pixelwise t
      frame-inhibit-implied-resize t
      frame-title-format '("%b")
      ring-bell-function 'ignore
      use-dialog-box t ; file dialogs only when invoked by mouse (rare here)
      use-file-dialog nil
      use-short-answers t
      inhibit-splash-screen t
      inhibit-startup-screen t
      inhibit-x-resources t
      ;; Emacs can show a startup message in the echo area; this silences it.
      inhibit-startup-echo-area-message user-login-name
      inhibit-startup-buffer-menu t)

;; menu-bar and scroll-bar stay available for demos; toolbar is off on GUI
;; frames because this config is keyboard-first.  Beginners should keep those
;; elements until they know they do not need them.

;(menu-bar-mode -1)
;(scroll-bar-mode -1)
(when (display-graphic-p) (tool-bar-mode -1))

(when (eq system-type 'darwin)
  (add-to-list 'default-frame-alist '(undecorated-round . t))
  (add-to-list 'default-frame-alist '(font . "Menlo-18"))
  ;; Modifier remapping must be set before the NS window system initializes
  ;; (including daemon / emacsclient first frame).
  (setq mac-command-modifier 'control) ; Command sends Control
  (setq mac-option-modifier 'meta)     ; Option sends Meta
  (setq mac-control-modifier 'super)   ; Control sends Super
  (setq ns-function-modifier 'hyper))  ; Fn (via Karabiner) sends Hyper

(when (display-graphic-p)
  (add-hook 'after-init-hook (lambda () (set-frame-name "home"))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Package setup
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; When early-init is loaded by file, anchor user-emacs-directory to this tree.
(setq user-emacs-directory (file-name-directory (or load-file-name buffer-file-name)))

(require 'package)
;; MELPA packages may replace Emacs-bundled versions when upgrades require it.
(setq package-install-upgrade-built-in t)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(when (string-match "NATIVE_COMP" system-configuration-features)
  (setq package-native-compile t))

(package-initialize)

;;; early-init.el ends here
