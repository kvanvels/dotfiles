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
  (when (and (display-graphic-p) (< (frame-width) 250))
    (set-frame-width (selected-frame) 250))
  (split-window-right 82)
  (other-window 1)
  (split-window-right 82)
  (other-window -1)
  (dolist (win (window-list))
    (set-window-parameter win 'no-delete-other-windows t)))

;; PDF-Tools + SyncTeX
(pdf-tools-install)
(setq TeX-view-program-selection '((output-pdf "PDF Tools")))
(setq TeX-view-program-list '(("PDF Tools" TeX-pdf-tools-sync-view)))
(setq TeX-source-correlate-start-server t)
(add-hook 'TeX-after-compilation-finished-functions #'TeX-revert-document-buffer)

(require 'claude-code)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-enabled-themes '(infodoc))
 '(custom-safe-themes
   '("d2c18b27125e7319c0abaf829e282e1cd83dfa8d810302842ed665f2703d87bc"
     "847c2471758ccf5e05baea345e2354e8ad6b4bc48a7059fa9b73d23a1f205a5d"
     "8d9915384e65ab0bc14919983c4f17ff5b0dc1a4db28159eefd9cd76c2a8e7a8"
     "13bd95b605d4415176da8feb6e58e077017f3d41489d2cb1aaae4db1584727ed"
     "1c96aa7a8f3ffa83d02ea0be4a572d2f8f66e7bb440b060e7f2fb0e2081078d9"
     "6f49b774cc8ded22c4c4b78dfe5cc6198ea0ebf21bf740f5e202c1975955ba3e"
     default))
 '(package-selected-packages
   '(auctex claude-code claude-code-context claude-shell
	    color-theme-modern company-auctex fold-this git-annex
	    indent-bars magit magit-annex nael nov org outline-indent
	    pdf-tools pdf-view-pagemark preview-tailor sr-speedbar
	    yafolding)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
(put 'narrow-to-region 'disabled nil)
