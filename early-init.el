;;; early-init.el --- Early Emacs initialization  -*- lexical-binding: t; no-byte-compile: t; -*-
;;
;; $Id: early-init.el,v 1.1 2026/03/23 07:36:04 scs Exp $
;;
;; Filename: early-init.el
;; Description: Performance, UI, packages, PATH, and macOS native-comp setup before init.el.
;; Author: SCS
;; Copyright: Copyright (C) 2026, SCS, all rights reserved.
;; Created: 2026-03-23 Mon 07:36
;; Version: 0.1.0
;; Last-Updated: 2026-08-31 Mon 12:52
;; Update #: 1
;;
;;; Commentary:
;;
;; Emacs 27 and later load this file automatically *before* init.el.  Think of
;; it as the "bootstrap" phase: things here run while Emacs is still waking up,
;; so we can defer expensive work and set environment variables that must exist
;; before libraries like libgccjit load.
;;
;; What lives here (in order):
;;   - user-emacs-directory anchor for this Git tree
;;   - Temporary GC and handler tweaks for faster startup, restored on
;;     emacs-startup-hook (handler merge preserves init-time additions)
;;   - GUI-only redisplay/load-file silencing to avoid startup flash
;;   - Prefer GNU/user tool prefixes on PATH (SmartOS /opt/tools, pkgsrc,
;;     Homebrew, FreeBSD ports) before thin system /usr/bin; on SmartOS
;;     install missing GNU tools via pkgin, then exit if any remain missing
;;   - Homebrew paths for native compilation on macOS (LIBRARY_PATH, CC)
;;   - Native-comp eln-cache/, quiet async warnings, deferred compilation
;;   - Quiet warnings during normal startup (use bin/emacs-diagnostic to debug)
;;   - Frame defaults, macOS modifier remapping, package.el archives
;;   - GUI: *scratch* as initial buffer (single window enforced in startup-state)
;;
;; The no-byte-compile cookie is intentional: do not leave early-init.elc in
;; the tree; stale bytecode here is painful to diagnose.
;;
;;; Change Log:
;;
;; Newest first.  File-local so readers need not dig through VCS.
;;
;; add: 2026-08-31 -- SmartOS pkgin guard installs missing GNU tools
;; fix: 2026-08-22 -- use scratch-buffer (not get-buffer-create) for welcome text
;; fix: 2026-08-22 -- drop initial-scratch-message nil (restore Emacs default text)
;; add: 2026-08-22 -- tier 2 borrow: scroll/cursor perf; scratch-only GUI startup
;; add: 2026-08-22 -- karthink early-init borrow: redisplay guard, native-comp quiet, bidi
;; add: 2026-08-03 -- SmartOS MAKEFLAGS SHELL=bash for make recipes
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

;; Anchor the config tree before anything uses `user-emacs-directory'
;; (load-path, eln-cache, no-littering paths in init.el).
(setq user-emacs-directory (file-name-directory (or load-file-name buffer-file-name)))


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

;; karthink/setup-core and .emacs.d early-init: cheaper scrolling and cursors
;; on LTR-only editing; skip domain-name pings in ffap.
(setq-default bidi-display-reordering 'left-to-right)
(setq-default cursor-in-non-selected-windows nil)
(setq highlight-nonselected-windows nil)
(setq fast-but-imprecise-scrolling t
      ffap-machine-p-known 'reject)
(when (> emacs-major-version 27)
  (setq redisplay-skip-fontification-on-input t))

;; file-name-handler-alist and vc-handled-backends add hooks around file I/O
;; and version control.  Disabling them for init avoids extra work on every
;; path operation while packages load.  Save the defaults first so we can put
;; them back once startup finishes (merge handlers so init-time additions are
;; kept -- pattern from karthink/.emacs.d early-init).

;; Saved default value of file-name-handler-alist for post-init restore.
(defvar scs--file-name-handler-alist file-name-handler-alist)

;; Saved default value of vc-handled-backends for post-init restore.
(defvar scs--vc-handled-backends vc-handled-backends)

;; Saved `load-suffixes' for post-init restore (GUI startup only).
(defvar scs--load-suffixes (default-toplevel-value 'load-suffixes))

(setq vc-handled-backends nil)

(if (or (daemonp) noninteractive)
    (setq file-name-handler-alist nil)
  ;; Interactive GUI: trim handlers and suffixes (karthink/.emacs.d early-init).
  (set-default-toplevel-value
   'file-name-handler-alist
   (if (eval-when-compile (locate-file-internal "calc-loaddefs.el" load-path))
       nil
     (list (rassq 'jka-compr-handler scs--file-name-handler-alist))))
  (set-default-toplevel-value 'load-suffixes '(".elc" ".el"))
  (setq-default inhibit-redisplay t
                inhibit-message t)
  (add-hook 'window-setup-hook
            (lambda ()
              (setq-default inhibit-redisplay nil
                            inhibit-message nil)
              (redisplay)))
  ;; Site init and el-get load many files; "Loading ..." forces redisplay and
  ;; can flash an unstyled frame.  Silence only until init.el is about to load.
  (define-advice load-file (:override (file) silence)
    (load file nil 'nomessage))
  (define-advice startup--load-user-init-file (:before (&rest _) nomessage-remove)
    (advice-remove #'load-file #'load-file@silence)))

(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 1024 1024 20)
                  gc-cons-percentage 0.2
                  vc-handled-backends scs--vc-handled-backends)
            (set-default-toplevel-value
             'file-name-handler-alist
             (delete-dups (append file-name-handler-alist
                                  scs--file-name-handler-alist)))
            (unless (or (daemonp) noninteractive)
              (set-default-toplevel-value 'load-suffixes scs--load-suffixes))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PATH / exec-path: prefer GNU and user tool prefixes
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; SmartOS login PATH often puts /usr/bin before /opt/tools/bin.  System sed,
;; make, awk, find, grep, ls then win over gsed/gmake/gawk/gfind/gls
;; (and the unprefixed GNU binaries that pkgsrc/tools install beside them).
;; Package builds (el-get/howm make) and Emacs subprocesses inherit that
;; order.  Prepend known tool directories early so both PATH and exec-path
;; agree before configure/make and before init.el probes helpers.
;;
;; On SmartOS this config then *requires* those GNU helpers.  Missing ones
;; are installed with pkgin (see `scs/smartos-gnu-tool-packages').  If any
;; are still missing after that attempt, Emacs exits with a clear message
;; instead of failing halfway through package builds.
;;
;; el-get cannot do this job: it loads later from init.el and talks to Git,
;; not pkgin.  howm's el-get :build may install Ruby rd2; that is separate.
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

;; Probe name -> pkgin package on the SmartOS *tools* repo
;; (https://pkgsrc.smartos.org/packages/SmartOS/trunk/tools/All).
;; Names verified on ckg1 2026-08-31 (pkgin pkg-content).
;;
;; grep is the pkgsrc package *and* the unprefixed binary.  The same
;; package also ships ggrep under /opt/tools/bin.  Stock /usr/bin/grep
;; is illumos, not GNU, and must not satisfy the probe.
;; gsed/gmake/gawk/gfind/gls keep the g-prefix so /usr/bin/sed and
;; friends cannot sneak through.  Keep in sync with
;; bin/smartos-emacs-deps.sh.
(defvar scs/smartos-gnu-tool-packages
  '(("gsed"  . "gsed")
    ("gmake" . "gmake")
    ("gawk"  . "gawk")
    ("gfind" . "findutils")
    ("grep"  . "grep")
    ("gls"   . "coreutils"))
  "Alist of GNU probe binaries to pkgin packages for SmartOS host deps.

Each CAR is what we look for after PATH setup.  Each CDR is the pkgin
package that provides it.  Optional howm HTML docs need `rd2' (Ruby gem
rdtool); that is not a global Emacs startup requirement -- see the howm
el-get recipe in init.el and bin/smartos-emacs-deps.sh.")

(defun scs/smartos-in-tool-prefix-p (path)
  "Return non-nil when PATH lives under a GNU/user tool prefix.

Stock /usr/bin does not count.  Prefixes match `scs/setup-tool-path'."
  (and (stringp path)
       (let ((p (expand-file-name path)))
         (or (string-prefix-p "/opt/tools/" p)
             (string-prefix-p "/opt/local/" p)
             (string-prefix-p "/usr/local/" p)
             (string-prefix-p "/opt/homebrew/" p)))))

(defun scs/smartos-tool-prefix-executable (name)
  "Return `executable-find' of NAME only if it is in a GNU/user prefix."
  (let ((path (executable-find name)))
    (and path (scs/smartos-in-tool-prefix-p path) path)))

(defun scs/smartos-gnu-tool-path (binary)
  "Return absolute path of GNU BINARY, or nil.

BINARY is a CAR from `scs/smartos-gnu-tool-packages'.  For grep, accept
ggrep or grep only when the file lives under a tool prefix.  Illumos
/usr/bin/grep does not count."
  (cond
   ((string= binary "grep")
    (or (scs/smartos-tool-prefix-executable "ggrep")
        (scs/smartos-tool-prefix-executable "grep")))
   (t
    (executable-find binary))))

(defun scs/smartos-missing-gnu-tools ()
  "Return probe names from `scs/smartos-gnu-tool-packages' that are missing."
  (let (missing)
    (dolist (cell scs/smartos-gnu-tool-packages (nreverse missing))
      (unless (scs/smartos-gnu-tool-path (car cell))
        (push (car cell) missing)))))

(defun scs/gnu-tool-path (base)
  "Return absolute path of gBASE or BASE on `exec-path', or nil.

BASE is the unprefixed name (\"sed\", \"awk\", ...).  Prefers gBASE."
  (or (executable-find (concat "g" base))
      (executable-find base)))

(defun scs/early-init-echo (fmt &rest args)
  "Print FMT with ARGS even when `inhibit-message' is t on a TTY."
  (let ((msg (apply #'format fmt args)))
    (message "%s" msg)
    ;; TTY / SSH users see stderr even when the echo area is silenced.
    (ignore-errors
      (princ (concat msg "\n") #'external-debugging-output))))

(defun scs/early-init-fail (fmt &rest args)
  "Print FMT with ARGS to the echo area and stderr, then exit Emacs."
  (apply #'scs/early-init-echo fmt args)
  (kill-emacs 1))

(defun scs/smartos-pkgin-install (packages)
  "Install PACKAGES with pkgin -y.  Return the process exit status.

PACKAGES is a list of pkgin names.  Output goes to stderr so a TTY SSH
session can see the download.  Return 127 when pkgin is missing."
  (let ((pkgin (or (executable-find "pkgin") "/opt/tools/bin/pkgin")))
    (cond
     ((not (file-executable-p pkgin))
      (scs/early-init-echo "pkgin not found at %s" pkgin)
      127)
     (t
      (scs/early-init-echo
       "SCS Emacs: pkgin -y install %s"
       (mapconcat #'identity packages " "))
      (with-temp-buffer
        (let ((status (apply #'call-process pkgin nil t nil
                             (append '("-y" "install") packages))))
          (scs/early-init-echo "%s" (buffer-string))
          status))))))

(defun scs/smartos-install-gnu-tools (missing)
  "Map MISSING probe names to pkgin packages and install them.

MISSING is a list of CARs from `scs/smartos-gnu-tool-packages'.
No-op when MISSING is nil.  After pkgin returns, refresh PATH so
the new binaries are visible to `executable-find'."
  (when missing
    (let ((pkgs (delete-dups
                 (mapcar (lambda (bin)
                           (cdr (assoc bin scs/smartos-gnu-tool-packages)))
                         missing))))
      (setq pkgs (delq nil pkgs))
      (when pkgs
        (scs/smartos-pkgin-install pkgs)
        (scs/setup-tool-path)))))

(defun scs/require-smartos-gnu-tools ()
  "On SmartOS, install missing GNU tools via pkgin, then exit if any remain.

No-op on macOS, FreeBSD, and Linux.  Probes gsed, gmake, gawk, gfind,
gls by those g-prefixed names, and GNU grep as grep (or ggrep) under
/opt/tools -- never illumos /usr/bin/grep.  Does not require rd2
(howm-only; see init.el).  el-get is not used here: it is not loaded
yet and it does not speak pkgin."
  (when (scs/smartos-p)
    (let ((missing (scs/smartos-missing-gnu-tools)))
      (when missing
        (scs/early-init-echo
         "SCS Emacs on SmartOS: missing GNU tools: %s"
         (mapconcat #'identity missing ", "))
        (scs/smartos-install-gnu-tools missing)
        (setq missing (scs/smartos-missing-gnu-tools)))
      (when missing
        (scs/early-init-fail
         (concat
          "SCS Emacs on SmartOS requires GNU tools on PATH after early-init.\n"
          "Still missing after pkgin: %s\n"
          "Need pkgin packages: gsed gmake gawk findutils grep coreutils\n"
          "(binaries: gsed gmake gawk gfind grep/ggrep gls under /opt/tools).\n"
          "Install as root, then restart Emacs.\n"
          "Tip: run bin/smartos-emacs-deps.sh on a new SmartOS host.\n"
          "Current PATH=%s")
         (mapconcat #'identity missing ", ")
         (or (getenv "PATH") ""))))))

(scs/require-smartos-gnu-tools)

(defun scs/setup-smartos-make-shell ()
  "On SmartOS, force GNU make recipes to run under bash.

Login SHELL can be bash while /bin/sh is still ksh93.  GNU make does not
honor the SHELL environment variable for recipes (it defaults to /bin/sh).
ksh93's `echo -n` is not portable and breaks stock Makefiles (howm's
bcomp.el rule: unterminated sed s///).  Putting SHELL=/path/to/bash into
MAKEFLAGS applies to every `make` Emacs spawns (el-get, etc.) without
per-package recipes.

No-op when not on SmartOS or when bash is missing."
  (when (scs/smartos-p)
    (let ((bash (or (executable-find "bash") "/usr/bin/bash")))
      (unless (file-executable-p bash)
        (scs/early-init-fail
         "SCS Emacs on SmartOS needs bash for GNU make recipes (MAKEFLAGS).\nMissing executable: %s"
         bash))
      ;; Interactive and call-process shell helpers match the login shell.
      (setq shell-file-name bash)
      (setenv "SHELL" bash)
      ;; make ignores env SHELL; MAKEFLAGS assignment is the portable lever.
      (let* ((assign (concat "SHELL=" bash))
             (prev (getenv "MAKEFLAGS")))
        (setenv "MAKEFLAGS"
                (cond
                 ((or (null prev) (string= prev ""))
                  assign)
                 ((string-match-p "\\bSHELL=" prev)
                  ;; Keep an existing SHELL= from the user/environment.
                  prev)
                 (t
                  (concat assign " " prev))))))))

(scs/setup-smartos-make-shell)

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

;; Native compilation (Emacs 28+): quiet async reports, defer compile until
;; idle, and keep .eln files under this tree's gitignored eln-cache/ (not
;; karthink's ~/.cache/emacs/, which would split cache away from the repo).
(unless (version-list-<
         (version-to-list emacs-version)
         '(28 0 1 0))
  (when (boundp 'native-comp-eln-load-path)
    (add-to-list 'native-comp-eln-load-path
                 (expand-file-name "eln-cache/" user-emacs-directory))
    (setq native-comp-async-report-warnings-errors 'silent
          native-comp-deferred-compilation t)))

(when (version< emacs-version "31")
  (setq load-path-filter-function #'load-path-filter-cache-directory-files))

;; Normal interactive sessions stay quiet; bin/emacs-diagnostic lowers this to
;; :warning when you need to see compile or init warnings.
(setq warning-minimum-level :emergency)
(setq byte-compile-warnings '(not free-vars obsolete cl-functions lexical))
(setq jka-compr-verbose init-file-debug)
(setq auto-mode-case-fold nil)
;; LTR-only editing (en/it); skip bidirectional paragraph analysis cost.
(setq bidi-inhibit-bpa t)
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
      inhibit-default-init t
      initial-buffer-choice #'scratch-buffer
      initial-major-mode 'fundamental-mode
      ;; Emacs can show a startup message in the echo area; this silences it.
      inhibit-startup-echo-area-message user-login-name
      inhibit-startup-buffer-menu t)

(advice-add #'display-startup-screen :override #'ignore)
(fset #'display-startup-echo-area-message #'ignore)

;; Scroll bars off in the first frame alist reduces GUI flash; menu-bar stays
;; on for demos (see readme.org).  Toolbar lines zero here; tool-bar-mode -1
;; below is the active toggle on graphic frames.
(when (display-graphic-p)
  (add-to-list 'default-frame-alist '(vertical-scroll-bars . nil))
  (add-to-list 'default-frame-alist '(horizontal-scroll-bars . nil))
  (add-to-list 'default-frame-alist '(tool-bar-lines . 0))
  (when (fboundp 'horizontal-scroll-bar-mode)
    (horizontal-scroll-bar-mode -1)))

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

(require 'package)
;; MELPA packages may replace Emacs-bundled versions when upgrades require it.
(setq package-install-upgrade-built-in t
      package-quickstart nil)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(when (string-match "NATIVE_COMP" system-configuration-features)
  (setq package-native-compile t))

(package-initialize)

;;; early-init.el ends here
