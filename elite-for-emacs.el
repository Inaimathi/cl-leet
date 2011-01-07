;;; elite-for-emacs.el - Elite for EMACS

(defconst elite-for-emacs-version "0.1"
  "Version number of Elite for EMACS")

;; TAB is used for command completion. Shift-right arrow browses all commands.
;; Shift-up arrow browses command history.
;;
;; Installation:
;;
;; Add directory elite-for-emacs-0.1 to your load path and add
;; (require 'elite-for-emacs)
;; to .emacs
;;
;; Start Elite for EMACS M-x elite-for-emacs

(require 'cl)

;;Load Elite for EMACS functions
(load "elite-for-emacs-commands")
(load "elite-for-emacs-functions")
(load "elite-for-emacs-commander")
(load "elite-for-emacs-engine")
(load "elite-for-emacs-bazaar")

(defvar elite-for-emacs-current-command nil)
(defvar elite-for-emacs-original-frame-title-format nil)
(defvar elite-for-emacs-command-history nil)
(defvar elite-for-emacs-command "")
(defvar elite-for-emacs-buffer-name "*Elite for EMACS*")
(defvar elite-for-emacs-buffer-name-offline "*Elite for EMACS*")

;;Functions for prompt, modeline title.
(defvar elite-for-emacs-prompt-function 'elite-for-emacs-prompt)
(defvar elite-for-emacs-mode-line-function 'elite-for-emacs-mode-line)
(defvar elite-for-emacs-frame-title-function 'ignore)
(defvar elite-for-emacs-custom-post-command-function 'elite-for-emacs-post-command)
(defvar elite-for-emacs-custom-pre-command-function 'elite-for-emacs-post-command)
(defvar elite-for-emacs-kill-buffer-function 'elite-for-emacs-kill-buffer)
(defvar elite-for-emacs-command-list nil)
(defvar elite-for-emacs-suppress-message t)
(defvar elite-for-emacs-suppress-default-newline-command nil)

(defvar elite-for-emacs-base-command-list
  (list (list "version" 'elite-for-emacs-version-info)
	(list "display-logo" 'elite-for-emacs-logo)
	(list "cls" 'elite-for-emacs-clear)
	(list "help" 'elite-for-emacs-help)
	(list "exit" 'elite-for-emacs-exit)
	(list "quit" 'elite-for-emacs-exit)
	(list "script" 'elite-for-emacs-script-execute)))

;;todo: save history variable
(add-hook 'kill-buffer-hook 'elite-for-emacs-kill-buffer-hook)

(defun elite-for-emacs ()
  "Elite for EMACS."
  (interactive)
  (let ((buffer))
    (if (get-buffer elite-for-emacs-buffer-name)
	(switch-to-buffer elite-for-emacs-buffer-name)
      (progn (random t)
	     (setq elite-for-emacs-command "")
	     (setq elite-for-emacs-tab-command nil)
	     (setq elite-for-emacs-tab-index 0)
	     
	     ;;buffer local variable, shell prompt
	     ;;enter: executes command, adds new line, inserts prompt
	     (setq buffer (get-buffer-create elite-for-emacs-buffer-name))
	     (switch-to-buffer buffer)
	     
	     (setq elite-for-emacs-command-loop-index 0)
	     (setq elite-for-emacs-history-index 0)

	     (insert (elite-for-emacs-set-prompt))
	     (local-set-key [tab] 'elite-for-emacs-tab)

	     (setq elite-for-emacs-original-frame-title-format frame-title-format)
	     (elite-for-emacs-set-mode-line)
	     (elite-for-emacs-frame-title)

	     ;;Set commands before game
	     (setq elite-for-emacs-command-list
		   (append (list (list "new" 'elite-for-emacs-new-commander)
				 (list "load" 'elite-for-emacs-load-commander))
			   elite-for-emacs-base-command-list))

	     ;;todo: save history in kill hook, load here
	     (setq elite-for-emacs-command-history (list))
	     ;;add handler to self-insert-command, post-command hook
	     (add-hook 'pre-command-hook 'elite-for-emacs-pre-command-hook nil t)
	     (add-hook 'post-command-hook 'elite-for-emacs-post-command-hook nil t)))))

(defvar elite-for-emacs-command-loop-index 0)
(defvar elite-for-emacs-history-index 0)

(defun elite-for-emacs-post-command-hook ()
  "Added to post-command-hook"
  (let ((cmd)
	(completion)
	(event)
	(modifiers)
	(command-list)
	(temp))
    ;;special functions: tab, enter, up, down, left, right
    (condition-case error
	(progn (setq event last-command-event)
	       (when (eq this-command 'self-insert-command)
		 (setq elite-for-emacs-command (concat elite-for-emacs-command (list event))))
	       
	       (when (and (eq this-command 'delete-backward-char) (> (length elite-for-emacs-command) 0))
		 (setq elite-for-emacs-command 
		       (substring elite-for-emacs-command 0 (- (length elite-for-emacs-command) 1))))
	       
	       (when (eq this-command 'forward-char)
		 (setq modifiers (event-modifiers last-input-event))
		 (when (eq (car modifiers) 'shift)
		   (goto-char (point-max))
		   (beginning-of-line)
		   (kill-line)
		   (insert (concat (elite-for-emacs-set-prompt)))
		   (setq cmd (car (nth elite-for-emacs-command-loop-index elite-for-emacs-command-list)))
		   (setq elite-for-emacs-command cmd)
		   (insert cmd)
		   (setq elite-for-emacs-command-loop-index (1+ elite-for-emacs-command-loop-index))
		   (when (= elite-for-emacs-command-loop-index (length elite-for-emacs-command-list))
		     (setq elite-for-emacs-command-loop-index 0))))
	       
	       (when (eq this-command 'backward-char)
		 (setq modifiers (event-modifiers last-input-event))
		 (when (eq (car modifiers) 'shift)
		   (goto-char (point-max))
		   (beginning-of-line)
		   (kill-line)
		   (insert (concat (elite-for-emacs-set-prompt)))
		   (setq cmd (car (nth elite-for-emacs-command-loop-index elite-for-emacs-command-list)))
		   (setq elite-for-emacs-command cmd)
		   (insert cmd)
		   (setq elite-for-emacs-command-loop-index (1- elite-for-emacs-command-loop-index))
		   (when (< elite-for-emacs-command-loop-index 0)
		     (setq elite-for-emacs-command-loop-index (1- (length elite-for-emacs-command-list))))))
      
	       (if (eq this-command 'previous-line)
		   (progn (setq modifiers (event-modifiers last-input-event))
			  (when (eq (car modifiers) 'shift)
			    (when (> (length elite-for-emacs-command-history) 0)
			      (goto-char (point-max))
			      (beginning-of-line)
			      (kill-line)
			      (insert (concat (elite-for-emacs-set-prompt)))
			      (setq cmd (nth elite-for-emacs-history-index 
					     (reverse elite-for-emacs-command-history)))
			      (setq elite-for-emacs-command cmd)
			      (insert cmd)
			      (setq elite-for-emacs-history-index (1+ elite-for-emacs-history-index))
			      (if (= elite-for-emacs-history-index (length elite-for-emacs-command-history))
				  (setq elite-for-emacs-history-index 0)))))
		 (progn ;;set history to 0 if not previous line command
		   (setq elite-for-emacs-history-index 0)))
	       
	       (if (eq this-command 'newline)
		   (progn
		     (if (< (point) (point-max))
			 (progn ;;for some reason pre-command-hook newline (goto-char (point-max))
			   ;;does not work if we are not at the end of buffer
			   (delete-backward-char 1)
			   (goto-char (point-max))
			   (insert "\n")))
		     (if (not elite-for-emacs-suppress-default-newline-command)
			 (progn
			   ;;todo (documentation 'forward-char)
			   
			   ;;get first match
			   (setq cmd (elite-for-emacs-get-first-command-match (car (split-string elite-for-emacs-command))))
			   (setq cmd (cadr (assoc cmd elite-for-emacs-command-list)))
			   
			   ;;act on command
			   (if (or (commandp cmd) (functionp cmd))
			       (progn (if (commandp cmd)
					  (command-execute cmd)
					(funcall cmd))
				      
				      (when (current-message)
					(insert (current-message))
					(when elite-for-emacs-suppress-message (message nil)))
				      
				      (when (not (eq cmd 'elite-for-emacs-clear))
					(insert "\n")))
			     (when (not (string= elite-for-emacs-command ""))
			       (insert "Bad command (" elite-for-emacs-command ").\n")))
			   
			   (when (and elite-for-emacs-command (not (string= elite-for-emacs-command "")))
			     (setq elite-for-emacs-command-history 
				   (append elite-for-emacs-command-history (list elite-for-emacs-command))))

			   (setq elite-for-emacs-command "")
			   (insert (concat (elite-for-emacs-set-prompt)))
			   
			   (setq elite-for-emacs-tab-index 0)
			   (setq elite-for-emacs-tab-ring nil)
			   (setq elite-for-emacs-tab-command nil)
			   
			   (elite-for-emacs-set-mode-line)
			   (elite-for-emacs-frame-title)))))
	       
	       (when (and elite-for-emacs-suppress-message (current-message))
		 (message nil))
	       
	       (when (functionp elite-for-emacs-custom-post-command-function)
		   (funcall elite-for-emacs-custom-post-command-function)))
      
      (error (insert (error-message-string error) "\n")
	     (setq elite-for-emacs-command "")
	     (insert (concat (elite-for-emacs-set-prompt)))
	     
	     (setq elite-for-emacs-tab-index 0)
	     (setq elite-for-emacs-tab-ring nil)
	     (setq elite-for-emacs-tab-command nil)
	     
	     (elite-for-emacs-set-mode-line)
	     (elite-for-emacs-frame-title)))))

(defun elite-for-emacs-get-first-command-match (cmd)
  ""
  (let ((command-list)
	(temp)
	(index)
	(command ""))
    (if cmd (progn (setq command-list elite-for-emacs-command-list)
		   (while command-list
		     (setq temp (caar command-list))
		     (setq index (string-match cmd temp))
		     (when (and index (= index 0))
			 (setq command-list nil)
			 (setq command temp))
		     (setq command-list (cdr command-list)))))
    command))

(defvar elite-for-emacs-tab-index 0)
(defvar elite-for-emacs-tab-command nil)
(defvar elite-for-emacs-tab-ring nil)

(defun elite-for-emacs-tab ()
  (interactive)
  (let ((completion)
	(cmd))
    (if elite-for-emacs-tab-command
	(setq completion (all-completions elite-for-emacs-tab-command elite-for-emacs-command-list))
      (progn
	(when (string= elite-for-emacs-command "")
	  (setq elite-for-emacs-tab-ring t))
	(if elite-for-emacs-tab-ring
	    (setq completion (all-completions "" elite-for-emacs-command-list))
	  (setq completion (all-completions elite-for-emacs-command elite-for-emacs-command-list)))))

    (when completion
      (if (and (not elite-for-emacs-tab-ring) (> (length completion) 1) (not elite-for-emacs-tab-command))
	  (progn (setq elite-for-emacs-tab-command elite-for-emacs-command)))
      
      (when (>= elite-for-emacs-tab-index (length completion))
	(setq elite-for-emacs-tab-index 0))
      
      (goto-char (point-max))
      (beginning-of-line)
      (kill-line)
      (insert (elite-for-emacs-set-prompt))
      (setq cmd (nth elite-for-emacs-tab-index completion))
      (setq elite-for-emacs-command cmd)
      (insert cmd)
      (setq elite-for-emacs-tab-index (1+ elite-for-emacs-tab-index)))))


(defun elite-for-emacs-pre-command-hook ()
  "Added to pre-command-hook"
  (let ((event last-command-event))
    (if (/= event 9);;TAB
  	(progn
	  (setq elite-for-emacs-tab-index 0)
	  (setq elite-for-emacs-tab-ring nil)
	  (setq elite-for-emacs-tab-command nil)))
    (when (eq this-command 'newline) (goto-char (point-max)))
    (when (functionp elite-for-emacs-custom-pre-command-function)
      (funcall elite-for-emacs-custom-pre-command-function))))

(defun elite-for-emacs-kill-buffer-hook ()
  (when (string= (buffer-name) elite-for-emacs-buffer-name)
    (remove-hook 'post-command-hook 'elite-for-emacs-post-command-hook t)
    (remove-hook 'pre-command-hook 'elite-for-emacs-pre-command-hook t)
    (setq frame-title-format elite-for-emacs-original-frame-title-format)
    (when (functionp elite-for-emacs-kill-buffer-function)
      (funcall elite-for-emacs-kill-buffer-function))))

(defun elite-for-emacs-set-prompt ()
  "Function returns prompt"
  (let ()
    (if (and (functionp elite-for-emacs-prompt-function) (not (string= (symbol-name elite-for-emacs-prompt-function) "ignore")))
	;;(if (functionp elite-for-emacs-prompt-function)
	(funcall elite-for-emacs-prompt-function)
      "")))

(defun elite-for-emacs-set-mode-line ()
  "Sets mode line for Simple Shell buffer"
  (let ()
    (when (and (functionp elite-for-emacs-mode-line-function) 
	     (not (string= (symbol-name elite-for-emacs-mode-line-function) "ignore")))
      (setq mode-line-format
	    (funcall elite-for-emacs-mode-line-function))
      (force-mode-line-update))))

(defun elite-for-emacs-frame-title ()
  "Sets frame title for Simple Shell buffer"
  (when (and (functionp elite-for-emacs-frame-title-function) 
	     (not (string= (symbol-name elite-for-emacs-frame-title-function) "ignore")))
    (setq frame-title-format (funcall elite-for-emacs-frame-title-function))))


(defun elite-for-emacs-default-frame-title () "Simple Shell Title")
(defun elite-for-emacs-default-mode-line () (list "---" 'elite-for-emacs-command "-%-"))
(defun elite-for-emacs-default-prompt () "SimpleShell>")
(defun elite-for-emacs-clear () (erase-buffer))
(defun elite-for-emacs-exit () (kill-buffer nil))

(defun elite-for-emacs-help ()
  "Help."
  (let ((temp))
    (setq temp (split-string elite-for-emacs-command))
    (insert  "Commands:\n" )
    (setq command-list elite-for-emacs-command-list)
    (while command-list
      (setq cmd (car command-list))
      (insert (car cmd))
      (if (>= (length (car cmd)) 16)
	  (insert  "\t")
	(progn (if (>= (length (car cmd)) 8)
		   (insert  "\t\t")
		 (progn (insert  "\t\t\t")))))	
      (setq temp (documentation (cadr cmd)))
      (if temp
	  (insert (documentation (cadr cmd)) "\n")
	(insert "\n"))
      (setq command-list (cdr command-list)))))

(defgroup elite-for-emacs nil
  "Elite for EMACS."
  :tag "Elite for EMACS"
  :prefix "elite-for-emacs-"
  :version "21.2.1"
  :group 'games)

(defcustom elite-for-emacs-save-confirmation-when-exit t
  "*If non-nil user is asked to save commander when killing Elite for EMACS buffer."
  :type 'boolean
  :group 'elite-for-emacs)

(provide 'elite-for-emacs)
