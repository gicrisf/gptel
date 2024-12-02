;;; gptel-replicate.el -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2024
;;
;; Author:  <giovanni.crisalfi@protonmail.com>
;; Maintainer:  <giovanni.crisalfi@protonmail.com>
;; Created: December 01, 2024
;; Modified: December 01, 2024
;; Version: 0.0.1
;; Keywords: extensions
;; Homepage: https://github.com/cromo/gptel-replicate
;; Package-Requires: ((emacs "26.1"))
;;
;; This file is not part of GNU Emacs.
;;
;;; Commentary:
;;
;; This file adds support for Replicate's API to gptel
;;
;;; Code:

(require 'gptel)
(require 'cl-generic)
(require 'map)
(eval-when-compile (require 'cl-lib))

(declare-function prop-match-value "text-property-search")
(declare-function text-property-search-backward "text-property-search")
(declare-function json-read "json")
(declare-function gptel-context--wrap "gptel-context")
(declare-function gptel-context--collect-media "gptel-context")
(defvar json-object-type)

;; Replicate
(cl-defstruct
    (gptel-replicate (:constructor gptel--make-replicate)
                     (:copier nil)
                     (:include gptel-backend)))

;; TODO methods

;; (cl-defmethod gptel-curl--parse-stream ((_backend gptel-replicate) _info))
;; (cl-defmethod gptel-curl--parse-stream ((_backend gptel-replicate) _info))
;; (cl-defmethod gptel--parse-response ((_backend gptel-replicate) response _info))

(cl-defmethod gptel--request-data ((_backend gptel-replicate) prompts)
  "JSON encode PROMPTS for sending to ChatGPT."
  (when (and gptel--system-message
             (not (gptel--model-capable-p 'nosystem)))
    (push (list :role "system"
                :content gptel--system-message)
          prompts))
  (let ((prompts-plist
         ;; TODO replace actual values (hardcoded for test reasons)
         `(:input
           (:prompt "Johnny has 8 billion parameters. His friend Tommy has 70 billion parameters. What does this mean when it comes to speed?"
            :max-new-tokens 512
            :prompt-template "<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\n{system_prompt}<|eot_id|><|start_header_id|>user<|end_header_id|>\n\n{prompt}<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n")))
        options-plist)
    (when gptel-temperature
      (setq options-plist
            (plist-put options-plist :temperature
                       gptel-temperature)))
    ;; TODO move up
    (when gptel-max-tokens
      (setq options-plist
            (plist-put options-plist :num_predict
                       gptel-max-tokens)))
    ;; FIXME: These options will be lost if there are model/backend-specific
    ;; :options, since `gptel--merge-plists' does not merge plist values
    ;; recursively.
    (when options-plist
      (plist-put prompts-plist :options options-plist))
    ;; Merge request params with model and backend params.
    (gptel--merge-plists
     prompts-plist
     (gptel-backend-request-params gptel-backend)
     (gptel--model-request-params  gptel-model))))

;; (cl-defmethod gptel--parse-list ((_backend gptel-replicate) prompt-list))
;; (cl-defmethod gptel--parse-buffer ((_backend gptel-replicate) &optional max-entries))
;; (cl-defmethod gptel--wrap-user-prompt ((_backend gptel-replicate) prompts)

(defconst gptel--replicate-models
  '((meta/meta-llama-3-8b-instruct
     :description "An 8 billion parameter language model from Meta, fine tuned for chat completions"
     :capabilities (tool json)
     :mime-types ("text/plain" "text/csv" "text/html")
     :context-window 8000
     :input-cost 0.05
     :output-cost 0.25
     :cutoff-date "2023-03"))
  "
List of available models.
Keys:

- `:description': a brief description of the model.

- `:capabilities': a list of capabilities supported by the model.

- `:mime-types': a list of supported MIME types for media files.

- `:context-window': the context window size, in thousands of tokens.

- `:input-cost': the input cost, in US dollars per million tokens.

- `:output-cost': the output cost, in US dollars per million tokens.

- `:cutoff-date': the knowledge cutoff date.

- `:request-params': a plist of additional request parameters to
  include when using this model.

Models sources:
https://replicate.com/meta/meta-llama-3-8b-instruct/readme")

;;;###autoload
(cl-defun gptel-make-replicate
    (name &key curl-args header key request-params
          (stream nil)
          (host "api.replicate.com")
          (protocol "https")
          (models gptel--replicate-models)
          (endpoint "/v1/models/meta/meta-llama-3-8b-instruct/predictions"))

  "Register a Replicate backend for gptel with NAME.

Keyword arguments:

CURL-ARGS (optional) is a list of additional Curl arguments.

HOST (optional) is the API host, \"api.replicate.com\" by default.

MODELS is a list of available model names, as symbols.
Additionally, you can specify supported LLM capabilities like
vision or tool-use by appending a plist to the model with more
information, in the form

 (model-name . plist)

For a list of currently recognized plist keys, see
`gptel--replicate-models'. An example of a model specification
including both kinds of specs:

:models
\\='(meta/meta-llama-3-8b-instruct
     :description \"An 8 billion parameter language model from Meta, fine tuned for chat completions\"
     :capabilities (tool json)
     :mime-types (\"text/plain\" \"text/csv\" \"text/html\")
     :context-window 8000
     :input-cost 0.05
     :output-cost 0.25
     :cutoff-date \"2023-03\")

STREAM is a boolean to toggle streaming responses, defaults to
false.

PROTOCOL (optional) specifies the protocol, https by default.

ENDPOINT (optional) is the API endpoint for completions, defaults to
\"/v1/models/meta/meta-llama-3-8b-instruct/predictions\".

HEADER (optional) is for additional headers to send with each
request.  It should be an alist or a function that retuns an
alist, like:
 ((\"Content-Type\" . \"application/json\"))

KEY is a variable whose value is the API key, or function that
returns the key.

REQUEST-PARAMS (optional) is a plist of additional HTTP request
parameters (as plist keys) and values supported by the API.  Use
these to set parameters that gptel does not provide user options
for."
  (declare (indent 1))
  (let ((backend (gptel--make-replicate
                  :curl-args curl-args
                  :name name
                  :host host
                  :header header
                  :key key
                  :models (gptel--process-models models)
                  :protocol protocol
                  :endpoint endpoint
                  :stream stream
                  :request-params request-params
                  :url (if protocol
                           (concat protocol "://" host endpoint)
                         (concat host endpoint)))))
    (prog1 backend
      (setf (alist-get name gptel--known-backends
                       nil nil #'equal)
            backend))))

(provide 'gptel-replicate)
;;; gptel-replicate.el ends here
