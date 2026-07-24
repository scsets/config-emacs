;;; flycheck-org-lint-workaround.el --- Flycheck org-lint integration fix  -*- lexical-binding: t; -*-

;; Author: SCS
;; Keywords: flycheck, org, lint

;;; Commentary:
;;
;; Problem:
;;   org-lint reports issues using tabulated-list cells: the "line" value is a
;;   propertized string with an org-lint-marker text property, not a plain line
;;   number.  Some Flycheck versions pass that string straight into
;;   flycheck-error-new-at, which expects a number and signals an error.
;;
;; Solution:
;;   At setup time, run a small in-buffer test.  If the bug is still present
;;   and flycheck-error-new-at-pos exists, advise flycheck-error-new-at to
;;   follow org-lint markers.  If the helper is missing, disable the org-lint
;;   checker instead of leaving Flycheck in a broken state.
;;
;; How to check:
;;   Open an Org buffer with a deliberate lint issue, confirm Flycheck lists it
;;   without errors in *Messages*.  After upgrading Flycheck, watch for the
;;   "integration is fixed upstream" message; then this file and its require
;;   in init.el can be removed.

(require 'scs-cl)

(defun scs/flycheck--org-lint-line-cell-p (line)
  "Return non-nil when LINE is an org-lint tabulated-list cell, not a number.

org-lint marks report lines with the org-lint-marker property so Flycheck
can jump to the right place; this predicate detects that shape."
  (and (stringp line)
       (get-text-property 0 'org-lint-marker line)))

(defun scs/flycheck--org-lint-integration-broken-p ()
  "Return non-nil when Flycheck cannot handle org-lint line cells.

Builds a tiny Org buffer, runs org-lint once, and tries the same
flycheck-error-new-at path Flycheck uses in real buffers.  A caught error
means the workaround is still needed."
  (cl-block test
    (unless (and (fboundp 'org-lint)
                 (require 'org nil t)
                 (fboundp 'flycheck-error-new-at)
                 (fboundp 'flycheck-error-line))
      (cl-return-from test nil))
    (with-current-buffer (get-buffer-create " *scs-flycheck-org-lint-test*")
      (erase-buffer)
      (org-mode)
      ;; Unclosed src block triggers a predictable org-lint entry.
      (insert "#+begin_src\nx\n#+end_src\n")
      (let* ((entry (car (org-lint)))
             (line (and entry (aref (cadr entry) 0))))
        (unless (scs/flycheck--org-lint-line-cell-p line)
          (cl-return-from test nil))
        (condition-case _
            (progn
              (flycheck-line-column-to-position
               (flycheck-error-line
                (flycheck-error-new-at line nil 'info "test"
                                       :checker 'org-lint))
               1)
              nil)
          (error t))))))

(defun scs/flycheck-error-new-at--org-lint-advice (orig line &rest args)
  "Around-advice for `flycheck-error-new-at': honor org-lint line cells.

When LINE carries org-lint-marker, delegate to flycheck-error-new-at-pos;
otherwise call ORIG unchanged so normal numeric lines still work."
  (if (scs/flycheck--org-lint-line-cell-p line)
      (let ((marker (get-text-property 0 'org-lint-marker line)))
        (if marker
            (apply #'flycheck-error-new-at-pos marker (nth 1 args) (nth 2 args)
                   (nthcdr 3 args))
          ;; Fallback if the property shape changed but the string type did not.
          (apply orig (string-to-number line) args)))
    (apply orig line args)))

(defun scs/flycheck-setup-org-lint-workaround ()
  "Install or remove org-lint advice depending on Flycheck and org-lint versions.

Safe to call repeatedly (for example after el-get updates flycheck): it
removes old advice first, then re-runs the integration test."
  (advice-remove 'flycheck-error-new-at #'scs/flycheck-error-new-at--org-lint-advice)
  (setq flycheck-disabled-checkers (delq 'org-lint flycheck-disabled-checkers))
  (cond
   ((not (featurep 'flycheck))
    nil)
   ((scs/flycheck--org-lint-integration-broken-p)
    (if (fboundp 'flycheck-error-new-at-pos)
        (advice-add 'flycheck-error-new-at :around
                    #'scs/flycheck-error-new-at--org-lint-advice)
      ;; Without -at-pos we cannot fix the bug; disabling beats a broken checker.
      (add-to-list 'flycheck-disabled-checkers 'org-lint)))
   ((and (fboundp 'org-lint) (require 'org nil t))
    (message "Flycheck org-lint integration is fixed upstream; lisp/flycheck-org-lint-workaround.el can be safely deleted along with its require in init.el (%s)"
             (or (locate-library "flycheck-org-lint-workaround")
                 "lisp/flycheck-org-lint-workaround.el")))
   (t nil)))

(defun scs/flycheck-org-lint-workaround-on-package-update (package)
  "Re-test org-lint integration after PACKAGE is updated via el-get.

Only flycheck matters here; other packages are ignored."
  (when (eq package 'flycheck)
    (when (featurep 'flycheck)
      ;; Reload so advice targets the newly installed flycheck.el.
      (load-file (locate-library "flycheck" t)))
    (scs/flycheck-setup-org-lint-workaround)))

(with-eval-after-load 'el-get
  (add-hook 'el-get-post-update-hooks
            #'scs/flycheck-org-lint-workaround-on-package-update))

(provide 'flycheck-org-lint-workaround)

;;; flycheck-org-lint-workaround.el ends here
