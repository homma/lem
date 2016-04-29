(in-package :lem)

(export '(*keymaps*
          keymap
          keymap-undef-hook
          keymap-parent
          keymap-table
          make-keymap
          *global-keymap*
          kbd-p
          define-key
          kbd-to-string
          kbd
          keymap-find-keybind
          search-keybind-all
          find-keybind
          insertion-key-p))

(defvar *keymaps* nil)

(defstruct (keymap (:constructor %make-keymap))
  undef-hook
  parent
  table)

(defun make-keymap (&optional undef-hook parent)
  (let ((keymap (%make-keymap
                 :undef-hook undef-hook
                 :parent parent
                 :table (make-hash-table :test 'equal))))
    (push keymap *keymaps*)
    keymap))

(defclass kbd ()
  ((list :initarg :list
         :reader kbd-list)))

(defvar *kbd-cache-table* (make-hash-table :test 'equal))

(defun make-kbd (list)
  (or (gethash list *kbd-cache-table*)
      (setf (gethash list *kbd-cache-table*)
            (make-instance 'kbd :list list))))

(defmethod print-object ((k kbd) stream)
  (format stream "(~A ~S)" 'kbd (kbd-to-string k)))

(defun kbd-p (x)
  (typep x 'kbd))

(defun define-key (keymap key fun)
  (let ((kbd (typecase key
               (list (apply #'kbd key))
               (string (kbd key))
               (t key))))
    (unless (and (kbd-p kbd)
                 (every #'characterp (kbd-list kbd)))
      (error "define-key: ~s is illegal key" key))
    (setf (gethash kbd (keymap-table keymap)) fun)))

(defun kbd-to-string (key)
  (format nil "~{~A~^~}"
          (loop for c- on (kbd-list key)
             for c = (first c-)
             collect (cond
                       ((ctrl-p c)
                        (format nil "C-~c"
                                (char-downcase
                                 (code-char
                                  (+ 64 (char-code c))))))
                       ((char= c escape) "M")
                       ((gethash c *key->symbol*))
                       (t (format nil "~A" c)))
             collect (cond ((not (cdr c-))"")
                           ((char= c escape) "-")
                           (t " ")))))

(defun kbd-string-1 (str)
  (if (and (>= (length str) 2)
           (eql (aref str 0) #\M)
           (eql (aref str 1) #\-))
      (cons escape (kbd-string-1 (subseq str 2)))
      (list (gethash str *string->key*))))

(defun kbd-string (str)
  (make-kbd
   (mapcan #'(lambda (str)
               (if (and (< 4 (length str))
                        (string= str "C-M-" :end1 4))
                   (kbd-string-1 (concatenate 'string
                                              "M-C-" (subseq str 4)))
                   (kbd-string-1 str)))
           (split-string str #\space))))

(defun kbd-keys (keys)
  (make-kbd keys))

(defun kbd (string-or-first-key &rest keys)
  (etypecase string-or-first-key
    (string
     (kbd-string string-or-first-key))
    (character
     (kbd-keys (cons string-or-first-key keys)))))

(defun keymap-find-keybind (keymap key)
  (let ((cmd (gethash key (keymap-table keymap))))
    (or cmd
        (let ((keymap (keymap-parent keymap)))
          (when keymap
            (keymap-find-keybind keymap key)))
        (keymap-undef-hook keymap))))

(defun search-keybind-all (name)
  (let ((name (intern (string-upcase name) :lem))
        (keys))
    (dolist (keymap *keymaps*)
      (maphash #'(lambda (key val)
                   (when (eq name val)
                     (push key keys)))
               (keymap-table keymap)))
    keys))

(defun key-undef-hook (keymap key)
  (when (keymap-undef-hook keymap)
    (funcall (keymap-undef-hook keymap) key)))

(defun insertion-key-p (key)
  (let ((first-key (car (kbd-list key))))
    (when (or (< 31 (char-code first-key))
              (char= C-i first-key))
      first-key)))

(defvar *global-keymap* (make-keymap 'self-insert))

(define-command undefined-key () ()
  (editor-error "Key not found: ~A"
                (kbd-to-string (last-read-key-sequence))))

(define-key *global-keymap* "C-@" 'undefined-key)
(define-key *global-keymap* "C-a" 'undefined-key)
(define-key *global-keymap* "C-b" 'undefined-key)
(define-key *global-keymap* "C-c" 'undefined-key)
(define-key *global-keymap* "C-d" 'undefined-key)
(define-key *global-keymap* "C-e" 'undefined-key)
(define-key *global-keymap* "C-f" 'undefined-key)
(define-key *global-keymap* "C-g" 'undefined-key)
(define-key *global-keymap* "C-h" 'undefined-key)
(define-key *global-keymap* "C-i" 'undefined-key)
(define-key *global-keymap* "C-j" 'undefined-key)
(define-key *global-keymap* "C-k" 'undefined-key)
(define-key *global-keymap* "C-l" 'undefined-key)
(define-key *global-keymap* "C-m" 'undefined-key)
(define-key *global-keymap* "C-n" 'undefined-key)
(define-key *global-keymap* "C-o" 'undefined-key)
(define-key *global-keymap* "C-p" 'undefined-key)
(define-key *global-keymap* "C-q" 'undefined-key)
(define-key *global-keymap* "C-r" 'undefined-key)
(define-key *global-keymap* "C-s" 'undefined-key)
(define-key *global-keymap* "C-t" 'undefined-key)
(define-key *global-keymap* "C-u" 'undefined-key)
(define-key *global-keymap* "C-v" 'undefined-key)
(define-key *global-keymap* "C-w" 'undefined-key)
(define-key *global-keymap* "C-x" 'undefined-key)
(define-key *global-keymap* "C-y" 'undefined-key)
(define-key *global-keymap* "C-z" 'undefined-key)
(define-key *global-keymap* "escape" 'undefined-key)
(define-key *global-keymap* "C-\\" 'undefined-key)
(define-key *global-keymap* "C-]" 'undefined-key)
(define-key *global-keymap* "C-^" 'undefined-key)
(define-key *global-keymap* "C-_" 'undefined-key)
;(define-key *global-keymap* "Spc" 'undefined-key)
(define-key *global-keymap* "[del]" 'undefined-key)
(define-key *global-keymap* "[down]" 'undefined-key)
(define-key *global-keymap* "[up]" 'undefined-key)
(define-key *global-keymap* "[left]" 'undefined-key)
(define-key *global-keymap* "[right]" 'undefined-key)
(define-key *global-keymap* "C-down" 'undefined-key)
(define-key *global-keymap* "C-up" 'undefined-key)
(define-key *global-keymap* "C-left" 'undefined-key)
(define-key *global-keymap* "C-right" 'undefined-key)
(define-key *global-keymap* "[home]" 'undefined-key)
(define-key *global-keymap* "[backspace]" 'undefined-key)
(define-key *global-keymap* "[f0]" 'undefined-key)
(define-key *global-keymap* "[f1]" 'undefined-key)
(define-key *global-keymap* "[f2]" 'undefined-key)
(define-key *global-keymap* "[f3]" 'undefined-key)
(define-key *global-keymap* "[f4]" 'undefined-key)
(define-key *global-keymap* "[f5]" 'undefined-key)
(define-key *global-keymap* "[f6]" 'undefined-key)
(define-key *global-keymap* "[f7]" 'undefined-key)
(define-key *global-keymap* "[f8]" 'undefined-key)
(define-key *global-keymap* "[f9]" 'undefined-key)
(define-key *global-keymap* "[f10]" 'undefined-key)
(define-key *global-keymap* "[f11]" 'undefined-key)
(define-key *global-keymap* "[f12]" 'undefined-key)
(define-key *global-keymap* "[dl]" 'undefined-key)
(define-key *global-keymap* "[il]" 'undefined-key)
(define-key *global-keymap* "[dc]" 'undefined-key)
(define-key *global-keymap* "C-dc" 'undefined-key)
(define-key *global-keymap* "[ic]" 'undefined-key)
(define-key *global-keymap* "[eic]" 'undefined-key)
(define-key *global-keymap* "[clear]" 'undefined-key)
(define-key *global-keymap* "[eos]" 'undefined-key)
(define-key *global-keymap* "[eol]" 'undefined-key)
(define-key *global-keymap* "[sf]" 'undefined-key)
(define-key *global-keymap* "[sr]" 'undefined-key)
(define-key *global-keymap* "[npage]" 'undefined-key)
(define-key *global-keymap* "[ppage]" 'undefined-key)
(define-key *global-keymap* "[stab]" 'undefined-key)
(define-key *global-keymap* "[ctab]" 'undefined-key)
(define-key *global-keymap* "[catab]" 'undefined-key)
(define-key *global-keymap* "[enter]" 'undefined-key)
(define-key *global-keymap* "[print]" 'undefined-key)
(define-key *global-keymap* "[ll]" 'undefined-key)
(define-key *global-keymap* "[a1]" 'undefined-key)
(define-key *global-keymap* "[a3]" 'undefined-key)
(define-key *global-keymap* "[b2]" 'undefined-key)
(define-key *global-keymap* "[c1]" 'undefined-key)
(define-key *global-keymap* "[c3]" 'undefined-key)
(define-key *global-keymap* "[btab]" 'undefined-key)
(define-key *global-keymap* "[beg]" 'undefined-key)
(define-key *global-keymap* "[cancel]" 'undefined-key)
(define-key *global-keymap* "[close]" 'undefined-key)
(define-key *global-keymap* "[command]" 'undefined-key)
(define-key *global-keymap* "[copy]" 'undefined-key)
(define-key *global-keymap* "[create]" 'undefined-key)
(define-key *global-keymap* "[end]" 'undefined-key)
(define-key *global-keymap* "[exit]" 'undefined-key)
(define-key *global-keymap* "[find]" 'undefined-key)
(define-key *global-keymap* "[help]" 'undefined-key)
(define-key *global-keymap* "[mark]" 'undefined-key)
(define-key *global-keymap* "[message]" 'undefined-key)
(define-key *global-keymap* "[move]" 'undefined-key)
(define-key *global-keymap* "[next]" 'undefined-key)
(define-key *global-keymap* "[open]" 'undefined-key)
(define-key *global-keymap* "[options]" 'undefined-key)
(define-key *global-keymap* "[previous]" 'undefined-key)
(define-key *global-keymap* "[redo]" 'undefined-key)
(define-key *global-keymap* "[reference]" 'undefined-key)
(define-key *global-keymap* "[refresh]" 'undefined-key)
(define-key *global-keymap* "[replace]" 'undefined-key)
(define-key *global-keymap* "[restart]" 'undefined-key)
(define-key *global-keymap* "[resume]" 'undefined-key)
(define-key *global-keymap* "[save]" 'undefined-key)
(define-key *global-keymap* "[sbeg]" 'undefined-key)
(define-key *global-keymap* "[scancel]" 'undefined-key)
(define-key *global-keymap* "[scommand]" 'undefined-key)
(define-key *global-keymap* "[scopy]" 'undefined-key)
(define-key *global-keymap* "[screate]" 'undefined-key)
(define-key *global-keymap* "[sdc]" 'undefined-key)
(define-key *global-keymap* "[sdl]" 'undefined-key)
(define-key *global-keymap* "[select]" 'undefined-key)
(define-key *global-keymap* "[send]" 'undefined-key)
(define-key *global-keymap* "[seol]" 'undefined-key)
(define-key *global-keymap* "[sexit]" 'undefined-key)
(define-key *global-keymap* "[sfind]" 'undefined-key)
(define-key *global-keymap* "[shelp]" 'undefined-key)
(define-key *global-keymap* "[shome]" 'undefined-key)
(define-key *global-keymap* "[sic]" 'undefined-key)
(define-key *global-keymap* "[sleft]" 'undefined-key)
(define-key *global-keymap* "[smessage]" 'undefined-key)
(define-key *global-keymap* "[smove]" 'undefined-key)
(define-key *global-keymap* "[snext]" 'undefined-key)
(define-key *global-keymap* "[soptions]" 'undefined-key)
(define-key *global-keymap* "[sprevious]" 'undefined-key)
(define-key *global-keymap* "[sprint]" 'undefined-key)
(define-key *global-keymap* "[sredo]" 'undefined-key)
(define-key *global-keymap* "[sreplace]" 'undefined-key)
(define-key *global-keymap* "[sright]" 'undefined-key)
(define-key *global-keymap* "[srsume]" 'undefined-key)
(define-key *global-keymap* "[ssave]" 'undefined-key)
(define-key *global-keymap* "[ssuspend]" 'undefined-key)
(define-key *global-keymap* "[sundo]" 'undefined-key)
(define-key *global-keymap* "[suspend]" 'undefined-key)
(define-key *global-keymap* "[undo]" 'undefined-key)
(define-key *global-keymap* "[mouse]" 'undefined-key)
(define-key *global-keymap* "[resize]" 'undefined-key)
(define-key *global-keymap* "[event]" 'undefined-key)

(defun find-keybind (key)
  (let ((cmd (or (some #'(lambda (mode)
                           (keymap-find-keybind (mode-keymap mode) key))
                       (buffer-minor-modes))
                 (keymap-find-keybind (mode-keymap (buffer-major-mode)) key)
                 (keymap-find-keybind *global-keymap* key))))
    (function-to-command cmd)))
