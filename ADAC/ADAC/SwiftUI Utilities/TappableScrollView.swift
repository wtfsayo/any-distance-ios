// Licensed under the Any Distance Source-Available License
//
//  TappableScrollView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 12/9/21.
//

import SwiftUI

struct TappableScrollView<Content: View>: UIViewRepresentable {
    private let content: UIView
    private let scrollView = TappableUIScrollView()

    init(@ViewBuilder content: () -> Content) {
        self.content = UIHostingController(rootView: content()).view
        self.content.backgroundColor = .clear
    }

    func makeUIView(context: Context) -> UIView {
        scrollView.addSubview(content)
        scrollView.delaysContentTouches = true
        content.translatesAutoresizingMaskIntoConstraints = false
        content.topAnchor.constraint(equalTo: scrollView.topAnchor).isActive = true
        content.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor).isActive = true
        content.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor).isActive = true
        content.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
        scrollView.setContentOffset(.zero, animated: false)

        return scrollView
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

final class TappableUIScrollView: UIScrollView {
    init() {
        super.init(frame: .zero)
        delaysContentTouches = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }

    override func touchesShouldBegin(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) -> Bool {
        if view is TappableUIView {
            return false
        }

        return super.touchesShouldBegin(touches, with: event, in: view)
    }
}

struct TappableView: UIViewRepresentable {
    let onTap: (() -> Void)?
    let onPress: (Bool) -> Void
    let pressDuration: TimeInterval
    var shouldRecognizeSimultaneously: Bool = true

    private let view = TappableUIView()

    func makeUIView(context: Context) -> UIView {
        let tapRecognizer = UITapGestureRecognizer()
        tapRecognizer.delegate = context.coordinator
        tapRecognizer.addTarget(context.coordinator, action: #selector(Coordinator.handleTap))
        view.addGestureRecognizer(tapRecognizer)

        let longPressRecognizer = UILongPressGestureRecognizer()
        longPressRecognizer.minimumPressDuration = pressDuration
        longPressRecognizer.delegate = context.coordinator
        longPressRecognizer.addTarget(context.coordinator, action: #selector(Coordinator.handlePress))
        view.addGestureRecognizer(longPressRecognizer)

        if !shouldRecognizeSimultaneously {
            tapRecognizer.require(toFail: longPressRecognizer)
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private var parent: TappableView

        init(parent: TappableView) {
            self.parent = parent
        }

        @objc fileprivate func handlePress(_ sender: UIGestureRecognizer) {
            switch sender.state {
            case .began: parent.onPress(true)
            case .ended, .cancelled, .failed: parent.onPress(false)
            case .changed, .possible: break
            @unknown default: break
            }
        }

        @objc fileprivate func handleTap(_ sender: UIGestureRecognizer) {
            if case .ended = sender.state,
               let onTap = parent.onTap {
                onTap()
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
    }
}

class TappableUIView: UIView {
    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
}
