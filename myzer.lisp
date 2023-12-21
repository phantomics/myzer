;;;; myzer.lisp

(in-package #:myzer)

#+(not clasp) (defparameter *workers-count* (max 1 (1- (serapeum:count-cpus :default 2))))
#+clasp (defparameter *workers-count* (max 1 (1- (ext:num-logical-processors))))

;; redefine portaudio's bitfield so that sound data is read as a vector of 8-bit integers
(portaudio::defbitfield (portaudio::sample-format :unsigned-long)
  (:float #x0001)
  :int8)

(let* ((frames (expt 2 5)) ;; 32
       (reduced 4)
       (monitoring)
       ;; (ochannels (make-array frames :element-type '(signed-byte 32)))
       (ochannels (make-array frames :element-type 'number))
       (myzer-lpchannel)
       (offt (make-array frames :element-type '(complex double-float)))
       (magnitudes (make-array (/ frames 2) :element-type 'fixnum :initial-element 0))
       (reduced-out (make-array reduced :element-type 'number)))

  (defun make-threading-kernel-if-absent ()
    "Create a kernel for multithreaded executuion via lparallel if none is present."
    (unless lparallel:*kernel*
      (setf lparallel:*kernel* (lparallel:make-kernel *workers-count* :name "myzer-parallel-kernel")))
    (unless myzer-lpchannel (setf myzer-lpchannel (lparallel::make-channel))))

  (defun audio-monitor-start ()
    (setf monitoring t)
    (make-threading-kernel-if-absent)
    (handler-case (lparallel:submit-task
                   myzer-lpchannel
                   (lambda ()
                     (with-audio (with-default-audio-stream (astream 1 0 :sample-format :int8 :sample-rate 48000d0
							                 :frames-per-buffer frames)
		                   (loop :while monitoring
			                 :do (let ((stream-out (read-stream astream)))
			                       ;; stream contents must be copied to array; the raw content cannot be
			                       ;; digested properly by other functions
			                       (loop :for i :below frames :do (setf (aref ochannels i)
                                                                                    (aref stream-out i)))))))))
      (error (err) (setf monitoring nil) err)))

  (defun audio-monitor-activep ()
    monitoring)

  (defun get-channels ()
    ochannels)

  (defun get-amp ()
    (pfft::pfft ochannels offt)
    offt)

  (defun get-amp2 ()
    (pfft::pfft ochannels offt)
    (loop :for i :below (length magnitudes) :do
      (setf (aref magnitudes i) (floor (sqrt (+ (expt (realpart (aref offt i)) 2)
						(expt (imagpart (aref offt i)) 2))))))
    magnitudes)
  
  (defun audio-monitor-stop ()
    (setf monitoring nil))

  (let ((interval-size (/ (length magnitudes) reduced)))
    (defun reduce-frequencies-avg ()
      (get-amp2)
      (loop :for ix :below reduced :do
	(let ((total 0) (offset (* interval-size ix)))
          (loop :for ox :below interval-size :do (incf total (aref magnitudes (+ ox offset))))
	  (setf (aref reduced-out ix) (floor (/ total interval-size)))))
      reduced-out))

  (let ((interval-size (/ (length magnitudes) reduced)))
    (defun reduce-frequencies-max ()
      (get-amp2)
      (loop :for ix :below reduced :do
	(let ((max 0) (offset (* interval-size ix)))
          (loop :for ox :below interval-size
		:do (setf max (max max (aref magnitudes offset))))
	  (setf (aref reduced-out ix) (ash max -3))))
      reduced-out)))

