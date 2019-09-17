;;; dwsm.el ---                                      -*- lexical-binding: t; -*-

;; Copyright (C) 2019 robario

;; Author: robario <robario@webmaster.com>
;; Keywords: desktop

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; The desktop window state manager

;; from eyebrowse
;; Notes
;; The window-state-put and window-state-get functions do not save all window parameters. If you use features like side windows that store the window parameters window-side and window-slot, you will need to customize window-persistent-parameters for them to be saved as well:
;; (add-to-list 'window-persistent-parameters '(window-side . writable))
;; (add-to-list 'window-persistent-parameters '(window-slot . writable))

;;; Code:

(with-eval-after-load "window"
  ;; window-state-put cannot resume splitting window when a buffer has gone away
  (defun advice:after-until/get-buffer (&rest args)
    (or (get-buffer "*scratch*") (other-buffer)))

  (defun advice:around/window--state-put-2 (orig-func &rest args)
    (advice-add 'get-buffer :after-until #'advice:after-until/get-buffer)
    (apply orig-func args)
    (advice-remove 'get-buffer #'advice:after-until/get-buffer))
  (advice-add 'window--state-put-2 :around #'advice:around/window--state-put-2)

  (defvar my:window-state-pool nil)
  (defvar my:window-state-index 0)

  (defun my:window-state-info ()
    (format "[%d/%d]" (1+ my:window-state-index) (length my:window-state-pool)))

  (defun my:window-state-save ()
    (interactive)
    (setcar (nthcdr my:window-state-index my:window-state-pool) (window-state-get nil t)))

  (defun my:window-state-create ()
    (interactive)
    (when (not (null my:window-state-pool))
      (my:window-state-save))
    (setq my:window-state-index (length my:window-state-pool))
    (add-to-list 'my:window-state-pool (window-state-get nil t) t #'(lambda (a b) nil))
    (switch-to-buffer "*scratch*")
    (delete-other-windows)
    (my:window-state-save))

  (defun my:window-state-delete ()
    (interactive)
    (setq my:window-state-pool (remove (nth my:window-state-index my:window-state-pool) my:window-state-pool))
    (my:window-state-goto my:window-state-index))

  (defun my:window-state-goto (index &optional cyclic)
    (when (null my:window-state-pool)
      (my:window-state-create))
    (let ((last-index (1- (length my:window-state-pool))))
      (interactive (number-sequence 0 last-index))
      (setq my:window-state-index (cond ((< index 0) (if cyclic last-index 0))
                                        ((< last-index index) (if cyclic 0 last-index))
                                        (t index)))
      (window-state-put (nth my:window-state-index my:window-state-pool) (frame-root-window))))

  (defun my:window-state-swap-left ()
    (interactive)
    (when (<= 0 (1- my:window-state-index))
      (let* ((left-index (1- my:window-state-index))
             (cur (nth my:window-state-index my:window-state-pool))
             (left (nth left-index my:window-state-pool)))
        (setcar (nthcdr my:window-state-index my:window-state-pool) left)
        (setcar (nthcdr left-index my:window-state-pool) cur)
        (setq my:window-state-index left-index))
      (my:window-state-goto my:window-state-index)))

  (defun my:window-state-swap-right ()
    (interactive)
    (when (<= (1+ my:window-state-index) (1- (length my:window-state-pool)))
      (let* ((right-index (1+ my:window-state-index))
             (cur (nth my:window-state-index my:window-state-pool))
             (right (nth right-index my:window-state-pool)))
        (setcar (nthcdr my:window-state-index my:window-state-pool) right)
        (setcar (nthcdr right-index my:window-state-pool) cur)
        (setq my:window-state-index right-index))
      (my:window-state-goto my:window-state-index)))

  (defun my:window-state-prev ()
    (interactive)
    (my:window-state-save)
    (my:window-state-goto (1- my:window-state-index)))

  (defun my:window-state-prev-cyclic ()
    (interactive)
    (my:window-state-save)
    (my:window-state-goto (1- my:window-state-index) t))

  (defun my:window-state-next ()
    (interactive)
    (my:window-state-save)
    (my:window-state-goto (1+ my:window-state-index)))

  (defun my:window-state-next-cyclic ()
    (interactive)
    (my:window-state-save)
    (my:window-state-goto (1+ my:window-state-index) t))

  (defun my:window-state-init ()
    (my:window-state-goto my:window-state-index)
    (add-hook 'window-configuration-change-hook #'my:window-state-save))

  (add-to-list 'desktop-globals-to-save 'my:window-state-pool)
  (add-to-list 'desktop-globals-to-save 'my:window-state-index)
  (add-hook 'desktop-no-desktop-file-hook #'my:window-state-init)
  (add-hook 'desktop-not-loaded-hook #'my:window-state-init)
  (add-hook 'desktop-after-read-hook #'my:window-state-init)
)

(provide 'dwsm)
;;; dwsm.el ends here
