;;; flycheck-org-lint-workaround.el --- Flycheck org-lint integration fix  -*- lexical-binding: t; -*-

(defun scs/flycheck--org-lint-line-cell-p (line)
  "Return non-nil if LINE is an org-lint tabulated-list line cell."
  (and (stringp line)
       (get-text-property 0 'org-lint-marker line)))

(defun scs/flycheck--org-lint-integration-broken-p ()
  "Return non-nil if Flycheck mishandles org-lint report line cells."
  (and (fboundp 'org-lint)
       (require 'org nil t)
       (fboundp 'flycheck-error-new-at)
       (fboundp 'flycheck-error-line)
       (with-current-buffer (get-buffer-create " *scs-flycheck-org-lint-test*")
         (erase-buffer)
         (org-mode)
         (insert "#+begin_src\nx\n#+end_src\n")
         (let* ((entry (car (org-lint)))
                (line (and entry (aref (cadr entry) 0))))
           (when (scs/flycheck--org-lint-line-cell-p line)
             (condition-case _
                 (progn
                   (flycheck-line-column-to-position
                    (flycheck-error-line
                     (flycheck-error-new-at line nil 'info "test"
                                            :checker 'org-lint))
                    1)
                   nil)
               (error t)))))))

(defun scs/flycheck-error-new-at--org-lint-advice (orig line &rest args)
  "Use org-lint markers when Flycheck passes propertized line cells."
  (if (scs/flycheck--org-lint-line-cell-p line)
      (let ((marker (get-text-property 0 'org-lint-marker line)))
        (if marker
            (apply #'flycheck-error-new-at-pos marker (nth 1 args) (nth 2 args)
                   (nthcdr 3 args))
          (apply orig (string-to-number line) args)))
    (apply orig line args)))

(defun scs/flycheck-setup-org-lint-workaround ()
  "Enable or remove org-lint workaround advice as needed."
  (advice-remove 'flycheck-error-new-at #'scs/flycheck-error-new-at--org-lint-advice)
  (setq flycheck-disabled-checkers (delq 'org-lint flycheck-disabled-checkers))
  (cond
   ((not (featurep 'flycheck))
    nil)
   ((scs/flycheck--org-lint-integration-broken-p)
    (if (fboundp 'flycheck-error-new-at-pos)
        (advice-add 'flycheck-error-new-at :around
                    #'scs/flycheck-error-new-at--org-lint-advice)
      (add-to-list 'flycheck-disabled-checkers 'org-lint)))
   ((and (fboundp 'org-lint) (require 'org nil t))
    (message "Flycheck org-lint integration is fixed upstream; lisp/flycheck-org-lint-workaround.el can be safely deleted along with its require in init.el (%s)"
             (or (locate-library "flycheck-org-lint-workaround")
                 "lisp/flycheck-org-lint-workaround.el")))
   (t nil)))

(defun scs/flycheck-org-lint-workaround-on-package-update (package)
  "Re-test org-lint integration after PACKAGE is updated via el-get."
  (when (eq package 'flycheck)
    (when (featurep 'flycheck)
      (load-file (locate-library "flycheck" t)))
    (scs/flycheck-setup-org-lint-workaround)))

(with-eval-after-load 'el-get
  (add-hook 'el-get-post-update-hooks
            #'scs/flycheck-org-lint-workaround-on-package-update))

(provide 'flycheck-org-lint-workaround)

;;; flycheck-org-lint-workaround.el ends here
