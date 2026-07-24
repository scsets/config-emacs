;;; init.el --- SCS team Emacs configuration  -*- lexical-binding: t; no-byte-compile: t; -*-
;;
;; $Id: init.el,v 1.19 2026/03/23 08:27:13 scs Exp $
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
;;   General settings -- server, encoding, save hygiene, dired, input method.
;;   Custom file -- where Customize would write (we keep config in Git instead).
;;   Settings formerly in custom.el -- theme, desktop, migrated Customize values.
;;   Keybindings -- Hyper chords (macOS), C-c prefixes, safety remaps.
;;   Packages -- use-package blocks, mostly alphabetical (see in-file notes).
;;   Finalization -- (provide 'init).
;;
;; How to find things in this file:
;;   Search for semicolon banner lines or for `(use-package PACKAGE'.
;;   Team-specific symbols usually start with scs/ or scs--.
;;   C-h f and apropos still work once Emacs is running.
;;
;; The no-byte-compile cookie is intentional: init.el is the authoritative
;; source; stale init.elc in the tree is painful to debug.
;;
;;; Change Log:
;;
;; Newest first.  File-local so readers need not dig through VCS.
;;
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
(autoload 'scs/convert "scs-convert"
  "Convert region or buffer via Pandoc (markdown -> org)." t)
;; add: 2026-07-20 -- mail lab (mu4e / notmuch / BBDB / org-msg)
(autoload 'scs/mail-lab-mu4e "scs-mail-lab"
  "Open mu4e on the shared ~/mail vault." t)
(autoload 'scs/mail-lab-notmuch "scs-mail-lab"
  "Open notmuch on the shared ~/mail vault." t)
(autoload 'scs/mail-lab-search "scs-mail-lab"
  "notmuch search on the shared ~/mail vault." t)
(autoload 'scs/mail-lab-compose "scs-mail-lab"
  "Compose mail as one of the lab addresses." t)
(autoload 'scs/mail-lab-bbdb "scs-mail-lab"
  "Open BBDB for the mail lab." t)
(autoload 'scs/mail-lab-export-contacts "scs-mail-lab"
  "Export mu contacts into the BBDB file." t)
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
  "Browse the curated command catalog with Helm." t)


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
        (:name haproxy-mode
         :type github
         :pkgname "port19x/haproxy-mode")
        ;; add: 2026-07-24 -- command hub deep docs (Transient catalog Describe)
        (:name dash
         :type github
         :pkgname "magnars/dash.el"
         :features dash)
        (:name s
         :type github
         :pkgname "magnars/s.el"
         :features s)
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
        (:name helm
         :type github
         :pkgname "emacs-helm/helm"
         :features helm
         :depends (async wfnames))
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
         :depends (compat cond-let llama seq transient))
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
        (:name ob-mermaid
         :type github
         :pkgname "arnm/ob-mermaid"
         :depends (org))
        ;; add: 2026-07-20 -- mail lab contacts + HTML compose
        ;; Build via lisp/makefile-temp (no automake/autoconf required).
        (:name bbdb
         :type git
         :url "https://git.savannah.nongnu.org/git/bbdb.git"
         :description "Insidious Big Brother Database (contacts)"
         :load-path ("./lisp")
         ;; /usr/bin/make: zsh may shadow `make' with a function.
         :build (("/usr/bin/make" "--directory=lisp" "--makefile=./makefile-temp"))
         :features bbdb-loaddefs
         :autoloads nil)
        (:name org-msg
         :type github
         :pkgname "jeremy-compostella/org-msg"
         :description "Org-mode HTML compose for message-mode MUAs"
         :depends (htmlize)
         :features org-msg)
        (:name wfnames
         :type github
         :pkgname "thierryvolpiatto/wfnames"
         :branch "main"
         :features wfnames)
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
         :features yasnippet)))

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

;; Register load-paths and autoloads for installed packages once,
;; without requiring their features.  Per-package :el-get sync below
;; only runs for packages that are not yet installed.
;; el-get-is-lazy avoids loading every package feature during this pass.
(let ((el-get-is-lazy t))
  (el-get 'sync))

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
package files, and mutate `el-get-sources'."
  (ignore name)
  (when source
    (require 'el-get)
    (when (consp source)
      (scs/el-get-upsert-source source))
    (let ((pkg (if (consp source)
                   (el-get-source-name source)
                 source)))
      (unless (el-get-package-is-installed pkg)
        (el-get 'sync pkg)))))

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
;; start a named TCP server for tools (e.g. Scrim) that expect that convention.

(require 'server)
(unless (server-running-p) (server-start))

;; Second server instance via TCP for Scrim
(when (eq system-type 'darwin)
  (let ((server-name "server")
        (server-use-tcp t))
    (unless (server-running-p "server") (server-start))))

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

(setq-default history-length 10000)

;; ----------------------------------------------------------
;; Minibuffer completion
;; ----------------------------------------------------------

;; Helm owns minibuffer completion; keep built-in Fido inactive.
(when (fboundp 'fido-vertical-mode)
  (fido-vertical-mode -1))

;; ----------------------------------------------------------
;; Dired settings
;; ----------------------------------------------------------

(setq dired-kill-when-opening-new-dired-buffer t)

;; ----------------------------------------------------------
;; Input method
;; ----------------------------------------------------------

;; M-x list-input-methods
;; Display a list of all the supported input methods.

(setq default-input-method "latin-prefix")
(add-hook 'after-init-hook
          (lambda () (activate-input-method "latin-prefix")))

;;   latin-prefix ('L>' in mode line) — quail/latin-pre
;;   Modifier before letter: ` then a -> à, ' then e -> é, etc.
;;
;;    effect    | prefix | examples
;;   -----------+--------+--------------------------------------
;;    acute     |   '    | 'a -> á   'e -> é   '' -> ´
;;    grave     |   `    | `a -> à   `e -> è
;;    circumflex|   ^    | ^a -> â   ^e -> ê
;;    diaeresis |   "    | "a -> ä   "u -> ü   "" -> ¨
;;    tilde     |   ~    | ~a -> ã   ~n -> ñ
;;    cedilla   |  , ~   | ,c -> ç   ~c -> ç
;;    caron     |   ~    | ~c -> č   ~z -> ž
;;    macron    |   -    | -a -> ā   -- -> ¯
;;    dot above |  / .   | /g -> ġ   .g -> ġ
;;    misc      | " ~ /  | "s -> ß   ~d -> ð   ~t -> þ   /a -> å   /e -> æ   /o -> ø
;;    symbol    |   ~    | ~> -> »   ~< -> «   ~! -> ¡   ~? -> ¿
;;    symbol    |  _ /   | _o -> º   _a -> ª   // -> °   /\ -> ×   _y -> ¥
;;    symbol    |   ^    | ^r -> ®   ^c -> ©   ^1 -> ¹   ^2 -> ²   ^3 -> ³
;;
;;   Doubling the prefix separates it from the letter: e.g. ''a -> 'a
;;
;;   On macOS: Option is Meta in early-init.el, so Option+` sends M-`, not
;;   the quail grave prefix.  Type ` as a plain character (often the §/` key
;;   without Option), then the letter.

;; ----------------------------------------------------------
;; Visual-line-mode hook for text-mode
;; ----------------------------------------------------------

(add-hook 'text-mode-hook #'visual-line-mode)

;; ----------------------------------------------------------
;; External tools (aspell, ugrep)
;; ----------------------------------------------------------

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

;; https://github.com/Genivia/ugrep?tab=readme-ov-file#emacs
(when (executable-find "ugrep")
  (setq-default xref-search-program 'ugrep))


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
;; repo remains the single source of truth.  Desktop save/load and theme choice
;; are part of daily session restore on this machine.

(blink-cursor-mode -1)
(with-eval-after-load 'desktop
  ;; Stale desktop lock files after a crash can block session restore; remove
  ;; them when the recorded PID is not a live Emacs process.
  (defun scs/desktop-clear-stale-lock ()
    "Remove a stale `.emacs.desktop.lock' left by a crashed session."
    (when-let* ((_dir (and (boundp 'desktop-dirname) (stringp desktop-dirname)))
                (lock (expand-file-name ".emacs.desktop.lock" desktop-dirname))
                (_ (file-readable-p lock)))
      (let ((pid (ignore-errors
                   (string-to-number
                    (string-trim (with-temp-buffer
                                   (insert-file-contents lock)
                                   (buffer-string)))))))
        (when (or (not (natnump pid))
                  (not (zerop
                        (call-process "kill" nil nil nil "-0"
                                      (number-to-string pid)))))
          (delete-file lock)))))
  (scs/desktop-clear-stale-lock)
  ;; EWW buffers with nil history position break desktop save on quit; normalize
  ;; before desktop writes buffer metadata.
  (defun scs/desktop-sanitize-before-save ()
    "Repair buffer state that breaks `desktop-buffer-info' during desktop save.

EWW buffers with a nil `eww-history-position' make desktop save signal
`wrong-type-argument' (integerp nil) when quitting Emacs."
    (cl-loop for buf in (buffer-list)
             when (eq (buffer-local-value 'major-mode buf) 'eww-mode)
             do (with-current-buffer buf
                  (unless (natnump eww-history-position)
                    (setq eww-history-position 0)))))
  (add-hook 'desktop-save-hook #'scs/desktop-sanitize-before-save))
(desktop-save-mode t)
(size-indication-mode t)
(load-theme 'adwaita t) ;; used to be tango-dark

(setq byte-compile-error-on-warn nil)
(when (executable-find "ugrep")
  (setq grep-command "ugrep"))
(setq org-ql-search-directories-files-recursive t)
(setq org-safe-remote-resources
      '("\\`https://cdn\\.britannica\\.com/s:800x450,c:crop/66/195966-138-F9E7A828/facts-turtles\\.jpg\\'"))
(setq safe-local-variable-values
      '((tab . 4) (var . value) (Base . 10) (Package . CL-USER)
        (Syntax . COMMON-LISP)))
(setq windmove-wrap-around nil)

;; ----------------------------------------------------------
;; Frame / UI (GUI only)
;; ----------------------------------------------------------

(defun scs/apply-default-font (&optional frame)
  "Apply the standard GUI font to FRAME, or globally when FRAME is nil.

emacsclient frames are created after init, often when `display-graphic-p'
was nil during daemon startup, so font must be applied per frame."
  (let ((ws (if frame (frame-parameter frame 'window-system) window-system)))
    (when (memq ws '(ns mac win32 pgtkf))
      (set-face-attribute 'default (or frame t)
                          :family "Menlo"
                          :height 180
                          :weight 'normal
                          :width 'normal))))

(add-hook 'after-make-frame-functions
          ;; emacsclient frames may miss the startup-time font set in early-init.
          (lambda (frame) (scs/apply-default-font frame)))

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
;; init).  Karabiner rewrites Fn+C in Emacs to C-M-s-c (see karabiner.json)
;; so macOS does not open Control Center.  Lowercase s is Super, not Shift.
(when (eq system-type 'darwin)
  (define-key key-translation-map (kbd "C-M-s-c") (kbd "H-c")))

;; Another possibility would be to define each one separately
;; (define-key key-translation-map (kbd "C-M-S-s") (kbd "H"))
;; (define-key function-key-map (kbd "C-c H") 'event-apply-hyper-modifier)

;; ----------------------------------------------------------
;; Hyper key shortcuts (macOS only, via Karabiner)
;; ----------------------------------------------------------

(when (eq system-type 'darwin)
  ;;              key          command                   ;; mnemonic
  (global-set-key (kbd "H-x") 'helm-M-x)                 ;; eXecute
  (global-set-key (kbd "H-b") 'helm-mini)                ;; Buffer
  (global-set-key (kbd "H-k") 'kill-current-buffer)      ;; Kill
  (global-set-key (kbd "H-s") 'save-buffer)              ;; Save
  (global-set-key (kbd "H-r") 'revert-buffer-quick)      ;; Revert
  (global-set-key (kbd "H-g") 'grep)                     ;; Grep
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
  (global-set-key (kbd "H-a") 'org-agenda)               ;; Agenda
  (global-set-key (kbd "H-l") 'org-store-link)           ;; Link
  (global-set-key (kbd "H-i") 'helm-imenu)               ;; Imenu
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
;; C-h/M-h as backspace
;; ----------------------------------------------------------

;; CTRL-H as delete
;; `help` is mapped to F1
;; https://www.emacswiki.org/emacs/BackspaceKey

;; tip: Tab is available as C-i
;;      RET is available as C-j or C-m
;;      ESC is available as C-[

;; map C-h to backspace
(define-key key-translation-map [?\C-h] [?\C-?])

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
  (abbrev-mode))

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
;; company (active in-buffer completion UI; helm owns the minibuffer)
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
;; helm
;; ----------------------------------------------------------

;; https://emacs-helm.github.io/helm/
(use-package helm
  :el-get t
  :commands
  (helm-M-x helm-find-files helm-mini helm-buffers-list
            helm-filtered-bookmarks helm-show-kill-ring helm-occur
            helm-command-prefix helm-imenu helm-multi-files)
  :init
  (setq helm-M-x-fuzzy-match t)
  (setq helm-buffers-fuzzy-matching t)
  (setq helm-recentf-fuzzy-match t)
  (setq helm-move-to-line-cycle-in-source t)
  (setq helm-split-window-inside-p t)
  (setq helm-autoresize-max-height 40)
  (setq helm-autoresize-min-height 10)
  :bind
  (("M-x"       . helm-M-x)
   ("C-x C-f"   . helm-multi-files) ; name search (buffers/recent/fd)
   ("C-x f"     . helm-find-files)  ; path browser (was C-x C-f)
   ("C-x b"     . helm-mini)
   ("C-x C-b"   . helm-buffers-list)
   ("C-x r b"   . helm-filtered-bookmarks)
   ("M-y"       . helm-show-kill-ring)
   ("M-s o"     . helm-occur)
   ("C-c h"     . helm-command-prefix))
  :config
  (require 'helm-mode)
  (require 'helm-command)
  (require 'helm-files)
  (require 'helm-buffers)
  (require 'helm-bookmark)
  (require 'helm-ring)
  (require 'helm-imenu)
  (require 'helm-occur)
  (require 'helm-for-files)
  (helm-mode 1)
  (helm-autoresize-mode 1)

  ;; C-h is delete in this profile (key-translation-map).  Do not leave
  ;; Helm's help/debug family on a C-h prefix -- it fights muscle memory
  ;; and confuses the team.  Clear the C-h *subkeys first*, then drop the
  ;; prefix itself (the other order recreates a C-h keymap).  Helm help
  ;; is on ? ; debug/customize move under C-c on helm-map.
  (define-key helm-map (kbd "C-h C-h") nil)
  (define-key helm-map (kbd "C-h h") nil)
  (define-key helm-map (kbd "C-h C-d") nil)
  (define-key helm-map (kbd "C-h c") nil)
  (define-key helm-map (kbd "C-h d") nil)
  (define-key helm-map (kbd "C-h") nil)
  (define-key helm-map (kbd "?") #'helm-help)
  (define-key helm-map (kbd "C-c C-d") #'helm-enable-or-switch-to-debug)
  (define-key helm-map (kbd "C-c c") #'helm-customize-group)
  (define-key helm-map (kbd "C-c d") #'helm-debug-output)

  ;; helm-fd (C-/ in helm-find-files) is async and cannot fuzzy-match; it also
  ;; feeds the pattern to fd as literal substrings.  Replace with an in-buffer
  ;; source: list files once via fd, then use Helm fuzzy + space-separated tokens
  ;; (e.g. "thing illumos" -> illumos-notes-something.org).
  (defvar scs/helm-fuzzy-fd--cache (make-hash-table :test 'equal)
    "Cache mapping fd root directories to expanded file-name lists.")
  (defvar scs/helm-multi-files--fd-root nil
    "Current fd root used by `scs/helm-multi-files'.")
  (defvar scs/helm-source-fd-fuzzy nil
    "Helm source object for the current fuzzy fd file list.")
  (defvar scs/helm-multi-files--fd-on nil
    "Non-nil when the fuzzy fd source is active in `scs/helm-multi-files'.")

  (defun scs/helm-fd-executable ()
    "Return the fd executable Helm should use, or nil when unavailable."
    (or (and (boundp 'helm-fd-executable) helm-fd-executable)
        (executable-find "fdfind")
        (executable-find "fd")))

  (defun scs/helm-fd-root-unsafe-p (directory)
    "True when DIRECTORY is too broad to index synchronously (e.g. $HOME)."
    (let ((dir (file-name-as-directory (expand-file-name directory)))
          (home (file-name-as-directory (expand-file-name "~"))))
      (or (file-remote-p dir)
          (string= dir "/")
          (string= dir home))))

  (defun scs/helm-multi-files-fd-root (&optional arg)
    "Pick a safe fd root for `scs/helm-multi-files'.
Without ARG prefer notes (`howm-directory' or ~/notes); with ARG use `default-directory'."
    (let* ((notes (expand-file-name
                   (or (and (boundp 'howm-directory) howm-directory)
                       "~/notes")))
           (requested (expand-file-name
                       (if arg default-directory notes))))
      (cond
       ((not (scs/helm-fd-root-unsafe-p requested)) requested)
       ((not (scs/helm-fd-root-unsafe-p notes)) notes)
       (t (user-error "Refusing to index %s; open a narrower directory or set howm-directory"
                      requested)))))

  (defun scs/helm-fuzzy-fd--parse-buffer (_directory buffer)
    "Return existing files listed one per line in BUFFER."
    (with-current-buffer buffer
      (cl-loop for line in (split-string (buffer-string) "\n" t)
               when (file-exists-p line)
               collect (expand-file-name line))))

  ;; add: 2026-07-10
  (defun scs/helm-fuzzy-fd--notes-root-p (directory)
    "Return non-nil when DIRECTORY is the howm/notes tree (safe to sync-index)."
    (let ((dir (file-name-as-directory (expand-file-name directory)))
          (notes (file-name-as-directory
                  (expand-file-name
                   (or (and (boundp 'howm-directory) howm-directory)
                       "~/notes")))))
      (string= dir notes)))

  ;; add: 2026-07-10
  (defun scs/helm-fuzzy-fd--invalidate (directory)
    "Drop the fuzzy fd cache entry for DIRECTORY, if any."
    (remhash (expand-file-name directory) scs/helm-fuzzy-fd--cache))

  (defun scs/helm-fuzzy-fd--populate-cache-sync (directory)
    "Synchronously populate and return the fuzzy fd cache for DIRECTORY."
    (unless (gethash directory scs/helm-fuzzy-fd--cache)
      (let ((fd (scs/helm-fd-executable)))
        (cl-assert fd nil "Could not find fd executable")
        (puthash directory
                 (or (with-temp-buffer
                       (call-process fd nil (current-buffer) nil
                                     "--hidden" "--type" "f" "--glob" "*"
                                     directory)
                       (scs/helm-fuzzy-fd--parse-buffer directory (current-buffer)))
                     '())
                 scs/helm-fuzzy-fd--cache)))
    (gethash directory scs/helm-fuzzy-fd--cache))

  (defun scs/helm-fuzzy-fd--index-async (directory callback)
    "Run fd in the background; call CALLBACK when DIRECTORY is cached."
    (if (gethash directory scs/helm-fuzzy-fd--cache)
        (funcall callback)
      (let ((fd (scs/helm-fd-executable)))
        (unless fd
          (user-error "Could not find fd executable"))
        (let ((buf (generate-new-buffer " *scs-fd-index*")))
          (message "Indexing files under %s…" (abbreviate-file-name directory))
          (make-process
           :name "scs-fd-index"
           :buffer buf
           :noquery t
           :command (list fd "--hidden" "--type" "f" "--glob" "*" directory)
           :sentinel
           (lambda (_proc event)
             (if (string-match-p "finished\\|exited" event)
                 (puthash directory
                          (scs/helm-fuzzy-fd--parse-buffer directory buf)
                          scs/helm-fuzzy-fd--cache)
               (message "Fd indexing failed: %s" event))
             (when (buffer-live-p buf)
               (kill-buffer buf))
             (funcall callback)))))))

  (defun scs/helm-fuzzy-fd--file-list (directory)
    "Return cached fuzzy fd file names for DIRECTORY, or an empty list."
    (or (gethash directory scs/helm-fuzzy-fd--cache) '()))

  (defun scs/helm-rebuild-fd-fuzzy-source (directory)
    "Rebuild `scs/helm-source-fd-fuzzy' for DIRECTORY."
    (require 'helm-fd)
    (setq scs/helm-source-fd-fuzzy
          (helm-make-source "Fd fuzzy"
            'helm-source-in-buffer
            :requires-pattern 1
            :data (lambda ()
                    (or (gethash directory scs/helm-fuzzy-fd--cache) '()))
            :fuzzy-match helm-ff-fuzzy-matching
            :multimatch t
            :header-name
            (lambda (name)
              (format "%s (%s)"
                      name (abbreviate-file-name directory)))
            :action 'helm-type-file-actions
            :keymap 'helm-fd-map)))

  (defun scs/helm-make-fd-fuzzy-source (directory)
    "Return a Helm source for fuzzy fd search under DIRECTORY."
    (scs/helm-rebuild-fd-fuzzy-source directory)
    scs/helm-source-fd-fuzzy)

  (defun scs/helm-fuzzy-fd-1 (directory)
    "Fuzzy file search under DIRECTORY (replacement for `helm-fd-1')."
    (require 'helm-fd)
    (let ((directory (expand-file-name directory)))
      (cl-assert (scs/helm-fd-executable) nil "Could not find fd executable")
      (cl-assert (not (file-remote-p directory))
                 nil "Fd not supported on remote directories")
      (when (scs/helm-fd-root-unsafe-p directory)
        (user-error "Directory too broad for fuzzy fd (%s); cd into a subdir first"
                    directory))
      (when helm-current-prefix-arg
        (scs/helm-fuzzy-fd--invalidate directory))
      (scs/helm-fuzzy-fd--populate-cache-sync directory)
      (scs/helm-rebuild-fd-fuzzy-source directory)
      (let ((default-directory directory))
        (helm :sources 'scs/helm-source-fd-fuzzy
              :buffer "*helm fd*"
              :ff-transformer-show-only-basename nil))))

  ;; Replace built-in helm-fd-1 with our synchronous cache + Helm fuzzy matcher
  ;; so C-/ inside find-files can match space-separated tokens on a fixed root.
  (advice-add 'helm-fd-1 :override #'scs/helm-fuzzy-fd-1)

  (defun scs/helm-multi-files--fd-present-p ()
    "Return non-nil when the fuzzy fd source is in `helm-sources'."
    (with-helm-buffer
      (cl-loop for src in helm-sources
               thereis (equal (assoc-default 'name src) "Fd fuzzy"))))

  (defun scs/helm-multi-files-enable-fd ()
    "Add the fuzzy fd source to the live Helm multi-files session."
    (when (and helm-buffer (get-buffer helm-buffer))
      (with-helm-buffer
        (unless (scs/helm-multi-files--fd-present-p)
          (scs/helm-rebuild-fd-fuzzy-source scs/helm-multi-files--fd-root)
          (helm-set-sources (append helm-sources (list scs/helm-source-fd-fuzzy)))
          (setq scs/helm-multi-files--fd-on t)
          (helm-update)))))

  (defun scs/helm-multi-files-disable-fd ()
    "Remove the fuzzy fd source from the live Helm multi-files session."
    (with-helm-alive-p
      (with-helm-buffer
        (setq helm-sources
              (cl-remove-if (lambda (src)
                              (equal (assoc-default 'name src) "Fd fuzzy"))
                            helm-sources)
              scs/helm-multi-files--fd-on nil)
        (helm-set-source-filter nil)
        (helm-update))))

  (defun scs/helm-multi-files-toggle-fd ()
    "Toggle fuzzy fd source in `scs/helm-multi-files' (HFF `C-/')."
    (interactive)
    (with-helm-alive-p
      (if scs/helm-multi-files--fd-on
          (scs/helm-multi-files-disable-fd)
        (if (gethash scs/helm-multi-files--fd-root scs/helm-fuzzy-fd--cache)
            (scs/helm-multi-files-enable-fd)
          (scs/helm-fuzzy-fd--index-async
           scs/helm-multi-files--fd-root
           #'scs/helm-multi-files-enable-fd)))))
  (put 'scs/helm-multi-files-toggle-fd 'helm-only t)

  ;; Notes root: sync index (measured ~10ms).  Other roots: open Helm
  ;; immediately and attach fd when the async index finishes.  C-/ toggles
  ;; fd off/on.  C-u uses `default-directory' and refreshes the fd cache.
  ;; fix: 2026-07-10 — async cold-cache for non-notes roots
  (defun scs/helm-multi-files (&optional arg)
    "Like `helm-multi-files' with fuzzy fd (HFF `C-/') under notes by default."
    (interactive "P")
    (require 'helm-for-files)
    (require 'helm-x-files)
    (unless helm-source-buffers-list
      (setq helm-source-buffers-list
            (helm-make-source "Buffers" 'helm-source-buffers)))
    (setq scs/helm-multi-files--fd-root (scs/helm-multi-files-fd-root arg)
          scs/helm-multi-files--fd-on nil)
    (when arg (scs/helm-fuzzy-fd--invalidate scs/helm-multi-files--fd-root))
    (let* ((root scs/helm-multi-files--fd-root)
           (safe (not (scs/helm-fd-root-unsafe-p root)))
           (cached (and safe (gethash root scs/helm-fuzzy-fd--cache)))
           (sync-ok (and safe (or cached (scs/helm-fuzzy-fd--notes-root-p root))))
           (sources (remove 'helm-source-locate helm-for-files-preferred-list))
           (old-key (lookup-key helm-map (kbd "C-/"))))
      (when (and safe sync-ok)
        (scs/helm-fuzzy-fd--populate-cache-sync root)
        (scs/helm-rebuild-fd-fuzzy-source root)
        (setq sources (append sources '(scs/helm-source-fd-fuzzy))
              scs/helm-multi-files--fd-on t))
      (when (and safe (not sync-ok))
        (scs/helm-fuzzy-fd--index-async root #'scs/helm-multi-files-enable-fd))
      (unwind-protect
          (progn
            (define-key helm-map (kbd "C-/") #'scs/helm-multi-files-toggle-fd)
            (helm :sources sources
                  :buffer "*helm multi files*"
                  :ff-transformer-show-only-basename nil
                  :truncate-lines helm-buffers-truncate-lines))
        (if old-key
            (define-key helm-map (kbd "C-/") old-key)
          (define-key helm-map (kbd "C-/") nil)))))

  (advice-add 'helm-multi-files :override #'scs/helm-multi-files))

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
        ;; add: 2026-07-10 — keep org-id + fd cache in sync after rename
        (scs/org-id-update-current-file)
        (when (fboundp 'scs/helm-fuzzy-fd--invalidate)
          (scs/helm-fuzzy-fd--invalidate howm-directory))
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

  ;; Org steals RET; use C-c , RET to follow action-lock links in howm notes.
  (define-key howm-mode-map (kbd "C-c , RET") 'action-lock-magic-return)
  (define-key howm-mode-map (kbd "C-c , <return>") 'action-lock-magic-return)
  (define-key howm-mode-map (kbd "<tab>") 'action-lock-goto-next-link)
  (define-key howm-mode-map (kbd "<backtab>") 'action-lock-goto-previous-link))

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

No-op outside `howm-directory'.  Invalidates the Helm fd cache for notes
when IDs change so filename search stays consistent."
  (when (and buffer-file-name
             (string-match-p "\\.org\\'" buffer-file-name)
             (boundp 'howm-directory)
             (file-directory-p howm-directory)
             (file-in-directory-p buffer-file-name howm-directory))
    (scs/org-id--configure-locations-file)
    (org-id-update-id-locations (list buffer-file-name) t)
    (when (fboundp 'scs/helm-fuzzy-fd--invalidate)
      (scs/helm-fuzzy-fd--invalidate howm-directory))))

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
;; updates only the current file's entries and refreshes Helm's fd cache.
(add-hook 'howm-create-hook #'scs/howm-add-org-id)
(add-hook 'emacs-startup-hook #'scs/org-id-init 100)
;; add: 2026-07-10
(defun scs/howm-setup-id-on-save ()
  "Buffer-local after-save hook: sync org-id and fd cache for this note."
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
  (require 'org-tools))

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

;; org-capture
;; (hook defined in Custom functions section above)

;; ----------------------------------------------------------
;; recentf
;; ----------------------------------------------------------

;; jwiegley
(use-package recentf
  :defer 1
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
  :no-require t
  :bind ("C-c M-v" .
         (lambda () (interactive)
           (call-process "/usr/bin/open" nil nil nil
                         "-R" (expand-file-name
                               (or (buffer-file-name)
                                   default-directory))))))

;; ----------------------------------------------------------
;; savehist
;; ----------------------------------------------------------

(use-package savehist
  :unless noninteractive
  :custom
  (savehist-additional-variables
   '(file-name-history
     kmacro-ring
     compile-history
     compile-command))
  (savehist-autosave-interval 60)
  (savehist-ignored-variables
   '(load-history
     flyspell-auto-correct-ring
     org-roam-node-history
     magit-revision-history
     org-read-date-history
     query-replace-history
     yes-or-no-p-history
     kill-ring))
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
(use-package transient
  :el-get t)

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
  :defer t
  :config
  (global-diff-hl-mode)
  (unless (display-graphic-p)
    (diff-hl-margin-mode)))

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

;; Use fd instead of find for dired
(use-package fd-dired
  :el-get t
  :if (executable-find "fd")
  :bind ("C-c f" . fd-dired))

;; ----------------------------------------------------------
;; wgrep
;; ----------------------------------------------------------

;; Edit grep results in-place and apply changes back to files
(use-package wgrep :el-get t)


;; ----------------------------------------------------------
;; mail lab (mu4e + notmuch on ~/mail)
;; ----------------------------------------------------------

;; Homebrew ships mu4e/notmuch Lisp; lisp/scs-mail-lab.el wires
;; load-path, BBDB contacts, org-msg compose, and msmtp send.
;; Sync stays in the terminal (mbsync / mu index / notmuch new).
;; add: 2026-07-20
(use-package bbdb
  :el-get t
  :defer t)

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
