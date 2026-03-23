;;; init.el --- Personal configuration  -*- lexical-binding: t; -*-
;;
;; $Id: init.el,v 1.16 2026/03/23 07:36:21 scs Exp $
;;
;;; Commentary:
;;  Main Emacs configuration.  Requires Emacs 29+.
;;
;;; Code:


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Custom functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; https://emacs.stackexchange.com/a/28927
;; Call this anywhere to end loading init file, good to debug.
(defun my-exit ()
  "Abort loading the current file by jumping to its end."
  (with-current-buffer " *load*"
    (goto-char (point-max))))

;; http://www.emacswiki.org/emacs/ParenthesisMatching#toc4
;; bind C-% to goto-match-paren
;; note, cursor must right before/on/after paren/brace/bracket
(defun goto-match-paren (arg)
  "Go to the matching  if on (){}[], similar to vi style of % "
  (interactive "p")
  ;; first, check for "outside of bracket" positions expected by forward-sexp, etc.
  (cond ((looking-at "[\[\(\{]") (forward-sexp))
        ((looking-back "[\]\)\}]" 1) (backward-sexp))
        ;; now, try to succeed from inside of a bracket
        ((looking-at "[\]\)\}]") (forward-char) (backward-sexp))
        ((looking-back "[\[\(\{]" 1) (backward-char) (forward-sexp))
        (t nil)))

;; delete visited file and buffer
;; https://zck.org/deleting-files-in-emacs
(defun delete-visited-file (buffer-name)
  "Delete the file visited by the buffer named BUFFER-NAME."
  (interactive "bDelete file visited by buffer ")
  (let* ((buffer (get-buffer buffer-name))
         (filename (buffer-file-name buffer)))
    (when buffer
      (when (and filename
                 (file-exists-p filename))
        (delete-file filename))
      (kill-buffer buffer))))

;; kill all dired buffers
(defun kill-dired-buffers ()
  "Kill every buffer whose major mode is `dired-mode'."
  (interactive)
  (mapc (lambda (buffer)
          (when (eq 'dired-mode (buffer-local-value 'major-mode buffer))
            (kill-buffer buffer)))
        (buffer-list)))

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
(defun my/org-capture-finalize-hook ()
  "Close frame after org-capture if it was opened for capture."
  (when (and (> (length (frame-list)) 1)  ; More than one frame
             (frame-parameter nil 'client)) ; Frame created by emacsclient
    (delete-frame)))

(add-hook 'org-capture-after-finalize-hook 'my/org-capture-finalize-hook)

(defun my/switch-to-scratch-buffer (f)
  "Switch to the *scratch* buffer in newly created frame F."
  (with-selected-frame f
    (remember-notes t)))

(add-hook 'after-make-frame-functions #'my/switch-to-scratch-buffer)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Package managers
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; ----------------------------------------------------------
;; use-package
;; ----------------------------------------------------------

;; use-package is built-in since Emacs 29
(defvar use-package-enable-imenu-support t)
(setq use-package-always-ensure nil)
(require 'bind-key)
(require 'use-package)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; General settings
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; ----------------------------------------------------------
;; Server
;; ----------------------------------------------------------

(require 'server)
(unless (server-running-p) (server-start))

;; Second server instance via TCP for Scrim
(when (eq system-type 'darwin)
  (let ((server-name "scrim")
        (server-use-tcp t))
    (unless (server-running-p "scrim") (server-start))))

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

;; Default line length
(setq-default fill-column 70)

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
(setq require-final-newline t)
(add-hook 'before-save-hook #'delete-trailing-whitespace)

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

(setq-default history-length 1000)

;; ----------------------------------------------------------
;; Fido-vertical-mode
;; ----------------------------------------------------------

;; <2024-04-13>
(fido-vertical-mode t)

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

;;   italian-alt-postfix ('IT<' in mode line)
;;   Italian (Italiano) input method with postfix modifiers

;;   a' -> a'    A' -> A'    a` -> a`    A` -> A`    i^ -> i^    << -> <<
;;   e' -> e'    E' -> E'    e` -> e`    E` -> E`    I^ -> I^    >> -> >>
;;   i' -> i'    I' -> I'    i` -> i`    I` -> I`               o_ -> o_
;;   o' -> o'    O' -> O'    o` -> o`    O` -> O`               a_ -> a_
;;   u' -> u'    U' -> U'    u` -> u`    U` -> U`

;;   This method is for purists who like accents the old way.
;;   Doubling the postfix separates the letter and postfix: e.g. a`` -> a`

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

;; Redirect customize output so it never pollutes init.el
(setq custom-file (expand-file-name "custom.el" temporary-file-directory))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Settings formerly in custom.el
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(blink-cursor-mode -1)
(desktop-save-mode t)
(size-indication-mode t)
(load-theme 'tango-dark t)

(setq byte-compile-error-on-warn nil)
(setq grep-command "ugrep")
(setq org-ql-search-directories-files-recursive t)
(setq org-safe-remote-resources
      '("\\`https://cdn\\.britannica\\.com/s:800x450,c:crop/66/195966-138-F9E7A828/facts-turtles\\.jpg\\'"))
(setq safe-local-variable-values
      '((tab . 4) (var . value) (Base . 10) (Package . CL-USER)
        (Syntax . COMMON-LISP)))
(setq windmove-wrap-around nil)

;; Font (GUI only)
(when (display-graphic-p)
  (set-face-attribute 'default nil
                      :family "Menlo"
                      :height 180
                      :weight 'normal
                      :width 'normal))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Keybindings
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; ----------------------------------------------------------
;; macOS modifier keys
;; ----------------------------------------------------------

;; set keys for emacs in osx (macOS-only variables)
(when (eq system-type 'darwin)
  (setq mac-command-modifier 'control) ; make cmd key do Meta
  (setq mac-option-modifier 'meta) ; make opt key do Super
  (setq mac-control-modifier 'super) ; make Control key do Control

  ;; We define CAPS LOCK as Fn with Karabiner, then we can use it here
  ;; it works well!
  (setq ns-function-modifier 'hyper))  ; make Fn key do Hyper

;; Another possibility would be to define each one separately
;; (define-key key-translation-map (kbd "C-M-S-s") (kbd "H"))
;; (define-key function-key-map (kbd "C-c H") 'event-apply-hyper-modifier)

;; ----------------------------------------------------------
;; Hyper-x
;; ----------------------------------------------------------

(global-set-key (kbd "H-x") 'execute-extended-command) ; Execute an extended command (M-x)

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

;; Do not exit with C-x C-c
(global-unset-key (kbd "C-x C-c"))

;; Instead use this
(global-set-key (kbd "C-x C-c C-c") 'save-buffers-kill-terminal)
(global-set-key (kbd "C-x C-c q")   'keyboard-escape-quit)

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

;; ----------------------------------------------------------
;; Timestamp -- S-f9 (rebind from f9, conflicts with howm)
;; ----------------------------------------------------------

(define-key global-map (kbd "<S-f9>")
  (lambda () (interactive)
    (when (eq major-mode 'org-mode)
      (org-insert-timestamp nil nil :inactive " " " pds"))))

;; Example of timestamp
;; (org-insert-timestamp nil nil :inactive "Date: " " pdn")


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Packages (alphabetical, with dependency exceptions noted)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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
  :ensure t
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
;; company
;; ----------------------------------------------------------

(use-package company
  :ensure t
  :defer 2
  :config
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

(use-package delight :ensure t)

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
  :ensure t
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
     (concat (abbreviate-file-name (eshell/pwd))
             (if (= (user-uid) 0)
                 " # " " $ "))))
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
  (add-hook 'eshell-first-time-mode-hook #'eshell-initialize))

(use-package eshell-toggle
  :ensure t
  :bind ("C-x C-z" . eshell-toggle))

(use-package eshell-bookmark
  :hook (eshell-mode . eshell-bookmark-setup))

(use-package eshell-up
  :ensure t
  :commands eshell-up)

(use-package eshell-z
  :ensure t
  :after eshell)

;; ----------------------------------------------------------
;; flycheck
;; ----------------------------------------------------------

(use-package flycheck
  :ensure t
  :defer 3
  :config (global-flycheck-mode))

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
;; Install via package-vc if missing (avoids re-install prompt on every startup)
(unless (package-installed-p 'framemove)
  (package-vc-install '(framemove :url "https://github.com/emacsmirror/framemove")))

(use-package framemove
  :init
  (windmove-default-keybindings)
  (setq framemove-hook-into-windmove t))

;; ----------------------------------------------------------
;; haproxy-mode
;; ----------------------------------------------------------

;; https://github.com/port19x/haproxy-mode
(use-package haproxy-mode :ensure t)

;; ----------------------------------------------------------
;; hl-todo
;; ----------------------------------------------------------

(use-package hl-todo
  :ensure t
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
  :ensure t
  :after org
  :init
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

  :bind
  ("<f9>" . howm-list-all)
  ("<C-f9>" . howm-create)

  :hook
  ;; Set buffer names from note title.
  (howm-mode . howm-mode-set-buffer-name)
  ;; Enable howm minor mode in all org buffers for comefrom links.
  (org-mode . howm-mode)

  :config
  (setq howm-directory "~/notes")
  (setq howm-home-directory howm-directory)

  ;; Sort by mtime so recently-touched notes appear first.
  (setq howm-normalizer 'howm-sort-items-by-mtime)
  ;; Preview contents in summary view.
  (setq howm-view-contents-limit 200)
  ;; Open summary and content side-by-side.
  (setq howm-view-split-horizontally t)
  ;; Keep summary visible when selecting an item.
  (setq howm-view-summary-persistent t)

  ;; Rename howm files to title_tags_date.org format.
  ;; Call M-x howm-rename-to-slug interactively when ready to rename.
  ;; Format example: my-note-title_tag1-tag2_20260307.org

  (defun scs--howm-slugify (str)
    "Convert STR to a lowercase slug (alphanumeric and hyphens).
Strips leading/trailing hyphens and collapses runs of hyphens."
    (replace-regexp-in-string
     "^-\\|-$" ""
     (downcase
      (replace-regexp-in-string
       "-\\{2,\\}" "-"
       (replace-regexp-in-string
        "[^a-zA-Z0-9-]" "-"
        (string-trim str))))))

  (defun scs--howm-desired-filename ()
    "Compute the desired filename from the note's title, filetags, and date.
Reads the first org heading as title and #+filetags: as tags.
Returns a filename like title_tags_20260307.org, or nil if no title."
    (save-excursion
      (goto-char (point-min))
      (let ((title (when (re-search-forward
                          (concat "^" howm-view-title-header " +\\(.+\\)$")
                          nil t)
                     (match-string 1)))
            (tags (progn
                    (goto-char (point-min))
                    (when (re-search-forward
                           "^#\\+filetags: *\\(.+\\)$" nil t)
                      (match-string 1))))
            (date (format-time-string "%Y%m%d")))
        (when (and title (not (string-blank-p title)))
          (let ((slug (scs--howm-slugify title))
                (tag-part (if (and tags (not (string-blank-p tags)))
                              (scs--howm-slugify
                               (replace-regexp-in-string ":" " " tags))
                            nil)))
            (concat slug
                    (when tag-part (concat "_" tag-part))
                    "_" date ".org"))))))

  (defun howm-rename-to-slug ()
    "Rename the current howm note to title_tags_date.org format.
Derives the filename from the first org heading and #+filetags: line.
Prompts for confirmation before renaming.  Does nothing if:
- The buffer is not a howm note in `howm-directory'.
- No title heading is found.
- The filename already matches.
- A file with the target name already exists."
    (interactive)
    (unless (and howm-mode buffer-file-name
                 (file-in-directory-p buffer-file-name howm-directory))
      (user-error "Not a howm note in %s" howm-directory))
    (let ((desired (scs--howm-desired-filename)))
      (unless desired
        (user-error "No title heading found"))
      (if (string= (file-name-nondirectory buffer-file-name) desired)
          (message "Filename already matches: %s" desired)
        (let ((new-path (expand-file-name desired
                                          (file-name-directory buffer-file-name))))
          (when (file-exists-p new-path)
            (user-error "Target file already exists: %s" desired))
          (when (y-or-n-p (format "Rename to %s? " desired))
            (rename-file buffer-file-name new-path)
            (set-visited-file-name new-path t t)
            (message "Renamed to %s" desired))))))

  ;; Tag/name action-lock rules: #tag, +tag, @name become clickable links.
  ;; Clicking searches across howm notes (uses rg via howm-view-grep).
  (defun scs--howm-grep-tag (tag)
    "Search howm notes for TAG using howm's native search."
    (howm-keyword-search tag nil nil))

  (defun scs--howm-add-tag-rules ()
    "Add action-lock rules for #tag, +tag, and @name patterns."
    (dolist (rule
             (list
              ;; #tag -- topics/categories
              (action-lock-general #'scs--howm-grep-tag
                                   "\\(?:^\\|[ \t]\\)\\(#[a-zA-Z0-9_-]+\\)" 1 1)
              ;; +tag -- projects/groups
              (action-lock-general #'scs--howm-grep-tag
                                   "\\(?:^\\|[ \t]\\)\\(\\+[a-zA-Z0-9_-]+\\)" 1 1)
              ;; @name or @@tag -- people, files, resources
              (action-lock-general #'scs--howm-grep-tag
                                   "\\(?:^\\|[ \t]\\)\\(@@?[a-zA-Z0-9_.-]+\\)" 1 1)))
      (add-to-list 'action-lock-rules rule t)))

  (add-hook 'howm-mode-hook #'scs--howm-add-tag-rules))

;; ----------------------------------------------------------
;; org-node (find howm notes by ID)
;; ----------------------------------------------------------

;; https://baty.net/posts/2025/12/finding-howm-notes-with-org-node/
;; org-node gives us fast ID-based linking across howm notes.
(use-package org-node
  :ensure t
  :after howm
  :hook
  ;; New howm notes automatically get an org-id via org-node.
  (howm-create . org-node-nodeify-entry)
  :config
  ;; Include the howm directory in org-id's search scope.
  (add-to-list 'org-id-extra-files
               (directory-files-recursively howm-directory "\\.org\\'"))
  (org-node-cache-ensure))

;; ----------------------------------------------------------
;; imenu-list
;; ----------------------------------------------------------

;; https://github.com/bmag/imenu-list
;; <2024-06-20>
(use-package imenu-list
  :ensure t
  :bind
  ("C-c i" . imenu-list-smart-toggle)
  :custom
  (imenu-list-focus-after-activation t)
  (imenu-list-auto-resize nil))

;; ----------------------------------------------------------
;; impatient-mode
;; ----------------------------------------------------------

(use-package impatient-mode :ensure t)

;; ----------------------------------------------------------
;; keycast
;; ----------------------------------------------------------

;; (keycast-tab-bar-mode)
(use-package keycast :ensure t)

;; ----------------------------------------------------------
;; minions
;; ----------------------------------------------------------

(use-package minions :ensure t)

;; ----------------------------------------------------------
;; move-dup
;; ----------------------------------------------------------

;; https://github.com/wyuenho/move-dup
;; <2024-05-14>
(use-package move-dup
  :ensure t
  :bind (("M-<up>"     . move-dup-move-lines-up)
         ("C-M-<up>"   . move-dup-duplicate-up)
         ("M-<down>"   . move-dup-move-lines-down)
         ("C-M-<down>" . move-dup-duplicate-down))
  :config
  (global-move-dup-mode))

;; ----------------------------------------------------------
;; no-littering
;; ----------------------------------------------------------

;; https://github.com/emacscollective/no-littering
(use-package "no-littering"
  :ensure t
  :init
  (let ((dir (no-littering-expand-var-file-name "lock-files/")))
    (make-directory dir t)
    (setq lock-file-name-transforms `((".*" ,dir t))))
  (no-littering-theme-backups))

;; ----------------------------------------------------------
;; org
;; ----------------------------------------------------------

(use-package org
  :ensure t
  :defer t)

;; org-protocol needed for macOS scrim -- load after server starts
(with-eval-after-load 'server
  (require 'org-protocol))

;; :vip:
(setq org-fold-catch-invisible-edits 'show-and-error)

;; :vip:
;;  Query to the user, if it is OK to kill that hidden subtree.
;; When nil, kill without remorse.
(setq org-ctrl-k-protect-subtree t)

;; Enable BIND property. This will work:
;; #+BIND variable "scs"
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
  :ensure t
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
  :ensure t
  :after org
  :config
  (org-auto-expand-mode))

;; org-babel -- loads when org loads
(use-package ob
  :after org
  :config
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
     ;; (jupyter    . t)
     ))                  ; must be last

  (remove-hook 'kill-emacs-hook 'org-babel-remove-temporary-directory)

  (defun org-babel-sh-strip-weird-long-prompt (string)
    "Remove prompt cruft from a string of shell output."
    (while (string-match "^.+?;C;\xef\xbf\xbd" string)
      (setq string (substring string (match-end 0))))
    string)

  (advice-add 'org-babel-edit-prep:emacs-lisp :after
              (lambda (&rest _) (run-hooks 'emacs-lisp-mode-hook)))

  (setq org-babel-default-header-args:sh    '((:results . "output replace"))
        org-babel-default-header-args:bash  '((:results . "output replace"))
        org-babel-default-header-args:shell '((:results . "output replace"))
        ;; org-babel-default-header-args:jupyter-python
        ;; '((:async . "yes")
        ;;   (:session . "py")
        ;;   (:kernel . "sagemath"))
        )

  (use-package ob-plantuml)
  (use-package ob-ditaa)

  (setq org-confirm-babel-evaluate nil)
  (let ((pdir (getenv "PROFILE_DIR")))
    (when pdir
      (let ((plantuml (expand-file-name "lib/plantuml.jar" pdir))
            (ditaa (expand-file-name "lib/ditaa.jar" pdir)))
        (when (file-exists-p plantuml)
          (setq org-plantuml-jar-path plantuml))
        (when (file-exists-p ditaa)
          (setq org-ditaa-jar-path ditaa)))))

  (add-to-list 'org-src-lang-modes (quote ("plantuml" . plantuml))))

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
  (defun recentf-add-dired-directory ()
    "Add directories visit by dired into recentf."
    (if (and dired-directory
             (file-directory-p dired-directory)
             (not (string= "/" dired-directory)))
        (let ((last-idx (1- (length dired-directory))))
          (recentf-add-file
           (if (= ?/ (aref dired-directory last-idx))
               (substring dired-directory 0 last-idx)
             dired-directory)))))
  :hook (dired-mode . recentf-add-dired-directory)
  :config
  (add-to-list 'recentf-exclude
               (recentf-expand-file-name no-littering-var-directory))
  (add-to-list 'recentf-exclude
               (recentf-expand-file-name no-littering-etc-directory))
  (recentf-mode 1))

;; ----------------------------------------------------------
;; reveal-in-osx-finder (macOS only)
;; ----------------------------------------------------------

(use-package reveal-in-osx-finder
  :ensure t
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
  :ensure t
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

(use-package "sly"
  :ensure t
  :disabled t
  :init
  (setq inferior-lisp-program (expand-file-name "~/lisp/lispworks/lw-console"))
;;(setq inferior-lisp-program "/Applications/LispWorks\ 8.0\ (64-bit)/LispWorks\ (64-bit).app/Contents/MacOS/lispworks-8-0-0-macos64-universal")
  (setq sly-protocol-version 'ignore)
  (setq sly-net-coding-system 'utf-8-unix)
  :config
  (use-package "sly-asdf" :ensure t)
  (use-package "sly-macrostep" :ensure t)
  (use-package "sly-repl-ansi-color" :ensure t)
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
  (setq tramp-auto-save-directory
        (expand-file-name "tramp-autosave" temporary-file-directory))

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

  ;; Hardcode /tmp to prevent hundreds of shell commands probing temp dir
  (put 'temporary-file-directory 'standard-value '("/tmp"))

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
  )

;; Connection-local variables
;; Direct async processes for all SSH connections (Emacs 30)
(connection-local-set-profile-variables
 'remote-direct-async-process
 '((tramp-direct-async-process . t)))

(connection-local-set-profiles
 '(:application tramp :protocol "ssh")
 'remote-direct-async-process)

(connection-local-set-profiles
 '(:application tramp :protocol "scp")
 'remote-direct-async-process)

;; FreeBSD-specific: use GNU ls if available (for dired --dired flag)
(connection-local-set-profile-variables
 'remote-bsd-process
 '((insert-directory-program . "gls")))

;; Apply to known FreeBSD hosts (add patterns as needed)
;; (connection-local-set-profiles
;;  '(:application tramp :machine "freebsd-host")
;;  'remote-bsd-process)

;; Opening eshell on a remote TRAMP path gives a remote shell automatically.
;; cd /ssh:host:/path then M-x eshell -- commands run on the remote host.

;; C-x d /ssh:host:/path -- browse remote filesystem
;; With ControlMaster, subsequent dired buffers on the same host are instant.

;; Useful TRAMP shortcuts
(defun my/tramp-cleanup ()
  "Clean up all TRAMP connections and buffers."
  (interactive)
  (require 'tramp)
  (tramp-cleanup-all-connections)
  (tramp-cleanup-all-buffers)
  (message "TRAMP: all connections and buffers cleaned up"))

(defun my/tramp-reopen ()
  "Revert current remote buffer, refreshing from remote host."
  (interactive)
  (when (file-remote-p default-directory)
    (revert-buffer t t)
    (message "Refreshed from remote")))

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
  :ensure t
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


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Finalization
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(provide 'init)

;;; init.el ends here
