;; -*- lexical-binding: t -*-
(require 'package)
(add-to-list 'package-archives '("MELPA" . "https://melpa.org/packages/") t)

(setq vc-handled-backends (delq 'Git vc-handled-backends))

;; Show text-area width in the mode line, e.g. "100W"
(add-to-list 'mode-line-position '(:eval (format "  %dW" (window-body-width))) t)

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

;; Flash cursor briefly when switching windows so active window is obvious
(beacon-mode 1)

;; Keep eldoc output in the echo area; suppress the *eldoc* popup buffer.
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

(defun my-nael-setup ()
  ;; Disable hover provider: suppresses tactic docstrings on cursor movement.
  ;; C-c C-n: eglot code actions (nael remaps C-c C-a to abbrev-mode).
  ;; C-c C-p: toggle eglot sync to freeze goal state while typing mid-proof.
  (setq-local eglot-ignored-server-capabilities '(:hoverProvider))
  (setq-local indent-tabs-mode nil)
  (setq fill-column 125)
  (local-set-key (kbd "C-c C-n") #'eglot-code-actions)
  (local-set-key (kbd "C-c C-p") #'my-eglot-pause-sync)
  (abbrev-mode 1)
  (eglot-ensure)
  (yafolding-mode 1))

(add-hook 'nael-mode-hook #'my-nael-setup)

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

(defun my-latex-layout ()
  "TeX layout: speedbar | editor/claude | pdf/browser."
  (interactive)
  (delete-other-windows)
  (when (and (display-graphic-p) (< (frame-width) 210))
    (set-frame-width (selected-frame) 210)
    (sit-for 0.2))
  (setq sr-speedbar-right-side nil)
  (sr-speedbar-open)
  (let* ((editor-win  (selected-window))
         (pdf-file    (when buffer-file-name
                        (concat
                         (expand-file-name
                          (if (and (fboundp 'TeX-master-file)
                                   (boundp 'TeX-master)
                                   (not (eq TeX-master t)))
                              (TeX-master-file)
                            (file-name-sans-extension buffer-file-name))
                          (file-name-directory buffer-file-name))
                         ".pdf")))
         (right-win   (split-window-right 85))
         (claude-win  (split-window-below))
         (_           (select-window right-win))
         (browser-win (split-window-below)))
    ;; PDF: open compiled output if it exists alongside the .tex file
    (when (and pdf-file (file-exists-p pdf-file))
      (find-file pdf-file))
    ;; Claude Code session in the bottom-center window
    (require 'claude-code)
    (with-selected-window claude-win
      (claude-code-run))
    ;; Return focus to the editor
    (select-window editor-win)
    (dolist (win (window-list))
      (set-window-parameter win 'no-delete-other-windows t))))

;; Load claude-code after startup so vterm and other deps are available
(run-with-idle-timer 2 nil #'require 'claude-code)

;; PDF-Tools + SyncTeX — defer loading until a PDF is actually opened
(pdf-loader-install)
(with-eval-after-load 'tex
  (setq TeX-view-program-selection '((output-pdf "PDF Tools")))
  (setq TeX-view-program-list '(("PDF Tools" TeX-pdf-tools-sync-view)))
  (setq TeX-source-correlate-start-server t)
  (add-hook 'TeX-after-compilation-finished-functions #'TeX-revert-document-buffer))
(with-eval-after-load 'pdf-view
  (add-hook 'pdf-view-after-change-page-hook
            #'pdf-view-set-slice-from-bounding-box))

(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(load custom-file :no-error)

(put 'narrow-to-region 'disabled nil)
