// Licensed under the Any Distance Source-Available License
//
//  TappableAttributedText.swift
//  ADAC
//
//  Created by Daniel Kuntz on 5/9/23.
//

import SwiftUI
import UIKit
import NaturalLanguage

struct UsernameTappableAttributedText: View {
    var attributedText: AttributedString
    var maxWidth: CGFloat = 0.0
    var taggedColor: UIColor = .adOrangeLighter
    @Binding var layoutWidth: CGFloat?
    @Binding var layoutHeight: CGFloat?

    private func wordTapped(_ range: Range<String.Index>) {
        let string = String(attributedText.characters)
        let lower = AttributedString.Index(range.lowerBound, within: attributedText)!
        let upper = AttributedString.Index(range.upperBound, within: attributedText)!
        let attrStringRange = Range<AttributedString.Index>(uncheckedBounds: (lower: lower, upper: upper))

        if attributedText[attrStringRange].foregroundColor == taggedColor {
            // Tapped a username (because it's orange)
            let username = String(string[range])
            Task {
                let user: ADUser? = await {
                    if let user = UserCache.shared.user(for: username) {
                        return user
                    }

                    return try? await UserManager.shared.searchUsers(by: username)
                        .first(where: { $0.username == username })
                }()

                guard let user = user else {
                    return
                }

                DispatchQueue.main.async {
                    let hostingView = UIHostingController(rootView:
                        ProfileView(model: ProfileViewModel(user: user),
                                    presentedInSheet: true)
                            .background(Color.clear)
                    )
                    hostingView.view.backgroundColor = .clear
                    hostingView.view.layer.backgroundColor = UIColor.clear.cgColor

                    UIApplication.shared.topViewController?.present(hostingView, animated: true)
                }
            }
        }
    }

    var body: some View {
        TappableAttributedText(attributedText: attributedText,
                               maxWidth: maxWidth,
                               onWordTapped: wordTapped(_:),
                               layoutWidth: $layoutWidth,
                               layoutHeight: $layoutHeight)
    }
}

struct TappableAttributedText: UIViewRepresentable {
    var attributedText: AttributedString
    var maxWidth: CGFloat
    var onWordTapped: (Range<String.Index>) -> Void
    @Binding var layoutWidth: CGFloat?
    @Binding var layoutHeight: CGFloat?

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = .left
        if maxWidth == 0.0 {
            label.setContentHuggingPriority(.defaultHigh, for: .vertical)
            label.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        }
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let tapGesture = UITapGestureRecognizer(target: context.coordinator,
                                                action: #selector(Coordinator.labelTapped))
        label.addGestureRecognizer(tapGesture)
        label.isUserInteractionEnabled = true

        return label
    }

    func updateUIView(_ uiView: UILabel, context: Context) {
        uiView.attributedText = NSAttributedString(attributedText)
        context.coordinator.updateWidthConstraint(for: uiView, maxWidth: maxWidth)
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self, onWordTapped: onWordTapped)
    }

    class Coordinator: NSObject {
        var parent: TappableAttributedText
        var onWordTapped: (Range<String.Index>) -> Void
        var heightConstraint: NSLayoutConstraint?

        init(parent: TappableAttributedText,
             onWordTapped: @escaping (Range<String.Index>) -> Void) {
            self.parent = parent
            self.onWordTapped = onWordTapped
        }

        func updateWidthConstraint(for label: UILabel, maxWidth: CGFloat) {
            guard let rect = label.attributedText?.boundingRect(with: CGSize(width: maxWidth,
                                                                             height: .greatestFiniteMagnitude),
                                                                options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                                context: .none) else {
                return
            }

            guard maxWidth != 0.0 else {
                return
            }

            DispatchQueue.main.async {
                self.parent.layoutWidth = ceil(rect.width)
                self.parent.layoutHeight = ceil(rect.height)
                self.heightConstraint?.autoRemove()
                self.heightConstraint = label.autoSetDimension(.height,
                                                               toSize: ceil(rect.height))
            }
        }

        @objc func labelTapped(_ gesture: UITapGestureRecognizer) {
            guard let label = gesture.view as? UILabel,
                  let attributedText = label.attributedText else { return }

            let layoutManager = NSLayoutManager()
            let textContainer = NSTextContainer(size: label.bounds.size)
            let textStorage = NSTextStorage(attributedString: attributedText)

            layoutManager.addTextContainer(textContainer)
            textStorage.addLayoutManager(layoutManager)

            textContainer.lineFragmentPadding = 0
            textContainer.lineBreakMode = label.lineBreakMode
            textContainer.maximumNumberOfLines = label.numberOfLines

            let location = gesture.location(in: label)
            let textContainerLocation = CGPoint(x: location.x, y: location.y)

            let characterIndex = layoutManager.characterIndex(for: textContainerLocation,
                                                              in: textContainer,
                                                              fractionOfDistanceBetweenInsertionPoints: nil)

            if characterIndex < textStorage.length {
                if let wordRange = self.wordRange(at: characterIndex, in: attributedText.string) {
                    onWordTapped(wordRange)
                }
            }
        }

        func wordRange(at charIndex: Int, in text: String) -> Range<String.Index>? {
            guard charIndex >= 0, charIndex < text.count else {
                print("Invalid character index.")
                return nil
            }

            let index = text.index(text.startIndex, offsetBy: charIndex)
            let tokenizer = NLTokenizer(unit: .word)
            tokenizer.string = text

            for wordRange in tokenizer.tokens(for: text.startIndex..<text.endIndex) {
                if wordRange.contains(index) {
                    return wordRange
                }
            }

            return nil
        }
    }
}
