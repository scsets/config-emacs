;;; early-init.el --- Early Emacs initialization  -*- lexical-binding: t; no-byte-compile: t; -*-
;;
;; $Id: early-init.el,v 1.1 2026/03/23 07:36:04 scs Exp $
;;
;; Filename: early-init.el
;; Description: Performance, UI, packages, PATH, and macOS native-comp setup before init.el.
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
;;   - Prefer GNU/user tool prefixes on PATH (SmartOS /opt/tools, pkgsrc,
;;     Homebrew, FreeBSD ports) before thin system /usr/bin; on SmartOS
;;     exit immediately if core GNU tools are still missing
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
;; add: 2026-08-03 -- SmartOS hard-fail if core GNU tools missing after PATH
;; add: 2026-08-03 -- prepend GNU/user tool dirs on PATH and exec-path
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
;; PATH / exec-path: prefer GNU and user tool prefixes
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; SmartOS login PATH often puts /usr/bin before /opt/tools/bin.  System sed,
;; make, awk, find, grep, ls then win over gsed/gmake/gawk/gfind/ggrep/gls
;; (and the unprefixed symlinks that pkgsrc/tools install beside them).
;; Package builds (el-get/howm make) and Emacs subprocesses inherit that
;; order.  Prepend known tool directories early so both PATH and exec-path
;; agree before configure/make and before init.el probes helpers.
;;
;; On SmartOS/Illumos this config then *requires* the core GNU helpers.  A
;; bare zone without /opt/tools (or equivalent) exits immediately with a
;; clear message instead of failing halfway through package builds.
;;
;; Directories that do not exist are skipped (macOS has no /opt/tools, a bare
;; SmartOS zone may lack pkgsrc, etc.).

(defun scs/prepend-exec-directory (dir)
  "Put DIR first on `exec-path' and on the process PATH when it exists.

DIR is expanded.  No-op when DIR is missing or not a directory.  Drops any
earlier duplicate of DIR from `exec-path' so the prepend sticks."
  (when (and (stringp dir) (file-directory-p dir))
    (let* ((dir (directory-file-name (expand-file-name dir)))
           (path (or (getenv "PATH") ""))
           (parts (unless (string= path "")
                    (split-string path path-separator t))))
      (setq exec-path (cons dir (delete dir (copy-sequence exec-path))))
      (setenv "PATH" (mapconcat #'identity
                                (cons dir (delete dir parts))
                                path-separator))
      dir)))

(defun scs/setup-tool-path ()
  "Prepend platform tool prefixes so GNU helpers shadow thin system ones.

Highest priority first in the list below.  Each existing directory is
prepended in reverse so the first entry ends up first on PATH/`exec-path'.
Only existing directories are added.  Safe on every platform; missing
prefixes are ignored."
  ;; Walk low-to-high priority so the final prepend leaves Homebrew /
  ;; /opt/tools ahead of /usr/local and system paths.
  (dolist (dir (reverse '("/opt/homebrew/bin"
                          "/opt/homebrew/sbin"
                          "/opt/tools/bin"
                          "/opt/tools/sbin"
                          "/opt/local/bin"
                          "/opt/local/sbin"
                          "/usr/local/bin"
                          "/usr/local/sbin")))
    (scs/prepend-exec-directory dir)))

(scs/setup-tool-path)

(defun scs/smartos-p ()
  "Return non-nil when this Emacs is running on SmartOS/Illumos.

`system-type' is `usg-unix-v' there.  Confirm with zonename(1) or the
usual pkgsrc/tools prefixes so plain SVR4 hosts are not treated as SmartOS."
  (and (eq system-type 'usg-unix-v)
       (or (file-executable-p "/usr/bin/zonename")
           (file-directory-p "/opt/tools")
           (file-directory-p "/opt/local"))))

(defvar scs/smartos-required-gnu-tools
  '("gsed" "gmake" "gawk" "gfind" "ggrep" "gls")
  "GNU tool names that must exist on SmartOS after PATH setup.

Require the g-prefixed binaries explicitly.  Accepting plain sed/make/awk
would pass on stock /usr/bin (illumos sed is not GNU and breaks howm make).
/opt/tools usually also ships unprefixed symlinks (sed -> gsed); PATH
prepending makes those work for Makefiles that call sed/make without the g.")

(defun scs/gnu-tool-path (base)
  "Return absolute path of gBASE or BASE on `exec-path', or nil.

BASE is the unprefixed name (\"sed\", \"awk\", …).  Prefers gBASE."
  (or (executable-find (concat "g" base))
      (executable-find base)))

(defun scs/early-init-fail (fmt &rest args)
  "Print FMT with ARGS to the echo area and stderr, then exit Emacs."
  (let ((msg (apply #'format fmt args)))
    (message "%s" msg)
    ;; TTY / SSH users see stderr even when the echo area is gone.
    (ignore-errors
      (princ (concat msg "\n") #'external-debugging-output))
    (kill-emacs 1)))

(defun scs/require-smartos-gnu-tools ()
  "On SmartOS, exit unless core g* GNU tools are on PATH after setup.

No-op on macOS, FreeBSD, and Linux.  Requires gsed, gmake, gawk, gfind,
ggrep, and gls by those exact names so thin /usr/bin sed/awk cannot
satisfy the check."
  (when (scs/smartos-p)
    (let ((missing
           (let (out)
             (dolist (name scs/smartos-required-gnu-tools (nreverse out))
               (unless (executable-find name)
                 (push name out))))))
      (when missing
        (scs/early-init-fail
         (concat
          "SCS Emacs on SmartOS requires GNU tools on PATH after early-init.\n"
          "Missing: %s\n"
          "Install under /opt/tools/bin (preferred) or /opt/local/bin, then\n"
          "restart Emacs.  Need at least: gsed gmake gawk gfind ggrep gls\n"
          "(unprefixed sed/make/awk/find/grep/ls symlinks are optional but\n"
          "recommended so Makefiles that call plain sed still get GNU).\n"
          "Current PATH=%s")
         (mapconcat #'identity missing ", ")
         (or (getenv "PATH") ""))))))

(scs/require-smartos-gnu-tools)

(defun scs/prefer-gnu-program (base &optional emacs-var)
  "Prefer the g-prefixed GNU tool for BASE when it is on `exec-path'.

Looks up \"gBASE\" then BASE via `executable-find'.  When EMACS-VAR is a
bound symbol (for example `find-program'), set it to the absolute path.
Return the chosen path string, or nil when neither exists.

Examples of BASE: \"sed\", \"make\", \"awk\", \"find\", \"grep\", \"ls\".
Call after `scs/setup-tool-path' so /opt/tools and friends are visible."
  (let ((path (scs/gnu-tool-path base)))
    (when (and path emacs-var (boundp emacs-var))
      (set emacs-var path))
    path))

;; Point Emacs at GNU-friendly helpers when the g* name exists.  PATH already
;; prefers unprefixed symlinks under /opt/tools (sed -> gsed, make -> gmake);
;; these bindings cover hosts that only ship the g* names, and make Dired /
;; grep / find unambiguous inside Emacs.
(scs/prefer-gnu-program "ls" 'insert-directory-program)
(scs/prefer-gnu-program "find" 'find-program)
(scs/prefer-gnu-program "grep" 'grep-program)


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
