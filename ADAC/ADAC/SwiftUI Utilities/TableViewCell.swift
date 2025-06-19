// Licensed under the Any Distance Source-Available License
//
//  TableViewCell.swift
//  ADAC
//
//  Created by Daniel Kuntz on 6/29/22.
//

import SwiftUI

enum TableViewCellType {
    case top
    case bottom
    case middle
    case floating
}

struct TableViewCell: View {
    var text: String?
    var font: Font?
    var textColor: Color?
    var image: Image?
    var accessoryImage: Image?
    var imageSize: CGSize?
    var accessoryTint: Color?
    var imageOffset: CGSize?
    var accessory: AnyView?
    var type: TableViewCellType
    var onTap: (() -> Void)?

    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)

    @State private var pressed: Bool = false

    func roundedCorners() -> UIRectCorner {
        switch type {
        case .top:
            return [.topLeft, .topRight]
        case .bottom:
            return [.bottomLeft, .bottomRight]
        case .middle:
            return []
        case .floating:
            return .allCorners
        }
    }

    func shouldAddSeparator() -> Bool {
        switch type {
        case .top, .middle:
            return true
        default:
            return false
        }
    }

    var body: some View {
        let stack = VStack(alignment: .leading, spacing: 0) {
            if shouldAddSeparator() {
                Spacer()
            }

            ZStack {
                HStack {
                    if let text = text {
                        Text(text)
                            .font(font ?? .system(size: 17))
                            .foregroundColor(textColor ?? .white)
                    }
                    if let image = image {
                        image.offset(x: 0.0, y: -1.0)
                    }
                    Spacer()
                }

                HStack {
                    Spacer()
                    if let accessory = accessory {
                        accessory
                    } else if let image = accessoryImage {
                        if let size = imageSize {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: size.width, height: size.height)
                                .offset(imageOffset ?? .zero)
                                .foregroundColor(accessoryTint ?? .white)
                        } else {
                            image
                                .offset(imageOffset ?? .zero)
                                .foregroundColor(accessoryTint ?? .white)
                        }
                    }
                }
            }
            .padding([.leading, .trailing], 15)

            if shouldAddSeparator() {
                Spacer()
                Spacer()
                    .frame(height: 0.5)
                    .frame(maxWidth: .infinity)
                    .background(Color(white: 0.25))
            }
        }
        .frame(height: 51)
        .background(Color(white: pressed ? 0.25 : 0.125))
        .cornerRadius(12, corners: roundedCorners())

        if accessory == nil || onTap != nil {
            stack.overlay(
                TappableView(onTap: {
                    feedbackGenerator.impactOccurred()
                    onTap?()
                }, onPress: onPress, pressDuration: 0.1)
            )
        } else {
            stack
        }
    }

    private func onPress(isPressed: Bool) {
        withAnimation(Animation.easeInOut.speed(8)) {
            self.pressed = isPressed
        }
    }
}

struct SectionHeaderText: View {
    var text: String

    var body: some View {
        HStack(spacing: 0) {
            Text(text)
                .font(.greedMedium(size: 18.0))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Spacer(minLength: 0)
                .frame(height: 12)
        }
        .padding(.leading, 5)
    }
}
