;;; org-tools.el --- Org export helpers: line-prefix blocks  -*- lexical-binding: t; -*-

;; Filename: org-tools.el
;; Description: Line-prefix blocks, stationery fade, PDF/X export hooks
;; Author: SCS
;; Copyright: Copyright (C) 2026, SCS, all rights reserved.
;; Created: 2026-07-15 Tue 10:00
;; Version: 0.1.0
;; Last-Updated: 2026-07-24 Fri 06:49
;; Update #: 1
;; Keywords: org, export, convenience
;; Package-Requires: ((emacs "29.1") (org "9.0"))

;;; Commentary:
;;
;; Problem
;; -------
;; Org export is powerful but verbose for small layout habits: centered
;; lines, quote blocks, faded letterhead PDFs, and print-shop PDF/X-1a.
;; Authors should write short prefixes at column 0 and let export expand
;; them safely (skipping src/example blocks).
;;
;; Solution
;; --------
;; org-tools.el registers hooks on `org-export-before-parsing-functions'
;; and related filters.  Line-prefix syntax runs first; optional stationery
;; and PDF/X steps run when #+SCS_* keywords request them.
;;
;; Enable once in your init file:
;;
;;   (with-eval-after-load 'org
;;     (require 'org-tools))
;;
;; How to verify
;; -------------
;; Export a small .org test file with `! ` and `> ` lines; toggle
;; `M-x org-tools-line-prefixes-mode RET' and re-export to see the hook
;; register or unregister.
;;
;; ---------------------------------------------------------------------------
;; Syntax
;; ---------------------------------------------------------------------------
;;
;; Centered lines
;; ~~~~~~~~~~~~~~~~
;;
;; Consecutive lines starting with "! " become a center block.  Optional
;; style tokens may follow "!" on the same line and apply to that line
;; only.
;;
;;   !sc large Packing checklist
;;   ! (summer -- warm season)
;;
;; becomes on LaTeX export:
;;
;;   #+begin_center
;;   @@latex:{\large\textsc{Packing checklist}}@@
;;
;;   (summer -- warm season)
;;   #+end_center
;;
;; Quote lines
;; ~~~~~~~~~~~
;;
;; Consecutive lines starting with "> " become a quote block:
;;
;;   > Nothing is compulsory, of course.
;;   > Some items are optional.
;;
;; becomes:
;;
;;   #+begin_quote
;;   Nothing is compulsory, of course.
;;   Some items are optional.
;;   #+end_quote
;;
;; ---------------------------------------------------------------------------
;; Style modifiers (center lines only)
;; ---------------------------------------------------------------------------
;;
;; Recognised tokens (case-sensitive, space-separated):
;;
;;   sc, smallcaps     -> \textsc{...} on LaTeX export
;;   tiny ... huge     -> \tiny ... \huge
;;   Huge              -> \Huge
;;   10pt, 12.5pt      -> \fontsize{...}{...}\selectfont
;;
;; Small caps and the body font
;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;;
;; Configure fonts in /Users/scs/fonts/scs-canon/scs-fontspec.tex and include
;; it from your Org file:
;;
;;   #+LATEX_HEADER: \input{/Users/scs/fonts/scs-canon/scs-fontspec.tex}
;;
;; That file defines the body face, header face, and a \textsc{} that applies
;; Adobe Garamond OpenType small caps (smcp).  Plain !sc centre lines then
;; need no extra modifiers.
;;
;; Examples:
;;
;;   !sc large Main title
;;   !sc typeset at tapoban -- 4 july 63 SC
;;   !14pt Subtitle
;;   ! Plain centred line
;;
;; ---------------------------------------------------------------------------
;; Rules
;; ---------------------------------------------------------------------------
;;
;; * Prefixes start at column 0.
;; * A blank line ends the current run.
;; * "! " and "> " runs do not mix.
;; * Lines inside #+begin_src / #+begin_export / #+begin_example /
;;   #+begin_verse blocks are left untouched.
;;
;; Toggle without reloading:
;;
;;   M-x org-tools-line-prefixes-mode RET
;;
;; ---------------------------------------------------------------------------
;; Faded letterhead (stationery)
;; ---------------------------------------------------------------------------
;;
;; Declare the fade strength in the Org file and use a placeholder in the
;; eso-pic background line:
;;
;;   #+SCS_STATIONERY: ~/Documents/scs-stationary.pdf
;;   #+SCS_STATIONERY_FADE: 27
;;
;;   #+LATEX_HEADER: \AddToShipoutPictureBG{...{SCS_STATIONERY_FADED_PDF}}}
;;
;; On LaTeX export, org-tools rasterises the source PDF (Ghostscript),
;; colorises it to the requested strength (ImageMagick), caches the result as
;; e.g. scs-stationary-faded-27pct.pdf, and substitutes SCS_STATIONERY_FADED_PDF
;; in the final .tex output.  FADE is the percentage of original colour kept
;; (lower values look fainter).  Requires gs and magick on PATH.
;;
;;   M-x org-tools-regenerate-stationery RET   ; rebuild from current buffer
;;
;; If #+SCS_STATIONERY_FADE: is absent, the stationery hook does nothing.
;;
;; ---------------------------------------------------------------------------
;; PDF/X-1a post-processing
;; ---------------------------------------------------------------------------
;;
;; After =C-c C-e l p= (PDF export), convert the finished PDF to PDF/X-1a
;; with embedded fonts:
;;
;;   #+SCS_PDFX: yes
;;
;; Requires pdf2pdfx1a.sh (Ghostscript + Adobe SWOP ICC profile).  The
;; exported PDF is replaced in place.  Set =org-tools-pdfx-script= if the
;; script lives somewhere other than the default path.

;;; Change Log:
;; Newest first.  File-local so readers need not dig through VCS.
;; fix: 2026-07-24 -- teachable Commentary for SCS team
;; fix: 2026-07-09 -- when-let* / cl-reduce / cl-sort cleanups
;; add: 2026-07-08 -- stationery and LaTeX export helpers

;;; Code:

(require 'org)
(require 'scs-cl)
(require 'subr-x)

;;;###autoload
(defgroup org-tools nil
  "Org export helpers from org-tools.el."
  :group 'org
  :prefix "org-tools-")

(defcustom org-tools-line-prefixes-enabled t
  "Whether line-prefix expansion runs before Org export parsing."
  :group 'org-tools
  :type 'boolean)

(defvar org-tools--latex-size-commands
  '("tiny" "scriptsize" "footnotesize" "small" "normalsize"
    "large" "Large" "huge" "Huge")
  "LaTeX size command names accepted as center-line modifiers.")

(defvar org-tools--smallcaps-modifiers '("sc" "smallcaps")
  "Modifier tokens that enable small caps on a centre line.")

(defvar org-tools--header-font-modifiers '("runfont" "headerfont" "ag")
  "Modifier tokens that prefix the line with `org-tools-latex-header-font-command'.")

(defcustom org-tools-latex-header-font-command "\\runheaderfont"
  "LaTeX font command for the runfont/headerfont/ag centre-line modifiers.
Your Org file must define this command, e.g. in #+LATEX_HEADER."
  :group 'org-tools
  :type 'string)

;;;###autoload
(define-minor-mode org-tools-line-prefixes-mode
  "Toggle Org line-prefix expansion before export."
  :lighter " OrgLP"
  :group 'org-tools
  (if org-tools-line-prefixes-mode
      (org-tools-enable-line-prefixes)
    (org-tools-disable-line-prefixes)))

(defun org-tools-enable-line-prefixes ()
  "Register line-prefix expansion on `org-export-before-parsing-functions'."
  (add-hook 'org-export-before-parsing-functions
            #'org-tools-expand-line-prefixes)
  (setq org-tools-line-prefixes-enabled t))

(defun org-tools-disable-line-prefixes ()
  "Unregister line-prefix expansion from `org-export-before-parsing-functions'."
  (remove-hook 'org-export-before-parsing-functions
               #'org-tools-expand-line-prefixes)
  (setq org-tools-line-prefixes-enabled nil))

(defun org-tools--blank-line-p (line)
  "Return non-nil if LINE contains only whitespace."
  (string= "" (string-trim line)))

(defun org-tools--protected-regions ()
  "Return (START . END) positions of Org blocks to skip during expansion.
Src, export, example, and verse blocks are left untouched so prefixed
lines inside code or poetry are not rewritten."
  (let (regions)
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward
              "^#\\+\\(?:begin\\|BEGIN\\)_\\(src\\|export\\|example\\|verse\\)"
              nil t)
        (let* ((kind (downcase (match-string 1)))
               (start (match-beginning 0))
               (end-re (format "^#\\+\\(?:end\\|END\\)_%s" (regexp-quote kind))))
          (when (re-search-forward end-re nil t)
            (push (cons start (line-end-position)) regions)))))
    (cl-sort regions #'< :key #'car)))

(defun org-tools--in-protected-region-p (pos regions)
  "Return non-nil if POS lies inside any region in REGIONS."
  (cl-some (lambda (region)
             (and (>= pos (car region))
                  (<= pos (cdr region))))
           regions))

(defun org-tools--parse-center-content (content)
  "Parse CONTENT after the \"!\" prefix.
Return (MODIFIERS TEXT)."
  (let ((mods nil)
        (rest (string-trim content)))
    (while (string-match
             "\\`\\(sc\\|smallcaps\\|runfont\\|headerfont\\|ag\\|tiny\\|scriptsize\\|footnotesize\\|small\\|normalsize\\|large\\|Large\\|huge\\|Huge\\|[0-9.]+pt\\)\\s-+\\(.*\\)\\'"
             rest)
      (push (match-string 1 rest) mods)
      (setq rest (match-string 2 rest)))
    (list (nreverse mods) (string-trim rest))))

(defun org-tools--latex-baseline-skip (pt-token)
  "Return a baselineskip string for PT-TOKEN like \"12pt\"."
  (format "%spt" (/ (round (* (string-to-number (substring pt-token 0 -2)) 12.0)) 10.0)))

(defun org-tools--smallcaps-p (modifiers)
  "Return non-nil if any MODIFIERS token requests small caps."
  (cl-some (lambda (mod) (member mod org-tools--smallcaps-modifiers))
           modifiers))

(defun org-tools--header-font-p (modifiers)
  "Return non-nil if any MODIFIERS token requests the header font."
  (cl-some (lambda (mod) (member mod org-tools--header-font-modifiers))
           modifiers))

(defun org-tools--apply-latex-styles (text modifiers)
  "Wrap TEXT with LaTeX size/sc commands from MODIFIERS."
  (let ((wrapped
         (cl-reduce
          (lambda (acc mod)
            (cond
             ((member mod org-tools--latex-size-commands)
              (format "{\\%s %s}" mod acc))
             ((string-match-p "\\`[0-9.]+pt\\'" mod)
              (format "{\\fontsize{%s}{%s}\\selectfont %s}"
                      mod (org-tools--latex-baseline-skip mod) acc))
             (t acc)))
          (cl-remove-if (lambda (m)
                          (or (member m org-tools--smallcaps-modifiers)
                              (member m org-tools--header-font-modifiers)))
                        modifiers)
          :initial-value (if (org-tools--smallcaps-p modifiers)
                             (format "\\textsc{%s}" text)
                           text))))
    (if (org-tools--header-font-p modifiers)
        (format "%s%s" org-tools-latex-header-font-command wrapped)
      wrapped)))

(defun org-tools--center-line->org (raw-line backend)
  "Turn a single !-prefixed RAW-LINE into Org markup for BACKEND."
  (pcase-let ((`(,modifiers ,text) (org-tools--parse-center-content raw-line)))
    (cond
     ((string= text "")
      "")
     ((and modifiers (org-export-derived-backend-p backend 'latex))
      (format "@@latex:%s@@" (org-tools--apply-latex-styles text modifiers)))
     (t text))))

(defun org-tools--expand-center-group (lines backend)
  "Expand LINES into a center block."
  (format "#+begin_center\n%s\n#+end_center"
          (mapconcat (lambda (line)
                       (org-tools--center-line->org line backend))
                     lines "\n\n")))

(defun org-tools--expand-quote-group (lines)
  "Expand LINES into a quote block."
  (format "#+begin_quote\n%s\n#+end_quote"
          (mapconcat #'string-trim lines "\n\n")))

(defun org-tools--line-prefix-type (line)
  "Return \\='center, \\='quote, or nil for LINE."
  (cond
   ((string-match "\\`!" line) 'center)
   ((string-match "\\`>\\s-+" line) 'quote)
   (t nil)))

(defun org-tools--strip-prefix (line type)
  "Remove prefix from LINE for TYPE."
  (pcase type
    ('center (if (string-match "\\`!\\s-*\\(.*\\)" line)
                 (match-string 1 line)
               line))
    ('quote (if (string-match "\\`>\\s-*\\(.*\\)" line)
                (match-string 1 line)
              line))
    (_ line)))

(defun org-tools--collect-line-prefix-groups ()
  "Collect contiguous line-prefix groups in the current buffer."
  (let ((protected (org-tools--protected-regions))
        (groups nil)
        (current-type nil)
        (current-start nil)
        (current-lines nil))
    (save-excursion
      (goto-char (point-min))
      (while (not (eobp))
        (let* ((line-start (line-beginning-position))
               (line (buffer-substring-no-properties
                      line-start (line-end-position)))
               (line-type (unless (or (org-tools--blank-line-p line)
                                      (org-tools--in-protected-region-p
                                       line-start protected))
                            (org-tools--line-prefix-type line))))
          (cond
           ((null line-type)
            (when current-type
              (push (list current-type current-start line-start
                          (nreverse current-lines))
                    groups)
              (setq current-type nil
                    current-start nil
                    current-lines nil)))
           ((and current-type (not (eq current-type line-type)))
            (push (list current-type current-start line-start
                        (nreverse current-lines))
                  groups)
            (setq current-type line-type
                  current-start line-start
                  current-lines (list (org-tools--strip-prefix line line-type))))
           (t
            (unless current-start
              (setq current-start line-start))
            (setq current-type line-type)
            (push (org-tools--strip-prefix line line-type) current-lines)))
          (forward-line 1)))
      (when current-type
        (push (list current-type current-start (point-max)
                    (nreverse current-lines))
              groups)))
    (nreverse groups)))

(defun org-tools--expand-group (group backend)
  "Expand GROUP tuple into Org markup."
  (pcase group
    (`(center ,_ ,_ ,lines) (org-tools--expand-center-group lines backend))
    (`(quote ,_ ,_ ,lines) (org-tools--expand-quote-group lines))
    (_ "")))

;;;###autoload
(defun org-tools-expand-line-prefixes (backend)
  "Expand ! and > line prefixes before Org export parsing.
Groups are applied from the bottom of the buffer upward so earlier
line numbers stay valid while regions are deleted and replaced."
  (dolist (group (reverse (org-tools--collect-line-prefix-groups)))
    (pcase group
      (`(,type ,start ,end ,lines)
       (delete-region start end)
       (goto-char start)
       (insert (org-tools--expand-group group backend) "\n"))))
  nil)

;;;###autoload
(defun org-tools-line-prefixes-status ()
  "Show whether line-prefix expansion is active."
  (interactive)
  (message "Org line-prefix expansion is %s"
           (if (and org-tools-line-prefixes-enabled
                    (member #'org-tools-expand-line-prefixes
                            org-export-before-parsing-functions))
               "enabled"
             "disabled")))

;;; Stationery fade

(defcustom org-tools-stationery-enabled t
  "Whether faded-stationery preparation runs before Org export parsing."
  :group 'org-tools
  :type 'boolean)

(defcustom org-tools-stationery-default-source "~/Documents/scs-stationary.pdf"
  "Default source PDF when #+SCS_STATIONERY: is not set."
  :group 'org-tools
  :type 'file)

(defconst org-tools-stationery-placeholder "SCS_STATIONERY_FADED_PDF"
  "Placeholder substituted with the faded stationery PDF path on export.")

(defvar org-tools--stationery-faded-path nil
  "Faded stationery path used during the current export.
Set by `org-tools-prepare-stationery' and read by the final-output filter.")

(defun org-tools--stationery-keyword (name)
  "Read #+NAME: value from the current buffer, or nil."
  (save-excursion
    (goto-char (point-min))
    (let ((limit (min (point-max) (+ (point-min) 32768))))
      (when (re-search-forward
             (format "^#\\+%s:\\s-+\\(.*\\)"
                     (regexp-quote (upcase name)))
             limit t)
        (string-trim (match-string 1))))))

(defun org-tools--stationery-fade-percent ()
  "Return colour strength 1-100 from #+SCS_STATIONERY_FADE:, or nil.
Values outside 1..100 are ignored so a typo does not build nonsense PDFs."
  (when-let* ((raw (org-tools--stationery-keyword "SCS_STATIONERY_FADE"))
              (n (string-to-number (string-trim raw)))
              (_ (and (numberp n) (> n 0) (<= n 100))))
    n))

(defun org-tools--stationery-source-path ()
  "Return expanded source stationery PDF path."
  (expand-file-name
   (or (org-tools--stationery-keyword "SCS_STATIONERY")
       org-tools-stationery-default-source)))

(defun org-tools--stationery-faded-path-for (source percent)
  "Return cached faded PDF path for SOURCE kept at PERCENT % strength."
  (let* ((dir (file-name-directory source))
         (base (file-name-sans-extension (file-name-nondirectory source))))
    (expand-file-name (format "%s-faded-%dpct.pdf" base percent) dir)))

(defun org-tools--stationery-latex-path (path)
  "Return PATH formatted for LaTeX \\includegraphics."
  (replace-regexp-in-string "\\\\" "/" (expand-file-name path)))

(defun org-tools--stationery-needs-regenerate-p (source faded)
  "Return non-nil if FADED should be rebuilt from SOURCE."
  (or (not (file-readable-p faded))
      (file-newer-than-file-p source faded)))

(defun org-tools--run-process (program args &optional output-buffer)
  "Run PROGRAM with ARGS, optionally capturing to OUTPUT-BUFFER.
Signal `error' on missing binary or non-zero exit."
  (unless (executable-find program)
    (error "Program %s not found on PATH" program))
  (let ((exit (apply #'call-process program nil
                     (and output-buffer (list output-buffer)) nil args)))
    (unless (and (numberp exit) (zerop exit))
      (error "%s failed (%s)" program exit))))

(defun org-tools--stationery-run (program args)
  "Run PROGRAM with ARGS, capturing stdout into the current buffer."
  (org-tools--run-process program args t))

(defun org-tools--run-silent (program args)
  "Run PROGRAM with ARGS, discarding stdout."
  (org-tools--run-process program args nil))

(defun org-tools--regenerate-stationery-faded (source faded percent)
  "Build FADED from SOURCE at PERCENT % colour strength."
  (let* ((tmpdir (make-temp-file "org-tools-stationery" t))
         (png-pattern (expand-file-name "page-%03d.png" tmpdir))
         (png-page (expand-file-name "page-001.png" tmpdir))
         (png-out (expand-file-name "faded.png" tmpdir))
         ;; ImageMagick colorize: 100-percent means white; we keep PERCENT colour.
         (colorize (format "%d%%" (- 100 percent))))
    (unwind-protect
        (progn
          (org-tools--stationery-run
           "gs"
           `("-q" "-dNOPAUSE" "-dBATCH" "-dNOSAFER"
             "-sDEVICE=png16m" "-r300"
             ,(concat "-sOutputFile=" png-pattern)
             ,source))
          (org-tools--stationery-run
           "magick"
           `(,png-page "-background" "white" "-alpha" "remove"
             "-fill" "white" "-colorize" ,colorize
             ,png-out))
          (org-tools--stationery-run
           "magick"
           `(,png-out "-units" "PixelsPerInch" "-density" "300"
             "-compress" "zip" ,faded)))
      (delete-directory tmpdir t))
    faded))

(defun org-tools-ensure-stationery-faded ()
  "Ensure faded stationery for the current buffer exists; return its path."
  (when-let* ((percent (org-tools--stationery-fade-percent))
              (source (org-tools--stationery-source-path))
              (faded (org-tools--stationery-faded-path-for source percent)))
    (unless (file-readable-p source)
      (user-error "Stationery source not found: %s" source))
    (when (org-tools--stationery-needs-regenerate-p source faded)
      (message "org-tools: regenerating faded stationery (%d%%) -> %s"
               percent faded)
      (org-tools--regenerate-stationery-faded source faded percent))
    faded))

(defun org-tools--substitute-stationery-in-string (contents path)
  "Return CONTENTS with stationery placeholder replaced by PATH."
  (let ((latex-path (org-tools--stationery-latex-path path))
        (ph (regexp-quote org-tools-stationery-placeholder))
        (result contents))
    (while (string-match ph result)
      (setq result (replace-match latex-path t t result)))
    result))

;;;###autoload
(defun org-tools-prepare-stationery (_backend)
  "Build faded stationery PDF for the current export buffer."
  (when-let* ((faded (org-tools-ensure-stationery-faded)))
    (setq org-tools--stationery-faded-path faded))
  nil)

;;;###autoload
(defun org-tools-filter-stationery-output (contents _backend _info)
  "Replace SCS_STATIONERY_FADED_PDF in the final export string."
  (if org-tools--stationery-faded-path
      (org-tools--substitute-stationery-in-string
       contents org-tools--stationery-faded-path)
    contents))

;;;###autoload
(defun org-tools-regenerate-stationery ()
  "Rebuild the faded stationery PDF for the current Org file."
  (interactive)
  (unless (derived-mode-p 'org-mode)
    (user-error "Not in Org mode"))
  (if-let* ((faded (org-tools-ensure-stationery-faded)))
      (message "Faded stationery ready: %s" faded)
    (user-error "Set #+SCS_STATIONERY_FADE: in this file")))

(defun org-tools-enable-stationery ()
  "Register stationery preparation on `org-export-before-parsing-functions'."
  (add-hook 'org-export-before-parsing-functions
            #'org-tools-prepare-stationery)
  (add-hook 'org-export-filter-final-output-functions
            #'org-tools-filter-stationery-output))

(defun org-tools-disable-stationery ()
  "Unregister stationery preparation from `org-export-before-parsing-functions'."
  (remove-hook 'org-export-before-parsing-functions
               #'org-tools-prepare-stationery)
  (remove-hook 'org-export-filter-final-output-functions
               #'org-tools-filter-stationery-output))

;;; PDF/X-1a post-processing

(defcustom org-tools-pdfx-enabled t
  "Whether PDF/X-1a post-processing runs after Org PDF export."
  :group 'org-tools
  :type 'boolean)

(defcustom org-tools-pdfx-script
  "/Users/scs/scs/lab/code/pdf2pdfx/pdf2pdfx.sh"
  "Path to pdf2pdfx1a.sh for #+SCS_PDFX: exports."
  :group 'org-tools
  :type 'file)

(defvar org-tools--pdfx-disabled-values '("no" "false" "0" "off")
  "Values for #+SCS_PDFX: that disable post-processing.
Any other non-empty value enables PDF/X-1a when `org-tools-pdfx-enabled' is t.")

(defun org-tools--pdfx-requested-p ()
  "Return non-nil when #+SCS_PDFX: requests PDF/X-1a post-processing."
  (when-let* ((raw (org-tools--stationery-keyword "SCS_PDFX")))
    (not (member (downcase (string-trim raw))
                 org-tools--pdfx-disabled-values))))

(defun org-tools--run-pdfx (pdf)
  "Convert PDF to PDF/X-1a in place; return PDF."
  (let ((script (expand-file-name org-tools-pdfx-script)))
    (unless (file-readable-p script)
      (error "pdf2pdfx1a script not found: %s" script))
    (message "org-tools: converting to PDF/X-1a -> %s" pdf)
    (org-tools--run-silent script (list "--in-place" pdf))
    pdf))

(defun org-tools--around-latex-export-to-pdf (orig &rest args)
  "Run PDF/X-1a conversion after Org LaTeX PDF export when requested.
Advice wraps `org-latex-export-to-pdf' so normal export still returns the
PDF path; conversion runs only when #+SCS_PDFX: is set and enabled."
  (let ((pdf (apply orig args)))
    (when (and org-tools-pdfx-enabled
               (org-tools--pdfx-requested-p)
               pdf (stringp pdf) (file-readable-p pdf))
      (org-tools--run-pdfx pdf))
    pdf))

(defun org-tools-enable-pdfx ()
  "Register PDF/X-1a post-processing on `org-latex-export-to-pdf'."
  (advice-add 'org-latex-export-to-pdf :around
              #'org-tools--around-latex-export-to-pdf))

(defun org-tools-disable-pdfx ()
  "Unregister PDF/X-1a post-processing from `org-latex-export-to-pdf'."
  (advice-remove 'org-latex-export-to-pdf
                 #'org-tools--around-latex-export-to-pdf))

(when org-tools-line-prefixes-enabled
  (org-tools-enable-line-prefixes))

(when org-tools-stationery-enabled
  (org-tools-enable-stationery))

(when org-tools-pdfx-enabled
  (org-tools-enable-pdfx))

(provide 'org-tools)

;;; org-tools.el ends here
