;;; scs-mx-history.el --- Keep M-x history even when the command errors  -*- lexical-binding: t; -*-

;; Filename: scs-mx-history.el
;; Description: Pin the last M-x command on extended-command-history
;; Author: SCS
;; Copyright: Copyright (C) 2026, SCS, all rights reserved.
;; Created: 2026-09-03 Thu 09:36
;; Version: 0.1.0
;; Last-Updated: 2026-09-03 Thu 09:36
;; Update #: 0
;; Keywords: convenience, minibuffer, completion
;; Package-Requires: ((emacs "29.1"))

;;; Commentary:
;;
;; Problem
;; -------
;; M-x candidates are ordered from `extended-command-history': a list of
;; command-name strings, newest first.  Vertico reads that list and puts
;; the most recent name on top; names that appear more than once get a
;; frequency bump (frecency).  `completing-read' usually prepends the
;; name when you press RET, before the command body runs.  If something
;; skips that prepend, or you later expect the failed command to stay
;; first, a command that signals would drop off the top of the next M-x.
;;
;; Solution
;; --------
;; `scs/mx-history-remember' writes one name to the front of
;; `extended-command-history' when it is not already the car.
;; `scs/mx-history-around-execute' wraps `execute-extended-command' (and
;; the buffer-local M-X variant) in `unwind-protect' so the pin still
;; runs after an error.  Successful M-x that already prepended the name
;; is left alone: a second copy would look like extra frequency.
;;
;; The data is the list.  Sorting lives in Vertico (`vertico-sort');
;; this file only keeps the list honest.
;;
;; How to check
;; ------------
;;   M-x a command that errors, then M-x again -- that name is first.
;;
;;   emacs -Q --batch -L lisp -l ert -l test/scs-mx-history-test.el \
;;     -f ert-run-tests-batch-and-exit

;;; Code:

(require 'subr-x)

(defun scs/mx-history--name (command-name)
  "Return COMMAND-NAME as a nonempty string, or nil.

COMMAND-NAME is the string `read-extended-command' returned, or a
command symbol.  Nil, `nil' as a symbol, and empty string are ignored
so a quit at the M-x prompt does not invent a history entry."
  (cond
   ((and (stringp command-name) (not (string-empty-p command-name)))
    command-name)
   ;; `symbolp' is true for nil; reject that so we do not record "nil".
   ((and command-name (symbolp command-name))
    (symbol-name command-name))))

(defun scs/mx-history--executed-command ()
  "Return `this-command' when it is the command M-x actually ran.

`execute-extended-command' sets `this-command' to that command before
calling it.  Skip the M-x wrappers themselves so a quit at the prompt
does not record `execute-extended-command'."
  (and (symbolp this-command)
       (not (memq this-command
                  '(execute-extended-command
                    execute-extended-command-for-buffer
                    scs/mx-history-around-execute)))
       this-command))

(defun scs/mx-history-remember (command-name)
  "Put COMMAND-NAME at the front of `extended-command-history'.

If it is already the first element, do nothing.  Vertico's history
sort treats duplicate entries as extra frequency (`vertico-sort.el').
Successful M-x already prepends via `completing-read'; this function
exists so a command that then errors still has a first-place entry."
  (when-let* ((name (scs/mx-history--name command-name)))
    (unless (equal (car extended-command-history) name)
      (add-to-history 'extended-command-history name))))

(defun scs/mx-history-around-execute (orig prefixarg &optional command-name typed)
  "Run ORIG then pin the chosen M-x command on history.

ORIG is `execute-extended-command' or
`execute-extended-command-for-buffer'.  The pin runs in
`unwind-protect' so a command that signals still sits at the front of
`extended-command-history'.  Vertico sorts M-x by that list, and the
most recent entry is never outranked."
  (unwind-protect
      (funcall orig prefixarg command-name typed)
    (scs/mx-history-remember
     (or command-name (scs/mx-history--executed-command)))))

(defun scs/mx-history-setup ()
  "Advise M-x so a failing command still sits at the front of history.

Safe to call more than once: `advice-add' is a no-op when this around
advice is already present."
  (dolist (cmd '(execute-extended-command execute-extended-command-for-buffer))
    (advice-add cmd :around #'scs/mx-history-around-execute)))

(provide 'scs-mx-history)

;;; scs-mx-history.el ends here
