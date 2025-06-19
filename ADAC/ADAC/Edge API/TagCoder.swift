// Licensed under the Any Distance Source-Available License
//
//  TagCoder.swift
//  ADAC
//
//  Created by Daniel Kuntz on 5/9/23.
//

import UIKit

struct EncodedTags {
    var attributedString: AttributedString
    var tagEncodedString: String
}

struct DecodedTags {
    var attributedString: AttributedString
    var tags: [UserTag]
}

struct UserTag {
    var userID: String
    var username: String

    func encoded() -> String {
        return "<tag userID=\"\(userID)\" username=\"\(username)\">"
    }

    init(userID: String, username: String) {
        self.userID = userID
        self.username = username
    }

    init?(encodedString: String) {
        let userIDRegex = try! Regex("userID=\"[^\"]+\"")
        let usernameRegex = try! Regex("username=\"[^\"]+\"")
        guard let userIDMatch = encodedString.matches(of: userIDRegex).first,
              let usernameMatch = encodedString.matches(of: usernameRegex).first else {
            return nil
        }

        self.userID = String(userIDMatch.0.dropFirst(8).dropLast())
        self.username = String(usernameMatch.0.dropFirst(10).dropLast())
    }
}

struct TagCoder {
    /// Accepts a string with @tags and returns an attributed string with tags highlighted and
    /// a tag-encoded string with tags encoded as <tag userID=USERID username=USERNAME>
    static func encodeTags(for string: String,
                           withBaseFontSize baseFontSize: CGFloat = 14.0) -> EncodedTags {
        let usernameRegex = try! Regex("@\\w+")

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left

        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: baseFontSize,
                                     weight: .regular),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]
        var attributedString = AttributedString(string, attributes: AttributeContainer(baseAttrs))
        var tagEncodedString: String = string
        let friends = ADUser.current.friendIDs.compactMap { UserCache.shared.user(forID: $0) }
        let usernameMatches = string.matches(of: usernameRegex)

        for match in usernameMatches {
            if let user = friends.first(where: { ("@" + ($0.username ?? "")) == match.0 }) {
                let encodedTag = UserTag(userID: user.id, username: user.username ?? "").encoded()
                tagEncodedString = tagEncodedString.replacingOccurrences(of: match.0, with: encodedTag)
                if let range = attributedString.range(of: match.0) {
                    attributedString[range].foregroundColor = UIColor.adOrangeLighter
                    attributedString[range].font = UIFont.systemFont(ofSize: baseFontSize, weight: .bold)
                }
            }
        }

        return EncodedTags(attributedString: attributedString,
                           tagEncodedString: tagEncodedString)
    }

    /// Accepts a string with tags encoded as <tag userID=USERID username=USERNAME> and returns an
    /// attributed string with tags highlighted
    static func decodeTags(for string: String,
                           withBaseFontSize baseFontSize: CGFloat = 14.0,
                           baseColor: UIColor = .white,
                           taggedColor: UIColor = .adOrangeLighter) -> DecodedTags {
        let tagRegex = try! Regex("<tag(.*?)>")


        var decodedString = string
        var tags: [UserTag] = []
        let tagMatches = string.matches(of: tagRegex)

        for tagMatch in tagMatches {
            guard let tag = UserTag(encodedString: String(tagMatch.0)) else {
                decodedString = decodedString.replacingOccurrences(of: tagMatch.0, with: "")
                break
            }

            tags.append(tag)
            decodedString = decodedString.replacingOccurrences(of: tagMatch.0,
                                                               with: "@" + tag.username)
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left

        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: baseFontSize,
                                     weight: .regular),
            .foregroundColor: baseColor,
            .paragraphStyle: paragraphStyle
        ]

        var attributedString = AttributedString(decodedString, attributes: AttributeContainer(baseAttrs))
        let taggedUsernameRegex = try! Regex("@\\w+")
        let usernameMatches = decodedString.matches(of: taggedUsernameRegex)
        for match in usernameMatches {
            if let range = attributedString.range(of: match.0),
               tags.contains(where: { $0.username == match.0.dropFirst() }) {
                attributedString[range].foregroundColor = taggedColor
                attributedString[range].font = UIFont.systemFont(ofSize: baseFontSize, weight: .bold)
            }
        }

        return DecodedTags(attributedString: attributedString, tags: tags)
    }
}
