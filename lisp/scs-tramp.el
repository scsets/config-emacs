;;; scs-tramp.el --- TRAMP hosts, safety, and no-trace policy  -*- lexical-binding: t; -*-

;; Author: SCS
;; Keywords: tramp, remote-files, convenience
;; Package-Requires: ((emacs "29.1"))

;;; Commentary:
;;
;; Known SSH hosts (from ~/.ssh/config) and TRAMP policy:
;;
;; - Backups of remote files stay on this machine under var/tramp-backup/.
;; - Auto-save, lock files, and shell history are kept off remote hosts
;;   (see init.el use-package tramp and no-littering-theme-backups).
;; - Connection-local profiles tune dired for FreeBSD hosts.
;;
;; Hosts: fido, dasfrp, ganafrp, ckg1 (SSH name; spoken "ck1"), ckg2.
;;
;; C-c t f  find file on a known host
;; C-c t d  dired on a known host
;; C-c t c  clean up TRAMP connections
;; C-c t r  revert buffer from remote

;;; Code:

(require 'tramp)

(defconst scs/tramp-hosts
  '("fido" "dasfrp" "ganafrp" "ckg1" "ckg2")
  "SSH config Host names reachable via TRAMP.")

(defconst scs/tramp-freebsd-hosts
  '("dasfrp" "ganafrp")
  "Hosts running FreeBSD; prefer GNU ls in dired when available.")

(defvar scs/tramp-prefix-map nil
  "Keymap for TRAMP commands under \\[scs/tramp-prefix-map].")

(defun scs/tramp--backup-directory ()
  "Return the local directory for remote-file backup copies."
  (no-littering-expand-var-file-name "tramp-backup/"))

(defun scs/tramp--default-directory (host)
  "Return a TRAMP default directory for SSH HOST."
  (file-name-as-directory (format "/ssh:%s:/" host)))

(defun scs/tramp--read-host (prompt)
  "Read one of `scs/tramp-hosts' from the minibuffer with PROMPT."
  (completing-read prompt scs/tramp-hosts nil t))

(defun scs/tramp--apply-connection-profiles ()
  "Install connection-local profiles for known TRAMP hosts."
  (connection-local-set-profile-variables
   'remote-direct-async-process
   '((tramp-direct-async-process . t)))

  (connection-local-set-profiles
   '(:application tramp :protocol "ssh")
   'remote-direct-async-process)

  (connection-local-set-profiles
   '(:application tramp :protocol "scp")
   'remote-direct-async-process)

  (connection-local-set-profile-variables
   'remote-bsd-process
   '((insert-directory-program . "gls")))

  (dolist (host scs/tramp-freebsd-hosts)
    (connection-local-set-profiles
     `(:application tramp :machine ,host)
     'remote-bsd-process)))

(defun scs/tramp--configure-no-trace ()
  "Keep TRAMP side effects on remote hosts and in $HOME to a minimum."
  (let ((backup-dir (scs/tramp--backup-directory)))
    (make-directory backup-dir #o700)
    (setq tramp-backup-directory-alist `((".*" . ,backup-dir))))

  (let ((autosave-dir (expand-file-name "tramp-autosave"
                                        temporary-file-directory)))
    (make-directory autosave-dir #o700)
    (setq tramp-auto-save-directory autosave-dir))

  (add-hook 'kill-emacs-hook #'tramp-cleanup-all-connections))

;;;###autoload
(defun scs/tramp-setup ()
  "Apply host list, local backup policy, and TRAMP key bindings."
  (scs/tramp--configure-no-trace)
  (scs/tramp--apply-connection-profiles)

  (unless scs/tramp-prefix-map
    (setq scs/tramp-prefix-map (make-sparse-keymap))
    (define-key scs/tramp-prefix-map (kbd "f") #'scs/tramp-find-file)
    (define-key scs/tramp-prefix-map (kbd "d") #'scs/tramp-dired)
    (define-key scs/tramp-prefix-map (kbd "c") #'my/tramp-cleanup)
    (define-key scs/tramp-prefix-map (kbd "r") #'my/tramp-reopen))
  (define-key global-map (kbd "C-c t") scs/tramp-prefix-map))

;;;###autoload
(defun scs/tramp-find-file (path)
  "Open PATH on a known SSH host via TRAMP.
When called interactively, read the host from `scs/tramp-hosts' and
PATH from the minibuffer."
  (interactive
   (let* ((host (scs/tramp--read-host "TRAMP host: "))
          (default (scs/tramp--default-directory host)))
     (list (read-file-name (format "File on %s: " host) default))))
  (find-file path))

;;;###autoload
(defun scs/tramp-dired (directory)
  "Open dired on DIRECTORY at a known SSH host via TRAMP.
When called interactively, read the host from `scs/tramp-hosts' and
DIRECTORY from the minibuffer."
  (interactive
   (let* ((host (scs/tramp--read-host "TRAMP host: "))
          (default (scs/tramp--default-directory host)))
     (list (read-directory-name (format "Directory on %s: " host)
                                 default))))
  (dired directory))

;;;###autoload
(defun my/tramp-cleanup ()
  "Clean up all TRAMP connections and buffers."
  (interactive)
  (tramp-cleanup-all-connections)
  (tramp-cleanup-all-buffers)
  (message "TRAMP: all connections and buffers cleaned up"))

;;;###autoload
(defun my/tramp-reopen ()
  "Revert current remote buffer, refreshing from remote host."
  (interactive)
  (when (file-remote-p default-directory)
    (revert-buffer t t)
    (message "Refreshed from remote")))

(provide 'scs-tramp)
;;; scs-tramp.el ends here
