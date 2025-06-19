// Licensed under the Any Distance Source-Available License
//
//  SwiftUILoadingButton.swift
//  ADAC
//
//  Created by Daniel Kuntz on 1/23/23.
//

import SwiftUI

struct SwiftUILoadingButton: UIViewRepresentable {
    var isLoading: Bool = false
    var title: String = ""
    var backgroundColor: UIColor = .white
    var action: (() -> Void)?

    func makeUIView(context: Context) -> LoadingButton {
        let button = LoadingButton()
        button.setTitle(title, for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = backgroundColor
        button.layer.cornerRadius = 10
        button.addAction(UIAction(handler: { _ in
            action?()
        }), for: .touchUpInside)
        button.autoSetDimension(.height, toSize: 50)
        button.autoSetDimension(.width, toSize: UIScreen.main.bounds.width - 40)
        return button
    }

    func updateUIView(_ uiView: LoadingButton, context: Context) {
        uiView.isLoading = isLoading
    }
}
