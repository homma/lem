(in-package :lem)

(defun convert-line (str reverse-p)
  (let ((acc)
        (comment-p))
    (do ((i 0 (1+ i)))
        ((<= (length str) i))
      (let ((c (aref str i)))
        (cond (comment-p
               (push 'space acc))
              ((syntax-space-char-p c)
               (push 'space acc))
              ((syntax-symbol-char-p c)
               (push 'symbol acc))
              ((syntax-open-paren-char-p c)
               (push (if reverse-p 
                       'closed-paren
                       'open-paren)
                     acc))
              ((syntax-closed-paren-char-p c)
               (push (if reverse-p
                       'open-paren
                       'closed-paren)
                     acc))
              ((syntax-string-quote-char-p c)
               (push 'string-quote acc))
              ((syntax-escape-char-p c)
               (push 'symbol acc)
               (push 'symbol acc)
               (incf i))
              ((syntax-expr-prefix-char-p c)
               (push 'expr-prefix acc))
              ((syntax-line-comment-char-p c)
               (push 'space acc)
               (setq comment-p t))
              (t
               (push 'symbol acc)))))
    (if reverse-p
      acc
      (nreverse acc))))

(defmacro do-scan (outer dir (type-var dir-var) &body body)
  (let ((gdir (gensym "DIR"))
        (gpoint (gensym "POINT"))
        (gstr (gensym "STR"))
        (glen (gensym "LEN"))
        (gline (gensym "LINE"))
        (gtype (gensym "TYPE")))
    `(let ((,gdir ,dir))
       (loop named ,outer
             for ,gpoint = (point)
             for ,gstr = (buffer-line-string 
                          (window-buffer)
                          (point-linum ,gpoint))
             for ,glen = (length ,gstr)
             for ,gline = (convert-line ,gstr (minusp ,gdir))
             do
             (dolist (,gtype (nthcdr (if (plusp ,gdir)
                                       (point-column ,gpoint)
                                       (- ,glen (point-column ,gpoint)))
                                     ,gline))
               (let ((,type-var ,gtype)
                     (,dir-var ,gdir))
                 ,@body)
               (unless (next-char ,gdir)
                 (return-from ,outer nil)))
             (unless (next-char ,gdir)
               (return-from ,outer nil))
             finally
             (return-from ,outer t)))))

(defun scan-lists (point count depth)
  (point-set point)
  (dotimes (_ (abs count) t)
    (unless
      (do-scan outer
               (if (plusp count) 1 -1)
               (x dir)
               (ecase x
                 ((open-paren closed-paren)
                  (if (eq x 'open-paren)
                    (incf depth)
                    (decf depth))
                  (cond ((zerop depth)
                         (next-char dir)
                         (when (minusp dir)
                           (do () 
                               ((not (syntax-expr-prefix-char-p
                                      (preceding-char))))
                             (prev-char)))
                         (return-from outer t))
                        ((minusp depth)
                         (return-from outer nil)))) 
                 (string-quote
                  (scan-string (point) dir))
                 ((symbol space expr-prefix)
                  nil)))
      (point-set point)
      (return nil))))

(macrolet ((def (name &body body)
                `(defun ,name (point dir)
                   (point-set point)
                   (if (do-scan outer
                                dir
                                (x dir)
                                ,@body)
                     t
                     (progn
                       (point-set point)
                       nil)))))
  (def scan-string
       (when (eq x 'string-quote)
         (return-from outer t)))
  (def scan-symbol
       (unless (or (eq x 'symbol)
                   (eq x 'expr-prefix))
         (when (and (plusp dir) (bolp))
           (prev-char))
         (return-from outer t))))

(defun scan-sexps (point count)
  (point-set point)
  (dotimes (_ (abs count) t)
    (unless 
      (do-scan outer
               (if (plusp count) 1 -1)
               (x dir)
               (ecase x
                 (open-paren
                  (return-from outer
                               (scan-lists (point) dir 0)))
                 (closed-paren
                  (return-from outer nil))
                 (string-quote
                  (next-char dir)
                  (return-from outer
                               (and (scan-string (point) dir)
                                    (next-char dir))))
                 (space
                  nil)
                 ((symbol)
                  (return-from outer
                               (scan-symbol (point) dir)))
                 ((expr-prefix))))
      (return nil))))
      
(define-key *global-keymap* "M-C-n" 'forward-list)
(define-command forward-list (&optional (n 1)) ("p")
  (scan-lists (point) n 0))

(define-key *global-keymap* "M-C-p" 'backward-list)
(define-command backward-list (&optional (n 1)) ("p")
  (scan-lists (point) (- n) 0))

(define-key *global-keymap* "M-C-f" 'forward-sexp)
(define-command forward-sexp (&optional (n 1)) ("p")
  (scan-sexps (point) n))

(define-key *global-keymap* "M-C-b" 'backward-sexp)
(define-command backward-sexp (&optional (n 1)) ("p")
  (scan-sexps (point) (- n)))

(define-key *global-keymap* "M-C-d" 'down-list)
(define-command down-list (&optional (n 1)) ("p")
  (scan-lists (point) n -1))

(define-key *global-keymap* "M-C-u" 'up-list)
(define-command up-list (&optional (n 1)) ("p")
  (scan-lists (point) (- n) 1))

(defun top-of-defun ()
  (do () ((not (up-list 1)) t)))

(define-key *global-keymap* "M-C-a" 'beginning-of-defun)
(define-command beginning-of-defun (&optional (n 1)) ("p")
  (if (minusp n)
    (end-of-defun (- n))
    (dotimes (_ n t)
      (if (up-list 1)
        (top-of-defun)
        (unless (backward-sexp 1)
          (return nil))))))

(define-key *global-keymap* "M-C-e" 'end-of-defun)
(define-command end-of-defun (&optional (n 1)) ("p")
  (if (minusp n)
    (beginning-of-defun (- n))
    (dotimes (_ n t)
      (top-of-defun)
      (unless (forward-sexp 1)
        (return nil)))))

(define-key *global-keymap* "M-C-@" 'mark-sexp)
(define-command mark-sexp () ()
  (let ((point (point)))
    (forward-sexp 1)
    (mark-set)
    (point-set point)))

(define-key *global-keymap* "M-C-k" 'kill-sexp)
(define-command kill-sexp (&optional (n 1)) ("p")
  (mark-sexp)
  (kill-region (region-beginning) (region-end)))

(define-key *global-keymap* "M-C-t" 'transpose-sexps)
(define-command transpose-sexps () ()
  (let ((point (point)))
    (or
     (block outer
       (let (left right)
         (unless (forward-sexp 1)
           (return-from outer nil))
         (unless (backward-sexp 2)
           (return-from outer nil))
         (kill-sexp 1)
         (setq *kill-new-flag* t)
         (delete-while-whitespaces nil t)
         (setq *kill-new-flag* t)
         (kill-sexp 1)
         (yank 1)
         (yank 2)
         (yank 3)
         (setq *kill-new-flag* t)
         t))
     (progn (point-set point)
       nil))))
