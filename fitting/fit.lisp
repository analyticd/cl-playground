(require 'asdf)
(require 'prove)
(require 'eazy-gnuplot)

(in-package :cl-user)
(defpackage fitting
  (:use :cl
        :prove
        :eazy-gnuplot))
(in-package :fitting)


(defun noise ()
  "Make normally distributed noise."
  (* (sqrt (* -2.0 (log (random 1.0))))
     (sin (* 2.0 pi (random 1.0)))))

(defun graph-from (f len)
  "Make a vector represents a graph from function and length."
  (let ((res (make-array len)))
    (dotimes (i len)
      (setf (aref res i)
            (funcall f)))
    res))

(defun power-series (x w)
  "Calc the power series represented with x and w;
   where w are coefficients."
  (loop for i from 0 below (length w)
        sum (* (aref w i) (expt x i))))

;; w is weight MxM matrix (2D-array)
;; y is values 1xM vector (1D-array)
(defun solve (w y)
  "Return the answer of simultaneous equations by Gaussian elimination
   a.k.a. row reduction."
  (let ((m (array-dimension w 1)))
    ;; forward elimination
    (loop for k from 0 below (1- m)
          do (loop for i from (1+ k) below m
                   for d = (/ (aref w i k) (aref w k k))
                   do (loop for j from (1+ k) below m
                            do (decf (aref w i j) (* (aref w k j) d)))
                   do (decf (aref y i) (* (aref y k) d))))
    ;; backward substitution
    (loop for i from (1- m) downto 0
          for d = (aref y i)
          do (loop for j from (1+ i) below m
                   do (decf d (* (aref w i j) (aref y j))))
             (setf (aref y i) (/ d (aref w i i))))
    y))

;; xv is observed values vector
;; yv is observed values vector corresponding to xv
;; m is order number
(defun curve-fit (xv yv m)
  "Return fitted curve's coefficients by Polynomial curve fitting."
  (let* ((n (length yv))
         (Aij (make-array `(,(1+ m) ,(1+ m))))
         (Ti (make-array (1+ m))))
    (loop for i from 0 below (1+ m)
          do (loop for j from 0 below (1+ m)
                   do (setf (aref Aij i j)
                            (loop for k from 0 below n
                                  sum (expt (aref xv k) (+ i j))))))
    (loop for i from 0 below (1+ m)
          do (setf (aref Ti i)
                   (loop for k from 0 below n
                         sum (* (expt (aref xv k) i) (aref yv k)))))
    (solve Aij Ti)))

(defun arange (x y z)
  (loop for i from x to y by z collect i))

(defun arangev (x y z)
  (let ((v (make-array 1 :element-type 'float
                         :adjustable t
                         :fill-pointer 0)))
    (loop for i from x to y by z
          do (vector-push-extend i v))
    v))

(defun main (N)
         ;; Sine curve
  (let* ((x-real (arange 0 1 0.01))
         (y-real (mapcar (lambda (x) (sin (* 2 pi x))) x-real))
         ;; Training data
         (x-train (arangev 0 1 (float (/ 1 N))))
         (y-train (map 'vector
                       (lambda (x) (+ (sin (* 2 pi x))
                                      (noise)))
                       x-train))
         ;; Results
         (wlist (loop for M across #(0 1 3 9)
                      collect (curve-fit x-train y-train M)))
         (y-estimates (loop for w in wlist
                            collect (loop for x in x-real
                                          collect (power-series x w)))))

    (with-plots (*standard-output* :debug t)
      (gp-setup :output #p"fitting.png"
                :terminal '(pngcairo background rgb "gray")
                :title (format nil "Polynomial curve fitting (N=~D)" N)
                :xlabel "x"
                :ylabel "y(x,w)"
                :key '(:bottom :right :font "Sans, 12")
                :pointsize "0.6px"
                :xrange :|[0:1]|
                :yrange :|[-2:2]|)
      (plot (lambda ()
              (loop for x in x-real
                    for y in y-real
                    do (format t "~&~F ~F" x y)))
            :using '(1 2)
            :title "sin2πx"
            :with '(:lines))
      (plot (lambda ()
              (loop for x across x-train
                    for y across y-train
                    do (format t "~&~F ~F" x y)))
            :using '(1 2)
            :title "Train"
            :with '(:points))
      (loop for M across #(0 1 3 9)
            for ylist in y-estimates
            do (plot (lambda ()
                       (loop for x in x-real
                             for y in ylist
                             do (format t "~&~F ~F" x y)))
                     :using '(1 2)
                     :title (format nil "M=~A" M)
                     :with '(:lines)
                     :linewidth 2)))))

(main 12)
