;; -*- lexical-binding: t -*-
(require 'package)
(add-to-list 'package-archives '("MELPA" . "https://melpa.org/packages/") t)

(setq vc-handled-backends (delq 'Git vc-handled-backends))

;; Show text-area width in the mode line, e.g. "100W"
(setq mode-line-position
      (append mode-line-position
              '((:eval (format "  %dW" (window-body-width))))))

;; Skip font-lock while actively typing (Emacs 28+)
(setq redisplay-skip-fontification-on-input t)
(setq jit-lock-defer-time 0.1)

;; Reduce AUCTeX font-lock to level 1 (drops regex passes + texmathp scans)
(setq font-lock-maximum-decoration '((latex-mode . 1) (t . t)))

;; Stop computing shorter keybinding suggestions after every M-x
(setq suggest-key-bindings nil)

;; Reduce GC frequency (default 800KB threshold fires constantly)
(setq gc-cons-threshold (* 100 1024 1024))

;; Disable UI elements that run expensive updates on every redisplay
(menu-bar-mode -1)
(tool-bar-mode -1)

;; Delay show-paren so it doesn't fire on every keystroke
(setq show-paren-delay 0.5)

;; Keep eldoc output in the echo area; suppress the *eldoc* popup buffer.
;; Other options if more reduction is needed:
;;   (setq eldoc-echo-area-use-multiline-p 3)  ; limit to N lines
(setq eldoc-echo-area-prefer-doc-buffer nil)

;; Disable hover provider so eglot doesn't show tactic/term docstrings
;; (e.g. "Introduces one or more hypotheses..." when hovering over `intro`).
;; Goal state and signature help are unaffected.
;;
;; C-c C-n triggers eglot code actions, which is how `exact?` and similar
;; tactics surface their suggestions as an actionable pop-up.
;; (nael remaps C-c C-a to abbrev-mode, so we need a different binding.)
(defun my-eglot-pause-sync ()
  "Toggle eglot change sync on/off."
  (interactive)
  (if (= eglot-send-changes-idle-time 9999)
      (progn
        (setq-local eglot-send-changes-idle-time 0.5)
        (message "eglot sync: on"))
    (setq-local eglot-send-changes-idle-time 9999)
    (message "eglot sync: paused")))

(add-hook 'nael-mode-hook (lambda ()
  (setq-local eglot-ignored-server-capabilities '(:hoverProvider))
  (local-set-key (kbd "C-c C-n") #'eglot-code-actions)
  (local-set-key (kbd "C-c C-p") #'my-eglot-pause-sync)))

(add-hook 'nael-mode-hook #'abbrev-mode)
(add-hook 'nael-mode-hook #'eglot-ensure)
(add-hook 'nael-mode-hook (lambda () (setq-local indent-tabs-mode nil)))
(add-hook 'nael-mode-hook (lambda () (setq fill-column 125)))
(add-hook 'nael-mode-hook #'yafolding-mode)

(add-hook 'LaTeX-mode-hook (lambda ()
  (outline-minor-mode 1)
  (TeX-source-correlate-mode 1)))

(global-set-key (kbd "C-c C-<left>")  #'windmove-left)
(global-set-key (kbd "C-c C-<right>") #'windmove-right)
(global-set-key (kbd "C-c C-<up>")    #'windmove-up)
(global-set-key (kbd "C-c C-<down>")  #'windmove-down)

(defun my-tex-layout ()
  "Set up three protected 80-column windows for TeX editing."
  (interactive)
  (delete-other-windows)
  ;; Terminal frames are ignored; set-frame-width only works graphically.
  ;; Wayland compositor takes ~0.045s to acknowledge resize; 0.2s gives 4x margin.
  (when (and (display-graphic-p) (< (frame-width) 250))
    (set-frame-width (selected-frame) 250)
    (sit-for 0.2))
  (split-window-right 82)
  (other-window 1)
  (split-window-right 82)
  (other-window -1)
  (dolist (win (window-list))
    (set-window-parameter win 'no-delete-other-windows t)))

;; PDF-Tools + SyncTeX — defer loading until a PDF is actually opened
(pdf-loader-install)
(with-eval-after-load 'tex
  (setq TeX-view-program-selection '((output-pdf "PDF Tools")))
  (setq TeX-view-program-list '(("PDF Tools" TeX-pdf-tools-sync-view)))
  (setq TeX-source-correlate-start-server t)
  (add-hook 'TeX-after-compilation-finished-functions #'TeX-revert-document-buffer))

(require 'claude-code)

(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(load custom-file :no-error)

(put 'narrow-to-region 'disabled nil)
