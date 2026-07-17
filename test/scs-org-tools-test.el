;;; scs-org-tools-test.el --- Tests for scs-org-tools  -*- lexical-binding: t; -*-

(require 'ert)
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

(provide 'scs-org-tools-test)

;;; scs-org-tools-test.el ends here
