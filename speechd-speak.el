;;; speechd-speak.el --- simple speechd-el based Emacs client

;; Copyright (C) 2003 Brailcom, o.p.s.

;; COPYRIGHT NOTICE
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

;;; Commentary:

;; This is a simple experimental Emacs client to speechd.  Some ideas taken
;; from the Emacspeak package (http://emacspeak.sourceforge.net) by
;; T. V. Raman.

;;; Code:


(eval-when-compile (require 'cl))
(require 'speechd)


(defconst speechd-speak-version "$Id: speechd-speak.el,v 1.26 2003-07-24 19:06:39 pdm Exp $"
  "Version of the speechd-speak file.")


;;; User options


(defgroup speechd-speak nil
  "Speechd-el user client customization."
  :group 'speechd-el)

(defcustom speechd-speak-startup-hook nil
  "Hook to run after starting speechd-speak."
  :type 'sexp
  :group 'speechd-speak)

(defcustom speechd-speak-deleted-char t
  "If non-nil, speak the deleted char, otherwise speak the adjacent char."
  :type 'boolean
  :group 'speechd-speak)

(defcustom speechd-speak-buffer-name t
  "If non-nil, speak buffer name on a buffer change, otherwise speak a line."
  :type 'boolean
  :group 'speechd-speak)

(defcustom speechd-speak-auto-speak-buffers '("*Help*")
  "List of names of other-window buffers to speak is nothing else fits.
If nothing else is to be spoken after a command and a visible window in the
current frame displaying a buffer with a name contained in this list is
changed, the contents of the window buffer is spoken."
  :type '(repeat string)
  :group 'speechd-speak)

(defcustom speechd-speak-force-auto-speak-buffers '()
  "List of names of other-window buffers to speak on visible changes.
Like `speechd-speak-auto-speak-buffers' except that the window content is
spoken even when there are other messages to speak."
  :type '(repeat string)
  :group 'speechd-speak)

(defcustom speechd-speak-by-properties-on-movement t
  "Method of selection of the piece of text to be spoken on movement.
Unless a command provides its speechd feedback in a different way, it speaks
the current line by default if the cursor has moved.  However, if this variable
is t, it speaks the uniform text around the cursor, where \"uniform\"
means the maximum amount of text without any text property change.

If the variable is a list of faces, uniform text is spoken only when the cursor
is on one of the named faces.

Speaking uniform text only works if font-lock-mode is enabled for the current
buffer.

See also `speechd-speak-by-properties-always' and
`speechd-speak-by-properties-never'."
  :type '(choice (const t) (repeat face))
  :group 'speechd-speak)

(defcustom speechd-speak-by-properties-always '()
  "List of commands to always speak by properties on movement.
The elements of the list are command names, symbols.

See `speechd-speak-by-properties-on-movement' for more information about
property speaking."
  :type '(repeat symbol)
  :group 'speechd-speak)

(defcustom speechd-speak-by-properties-never '()
  "List of commands to never speak by properties on movement.
The elements of the list are command names, symbols.

See `speechd-speak-by-properties-on-movement' for more information about
property speaking."
  :type '(repeat symbol)
  :group 'speechd-speak)

(defcustom speechd-speak-faces '()
  "Alist of faces and speaking functions.
Each element of the list is of the form (FACE . ACTION).
If a movement command leaves the cursor on a FACE and there is no explicit
speaking bound to the command, ACTION is invoked.

If ACTION is a string, the string is spoken.
If ACTION is a function, it is invoked, with no arguments."
  :type '(repeat (cons face (choice string function)))
  :group 'speechd-speak)

(defcustom speechd-speak-whole-line nil
  "If non-nil, speak whole line on movement by default.
Otherwise from the point to the end of line on movement by default."
  :type 'boolean
  :group 'speechd-speak)

(defcustom speechd-speak-connections '()
  "Alist mapping major modes and buffers to speechd connection.
By default, there's a single connection to speechd, named \"default\".  This
variable can define special connections for particular major modes and buffers.

Each element of the alist is of the form (MODE-OR-BUFFER . CONNECTION-NAME).

MODE-OR-BUFFER may be, in the order of preference from the highest to the
lowest:

- a list, representing a function call returning non-nil iff the element should
  be applied
- buffer name
- the symbol `:minibuffer', representing minibuffers
- major mode symbol
- nil, representing non-buffer areas, e.g. echo area
- t, representing the default value if nothing else matches

CONNECTION-NAME is an arbitrary non-empty string naming the corresponding
connection.  If connection with such a name doesn't exist, it is automatically
created."
  :type '(repeat (cons :tag "Connection"
                       (choice :tag "Matcher" :value nil
                         (const :tag "Default" t)
                         (const :tag "Non-buffers" nil)
                         (const :tag "Minibuffer" :value :minibuffer)
                         (symbol :tag "Major mode" :value fundamental-mode)
                         (string :tag "Buffer name" :value "")
                         (restricted-sexp :tag "Function call"
                                          :match-alternatives (listp)))
                       (string :tag "Connection name")))
  :group 'speechd-speak)

(defcustom speechd-speak-buffer-insertions 'one-line
  "Defines whether insertions in a current buffer should be read automatically.
The value is a symbol and can be from the following set:
- nil means don't speak them
- t means speak them all
- `one-line' means speak only changes not exceeding line boundary
Only newly inserted text is read, the option doesn't affect processing of
deleted text.  Also, the option doesn't affect insertions within commands
processed in a different way by speechd-speak or user definitions."
  :type '(choice (const :tag "Never" nil)
                 (const :tag "One-line changes only" 'one-line)
                 (const :tag "Always" t))
  :group 'speechd-speak)

(defcustom speechd-speak-align-buffer-insertions t
  "If non-nil, read insertions aligned to the beginning of the first word."
  :type 'boolean
  :group 'speechd-speak)

(defcustom speechd-speak-signal-empty t
  "If non-nil, signal empty lines with a standard sound icon."
  :type 'boolean
  :group 'speechd-speak)

(defcustom speechd-speak-signal-beginning-of-line t
  "If non-nil, signal beginning of lines with a standard sound icon."
  :type 'boolean
  :group 'speechd-speak)

(defcustom speechd-speak-signal-end-of-line t
  "If non-nil, signal ends of lines with a standard sound icon."
  :type 'boolean
  :group 'speechd-speak)

(defcustom speechd-speak-prefix "\C-e"
  "Default prefix key used for speechd-speak commands."
  :set #'(lambda (name value)
	   (set-default name value)
	   (global-set-key value 'speechd-speak-prefix-command))
  :type 'sexp
  :group 'speechd-speak)


;;; Internal constants


(defvar speechd-speak--empty-message "*empty-text")
(defvar speechd-speak--beginning-of-line-message "*beginning-of-line")
(defvar speechd-speak--end-of-line-message "*end-of-line")


;;; Control functions


(defvar speechd-speak-quiet t
  "If non-nil in the current buffer, no speech output is produced.")

(defun speechd-speak-toggle-quiet (&optional prefix speak silently)
  "Turn speaking on or off.
Without the PREFIX argument, toggle speaking globally, except for the buffers
with previously explicitly toggled speaking.
With the universal PREFIX argument, toggle speaking in all buffers.
With the PREFIX argument 1, toggle speaking in the current buffer only.

If the optional argument SPEAK is a positive number, turn speaking on; if it
is a non-positive number, turn speaking off.

If the optional argument SILENTLY is non-nil, don't report switching the mode."
  (interactive "P")
  (let ((new-state (if (numberp speak) (<= speak 0) (not speechd-speak-quiet)))
	prompt)
    (cond
     ((not prefix)
      (setq-default speechd-speak-quiet new-state)
      (setq speechd-speak-quiet new-state
	    prompt "globally"))
     ((listp prefix)
      (save-excursion
	(mapc #'(lambda (buffer)
		  (when (local-variable-p 'speechd-speak-quiet buffer)
		    (set-buffer buffer)
		    (kill-local-variable 'speechd-speak-quiet)))
	      (buffer-list)))
      (setq speechd-speak-quiet new-state
	    prompt "everywhere"))
     (t
      (make-local-variable 'speechd-speak-quiet)
      (setq speechd-speak-quiet new-state
	    prompt "in the current buffer")))
    (when speechd-speak-quiet
      (speechd-cancel))
    (unless silently
      (let ((speechd-speak-quiet nil))
        (message "Speaking turned %s %s" (if new-state "off" "on") prompt)))))

(defvar speechd-speak--predefined-rates
  '((1 . -100)
    (2 . -75)
    (3 . -50)
    (4 . -25)
    (5 . 0)
    (6 . 25)
    (7 . 50)
    (8 . 75)
    (9 . 100)))
(defun speechd-speak-set-predefined-rate (level)
  "Set speech rate to one of nine predefined levels.
Level 1 is the slowest, level 9 is the fastest."
  (interactive "nSpeech rate level (1-9): ")
  (setq level (min (max level 1) 9))
  (let ((rate (cdr (assoc level speechd-speak--predefined-rates))))
    (speechd-set-rate rate)
    (message "Speech rate set to %d" rate)))

(defvar speechd-speak--char-to-number
  '((?1 . 1) (?2 . 2) (?3 . 3) (?4 . 4) (?5 . 5)
    (?6 . 6) (?7 . 7) (?8 . 8) (?9 . 9)))
(defun speechd-speak-key-set-predefined-rate ()
  "Set speech rate to one of nine predefined levels via a key binding.
Level 1 is the slowest, level 9 is the fastest."
  (interactive)
  (let ((level (cdr (assoc last-input-char speechd-speak--char-to-number))))
    (when level
      (speechd-speak-set-predefined-rate level))))


;;; Supporting functions and options


(defvar speechd-speak--last-buffer-mode t)
(defvar speechd-speak--last-connection-name nil)
(defvar speechd-speak--last-connections nil)
(defvar speechd-speak--default-connection-name "default")
(defvar speechd-speak--special-area nil)
(defun speechd-speak--connection-name ()
  (let ((buffer-mode (if speechd-speak--special-area
                         nil
                       (cons major-mode (buffer-name)))))
    (if (and (eq speechd-speak-connections speechd-speak--last-connections)
             (equal buffer-mode speechd-speak--last-buffer-mode))
        speechd-speak--last-connection-name
      (progn
        (setq speechd-speak--last-buffer-mode buffer-mode
              speechd-speak--last-connections speechd-speak-connections
              speechd-speak--last-connection-name
              (if buffer-mode
                  (or (cdr (or ;; functional test
                               (let ((specs speechd-speak-connections)
                                     (result nil))
                                 (while (and (not result) specs)
                                   (if (and (listp (caar specs))
                                            (eval (caar specs)))
                                       (setq result (car specs))
                                     (setq specs (cdr specs))))
                                 result)
                               ;; buffer name
                               (assoc (buffer-name) speechd-speak-connections)
                               ;; minibuffer
                               (and (speechd-speak--in-minibuffer-p)
                                    (assoc :minibuffer
                                           speechd-speak-connections))
                               ;; major mode
                               (assq major-mode speechd-speak-connections)
                               ;; default
                               (assq t speechd-speak-connections)))
                      speechd-speak--default-connection-name)
                (or (cdr (assq nil speechd-speak-connections))
                    speechd-speak--default-connection-name)))
        (set (make-local-variable 'speechd-client-name)
             speechd-speak--last-connection-name)))))

(defmacro* speechd-speak--maybe-speak (&body body)
  `(unless speechd-speak-quiet
     (let ((speechd-client-name (speechd-speak--connection-name)))
       ,@body)))

(defun speechd-speak--text (text &rest args)
  (speechd-speak--maybe-speak
   ;; TODO: skip invisible text
   ;; TODO: replace repeating patterns
   ;; TODO: handle selective display
   (apply #'speechd-say-text text args)))

(defun speechd-speak--char (&rest args)
  (speechd-speak--maybe-speak
   (apply #'speechd-say-char args)))

(defun speechd-speak--key (&rest args)
  (speechd-speak--maybe-speak
   (apply #'speechd-say-key args)))

(defun speechd-speak--sound (&rest args)
  (speechd-speak--maybe-speak
   (apply #'speechd-say-sound args)))

(defun speechd-speak-report (message &rest args)
  "Speak text or sound icon MESSAGE.
MESSAGE is a string; if it starts with the `*' character, the asterisk is
stripped of the MESSAGE and the rest of MESSAGE names a sound icon to play.
Otherwise MESSAGE is simply a text to speak.

ARGS are appended to the arguments of the corresponding speaking
function (`speechd-say-text' or `speechd-say-sound') without change after the
message argument."
  (speechd-speak--maybe-speak
   (unless (string= message "")
     (if (string-match "^\\*" message)
         (apply #'speechd-say-sound (substring message 1) args)
       (apply #'speechd-say-text message args)))))

(defun speechd-speak-read-char (&optional char)
  "Read character CHAR.
If CHAR is nil, speak the character just after current point."
  (interactive)
  (speechd-speak--char (or char (following-char))))

(defun speechd-speak-read-region (&optional beg end empty-text)
  "Read region of the current buffer between BEG and END.
If BEG is nil, current mark is used instead.
If END is nil, current point is used instead.
EMPTY-TEXT is a text to say if the region is empty; if nil, empty text icon is
played."
  (interactive "r")
  (let ((text (buffer-substring (or beg (mark)) (or end (point)))))
    (if (string= text "")
        (speechd-speak-report (or empty-text
                                  (if speechd-speak-signal-empty
                                      speechd-speak--empty-message
                                    ""))
                              :priority :message)
      (speechd-speak--text text))))

(defun speechd-speak-read-line (&optional rest-only)
  "Speak current line.
If REST-ONLY is non-nil, read only the part of the line from the current point
to the end of the line."
  (interactive)
  (speechd-speak-read-region (if rest-only (point) (line-beginning-position))
			     (line-end-position)
			     (when (speechd-speak--in-minibuffer-p) "")))

(defun speechd-speak-read-next-line ()
  "Speak the next line after the current line.
If there is no such line, play the empty text icon."
  (interactive)
  (save-excursion
    (if (= (forward-line 1) 0)
        (speechd-speak-read-line)
      (speechd-speak-report speechd-speak--empty-message))))

(defun speechd-speak-read-previous-line ()
  "Speak the previous line before the current line.
If there is no such line, play the empty text icon."
  (interactive)
  (save-excursion
    (if (= (forward-line -1) 0)
        (speechd-speak-read-line)
      (speechd-speak-report speechd-speak--empty-message))))

(defun speechd-speak-read-buffer (&optional buffer)
  "Read BUFFER.
If BUFFER is nil, read current buffer."
  (interactive)
  (save-excursion
    (when buffer
      (set-buffer buffer))
    (speechd-speak-read-region (point-min) (point-max))))

(defun speechd-speak-read-rest-of-buffer ()
  "Read current buffer from the current point to the end of the buffer."
  (interactive)
  (speechd-speak-read-region (point) (point-max)))

(defun speechd-speak-read-other-window ()
  "Read buffer of the last recently used window."
  (interactive)
  (speechd-speak-read-buffer (window-buffer (get-lru-window))))

(defun speechd-speak--window-contents ()
  (sit-for 0)                           ; to update window start and end
  (speechd-speak-read-region (window-start) (window-end)))

(defun speechd-speak--uniform-text-around-point ()
  (let ((beg (speechd-speak--previous-property-change (1+ (point))))
	(end (speechd-speak--next-property-change (point))))
    (speechd-speak-read-region beg end)))

(defun speechd-speak--speak-piece (start)
  (let ((point (point)))
    (if (> (count-lines start point) 1)
	(speechd-speak-read-line)
      (speechd-speak-read-region start point))))

(defun speechd-speak--speak-current-column ()
  (speechd-speak--text (format "Column %d" (current-column))))

(defmacro speechd-speak--def-speak-object (type)
  (let* ((name (symbol-name type))
	 (function-name (intern (format "speechd-speak-read-%s" name)))
	 (backward-function (intern (format "backward-%s" name)))
	 (forward-function (intern (format "forward-%s" name))))
    `(defun ,function-name ()
       (interactive)
       (save-excursion
	 (let* ((point (point))
                (end (progn (,forward-function 1) (point)))
                (beg (progn (,backward-function 1) (point))))
           (when (<= (progn (,forward-function 1) (point)) point)
             (setq beg end))
	   (speechd-speak-read-region beg end))))))

(speechd-speak--def-speak-object word)
(speechd-speak--def-speak-object sentence)
(speechd-speak--def-speak-object paragraph)
(speechd-speak--def-speak-object page)
(speechd-speak--def-speak-object sexp)

(defstruct speechd-speak--command-info-struct
  buffer
  point
  modified
  changes
  other-window
  other-buffer-modified
  minibuffer-contents)

(defvar speechd-speak--command-start-info (make-vector 5 nil))

(defmacro* speechd-speak--with-minibuffer-depth (&body body)
  `(let ((depth (minibuffer-depth)))
     (when (>= depth (length speechd-speak--command-start-info))
       (setq speechd-speak--command-start-info
	     (vconcat speechd-speak--command-start-info
		      (make-vector
		       (- (1+ depth)
			  (length speechd-speak--command-start-info))
		       nil))))
     ,@body))

(defun speechd-speak--in-minibuffer-p ()
  (window-minibuffer-p (selected-window)))

(defun speechd-speak--command-start-info ()
  (speechd-speak--with-minibuffer-depth
    (aref speechd-speak--command-start-info depth)))

(defun speechd-speak--set-command-start-info (&optional reset)
  (speechd-speak--with-minibuffer-depth
    (aset speechd-speak--command-start-info depth
	  (if reset
	      nil
	    (ignore-errors
	      (let ((other-window (next-window)))
		(make-speechd-speak--command-info-struct
		 :buffer (current-buffer) :point (point)
		 :modified (buffer-modified-tick)
                 :changes '()
		 :other-window other-window
		 :other-buffer-modified (and other-window
					     (buffer-modified-tick
					      (window-buffer other-window)
					      ))
                 :minibuffer-contents (if (speechd-speak--in-minibuffer-p)
                                          (minibuffer-contents)
                                        'unset))))))))

(defun speechd-speak--reset-command-start-info ()
  (speechd-speak--set-command-start-info t))

(defmacro* speechd-speak--with-command-start-info (&body body)
  `(let ((info (speechd-speak--command-start-info)))
     (when info
       ,@body)))

(defmacro* speechd-speak--defadvice (function class &body body)
  (let* ((function* function)
         (fname (if (listp function*) (first function*) function*))
         (aname (if (listp function*) 'speechd-speak-user 'speechd-speak)))
    `(defadvice ,fname (,class ,aname activate preactivate compile)
       ,@body)))

(defmacro speechd-speak-function-feedback (function position feedback)
  "Report FEEDBACK on each invocation of FUNCTION.
FUNCTION is a function name.
POSITION may be one of the symbols `before' (the feedback is run before the
function is invoked) or `after' (the feedback is run after the function is
invoked.
FEEDBACK is a string to be given as the argument of the `speechd-speak-report'
function."
  `(speechd-speak--defadvice ,(list function) ,position
     (speechd-speak-report ,feedback :priority :message)))

(defmacro speechd-speak-command-feedback (function position feedback)
  "Report FEEDBACK on each invocation of FUNCTION.
The arguments are the same as in `speechd-speak-function-feedback'.
Unlike `speechd-speak-function-feedback', the feedback is reported only when
FUNCTION is invoked interactively."
  `(speechd-speak--defadvice ,(list function) ,position
     (when (interactive-p)
       (speechd-speak-report ,feedback :priority :message))))

(defmacro* speechd-speak--command-feedback (commands position &body body)
  (let ((commands* (if (listp commands) commands (list commands)))
	(position* position)
	(body* `(progn (speechd-speak--reset-command-start-info) ,@body)))
    `(progn
       ,@(mapcar #'(lambda (command)
		     `(speechd-speak--defadvice ,command ,position*
			,(if (eq position* 'around)
			     `(if (interactive-p)
				  ,body*
				ad-do-it)
			   `(when (interactive-p)
			      ,body*))))
		 commands*))))

(defmacro* speechd-speak--command-feedback-region (commands &key (move nil))
  `(speechd-speak--command-feedback ,commands around
     (let ((start (save-excursion ,move (point))))
       ad-do-it
       (speechd-speak--speak-piece start))))

(defun* speechd-speak--next-property-change (&optional (point (point))
                                                       (limit (point-max)))
  (next-char-property-change point limit))

(defun* speechd-speak--previous-property-change (&optional (point (point))
                                                           (limit (point-min)))
  (previous-char-property-change point limit))



;;; Basic speaking


;; These two simply don't work in Emacs 21.3 when invoked via key binding.
;; They're called directly in Emacs 21, to speed them up; no advice is invoked
;; in such a case.

;; (speechd-speak--command-feedback (self-insert-command) after
;;   (speechd-speak--char (preceding-char)))

;; (speechd-speak--command-feedback (forward-char backward-char) after
;;   (speechd-speak-read-char))

(speechd-speak--command-feedback (next-line previous-line) after
  (speechd-speak-read-line))

(speechd-speak--command-feedback (forward-word backward-word) after
  (speechd-speak-read-word))

(speechd-speak--command-feedback (beginning-of-buffer end-of-buffer) after
  (speechd-speak-read-line))

(speechd-speak--command-feedback (forward-sentence backward-sentence) after
  (speechd-speak-read-sentence))

(speechd-speak--command-feedback (forward-paragraph backward-paragraph) after
  (speechd-speak-read-paragraph))

(speechd-speak--command-feedback (forward-page backward-page) after
  (speechd-speak-read-page))

(speechd-speak--command-feedback (beginning-of-defun end-of-defun) after
  (speechd-speak-read-line))

(speechd-speak--command-feedback (scroll-up scroll-down) after
  (speechd-speak--window-contents))

(speechd-speak--command-feedback-region
 (backward-sexp forward-sexp forward-list backward-list up-list
  backward-up-list down-list))

(speechd-speak--command-feedback (upcase-word downcase-word capitalize-word)
				 after
  (speechd-speak-read-word))

(speechd-speak--command-feedback (delete-backward-char backward-delete-char
				  backward-delete-char-untabify)
				 around
  (when speechd-speak-deleted-char
    (speechd-speak-read-char (preceding-char)))
  ad-do-it
  (unless speechd-speak-deleted-char
    (speechd-speak-read-char (preceding-char))))

(speechd-speak--command-feedback (delete-char) around
  (when speechd-speak-deleted-char
    (speechd-speak-read-char (following-char)))
  ad-do-it
  (unless speechd-speak-deleted-char
    (speechd-speak-read-char (following-char))))

(speechd-speak--command-feedback (quoted-insert) after
  (speechd-speak-read-char (preceding-char)))

(speechd-speak--command-feedback (newline newline-and-indent) before
  (speechd-speak-read-line))

(speechd-speak--command-feedback (undo) after
  (speechd-speak-read-line))


;;; Killing and yanking


(speechd-speak--command-feedback (kill-word) before
  (speechd-speak-read-word))

(speechd-speak--command-feedback (backward-kill-word) before
  (save-excursion
    (forward-word -1)
    (speechd-speak-read-word)))

(speechd-speak--command-feedback (kill-line) before
  (speechd-speak-read-line))

(speechd-speak--command-feedback (kill-sexp) before
  (speechd-speak-read-sexp))

(speechd-speak--command-feedback (kill-sentence) before
  (speechd-speak-read-sentence))

(speechd-speak--command-feedback (zap-to-char) after
  (speechd-speak-read-line))

(speechd-speak--command-feedback (yank yank-pop) after
  (speechd-speak-read-region))

(speechd-speak--command-feedback (kill-region completion-kill-region) around
  (let ((nlines (count-lines (region-beginning) (region-end))))
    ad-do-it
    (speechd-speak--maybe-speak
     (message "Killed region containing %s lines" nlines))))


;;; Messages


(defvar speechd-speak--last-message "")
(defvar speechd-speak--last-spoken-message "")

(defun speechd-speak-last-message ()
  (interactive)
  (speechd-speak--text speechd-speak--last-message))

(defun speechd-speak--current-message (&optional reset-last-spoken)
  (let ((message (current-message)))
    (when (and message
	       (not (string= message speechd-speak--last-spoken-message)))
      (setq speechd-speak--last-message message
	    speechd-speak--last-spoken-message message)
      (let ((speechd-speak--special-area t))
        (speechd-speak--text message :priority :progress))))
  (when reset-last-spoken
    (setq speechd-speak--last-spoken-message "")))

(speechd-speak--defadvice message after
  (speechd-speak--current-message))


;;; Minibuffer


(defun speechd-speak--prompt (prompt)
  (speechd-speak--text prompt :priority :message))

(defun speechd-speak--speak-minibuffer-prompt ()
  (speechd-speak--prompt (minibuffer-prompt))
  (speechd-speak--prompt (minibuffer-contents)))

(defun speechd-speak--minibuffer-setup-hook ()
  (speechd-speak--with-command-start-info
   (setf (speechd-speak--command-info-struct-minibuffer-contents info)
         (minibuffer-contents)))
  (speechd-speak--speak-minibuffer-prompt))

(defun speechd-speak--minibuffer-exit-hook ()
  (speechd-speak--with-command-start-info
   (setf (speechd-speak--command-info-struct-minibuffer-contents info)
         'unset)))

(defun speechd-speak--speak-minibuffer ()
  (speechd-speak--text (minibuffer-contents)))

(speechd-speak--command-feedback minibuffer-message after
  (speechd-speak--text (ad-get-arg 0) :priority :notification))

;; The following functions don't invoke `minibuffer-setup-hook'
(speechd-speak--defadvice y-or-n-p before
  (speechd-speak--text (concat (ad-get-arg 0) "(y or n)") :priority :message))
(speechd-speak--defadvice read-key-sequence before
  (let ((prompt (ad-get-arg 0)))
    (when prompt
      (speechd-speak--text prompt :priority :message))))


;;; Commands


(defun speechd-speak--add-command-text (info text)
  (unless (string= (first (speechd-speak--command-info-struct-changes info))
                   text)
    (push text (speechd-speak--command-info-struct-changes info))))

(defun speechd-speak--buffer-substring (beg end)
  (buffer-substring
   (if (and speechd-speak-align-buffer-insertions
            (not (eq this-command 'self-insert-command)))
       (save-excursion
         (goto-char beg)
         (when (and (looking-at "\\w")
                    (not (looking-at "\\<")))
           (backward-word 1))
         (point))
     beg)
   end))

(defun speechd-speak--minibuffer-update-report (info old new)
  (speechd-speak--add-command-text
   info
   (if (and (<= (length old) (length new))
            (string= old (substring new 0 (length old))))
       (speechd-speak--buffer-substring
        (+ (minibuffer-prompt-end) (length old))
        (point-max))
     new)))

(defun speechd-speak--minibuffer-update (beg end len)
  (speechd-speak--with-command-start-info
   (let ((old-content (speechd-speak--command-info-struct-minibuffer-contents
                       info))
         (new-content (minibuffer-contents)))
     (unless (or (eq old-content 'unset)
                 (string= old-content new-content))
       (setf (speechd-speak--command-info-struct-minibuffer-contents info)
             new-content)
       (speechd-speak--minibuffer-update-report
        info old-content new-content)))))

(defun speechd-speak--after-change-hook (beg end len)
  (unless speechd-speak-quiet
    (speechd-speak--with-command-start-info
      (when (and (eq (current-buffer)
                     (speechd-speak--command-info-struct-buffer info))
                 (not (= beg end)))
        (if (speechd-speak--in-minibuffer-p)
            (speechd-speak--minibuffer-update beg end len)
          (speechd-speak--add-command-text
           info
           (speechd-speak--buffer-substring beg end)))))))

(defun speechd-speak--pre-command-hook ()
  (speechd-speak--set-command-start-info)
  (unless speechd-speak-quiet
    ;; Some parameters of interactive commands don't set up the minibuffer, so
    ;; we have to speak the prompt in a special way.
    (let ((interactive (cadr (interactive-form this-command))))
      (save-match-data
        (when (and (stringp interactive)
                   (string-match "^[@*]*\\([eipPmnr]\n\\)*[ckK]\\(.+\\)"
                                 interactive))
          (speechd-speak--prompt (match-string 2 interactive))))))
  (add-hook 'pre-command-hook 'speechd-speak--pre-command-hook))

(defun speechd-speak--post-command-hook ()
  (unless speechd-speak-quiet
    ;; Messages should be handled by an after change function.  Unfortunately,
    ;; in Emacs 21 after change functions in the *Messages* buffer don't work
    ;; in many situations.  This is a property of the Emacs implementation, so
    ;; the mechanism can't be used.
    (speechd-speak--current-message t)
    (speechd-speak--with-command-start-info
      (macrolet ((getinfo (slot)
                    `(,(intern (concat "speechd-speak--command-info-struct-"
                                       (symbol-name slot)))
                      info)))
        (let* ((buffer-changed (not (eq (getinfo buffer) (current-buffer))))
               (buffer-modified (and (not buffer-changed)
                                     (/= (getinfo modified)
                                         (buffer-modified-tick))))
               (point-moved (and (not buffer-changed)
                                 (not (= (getinfo point) (point)))))
               (in-minibuffer (speechd-speak--in-minibuffer-p))
               (other-spoken nil))
          (flet ((other-window-change (buffers)
                   (let* ((other-window (next-window))
                          (other-buffer (and other-window
                                             (window-buffer other-window))))
                     (and other-window
                          (not in-minibuffer)
                          (member (buffer-name other-buffer) buffers)
                          (not (eq other-buffer (current-buffer)))
                          (or (not (eq other-window (getinfo other-window)))
                              (not (= (buffer-modified-tick other-buffer)
                                      (getinfo other-buffer-modified))))))))
            (cond
             ;; Speak commands that can't speak in a regular way
             ((memq this-command '(forward-char backward-char))
              (speechd-block (:priority speechd-default-char-priority)
               (cond
                ((looking-at "^")
                 (when speechd-speak-signal-beginning-of-line
                   (speechd-speak-report
                    speechd-speak--beginning-of-line-message))
                 (speechd-speak-read-char))
                ((and (looking-at "$")
                      speechd-speak-signal-end-of-line)
                 (speechd-speak-report
                  speechd-speak--end-of-line-message))
                (t
                 (speechd-speak-read-char)))))
             ;; Buffer switch
             (buffer-changed
              (if speechd-speak-buffer-name
                  (speechd-speak--text (buffer-name) :priority :message)
                (speechd-speak-read-line)))
             ;; Buffer modification
             (buffer-modified
              (when speechd-speak-buffer-insertions
                (let ((text (mapconcat #'identity
                                       (funcall (if (eq this-command
                                                        'self-insert-command)
                                                    #'butlast #'identity)
                                                (reverse (getinfo changes)))
                                       " ")))
                  (when (or (eq speechd-speak-buffer-insertions t)
                            (save-match-data (not (string-match "\n" text))))
                    (speechd-speak--text text))))
              (when (eq this-command 'self-insert-command)
                (speechd-speak-read-char (preceding-char))))
             ;; Special face hit
             ((and (not in-minibuffer)
                   point-moved
                   (assq (get-char-property (point) 'face)
                         speechd-speak-faces))
              (let ((action (cdr (assq (get-char-property (point) 'face)
                                       speechd-speak-faces))))
                (cond
                 ((stringp action)
                  (speechd-speak--text action))
                 ((functionp action)
                  (ignore-errors
                    (funcall action))))))
             ;; General text or overlay property hit
             ((and (not in-minibuffer)
                   (or (eq speechd-speak-by-properties-on-movement t)
                       (memq (get-char-property (point) 'face)
                             speechd-speak-by-properties-on-movement)
                       (memq this-command
                             speechd-speak-by-properties-always))
                   (not (memq this-command
                              speechd-speak-by-properties-never))
                   point-moved
                   (get-char-property (point) 'face)
                   (let ((position (getinfo point)))
                     (or (> (speechd-speak--previous-property-change
                             (point) position)
                            position)
                         (<= (speechd-speak--next-property-change
                              (point) (1+ position))
                             position))))
              (speechd-speak--uniform-text-around-point))
             ;; Boring movement
             (point-moved
              (speechd-speak-read-line (not speechd-speak-whole-line)))
             ;; Something interesting in other window
             ((other-window-change speechd-speak-auto-speak-buffers)
              (speechd-speak-read-buffer (window-buffer (next-window))))
             (t
              (setq other-spoken t)))
            ;; If other window buffer is very interesting, speak it too
            (when (and (not other-spoken)
                       (other-window-change
                        speechd-speak-force-auto-speak-buffers))
              (speechd-speak-read-buffer
               (window-buffer (next-window))))))))
    (add-hook 'post-command-hook 'speechd-speak--post-command-hook)))


;;; Comint


(speechd-speak--command-feedback comint-show-output after
  (speechd-speak-read-region))

(speechd-speak--defadvice comint-output-filter around
  ;; TODO:
  ad-do-it)


;;; Completions, menus, etc.


(defun speechd-speak--speak-completion ()
  ;; Taken from `choose-completion'
  (let (beg end completion (buffer completion-reference-buffer)
	(base-size completion-base-size))
    (if (and (not (eobp)) (get-text-property (point) 'mouse-face))
	(setq end (point) beg (1+ (point))))
    (if (and (not (bobp)) (get-text-property (1- (point)) 'mouse-face))
	(setq end (1- (point)) beg (point)))
    (if (null beg)
	(error "No completion here"))
    (setq beg (previous-single-property-change beg 'mouse-face))
    (setq end (or (next-single-property-change end 'mouse-face) (point-max)))
    (setq completion (buffer-substring beg end))
    (speechd-speak--text completion)
    (speechd-speak--reset-command-start-info)))

(speechd-speak--command-feedback (next-completion previous-completion) after
  (speechd-speak--speak-completion))

(speechd-speak--command-feedback choose-completion before
  (speechd-speak--speak-completion))

;; The `widget-choose' function is written in a non-extensible way.  So before
;; this is fixed, we have to use some dirty hacks.
(defconst speechd-speak--widget-choose-buffer-name " widget-choose")
(speechd-speak--defadvice scroll-other-window after
  (when (string= (buffer-name (window-buffer (next-window)))
		 speechd-speak--widget-choose-buffer-name)
    (speechd-speak-read-buffer speechd-speak--widget-choose-buffer-name)))


;;; Other functions and packages


(speechd-speak--command-feedback (isearch-search isearch-delete-char) after
  (speechd-speak--text isearch-string)
  (speechd-speak-read-line))

(speechd-speak--command-feedback (occur-prev occur-next
				  occur-mode-goto-occurence)
				 after
  (speechd-speak-read-line))

(speechd-speak--command-feedback transpose-chars after
  (speechd-speak--char (following-char)))

(speechd-speak--command-feedback transpose-lines after
  (speechd-speak-read-line))

(speechd-speak--command-feedback transpose-words after
  (speechd-speak-read-word))

(speechd-speak--command-feedback transpose-sexps after
  (speechd-speak-read-sexp))

(speechd-speak--command-feedback undefined after
  (speechd-speak--text "No command on this key"))

(speechd-speak--command-feedback indent-for-tab-command after
  (speechd-speak--speak-current-column))



;;; The startup and shutdown functions


(defun speechd-speak--shutdown ()
  (speechd-speak-toggle-quiet '(4) 0 t))

(defvar speechd-speak--started nil)
(defun speechd-speak ()
  "Start or restart speaking."
  (interactive)
  (speechd-reopen)
  (add-hook 'pre-command-hook 'speechd-speak--pre-command-hook)
  (add-hook 'post-command-hook 'speechd-speak--post-command-hook)
  (add-hook 'after-change-functions 'speechd-speak--after-change-hook)
  (add-hook 'minibuffer-setup-hook 'speechd-speak--minibuffer-setup-hook)
  (add-hook 'minibuffer-exit-hook 'speechd-speak--minibuffer-exit-hook)
  (add-hook 'kill-emacs-hook 'speechd-speak--shutdown)
  (speechd-speak-toggle-quiet nil 1)
  (run-hooks 'speechd-speak-startup-hook)
  (message "Speechd-speak %s"
	   (if speechd-speak--started "restarted" "started"))
  (setq speechd-speak--started t))


;;; Keymap


(defvar speechd-speak-keymap nil
  "Keymap used by speechd-speak.")

(define-prefix-command 'speechd-speak-prefix-command 'speechd-speak-keymap)
(global-set-key speechd-speak-prefix 'speechd-speak-prefix-command)

(define-key speechd-speak-keymap "e" 'end-of-line)
(define-key speechd-speak-keymap "\C-e" 'end-of-line)

(define-key speechd-speak-keymap "a" 'speechd-speak-last-message)
(define-key speechd-speak-keymap "b" 'speechd-speak-read-buffer)
(define-key speechd-speak-keymap "c" 'speechd-speak-read-char)
(define-key speechd-speak-keymap "l" 'speechd-speak-read-line)
(define-key speechd-speak-keymap "n" 'speechd-speak-read-rest-of-buffer)
(define-key speechd-speak-keymap "p" 'speechd-pause)
(define-key speechd-speak-keymap "q" 'speechd-speak-toggle-quiet)
(define-key speechd-speak-keymap "r" 'speechd-speak-read-region)
(define-key speechd-speak-keymap "s" 'speechd-stop)
(define-key speechd-speak-keymap "w" 'speechd-speak-read-word)
(define-key speechd-speak-keymap "{" 'speechd-speak-read-paragraph)
(define-key speechd-speak-keymap " " 'speechd-resume)
(define-key speechd-speak-keymap "'" 'speechd-speak-speak-sexp)
(define-key speechd-speak-keymap "[" 'speechd-speak-read-page)
(define-key speechd-speak-keymap "\C-n" 'speechd-speak-read-other-window)
(define-key speechd-speak-keymap "\C-s" 'speechd-reopen)
(define-key speechd-speak-keymap "\M-\C-k" 'kill-emacs)
(define-key speechd-speak-keymap [down] 'speechd-speak-read-next-line)
(define-key speechd-speak-keymap [up] 'speechd-speak-read-previous-line)
(dotimes (i 9)
  (define-key speechd-speak-keymap (format "%s" (1+ i))
              'speechd-speak-key-set-predefined-rate))


;;; Announce


(provide 'speechd-speak)


;;; speechd-speak.el ends here
