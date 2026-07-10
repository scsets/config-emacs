;;; scs-cl.el --- Eager Common Lisp toolkit for this config  -*- lexical-binding: t; -*-

;; Author: SCS
;; Keywords: lisp, extensions
;; Package-Requires: ((emacs "29.1"))

;;; Commentary:
;;
;; Load the full Emacs Common Lisp extension stack from
;; lisp/emacs-lisp/cl-*.el so owned config can rely on CL idioms
;; without per-call autoloads.
;;
;; Features required (see emacs-mirror emacs/lisp/emacs-lisp):
;;   cl-lib, cl-macs, cl-seq, cl-extra, cl-generic, cl-print, cl-indent,
;;   plus cl-preloaded and cl-loaddefs when present.
;;
;; Prefer (require 'scs-cl) over bare (require 'cl-lib) in this repo.

;;; Code:

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
