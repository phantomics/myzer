;;;; myzer.asd

(asdf:defsystem #:myzer
  :description "Describe myzer here"
  :author "Your Name <your.name@example.com>"
  :license  "Specify license here"
  :version "0.0.1"
  :serial t
  :depends-on ("lparallel" "serapeum" "cl-portaudio" "pfft")
  :components ((:file "package")
               (:file "myzer")))
