;;; ox-g-brief.el --- g-brief2 Back-End for Org Export Engine

;; Copyright (C) 2007-2015  Free Software Foundation, Inc.

;; Author: Nicolas Goaziou <n.goaziou AT gmail DOT com>
;;         Alan Schmitt <alan.schmitt AT polytechnique DOT org>
;;         Viktor Rosenfeld <listuser36 AT gmail DOT com>
;;         Rasmus Pank Roulund <emacs AT pank DOT eu>
;;         Bernd Wachter <bwachter-org AT aardsoft DOT fi>
;; Keywords: org, wp, tex

;; TODO:
;; Postvermerk, IhrZeichen, MeinZeichen, IhrSchreiben, Anlagen, Verteiler
;; kill the old subject formatting code
;; kill the encl/ps/... code, replace it with support for anlagen/verteiler

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; This library implements a g-brief back-end, derived from the KOMA one.
;;
;; Depending on the desired output format, three commands are provided
;; for export: `org-g-brief-export-as-latex' (temporary buffer),
;; `org-g-brief-export-to-latex' ("tex" file) and
;; `org-g-brief-export-to-pdf' ("pdf" file).
;;
;; On top of buffer keywords supported by `latex' back-end (see
;; `org-latex-options-alist'), this back-end introduces the following
;; keywords:
;;   - CLOSING: see `org-g-brief-closing',
;;   - FROM_ADDRESS: see `org-g-brief-from-address',
;;   - OPENING: see `org-g-brief-opening',
;;   - SIGNATURE: see `org-g-brief-signature',
;;   - TO_ADDRESS:  If unspecified this is set to "\mbox{}".
;;
;; TO_ADDRESS and FROM_ADDRESS can also be specified using heading
;; with the special tags specified in
;; `org-g-brief-special-tags-in-letter', namely "to" and "from".
;; LaTeX line breaks are not necessary if using these headings.  If
;; both a headline and a keyword specify a to or from address the
;; value is determined in accordance with
;; `org-g-brief-prefer-special-headings'.
;;
;; A number of OPTIONS settings can be set to change which contents is
;; exported.
;;   - name (see `org-g-brief-use-name')
;;   - our-reference (see `org-g-brief-use-our-reference')
;;   - foldmarks (see `org-g-brief-use-foldmarks')
;;   - punchmarks (see `org-g-brief-use-punchmarks')
;;   - windowmarks (see `org-g-brief-use-windowmarks')
;;   - separators (see `org-g-brief-use-separators')
;;   - after-closing-order, a list of the ordering of headings with
;;     special tags after closing (see
;;     `org-g-brief-special-tags-after-closing')
;;   - after-letter-order, as above, but after the end of the letter
;;     (see `org-g-brief-special-tags-after-letter').
;;
;; The following variables works differently from the main LaTeX class
;;   - AUTHOR: Default to user-full-name but may be disabled.
;;     (See also `org-g-brief-author'),
;;
;; Headlines are in general ignored.  However, headlines with special
;; tags can be used for specified contents like postscript (ps),
;; carbon copy (cc), enclosures (encl) and code to be inserted after
;; \end{g-brief} (after_letter).  Specials tags are defined in
;; `org-g-brief-special-tags-after-closing' and
;; `org-g-brief-special-tags-after-letter'.  Currently members of
;; `org-g-brief-special-tags-after-closing' used as macros and the
;; content of the headline is the argument.
;;
;; Headlines with two and from may also be used rather than the
;; keyword approach described above.  If both a keyword and a headline
;; with information is present precedence is determined by
;; `org-g-brief-prefer-special-headings'.
;;
;; You need an appropriate association in `org-latex-classes' in order
;; to use the g-brief class.  By default, two sparse g-brief classes
;; are provided: "default-g-brief" and "default-g-brief-de", generating
;; english or german output. You can also add you own letter class.  For
;; instance:
;;
;;   (add-to-list 'org-latex-classes
;;                '("my-letter"
;;                  "\\documentclass\[%
;;   DIV=14,
;;   fontsize=12pt,
;;   parskip=half,
;;   \[DEFAULT-PACKAGES]
;;   \[PACKAGES]
;;   \[EXTRA]"))
;;
;; Then, in your Org document, be sure to require the proper class
;; with:
;;
;;    #+LATEX_CLASS: my-letter
;;
;; Or by setting `org-g-brief-default-class'.
;;
;; You may have to load (LaTeX) Babel as well, e.g., by adding
;; it to `org-latex-packages-alist',
;;
;;    (add-to-list 'org-latex-packages-alist '("AUTO" "babel" nil))

;;; Code:

(require 'ox-latex)

;; Install a default letter class.
(unless (assoc "default-g-brief" org-latex-classes)
  (add-to-list 'org-latex-classes
	       '("default-g-brief" "\\documentclass[11pt,english]{g-brief2}")
               '("default-g-brief-de" "\\documentclass[11pt,german]{g-brief2}")
               ))


;;; User-Configurable Variables

(defgroup org-export-g-brief nil
  "Options for exporting to g-brief class in LaTeX export."
  :tag "Org g-brief"
  :group 'org-export)

(defcustom org-g-brief-author 'user-full-name
  "Sender's name.

This variable defaults to calling the function `user-full-name'
which just returns the current function `user-full-name'.
Alternatively a string, nil or a function may be given.
Functions must return a string.

This option can also be set with the AUTHOR keyword."
  :group 'org-export-g-brief
  :type '(radio (function-item user-full-name)
		(string)
		(function)
		(const :tag "Do not export author" nil)))

(defcustom org-g-brief-from-address ""
  "Sender's address, as a string.
This option can also be set with one or more FROM_ADDRESS
keywords."
  :group 'org-export-g-brief
  :type 'string)

(defcustom org-g-brief-opening ""
  "Letter's opening, as a string.

This option can also be set with the OPENING keyword.  Moreover,
when:
  (1) this value is the empty string;
  (2) there's no OPENING keyword or it is empty;
  (3) `org-g-brief-headline-is-opening-maybe' is non-nil;
  (4) the letter contains a headline without a special
      tag (e.g. \"to\" or \"ps\");
then the opening will be implicitly set as the headline title.

If a headline is selected as opening, and the headline has the tag `empty'
the opening will be exported as empty string."
  :group 'org-export-g-brief
  :type 'string)

(defcustom org-g-brief-closing ""
  "Letter's closing, as a string.
This option can also be set with the CLOSING keyword.  Moreover,
when:
  (1) there's no CLOSING keyword or it is empty;
  (2) `org-g-brief-headline-is-opening-maybe' is non-nil;
  (3) the letter contains a headline with the special
      tag closing;
then the opening will be set as the title of the closing special
heading."
  :group 'org-export-g-brief
  :type 'string)

(defcustom org-g-brief-signature ""
  "Signature, as a string.
This option can also be set with the SIGNATURE keyword.
Moreover, when:
  (1) there's no CLOSING keyword or it is empty;
  (2) `org-g-brief-headline-is-opening-maybe' is non-nil;
  (3) the letter contains a headline with the special
      tag closing;
then the signature will be  set as the content of the
closing special heading."
  :group 'org-export-g-brief
  :type 'string)

(defcustom org-g-brief-prefer-special-headings nil
  "Non-nil means prefer headlines over keywords for TO and FROM.
This option can also be set with the OPTIONS keyword, e.g.:
\"special-headings:t\"."
  :group 'org-export-g-brief
  :type 'boolean)

(defcustom org-g-brief-use-name nil
  "Non-nil prints the name in the letters header.
This option can also be set with the OPTIONS keyword, e.g.:
\"name:t\"."
  :group 'org-export-g-brief
  :type 'boolean)

(defcustom org-g-brief-use-our-reference nil
  "Configure use of \"our referenc\" vs. \"my reference\"

When t, use \"our reference\". When nil, use \"my reference\""
  :group 'org-export-g-brief
  :type 'boolean)

(defcustom org-g-brief-use-foldmarks t
  "Configure use of folding marks.

When t, activate default folding marks. When nil, do not insert
folding marks at all."
  :group 'org-export-g-brief
  :type 'boolean)

(defcustom org-g-brief-use-punchmarks t
  "Configure use of punch marks.

When t, activate punch marks. When nil, do not insert punch marks."
  :group 'org-export-g-brief
  :type 'boolean)

(defcustom org-g-brief-use-windowmarks t
  "Configure use of window marks for window envelopes.

When t, activate window marks. When nil, do not insert window marks."
  :group 'org-export-g-brief
  :type 'boolean)

(defcustom org-g-brief-use-separators t
  "Configure use of separators between header/text and text/footer.

When t, activate separators. When nil, do not insert separators."
  :group 'org-export-g-brief
  :type 'boolean)

(defcustom org-g-brief-default-class "default-g-brief"
  "Default class for `org-g-brief'.
The value must be a member of `org-latex-classes'."
  :group 'org-export-g-brief
  :type 'string)

(defcustom org-g-brief-headline-is-opening-maybe t
  "Non-nil means a headline may be used as an opening.
A headline is only used if #+OPENING is not set.  See also
`org-g-brief-opening'."
  :group 'org-export-g-brief
  :type 'boolean)

(defconst org-g-brief-special-tags-in-letter
  '(to from closing address bank internet name phone)
  "Header tags related to the letter itself.")

(defconst org-g-brief-special-tags-after-closing '(ps encl cc)
  "Header tags to be inserted after closing.")

(defconst org-g-brief-special-tags-after-letter '(after_letter)
  "Header tags to be inserted after closing.")

(defvar org-g-brief-special-contents nil
  "Holds special content temporarily.")


;;; Define Back-End

(org-export-define-derived-backend 'g-brief 'latex
  :options-alist
  '((:latex-class "LATEX_CLASS" nil org-g-brief-default-class t)
    (:author "AUTHOR" nil (org-g-brief--get-value org-g-brief-author) parse)
    (:author-changed-in-buffer-p "AUTHOR" nil nil t)
    (:from-address "FROM_ADDRESS" nil org-g-brief-from-address newline)
    (:to-address "TO_ADDRESS" nil nil newline)
    (:subject "SUBJECT" nil nil parse)
    (:opening "OPENING" nil org-g-brief-opening space)
    (:closing "CLOSING" nil org-g-brief-closing space)
    (:signature "SIGNATURE" nil org-g-brief-signature newline)
    (:special-headings nil "special-headings"
		       org-g-brief-prefer-special-headings)
    (:special-tags nil nil (append
			    org-g-brief-special-tags-in-letter
			    org-g-brief-special-tags-after-closing
			    org-g-brief-special-tags-after-letter))
    (:with-after-closing nil "after-closing-order"
			 org-g-brief-special-tags-after-closing)
    (:with-after-letter nil "after-letter-order"
			org-g-brief-special-tags-after-letter)
    (:with-name nil "name" org-g-brief-use-name)
    (:with-our-reference nil "our-reference" org-g-brief-use-our-reference)
    (:with-foldmarks nil "foldmarks" org-g-brief-use-foldmarks)
    (:with-punchmarks nil "punchmarks" org-g-brief-use-punchmarks)
    (:with-windowmarks nil "windowmarks" org-g-brief-use-windowmarks)
    (:with-separators nil "separators" org-g-brief-use-separators)
    (:with-headline-opening nil nil org-g-brief-headline-is-opening-maybe)
    ;; Special properties non-nil when a setting happened in buffer.
    ;; They are used to prioritize in-buffer settings over "lco"
    ;; files.  See `org-g-brief-template'.
    (:inbuffer-author "AUTHOR" nil 'g-brief:empty)
    (:inbuffer-signature "SIGNATURE" nil 'g-brief:empty)
    (:inbuffer-with-name nil "name" 'g-brief:empty)
    (:inbuffer-with-foldmarks nil "foldmarks" 'g-brief:empty))
  :translate-alist '((export-block . org-g-brief-export-block)
		     (export-snippet . org-g-brief-export-snippet)
		     (headline . org-g-brief-headline)
		     (keyword . org-g-brief-keyword)
		     (template . org-g-brief-template))
  :menu-entry
  '(?g "Export with g-brief"
       ((?L "As LaTeX buffer" org-g-brief-export-as-latex)
	(?l "As LaTeX file" org-g-brief-export-to-latex)
	(?p "As PDF file" org-g-brief-export-to-pdf)
	(?o "As PDF file and open"
	    (lambda (a s v b)
	      (if a (org-g-brief-export-to-pdf t s v b)
		(org-open-file (org-g-brief-export-to-pdf nil s v b))))))))



;;; Helper functions

;; The following is taken from/inspired by ox-grof.el
;; Thanks, Luis!

(defun org-g-brief--get-tagged-contents (key)
  "Get contents from a headline tagged with KEY.
The contents is stored in `org-g-brief-special-contents'."
  (cdr (assoc-string (org-g-brief--get-value key)
		     org-g-brief-special-contents)))

(defun org-g-brief--get-value (value)
  "Turn value into a string whenever possible.
Determines if VALUE is nil, a string, a function or a symbol and
return a string or nil."
  (when value
    (cond ((stringp value) value)
	  ((functionp value) (funcall value))
	  ((symbolp value) (symbol-name value))
	  (t value))))

(defun org-g-brief--special-contents-as-macro
    (keywords &optional keep-newlines no-tag)
  "Process KEYWORDS members of `org-g-brief-special-contents'.
KEYWORDS is a list of symbols.  Return them as a string to be
formatted.

The function is used for inserting content of special headings
such as PS.

If KEEP-NEWLINES is non-nil leading and trailing newlines are not
removed.  If NO-TAG is non-nil the content in
`org-g-brief-special-contents' are not wrapped in a macro
named whatever the members of KEYWORDS are called."
  (mapconcat
   (lambda (keyword)
     (let* ((name (org-g-brief--get-value keyword))
	    (value (org-g-brief--get-tagged-contents name)))
       (cond ((not value) nil)
	     (no-tag (if keep-newlines value (org-trim value)))
	     (t (format "\\%s{%s}\n"
			name
			(if keep-newlines value (org-trim value)))))))
   keywords
   ""))

(defun org-g-brief--determine-to-and-from (info key)
  "Given INFO determine KEY for the letter.
KEY should be `to' or `from'.

`ox-g-brief' allows two ways to specify TO and FROM.  If both
are present return the preferred one as determined by
`org-g-brief-prefer-special-headings'."
  (let ((option (org-string-nw-p
		 (plist-get info (if (eq key 'to) :to-address :from-address))))
	(headline (org-g-brief--get-tagged-contents key)))
    (replace-regexp-in-string
     "\n" "\\\\\\\\\n"
     (org-trim
      (if (plist-get info :special-headings) (or headline option "")
	(or option headline ""))))))

(defun org-g-brief--insert-footer (key)
  "Fills one of the special g-brief footers. KEY should be Name, Adress,
Telefon, Internet or Bank."
  (let ((footers (list "A" "B" "C" "D" "E" "F"))
        (headline (split-string (or (org-g-brief--get-tagged-contents key) "") "\n"))
        (footer (cond
                 ((eq key 'name) "NameZeile")
                 ((eq key 'address) "AdressZeile")
                 ((eq key 'phone) "TelefonZeile")
                 ((eq key 'internet) "InternetZeile")
                 ((eq key 'bank) "BankZeile")))
        (value "\n")
        )
    (dotimes (number 6 value)
      (setq value (concat value "\\" footer (nth number footers) "{" (nth number headline) "}\n")))))




;;; Transcode Functions

;;;; Export Block

(defun org-g-brief-export-block (export-block contents info)
  "Transcode an EXPORT-BLOCK element into g-brief code.
CONTENTS is nil.  INFO is a plist used as a communication
channel."
  (when (member (org-element-property :type export-block) '("g-brief" "LATEX"))
    (org-remove-indentation (org-element-property :value export-block))))

;;;; Export Snippet

(defun org-g-brief-export-snippet (export-snippet contents info)
  "Transcode an EXPORT-SNIPPET object into g-brief code.
CONTENTS is nil.  INFO is a plist used as a communication
channel."
  (when (memq (org-export-snippet-backend export-snippet) '(latex g-brief))
    (org-element-property :value export-snippet)))

;;;; Keyword

(defun org-g-brief-keyword (keyword contents info)
  "Transcode a KEYWORD element into g-brief code.
CONTENTS is nil.  INFO is a plist used as a communication
channel."
  (let ((key (org-element-property :key keyword))
	(value (org-element-property :value keyword)))
    ;; Handle specifically G-BRIEF keywords.  Otherwise, fallback
    ;; to `latex' back-end.
    (if (equal key "G-BRIEF") value
      (org-export-with-backend 'latex keyword contents info))))

;; Headline

(defun org-g-brief-headline (headline contents info)
  "Transcode a HEADLINE element from Org to LaTeX.
CONTENTS holds the contents of the headline.  INFO is a plist
holding contextual information.

Note that if a headline is tagged with a tag from
`org-g-brief-special-tags' it will not be exported, but
stored in `org-g-brief-special-contents' and included at the
appropriate place."
  (let ((special-tag (org-g-brief--special-tag headline info)))
    (if (not special-tag)
	contents
      (push (cons special-tag contents) org-g-brief-special-contents)
      "")))

(defun org-g-brief--special-tag (headline info)
  "Non-nil if HEADLINE is a special headline.
INFO is a plist holding contextual information.  Return first
special tag headline."
  (let ((special-tags (plist-get info :special-tags)))
    (catch 'exit
      (dolist (tag (org-export-get-tags headline info))
	(let ((tag (assoc-string tag special-tags)))
	  (when tag (throw 'exit tag)))))))

;;;; Template

(defun org-g-brief-template (contents info)
  "Return complete document string after g-brief conversion.
CONTENTS is the transcoded contents string.  INFO is a plist
holding export options."
  (concat
   ;; Time-stamp.
   (and (plist-get info :time-stamp-file)
        (format-time-string "%% Created %Y-%m-%d %a %H:%M\n"))
   ;; Document class and packages.
   (org-latex--make-header info)
   ;; Settings.  They can come from two locations, in increasing
   ;; order of precedence: global variables  and in-buffer
   ;; settings.  Thus, we first insert settings coming from global
   ;; variables, then we insert settings coming from buffer keywords.
   (org-g-brief--build-settings 'global info)
   (org-g-brief--build-settings 'buffer info)

   (org-g-brief--insert-footer 'name)
   (org-g-brief--insert-footer 'address)
   (org-g-brief--insert-footer 'phone)
   (org-g-brief--insert-footer 'internet)
   (org-g-brief--insert-footer 'bank)

   ;; From address.
   (let ((from-address (org-g-brief--determine-to-and-from info 'from)))
     (when (org-string-nw-p from-address)
       (format "\\RetourAdresse{%s}\n" from-address)))
   ;; Date.
   (format "\\Datum{%s}\n" (org-export-data (org-export-get-date info) info))
   ;; Hyperref, document start, and subject
   (let* ((subject (org-string-nw-p
		     (org-export-data (plist-get info :subject) info)))
	  (hyperref-template (plist-get info :latex-hyperref-template))
	  (spec (append (list (cons ?t (or subject "")))
			(org-latex--format-spec info))))
     (concat
      ;; Hyperref.
      (format-spec hyperref-template spec)
      ;; Subject
      (when subject (format "\\Betreff{%s}\n" subject))

      ;; Opening.
      (format "\\Anrede{%s}\n\n"
              (org-export-data
               (or (org-string-nw-p (plist-get info :opening))
                   (when (plist-get info :with-headline-opening)
                     (org-element-map (plist-get info :parse-tree) 'headline
                       (lambda (head)
                         (let ((tags (and (plist-get info :with-tags)
                                          (org-export-get-tags head info))))
                           (unless (org-g-brief--special-tag head info)
                             (if (member "empty" tags)
                                 ""
                             (org-element-property :title head)))
                           ))
                       info t))
                   "")
               info))

      ;; Closing.
      (format "\n\\Gruss{%s}{1cm}\n"
              (org-export-data
               (or (org-string-nw-p (plist-get info :closing))
                   (when (plist-get info :with-headline-opening)
                     (org-element-map (plist-get info :parse-tree) 'headline
                       (lambda (head)
                         (when (eq (org-g-brief--special-tag head info)
                                   'closing)
                           (org-element-property :title head)))
                       info t)))
               info))

      (format "\n\\Adresse{%s}\n" (org-g-brief--determine-to-and-from info 'to))

      ;; Document start.
      "\\begin{document}\n\n"
      ))

   ;; Letter start.
   "\\begin{g-brief}\n\n"

   ;; Letter body.
   contents

   (org-g-brief--special-contents-as-macro
    (plist-get info :with-after-closing))
   ;; Letter end.
   "\n\\end{g-brief}\n"
   (org-g-brief--special-contents-as-macro
    (plist-get info :with-after-letter) t t)
   ;; Document end.
   "\n\\end{document}"))

(defun org-g-brief--build-settings (scope info)
  "Build settings string according to type.
SCOPE is either `global' or `buffer'.  INFO is a plist used as
a communication channel."
  (let ((check-scope
         (function
          ;; Non-nil value when SETTING was defined in SCOPE.
          (lambda (setting)
            (let ((property (intern (format ":inbuffer-%s" setting))))
              (if (eq scope 'global)
		  (eq (plist-get info property) 'g-brief:empty)
                (not (eq (plist-get info property) 'g-brief:empty))))))))
    (concat
     ;; Name.
     (and (funcall check-scope 'with-name)
          (let ((author (plist-get info :author)))
            (and author
                 (funcall check-scope 'author)
                 (format "\\Name{%s}\n"
                         (org-export-data author info)))))
     ;; Signature.
     (let* ((heading-val
	     (and (plist-get info :with-headline-opening)
		  (org-string-nw-p
		   (org-trim
		    (org-export-data
		     (org-g-brief--get-tagged-contents 'closing)
		     info)))))
	    (signature (org-string-nw-p (plist-get info :signature)))
	    (signature-scope (funcall check-scope 'signature)))
       (and (or (and signature signature-scope)
		heading-val)
	    (not (and (eq scope 'global) heading-val))
	    (format "\\Unterschrift{%s}\n"
		    (if signature-scope signature heading-val))))

     (and (funcall check-scope 'with-our-reference)
          (if (plist-get info :with-our-reference)
              "\\unserzeichen\n"))
     (and (funcall check-scope 'with-foldmarks)
          (if (plist-get info :with-foldmarks)
              "\\faltmarken\n"))
     (and (funcall check-scope 'with-punchmarks)
          (if (plist-get info :with-punchmarks)
              "\\lochermarke\n"))
     (and (funcall check-scope 'with-windowmarks)
          (if (plist-get info :with-windowmarks)
              "\\fenstermarken\n"))
     (and (funcall check-scope 'with-separators)
          (if (plist-get info :with-separators)
              "\\trennlinien\n")))))


;;; Commands

;;;###autoload
(defun org-g-brief-export-as-latex
  (&optional async subtreep visible-only body-only ext-plist)
  "Export current buffer as a g-brief letter.

If narrowing is active in the current buffer, only export its
narrowed part.

If a region is active, export that region.

A non-nil optional argument ASYNC means the process should happen
asynchronously.  The resulting buffer should be accessible
through the `org-export-stack' interface.

When optional argument SUBTREEP is non-nil, export the sub-tree
at point, extracting information from the headline properties
first.

When optional argument VISIBLE-ONLY is non-nil, don't export
contents of hidden elements.

When optional argument BODY-ONLY is non-nil, only write code
between \"\\begin{g-brief}\" and \"\\end{g-brief}\".

EXT-PLIST, when provided, is a proeprty list with external
parameters overriding Org default settings, but still inferior to
file-local settings.

Export is done in a buffer named \"*Org G-BRIEF Export*\".  It
will be displayed if `org-export-show-temporary-export-buffer' is
non-nil."
  (interactive)
  (let (org-g-brief-special-contents)
    (org-export-to-buffer 'g-brief "*Org G-BRIEF Export*"
      async subtreep visible-only body-only ext-plist
      (lambda () (LaTeX-mode)))))

;;;###autoload
(defun org-g-brief-export-to-latex
  (&optional async subtreep visible-only body-only ext-plist)
  "Export current buffer as a g-brief letter (tex).

If narrowing is active in the current buffer, only export its
narrowed part.

If a region is active, export that region.

A non-nil optional argument ASYNC means the process should happen
asynchronously.  The resulting file should be accessible through
the `org-export-stack' interface.

When optional argument SUBTREEP is non-nil, export the sub-tree
at point, extracting information from the headline properties
first.

When optional argument VISIBLE-ONLY is non-nil, don't export
contents of hidden elements.

When optional argument BODY-ONLY is non-nil, only write code
between \"\\begin{g-brief}\" and \"\\end{g-brief}\".

EXT-PLIST, when provided, is a property list with external
parameters overriding Org default settings, but still inferior to
file-local settings.

When optional argument PUB-DIR is set, use it as the publishing
directory.

Return output file's name."
  (interactive)
  (let ((outfile (org-export-output-file-name ".tex" subtreep))
	(org-g-brief-special-contents))
    (org-export-to-file 'g-brief outfile
      async subtreep visible-only body-only ext-plist)))

;;;###autoload
(defun org-g-brief-export-to-pdf
  (&optional async subtreep visible-only body-only ext-plist)
  "Export current buffer as a g-brief letter (pdf).

If narrowing is active in the current buffer, only export its
narrowed part.

If a region is active, export that region.

A non-nil optional argument ASYNC means the process should happen
asynchronously.  The resulting file should be accessible through
the `org-export-stack' interface.

When optional argument SUBTREEP is non-nil, export the sub-tree
at point, extracting information from the headline properties
first.

When optional argument VISIBLE-ONLY is non-nil, don't export
contents of hidden elements.

When optional argument BODY-ONLY is non-nil, only write code
between \"\\begin{g-brief}\" and \"\\end{g-brief}\".

EXT-PLIST, when provided, is a property list with external
parameters overriding Org default settings, but still inferior to
file-local settings.

Return PDF file's name."
  (interactive)
  (let ((file (org-export-output-file-name ".tex" subtreep))
	(org-g-brief-special-contents))
    (org-export-to-file 'g-brief file
      async subtreep visible-only body-only ext-plist
      (lambda (file) (org-latex-compile file)))))


(provide 'ox-g-brief)
;;; ox-g-brief.el ends here
