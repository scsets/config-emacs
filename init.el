;;; init.el --- SCS team Emacs configuration  -*- lexical-binding: t; no-byte-compile: t; -*-
;;
;; Filename: init.el
;; Description: SCS team Emacs configuration and package policy
;; Author: SCS
;; Copyright: Copyright (C) 2026, SCS, all rights reserved.
;; Created: 2026-03-05 Thu 17:59
;; Version: 0.1.0
;; Last-Updated: 2026-08-21 Fri 13:53
;; Update #: 48
;;
;;; Commentary:
;;
;; SCS team Emacs configuration: editor policy, packages, and keybindings
;; for daily work.  Shared, reusable Elisp lives under lisp/ (see readme.org
;; in this directory).  Requires Emacs 29+.
;;
;; Load order:
;;   early-init.el runs once at process startup (GC tuning, frame defaults,
;;   package archives, macOS modifier remaps, native-comp environment).
;;   init.el (this file) loads next and holds everything else.
;;
;; Sections (top to bottom):
;;   Custom functions -- small helpers and hook targets defined here.
;;   Local libraries -- autoloads pointing at lisp/*.el.
;;   Package managers -- el-get bootstrap and use-package :el-get glue.
;;   General settings -- server, encoding, save hygiene, dired, search tools,
;;   input method.
;;   Custom file -- where Customize would write (we keep config in Git instead).
;;   Settings formerly in custom.el -- migrated Customize values; GUI startup
;;   uses scs-startup-state (not desktop.el).
;;   Frame / UI -- theme (GUI vs TTY), font, tool-bar.
;;   Keybindings -- Hyper chords (macOS), C-c prefixes, safety remaps.
;;   Packages -- use-package blocks, mostly alphabetical (see in-file notes).
;;   Finalization -- (provide 'init).
;;
;; How to find things in this file:
;;   Search for semicolon banner lines or for `(use-package PACKAGE'.
;;   Team-specific symbols usually start with scs/ or scs--.
;;   F1 f / F1 v and apropos still work once Emacs is running.
;;   (C-h is delete in this profile; see the C-h section under Keybindings.)
;;
;; The no-byte-compile cookie is intentional: init.el is the authoritative
;; source; stale init.elc in the tree is painful to debug.
;;
;;; Change Log:
;;
;; Newest first.  File-local so readers need not dig through VCS.
;;
;; add: 2026-08-29 -- scs/reveal-file: Finder or TTY Dired; copy path; C-c M-v
;; add: 2026-08-22 -- consult-dir (C-x C-d, C-x C-j); TRAMP + SSH sources
;; add: 2026-08-21 -- howm link jump on s-TAB (physical Ctrl-Tab)
;; add: 2026-08-21 -- spell/ personal dicts in Git; scs/spell-dicts-install
;; add: 2026-08-21 -- jinx (en_GB-ise it_IT); keep idle flyspell/aspell
;; add: 2026-08-17 -- H-f is find-file (toggle)
;; add: 2026-08-17 -- second M-x / Consult press quits that minibuffer
;; add: 2026-08-17 -- H-g is keyboard-escape-quit; H-b toggles consult-buffer
;; fix: 2026-08-17 -- Emacs 31 when-let* (when-let is obsolete)
;; fix: 2026-08-17 -- C-c h in Org falls back to command history
;; add: 2026-08-17 -- vertico-repeat (Helm-resume analogue; not Counsel)
;; add: 2026-08-17 -- scs/sync-emacs-config: git pull, prune leftover el-get
;; add: 2026-08-17 -- embark-consult + wgrep; recentf on before first C-x b
;; add: 2026-08-17 -- Vertico half-window always; enable Marginalia
;; add: 2026-08-17 -- Consult Vertico list uses half the frame
;; add: 2026-08-17 -- drop Helm; Consult takes clashing keys; catalog uses Vertico
;; add: 2026-08-17 -- C-x C-f 1..4 find-file UI trials (Vertico/Fido/Ivy/Lusty)
;; add: 2026-08-04 -- curated GUI startup (scs-startup-state); desktop-save-mode off
;; add: 2026-08-03 -- remove mail contacts package; gitea SSH; skip local clipper
;; add: 2026-08-03 -- howm el-get recipe (docs need rd2; not global dep)
;; add: 2026-08-03 -- TTY frames load misterioso; GUI keeps adwaita (Frame/UI)
;; add: 2026-07-31 -- autoload scs/copy-path and bind it on H-c p
;; fix: 2026-07-27 -- autoload howm-mode; expose async clipper cancellation
;; fix: 2026-07-27 -- forward delete chews spaces; leave rub-out alone
;; fix: 2026-07-27 -- smart-delete on C-h/DEL; guard M-x nil crash
;; fix: 2026-07-27 -- H-h uses single-space sentence ends; add smart-delete on DEL
;; fix: 2026-07-27 -- H-h rubs out sentence first, then rest of line
;; fix: 2026-07-27 -- H-h rubs out backward (line, then sentence)
;; fix: 2026-07-27 -- H-h first press keeps the newline (not kill-line)
;; add: 2026-07-27 -- H-h progressive kill; Karabiner proxy for macOS Fn+H
;; add: 2026-07-27 -- free package C-h help while keeping C-h as delete
;; add: 2026-07-27 -- bind Embark act to C-.
;; add: 2026-07-27 -- install org-web-clipper from local Gitea with pinned tools
;; add: 2026-07-27 -- prefer ripgrep and fd for search/find where syntax fits
;; fix: 2026-07-27 -- prefer gls for Dired on macOS and SmartOS, not darwin-only
;; add: 2026-07-27 -- use Homebrew gls for Dired on macOS (BSD ls lacks --dired)
;; add: 2026-07-27 -- install focused Org capture and Scrim/Captee templates
;; fix: 2026-07-27 -- use Scrim's required server/server TCP auth-file path
;; fix: 2026-07-27 -- keep socket and Scrim TCP servers independently tracked
;; fix: 2026-07-27 -- demand and idempotently enable diff-hl
;; fix: 2026-07-27 -- apply a nil-frame font setting to existing and future frames
;; fix: 2026-07-27 -- make abbrev-mode the default in new buffers
;; fix: 2026-07-25 -- use TeX as the always-on GUI/terminal input method
;; fix: 2026-07-25 -- keep the optional postfix input method dormant by default
;; fix: 2026-07-25 -- use postfix accents without swallowing leading punctuation
;; fix: 2026-07-25 -- declare Gitea contextual interface dependencies
;; add: 2026-07-25 -- install Embark for buffer-local Gitea actions
;; fix: 2026-07-25 -- let gitea.el own its platform cache location
;; fix: 2026-07-25 -- install gitea.el through its canonical el-get recipe
;; fix: 2026-07-24 -- el-get sync/install errors warn; init continues (theme stays put)
;; fix: 2026-07-24 -- teachable Commentary and section policy notes for SCS team
;; add: 2026-07-24 -- before-save LAST-UPDATED hook; rename-at-point autoload
;; add: 2026-07-22 -- org-ensure-buffer-header; scs/convert autoloads
;; add: 2026-07-17 -- zwsp markers autoload; H-w delete-frame
;; fix: 2026-07-10 -- scs-cl; Org ID / Helm / hygiene review fixes
;; add: 2026-07-09 -- frame-state; plain org-id for howm; recentf/dired hardening
;; fix: 2026-07-09 -- remove Hyperbole/HyWiki; drop org-mem/org-node
;; fix: 2026-07-09 -- howm rename/search/tags; desktop/EWW/el-get hygiene
;; add: 2026-03-05 -- cl-lib/subr-x at top; split heavy settings into early-init
;;
;;; Code:

;; lisp/ may already be on load-path from early-init; repeat here so batch
;; loads of init.el alone (tests, emacs -Q -l init.el) still find scs-cl.el.
(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))
(add-to-list 'load-path (expand-file-name "lisp/scs-convert" user-emacs-directory))
(require 'scs-cl)
(require 'subr-x)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Custom functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Helpers that are small enough to keep inline rather than in lisp/.
;; Most are bound to keys or registered on hooks later in this file.
;; When debugging init load order, `scs/exit-loading' jumps to end-of-load
;; so you can bisect which section causes trouble (see stackexchange link below).

;; https://emacs.stackexchange.com/a/28927
;; Call this anywhere to end loading init file, good to debug.
;; fix: 2026-07-10 — rename my-exit → scs/exit-loading
(defun scs/exit-loading ()
  "Abort loading the current file by jumping to its end.

Use while bisecting init.el: place a call just after the section you want
to test; everything below is skipped until you remove the call."
  (with-current-buffer " *load*"
    (goto-char (point-max))))
(defalias 'my-exit #'scs/exit-loading)

(defun scs/hyper-h--kill-sentence-back ()
  "Kill one preceding sentence, treating a single space after `.' as enough.

Emacs defaults `sentence-end-double-space' to t, so on a line like
\"A. B. C.|\" `kill-sentence' with -1 would rub out the whole line.
Bind it to nil for this command only; leave the global default alone."
  (let ((sentence-end-double-space nil))
    (kill-sentence -1)))

(defun scs/hyper-h-rubout ()
  "Rub out preceding text: one sentence, then the rest of the line.

\"Rub out\" is the old name for deleting /before/ point (Backspace
direction), not forward delete after point.

- First press: kill the preceding sentence.  Uses single-space sentence
  ends for this command only (see `scs/hyper-h--kill-sentence-back').
  On \"A. B. C.|\" only \"C.\" goes away.
- Immediate repeat: kill from the beginning of the line to point (the
  rest of the preceding line).  If point is already at the beginning
  of the line, kill one more sentence backward instead.

Kill commands normally set `this-command' to `kill-region' so consecutive
kills append on the kill ring; this command restores `this-command' so a
second H-h still counts as a repeat of this command.

Bound to Hyper-h on macOS (Karabiner proxies Fn+H; see Hyper keybindings).
Forward Delete / C-d is separate (`scs/delete-forward'); rub-out keys
(C-h, Backspace) stay one-character."
  (interactive)
  (if (eq last-command this-command)
      ;; Escalate: rest of line before point, or another sentence at BOL.
      (let ((beg (line-beginning-position)))
        (if (= (point) beg)
            (scs/hyper-h--kill-sentence-back)
          (kill-region beg (point))))
    (scs/hyper-h--kill-sentence-back))
  ;; Keep H-h repeat detection; do not leave this-command as kill-region.
  (setq this-command 'scs/hyper-h-rubout))

(defalias 'scs/hyper-h-delete #'scs/hyper-h-rubout)

(defun scs/delete-forward (&optional n)
  "Delete after point: chew a whitespace run, else one character.

Greybeard distinction (do not blur these):
- Rub-out -- delete /before/ point (Backspace, C-h).  Unchanged here.
- Delete -- delete /after/ point (C-d, Fn-Backspace / <deletechar>).

When the following text is spaces or tabs, remove that whole run in one
go.  Example, point at | in \"test|     test1\" becomes \"testtest1\".
Otherwise delete N characters forward like `delete-char'.

Active region: delete the region when `delete-active-region' allows it."
  (interactive "p")
  (cond
   ((and (use-region-p) delete-active-region)
    (delete-region (region-beginning) (region-end)))
   ((looking-at "[ \t]+")
    (delete-region (point) (match-end 0)))
   ((eobp)
    (message "End of buffer"))
   (t
    (delete-char (prefix-numeric-value n)))))

(defun scs/reapply-early-init-runtime ()
  "Re-apply early-init.el settings that can change mid-session.

`early-init.el' itself runs only once at startup.  Modifier remaps
(`mac-command-modifier', etc.), `default-frame-alist' and
`package-initialize' require a full Emacs restart."
  (setq gc-cons-threshold (* 1024 1024 20)
        gc-cons-percentage 0.2)
  (when (fboundp #'scs/setup-macos-native-comp)
    (scs/setup-macos-native-comp))
  (message "Early-init runtime settings updated (restart for modifiers/packages)"))

(defun scs/reload-config (&optional with-early)
  "Reload `user-init-file' without restarting Emacs.

Reloads init.el only.  early-init.el is not re-read; use a prefix
argument to re-apply GC and native-comp env vars from early-init.
Hook forms in init.el may run again and stack duplicates; restart
Emacs after large structural changes."
  (interactive "P")
  (when with-early
    (scs/reapply-early-init-runtime))
  (load user-init-file nil t)
  (message "Reloaded %s" (abbreviate-file-name user-init-file)))

(global-set-key (kbd "C-c r") #'scs/reload-config)
;; Command hub home: curated catalog, workflows, describe (see lisp/scs-command-hub.el).
;; C-c / is the same door without Shift (many keyboards need Shift for ?).
;; Org also binds those keys; reclaimed in with-eval-after-load 'org below.
(global-set-key (kbd "C-c ?") #'scs/command-hub)
(global-set-key (kbd "C-c /") #'scs/command-hub)

;; Parenthesis jump helper (vi-style `%').  Point may sit inside or on the bracket.
;; http://www.emacswiki.org/emacs/ParenthesisMatching#toc4
;; bind C-% to goto-match-paren
;; note, cursor must right before/on/after paren/brace/bracket
(defun goto-match-paren (_arg)
  "Jump to the matching bracket when point is on (), {}, or [].
Mimics the vi `%' motion.  Works from inside or just outside the
bracket pair."
  (interactive "p")
  (cond
   ((looking-at-p "[][(){}]") (forward-sexp))
   ((looking-back "[][(){}]" 1) (backward-sexp))
   ((looking-at-p "[])}]") (forward-char) (backward-sexp))
   ((looking-back "[][({]" 1) (backward-char) (forward-sexp))
   (t nil)))

;; delete visited file and buffer
;; https://zck.org/deleting-files-in-emacs
(defun delete-visited-file (buffer-name)
  "Delete the file visited by the buffer named BUFFER-NAME."
  (interactive "bDelete file visited by buffer ")
  (when-let* ((buffer (get-buffer buffer-name)))
    (when-let* ((filename (buffer-file-name buffer))
                (_ (file-exists-p filename)))
      (delete-file filename))
    (kill-buffer buffer)))

;; kill all dired buffers
(defun kill-dired-buffers ()
  "Kill every buffer whose major mode is `dired-mode'."
  (interactive)
  (cl-loop for buffer in (buffer-list)
           when (eq 'dired-mode (buffer-local-value 'major-mode buffer))
           do (kill-buffer buffer)))

;; From Prot, via https://emacsredux.com/blog/2025/06/01/let-s-make-keyboard-quit-smarter/
(defun prot/keyboard-quit-dwim ()
  "Do-What-I-Mean behaviour for a general `keyboard-quit'.

The generic `keyboard-quit' does not do the expected thing when
the minibuffer is open.  Whereas we want it to close the
minibuffer, even without explicitly focusing it.

The DWIM behaviour of this command is as follows:

- When the region is active, disable it.
- When a minibuffer is open, but not focused, close the minibuffer.
- When the Completions buffer is selected, close it.
- In every other case use the regular `keyboard-quit'."
  (interactive)
  (cond
   ((region-active-p)
    (keyboard-quit))
   ((derived-mode-p 'completion-list-mode)
    (delete-completion-window))
   ((> (minibuffer-depth) 0)
    (abort-recursive-edit))
   (t
    (keyboard-quit))))

;; https://baty.net/posts/2026/02/global-org-capture-shortcut-in-kde/
;; After org-capture finishes, close the extra frame emacsclient opened so
;; you are not left with a stray window (common with global capture shortcuts).
;; fix: 2026-07-10 — rename my/org-capture-finalize-hook → scs/
(defun scs/org-capture-finalize-hook ()
  "Close frame after org-capture if it was opened for capture."
  (when (and (> (length (frame-list)) 1)  ; More than one frame
             (frame-parameter nil 'client)) ; Frame created by emacsclient
    (delete-frame)))

(add-hook 'org-capture-after-finalize-hook #'scs/org-capture-finalize-hook)

;; New GUI frames land on persistent Remember notes instead of *scratch*,
;; so a fresh frame is ready for jotting without losing scratch buffer policy.
;; fix: 2026-07-10 — rename; docstring matched *scratch* but opened Remember
(defun scs/switch-to-remember-notes (frame)
  "Open the Remember notes buffer in newly created FRAME.
Intentionally not *scratch*; new frames land on persistent notes."
  (with-selected-frame frame
    (remember-notes t)))

(add-hook 'after-make-frame-functions #'scs/switch-to-remember-notes)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Local libraries (lisp/)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Autoloads defer loading until a command runs.  Heavier tools (TRAMP helpers,
;; frame state, Pandoc convert, mail lab) stay in lisp/ so init.el stays readable.

(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))
(add-to-list 'load-path (expand-file-name "lisp/scs-convert" user-emacs-directory))
;; fix: 2026-07-10 — autoload scs/tramp-* (was my/tramp-*)
(autoload 'scs/tramp-cleanup "scs-tramp" "Clean up TRAMP connections." t)
(autoload 'scs/tramp-reopen "scs-tramp" "Revert remote buffer from host." t)
(autoload 'scs/tramp-find-file "scs-tramp" "Find file on a known TRAMP host." t)
(autoload 'scs/tramp-dired "scs-tramp" "Dired on a known TRAMP host." t)
(autoload 'scs/frame-state-capture "scs-frame-state"
  "Capture the selected frame's geometry." t)
(autoload 'scs/frame-state-save "scs-frame-state"
  "Capture and save the selected frame's geometry." t)
(autoload 'scs/frame-state-load "scs-frame-state"
  "Load and inspect saved frame geometry." t)
(autoload 'scs/frame-state-restore "scs-frame-state"
  "Restore the selected frame's saved geometry." t)
(autoload 'scs/startup-state-apply "scs-startup-state"
  "Apply curated GUI startup buffers and frame geometry." t)
(autoload 'scs/startup-state-enable "scs-startup-state"
  "Enable curated GUI startup hooks." t)
(autoload 'scs/convert "scs-convert"
  "Convert region or buffer via Pandoc (markdown -> org)." t)
;; add: 2026-07-20 -- mail lab (mu4e / notmuch / org-msg)
(autoload 'scs/mail-lab-mu4e "scs-mail-lab"
  "Open mu4e on the shared ~/mail vault." t)
(autoload 'scs/mail-lab-notmuch "scs-mail-lab"
  "Open notmuch on the shared ~/mail vault." t)
(autoload 'scs/mail-lab-search "scs-mail-lab"
  "notmuch search on the shared ~/mail vault." t)
(autoload 'scs/mail-lab-compose "scs-mail-lab"
  "Compose mail as one of the lab addresses." t)
(autoload 'scs/mail-lab-install-keys "scs-mail-lab"
  "Bind C-c m for the mail lab." t)
;; org-tools: interactive entry points (hooks load via require after Org)
(autoload 'scs/org-line-prefixes-mode "org-tools" nil t)
(autoload 'scs/org-line-prefixes-status "org-tools" nil t)
(autoload 'scs/org-regenerate-stationery "org-tools" nil t)
(autoload 'scs/org-insert-creation-date "org-tools" nil t)
(autoload 'scs/org-append-zwsp-markers "org-tools" nil t)
(autoload 'scs/org-ensure-buffer-header "org-tools" nil t)
(autoload 'scs/rename-visited-file-to-name-at-point "org-tools" nil t)
;; add: 2026-07-24 -- Transient command hub home on C-c ?
(autoload 'scs/command-hub "scs-command-hub"
  "Open the SCS command hub (Transient home on C-c ?)." t)
(autoload 'scs/command-hub-browse-catalog "scs-command-hub"
  "Browse the curated command catalog with completing-read." t)
;; add: 2026-07-31 -- DWIM path copy (file / Dired / TRAMP / formats)
(autoload 'scs/copy-path "scs-copy-path"
  "Copy buffer/Dired/TRAMP path(s) to the kill ring and clipboard." t)
(autoload 'scs/copy-path-absolute "scs-copy-path" nil t)
(autoload 'scs/copy-path-relative "scs-copy-path" nil t)
(autoload 'scs/copy-path-project "scs-copy-path" nil t)
(autoload 'scs/copy-path-truename "scs-copy-path" nil t)
(autoload 'scs/copy-path-local-name "scs-copy-path" nil t)
;; add: 2026-08-29 -- reveal visited file in Finder or TTY Dired; copy path
(autoload 'scs/reveal-file "scs-reveal-file"
  "Reveal the current file in Finder or Dired; copy absolute path." t)
;; add: 2026-08-20 -- sort pipe-separated fields on the current line
(autoload 'scs/sort-line-fields "scs-sort-line-fields"
  "Sort pipe-separated fields on this line alphabetically." t)
;; add: 2026-08-17 -- git pull this repo, prune leftover el-get, maybe restart
(autoload 'scs/sync-emacs-config "scs-config-sync"
  "git pull this Emacs repo, prune leftover el-get packages, maybe restart." t)
(autoload 'scs/el-get-cleanup-unwanted "scs-config-sync"
  "Remove el-get packages this profile no longer declares." t)
(autoload 'scs/restart-emacs "scs-config-sync"
  "Exit this Emacs after spawning a waiter that starts a new process." t)
;; add: 2026-08-21 -- install versioned spell/ word lists for jinx/Enchant
(autoload 'scs/spell-dicts-install "scs-spell-dicts"
  "Install spell/ personal word lists into Enchant and aspell paths." t)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Package managers
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; el-get installs third-party packages from Git and similar sources.
;; use-package (below) declares what we want; :el-get ensures recipes exist
;; and packages are synced before config runs.

;; ----------------------------------------------------------
;; el-get
;; ----------------------------------------------------------

(defvar scs/el-get-repository-url "https://github.com/dimitri/el-get.git"
  "Git URL used to clone el-get when no checkout exists under user-emacs-directory.")

(defvar scs/el-get-local-sources nil
  "El-get recipe plists owned by init.el; populated by the setq form below.")

(setq scs/el-get-local-sources
      '(        (:name cl-lib
         :type builtin
         :builtin "24.3")
        (:name el-get
         :type github
         :pkgname "dimitri/el-get"
         :branch "master"
         :features el-get
         :compile ("el-get.*\\.el$" "methods/"))
        (:name emacs
         :type builtin)
        (:name nadvice
         :type builtin
         :builtin "24.4")
        (:name org
         :type builtin
         :builtin "9")
        (:name seq
         :type builtin
         :builtin "2")
        (:name async
         :type github
         :pkgname "jwiegley/emacs-async"
         :features async)
        (:name cape
         :type github
         :pkgname "minad/cape"
         :depends (compat))
        (:name company
         :type github
         :pkgname "company-mode/company-mode"
         :features company)
        (:name compat
         :type github
         :pkgname "emacs-compat/compat")
        (:name delight
         :type github
         :pkgname "emacsmirror/delight"
         :depends (cl-lib nadvice))
        (:name eat
         :type github
         :pkgname "emacsmirror/eat"
         :depends (compat))
        (:name eshell-bookmark
         :type github
         :pkgname "Fuco1/eshell-bookmark")
        (:name eshell-toggle
         :type github
         :pkgname "4DA/eshell-toggle"
         :depends (dash))
        (:name eshell-up
         :type github
         :pkgname "peterwvj/eshell-up")
        (:name eshell-z
         :type github
         :pkgname "xuchunyang/eshell-z")
        (:name fd-dired
         :type github
         :pkgname "yqrashawn/fd-dired")
        (:name framemove
         :type github
         :pkgname "emacsmirror/framemove")
        (:name embark
         :type github
         :pkgname "oantolin/embark"
         :features embark
         :depends (compat))
        (:name gitea
         ;; Private repo: HTTPS needs interactive credentials (fails on
         ;; SmartOS/daemon).  SSH works with the host key already on PATH.
         :type git
         :url "git@github.com:scsets/gitea.el.git"
         :branch "trunk"
         :features gitea
         :depends (embark magit-section transient))
        (:name haproxy-mode
         :type github
         :pkgname "port19x/haproxy-mode")
        ;; howm: stock upstream build (configure + make) including HTML docs
        ;; under doc/.  Docs need `rd2` from the Ruby gem rdtool
        ;; (gem install rdtool).  On SmartOS install host deps with
        ;; bin/smartos-emacs-deps.sh.  early-init sets MAKEFLAGS SHELL=bash
        ;; so make recipes are not run under ksh93 (echo -n / bcomp.el).
        ;; The configure step fails this package only if rd2 is missing,
        ;; without making rd2 a global Emacs startup dependency.
        (:name howm
         :website "https://kaorahi.github.io/howm/"
         :description "Write fragmentarily and read collectively."
         :type github
         :pkgname "kaorahi/howm"
         :build (("sh" "-c" "\
set -e
if ! command -v rd2 >/dev/null 2>&1; then
  echo 'howm: rd2 not on PATH (needed for doc/*.html).' >&2
  echo 'Install: gem install rdtool' >&2
  echo 'Or on SmartOS: bin/smartos-emacs-deps.sh' >&2
  exit 1
fi
em=$(command -v emacs)
if [ -z \"$em\" ]; then
  echo 'howm: emacs not on PATH for ./configure --with-emacs=' >&2
  exit 1
fi
exec ./configure --with-emacs=\"$em\"
")
                 ("make")))
        ;; add: 2026-07-24 -- command hub deep docs (Transient catalog Describe)
        (:name dash
         :type github
         :pkgname "magnars/dash.el"
         :features dash)
        (:name s
         :type github
         :pkgname "magnars/s.el"
         :features s)
        (:name smart-delete
         :type github
         :pkgname "leodag/smart-delete"
         :features smart-delete)
        (:name f
         :type github
         :pkgname "rejeep/f.el"
         :features f
         :depends (s dash))
        (:name elisp-refs
         :type github
         :pkgname "Wilfred/elisp-refs"
         :features elisp-refs
         :depends (dash s))
        (:name helpful
         :type github
         :pkgname "Wilfred/helpful"
         :features helpful
         :depends (elisp-refs dash s f))
        (:name hl-todo
         :type github
         :pkgname "tarsius/hl-todo"
         :depends (compat cond-let))
        (:name imenu-list
         :type github
         :pkgname "bmag/imenu-list")
        (:name impatient-mode
         :type github
         :pkgname "skeeto/impatient-mode"
         :depends (htmlize simple-httpd))
        ;; Spell-check via Enchant (libenchant); builds jinx-mod at install.
        ;; Host needs enchant + pkgconf (macOS: brew install enchant pkgconf).
        (:name jinx
         :type github
         :pkgname "minad/jinx"
         :depends (compat))
        (:name keycast
         :type github
         :pkgname "tarsius/keycast"
         :branch "main"
         :depends (compat))
        (:name llama
         :type github
         :pkgname "tarsius/llama"
         :depends (compat))
        (:name magit-section
         :type github
         :pkgname "magit/magit"
         :branch "main"
         :load-path ("lisp")
         :features magit-section
         :depends (compat cond-let llama seq transient with-editor))
        (:name minions
         :type github
         :pkgname "tarsius/minions"
         :depends (compat))
        (:name move-dup
         :type github
         :pkgname "wyuenho/move-dup")
        (:name no-littering
         :type github
         :pkgname "emacscollective/no-littering"
         :depends (cl-lib compat))
        (:name org-auto-expand
         :type github
         :pkgname "alphapapa/org-auto-expand"
         :depends (org))
        (:name org-contrib
         :type git
         :url "https://git.sr.ht/~bzg/org-contrib"
         :load-path ("lisp")
         :depends (org))
        (:name org-web-clipper
         :type git
         ;; Laptop-only local Gitea by default.  On hosts without
         ;; 127.0.0.1:3000, scs/el-get-skip-unavailable-local-packages
         ;; drops this source for the session so init does not thrash.
         :url "http://127.0.0.1:3000/scs/org-web-clipper.git"
         :branch "trunk"
         :features org-web-clipper
         :depends (org)
         ;; Keep Defuddle and LinkeDOM at the package's locked versions.
         :build (("npm" "ci" "--omit=dev" "--ignore-scripts")))
        (:name ob-mermaid
         :type github
         :pkgname "arnm/ob-mermaid"
         :depends (org))
        ;; add: 2026-07-20 -- mail lab HTML compose
        (:name org-msg
         :type github
         :pkgname "jeremy-compostella/org-msg"
         :description "Org-mode HTML compose for message-mode MUAs"
         :depends (htmlize)
         :features org-msg)
        ;; add: 2026-07-24 -- Magit process editor helper
        (:name with-editor
         :type github
         :pkgname "magit/with-editor"
         :branch "main"
         :load-path ("lisp")
         :features with-editor)
        ;; add: 2026-07-24 -- explicit Transient for command hub spine
        (:name transient
         :type github
         :pkgname "magit/transient"
         :branch "main"
         :load-path ("lisp")
         :features transient
         :depends (compat cond-let llama seq))
        (:name yasnippet
         :type github
         :pkgname "joaotavora/yasnippet"
         :features yasnippet)
        ;; Minibuffer stack: Vertico UI, Orderless matching, Consult
        ;; commands, Marginalia annotations.
        (:name consult
         :type github
         :pkgname "minad/consult"
         :depends (compat))
        (:name consult-dir
         :type github
         :pkgname "karthink/consult-dir"
         :depends (consult))
        (:name marginalia
         :type github
         :pkgname "minad/marginalia"
         :depends (compat))
        (:name orderless
         :type github
         :pkgname "oantolin/orderless"
         :depends (compat))
        (:name vertico
         :type github
         :pkgname "minad/vertico"
         :load-path ("." "extensions")
         :depends (compat))))

;; Packages installed with use-package :el-get using stock el-get
;; recipes (no plist in `scs/el-get-local-sources').  Cleanup keeps
;; these plus local sources and their dependencies.
(defconst scs/el-get-extra-keep-packages
  '(avy diff-hl exec-path-from-shell flycheck reveal-in-osx-finder
    slime sly sly-asdf sly-macrostep sly-repl-ansi-color unfill
    wgrep which-key)
  "el-get packages declared via use-package :el-get without a local recipe.")

(defun scs/el-get-bootstrap ()
  "Clone el-get into `user-emacs-directory' when no checkout is present.

Arguments: none.
Return value: nil.
Side effects: creates the el-get checkout and updates `load-path'."
  (unless (executable-find "git")
    (user-error "el-get bootstrap requires git in PATH"))
  (let* ((target (expand-file-name "el-get/el-get" user-emacs-directory))
         (parent (file-name-directory (directory-file-name target)))
         (output (get-buffer-create "*scs el-get bootstrap*")))
    (when (file-exists-p target)
      (user-error "el-get exists at %s but could not be loaded" target))
    (make-directory parent t)
    (with-current-buffer output
      (let ((inhibit-read-only t))
        (erase-buffer)))
    (unless (zerop (let ((inhibit-read-only t))
                     (call-process "git" nil output t
                                   "clone" "--depth" "1"
                                   scs/el-get-repository-url target)))
      (user-error "Could not clone el-get into %s; see %s"
                  target (buffer-name output)))
    (add-to-list 'load-path target)))

(add-to-list 'load-path
             (expand-file-name "el-get/el-get" user-emacs-directory))

(unless (require 'el-get nil 'noerror)
  (scs/el-get-bootstrap))

(require 'el-get)

(defun scs/el-get-upsert-source (source)
  "Add SOURCE to `el-get-sources', replacing any source with the same name.

Arguments: SOURCE is an el-get recipe plist.
Return value: SOURCE.
Side effects: mutates `el-get-sources'."
  (let ((name (el-get-source-name source)))
    (setq el-get-sources
          (cl-remove-if (lambda (candidate)
                          (string= name (el-get-source-name candidate)))
                        el-get-sources))
    (add-to-list 'el-get-sources source)
    source))

(dolist (source scs/el-get-local-sources)
  (scs/el-get-upsert-source source))

(defun scs/el-get-http-url-reachable-p (url &optional timeout)
  "Return non-nil when URL answers over HTTP within TIMEOUT seconds."
  (let ((timeout (or timeout 1)))
    (and (executable-find "curl")
         (zerop (call-process "curl" nil nil nil
                              "-sf" "--connect-timeout"
                              (number-to-string timeout)
                              "-o" null-device
                              url)))))

(defun scs/el-get-skip-unavailable-local-packages ()
  "Drop session sources that need host-local services when unavailable.

`org-web-clipper' lives on laptop Gitea (http://127.0.0.1:3000/...).  On
SmartOS and other hosts that URL fails every init: el-get marks the
package `required', then each startup does remove + reinstall + fail.
Skipping the source here and clearing a stuck `required' status stops
that thrash without deleting the recipe from init.el."
  (let ((local-gitea "http://127.0.0.1:3000/"))
    (unless (scs/el-get-http-url-reachable-p local-gitea)
      (let ((skip '("org-web-clipper")))
        (setq el-get-sources
              (cl-remove-if
               (lambda (candidate)
                 (member (el-get-source-name candidate) skip))
               el-get-sources))
        (dolist (pkg skip)
          (when (member (el-get-read-package-status pkg)
                        '("required" "removed"))
            ;; Keep a failed/partial checkout from looping forever.
            (ignore-errors
              (el-get-save-package-status pkg "removed"))
            (message
             "el-get: skipping %s (local Gitea %s not reachable)"
             pkg local-gitea)))))))

(scs/el-get-skip-unavailable-local-packages)

(defun scs/el-get-sync-status-recipes ()
  "Reconcile `.status.el' with bootstrap and declared recipes.

`el-get-self-update' compares cached status recipes against current
definitions.  When el-get itself is absent from `.status.el', the
cached recipe is nil and `el-get-package-method' treats nil as a
symbol, calls `el-get-package-def', and fails with \"recipe for
package \\\"nil\\\"\"."
  (cl-labels ((sync (package)
                 (let* ((declared (el-get-package-def package))
                        (cached (el-get-read-package-status-recipe package))
                        (cached-type (and cached (el-get-package-method cached)))
                        (declared-type (and declared (el-get-package-method declared))))
                   (when (or (not cached)
                             (not (eq cached-type declared-type)))
                     (el-get-save-package-status package "installed" declared)))))
    (when (file-directory-p (expand-file-name "el-get" el-get-dir))
      (sync "el-get"))
    (when (el-get-read-package-status-recipe "cl-lib")
      (sync "cl-lib"))))

(scs/el-get-sync-status-recipes)

;; add: 2026-07-10
(defun scs/el-get-report ()
  "Report installed el-get packages with source URL and revision."
  (interactive)
  (require 'el-get)
  (with-current-buffer (get-buffer-create "*scs el-get report*")
    (let ((inhibit-read-only t))
      (erase-buffer)
      (insert (format "# el-get report %s\n\n" (format-time-string "%F %T")))
      (dolist (pkg (sort (el-get-list-package-names-with-status "installed")
                         #'string<))
        (let* ((def (ignore-errors (el-get-package-def pkg)))
               (type (and def (el-get-package-method def)))
               (url (or (and def (plist-get def :url))
                        (and def (plist-get def :pkgname)
                             (format "github:%s" (plist-get def :pkgname)))
                        ""))
               (dir (el-get-package-directory pkg))
               (rev (when (and dir (file-directory-p (expand-file-name ".git" dir)))
                      (string-trim
                       (shell-command-to-string
                        (format "git -C %s rev-parse --short HEAD"
                                (shell-quote-argument dir)))))))
          (insert (format "%-20s  %-10s  %-40s  %s\n"
                          pkg
                          (or type "?")
                          (if (string-empty-p url) "-" url)
                          (or rev "-"))))))
    (goto-char (point-min))
    (view-mode 1)
    (display-buffer (current-buffer))))

(defun scs/el-get-package-has-recipe-p (package)
  "Return non-nil when el-get can resolve a recipe for PACKAGE.

Arguments: PACKAGE is a package name string or symbol.
Return value: non-nil when `el-get-package-def' succeeds.
Side effects: none."
  (condition-case nil
      (progn (el-get-package-def package) t)
    (error nil)))

(defun scs/el-get-prune-status-orphans ()
  "Remove installed el-get packages that no longer have a recipe.

When a recipe is deleted from `scs/el-get-local-sources' but the package
remains in `.status.el', a later `(el-get 'sync)' aborts with
\"can not find a recipe\".  That used to stop init.el before themes and
the rest of the UI loaded.  Pruning orphans keeps sync honest.

Also clears stuck `required' rows with no recipe (failed installs of
packages that were later removed from sources), without calling
`el-get-remove' when that path hits broken autoloads."
  (dolist (pkg (el-get-list-package-names-with-status "installed" "required"))
    (unless (scs/el-get-package-has-recipe-p pkg)
      (message "el-get: pruning orphan %s (no recipe in sources)" pkg)
      (let ((status (el-get-read-package-status pkg)))
        (cond
         ((string= status "required")
          ;; Avoid el-get-remove thrash/broken autoload paths for ghosts.
          (ignore-errors (el-get-save-package-status pkg "removed")))
         (t
          (ignore-errors (el-get-remove pkg))))))))

(defun scs/el-get-safe-sync (&rest packages)
  "Sync el-get packages without aborting Emacs init on failure.

Arguments: PACKAGES are optional package names; omit to sync all.
Return value: nil.
Side effects: may prune orphans and leftover packages, install/update
packages, and emit a warning if sync still fails.

This is the durable fix for \"init died before load-theme\": el-get must
never `error' out of init.el.  Prefer messages/warnings and keep going.

Why you see \"removing it first\" then reinstall: a failed package is
stored as status `required'.  The next `el-get' install path always
removes a `required' package before retrying.  That is normal el-get
behavior, not a random wipe.  Fix the underlying install error (or
remove the recipe / clear status) to stop the loop."
  (let ((el-get-is-lazy t))
    (scs/el-get-skip-unavailable-local-packages)
    (scs/el-get-prune-status-orphans)
    (condition-case err
        (scs/el-get-cleanup-unwanted)
      (error
       (message "el-get leftover cleanup failed (init continues): %s"
                (error-message-string err))))
    (condition-case err
        (apply #'el-get 'sync packages)
      (error
       (message "el-get sync failed (init continues): %s"
                (error-message-string err))
       (display-warning
        'scs-el-get
        (format "el-get sync failed (init continues): %s"
                (error-message-string err))
        :warning)))))

;; Register load-paths and autoloads for installed packages once,
;; without requiring their features.  Per-package :el-get sync below
;; only runs for packages that are not yet installed.
;; el-get-is-lazy avoids loading every package feature during this pass.
(scs/el-get-safe-sync)

;; ----------------------------------------------------------
;; use-package
;; ----------------------------------------------------------

;; use-package is built-in since Emacs 29
(defvar use-package-enable-imenu-support t
  "Non-nil lets use-package contribute entries to imenu in this init file.")
(setq use-package-always-ensure nil)
(require 'bind-key)
(require 'use-package)

(defun scs/use-package-el-get-normalize-recipe (name arg)
  "Normalize a `use-package' :el-get ARG for package NAME.

Arguments: NAME is the package declared by `use-package'; ARG is the
raw value supplied to :el-get.
Return value: nil, a package name, or an el-get recipe plist.
Side effects: none."
  (cond
   ((null arg) nil)
   ((eq arg t) name)
   ((or (symbolp arg) (stringp arg)) arg)
   ((and (consp arg) (keywordp (car arg)))
    (if (plist-member arg :name)
        arg
      (append (list :name name) arg)))
   ((and (consp arg) (or (symbolp (car arg)) (stringp (car arg))))
    (append (list :name (car arg)) (cdr arg)))
   (t
    (use-package-error
     ":el-get wants t, nil, a package name, or an el-get recipe"))))

(defun use-package-normalize/:el-get (name keyword args)
  "Normalize use-package :el-get ARGS for package NAME.

Arguments: NAME is the package declared by `use-package'; KEYWORD is
`:el-get'; ARGS is the raw argument list.
Return value: nil, a package name, or an el-get recipe plist.
Side effects: none."
  (if (null args)
      (scs/use-package-el-get-normalize-recipe name t)
    (use-package-only-one (symbol-name keyword) args
      (lambda (_label arg)
        (scs/use-package-el-get-normalize-recipe name arg)))))

(defun scs/use-package-el-get-install (name source)
  "Install SOURCE through el-get for use-package declaration NAME.

Arguments: NAME is the package declared by `use-package'; SOURCE is nil,
a package name, or an el-get recipe plist.
Return value: nil.
Side effects: may contact package archives or source repositories, update
package files, and mutate `el-get-sources'.  Errors are messaged; they do
not abort init.

Skips install when the package was intentionally dropped from
`el-get-sources' for this host (see
`scs/el-get-skip-unavailable-local-packages')."
  (ignore name)
  (when source
    (condition-case err
        (progn
          (require 'el-get)
          (when (consp source)
            (scs/el-get-upsert-source source))
          (let ((pkg (if (consp source)
                         (el-get-source-name source)
                       (el-get-as-string source))))
            (cond
             ((el-get-package-is-installed pkg)
              nil)
             ((not (scs/el-get-package-has-recipe-p pkg))
              (message
               "el-get: not installing %s (no recipe on this host)"
               pkg))
             (t
              (el-get 'sync pkg)))))
      (error
       (message "el-get install failed for %s (init continues): %s"
                name (error-message-string err))
       (display-warning
        'scs-el-get
        (format "el-get install failed for %s (init continues): %s"
                name (error-message-string err))
        :warning)))))

(defun use-package-handler/:el-get (name _keyword source rest state)
  "Generate code to install NAME through el-get using SOURCE.

Arguments: NAME is the package declared by `use-package'; _KEYWORD is
ignored; SOURCE is the normalized :el-get value; REST and STATE are the
remaining use-package keyword data.
Return value: a list of forms for the expanded `use-package' declaration.
Side effects: may install packages while byte-compiling."
  (let ((body (use-package-process-keywords name rest state)))
    (when source
      (if (bound-and-true-p byte-compile-current-file)
          (scs/use-package-el-get-install name source)
        (push `(scs/use-package-el-get-install ',name ',source) body)))
    body))

(unless (memq :el-get use-package-keywords)
  ;; Teach use-package about :el-get so declarations can install via el-get.
  (setq use-package-keywords
        (use-package-list-insert :el-get use-package-keywords :vc)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; General settings
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Emacs-wide defaults that are not tied to a single third-party package:
;; server and frames, encoding, what runs before save, dired, and spelling tools.

;; ----------------------------------------------------------
;; Server
;; ----------------------------------------------------------
;;
;; server-start lets emacsclient attach to this session.  On macOS we also
;; start a TCP server for Scrim, which requires the auth file server/server.
;; The listeners can share the basename "server": one is a Unix socket under
;; `server-socket-dir', while the other is a TCP auth file under the explicit
;; directory below.  Their process state must remain separate.

(require 'server)
(unless (server-running-p) (server-start))

(defconst scs/scrim-server-name "server"
  "Server name required by Scrim for its macOS-only TCP auth file.")

(defconst scs/scrim-server-auth-dir
  (expand-file-name "server/" user-emacs-directory)
  "Authentication directory required by Scrim.

Scrim 1.1.3 accepts only a shared-secret file named `server' inside a
directory also named `server'.  Keep this explicit because no-littering
changes the global value of `server-auth-dir' later during startup.")

(defvar scs/scrim-server-process nil
  "Network process for the Scrim TCP server, or nil.

Emacs normally tracks one server in `server-process'.  The Scrim TCP
listener is kept here so starting it does not replace the default Unix
socket listener used by plain emacsclient.")

(defun scs/start-scrim-server ()
  "Start the named Scrim TCP server on macOS without replacing the socket server.

Return the owned TCP server process, or nil when an external server with
the same name is already running.  No-op outside macOS."
  (when (eq system-type 'darwin)
    (let ((expected-file
           (expand-file-name scs/scrim-server-name
                             scs/scrim-server-auth-dir)))
      ;; Migrate a listener created by an older configuration.  A normal
      ;; config reload leaves an already-correct listener undisturbed.
      (when (and scs/scrim-server-process
                 (not (equal
                       (process-get scs/scrim-server-process :server-file)
                       expected-file)))
        (scs/stop-scrim-server))
      (if (process-live-p scs/scrim-server-process)
          scs/scrim-server-process
        ;; `server-start' restarts the process in `server-process'.  Bind that
        ;; state separately so the default Unix socket remains alive.
        (let ((server-name scs/scrim-server-name)
              (server-auth-dir scs/scrim-server-auth-dir)
              (server-use-tcp t)
              (server-process nil))
          ;; For TCP, `server-running-p' returns :other for a stale auth
          ;; file whose recorded PID no longer exists.  Only t establishes
          ;; that another live process owns this dedicated endpoint.
          (if (eq t (server-running-p server-name))
              (setq scs/scrim-server-process nil)
            ;; Startup and migration are configuration operations; do not
            ;; block a reload behind `server-start's client prompt.
            (server-start nil t)
            (setq scs/scrim-server-process server-process)))))))

(defun scs/stop-scrim-server ()
  "Stop the Scrim TCP server owned by this Emacs process.

This is an exit hook.  It removes the TCP authentication file while the
default server cleanup independently removes the Unix socket."
  (when scs/scrim-server-process
    ;; Do not call `server-stop' here: `server-clients' is shared by both
    ;; listeners, so it would also disconnect ordinary emacsclient frames.
    (let ((server-file
           (process-get scs/scrim-server-process :server-file)))
      (when (process-live-p scs/scrim-server-process)
        (delete-process scs/scrim-server-process))
      (when (and server-file (file-exists-p server-file))
        (let (delete-by-moving-to-trash)
          (delete-file server-file)))
      (setq scs/scrim-server-process nil))))

(scs/start-scrim-server)
(add-hook 'kill-emacs-hook #'scs/stop-scrim-server)

;; ----------------------------------------------------------
;; Column numbers
;; ----------------------------------------------------------

(setq column-number-mode t)

;; ----------------------------------------------------------
;; Auto-revert
;; ----------------------------------------------------------

;; Reload a buffer if it was changed by some other process
(global-auto-revert-mode t)
(setq global-auto-revert-non-file-buffers t)

;; ----------------------------------------------------------
;; Pixel scroll (GUI only)
;; ----------------------------------------------------------

;; Make scrolling smoother
(when (and (not (version< emacs-version "29.1"))
           (display-graphic-p))
  (pixel-scroll-precision-mode))

;; ----------------------------------------------------------
;; UTF-8, fill column, delete-selection, clipboard
;; ----------------------------------------------------------

;; Prefer UTF-8
(prefer-coding-system 'utf-8)

;; Default line length (mail-friendly 72; was 70)
(setq-default fill-column 72)
(global-set-key (kbd "C-c q") #'set-fill-column) ; was C-x f

;; Overwrite selected text when typing
(delete-selection-mode t)

;; insert the contents of the system clipboard into the current buffer.
;; C-y will only insert the Emacs clipboard
;; This has benefit of keeping Emacs and host OS separate.
(setq select-enable-clipboard t) ;; Usually t
(setq select-enable-primary nil) ;; Usually nil

(global-set-key (kbd "C-c y") 'clipboard-yank)
;; (global-set-key (kbd "C-c k") 'clipboard-kill-region)

;; ----------------------------------------------------------
;; Final newline / trailing whitespace
;; ----------------------------------------------------------

;; Ensure that files end with a new line and contain no trailing whitespace
;; on owned local text.  Skip remote, huge, and patch-like buffers.
(setq require-final-newline t)
;; fix: 2026-07-10 — predicate instead of global delete-trailing-whitespace
(defun scs/delete-trailing-whitespace-maybe ()
  "Delete trailing whitespace on save for ordinary local text buffers.

Skips TRAMP paths, buffers over 1 MiB, diff/change-log/comint, and
git-commit buffers so we do not fight tools or mangle huge logs."
  (unless (or (and buffer-file-name (file-remote-p buffer-file-name))
              (> (buffer-size) (* 1024 1024))
              (derived-mode-p 'diff-mode 'change-log-mode 'comint-mode)
              (and (boundp 'git-commit-mode) git-commit-mode))
    (delete-trailing-whitespace)))
(add-hook 'before-save-hook #'scs/delete-trailing-whitespace-maybe)

;; Team file headers (Org, Elisp, Lisp) may carry LAST-UPDATED / Last-Updated.
;; On save we refresh that field only when it already exists; we never invent
;; a new header line from whole cloth (logic lives in lisp/scs-file-header.el).
(autoload 'scs/update-last-updated-on-save "scs-file-header"
  "Refresh an existing LAST-UPDATED / Last-Updated field in the preamble."
  nil)
(add-hook 'before-save-hook #'scs/update-last-updated-on-save)

;; ----------------------------------------------------------
;; Show-paren, indent tabs, sentence double-space
;; ----------------------------------------------------------

;; Mark matching pairs of parentheses
(show-paren-mode t)
(setq show-paren-delay 0.0)

;; Prevent extraneous tabs
(setq-default indent-tabs-mode nil)

;; A sentence is signalled by a double space.
(setq sentence-end-double-space t)

;; ----------------------------------------------------------
;; History length
;; ----------------------------------------------------------
;;
;; Minibuffer histories honor `history-length'.  The rings below
;; have their own max variables; keep each at least 1000 so savehist
;; can restore a useful slice of kill, mark, and search state.

(setq-default history-length 10000)

(setq kill-ring-max 1000
      mark-ring-max 1000
      search-ring-max 1000
      regexp-search-ring-max 1000)

;; ----------------------------------------------------------
;; Minibuffer completion
;; ----------------------------------------------------------

;; Vertico owns minibuffer completion (see the vertico use-package
;; block).  Keep built-in Fido off so it cannot fight Vertico.
(when (fboundp 'fido-vertical-mode)
  (fido-vertical-mode -1))

;; ----------------------------------------------------------
;; Dired settings
;; ----------------------------------------------------------

(setq dired-kill-when-opening-new-dired-buffer t)

;; Dired wants an ls that supports --dired so unusual names parse safely.
;; Stock ls on macOS (BSD) and SmartOS/Illumos (system-type usg-unix-v)
;; does not.  GNU coreutils installs as `gls' via Homebrew (macOS) or
;; pkgsrc (SmartOS).  Emacs 31 only auto-picks gls for darwin and
;; berkeley-unix while files.el loads, so SmartOS never gets that
;; default, and a thin early PATH can miss the macOS probe too.  Prefer
;; gls wherever it exists, then let Dired re-probe --dired next listing.
(when-let* ((gls (executable-find "gls")))
  (setq insert-directory-program gls)
  (setq dired-use-ls-dired 'unspecified))

;; ----------------------------------------------------------
;; Input method
;; ----------------------------------------------------------

;; M-x list-input-methods
;; Display a list of all the supported input methods.

;; Activate TeX input at startup in graphical and terminal Emacs.  Its
;; backslash-led sequences leave ordinary apostrophes and hyphens alone;
;; C-\ still toggles the method for the current buffer.
(setq default-input-method "TeX")
(add-hook 'after-init-hook
          (lambda () (activate-input-method default-input-method)))

;;   TeX ('\' in the mode line) -- quail/latin-ltx
;;   A backslash introduces LaTeX-like character names and accents.
;;
;;    effect      | examples
;;   -------------+--------------------------------------
;;    acute       | \'e -> é   \'a -> á
;;    grave       | \`e -> è   \`a -> à
;;    circumflex  | \^e -> ê   \^a -> â
;;    diaeresis   | \"u -> ü   \"a -> ä
;;    tilde       | \~n -> ñ   \~a -> ã
;;    cedilla     | \cc -> ç
;;    names       | \pi -> π   \int -> ∫
;;    backslash   | \\ -> \
;;


;; ----------------------------------------------------------
;; Visual-line-mode hook for text-mode
;; ----------------------------------------------------------

(add-hook 'text-mode-hook #'visual-line-mode)

;; ----------------------------------------------------------
;; External tools (aspell, ripgrep, fd)
;; ----------------------------------------------------------
;; aspell remains the ispell/flyspell backend when those are invoked by
;; hand.  Day-to-day checking is jinx + Enchant (see the jinx
;; use-package block).  Keep both so the older path stays usable.

(when (executable-find "aspell")
  (setq ispell-program-name "aspell"
        ispell-local-dictionary "en_GB-ise"
        ispell-dictionary "en_GB-ise"
        ispell-local-dictionary-alist
        '(("en_GB-ise" "[[:alpha:]]" "[^[:alpha:]]" "[']" nil ("-d" "en_GB-ise") nil utf-8))
        ispell-extra-args '("--sug-mode=ultra" "--lang=en_GB-ise.multi")))

(setq flyspell-issue-message-flag nil)

(setq dictionary-default-dictionary "*")
(setq dictionary-server "dict.org")
(setq dictionary-use-single-buffer t)

;; Prefer ripgrep and fd when installed, without treating them as POSIX
;; grep/find drop-ins.  Syntax boundaries we honor:
;; - rgrep still builds find(1) -name/-path/-prune expressions; fd speaks
;;   a different language (-e/-t/-g, regex by default).  Keep find-program
;;   as "find" for rgrep/find-dired; use fd only via fd-dired and consult-fd.
;; - xref-search-program 'ripgrep uses the rg-shaped entry in
;;   xref-search-program-alist (not grep -r flags).
;; - grep/rgrep templates below keep find for file selection and swap only
;;   the content matcher to rg (-nH --null --no-heading; no grep --include).
(defun scs/fd-executable ()
  "Return fd or Debian fd-find's fdfind, or nil if neither is on `exec-path'."
  (or (executable-find "fd")
      (executable-find "fdfind")))

(defun scs/setup-search-tools ()
  "Point xref/grep at ripgrep, and fd-aware UIs at fd, when available.

Call once at init.  Safe to call again after PATH/`exec-path' changes.
Leaves stock find(1) as `find-program' so find-expression commands keep
working; see comments above this function for the syntax split."
  (cond
   ((executable-find "rg")
    (require 'grep)
    (setq xref-search-program 'ripgrep)
    ;; grep-apply-setting records host defaults so later
    ;; grep-compute-defaults does not restore POSIX grep commands.
    (grep-apply-setting
     'grep-command
     "rg -nH --null --no-heading -e ")
    (grep-apply-setting
     'grep-template
     "rg <X> <C> -nH --null --no-heading -e <R> <F>")
    (grep-apply-setting
     'grep-find-command
     '("find . -type f -print0 | xargs -0 rg -nH --null --no-heading -e " . 64))
    (grep-apply-setting
     'grep-find-template
     "find -H <D> <X> -type f <F> -print0 | xargs -0 rg <C> -nH --null --no-heading -e <R>"))
   ((executable-find "ugrep")
    ;; Fallback when rg is missing (older hosts); ugrep speaks its own flags.
    (setq xref-search-program 'ugrep)))
  (when-let* ((fd (scs/fd-executable)))
    ;; fd-dired reads this; set whenever the feature is loaded.
    (setq fd-dired-program fd)))

(scs/setup-search-tools)
(with-eval-after-load 'fd-dired
  (when-let* ((fd (scs/fd-executable)))
    (setq fd-dired-program fd)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Custom file
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Configuration-as-code: we do not let Customize write into the Git tree.
;; Setting custom-file to a temp path satisfies packages that expect the
;; variable to be set; the file is disposable and is never loaded on purpose.
;; Copy any wanted values from Customize into init.el or lisp/ by hand.

(setq custom-file (expand-file-name "custom.el" temporary-file-directory))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Settings formerly in custom.el
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Values that once lived in a persisted custom.el file, kept here so the
;; repo remains the single source of truth.  Theme lives under Frame / UI.
;; GUI home screen is curated by lisp/scs-startup-state.el (not desktop.el).
;; Normal startup: *scratch* in one window.  C-u M-x scs/startup-state-apply
;; opens the legacy progress-todo / init.el split.

(blink-cursor-mode -1)
(size-indication-mode t)

;; Curated GUI home screen (not desktop.el).  Terminal Emacs no-ops
;; inside scs/startup-state-apply via display-graphic-p.
(scs/startup-state-enable)

(setq byte-compile-error-on-warn nil)
(setq org-ql-search-directories-files-recursive t)
(setq org-safe-remote-resources
      '("\\`https://cdn\\.britannica\\.com/s:800x450,c:crop/66/195966-138-F9E7A828/facts-turtles\\.jpg\\'"))
(setq safe-local-variable-values
      '((tab . 4) (var . value) (Base . 10) (Package . CL-USER)
        (Syntax . COMMON-LISP)))
(setq windmove-wrap-around nil)

;; ----------------------------------------------------------
;; Frame / UI
;; ----------------------------------------------------------
;; Theme, font, and tool-bar.  Stays in init.el (not early-init): during
;; early-init the initial frame does not exist yet, so display-graphic-p
;; is always nil even for GUI Emacs.  See insights.org.

(defun scs/apply-ui-theme (&optional frame)
  "Load the GUI or terminal color theme for FRAME.

GUI frames use `adwaita'; TTY frames (emacs -nw, emacsclient -t, SSH)
use the built-in `misterioso' theme, which reads well on 256-color
terminals.  Themes are process-global: if one daemon serves both GUI
and TTY clients, the most recently created frame's kind wins.  Local
GUI and remote SSH Emacs are separate processes, so they do not
interfere."
  (let ((frame (or frame (selected-frame))))
    (when (frame-live-p frame)
      (with-selected-frame frame
        (if (display-graphic-p frame)
            (load-theme 'adwaita t)
          (load-theme 'misterioso t))))))

(defun scs/apply-default-font (&optional frame)
  "Apply the standard GUI font to FRAME, or globally when FRAME is nil.

emacsclient frames are created after init, often when `display-graphic-p'
was nil during daemon startup, so font must be applied per frame."
  (let ((ws (if frame (frame-parameter frame 'window-system) window-system)))
    (when (memq ws '(ns mac win32 pgtkf))
      ;; A nil FRAME means all existing frames and the default for new ones.
      (set-face-attribute 'default frame
                          :family "Menlo"
                          :height 180
                          :weight 'normal
                          :width 'normal))))

;; Daemon/emacsclient frames are created after init; re-apply so a
;; headless daemon still gets the right theme/font on the first client.
(scs/apply-ui-theme)
(add-hook 'after-make-frame-functions #'scs/apply-ui-theme)
(add-hook 'after-make-frame-functions #'scs/apply-default-font)

(when (display-graphic-p)
  (tool-bar-mode -1))

(when (eq system-type 'darwin)
  (scs/apply-default-font nil))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Keybindings
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Chords that should feel the same in every buffer.  macOS Hyper bindings
;; depend on Karabiner and early-init modifier remaps; see comments in each block.

;; ----------------------------------------------------------
;; macOS modifier keys
;; ----------------------------------------------------------

;; mac-command-modifier etc. are set in early-init.el (before window-system
;; init).  Karabiner rewrites stolen Fn chords inside Emacs to C-M-s-*
;; proxies (see karabiner.json): Fn+C would open Control Center, Fn+H
;; would Show Desktop (Apple: Command-Mission Control / Fn-H / Fn-F11).
;; Lowercase s is Super, not Shift.
(when (eq system-type 'darwin)
  (define-key key-translation-map (kbd "C-M-s-c") (kbd "H-c"))
  (define-key key-translation-map (kbd "C-M-s-h") (kbd "H-h")))

;; Another possibility would be to define each one separately
;; (define-key key-translation-map (kbd "C-M-S-s") (kbd "H"))
;; (define-key function-key-map (kbd "C-c H") 'event-apply-hyper-modifier)

;; ----------------------------------------------------------
;; Hyper key shortcuts (macOS only, via Karabiner)
;; ----------------------------------------------------------

(defvar scs/minibuffer-allow-repeat-commands nil
  "Commands that may re-enter their own minibuffer instead of quitting.

The default policy is: a second press of the same M-x, find-file,
or Consult command dismisses that prompt.  A *different* command
from inside a prompt still runs -- so minibuffer M-s
(`consult-history') works during M-x, because
`current-minibuffer-command' is not `consult-history'.  Put a
symbol here only if that command must nest *itself*.")

(defun scs/minibuffer-toggle-command-p (command)
  "Return non-nil when COMMAND is M-x, find-file, or a Consult command.

Internal `consult--...' helpers are excluded: they are not keys.
`scs/consult-history' is included so C-c h toggles like the rest."
  (and (symbolp command)
       (not (memq command scs/minibuffer-allow-repeat-commands))
       (or (memq command '(execute-extended-command
                           execute-extended-command-for-buffer
                           find-file
                           scs/consult-history))
           (let ((name (symbol-name command)))
             (and (string-prefix-p "consult-" name)
                  (not (string-prefix-p "consult--" name)))))))

(defun scs/minibuffer-same-command-p (this owner)
  "Return non-nil if THIS is a second press of OWNER's minibuffer command.

Wrappers share an identity with the command they run: C-c h and
minibuffer M-s both count as `consult-history'."
  (or (eq this owner)
      (and (memq this '(consult-history scs/consult-history))
           (memq owner '(consult-history scs/consult-history)))))

(defun scs/quit-duplicate-minibuffer-command ()
  "Quit when the user re-invokes the command that owns this minibuffer.

Runs from `pre-command-hook'.  M-x, find-file, and Consult-style
commands are included (see `scs/minibuffer-toggle-command-p').
Invoking a different command from inside a prompt (history,
Embark) is left alone."
  (when (and (minibufferp)
             (scs/minibuffer-toggle-command-p current-minibuffer-command)
             (scs/minibuffer-same-command-p this-command
                                            current-minibuffer-command))
    (abort-minibuffers)))

(add-hook 'pre-command-hook #'scs/quit-duplicate-minibuffer-command)

(when (eq system-type 'darwin)
  ;;              key          command                   ;; mnemonic
  (global-set-key (kbd "H-x") #'execute-extended-command) ;; eXecute (Vertico)
  (global-set-key (kbd "H-f") #'find-file)                ;; File (toggle)
  (global-set-key (kbd "H-b") #'consult-buffer)           ;; Buffer (toggle)
  (global-set-key (kbd "H-k") 'kill-current-buffer)      ;; Kill
  (global-set-key (kbd "H-h") #'scs/hyper-h-rubout)     ;; rub out sentence, then line
  (global-set-key (kbd "H-s") 'save-buffer)              ;; Save
  (global-set-key (kbd "H-r") 'revert-buffer-quick)      ;; Revert
  ;; Same command as ESC ESC ESC.  Also deactivates the region and can
  ;; delete other windows; that is stock `keyboard-escape-quit'.
  (global-set-key (kbd "H-g") #'keyboard-escape-quit)    ;; Get out
  (global-set-key (kbd "H-n") 'next-error)               ;; Next
  (global-set-key (kbd "H-p") 'previous-error)           ;; Previous
  (global-set-key (kbd "H-z") 'eshell-toggle)            ;; Z-shell
  (global-set-key (kbd "H-o") 'other-window)             ;; Other
  (global-set-key (kbd "H-w") 'delete-frame)             ;; Window
  (global-set-key (kbd "H-0") 'delete-window)            ;; 0 windows
  (global-set-key (kbd "H-1") 'delete-other-windows)     ;; 1 window
  (global-set-key (kbd "H-2") 'split-window-below)       ;; 2 horiz
  (global-set-key (kbd "H-3") 'split-window-right)       ;; 3 vert
  (global-set-key (kbd "H-t") 'my/tramp-cleanup)         ;; Tramp
  (define-prefix-command 'scs/hyper-c-prefix-map)
  (global-set-key (kbd "H-c") 'scs/hyper-c-prefix-map)
  (define-key scs/hyper-c-prefix-map (kbd "c") 'org-capture) ;; Capture
  ;; org-tools autoloads live under Local libraries (lisp/) above.
  (define-key scs/hyper-c-prefix-map (kbd "d") #'scs/org-insert-creation-date)
  (define-key scs/hyper-c-prefix-map (kbd "H-d") #'scs/org-insert-creation-date)
  (define-key scs/hyper-c-prefix-map (kbd "h") #'scs/org-ensure-buffer-header) ;; Header
  (define-key scs/hyper-c-prefix-map (kbd "R") #'scs/rename-visited-file-to-name-at-point) ;; Rename
  (define-key scs/hyper-c-prefix-map (kbd "v") #'scs/convert) ;; conVert
  ;; Path: absolute by default; C-u H-c p prompts for format (relative, truename, ...).
  (define-key scs/hyper-c-prefix-map (kbd "p") #'scs/copy-path) ;; Path
  (global-set-key (kbd "C-c M-v") #'scs/reveal-file) ;; Reveal in Finder / Dired
  (global-set-key (kbd "H-a") 'org-agenda)               ;; Agenda
  (global-set-key (kbd "H-l") 'org-store-link)           ;; Link
  (global-set-key (kbd "H-i") #'consult-imenu)            ;; Imenu
  (global-set-key (kbd "H-j") 'avy-goto-char-timer))     ;; Jump (avy)

;; ----------------------------------------------------------
;; C-c w (compare-windows)
;; ----------------------------------------------------------

(global-set-key "\C-cw" 'compare-windows)

;; ----------------------------------------------------------
;; C-x C-b (ibuffer) :vip:
;; ----------------------------------------------------------

;; By default, C-x C-b runs the list-buffers command. This command lists your
;; buffers in another window. Since I almost always want to do something in that
;; window, I prefer the buffer-menu command, which not only lists the buffers,
;; but moves point into that window.

;; (global-set-key "\C-x\C-b" 'buffer-menu)

;; ibuffer is better than buffer-menu
(global-set-key [remap list-buffers] 'ibuffer)

;; ----------------------------------------------------------
;; Rub-out (C-h) vs Delete (C-d / Fn-Backspace)
;; ----------------------------------------------------------

;; Greybeard keys (keep them distinct):
;; - Rub-out -- before point: C-h and physical Backspace (`DEL').
;; - Delete  -- after point:  C-d and Fn-Backspace (`<deletechar>').
;;
;; Goal for C-h: rub out by default, but local maps that bind C-h for
;; help (Embark during embark-act, and similar) must still see the real
;; C-h event.
;;
;; Why not key-translation-map C-h -> DEL?  Translation rewrites the event
;; before any keymap runs, so package C-h bindings never fire.  That is
;; why Embark help looked "broken" under the old one-way translation.
;;
;; Instead:
;; 1. Move help-char off C-h so the command loop does not treat C-h as
;;    the global help character (prefix help, help-form, and friends).
;;    C-\\ is already toggle-input-method here, so use C-^ instead.
;; 2. Bind C-h in the global map to rub-out.  Active minor/local maps that
;;    bind C-h (Embark, etc.) override this while they are active.
;; tip: Tab is available as C-i
;;      RET is available as C-j or C-m
;;      ESC is available as C-[

(setq help-char ?\C-^)
(global-set-key (kbd "C-^") #'help-command)
(global-set-key (kbd "C-h") #'delete-backward-char)
(global-set-key (kbd "<f1>") #'help-command)

;; Delete after point (not rub-out).  macOS Fn-Backspace is <deletechar>.
(global-set-key (kbd "C-d") #'scs/delete-forward)
(global-set-key (kbd "<deletechar>") #'scs/delete-forward)
(global-set-key (kbd "<delete>") #'scs/delete-forward)

;; map M-h [mark-paragraph] to M-backspace
(define-key key-translation-map [?\M-h] [?\M-\d])

;; TODO: [mark-paragraph] may be useful

;; ----------------------------------------------------------
;; C-x C-c protection
;; ----------------------------------------------------------

;; Plain C-x C-c is disabled to prevent accidental quit; show the real chords.
(defvar scs/quit-map
  (let ((map (make-sparse-keymap "Quit Emacs")))
    (define-key map (kbd "C-c") 'save-buffers-kill-terminal)
    (define-key map (kbd "q") 'keyboard-escape-quit)
    map)
  "Transient keymap confirming quit after the initial C-x C-c press.")

(defun scs/quit-hint ()
  "Show how to quit or cancel after C-x C-c."
  (interactive)
  (message "Quit: C-x C-c C-c  |  Cancel: C-x C-c q"))

(defun scs/quit-prefix ()
  "Show quit hint, then accept C-c or q to confirm."
  (interactive)
  (scs/quit-hint)
  (set-transient-map scs/quit-map nil nil))

(global-set-key (kbd "C-x C-c") #'scs/quit-prefix)

;; With mac-command-modifier, use ⌘ x, ⌘ c, ⌘ c for quit.

;; ----------------------------------------------------------
;; C-o / M-o (window/frame navigation)
;; ----------------------------------------------------------

(global-set-key (kbd "C-o") 'other-window) ;; was 'open-line
(global-set-key (kbd "M-o") 'other-frame) ;; was unused

;; ----------------------------------------------------------
;; S-mouse-3 (imenu, GUI only) :gem:
;; ----------------------------------------------------------

(cond (window-system
       (define-key global-map [S-mouse-3] 'imenu)))

;; ----------------------------------------------------------
;; C-% (goto-match-paren)
;; ----------------------------------------------------------

(global-set-key (kbd "C-%") 'goto-match-paren)

;; ----------------------------------------------------------
;; keyboard-quit remap
;; ----------------------------------------------------------

(global-set-key [remap keyboard-quit] #'prot/keyboard-quit-dwim)

;; S-f9 inserts an inactive Org timestamp in org-mode buffers (howm uses f9).

(define-key global-map (kbd "<S-f9>")
  (lambda () (interactive)
    (when (eq major-mode 'org-mode)
      (org-insert-timestamp nil nil :inactive " " " pds"))))

;; Example of timestamp
;; (org-insert-timestamp nil nil :inactive "Date: " " pdn")


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Packages (alphabetical, with dependency exceptions noted)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Each block uses use-package.  :el-get pulls from el-get recipes above.
;; no-littering must run first so var/ paths exist before other packages write
;; state under ~/.emacs.d or equivalent.

;; ----------------------------------------------------------
;; no-littering
;; ----------------------------------------------------------
;; https://github.com/emacscollective/no-littering
;; This MUST COME FIRST

(use-package no-littering
  :el-get t
  :init
  (let ((dir (no-littering-expand-var-file-name "lock-files/")))
    (make-directory dir t)
    (setq lock-file-name-transforms `((".*" ,dir t))))
  (no-littering-theme-backups))


;; ----------------------------------------------------------
;; abbrev
;; ----------------------------------------------------------

(use-package abbrev
  :init
  ;; `abbrev-mode' is buffer-local; new buffers inherit its default value.
  (setq-default abbrev-mode t))

;; ----------------------------------------------------------
;; calendar
;; ----------------------------------------------------------

;; Use ISO calendar (YYYY-MM-DD)
(use-package calendar
  :config (calendar-set-date-style 'iso))

;; ----------------------------------------------------------
;; cape
;; ----------------------------------------------------------

(use-package cape
  :el-get t
  :defer 2
  :bind (:prefix-map
         my-cape-map
         :prefix "C-c ."
         ("p" . completion-at-point)
         ("t" . complete-tag)
         ("d" . cape-dabbrev)
         ("h" . cape-history)
         ("f" . cape-file)
         ("k" . cape-keyword)
         ("s" . cape-elisp-symbol)
         ("a" . cape-abbrev)
         ("l" . cape-line)
         ("w" . cape-dict)
         ("\\" . cape-tex)
         ("_" . cape-tex)
         ("^" . cape-tex)
         ("&" . cape-sgml)
         ("r" . cape-rfc1345))
  :init
  ;; Add `completion-at-point-functions', used by `completion-at-point'.
  (add-to-list 'completion-at-point-functions #'cape-dabbrev)
  (add-to-list 'completion-at-point-functions #'cape-file)
  (add-to-list 'completion-at-point-functions #'cape-abbrev))

;; ----------------------------------------------------------
;; yasnippet
;; ----------------------------------------------------------

;; https://github.com/joaotavora/yasnippet
(use-package yasnippet
  :el-get t
  :defer 2
  :init
  (setq yas-verbosity 2)
  :config
  (let ((dir (expand-file-name "snippets" user-emacs-directory)))
    (make-directory dir t)
    (add-to-list 'yas-snippet-dirs dir))
  (yas-global-mode 1))

;; ----------------------------------------------------------
;; company (active in-buffer completion UI; Vertico owns the minibuffer)
;; ----------------------------------------------------------

(use-package company
  :el-get t
  :defer 2
  :config
  ;; SLIME capf signals "Not connected." when company-capf runs without a
  ;; live LispWorks session; cape and M-TAB still work in slime-mode.
  (require 'company-capf)
  (require 'company-yasnippet)
  (add-to-list 'company-capf-disabled-functions 'slime--completion-at-point)
  (add-to-list 'company-backends 'company-yasnippet)
  (setq company-selection-default nil)
  (setq company-minimum-prefix-length 3)
  (setq company-selection-wrap-around t)
  (setq company-transformers
        '(company-sort-by-occurrence
          company-sort-by-backend-importance))
  (setq company-frontends
        '(company-pseudo-tooltip-frontend
          company-preview-frontend
          company-echo-metadata-frontend))

  (defun my-company-return ()
    "Complete the selected Company candidate, or fall back to normal RET."
    (interactive)
    (if company-selection
        (company-complete-selection)
      (let ((default-return (key-binding (kbd "RET"))))
        (if default-return
            (call-interactively default-return)
          (newline-and-indent)))))

  (define-key company-active-map (kbd "RET") #'my-company-return)

  (global-company-mode))

;; ----------------------------------------------------------
;; delight
;; ----------------------------------------------------------

(use-package delight :el-get t)

(use-package emacs
  :delight
  (auto-fill-function " AF")
  (visual-line-mode)
  (lisp-mode)
  (eldoc-mode)
  (auto-revert-mode)
  (outline-minor-mode))

;; ----------------------------------------------------------
;; exec-path-from-shell (macOS only)
;; ----------------------------------------------------------

(use-package exec-path-from-shell
  :el-get t
  :if (eq system-type 'darwin)
  :init
  (exec-path-from-shell-initialize)
  (exec-path-from-shell-copy-envs '("LIBRARY_PATH" "INFOPATH" "CPATH" "MANPATH")))

;; ----------------------------------------------------------
;; eshell
;; ----------------------------------------------------------

(use-package eshell
  :commands (eshell eshell-command)
  :custom
  (eshell-directory-name (locate-user-emacs-file "var/eshell/"))
  (eshell-hist-ignoredups t)
  (eshell-history-size 50000)
  (eshell-ls-dired-initial-args '("-h"))
  (eshell-ls-exclude-regexp "~\\'")
  (eshell-ls-initial-args "-h")
  (eshell-modules-list
   '(eshell-alias
     eshell-basic
     eshell-cmpl
     eshell-dirs
     eshell-glob
     eshell-hist
     eshell-ls
     eshell-pred
     eshell-prompt
     eshell-rebind
     eshell-script
     eshell-term
     eshell-unix
     eshell-xtra))
  (eshell-prompt-function
   (lambda nil
     (concat
      (or (file-remote-p default-directory 'host)
          (system-name))
      ":"
      (abbreviate-file-name (eshell/pwd))
      (if (= (user-uid) 0)
          " # " " $ "))))
  (eshell-prompt-regexp "^[^#$\n]* [#$] ")
  (eshell-rebind-keys-alist
   '(([(control ?a)] . eshell-bol)
     ([home]         . eshell-bol)
     ([(control ?d)] . eshell-delchar-or-maybe-eof)
     ([backspace]    . eshell-delete-backward-char)
     ([delete]       . eshell-delete-backward-char)))
  (eshell-save-history-on-exit t)
  (eshell-stringify-t nil)
  (eshell-term-name "ansi")
  (eshell-visual-commands
   '("vi" "top" "htop" "screen" "less" "lynx" "rlogin" "telnet" "ssh"))
  :preface
  (defvar eshell-isearch-map
    (let ((map (copy-keymap isearch-mode-map)))
      (define-key map [(control ?m)] 'eshell-isearch-return)
      (define-key map [return]       'eshell-isearch-return)
      (define-key map [(control ?r)] 'eshell-isearch-repeat-backward)
      (define-key map [(control ?s)] 'eshell-isearch-repeat-forward)
      (define-key map [(control ?g)] 'eshell-isearch-abort)
      (define-key map [backspace]    'eshell-isearch-delete-char)
      (define-key map [delete]       'eshell-isearch-delete-char)
      map)
    "Keymap used in isearch in Eshell.")

  (defun eshell-spawn-external-command (beg end)
    "Parse and expand any history references in current input."
    (save-excursion
      (goto-char end)
      (when (looking-back "&!" beg)
        (delete-region (match-beginning 0) (match-end 0))
        (goto-char beg)
        (insert "spawn "))))

  (defun eshell-initialize ()
    "Set up eshell input expansion and unbind Tramp su/sudo wrappers."
    (add-hook 'eshell-expand-input-functions #'eshell-spawn-external-command)

    (use-package em-unix
      :defer t
      :config
      ;; Use the system su/sudo instead of Emacs's built-in Tramp wrappers
      (unintern 'eshell/su nil)
      (unintern 'eshell/sudo nil)))
  :init
  (add-hook 'eshell-first-time-mode-hook #'eshell-initialize)
  :config
  (require 'em-alias)
  (eshell/alias "ll"  "ls -lh $*")
  (eshell/alias "la"  "ls -lAh $*")
  (eshell/alias "ff"  "find-file $1")
  (eshell/alias "d"   "dired $1")
  (eshell/alias "cls" "clear-scrollback"))

(use-package eshell-toggle
  :el-get t
  :bind ("C-x C-z" . eshell-toggle))

(use-package eshell-bookmark
  :el-get t
  :hook (eshell-mode . eshell-bookmark-setup))

(use-package eshell-up
  :el-get t
  :commands eshell-up)

(use-package eshell-z
  :el-get t
  :after eshell)

;; ----------------------------------------------------------
;; flycheck
;; ----------------------------------------------------------

(use-package flycheck
  :el-get t
  :defer 3
  :config
  (require 'flycheck-org-lint-workaround)
  (scs/flycheck-setup-org-lint-workaround)
  (global-flycheck-mode))

;; ----------------------------------------------------------
;; flyspell
;; ----------------------------------------------------------

(use-package flyspell
  :unless (eq window-system 'w32)
  :commands (flyspell-prog-mode flyspell-mode)
;;  :hook ((text-mode . flyspell-mode)
;;        (prog-mode . flyspell-prog-mode))
  )

;; ----------------------------------------------------------
;; framemove
;; ----------------------------------------------------------

;; https://www.emacswiki.org/emacs/FrameMove
;; https://github.com/emacsmirror/emacswiki.org/blob/master/framemove.el
;; not on melpa
;; https://trey-jackson.blogspot.com/2010/02/emacs-tip-35-framemove.html
(use-package framemove
  :el-get t
  :init
  (windmove-default-keybindings)
  (setq framemove-hook-into-windmove t))

;; ----------------------------------------------------------
;; embark
;; ----------------------------------------------------------

;; Contextual actions on the thing at point or the current minibuffer
;; candidate.  Already pulled in for gitea.el; bind the usual act chord
;; so it is usable outside Gitea buffers too.
(use-package embark
  :el-get t
  :bind (("C-." . embark-act)))

;; ----------------------------------------------------------
;; gitea (el-get package; talks to the local Gitea /api/v1)
;; ----------------------------------------------------------
;; Source: https://github.com/scsets/gitea.el
;; Token is read from ~/.config/gitea/access-token when present -- not
;; hardcoded in this file.

(defun scs/gitea-token-from-config ()
  "Return the Gitea API token from ~/.config/gitea/access-token, or nil.

Reads the first line of that file when it is readable.  Used so init.el
never embeds a secret, while still letting `gitea.el' authenticate to
the local instance."
  (let ((file (expand-file-name "~/.config/gitea/access-token")))
    (when (file-readable-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (string-trim (buffer-substring-no-properties
                      (point-min)
                      (line-end-position)))))))

(use-package gitea
  :el-get t
  :commands (gitea gitea-api-browse gitea-api-execute gitea-create-token)
  :init
  ;; Local workstation Gitea.
  (setq gitea-host "http://127.0.0.1:3000"
        gitea-user "scs"
        ;; Prefer the workstation token file over auth-source for this lab.
        gitea-use-auth-source nil)
  :config
  (setq gitea-token (or gitea-token (scs/gitea-token-from-config)))
  (unless gitea-token
    (message "gitea.el: no token in ~/.config/gitea/access-token; call gitea-create-token")))

;; ----------------------------------------------------------
;; haproxy-mode
;; ----------------------------------------------------------

;; https://github.com/port19x/haproxy-mode
(use-package haproxy-mode :el-get t)

;; ----------------------------------------------------------
;; helpful
;; ----------------------------------------------------------

;; Richer command/function docs for the command hub (job D).
(use-package helpful
  :el-get t
  :commands (helpful-callable helpful-function helpful-variable
                             helpful-key helpful-command))

;; ----------------------------------------------------------
;; vertico + orderless + consult (minibuffer stack)
;; ----------------------------------------------------------
;;
;; Vertico is the completion UI.  Orderless is the matching style.
;; Consult is extra commands on completing-read (preview, fd, ripgrep).
;; Marginalia annotates candidates (docstrings, file bits, modes).
;; Embark act stays on C-.  Helm is not loaded.
;;
;; Consult README keys that used to be Helm now belong here: C-x b,
;; M-y, C-x r b, C-c h.  M-x is vanilla execute-extended-command
;; (Vertico).  C-x f is Emacs set-fill-column again.  M-s o is occur.

(defun scs/consult-history ()
  "Insert from a buffer input ring, or pick a previous command.

`consult-history' only knows Eshell, Comint, Term, and the
minibuffer (`consult-mode-histories').  Org and most editing
buffers have no input ring, so the stock command errors there.
In those buffers this command runs `consult-complex-command'
instead: pick a previous command (with its arguments) and run it
again.  That is the closest analogue to Helm remembering the last
M-x."
  (interactive)
  (require 'consult)
  (if (or (minibufferp)
          (seq-find (lambda (h)
                      (and (derived-mode-p (car h))
                           (boundp (if (consp (cdr h)) (cadr h) (cdr h)))))
                    consult-mode-histories))
      (call-interactively #'consult-history)
    (call-interactively #'consult-complex-command)))

(defun scs/vertico--completion-category ()
  "Return the current minibuffer completion category, or nil.

Used so category-specific Vertico layouts (for example jinx grid)
are not overwritten by the default half-window panel."
  (when (and (minibufferp) minibuffer-completion-table)
    (compat-call completion-metadata-get
                 (completion-metadata
                  (buffer-substring-no-properties
                   (minibuffer-prompt-end)
                   (max (minibuffer-prompt-end) (point)))
                  minibuffer-completion-table
                  minibuffer-completion-predicate)
                 'category)))

(defun scs/vertico-half-window ()
  "Keep the Vertico list at about half the selected window height.

`vertico-count' is a line count, not a fraction.  Vertico already
lets the minibuffer grow (`vertico--resize-window' sets
`max-mini-window-height' locally to 1.0).  With `vertico-resize'
nil, that count is also the floor, so one hit still occupies the
same panel as a long list.  Height follows the window that opened
the minibuffer, not the whole frame, so a split stays consistent.

Skip the jinx category: `vertico-multiform-categories' sets a
small grid there, and this hook would otherwise overwrite that
count (both run on `minibuffer-setup-hook')."
  (unless (eq (scs/vertico--completion-category) 'jinx)
    (let ((win (or (minibuffer-selected-window) (selected-window))))
      (setq-local vertico-count (max 10 (/ (window-body-height win) 2))))))

(use-package vertico
  :el-get t
  :init
  (vertico-mode)
  :config
  ;; Fixed panel: do not shrink when there are few candidates.
  (setq vertico-resize nil)
  (add-hook 'minibuffer-setup-hook #'scs/vertico-half-window)
  ;; Extensions live in vertico/extensions/.  el-get load-path lists
  ;; that dir after a fresh sync; add it here so this session finds
  ;; vertico-repeat without waiting for a reinstall.
  (let ((ext (expand-file-name "extensions"
                               (file-name-directory (locate-library "vertico")))))
    (when (file-directory-p ext)
      (add-to-list 'load-path ext)))
  ;; Helm-resume analogue: restore the last Vertico session (input and
  ;; selected candidate).  Not Counsel/ivy-resume -- Counsel is Ivy's
  ;; command pack; this profile uses Consult.  M-x itself is filtered
  ;; out of this history (upstream default); last M-x commands still
  ;; sort to the top of a new M-x via `extended-command-history'.
  (require 'vertico-repeat)
  (add-hook 'minibuffer-setup-hook #'vertico-repeat-save)
  (keymap-global-set "M-R" #'vertico-repeat)
  (keymap-set vertico-map "M-P" #'vertico-repeat-previous)
  (keymap-global-set "C-x C-f" #'find-file)
  ;; jinx README: grid + annotations for correction candidates so more
  ;; suggestions fit.  Require extensions before enabling multiform so
  ;; `intern-soft' finds vertico-grid-mode.
  (require 'vertico-grid)
  (require 'vertico-multiform)
  (add-to-list 'vertico-multiform-categories
               '(jinx grid (vertico-grid-annotate . 20) (vertico-count . 4)))
  (vertico-multiform-mode 1))

(use-package orderless
  :el-get t
  :demand t
  :config
  ;; Load first so the `orderless' completion style exists, then select
  ;; it.  orderless README: basic as fallback; partial-completion for
  ;; files so /u/s/e can expand.  completion-pcm-leading-wildcard is
  ;; Emacs 31.
  (setq completion-styles '(orderless basic)
        completion-category-defaults nil
        completion-category-overrides '((file (styles partial-completion)))
        completion-pcm-leading-wildcard t))

(use-package marginalia
  :el-get t
  :bind (:map minibuffer-local-map
              ("M-A" . marginalia-cycle))
  :init
  ;; README: enable in :init so the mode is on before the first prompt.
  (marginalia-mode))

(use-package consult
  :el-get t
  :bind
  (;; Consult README.  Keys that used to be Helm are included on purpose.
   ("C-x b" . consult-buffer)
   ("C-x 4 b" . consult-buffer-other-window)
   ("C-x 5 b" . consult-buffer-other-frame)
   ("C-x t b" . consult-buffer-other-tab)
   ("C-x r b" . consult-bookmark)
   ("C-x p b" . consult-project-buffer)
   ("C-x M-:" . consult-complex-command)
   ("C-c h" . scs/consult-history)
   ("C-c M-x" . consult-mode-command)
   ("C-c k" . consult-kmacro)
   ;; C-c i stays imenu-list (later in this file).  consult-info is
   ;; still on Info-search via the remap below.  C-c m is the mail lab.
   ("M-y" . consult-yank-pop)
   ("M-g e" . consult-compile-error)
   ("M-g g" . consult-goto-line)
   ("M-g M-g" . consult-goto-line)
   ("M-g o" . consult-outline)
   ("M-g m" . consult-mark)
   ("M-g k" . consult-global-mark)
   ("M-g i" . consult-imenu)
   ("M-g I" . consult-imenu-multi)
   ("M-s d" . consult-fd)
   ("M-s c" . consult-locate)
   ("M-s g" . consult-grep)
   ("M-s G" . consult-git-grep)
   ("M-s r" . consult-ripgrep)
   ("M-s l" . consult-line)
   ("M-s L" . consult-line-multi)
   ("M-s k" . consult-keep-lines)
   ("M-s u" . consult-focus-lines)
   ("M-s e" . consult-isearch-history)
   ([remap Info-search] . consult-info)
   :map isearch-mode-map
   ("M-e" . consult-isearch-history)
   ("M-s e" . consult-isearch-history)
   ("M-s l" . consult-line)
   ("M-s L" . consult-line-multi)
   :map minibuffer-local-map
   ("M-s" . consult-history)
   ("M-r" . consult-history))
  :config
  ;; Consult README: register preview, xref locations, live preview debounce.
  ;; Kept in :config so el-get autoloads need not exist yet at init parse.
  (advice-add #'register-preview :override #'consult-register-window)
  (setq register-preview-delay 0.5)
  (setq xref-show-xrefs-function #'consult-xref
        xref-show-definitions-function #'consult-xref)
  (setq consult-narrow-key "<")
  (consult-customize
   consult-theme :preview-key '(:debounce 0.2 any)
   consult-ripgrep consult-git-grep consult-grep
   consult-bookmark consult-recent-file consult-xref
   consult-source-bookmark consult-source-file-register
   consult-source-recent-file consult-source-project-recent-file
   :preview-key '(:debounce 0.4 any)))

;; Embark README: same checkout as embark; loads exporters so
;; consult-ripgrep can embark-export to a grep buffer (then wgrep).
(use-package embark-consult
  :after (embark consult)
  :demand t)

;; ----------------------------------------------------------
;; consult-dir
;; ----------------------------------------------------------
;;
;; Insert a directory path into the active minibuffer prompt (dired
;; copy targets, find-file, consult-grep with a prefix arg, and so
;; on).  Outside the minibuffer, pick a directory then run
;; `consult-dir-default-command' (find-file by default).  Sources:
;; bookmarks, recentf dirs, project.el roots, `scs/tramp-hosts', and
;; ~/.ssh/config hosts.  `recentf-mode' is already on in this init.

(use-package consult-dir
  :el-get t
  :after (consult vertico)
  :bind (("C-x C-d" . consult-dir)
         :map vertico-map
         ("C-x C-d" . consult-dir)
         ("C-x C-j" . consult-dir-jump-file))
  :init
  ;; Set before consult-dir.el loads so `consult-dir--source-tramp-local'
  ;; splices the host list at defvar time.
  (require 'scs-tramp)
  (setq consult-dir-tramp-local-hosts
        (mapcar #'scs/tramp--default-directory scs/tramp-hosts))
  :config
  ;; README: optional SSH config source (narrow with s).
  (add-to-list 'consult-dir-sources 'consult-dir--source-tramp-ssh t)
  ;; Match M-s d: fd-backed async find under the prompt directory.
  (setq consult-dir-jump-file-command #'consult-fd))

;; ----------------------------------------------------------
;; hl-todo
;; ----------------------------------------------------------

(use-package hl-todo
  :el-get t
  :config
  (global-hl-todo-mode)
  (setq hl-todo-keyword-faces
        '(("TODO"   . "#FF0000")
          ("FIXME"  . "#FF0000")
          ("DEBUG"  . "#A020F0")
          ("GOTCHA" . "#FF4300")
          ("STUB"   . "#1E90FF"))))

;; ----------------------------------------------------------
;; howm (:after org -- comes after org)
;; ----------------------------------------------------------

;; See also remember
(use-package howm
  :el-get t
  :after org
  :defer t
  :commands (howm-mode)
  :init
  (setq howm-directory "~/notes")
  (setq howm-home-directory howm-directory)

  ;; Org-compatible filenames and syntax.
  (setq howm-file-name-format "%Y-%m-%d-%H%M%S.org")
  (setq howm-view-title-header "*")
  (setq howm-dtime-format (format "<%s>" (cdr org-timestamp-formats)))

  ;; Use ripgrep for fast searching if available, fall back to grep.
  (setq howm-view-use-grep t)
  (when (executable-find "rg")
    (setq howm-view-grep-command "rg")
    (setq howm-view-grep-option "-nH --no-heading --color never")
    (setq howm-view-grep-extended-option nil)
    (setq howm-view-grep-fixed-option "-F")
    (setq howm-view-grep-expr-option nil)
    (setq howm-view-grep-file-stdin-option nil))

  ;; Make the "comefrom links" case-insensitive.
  (setq howm-keyword-case-fold-search t)
  ;; Get rid of the old-fashioned separators.
  (setq howm-view-summary-sep "\t")

  ;; Org-mode template: title as org heading, date, file link, tags line.
  (setq howm-template
        (concat "* %title%cursor\n"
                "%date %file\n"
                "#TITLE:\n"
                "#+filetags:\n\n"))

  ;; Menu: show more context.
  (setq howm-menu-recent-num 30)
  (setq howm-list-recent-days 30)
  (setq howm-menu-todo-num 30)

  ;; Schedule: look ahead 30 days, back 3 days.
  (setq howm-menu-schedule-days 30)
  (setq howm-menu-schedule-days-before 3)

  ;; Keep howm metadata inside the note directory via no-littering.
  (setq howm-keyword-file (no-littering-expand-var-file-name "howm/keys"))
  (setq howm-history-file (no-littering-expand-var-file-name "howm/history"))

  ;; add: 2026-07-10 — scope howm to notes tree (was all org-mode buffers)
  (defun scs/howm-enable-in-notes ()
    "Turn on `howm-mode' for Org files under `howm-directory'."
    (when (and buffer-file-name
               (boundp 'howm-directory)
               (file-directory-p howm-directory)
               (file-in-directory-p buffer-file-name howm-directory))
      (howm-mode 1)))

  :bind
  ("<f9>" . howm-list-all)
  ("<C-f9>" . howm-create)

  :hook
  ;; Set buffer names from note title.
  (howm-mode . howm-mode-set-buffer-name)
  ;; Enable howm only for Org files under the notes directory (not every Org buffer).
  (org-mode . scs/howm-enable-in-notes)

  :config
  ;; Sort by mtime so recently-touched notes appear first.
  (setq howm-normalizer 'howm-sort-items-by-mtime)
  ;; Preview contents in summary view.
  (setq howm-view-contents-limit 200)
  ;; Open summary and content side-by-side.
  (setq howm-view-split-horizontally t)
  ;; Keep summary visible when selecting an item.
  (setq howm-view-summary-persistent t)

  ;; Rename notes to a chosen filename (default from #TITLE: or * heading).
  (defvar-local scs/howm-rename-offered-p nil
    "Non-nil once we offered to rename this timestamp-named howm note.")

  (defun scs--howm-slugify (str)
    "Convert STR to a lowercase slug (alphanumeric and hyphens).
Strips leading/trailing hyphens and collapses runs of hyphens."
    (cl-reduce (lambda (acc fn) (funcall fn acc))
               (list (lambda (s) (string-trim s))
                     (lambda (s) (replace-regexp-in-string "[^a-zA-Z0-9-]" "-" s))
                     (lambda (s) (replace-regexp-in-string "-\\{2,\\}" "-" s))
                     #'downcase
                     (lambda (s) (replace-regexp-in-string "^-\\|-$" "" s)))
               :initial-value str))

  (defun scs--howm-note-title ()
    "Return note title from #TITLE:/#+TITLE: or the first org heading."
    (save-excursion
      (goto-char (point-min))
      (or (when (re-search-forward
                 "^#\\+?[Tt][Ii][Tt][Ll][Ee]:[ \t]*\\(.+\\)$" nil t)
            (string-trim (match-string 1)))
          (when (re-search-forward
                 (concat "^" (regexp-quote howm-view-title-header)
                         " +\\(.+\\)$")
                 nil t)
            (string-trim (match-string 1))))))

  (defun scs--howm-suggest-filename ()
    "Suggest a note filename from `scs--howm-note-title'."
    (let ((title (scs--howm-note-title)))
      (when (and title (not (string-blank-p title)))
        (concat (scs--howm-slugify title) ".org"))))

  (defun scs--howm-timestamp-filename-p (filename)
    "True when FILENAME is howm's default YYYY-MM-DD-HHMMSS.org pattern."
    (string-match-p "\\`[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}-[0-9]\\{6\\}\\.org\\'"
                    (file-name-nondirectory filename)))

  (defun scs/howm-rename-note (&optional no-prompt-p)
    "Rename the current howm note, choosing the filename interactively.

Default suggestion comes from #TITLE:/#+TITLE:, else the first * heading."
    (interactive)
    (unless (and howm-mode buffer-file-name
                 (file-in-directory-p buffer-file-name howm-directory))
      (user-error "Not a howm note in %s" howm-directory))
    (let* ((default (or (scs--howm-suggest-filename)
                        (file-name-nondirectory buffer-file-name)))
           (input (if no-prompt-p default
                    (read-string "Note filename: " default nil default)))
           (basename (if (string-match "\\.org\\'" input) input (concat input ".org")))
           (new-path (expand-file-name basename
                                       (file-name-directory buffer-file-name))))
      (when (string-blank-p basename)
        (user-error "Filename cannot be empty"))
      (if (string= (file-name-nondirectory buffer-file-name) basename)
          (message "Filename already matches: %s" basename)
        (when (and (file-exists-p new-path) (not (string= new-path buffer-file-name)))
          (user-error "Target file already exists: %s" basename))
        (rename-file buffer-file-name new-path)
        (set-visited-file-name new-path t t)
        ;; Keep org-id locations in sync after rename.
        (scs/org-id-update-current-file)
        (message "Renamed to %s" basename))))

  (defalias 'howm-rename-to-slug #'scs/howm-rename-note)

  (defun scs/howm-maybe-offer-rename ()
    "After first save, offer to rename a new timestamp-named howm note."
    (when-let* ((_mode (and howm-mode buffer-file-name))
                (_inhowm (file-in-directory-p buffer-file-name howm-directory))
                (_not-yet (not scs/howm-rename-offered-p))
                (_ts (scs--howm-timestamp-filename-p buffer-file-name))
                (suggested (scs--howm-suggest-filename)))
      (setq scs/howm-rename-offered-p t)
      (when (y-or-n-p (format "Rename note to %s? " suggested))
        (scs/howm-rename-note t))))

  (defun scs/howm-setup-rename-offer ()
    "Install the buffer-local after-save hook that may offer note renaming."
    (add-hook 'after-save-hook #'scs/howm-maybe-offer-rename nil t))

  (defun scs/notes-search ()
    "Search org notes under `howm-directory' (howm summary + ripgrep).
With prefix arg, treat the pattern as a fixed string."
    (interactive)
    (require 'howm)
    (if current-prefix-arg
        (call-interactively #'howm-list-grep-fixed)
      (call-interactively #'howm-list-grep)))

  (global-set-key (kbd "C-c n g") #'scs/notes-search)
  (global-set-key (kbd "C-c n r") #'scs/howm-rename-note)
  (when (eq system-type 'darwin)
    (global-set-key (kbd "H-/") #'scs/notes-search))

  ;; Tag/name action-lock rules: #tag, +tag, @name become clickable links.
  ;; Invoke runs a fixed-string ripgrep across howm-directory (not howm-keyword-search).
  (defun scs--howm-grep-tag (tag)
    "Search howm notes for literal TAG text (fixed-string ripgrep)."
    (howm-set-command 'howm-list-grep-fixed)
    (howm-search tag t nil nil (format "*howm: %s*" tag)))

  (defun scs--howm-add-tag-rules ()
    "Add action-lock rules for #tag, +tag, and @name patterns."
    (action-lock-add-rules
     (list
      ;; #tag -- topics/categories
      (action-lock-general #'scs--howm-grep-tag
                           "\\(?:^\\|[ \t]\\)\\(#[a-zA-Z0-9_-]+\\)" 1 1)
      ;; +tag -- projects/groups
      (action-lock-general #'scs--howm-grep-tag
                           "\\(?:^\\|[ \t]\\)\\(\\+[a-zA-Z0-9_-]+\\)" 1 1)
      ;; @name or @@tag -- people, files, resources
      (action-lock-general #'scs--howm-grep-tag
                           "\\(?:^\\|[ \t]\\)\\(@@?[a-zA-Z0-9_.-]+\\)" 1 1))
     t))

  (add-hook 'howm-mode-hook #'scs--howm-add-tag-rules)
  (add-hook 'howm-mode-hook #'scs/howm-setup-rename-offer)

  ;; Org needs Tab for org-cycle (fold/unfold).  howm steals RET, so
  ;; follow action-lock links with C-c , RET.
  ;;
  ;; Link jump uses Super-Tab (Emacs `s-<tab>').  On this Mac profile
  ;; early-init maps the physical Control key to Super
  ;; (`mac-control-modifier' -> super), so the chord you press is
  ;; Ctrl-Tab.  Physical Command is Emacs Control; Shift-Tab stays
  ;; with Org (`org-shifttab').
  (define-key howm-mode-map (kbd "C-c , RET") 'action-lock-magic-return)
  (define-key howm-mode-map (kbd "C-c , <return>") 'action-lock-magic-return)
  (keymap-unset howm-mode-map "<tab>" t)
  (keymap-unset howm-mode-map "S-<tab>" t)
  (keymap-unset howm-mode-map "<backtab>" t)
  (keymap-unset howm-mode-map "C-c , S-<tab>" t)
  (keymap-unset howm-mode-map "C-c , <backtab>" t)
  (define-key howm-mode-map (kbd "s-<tab>") 'action-lock-goto-next-link)
  (define-key howm-mode-map (kbd "s-<backtab>") 'action-lock-goto-previous-link)
  (define-key howm-mode-map (kbd "s-S-<tab>") 'action-lock-goto-previous-link))

;; ----------------------------------------------------------
;; org-id (find howm notes by ID)
;; ----------------------------------------------------------
;;
;; howm notes get stable Org IDs at creation time.  We persist id -> file
;; mappings under no-littering var/ and update incrementally on save rather
;; than rescanning the whole notes tree at every startup.

(defun scs/howm-add-org-id ()
  "Assign an Org ID to the current howm note (runs from `howm-create-hook')."
  (org-id-get-create))

;; add: 2026-07-10
(defun scs/org-id--notes-files ()
  "Return Org files under `howm-directory', or nil."
  (when (and (boundp 'howm-directory)
             (file-directory-p howm-directory))
    (directory-files-recursively (expand-file-name howm-directory)
                                 "\\.org\\'")))

;; add: 2026-07-10
(defun scs/org-id--configure-locations-file ()
  "Set `org-id-locations-file' under no-littering var/ (team persistence path)."
  (require 'org-id)
  (setq org-id-locations-file
        (no-littering-expand-var-file-name "org/id-locations.el")))

;; add: 2026-07-10
(defun scs/org-id-update-current-file ()
  "Merge this buffer's Org IDs into the persisted locations table.

No-op outside `howm-directory'."
  (when (and buffer-file-name
             (string-match-p "\\.org\\'" buffer-file-name)
             (boundp 'howm-directory)
             (file-directory-p howm-directory)
             (file-in-directory-p buffer-file-name howm-directory))
    (scs/org-id--configure-locations-file)
    (org-id-update-id-locations (list buffer-file-name) t)))

;; add: 2026-07-10
(defun scs/org-id-report-duplicates ()
  "Report duplicate Org IDs under `howm-directory'."
  (interactive)
  (scs/org-id--configure-locations-file)
  (let* ((files (or (scs/org-id--notes-files)
                    (user-error "howm-directory is not available")))
         (table (make-hash-table :test #'equal))
         (dups 0))
    (dolist (file files)
      (with-temp-buffer
        (insert-file-contents file)
        (org-mode)
        (org-map-entries
         (lambda ()
           (when-let* ((id (org-entry-get (point) "ID")))
             (push file (gethash id table))))
         t 'file)))
    (with-current-buffer (get-buffer-create "*scs org-id duplicates*")
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "# Org ID duplicates under %s\n\n"
                        (abbreviate-file-name howm-directory)))
        (maphash
         (lambda (id files)
           (setq files (delete-dups files))
           (when (> (length files) 1)
             (setq dups (1+ dups))
             (insert (format "ID %s\n" id))
             (dolist (f files)
               (insert (format "  %s\n" (abbreviate-file-name f))))
             (insert "\n")))
         table)
        (goto-char (point-min))
        (if (zerop dups)
            (message "No duplicate Org IDs under %s"
                     (abbreviate-file-name howm-directory))
          (message "%d duplicate Org ID%s" dups (if (= dups 1) "" "s")))
        (view-mode 1)
        (display-buffer (current-buffer))))))

;; add: 2026-07-10
(defun scs/org-id-rebuild (&optional quiet)
  "Fully rebuild org-id locations for `howm-directory'.
With QUIET non-nil, only message the elapsed time."
  (interactive)
  (scs/org-id--configure-locations-file)
  (let* ((files (or (scs/org-id--notes-files)
                    (user-error "howm-directory is not available")))
         (t0 (float-time)))
    (setq org-id-extra-files
          (cl-remove-duplicates
           (append files
                   (when (listp org-id-extra-files) org-id-extra-files))
           :test #'string=))
    (org-id-update-id-locations)
    (let ((elapsed (- (float-time) t0)))
      (unless quiet
        (message "org-id rebuild: %d files in %.3fs"
                 (length files) elapsed))
      elapsed)))

;; fix: 2026-07-10 — load persisted locations; no full startup rescan
(defun scs/org-id-init ()
  "Load persisted org-id locations; do not rescan the whole notes tree.
Run `scs/org-id-rebuild' after moving notes outside Emacs or repairing IDs."
  (when (and (boundp 'howm-directory)
             (file-directory-p howm-directory))
    (scs/org-id--configure-locations-file)
    (let ((files (scs/org-id--notes-files)))
      (setq org-id-extra-files
            (cl-remove-duplicates
             (append files
                     (when (listp org-id-extra-files) org-id-extra-files))
             :test #'string=)))
    (when (file-readable-p org-id-locations-file)
      (org-id-locations-load))
    (message "org-id: loaded %s (%s known files)"
             (abbreviate-file-name org-id-locations-file)
             (if (hash-table-p org-id-locations)
                 (hash-table-count org-id-locations)
               0))))

;; New notes get IDs at creation; startup loads the persisted table; each save
;; updates only the current file's org-id entries.
(add-hook 'howm-create-hook #'scs/howm-add-org-id)
(add-hook 'emacs-startup-hook #'scs/org-id-init 100)
;; add: 2026-07-10
(defun scs/howm-setup-id-on-save ()
  "Buffer-local after-save hook: sync org-id locations for this note."
  (add-hook 'after-save-hook #'scs/org-id-update-current-file nil t))
(add-hook 'howm-mode-hook #'scs/howm-setup-id-on-save)

;; ----------------------------------------------------------
;; imenu-list
;; ----------------------------------------------------------

;; https://github.com/bmag/imenu-list
;; <2024-06-20>
(use-package imenu-list
  :el-get t
  :bind
  ("C-c i" . imenu-list-smart-toggle)
  :custom
  (imenu-list-focus-after-activation t)
  (imenu-list-auto-resize nil))

;; ----------------------------------------------------------
;; impatient-mode
;; ----------------------------------------------------------

(use-package impatient-mode :el-get t)

;; ----------------------------------------------------------
;; jinx
;; ----------------------------------------------------------
;; https://github.com/minad/jinx
;; Just-in-time spell-check via Enchant.  Replaces day-to-day use of
;; flyspell/ispell (M-$), but those packages stay configured so they
;; can still be turned on by hand.  Needs libenchant at compile time
;; (macOS: brew install enchant pkgconf).

(use-package jinx
  :el-get t
  :unless (eq window-system 'w32)
  :hook (emacs-startup . global-jinx-mode)
  :bind (("M-$" . jinx-correct)
         ("C-M-$" . jinx-languages))
  :custom
  ;; Same British -ise dictionary as the ispell/aspell setup above
  ;; (en_GB-ise), plus Italian.  Whitespace separated; Enchant opens
  ;; one dictionary per code.
  (jinx-languages "en_GB-ise it_IT")
  :config
  ;; spell/ is the Git-tracked source; install links Enchant and rebuilds
  ;; aspell personal files so both backends see the same words.
  (scs/spell-dicts-install))

;; ----------------------------------------------------------
;; keycast
;; ----------------------------------------------------------

;; (keycast-tab-bar-mode)
(use-package keycast :el-get t)

;; ----------------------------------------------------------
;; minions
;; ----------------------------------------------------------

(use-package minions :el-get t)

;; ----------------------------------------------------------
;; move-dup
;; ----------------------------------------------------------

;; https://github.com/wyuenho/move-dup
;; <2024-05-14>
(use-package move-dup
  :el-get t
  :bind (("M-<up>"     . move-dup-move-lines-up)
         ("C-M-<up>"   . move-dup-duplicate-up)
         ("M-<down>"   . move-dup-move-lines-down)
         ("C-M-<down>" . move-dup-duplicate-down))
  :config
  (global-move-dup-mode))


;; ----------------------------------------------------------
;; org
;; ----------------------------------------------------------

(use-package org
  :el-get t
  :defer t)

(with-eval-after-load 'org
  (require 'org-tools)
  (require 'scs-org-capture)
  (scs/org-capture-configure)
  ;; Org binds C-c / (sparse-tree) and C-c ? (table field info), which
  ;; shadow the global command-hub portal.  Reclaim them; sparse trees
  ;; remain via M-x org-sparse-tree.
  (define-key org-mode-map (kbd "C-c /") #'scs/command-hub)
  (define-key org-mode-map (kbd "C-c ?") #'scs/command-hub))

;; org-protocol needed for macOS scrim -- load after server starts
(with-eval-after-load 'server
  (run-with-idle-timer 1 nil (lambda () (require 'org-protocol))))

;; :vip:
(setq org-fold-catch-invisible-edits 'show-and-error)

;; :vip:
;;  Query to the user, if it is OK to kill that hidden subtree.
;; When nil, kill without remorse.
(setq org-ctrl-k-protect-subtree t)

;; Enable BIND property. This will work:
;; #+BIND variable "scs"
;; This config intentionally treats my Org files as trusted.  Exports may
;; honour #+BIND and Babel blocks without prompts because these files are part
;; of my own publishing workflow, not untrusted input.
(setq org-export-allow-bind-keyword t)

(setq org-html-validation-link "<a href=\"https://scs.re\">$SCS$</a>")

(setq org-html-html5-fancy t
      org-html-indent nil)

(setq org-html-postamble t
      org-html-postamble-format
      '(("en" "<br /><p style=\"text-align:right;\"><code>%c</code></p>")))

;; (setq org-html-validation-link "scs")
(setq org-startup-folded t)

;; org-contrib
(use-package org-contrib
  :el-get t
  :after org
  :defer t
  :config
  (require 'org-expiry)
  (org-expiry-insinuate)
  (setq org-expiry-inactive-timestamps t))

;; org-web-clipper
;; Local Gitea checkout plus its pinned Defuddle/LinkeDOM toolchain.
(use-package org-web-clipper
  :el-get t
  :commands (org-web-clipper-capture
             org-web-clipper-capture-current-page
             org-web-clipper-cancel)
  :custom
  (org-web-clipper-root-directory
   (expand-file-name "~/notes/clips/")))

;; TODO keywords.
(setq org-todo-keywords
  '((sequence "TODO(t)" "NEXT(n)" "PROG(p)" "INTR(i)" "DONE(d)")))

;; Show the daily agenda by default.
(setq org-agenda-span 'day)

;; Hide tasks that are scheduled in the future.
(setq org-agenda-todo-ignore-scheduled 'future)

;; Use "second" instead of "day" for time comparison.
;; It hides tasks with a scheduled time like "<2020-11-15 Sun 11:30>"
(setq org-agenda-todo-ignore-time-comparison-use-seconds t)

;; Hide the deadline prewarning prior to scheduled date.
(setq org-agenda-skip-deadline-prewarning-if-scheduled 'pre-scheduled)

;; Customized view for the daily workflow. (Command: "C-c a n")
(setq org-agenda-custom-commands
  '(("n" "Agenda / INTR / PROG / NEXT"
     ((agenda "" nil)
      (todo "INTR" nil)
      (todo "PROG" nil)
      (todo "NEXT" nil))
     nil)))

;; Archive subtrees within same file
(setq org-archive-location "::* Archived")

;; org-auto-expand
;; https://github.com/alphapapa/org-auto-expand
(use-package org-auto-expand
  :el-get t
  :after org
  :defer t
  :config
  (org-auto-expand-mode))

;; org-babel -- loads when org loads
(use-package ob
  :after org
  :config
  ;; Babel language backends must load *before* org-babel-do-load-languages.
  (use-package ob-plantuml)
  (use-package ob-ditaa)
  (use-package ob-mermaid
    :el-get ob-mermaid
    :custom
    (ob-mermaid-cli-path "mmdc")
    (ob-mermaid-default-config-file
     (expand-file-name "~/.config/mermaid/config.json")))

  ;; load more languages for org-babel
  ;; https://orgmode.org/worg/org-contrib/babel/languages/index.html
  (org-babel-do-load-languages
   'org-babel-load-languages
   '((python     . t)
     (emacs-lisp . t)
     (haskell    . t)
     (calc       . t)
     (shell      . t)
     (latex      . t)
     (ditaa      . t)
     (plantuml   . t)
     (C          . t)
     (sql        . t)
     (dot        . t)
     (makefile   . t)
     (org        . t)
     (lisp       . t)
     (mermaid    . t)
     ;; (jupyter    . t)
     ))                  ; must be last

  ;; fix: 2026-07-10 — restore Babel temp-dir cleanup (removed prior remove-hook)
  ;; Keep Babel temp-dir cleanup on kill-emacs (disk hygiene).  Re-add a
  ;; documented exception here only if a publishing workflow needs the
  ;; directories to survive the Emacs session.

  (defun org-babel-sh-strip-weird-long-prompt (string)
    "Remove prompt cruft from a string of shell output."
    (while (string-match "^.+?;C;\uFFFD" string)
      (setq string (substring string (match-end 0))))
    string)

  (advice-add 'org-babel-edit-prep:emacs-lisp :after
              ;; Run normal emacs-lisp-mode hooks in the Babel edit buffer (indent, etc.).
              (lambda (&rest _) (run-hooks 'emacs-lisp-mode-hook)))

  (setq org-babel-default-header-args:sh    '((:results . "output replace"))
        org-babel-default-header-args:bash  '((:results . "output replace"))
        org-babel-default-header-args:shell '((:results . "output replace"))
        ;; org-babel-default-header-args:jupyter-python
        ;; '((:async . "yes")
        ;;   (:session . "py")
        ;;   (:kernel . "sagemath"))
        )

  (setq org-babel-default-header-args:mermaid
        '((:results . "file")
          (:exports . "results")))

  ;; See the trusted-Org comment near `org-export-allow-bind-keyword'.
  (setq org-confirm-babel-evaluate nil)
  (let ((pdir (getenv "PROFILE_DIR")))
    (when pdir
      (let ((plantuml (expand-file-name "lib/plantuml.jar" pdir))
            (ditaa (expand-file-name "lib/ditaa.jar" pdir)))
        (when (file-exists-p plantuml)
          (setq org-plantuml-jar-path plantuml))
        (when (file-exists-p ditaa)
          (setq org-ditaa-jar-path ditaa)))))

  (add-to-list 'org-src-lang-modes (quote ("plantuml" . plantuml)))
  (add-to-list 'org-src-lang-modes '(("mermaid" . mermaid))))

;; Org capture policy and target files live in lisp/scs-org-capture.el.
;; The finalization hook that closes client frames is defined above.

;; ----------------------------------------------------------
;; recentf
;; ----------------------------------------------------------
;;
;; Consult's buffer list Files source (narrow with f) reads this list.
;; Enable during init, not after a timer, so the first C-x b already
;; sees recents.  no-littering owns the save file under var/.

;; jwiegley
(use-package recentf
  :commands (recentf-mode
             recentf-add-file
             recentf-apply-filename-handlers)
  :custom
  (recentf-auto-cleanup 'never)
  (recentf-exclude
   '("~\\'" "\\`out\\'" "\\.log\\'" "^/[^/]*:" "\\.el\\.gz\\'"))
  (recentf-max-saved-items 2000)
  ;;  (recentf-save-file (user-data "recentf"))
  :preface
  ;; Advice: tolerate truncated recentf-save.el after a crash without breaking startup.
  (defun scs/recentf-load-list--safe (orig &rest args)
    "Load `recentf-save-file' quietly, recovering from truncated state."
    (condition-case err
        ;; Emacs 31's `recentf-load-list' uses `load-file', which always
        ;; announces "Loading ...recentf-save.el...done".  Suppress only that
        ;; normal load chatter; keep the explicit recovery messages below.
        (let ((inhibit-message t))
          (apply orig args))
      (end-of-file
       (message "recentf: save file truncated; starting with empty list")
       (setq recentf-list nil
             recentf-filter-changer-current nil))
      (error
       (message "recentf: could not load save file (%s)"
                (error-message-string err))
       (setq recentf-list nil
             recentf-filter-changer-current nil))))
  (defun recentf-add-dired-directory ()
    "Add directories visited by dired into recentf."
    (when (and dired-directory
               (file-directory-p dired-directory)
               (not (string= "/" dired-directory)))
      (recentf-add-file (string-trim-right dired-directory "/"))))
  :hook (dired-mode . recentf-add-dired-directory)
  :config
  (advice-add 'recentf-load-list :around #'scs/recentf-load-list--safe)
  (add-to-list 'recentf-exclude
               (recentf-expand-file-name no-littering-var-directory))
  (add-to-list 'recentf-exclude
               (recentf-expand-file-name no-littering-etc-directory))
  (add-to-list 'recentf-exclude "/private/var/folders/")
  (add-to-list 'recentf-exclude (regexp-quote temporary-file-directory))
  (recentf-mode 1))

;; ----------------------------------------------------------
;; reveal-in-osx-finder (macOS only)
;; ----------------------------------------------------------

(use-package reveal-in-osx-finder
  :el-get t
  :if (eq system-type 'darwin)
  :no-require t)

;; ----------------------------------------------------------
;; savehist
;; ----------------------------------------------------------
;;
;; Persist minibuffer histories across sessions.  Consult's
;; consult-history (M-s / M-r in the minibuffer) reads whatever
;; `minibuffer-history-variable' savehist restored.  Global C-c h
;; is `scs/consult-history', which falls back to command history
;; in Org and other editing buffers.
;;
;; Also persist kill, mark, and incremental-search rings (see the
;; History length block for ring max sizes).

(use-package savehist
  :unless noninteractive
  :custom
  (savehist-additional-variables
   '(file-name-history
     kmacro-ring
     compile-history
     compile-command
     vertico-repeat-history
     kill-ring
     mark-ring
     search-ring
     regexp-search-ring))
  (savehist-autosave-interval 60)
  (savehist-ignored-variables
   '(load-history
     flyspell-auto-correct-ring
     org-roam-node-history
     magit-revision-history
     org-read-date-history
     query-replace-history
     yes-or-no-p-history))
  (savehist-mode t))

;; ----------------------------------------------------------
;; saveplace
;; ----------------------------------------------------------

(use-package saveplace
  :unless noninteractive
  :config
  (save-place-mode 1))

;; ----------------------------------------------------------
;; slime
;; ----------------------------------------------------------

(use-package slime
  :el-get t
  :commands slime
  :custom
  (slime-kill-without-query-p t)
  (slime-startup-animation nil)
  :init
  (setq inferior-lisp-program (expand-file-name "~/lisp/lispworks/lw-console"))
  ;;  (setq inferior-lisp-program "sbcl")
  (setq slime-contribs '(slime-fancy)))

;; ----------------------------------------------------------
;; sly (:disabled)
;; ----------------------------------------------------------

(use-package sly
  :el-get t
  :disabled t
  :init
  (setq inferior-lisp-program (expand-file-name "~/lisp/lispworks/lw-console"))
;;(setq inferior-lisp-program "/Applications/LispWorks\ 8.0\ (64-bit)/LispWorks\ (64-bit).app/Contents/MacOS/lispworks-8-0-0-macos64-universal")
  (setq sly-protocol-version 'ignore)
  (setq sly-net-coding-system 'utf-8-unix)
  :config
  (use-package sly-asdf :el-get t)
  (use-package sly-macrostep :el-get t)
  (use-package sly-repl-ansi-color :el-get t)
  (sly-setup '(sly-fancy)))

;; ----------------------------------------------------------
;; smart-delete (installed, not enabled)
;; ----------------------------------------------------------

;; leodag/smart-delete is IntelliJ-like *rub-out* on leading blanks (it
;; binds DEL / Backspace).  This profile keeps rub-out plain and puts
;; whitespace chewing on Delete only (`scs/delete-forward' on C-d /
;; <deletechar>).  Keep the el-get recipe for optional experiments;
;; do not turn the minor mode on here.
(use-package smart-delete
  :el-get t
  :defer t
  :disabled t)

;; ----------------------------------------------------------
;; tramp
;; ----------------------------------------------------------

(use-package tramp
  :defer t
  :config
  (setq tramp-default-method "ssh")
  (setq tramp-copy-size-limit (* 1024 1024))   ;; use scp above 1MB
  (setq tramp-verbose 1)                       ;; minimal logging (raise to 6 for debugging)
  (setq tramp-connection-timeout 10)           ;; fail fast on unreachable hosts
  (setq tramp-persistency-file-name (no-littering-expand-var-file-name "tramp"))

  ;; Prevent TRAMP from polluting remote shell history
  (setq tramp-histfile-override t)

  ;; Emacs 30: built-in ControlMaster handling (defined in tramp-sh)
  (with-eval-after-load 'tramp-sh
    (setq tramp-use-connection-share t))

  ;; ----------------------------------------------------------
  ;; Performance
  ;; ----------------------------------------------------------

  ;; Don't create lock files on remote (avoids extra round-trips)
  (setq remote-file-name-inhibit-locks t)

  ;; Don't auto-save-visited remote files (slow and unreliable)
  (setq remote-file-name-inhibit-auto-save-visited t)

  ;; Use direct SCP for remote-to-remote copies (no local bounce)
  (setq tramp-use-scp-direct-remote-copying t)

  ;; Cache remote file attributes longer (default 10s is too aggressive)
  (setq remote-file-name-inhibit-cache 60)     ;; seconds; nil=forever, t=never

  ;; VC exclusion for remote files is set in the vc use-package block below
  ;; fix: 2026-07-10 — removed ineffective (put … 'standard-value '("/tmp"))

  ;; ----------------------------------------------------------
  ;; Remote PATH discovery
  ;; ----------------------------------------------------------

  ;; Extend path for FreeBSD, SmartOS, and custom profile directories
  (setq tramp-remote-path
        (append '("/usr/local/bin"             ;; FreeBSD ports
                  "/usr/local/sbin"            ;; FreeBSD ports
                  "/opt/local/bin"             ;; SmartOS pkgsrc
                  "/opt/local/sbin"            ;; SmartOS pkgsrc
                  tramp-default-remote-path)
                tramp-remote-path))
  (let ((pdir (getenv "PROFILE_DIR")))
    (when pdir
      (add-to-list 'tramp-remote-path (expand-file-name "bin" pdir))))

  ;; ----------------------------------------------------------
  ;; Shell setup
  ;; ----------------------------------------------------------

  ;; Use /bin/sh for speed (bash/zsh startup files add latency)
  (setq tramp-encoding-shell "/bin/sh")

  ;; ----------------------------------------------------------
  ;; Multihop / proxy support
  ;; ----------------------------------------------------------

  ;; Example: reach internal hosts via a jump box
  ;; (add-to-list 'tramp-default-proxies-alist
  ;;              '("\\.internal\\'" nil "/ssh:jumpbox:"))

  (require 'scs-tramp)
  (scs/tramp-setup))

;; Opening eshell on a remote TRAMP path gives a remote shell automatically.
;; cd /ssh:host:/path then M-x eshell -- commands run on the remote host.

;; C-x d /ssh:host:/path -- browse remote filesystem
;; C-c t f/d -- find file / dired on a known host (see lisp/scs-tramp.el)
;; With ControlMaster, subsequent dired buffers on the same host are instant.

;; ----------------------------------------------------------
;; transient
;; ----------------------------------------------------------

;; Explicit citizen for the command hub spine (also pulled by magit-section).
;; Display: bottom side window.  Transient always *fits* the window to the
;; menu text afterward, which is why a bare window-height alist entry looks
;; like a minibuffer for short hubs -- we grow to a floor after that fit.
;; Faces: punchier heading + semantic key colors (stay/exit/recurse).
(use-package transient
  :el-get t
  :config
  ;; Keep dedicated + inhibit-same-window so the editing buffer stays
  ;; current (suffixes often act on point).
  (setq transient-display-buffer-action
        '(display-buffer-in-side-window
          (side . bottom)
          (dedicated . t)
          (inhibit-same-window . t)))
  ;; Semantic coloring is already the Transient default; leave it on so
  ;; key faces below mean stay / exit / recurse / return.
  (setq transient-semantic-coloring t)
  ;; Floor for Transient menu height.  Fraction of the selected frame;
  ;; never smaller than 10 lines so short hubs still feel like a panel.
  (defvar scs/transient-min-height-fraction 0.28
    "Minimum Transient menu height as a fraction of the frame height.

Transient calls `transient--fit-window-to-buffer' after display, which
shrinks the side window to the menu text.  Short hubs therefore look
minibuffer-sized unless we enlarge again afterward.")
  (defun scs/transient--enforce-min-height (window)
    "Grow WINDOW when Transient fitted it shorter than our height floor.

Arguments: WINDOW is the Transient menu window.
Return value: nil.
Side effects: may call `enlarge-window' on WINDOW."
    (when (window-live-p window)
      (let* ((frame (window-frame window))
             (want (max 10
                        (round (* scs/transient-min-height-fraction
                                  (frame-height frame)))))
             (cur (window-total-height window))
             (delta (- want cur)))
        (when (> delta 0)
          ;; Side windows can refuse some resizes; ignore and keep the fit.
          (condition-case nil
              (with-selected-window window
                (enlarge-window delta))
            (error nil))))))
  ;; After Transient's own fit-to-buffer, enforce the floor.
  (advice-add 'transient--fit-window-to-buffer :after
              #'scs/transient--enforce-min-height)
  ;; Plain q quits the whole Transient stack from any nested menu.
  ;; Stock Transient uses C-g (one level) and C-q (all); hub muscle
  ;; memory wants q.  Suffix rows in scs-command-hub also show it.
  (keymap-set transient-base-map "q" #'transient-quit-all)
  ;; Theme-aware specs (light and dark).  Bold headings make Org/TRAMP
  ;; groups pop; key colors follow Transient's own semantic faces.
  (custom-set-faces
   '(transient-heading
     ((((class color) (background light))
       :inherit font-lock-keyword-face :weight bold :foreground "#005faf")
      (((class color) (background dark))
       :inherit font-lock-keyword-face :weight bold :foreground "#7dcfff")
      (t :inherit font-lock-keyword-face :weight bold)))
   '(transient-key
     ((((class color) (background light))
       :inherit font-lock-builtin-face :weight bold :foreground "#875f00")
      (((class color) (background dark))
       :inherit font-lock-builtin-face :weight bold :foreground "#e0af68")
      (t :inherit font-lock-builtin-face :weight bold)))
   '(transient-key-stay
     ((((class color) (background light))
       :inherit transient-key :foreground "#008700")
      (((class color) (background dark))
       :inherit transient-key :foreground "#9ece6a")))
   '(transient-key-exit
     ((((class color) (background light))
       :inherit transient-key :foreground "#af0000")
      (((class color) (background dark))
       :inherit transient-key :foreground "#f7768e")))
   '(transient-key-recurse
     ((((class color) (background light))
       :inherit transient-key :foreground "#005fff")
      (((class color) (background dark))
       :inherit transient-key :foreground "#7aa2f7")))
   '(transient-key-stack
     ((((class color) (background light))
       :inherit transient-key :foreground "#5f00af")
      (((class color) (background dark))
       :inherit transient-key :foreground "#bb9af7")))
   '(transient-key-return
     ((((class color) (background light))
       :inherit transient-key :foreground "#af8700")
      (((class color) (background dark))
       :inherit transient-key :foreground "#e0af68")))))

;; ----------------------------------------------------------
;; unfill
;; ----------------------------------------------------------

;; https://github.com/purcell/unfill
(use-package unfill :el-get t)

;; ----------------------------------------------------------
;; vc
;; ----------------------------------------------------------

(use-package vc
  :defer t
  :custom
  (vc-allow-async-revert t)
  (vc-annotate-background-mode t)
  (vc-command-messages t)
  (vc-follow-symlinks t)
  (vc-git-diff-switches '("-w" "-U3"))
  (vc-make-backup-files t)
  :config
  ;; Set in :config (not :custom) because early-init.el nils out
  ;; vc-handled-backends during startup and customize-set-variable
  ;; tries to validate backends before they're restored.
  (setq vc-handled-backends '(SVN RCS CVS Hg Git))

  ;; Don't probe VC on remote files (saves many round-trips per file open)
  (setq vc-ignore-dir-regexp
        (format "%s\\|%s" vc-ignore-dir-regexp tramp-file-name-regexp)))

;; ----------------------------------------------------------
;; vc-svn
;; ----------------------------------------------------------

;; psvn repo no longer available; use built-in vc-svn instead
(with-eval-after-load 'vc-svn
  (setq svn-status-svn-environment-var-list
        '("LC_MESSAGES=C" "LANG=C" "LC_ALL=C")))

;; ----------------------------------------------------------
;; which-function-mode :gem:
;; ----------------------------------------------------------

;; print the function or org-tree the cursor is in in the minibuffer
;; 950302 pds
(which-function-mode t)

;; ----------------------------------------------------------
;; which-key
;; ----------------------------------------------------------

(use-package which-key
  :el-get t
  :defer 1
  :config
  ;; Same visual budget as Vertico: up to half the frame.
  (setq which-key-side-window-max-height 0.5)
  (which-key-mode t))

;; ----------------------------------------------------------
;; whitespace
;; ----------------------------------------------------------

(use-package whitespace
  :hook (prog-mode . whitespace-mode)
  :config
  (setq whitespace-line-column 120
        whitespace-style '(face lines-tail tabs trailing)))


;; ----------------------------------------------------------
;; avy
;; ----------------------------------------------------------

;; Jump to any visible character on screen
(use-package avy
  :el-get t
  :bind (("C-c j" . avy-goto-char-timer)))

;; ----------------------------------------------------------
;; diff-hl
;; ----------------------------------------------------------

;; Show VCS diff markers in the margin/fringe
(use-package diff-hl
  :el-get t
  :demand t
  :config
  (global-diff-hl-mode 1)
  (unless (display-graphic-p)
    (require 'diff-hl-margin)
    (diff-hl-margin-mode 1)))

;; ----------------------------------------------------------
;; eat
;; ----------------------------------------------------------

;; Terminal emulator for eshell (lighter than vterm, no C compilation)
(use-package eat
  :el-get t
  :hook (eshell-mode . eat-eshell-mode)
  :custom
  (eat-term-name "xterm-256color"))

;; ----------------------------------------------------------
;; fd-dired
;; ----------------------------------------------------------

;; find-dired speaks find(1) expressions; this command speaks fd (regex
;; by default, -e/-t/-g).  Use C-c f when you mean fd; leave M-x find-dired
;; for classic find.  Binary may be `fd' or Debian's `fdfind'.
(use-package fd-dired
  :el-get t
  :if (scs/fd-executable)
  :init
  (setq fd-dired-program (scs/fd-executable))
  :bind ("C-c f" . fd-dired))

;; ----------------------------------------------------------
;; wgrep
;; ----------------------------------------------------------
;;
;; Edit grep hits in place, then write them back to the files.
;; Consult ripgrep/grep do not produce a *grep* buffer themselves:
;; C-. A (embark-export) via embark-consult does.  Then C-c C-p
;; enters wgrep.  Emacs 31 also offers `e' for grep-edit-mode in
;; the same buffer; pick one editor per session.

(use-package wgrep
  :el-get t
  :hook (grep-setup . wgrep-setup)
  :bind (:map grep-mode-map
              ("C-c C-p" . wgrep-change-to-wgrep-mode)))


;; ----------------------------------------------------------
;; mail lab (mu4e + notmuch on ~/mail)
;; ----------------------------------------------------------

;; Homebrew ships mu4e/notmuch Lisp; lisp/scs-mail-lab.el wires
;; load-path, org-msg compose, and msmtp send.
;; Sync stays in the terminal (mbsync / mu index / notmuch new).
(use-package org-msg
  :el-get t
  :defer t)

(use-package scs-mail-lab
  :demand t
  :config
  (scs/mail-lab-install-keys))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Finalization
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Mark this file as a feature so `require 'init' succeeds in batch checks.
;; End-of-init hooks belong in the sections above, not here.

(provide 'init)

;;; init.el ends here
