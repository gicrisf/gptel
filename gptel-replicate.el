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
;; Package-Requires: ((emacs "25.1"))
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
;; (cl-defmethod gptel-curl--parse-stream ((_backend gptel-anthropic) _info))
;; (cl-defmethod gptel--parse-response ((_backend gptel-anthropic) response _info))
;; (cl-defmethod gptel--request-data ((_backend gptel-anthropic) prompts))
;; (cl-defmethod gptel--parse-list ((_backend gptel-anthropic) prompt-list))
;; (cl-defmethod gptel--parse-buffer ((_backend gptel-anthropic) &optional max-entries))
;; (cl-defmethod gptel--wrap-user-prompt ((_backend gptel-anthropic) prompts)

(defconst gptel--replicate-models
  '((meta/meta-llama-3-8b-instruct
     :description "An 8 billion parameter language model from Meta, fine tuned for chat completions"
     :capabilities (tool json)
     :mime-types ("text/plain" "text/csv" "text/html")
     :context-window 8000
     ))
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

(provide 'gptel-replicate)
;;; gptel-replicate.el ends here
