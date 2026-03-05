;;; -*- lexical-binding: t -*-
;; $Id: custom.el,v 1.2 2026/03/05 17:04:49 scs Exp $
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(blink-cursor-mode nil)
 '(byte-compile-error-on-warn nil)
 '(column-number-mode t)
 '(custom-enabled-themes '(tango-dark))
 '(denote-directory "~/note/")
 '(denote-file-type 'org)
 '(desktop-save-mode t)
 '(grep-command "ugrep")
 '(org-ql-search-directories-files-recursive t)
 '(org-safe-remote-resources
   '("\\`https://cdn\\.britannica\\.com/s:800x450,c:crop/66/195966-138-F9E7A828/facts-turtles\\.jpg\\'"))
 '(package-selected-packages
   '(cape company corfu delight exec-path-from-shell flycheck-lilypond
          framemove haproxy-mode howm imenu-list impatient-mode
          keycast minions move-dup no-littering org-auto-expand
          org-contrib org2blog ox-pandoc reveal-in-osx-finder slime
          xeft))
 '(package-vc-selected-packages
   '((framemove :url "https://github.com/emacsmirror/framemove")
     (denote-search :url "https://github.com/lmq-10/denote-search"
                    :doc "README.org")))
 '(safe-local-variable-values
   '((tab . 4) (var . value) (Base . 10) (Package . CL-USER)
     (Syntax . COMMON-LISP)))
 '(size-indication-mode t)
 '(svn-status-svn-environment-var-list '("LC_MESSAGES=C" "LANG=C" "LC_ALL=C"))
 '(tool-bar-mode nil)
 '(windmove-wrap-around nil)
 '(xeft-default-extension "org")
 '(xeft-directory "~/note")
 '(xeft-recursive t))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(default ((t (:family "Menlo" :foundry "nil" :slant normal :weight regular :height 180 :width normal)))))
