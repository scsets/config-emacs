;;; scs-org-tools-test.el --- Tests for scs-org-tools  -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'org)
(require 'scs-org-tools)

(defun scs-org-tools-test--with-org (text point-marker fn)
  "Insert TEXT in a temp Org buffer, move to POINT-MARKER, call FN.
POINT-MARKER is a substring that must appear once; point is placed at
its beginning, then the marker text is left in the buffer."
  (with-temp-buffer
    (org-mode)
    (insert text)
    (goto-char (point-min))
    (search-forward point-marker)
    (goto-char (match-beginning 0))
    (funcall fn)))

(ert-deftest scs/org-append-zwsp-markers-sequences-from-point ()
  "Number Org paragraphs from point; leave earlier ones alone."
  (scs-org-tools-test--with-org
   (concat "Before.\n\n"
           "First tagged.\n\n"
           "* Heading\n"
           "Under heading.\n\n"
           "- list item\n\n"
           "Last tagged.\n")
   "First tagged."
   (lambda ()
     (scs/org-append-zwsp-markers 1)
     (let ((s (buffer-string)))
       (should (string-search "Before.\n\n" s))
       (should-not (string-match-p "Before\\.\\\\zwsp{}_" s))
       (should (string-match-p "First tagged\\.\\\\zwsp{}_1\n" s))
       (should (string-match-p "Under heading\\.\\\\zwsp{}_2\n" s))
       (should (string-match-p "- list item\n" s))
       (should-not (string-match-p "list item\\\\zwsp{}" s))
       (should (string-match-p "Last tagged\\.\\\\zwsp{}_3\n" s))))))

(ert-deftest scs/org-append-zwsp-markers-overwrites-existing ()
  "Replace an existing trailing marker instead of stacking."
  (scs-org-tools-test--with-org
   "Hello.\\zwsp{}_99\n\nWorld.\\zwsp{}_7\n"
   "Hello."
   (lambda ()
     (scs/org-append-zwsp-markers 5)
     (let ((s (buffer-string)))
       (should (string-match-p "Hello\\.\\\\zwsp{}_5\n" s))
       (should (string-match-p "World\\.\\\\zwsp{}_6\n" s))
       (should-not (string-match-p "\\\\zwsp{}_99" s))
       (should-not (string-match-p "\\\\zwsp{}_5\\\\zwsp{}" s))))))

(ert-deftest scs/org-append-zwsp-markers-tags-mid-paragraph ()
  "Include the paragraph containing point when point is mid-paragraph."
  (scs-org-tools-test--with-org
   (concat "Before.\n\n"
           "First tagged.\n\n"
           "After.\n")
   "tag"
   (lambda ()
     (scs/org-append-zwsp-markers 1)
     (let ((s (buffer-string)))
       (should-not (string-match-p "Before\\.\\\\zwsp{}" s))
       (should (string-match-p "First tagged\\.\\\\zwsp{}_1\n" s))
       (should (string-match-p "After\\.\\\\zwsp{}_2\n" s))))))

(ert-deftest scs/org-append-zwsp-markers-optional-start-and-guard ()
  "Default start is 1; non-Org buffers signal user-error."
  (scs-org-tools-test--with-org
   "Only one.\n"
   "Only one."
   (lambda ()
     (scs/org-append-zwsp-markers)
     (should (string-match-p "Only one\\.\\\\zwsp{}_1\n" (buffer-string)))))
  (with-temp-buffer
    (fundamental-mode)
    (insert "x\n")
    (should-error (scs/org-append-zwsp-markers 1) :type 'user-error)))

(defun scs-org-tools-test--header-lines (text)
  "Return non-blank lines of TEXT before the first blank line."
  (let ((lines (split-string text "\n"))
        (out nil)
        (done nil))
    (dolist (line lines)
      (cond
       (done nil)
       ((string-match-p "\\`[ \t]*\\'" line) (setq done t))
       (t (push line out))))
    (nreverse out)))

(ert-deftest scs/org-ensure-buffer-header-empty-buffer ()
  "Empty Org buffer gets a full header; TITLE from filename."
  (with-temp-buffer
    (org-mode)
    (setq buffer-file-name "/tmp/foo-bar.org")
    (scs/org-ensure-buffer-header)
    (let ((s (buffer-string)))
      (should (string-match-p "\\`#\\+TITLE: Foo bar\n" s))
      (should (string-match-p "^#\\+FILENAME: foo-bar.org\n" s))
      (should (string-match-p "^#\\+DESCRIPTION: \n" s))
      (should (string-match-p "^#\\+AUTHOR: SCS\n" s))
      (should (string-match-p
               "^#\\+COPYRIGHT: Copyright (C) [0-9]\\{4\\}, SCS, all rights reserved\\.\n"
               s))
      (should (string-match-p
               "^#\\+DATE: [0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\} [A-Z][a-z][a-z] [0-9]\\{2\\}:[0-9]\\{2\\}\n"
               s))
      (should (string-match-p "^#\\+VERSION: 0\\.1\\.0\n" s))
      (should (string-match-p "^#\\+LAST-UPDATED: " s))
      (should (string-match-p "^#\\+UPDATE: 0\n" s)))))

(ert-deftest scs/org-ensure-buffer-header-partial-reorder ()
  "Add missing keys, reorder, keep existing values."
  (with-temp-buffer
    (org-mode)
    (setq buffer-file-name "/tmp/note.org")
    (insert (concat "#+AUTHOR: KeepMe\n"
                    "#+title: Already Titled\n"
                    "#+VERSION: 9.9.9\n"
                    "\n"
                    "* Body\n"))
    (scs/org-ensure-buffer-header)
    (let* ((s (buffer-string))
           (headers (scs-org-tools-test--header-lines s)))
      (should (equal (car headers) "#+TITLE: Already Titled"))
      (should (equal (nth 1 headers) "#+FILENAME: note.org"))
      (should (equal (nth 3 headers) "#+AUTHOR: KeepMe"))
      (should (equal (nth 6 headers) "#+VERSION: 9.9.9"))
      (should (string-match-p "\\* Body\n" s)))))

(ert-deftest scs/org-ensure-buffer-header-idempotent ()
  "Complete correct header is left unchanged."
  (let ((stamp "2026-07-22 Wed 12:00"))
    (with-temp-buffer
      (org-mode)
      (setq buffer-file-name "/tmp/done.org")
      (insert (concat "#+TITLE: Done\n"
                      "#+FILENAME: done.org\n"
                      "#+DESCRIPTION: desc\n"
                      "#+AUTHOR: SCS\n"
                      "#+COPYRIGHT: Copyright (C) 2026, SCS, all rights reserved.\n"
                      "#+DATE: " stamp "\n"
                      "#+VERSION: 0.1.0\n"
                      "#+LAST-UPDATED: " stamp "\n"
                      "#+UPDATE: 0\n"
                      "\n"
                      "* Body\n"))
      (let ((before (buffer-string)))
        (scs/org-ensure-buffer-header)
        (should (equal (buffer-string) before))))))

(ert-deftest scs/org-ensure-buffer-header-unknown-after ()
  "Unknown keywords are preserved after the canonical block."
  (with-temp-buffer
    (org-mode)
    (setq buffer-file-name "/tmp/opts.org")
    (insert (concat "#+OPTIONS: toc:nil\n"
                    "#+TITLE: Opts\n"
                    "#+LATEX_HEADER: \\\\usepackage{foo}\n"
                    "\n"
                    "Body text.\n"))
    (scs/org-ensure-buffer-header)
    (let ((s (buffer-string)))
      (should (string-match-p "\\`#\\+TITLE: Opts\n" s))
      (should (string-search
               (concat "#+UPDATE: 0\n\n"
                       "#+OPTIONS: toc:nil\n"
                       "#+LATEX_HEADER: \\\\usepackage{foo}\n\n"
                       "Body text.\n")
               s)))))

(ert-deftest scs/org-ensure-buffer-header-empty-title-and-comment ()
  "Empty TITLE becomes sentence from filename; keep leading # comment."
  (with-temp-buffer
    (org-mode)
    (setq buffer-file-name "/tmp/foo-bar.org")
    (insert (concat "# $Id$\n"
                    "#+TITLE:\n"
                    "#+AUTHOR: SCS\n"
                    "\n"
                    "* Hi\n"))
    (scs/org-ensure-buffer-header)
    (let ((s (buffer-string)))
      (should (string-match-p "\\`# \\$Id\\$\n#\\+TITLE: Foo bar\n" s))
      (should (string-match-p "#\\+AUTHOR: SCS\n" s))
      (should (string-match-p "\\* Hi\n" s)))))

(ert-deftest scs/org-ensure-buffer-header-guard ()
  "Non-Org buffers signal user-error."
  (with-temp-buffer
    (fundamental-mode)
    (should-error (scs/org-ensure-buffer-header) :type 'user-error)))

(ert-deftest scs/org--basename-at-point-bare-quoted-link ()
  "Basename from bare name, quoted string, and Org file link."
  (scs-org-tools-test--with-org
   "See spiritual-life-is-not-democracy.org here.\n"
   "spiritual-life"
   (lambda ()
     (should (equal (scs/org--basename-at-point)
                    "spiritual-life-is-not-democracy.org"))))
  (scs-org-tools-test--with-org
   "See \"spiritual-life-is-not-democracy.org\" here.\n"
   "spiritual-life"
   (lambda ()
     (should (equal (scs/org--basename-at-point)
                    "spiritual-life-is-not-democracy.org"))))
  (scs-org-tools-test--with-org
   "See [[file:spiritual-life-is-not-democracy.org][note]] here.\n"
   "spiritual-life"
   (lambda ()
     (should (equal (scs/org--basename-at-point)
                    "spiritual-life-is-not-democracy.org"))))
  (with-temp-buffer
    (fundamental-mode)
    (insert "???\n")
    (goto-char (point-min))
    (should-not (scs/org--basename-at-point))))

(ert-deftest scs/rename-visited-file-to-name-at-point-tempdir ()
  "Rename visited file in a temp dir; overwrite asks then replaces."
  (let* ((dir (make-temp-file "scs-rename-" t))
         (old (expand-file-name "old-name.org" dir))
         (new (expand-file-name "new-name.org" dir))
         (other (expand-file-name "new-name.org" dir)))
    (unwind-protect
        (progn
          (with-temp-file old (insert "body\n"))
          (with-temp-buffer
            (insert "Rename to new-name.org please.\n")
            (setq buffer-file-name old)
            (goto-char (point-min))
            (search-forward "new-name.org")
            (goto-char (match-beginning 0))
            (cl-letf (((symbol-function 'yes-or-no-p) (lambda (&rest _) t)))
              (scs/rename-visited-file-to-name-at-point))
            (should (equal (file-name-nondirectory buffer-file-name)
                           "new-name.org"))
            (should (file-exists-p new))
            (should-not (file-exists-p old)))
          (with-temp-file old (insert "old again\n"))
          (with-temp-file other (insert "victim\n"))
          (with-temp-buffer
            (insert "Target new-name.org\n")
            (setq buffer-file-name old)
            (goto-char (point-min))
            (search-forward "new-name.org")
            (goto-char (match-beginning 0))
            (cl-letf (((symbol-function 'yes-or-no-p) (lambda (&rest _) t)))
              (scs/rename-visited-file-to-name-at-point))
            (should (file-exists-p new))
            (should-not (file-exists-p old))
            (with-temp-buffer
              (insert-file-contents new)
              (should (equal (buffer-string) "old again\n")))))
      (when (file-directory-p dir)
        (delete-directory dir t)))))

(provide 'scs-org-tools-test)

;;; scs-org-tools-test.el ends here
