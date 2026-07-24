;;; scs-cl.el --- Eager Common Lisp toolkit for this config  -*- lexical-binding: t; -*-

;; Author: SCS
;; Keywords: lisp, extensions
;; Package-Requires: ((emacs "29.1"))

;;; Commentary:
;;
;; Problem:
;;   Much of this config uses Common Lisp-style helpers (loop, destructuring,
;;   generic functions, pretty-printing).  Emacs ships those in separate
;;   cl-* libraries that are normally loaded on demand via autoloads.
;;   Scattered (require 'cl-lib) calls are easy to forget and produce
;;   confusing "void function" errors at runtime.
;;
;; Solution:
;;   One place, early in init, loads the full Emacs CL extension stack from
;;   lisp/emacs-lisp/cl-*.el so owned code can assume CL idioms are present.
;;
;; Modules pulled in (see emacs-mirror emacs/lisp/emacs-lisp):
;;   cl-lib, cl-macs, cl-seq, cl-extra, cl-generic, cl-print, cl-indent,
;;   plus cl-preloaded and cl-loaddefs when your Emacs build includes them.
;;
;; How to check:
;;   M-x eval-expression RET (featurep 'cl-lib) RET  should return t after
;;   init.  In this repo, prefer (require 'scs-cl) over bare (require 'cl-lib)
;;   so the stack stays consistent everywhere.

;;; Change Log:
;; Newest first.  File-local so readers need not dig through VCS.
;; fix: 2026-07-24 -- teachable Commentary for SCS team
;; add: 2026-07-10 -- eager load of Emacs CL toolkit

;;; Code:

;; Load order matches upstream dependencies: cl-lib first, then macros and
;; data-structure helpers, then generics, printing, and indentation support.
(require 'cl-lib)
(require 'cl-macs)
(require 'cl-seq)
(require 'cl-extra)
(require 'cl-generic)
(require 'cl-print)
(require 'cl-indent)
(require 'cl-preloaded)
(require 'cl-loaddefs)

(provide 'scs-cl)

;;; scs-cl.el ends here
