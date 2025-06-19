// Licensed under the Any Distance Source-Available License
//
//  TaggableTextField.swift
//  ADAC
//
//  Created by Daniel Kuntz on 5/8/23.
//

import SwiftUI

fileprivate struct TagSelectorItem: View {
    var user: ADUser
    var onTap: ((ADUser) -> Void)

    var body: some View {
        Button {
            onTap(user)
        } label: {
            HStack(spacing: 4.0) {
                ProfileImageView(profilePictureURL: user.profilePhotoUrl,
                                 name: user.name,
                                 width: 20.0)
                Text("@\(user.username ?? "")")
                    .font(.system(size: 12, weight: .medium))
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundColor(.white)
                    .opacity(0.6)
            }
        }
        .buttonStyle(ScalingPressButtonStyle())
    }
}

fileprivate struct TagSelector: View {
    var tag: String
    var onTap: ((ADUser) -> Void)
    @State private var users: [ADUser] = []

    private func hydrateUsers(for tag: String) {
        Task(priority: .userInitiated) {
            let users = Array(UserCache.shared.searchFriends(by: String(tag.dropFirst())).prefix(3))
            await MainActor.run {
                self.users = users
            }
        }
    }

    var body: some View {
        ZStack {
            if !users.isEmpty {
                HStack(spacing: 16.0) {
                    ForEach(users, id: \.id) { user in
                        TagSelectorItem(user: user) { user in
                            onTap(user)
                        }
                    }
                }
                .padding(10.0)
                .background {
                    RoundedRectangle(cornerRadius: 9.0, style: .continuous)
                        .foregroundColor(.black)
                }
                .shadow(color: .black, radius: 8.0)
            }
        }
        .id(users.compactMap({ $0.username }).joined())
        .modifier(BlurOpacityTransition(speed: 2.2))
        .onAppear {
            hydrateUsers(for: tag)
        }
        .onChange(of: tag) { newValue in
            hydrateUsers(for: newValue)
        }
    }
}

struct TaggableTextField: View {
    var placeholder: String
    @Binding var text: String
    var axis: Axis
    var returnKeyType: UIReturnKeyType
    var font: UIFont
    var onCommit: (() -> Void)? = nil

    @State var height: CGFloat = 32.0
    @State fileprivate var initDecodedTags: DecodedTags?
    @State private var attributedText: AttributedString = AttributedString("")

    @State var tagSelectorVisible: Bool = false

    private let generator = UIImpactFeedbackGenerator(style: .medium)

    private func setLastTag(with user: ADUser, tag: String) {
        let newUsername: String = "@" + (user.username ?? "") + " "
        let newString: String = String(attributedText.characters).dropLast(tag.count) + newUsername
        self.attributedText = AttributedString(newString)
        self.generator.impactOccurred()
    }

    var body: some View {
        AttributedTextField(attributedText: $attributedText,
                            height: $height,
                            placeholder: placeholder,
                            keyboardType: .default,
                            returnKeyType: returnKeyType,
                            font: font,
                            onCommit: onCommit)
        .frame(height: height)
        .overlay {
            ZStack(alignment: .bottom) {
                if tagSelectorVisible,
                   let tag = String(attributedText.characters).components(separatedBy: .whitespacesAndNewlines).last,
                   tag.count > 1 {
                    VStack {
                        Spacer()
                        TagSelector(tag: tag) { user in
                            setLastTag(with: user, tag: tag)
                        }
                        .modifier(BlurOpacityTransition(speed: 2.2))
                        .if(height < 46) { view in
                            view.offset(y: -0.5 * (46 - height))
                        }
                        .offset(y: -1 * (font.lineHeight + 14))
                    }
                } else {
                    EmptyView()
                }
            }
        }
        .onAppear {
            initDecodedTags = TagCoder.decodeTags(for: text,
                                                  withBaseFontSize: font.pointSize)
            attributedText = initDecodedTags?.attributedString ?? attributedText
        }
        .onChange(of: attributedText) { [oldValue = attributedText] newValue in
            guard newValue != oldValue else {
                return
            }

            let encodedTags = TagCoder.encodeTags(for: String(newValue.characters),
                                                  withBaseFontSize: font.pointSize)
            attributedText = encodedTags.attributedString
            text = encodedTags.tagEncodedString

            if String(attributedText.characters)
                .components(separatedBy: .whitespacesAndNewlines)
                .last?.first == "@" {
                // User is typing a tag
                tagSelectorVisible = true
            } else {
                tagSelectorVisible = false
            }
        }
        .onChange(of: text) { newValue in
            if newValue.isEmpty {
                attributedText = AttributedString("")
            }
        }
    }
}

fileprivate struct AttributedTextField: UIViewRepresentable {
    @Binding var attributedText: AttributedString
    @Binding var height: CGFloat
    var placeholder: String
    var keyboardType: UIKeyboardType = .default
    var returnKeyType: UIReturnKeyType
    var font: UIFont
    var onCommit: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        context.coordinator.textView = textView
        textView.delegate = context.coordinator
        textView.keyboardType = keyboardType
        textView.tintColor = UIColor.adOrangeLighter
        textView.returnKeyType = returnKeyType
        textView.textAlignment = .left
        textView.backgroundColor = .clear
        textView.textColor = .white
        textView.font = font
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.spellCheckingType = .no

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white
        ]
        textView.attributedPlaceholder = NSAttributedString(string: placeholder,
                                                            attributes: attrs)
        textView.attributedText = NSAttributedString(attributedText)
        textView.updatePlaceholderVisibility()

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        textView.attributedText = NSAttributedString(attributedText)
        textView.updatePlaceholderVisibility()
        updateHeight(for: textView)
    }

    func updateHeight(for textView: UITextView) {
        if attributedText.characters.isEmpty,
           let rect = textView.attributedPlaceholder?.boundingRect(with: CGSize(width: 10000, height: 10000),
                                                                   context: .none) {
            let insets: UIEdgeInsets = textView.textContainerInset
            DispatchQueue.main.async {
                self.height = rect.height + insets.top + insets.bottom
            }
        } else {
            let nsAttrString = NSAttributedString(attributedText)
            let rect = nsAttrString.boundingRect(with: CGSize(width: textView.frame.size.width, height: .greatestFiniteMagnitude),
                                                 options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                 context: .none)
            let insets: UIEdgeInsets = textView.textContainerInset
            DispatchQueue.main.async {
                self.height = ceil(rect.height) + insets.top + insets.bottom
            }
        }
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: AttributedTextField
        var textView: UITextView?

        init(_ textViewRepresentable: AttributedTextField) {
            self.parent = textViewRepresentable
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            DispatchQueue.main.async {
                self.parent.attributedText = (try? AttributedString(textView.attributedText ?? NSAttributedString(""),
                                                                    including: \.uiKit)) ?? AttributedString("")
                self.parent.updateHeight(for: textView)
            }
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if let onCommit = parent.onCommit, text == "\n" {
                textView.resignFirstResponder()
                onCommit()
                return false
            }
            return true
        }

        public func textViewDidChange(_ textView: UITextView) {
            textView.updatePlaceholderVisibility()
        }
    }
}

extension UITextView: UITextViewDelegate {
    private struct AssociatedKeys {
        static var attributedPlaceholder: NSAttributedString?
    }

    var attributedPlaceholder: NSAttributedString? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.attributedPlaceholder) as? NSAttributedString
        }
        set {
            if let newValue = newValue {
                objc_setAssociatedObject(self, &AssociatedKeys.attributedPlaceholder, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                setUpPlaceholder()
            }
        }
    }

    private var placeholderLabel: UILabel? {
        return viewWithTag(100) as? UILabel
    }

    private func setUpPlaceholder() {
        if let placeholderLabel = placeholderLabel {
            placeholderLabel.attributedText = attributedPlaceholder
        } else {
            let newPlaceholderLabel = UILabel()
            newPlaceholderLabel.attributedText = attributedPlaceholder
            newPlaceholderLabel.numberOfLines = 0
            newPlaceholderLabel.textColor = UIColor.white.withAlphaComponent(0.4)
            newPlaceholderLabel.tag = 100
            newPlaceholderLabel.sizeToFit()

            addSubview(newPlaceholderLabel)
            sendSubviewToBack(newPlaceholderLabel)

            newPlaceholderLabel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                newPlaceholderLabel.topAnchor.constraint(equalTo: self.topAnchor, constant: textContainerInset.top),
                newPlaceholderLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 0),
                newPlaceholderLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: 0)
            ])

            updatePlaceholderVisibility()
        }
    }

    func updatePlaceholderVisibility() {
        placeholderLabel?.isHidden = !text.isEmpty
    }
}
