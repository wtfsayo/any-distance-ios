// Licensed under the Any Distance Source-Available License
//
//  UserTableViewCell.swift
//  ADAC
//
//  Created by Daniel Kuntz on 7/25/23.
//

import SwiftUI

/// A view that shows a cell for a user with profile picture / name with an optional RightAccessory
struct UserTableViewCell<RightAccessory: View>: View {
    var profilePicture: UIImage?
    var profilePictureURL: URL?
    var nameText: String
    var subtitleText: String?
    var type: TableViewCellType
    var rightAccessory: (() -> RightAccessory)?

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
        VStack(alignment: .leading, spacing: 0) {
            if shouldAddSeparator() {
                Spacer()
            }

            ZStack {
                HStack {
                    ProfileImageView(profilePicture: profilePicture,
                                     profilePictureURL: profilePictureURL,
                                     name: nameText)

                    VStack(alignment: .leading) {
                        Text(nameText)
                            .font(.system(size: 17))
                            .foregroundColor(.white)
                        if let subtitleText = subtitleText {
                            Text(subtitleText)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white)
                                .opacity(0.7)
                        }
                    }

                    Spacer()

                    if let rightAccessory = rightAccessory?() {
                        rightAccessory
                    }
                }
                .padding([.leading, .trailing], 15)
            }

            if shouldAddSeparator() {
                Spacer()
                Spacer()
                    .frame(height: 0.5)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.25))
            }
        }
        .frame(height: 51)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12, corners: roundedCorners())
    }
}
