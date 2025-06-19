// Licensed under the Any Distance Source-Available License
//
//  UIView+Toast.swift
//  ADAC
//
//  Created by Jarod Luebbert on 4/15/22.
//

import UIKit

extension UIView {
    func present(toast: ToastView, insets: UIEdgeInsets = .zero) {
        ToastPresenter.shared.present(toast: toast, from: self, insets: insets)
    }
}

fileprivate class ToastPresenter {
    
    static let shared = ToastPresenter()
    
    private var sessionCount: [ToastView.Model: Int] = [:]
    
    private init() {}
    
    private func hasReachedMaxPerSession(for model: ToastView.Model) -> Bool {
        guard model.maxPerSession != 0,
              let count = sessionCount[model] else { return false }
        
        return count >= model.maxPerSession
    }
    
    func present(toast: ToastView, from view: UIView, insets: UIEdgeInsets = .zero) {
        guard !hasReachedMaxPerSession(for: toast.model) else {
            return
        }
        
        if toast.model.maxPerSession > 0 {
            let count = sessionCount[toast.model] ?? 0
            sessionCount[toast.model] = count + 1
        }
        
        view.addSubview(toast)
        
        let margin: CGFloat = 15.0 + (insets.left + insets.right)
        let marginBottom: CGFloat = 15.0 + insets.bottom
        toast.frame = .init(x: view.bounds.origin.x + margin,
                            y: view.bounds.origin.y + view.bounds.size.height,
                            width: view.bounds.size.width - (margin * 2.0),
                            height: ToastView.defaultHeight)
        
        var endFrame = toast.frame
        endFrame.origin.y = view.bounds.origin.y + view.bounds.size.height - marginBottom - ToastView.defaultHeight - view.safeAreaInsets.bottom
        UIView.animate(withDuration: 0.4, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2) {
            toast.frame = endFrame
        }
        
        if toast.model.autohide {
            DispatchQueue.main.asyncAfter(deadline: .now() + (toast.model.description.isEmpty ? 2.0 : 6.0)) {
                toast.dismiss()
            }
        }
        
        toast.impact()
    }

    
}
