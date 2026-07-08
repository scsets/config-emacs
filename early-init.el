;;; early-init.el --- Early initialization  -*- lexical-binding: t; -*-
;;
;; $Id: early-init.el,v 1.1 2026/03/23 07:36:04 scs Exp $
;;
;;; Commentary:
;;  Startup performance tweaks, UI defaults, and package setup.
;;  Loaded before init.el by Emacs 27+.
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

(setq native-comp-async-report-warnings-errors 'silent)
(setq warning-minimum-level :emergency)
(setq byte-compile-warnings '(not free-vars obsolete cl-functions lexical))


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
