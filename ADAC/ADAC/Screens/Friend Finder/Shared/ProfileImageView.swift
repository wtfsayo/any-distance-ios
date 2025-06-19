// Licensed under the Any Distance Source-Available License
//
//  ProfileImageView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 7/25/23.
//

import SwiftUI

/// Wrapper around ProfileImageView that shows profile picture for a given ADUser
struct UserProfileImageView: View {
    @ObservedObject var user: ADUser
    var showsLoadingIndicator: Bool = false
    var width: CGFloat

    var body: some View {
        ProfileImageView(profilePictureURL: user.isBlocked ? nil : user.profilePhotoUrl,
                         showsLoadingIndicator: showsLoadingIndicator,
                         name: user.name,
                         width: width)
        .background(Color.black)
        .cornerRadius(width / 2, style: .continuous)
        .id(user.profilePhotoUrl?.absoluteString ?? "")
    }
}

/// View that shows a profile picture from a UIImage or URL, or initials if neither is provided or valid,
/// with pill shape mask
struct ProfileImageView: View {
    var profilePicture: UIImage?
    var profilePictureURL: URL?
    var showsLoadingIndicator: Bool = false
    var name: String
    var width: CGFloat = 23

    func initials() -> String {
        return String(name.components(separatedBy: .whitespaces)
            .compactMap { $0.substring(from: 0, length: 1) }
            .joined()
            .uppercased()
            .prefix(2))
    }

    var body: some View {
        ZStack {
            if let profilePicture = profilePicture {
                Image(uiImage: profilePicture)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let profilePictureURL = profilePictureURL {
                AsyncCachedImage(url: profilePictureURL,
                                 resizeToWidth: width * 2.0,
                                 showsLoadingIndicator: showsLoadingIndicator)
            } else {
                Text(initials())
                    .font(.system(size: 0.55 * width,
                                  weight: .medium,
                                  design: .monospaced))
                    .foregroundColor(.black)
            }
        }
        .frame(width: width, height: 1.525 * width)
        .if(profilePicture == nil) { view in
            view
                .background {
                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                }
        }
        .mask(RoundedRectangle(cornerRadius: width / 2, style: .continuous))
    }
}
