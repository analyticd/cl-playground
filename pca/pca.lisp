;
; PCA

(require :dexador)

(defparameter +data-cache-path+
  (merge-pathnames "iris.data" (truename "./")))

(defparameter +output-path+
  (merge-pathnames "reducted.data" (truename "./")))

(defconstant +iris-data-url+
  "https://archive.ics.uci.edu/ml/machine-learning-databases/iris/iris.data")

(setf *read-default-float-format* 'double-float)

(defmacro mref (mat row col)
  `(aref (aref ,mat ,row) ,col))
(assert (let ((mat #(#(1 2)
                     #(3 4))))
          (= (mref mat 1 1) 4)))

(defun split (str delim)
  (let ((res (make-array 1 :element-type 'string
                           :fill-pointer 0
                           :adjustable t)))
    (loop for i from 0 below (length str)
          with start = 0
          when (eq (char str i) delim)
          do (vector-push-extend (subseq str start i) res)
             (setf start (1+ i))
          finally (let ((tail (subseq str start)))
                    (when tail
                      (vector-push-extend tail res))))
    res))


(defun dataload (url)
  (if (not (probe-file +data-cache-path+))
      (with-open-file (out +data-cache-path+ :direction :output :if-exists :supersede)
        (format out "~A" (dex:get url))))
  (with-open-file (in +data-cache-path+ :direction :input)
    (coerce
      (loop for line = (read-line in nil)
            while (and line (<= 4 (length line)))
            collect (map 'vector
                         (lambda (x)
                           (with-input-from-string
                             (in x)
                             (read in)))
                         (subseq (split line #\,) 0 4)))
      'vector)))

(defun mean (vec)
  (let ((len (length vec)))
    (/ (loop for x across vec sum x) len)))
(assert (= 3 (mean #(1 2 3 4 5))))

(defun mmean (data)
  (let* ((rows (length data))
         (cols (length (aref data 0)))
         (sum (make-array cols)))
    (loop for row across data
          do (loop for i from 0 below cols
                   do (incf (aref sum i) (aref row i))))
    (loop for i from 0 below cols
          do (setf (aref sum i) (float (/ (aref sum i) rows))))
    sum))
(assert (equalp #(5.0 3.0) (mmean #(#(1 3)
                                    #(6 4)
                                    #(8 2)))))

(defun make-unit-matrix (w h)
  (let ((mat (make-array h)))
    (loop for y from 0 below h
          do (setf (aref mat y)
                   (make-array w)))
    (loop for y from 0 below h
          do (loop for x from 0 below w
                   when (= x y)
                   do (setf (mref mat y x) 1.0)))
    mat))
(assert (equalp #(#(1.0 0.0 0.0 0.0)
                  #(0.0 1.0 0.0 0.0)
                  #(0.0 0.0 1.0 0.0))
                (make-unit-matrix 4 3)))

(defun non-diagonal-max-position (mat)
  (let ((w (length (aref mat 0)))
        (h (length mat))
        (p 0) (q 1)
        (m (aref (aref mat 1) 0)))
    (loop for i from 0 below h
          for row = (aref mat i)
          do (loop for j from (1+ i) below w
                   for v = (abs (aref row j))
                   when (< m v)
                   do (setf m v
                            p i
                            q j)))
    (values m q p)))
(assert (multiple-value-bind (m p q)
          (non-diagonal-max-position #(#(9 2 3)
                                       #(2 9 8)
                                       #(3 8 9)))
          (and (= m 8) (= p 2) (= q 1))))

(defun eigen (mat eps)
  (let* ((w (length (aref mat 0)))
         (h (length mat))
         (eig (make-unit-matrix w h)))
    (loop for (m p q) = (multiple-value-list (non-diagonal-max-position mat))
          for app = (mref mat p p)
          for apq = (mref mat p q)
          for aqq = (mref mat q q)
          for alpha = (/ (- app aqq) 2.0)
          for beta = (- apq)
          for gamma = (/ (abs alpha) (sqrt (+ (* alpha alpha) (* beta beta))))
          for s = (let ((s (sqrt (/ (- 1 gamma) 2.0))))
                    (if (>= (* alpha beta) 0.0)
                      s
                      (- s)))
          for c = (sqrt (/ (1+ gamma) 2.0))
          while (<= eps m)
          do (loop for i from 0 below h
                   for v = (- (* c (mref mat p i))
                              (* s (mref mat q i)))
                   do (setf (mref mat q i)
                            (+ (* s (mref mat p i))
                               (* c (mref mat q i)))
                            (mref mat p i)
                            v))
          do (loop for i from 0 below h
                   do (setf (mref mat i p)
                            (mref mat p i)
                            (mref mat i q)
                            (mref mat q i)))
          do (setf (mref mat p p)
                   (- (+ (* c c app) (* s s aqq)) (* 2.0 s c apq))
                   (mref mat p q)
                   (+ (* s c (- app aqq)) (* apq (- (* c c) (* s s))))
                   (mref mat q p)
                   (mref mat p q)
                   (mref mat q q)
                   (+ (* s s app) (* c c aqq) (* 2.0 s c apq)))
          do (loop for i from 0 below h
                   for v = (- (* c (mref eig i p)) (* s (mref eig i q)))
                   do (setf (mref eig i q)
                            (+ (* s (mref eig i p)) (* c (mref eig i q)))
                            (mref eig i p)
                            v)))
    (let ((vec (make-array h)))
      (loop for i from 0 below h
            do (setf (aref vec i) (mref mat i i)))
      (values vec eig))))

(defun transpose (mat)
  (if (typep (aref mat 0) 'vector)
    (let* ((w (length (aref mat 0)))
           (h (length mat))
           (new (make-array w)))
      (loop for y from 0 below w
            do (setf (aref new y) (make-array h))
            do (loop for x from 0 below h
                     for mv = (mref mat x y)
                     do (setf (aref (aref new y) x) mv)))
      new)
    (let* ((h (length mat))
           (new (make-array h)))
      (loop for y from 0 below h
            do (setf (aref new y)
                     (make-array 1 :initial-element (aref mat y))))
      new)))
(assert (equalp #(#(1 2 3)
                  #(4 5 6)
                  #(7 8 9))
                (transpose #(#(1 4 7)
                             #(2 5 8)
                             #(3 6 9)))))
(assert (equalp #(#(1)
                  #(2)
                  #(3))
                (transpose #(1 2 3))))

(defun dot (mat1 mat2)
  (assert (= (length (aref mat1 0))
             (length mat2)))
  (let* ((rows (length mat1))
         (cols (length (aref mat2 0)))
         (result (make-array rows)))
    (dotimes (row rows)
      (setf (aref result row) (make-array cols :initial-element 0))
      (dotimes (col cols)
        (dotimes (k (length (aref mat1 0)))
          (setf (mref result row col)
                (+ (mref result row col)
                   (* (mref mat1 row k) (mref mat2 k col)))))))
    result))
(assert (equalp #(#(35 44)
                  #(44 56))
                (dot #(#(1 3 5)
                       #(2 4 6))
                     #(#(1 2)
                       #(3 4)
                       #(5 6)))))

(defmethod m/ ((numer vector) (denom vector))
  (let* ((w (length (aref numer 0)))
         (h (length numer))
         (result (make-array h)))
    (loop for y from 0 below h
          do (setf (aref result y) (copy-seq (aref numer y))))
    (if (or (and (= 1 (length denom))
                 (typep (aref denom 0) 'vector))
            (and (= w (length denom))
                 (typep (aref denom 0) 'number)))
      (if (typep (aref denom 0) 'vector)
          (loop for y from 0 below h
                do (loop for x from 0 below w
                         do (setf (mref result y x)
                                  (/ (mref numer y x)
                                     (mref denom 0 x)))))
          (loop for y from 0 below h
                do (loop for x from 0 below w
                         do (setf (mref result y x)
                                  (/ (mref numer y x)
                                     (aref denom x))))))
      (loop for y from 0 below h
            do (loop for x from 0 below w
                     do (setf (mref result y x)
                              (/ (mref numer y x)
                                 (mref denom y x))))))
    result))
(assert (equalp #(#(1 2)
                  #(3 4))
                (m/ #(#(10 40)
                      #(30 80))
                    #(10 20))))
(assert (equalp #(#(1 2)
                  #(3 4))
                (m/ #(#(5 12)
                      #(21 32))
                    #(#(5 6)
                      #(7 8)))))
(assert (equalp #(#(1 2)
                  #(3 4))
                (m/ #(#(10 40)
                      #(30 80))
                    #(#(10 20)))))

(defmethod m/ ((numer vector) (denom number))
  (let* ((w (length (aref numer 0)))
         (h (length numer))
         (result (make-array h)))
    (loop for y from 0 below h
          do (setf (aref result y) (copy-seq (aref numer y))))
    (loop for y from 0 below h
          for row = (aref result y)
          do (loop for x from 0 below w
                   do (setf (aref row x) (/ (aref row x) denom))))
    result))
(assert (equalp #(#(1 2 3)
                  #(4 5 6))
                (m/ #(#(10 20 30)
                      #(40 50 60))
                    10)))

(defun msortv (mat order)
  (let* ((rows (length mat))
         (cols (length order))
         (res (make-array rows)))
    (loop for row from 0 below rows
          for mrow = (aref mat row)
          for v = (make-array cols)
          do (loop for i from 0 below cols
                   do (setf (aref v i) (aref mrow (elt order i))
                            (aref res row) v)))
    res))
(assert (equalp #(#(1 2 3)
                  #(4 5 6))
                (msortv #(#(2 3 1)
                          #(5 6 4))
                        '(2 0 1))))

(defun argsort (vec &optional (pred #'>))
  (let ((tmp (copy-seq vec))
        (sorted (sort (copy-seq vec) pred))
        (arg (make-array (length vec))))
    (loop for i from 0 below (length vec)
          for pos = (position (aref sorted i) tmp)
          do (setf (aref arg i) pos
                   (aref tmp pos) nil))
    arg))
(assert (equalp #(2 0 4 1 3)
                (argsort #(42 9 64 2 30))))

(defun copy-mat (mat)
  (let* ((rows (length mat))
         (cols (length (aref mat 0)))
         (new (make-array rows)))
    (loop for row from 0 below rows
          for mrow = (aref mat row)
          for v = (copy-seq (aref mat row))
          do (loop for col from 0 below cols
                   do (setf (aref v col) (aref mrow col)))
          do (setf (aref new row) v))
    new))
(assert (let* ((origin #(#(1 2 3)
                         #(4 5 6)))
               (copied (copy-mat origin)))
          (setf (aref (aref copied 0) 0) 0)
          (not (equalp origin copied))))

(defun m- (mat vec)
  (let* ((rows (length mat))
        (cols (length (aref mat 0)))
        (new (copy-mat mat)))
    (loop for row from 0 below rows
          do (loop for col from 0 below cols
                   do (decf (mref new row col)
                            (aref vec col))))
    new))
(assert (equalp #(#(1 2 3)
                  #(4 5 6))
                (m- #(#(5 7 9)
                      #(8 10 12))
                    #(4 5 6))))

(defun a- (arr v)
  (let ((len (length arr))
        (new (copy-seq arr)))
    (loop for i from 0 below len
          do (decf (aref new i) v))
    new))
(assert (equalp #(1 2 3)
                (a- #(2 3 4) 1)))

(defun mslicev (mat start end)
  (let* ((rows (length mat))
         (new (make-array rows)))
    (loop for row from 0 below rows
          for mrow = (aref mat row)
          do (setf (aref new row)
                   (subseq mrow start end)))
    new))
(assert (equalp #(#(2 3)
                  #(5 6))
                (mslicev #(#(1 2 3)
                           #(4 5 6))
                         1 3)))

(defun take (arr len)
  (let ((new (make-array len)))
    (loop for i from 0 below len
          do (setf (aref new i) (aref arr i)))
    new))
(assert (equalp #(1 2 3)
                (take #(1 2 3 4 5 6) 3)))

;(defun pca (dim, data)
;  (let* ((m (mean data))
;         (data ()))))

(defvar data (dataload +iris-data-url+))
(print data)
(let* ((x-bar (transpose
                (concatenate 'vector
                             (loop for row across (transpose data)
                                   collect (a- row (mean row))))))
       (cov (m/ (dot (transpose x-bar) x-bar) (length data)))
       (e nil)
       (ev nil))
  (multiple-value-setq (e ev)
    (eigen cov 0.0001))
  (format t "Eigen Value:~%~A~%" e)
  (format t "Eigen Vectors:~%~A~%" ev)
  (let* ((axis (msortv (transpose ev) (argsort e)))
         (components (take axis 2))
         (after (dot x-bar (transpose components)))
         (rows (length after)))
    (format t "Feature reducted:~%~A~%" after)
    (with-open-file (out +output-path+ :direction :output :if-exists :supersede)
      (loop for row from 0 below rows
            for mrow = (aref after row)
            do (format out "~A~A~A~%" (aref mrow 0) #\Tab (aref mrow 1))))
  ))
