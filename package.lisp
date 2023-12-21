;;;; package.lisp

(defpackage #:myzer
  (:use #:cl #:lparallel #:serapeum #:portaudio #:pfft)
  (:export #:audio-monitor-start #:audio-monitor-stop #:reduce-frequencies-max))
