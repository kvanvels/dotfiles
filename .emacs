;; -*- lexical-binding: t -*-
(require 'package)
(add-to-list 'package-archives '("MELPA" . "https://melpa.org/packages/") t)

(setq vc-handled-backends (delq 'Git vc-handled-backends))

;; Show text-area width in the mode line, e.g. "100W"
(add-to-list 'mode-line-position '(:eval (format "  %dW" (window-body-width))) t)

;; Clickable lock in mode line to toggle window dedication (protection)
(defun my-toggle-window-dedicated (event)
  "Toggle dedication of the window whose mode-line was clicked."
  (interactive "e")
  (let* ((win (posn-window (event-start event)))
         (dedicated (window-dedicated-p win)))
    (set-window-dedicated-p win (if dedicated nil t))
    (force-mode-line-update t)
    (message "Window %s" (if dedicated "unprotected" "protected"))))

(let ((map (make-sparse-keymap)))
  (define-key map [mode-line mouse-1] #'my-toggle-window-dedicated)
  (defvar my-mode-line-dedicated-map map))

;; global-mode-string is a sub-component included in every standard mode line,
;; so adding here reaches all buffers without fighting buffer-local overrides.
(add-to-list 'global-mode-string
             '(:eval (propertize
                      (if (window-dedicated-p) " [P]" " [ ]")
                      'face (if (window-dedicated-p)
                                '(:weight bold)
                              '(:foreground "#555555"))
                      'help-echo "Click to toggle window protection"
                      'local-map my-mode-line-dedicated-map
                      'mouse-face 'mode-line-highlight))
             t)

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
  (TeX-source-correlate-mode 1)
  (local-set-key (kbd "<tab>")     #'bicycle-cycle)
  (local-set-key (kbd "<backtab>") #'bicycle-cycle-global)))

;; C-x b handles most buffer switching; use M-x ibuffer when full list needed
(global-unset-key (kbd "C-x C-b"))

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
  "TeX layout: speedbar | editor/claude | pdf/terminal | wild-west.

Fixed windows (claude, pdf, terminal) are dedicated and survive C-x 1.
Editor also survives C-x 1 but is not dedicated so files open there
normally.  Wild-west column is unprotected: C-x 1 from editor closes
it without touching anything else."
  (interactive)
  (delete-other-windows)
  ;; Terminal frames are ignored; set-frame-width only works graphically.
  ;; Wayland compositor takes ~0.045s to acknowledge resize; 0.2s gives 4x margin.
  (when (and (display-graphic-p) (< (frame-width) 280))
    (set-frame-width (selected-frame) 280)
    (sit-for 0.2))
  ;; Capture editor-win before speedbar opens; sr-speedbar-open may steal focus
  ;; but the window object remains valid and is still the main editing window.
  (let* ((editor-win (selected-window))
         (pdf-file   (when buffer-file-name
                       (concat
                        (expand-file-name
                         (if (and (fboundp 'TeX-master-file)
                                  (boundp 'TeX-master)
                                  (not (eq TeX-master t)))
                             (TeX-master-file)
                           (file-name-sans-extension buffer-file-name))
                         (file-name-directory buffer-file-name))
                        ".pdf"))))
    (setq sr-speedbar-right-side nil)
    (sr-speedbar-open)
    ;; Use explicit window args so selected-window state after speedbar doesn't matter.
    (let* ((pdf-col    (split-window-right 85 editor-win))
           (wild-win   (split-window-right 85 pdf-col))
           (term-win   (split-window-below nil pdf-col))
           (claude-win (split-window-below nil editor-win)))
      ;; PDF viewer
      (select-window pdf-col)
      (when (and pdf-file (file-exists-p pdf-file))
        (find-file pdf-file))
      ;; Terminal
      (select-window term-win)
      (require 'vterm)
      (vterm "*terminal*")
      ;; Claude Code: claude-code-run ends with switch-to-buffer-other-window
      ;; which would steal wild-win, so replicate its setup and target claude-win.
      (require 'claude-code)
      (let* ((claude-name (claude-code-buffer-name))
             (project-root (claude-code-normalize-project-root
                            (projectile-project-root)))
             (default-directory project-root)
             (vterm-shell  claude-code-executable)
             (claude-buf   (get-buffer-create claude-name)))
        (with-current-buffer claude-buf
          (unless (eq major-mode 'claude-code-vterm-mode)
            (claude-code-vterm-mode))
          (setq-local mode-line-buffer-identification
                      (list (propertize
                             (concat "*"
                                     (file-name-nondirectory
                                      (directory-file-name project-root))
                                     "*")
                             'face 'mode-line-buffer-id))))
        (set-window-buffer claude-win claude-buf))
      ;; All six layout windows are protected: dedicated + survive C-x 1.
      (dolist (win (list editor-win pdf-col term-win claude-win wild-win))
        (set-window-dedicated-p win t)
        (set-window-parameter win 'no-delete-other-windows t))
      (select-window editor-win))))

;; Load claude-code after startup so vterm and other deps are available
(run-with-idle-timer 2 nil #'require 'claude-code)

(with-eval-after-load 'tex
  (setq TeX-source-correlate-start-server t)
  (add-hook 'TeX-after-compilation-finished-functions #'TeX-revert-document-buffer))

(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(load custom-file :no-error)

(put 'narrow-to-region 'disabled nil)
