;;; org-tools.el --- Org export and buffer helpers  -*- lexical-binding: t; -*-

;; Filename: org-tools.el
;; Description: Org helpers: headers, zwsp, rename; line-prefix/stationery/PDFX export
;; Author: SCS
;; Copyright: Copyright (C) 2026, SCS, all rights reserved.
;; Created: 2026-07-15 Tue 10:00
;; Version: 0.2.2
;; Last-Updated: 2026-07-24 Fri 09:47
;; Update #: 4
;; Keywords: org, export, convenience
;; Package-Requires: ((emacs "29.1") (org "9.0"))

;;; Commentary:
;;
;; Problem
;; -------
;; Org work in this config needs one reusable home: buffer hygiene (headers,
;; creation-date, zwsp markers, rename-at-point) and the export helpers
;; below.  Juniors should read one module rather than hunt init.el and old
;; snippets.
;;
;; Solution
;; --------
;; Buffer helpers (`scs/org-*' commands) keep SCS preamble and property
;; conventions consistent.  Org export helpers live in their own section
;; below so the export story stays easy to find.
;;
;; Enable once in your init file:
;;
;;   (with-eval-after-load 'org
;;     (require 'org-tools))
;;
;; How to verify (buffer helpers)
;; ------------------------------
;;   emacs -batch -L lisp -l ert -l lisp/org-tools.el \
;;     -l test/org-tools-test.el -f ert-run-tests-batch-and-exit
;;
;; ---------------------------------------------------------------------------
;; Org export helpers
;; ---------------------------------------------------------------------------
;;
;; Org export can do a lot, but small layout habits get verbose: centered
;; lines, quote blocks, faded letterhead PDFs, and print-shop PDF/X-1a.
;; Prefer short prefixes at column 0 and let export expand them safely
;; (src / example / export / verse blocks are left alone).
;;
;; These helpers register on `org-export-before-parsing-functions' and
;; related filters.  Line-prefix syntax runs first; optional stationery
;; and PDF/X steps run only when #+SCS_* keywords ask for them.
;;
;; How to verify (export)
;; ----------------------
;; Export a small .org test file with `! ` and `> ` lines; toggle
;; `M-x org-tools-line-prefixes-mode RET' and re-export to see the hook
;; register or unregister.
;;
;; Autoload cookies
;; ----------------
;; Only interactive entry points carry ;;;###autoload (M-x / Hyper).
;; Hook callbacks and internal helpers do not.  init.el also declares
;; matching (autoload ...) forms so those commands load org-tools on
;; first use, before the Org `require'.
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
;; fix: 2026-07-24 -- autoload cookies only on interactive entry points
;; fix: 2026-07-24 -- restore export clarifying text as its own Commentary section
;; fix: 2026-07-24 -- merge scs-org-tools buffer helpers into this file
;; fix: 2026-07-24 -- teachable Commentary for SCS team
;; fix: 2026-07-09 -- when-let* / cl-reduce / cl-sort cleanups
;; add: 2026-07-08 -- stationery and LaTeX export helpers

;;; Code:

(require 'org)
(require 'scs-cl)
(require 'subr-x)
(require 'thingatpt)

;;;###autoload
(defgroup org-tools nil
  "Org buffer and export helpers from org-tools.el."
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

(defun org-tools-prepare-stationery (_backend)
  "Build faded stationery PDF for the current export buffer."
  (when-let* ((faded (org-tools-ensure-stationery-faded)))
    (setq org-tools--stationery-faded-path faded))
  nil)

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


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Buffer helpers (header, creation-date, zwsp, rename)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Former scs-org-tools.el.  Symbol names keep the scs/ prefix so Hyper
;; bindings and ERT stay stable.

(defcustom scs/org-buffer-header-template-file
  (expand-file-name "scs_org-buffer-template.org"
                    (file-name-directory
                     (or load-file-name
                         ;; byte-compile and interactive load resolve differently.
                         (bound-and-true-p byte-compile-current-file)
                         (buffer-file-name))))
  "Org file that defines the SCS buffer-header keyword order.
Each non-blank `#+KEYWORD:' line contributes one keyword, in file order.
Change the template file, not hard-coded lists in Elisp, when the team
adds or reorders header fields."
  :type 'file
  :group 'org)

(defconst scs/org--header-keyword-re
  "^[ \t]*#\\+\\([^:\n]+\\):[ \t]*\\(.*\\)$"
  "Regexp matching an Org keyword line; groups are KEY and VALUE.")

(defconst scs/org--header-comment-re
  "^#[^+].*$"
  "Regexp matching a leading # comment that is not an Org #+keyword.")

(defun scs/org--header-stamp ()
  "Return the SCS header timestamp string (local time with weekday)."
  (format-time-string "%Y-%m-%d %a %H:%M"))

(defun scs/org--header-basename ()
  "Return the basename used for FILENAME / TITLE defaults."
  (if buffer-file-name
      (file-name-nondirectory buffer-file-name)
    (buffer-name)))

(defun scs/org--title-from-filename (basename)
  "Turn BASENAME into a sentence-case TITLE.
Strip a trailing .org, replace - and _ with spaces, upcase the first
character and downcase the rest."
  (let* ((name (if (string-suffix-p ".org" basename t)
                   (substring basename 0 -4)
                 basename))
         (spaced (replace-regexp-in-string "[-_]+" " " name))
         (trimmed (string-trim spaced)))
    (if (string-empty-p trimmed)
        ""
      (concat (upcase (substring trimmed 0 1))
              (downcase (substring trimmed 1))))))

(defun scs/org--load-header-template-keywords ()
  "Return the ordered list of header keywords from the template file.
Signals `user-error' if the template is missing or has no keywords."
  (let ((file scs/org-buffer-header-template-file))
    (unless (and file (file-readable-p file))
      (user-error "Header template not readable: %s" file))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (let ((keys nil))
        (while (not (eobp))
          (when (looking-at scs/org--header-keyword-re)
            (push (upcase (match-string 1)) keys))
          (forward-line 1))
        (setq keys (nreverse keys))
        (when (null keys)
          (user-error "Header template has no #+KEYWORD lines: %s" file))
        keys))))

(defun scs/org--header-default (keyword basename stamp)
  "Return the default VALUE for KEYWORD given BASENAME and STAMP."
  (pcase (upcase keyword)
    ("TITLE" (scs/org--title-from-filename basename))
    ("FILENAME" basename)
    ("DESCRIPTION" "")
    ("AUTHOR" "SCS")
    ("COPYRIGHT"
     (format "Copyright (C) %s, SCS, all rights reserved."
             (format-time-string "%Y")))
    ("DATE" stamp)
    ("VERSION" "0.1.0")
    ("LAST-UPDATED" stamp)
    ("UPDATE" "0")
    (_ "")))

(defun scs/org--parse-buffer-preamble (template-keys)
  "Parse the Org buffer preamble against TEMPLATE-KEYS.
Return (END LEADING-COMMENTS KNOWN UNKNOWN).  END is the buffer
position after the preamble, including trailing blank lines that sit
before the first body line.  LEADING-COMMENTS is a list of # comment
lines.  KNOWN is an alist of (KEY . VALUE) for template keys (first
wins).  UNKNOWN is a list of full keyword lines not in the template."
  (save-excursion
    (goto-char (point-min))
    (let ((known nil)
          (unknown nil)
          (comments nil)
          (template-set (mapcar #'upcase template-keys)))
      (cl-block done
        (while (not (eobp))
          (cond
           ((looking-at "^[ \t]*$")
            (forward-line 1))
           ((looking-at scs/org--header-comment-re)
            (push (buffer-substring-no-properties
                   (line-beginning-position) (line-end-position))
                  comments)
            (forward-line 1))
           ((looking-at scs/org--header-keyword-re)
            (let* ((key (upcase (match-string-no-properties 1)))
                   (value (match-string-no-properties 2))
                   (line (buffer-substring-no-properties
                          (line-beginning-position) (line-end-position))))
              ;; First occurrence wins for template keys (duplicates ignored).
              (if (member key template-set)
                  (unless (assoc key known)
                    (push (cons key value) known))
                (push line unknown)))
            (forward-line 1))
           ;; First non-comment, non-keyword, non-blank line ends the preamble.
           (t
            (cl-return-from done)))))
      (list (point)
            (nreverse comments)
            (nreverse known)
            (nreverse unknown)))))

(defun scs/org--header-value (known keyword basename stamp)
  "Return non-empty value for KEYWORD from KNOWN, else a default."
  (let* ((key (upcase keyword))
         (existing (cdr (assoc key known))))
    (if (and existing (not (string-empty-p (string-trim existing))))
        existing
      (scs/org--header-default key basename stamp))))

(defun scs/org--format-header-block (template-keys known comments unknown
                                                  basename stamp)
  "Build the replacement preamble string for the buffer header.
Always ends with a blank line after the canonical keywords (and after
any unknown keywords), so the following body keeps a clear separator."
  (with-temp-buffer
    (dolist (c comments)
      (insert c "\n"))
    (dolist (key template-keys)
      (insert (format "#+%s: %s\n"
                      key
                      (scs/org--header-value known key basename stamp))))
    (insert "\n")
    (dolist (u unknown)
      (insert u "\n"))
    (when unknown
      (insert "\n"))
    (buffer-string)))

;;;###autoload
(defun scs/org-ensure-buffer-header ()
  "Ensure this Org buffer has a full SCS file header.
Reads keyword order from `scs/org-buffer-header-template-file'.  Keeps
existing non-empty values, fills defaults for missing keywords, and
rewrites the preamble in template order.  Leading # comments are kept
above the header.  Unknown #+ keywords are placed after the canonical
block.  Signals `user-error' outside Org mode."
  (interactive)
  (unless (derived-mode-p 'org-mode)
    (user-error "Not in Org mode"))
  (let* ((template-keys (scs/org--load-header-template-keywords))
         (basename (scs/org--header-basename))
         (stamp (scs/org--header-stamp))
         (parsed (scs/org--parse-buffer-preamble template-keys))
         (end (nth 0 parsed))
         (comments (nth 1 parsed))
         (known (nth 2 parsed))
         (unknown (nth 3 parsed))
         (old (buffer-substring-no-properties (point-min) end))
         (new (scs/org--format-header-block
               template-keys known comments unknown basename stamp))
         (added 0))
    (dolist (key template-keys)
      (let ((existing (cdr (assoc (upcase key) known))))
        (when (or (null existing)
                  (string-empty-p (string-trim existing)))
          (setq added (1+ added)))))
    ;; String compare avoids touching the buffer when nothing would change.
    (if (string-equal old new)
        (message "Org buffer header already complete")
      (save-excursion
        (goto-char (point-min))
        (delete-region (point-min) end)
        (insert new))
      (message "Org buffer header: added %d, %s"
               added
               (if (zerop added) "reordered" "filled/reordered")))))

(defun scs/org--property-drawer-bounds ()
  "Return (START END INDENT) of the property drawer on the current heading, or nil.
START and END are buffer positions spanning :properties: through :end:.
INDENT is the leading whitespace shared by every drawer line.

Searches the entire entry between this headline and the next, so a drawer
is found even when body text or other lines precede it."
  (save-excursion
    (org-back-to-heading t)
    (let ((limit (org-entry-end-position)))
      (goto-char (line-beginning-position))
      (when (re-search-forward
             "^\\([ \t]*\\):\\(?:properties\\|PROPERTIES\\):[ \t]*$"
             limit t)
        (let ((start (match-beginning 0))
              (indent (match-string 1)))
          (when (re-search-forward
                 (concat "^" (regexp-quote indent)
                         ":\\(?:end\\|END\\):[ \t]*$")
                 limit t)
            (list start (line-end-position) indent)))))))

(defun scs/org--downcase-property-drawer ()
  "Downcase the property drawer on the current headline.
Converts :properties:, :end:, and every property :KEY: to lowercase.
Property values are left untouched.  Does nothing if the headline has
no drawer.

Locates the drawer with `scs/org--property-drawer-bounds'.  Iteration
stops at the :end: marker so text beyond the drawer is never touched."
  (let ((bounds (scs/org--property-drawer-bounds)))
    ;; cl-case on (null bounds): non-nil bounds => nil => match ((nil) ...)
    (cl-case (null bounds)
      ((nil)
       (cl-destructuring-bind (start end _indent) bounds
         (save-restriction
           (narrow-to-region start end)
           (goto-char (point-min))
           (cl-block done
             (while (not (eobp))
               (when (looking-at "^\\([ \t]*\\):\\([^:\n]+\\):")
                 (downcase-region (match-beginning 2) (match-end 2))
                 (when (string= (match-string 2) "end")
                   (cl-return-from done)))
               (forward-line 1)))))))))

;;;###autoload
(defun scs/org-insert-creation-date ()
  "Set the :creation-date: property on the current headline to today's date.
The date is stored in ISO 8601 format (YYYY-MM-DD).  If the headline has
no property drawer, one is created automatically by `org-entry-put'.
The entire drawer is then normalized to lowercase -- :properties:,
:end:, and all property keys -- so the result is always clean and
consistent.

Signals `user-error' if called outside Org mode."
  (interactive)
  (unless (derived-mode-p 'org-mode)
    (user-error "Not in Org mode"))
  (org-back-to-heading t)
  (org-entry-put nil "creation-date" (format-time-string "%Y-%m-%d"))
  (scs/org--downcase-property-drawer))

(defun scs/org--paragraph-in-list-item-p (paragraph)
  "Return non-nil if PARAGRAPH is nested inside an Org list item."
  (let ((parent (org-element-property :parent paragraph)))
    (and parent (eq (org-element-type parent) 'item))))

(defconst scs/org-zwsp-marker-re "\\\\zwsp{}_[0-9]+"
  "Regexp matching a trailing Org paragraph \\\\zwsp{}_N marker.")

(defun scs/org--set-zwsp-marker-at (contents-end n)
  "At paragraph CONTENTS-END, set trailing marker to N.
Removes an existing match of `scs/org-zwsp-marker-re' immediately before
CONTENTS-END, then inserts \\\\zwsp{}_N.  CONTENTS-END is an Org
`:contents-end' position (text end, not `:end' which includes blank
lines)."
  (save-excursion
    (goto-char contents-end)
    (skip-chars-backward " \t\n")
    ;; Look back only a short distance; markers sit at paragraph end.
    (when (looking-back scs/org-zwsp-marker-re
                        (max (point-min) (- (point) 80)))
      (delete-region (match-beginning 0) (match-end 0)))
    (insert (format "\\zwsp{}_%d" n))))

;;;###autoload
(defun scs/org-append-zwsp-markers (&optional start)
  "Append sequential \\\\zwsp{}_N markers to Org paragraphs from point.
START (prefix arg; default 1) is the first number used.  Only Org
elements of type `paragraph' that contain point or lie after it are
updated; at a paragraph boundary the prior paragraph is skipped.  List
item paragraphs are never updated.  An existing trailing
\\\\zwsp{}_[0-9]+ is replaced.  Sentence punctuation is left unchanged.

Signals `user-error' if called outside Org mode."
  (interactive "p")
  (unless (derived-mode-p 'org-mode)
    (user-error "Not in Org mode"))
  (let* ((start (or start 1))
         (origin (point))
         (paragraphs
          (org-element-map (org-element-parse-buffer) 'paragraph
            (lambda (p)
              (when (and (not (scs/org--paragraph-in-list-item-p p))
                         (or (> (org-element-property :end p) origin)
                             (and (<= (org-element-property :begin p) origin)
                                  (< origin (org-element-property :end p)))))
                p))))
         (n start)
         (jobs nil))
    (dolist (p paragraphs)
      (push (cons (org-element-property :contents-end p) n) jobs)
      (setq n (1+ n)))
    ;; `push' built jobs last->first already; edit in that order.
    (dolist (job jobs)
      (scs/org--set-zwsp-marker-at (car job) (cdr job)))
    (message "Updated %d paragraph%s"
             (length jobs)
             (if (= (length jobs) 1) "" "s"))))

(defun scs/org--strip-surrounding-quotes (s)
  "Return S without one layer of surrounding double or single quotes."
  (if (and s
           (>= (length s) 2)
           (let ((first (aref s 0))
                 (last (aref s (1- (length s)))))
             (or (and (eq first ?\") (eq last ?\"))
                 (and (eq first ?') (eq last ?')))))
      (substring s 1 -1)
    s))

(defun scs/org--basename-candidate-at-point ()
  "Return a raw filename candidate at point, or nil.
Prefer an Org link path, then `thing-at-point' filename, then a quoted
string.  The result may still contain a directory component."
  (or (when (derived-mode-p 'org-mode)
        (let ((ctx (org-element-context)))
          (when (eq (org-element-type ctx) 'link)
            (org-element-property :path ctx))))
      (thing-at-point 'filename t)
      (scs/org--strip-surrounding-quotes (thing-at-point 'string t))))

(defun scs/org--basename-at-point ()
  "Return the nondirectory basename at point for rename, or nil."
  (let* ((raw (scs/org--basename-candidate-at-point))
         (trimmed (and raw (string-trim raw)))
         (base (and trimmed
                    (not (string-empty-p trimmed))
                    (file-name-nondirectory trimmed))))
    (and base (not (string-empty-p base)) base)))

;;;###autoload
(defun scs/rename-visited-file-to-name-at-point ()
  "Rename the visited file to the basename at point.
Confirm with \"OLD: rename to: NEW\".  If the target already exists and
is not the same file, ask a second time before overwriting.  Stays in
the same directory.  Typical binding: `H-c R'."
  (interactive)
  (unless buffer-file-name
    (user-error "Buffer is not visiting a file"))
  (let* ((old buffer-file-name)
         (old-base (file-name-nondirectory old))
         (new-base (or (scs/org--basename-at-point)
                       (user-error "No filename at point")))
         (new (expand-file-name new-base (file-name-directory old))))
    (if (string-equal (expand-file-name old) (expand-file-name new))
        (message "Already named %s" old-base)
      (unless (yes-or-no-p (format "%s: rename to: %s " old-base new-base))
        (user-error "Rename aborted"))
      ;; rename-file needs ok-if-exists when target exists; we still confirm first.
      (let ((ok-if-exists nil))
        (when (file-exists-p new)
          (if (file-equal-p old new)
              (setq ok-if-exists t)
            (unless (yes-or-no-p
                     (format "Overwrite existing %s? " new-base))
              (user-error "Rename aborted"))
            (setq ok-if-exists t)))
        (rename-file old new ok-if-exists)
        (set-visited-file-name new nil t)
        (message "Renamed to %s" new-base)))))

(provide 'org-tools)

;;; org-tools.el ends here
