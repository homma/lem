(in-package :lem)

(export '(last-read-key-sequence
          start-record-key
          stop-record-key
          key-recording-p
          read-key
          unread-key
          read-key-sequence
          unread-key-sequence
          execute-key-sequence
          sit-for))

(defvar *last-read-key-sequence*)

(defvar *key-recording-p* nil)
(defvar *temp-macro-chars* nil)

(defvar *unread-keys* nil)

(defvar *key-recording-status-name* (make-symbol "Def"))

(defun last-read-key-sequence ()
  (if (kbd-p *last-read-key-sequence*)
      *last-read-key-sequence*
      (setf *last-read-key-sequence* (make-kbd *last-read-key-sequence*))))

(defun set-last-read-key-sequence (key-sequence)
  (setf *last-read-key-sequence* key-sequence))

(defun start-record-key ()
  (modeline-add-status-list *key-recording-status-name*)
  (setq *key-recording-p* t)
  (setq *temp-macro-chars* nil))

(defun stop-record-key ()
  (modeline-remove-status-list *key-recording-status-name*)
  (setq *key-recording-p* nil)
  (nreverse *temp-macro-chars*))

(defun key-recording-p ()
  *key-recording-p*)

(defun read-key-1 ()
  (loop
    (let ((ms (shortest-wait-timers)))
      (if (null ms)
          (loop :for obj := (read-event nil)
                :do (when (characterp obj)
                      (return-from read-key-1 obj)))
          (if (minusp ms)
              (update-timer)
              (let ((e (read-event (float (/ ms 1000)))))
                (if (characterp e)
                    (return e)
                    (update-timer))))))))

(defun read-key ()
  (let ((char (if (null *unread-keys*)
                  (read-key-1)
                  (pop *unread-keys*))))
    (when *key-recording-p*
      (push char *temp-macro-chars*))
    char))

(defun unread-key (char)
  (when *key-recording-p*
    (pop *temp-macro-chars*))
  (push char *unread-keys*))

(defun read-key-sequence ()
  (read-key-command)
  (last-read-key-sequence))

(defun unread-key-sequence (key)
  (setf *unread-keys*
        (nconc *unread-keys*
               (if (listp key) key (kbd-list key)) ;!!!
               )))

(defun execute-key-sequence (key-sequence)
  (let ((prev-unread-keys-length (length *unread-keys*))
        (prev-unread-keys (copy-list *unread-keys*)))
    (unread-key-sequence key-sequence)
    (block nil
      (do-commandloop ()
        (when (>= prev-unread-keys-length
                  (length *unread-keys*))
          (return t))
        (handler-case (let ((*interactive-p* nil))
                        (funcall (find-keybind (read-key-sequence)) nil))
          (editor-condition ()
	    (setf *unread-keys* prev-unread-keys)
	    (return nil)))))))

(defun sit-for (seconds &optional (update-window-p t))
  (when update-window-p (redraw-display))
  (let ((e (read-event seconds)))
    (cond ((null e) t)
          ((eql e C-g) (error 'editor-abort))
          ((characterp e) (unread-key e))
          (t nil))))