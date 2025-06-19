// Licensed under the Any Distance Source-Available License
//
//  ADExtensions.swift
//  ADAC
//
//  Created by Daniel Kuntz on 6/25/21.
//

import UIKit
import SDWebImage
import MessageUI
import SafariServices
import CloudKit

extension UIImageView {
    public func sd_setImageWithFade(url: URL?, placeholderImage placeholder: UIImage? = nil, options: SDWebImageOptions, completion: ((UIImage) -> Void)? = nil) {
        guard let url = url else {
            return
        }

        self.image = placeholder
        self.sd_setImage(with: url, placeholderImage: placeholder, options: options) { (image, error, cacheType, url) in
            if let downloadedImage = image {
                if cacheType == .none {
                    let prevAlpha = self.alpha
                    self.alpha = 0
                    UIView.transition(with: self, duration: 0.3, options: [.transitionCrossDissolve, .curveEaseInOut], animations: {
                        self.image = downloadedImage
                        self.alpha = prevAlpha
                    }, completion: nil)
                }
                completion?(downloadedImage)
            } else {
                self.image = placeholder
            }
        }
    }
}

extension UIApplication {
    var topViewController: UIViewController? {
        let keyWindow = UIApplication.shared.windows.filter { $0.isKeyWindow }.first

        if var topController = keyWindow?.rootViewController {
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }

            return topController
        }

        return nil
    }

    var versionAndBuildNumber: String {
        let appVersionString: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let buildNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        return "\(appVersionString) (\(buildNumber))"
    }
}

extension UIScreen {
    func heightMinusSafeArea() -> CGFloat {
        guard let window = UIApplication.shared.windows.first else {
            return bounds.height
        }

        return bounds.height - window.safeAreaInsets.top - window.safeAreaInsets.bottom
    }

    var safeAreaInsets: UIEdgeInsets {
        guard let window = UIApplication.shared.windows.first else {
            return .zero
        }

        return window.safeAreaInsets
    }
}

extension UIViewController {
    func openUrl(withString string: String) {
        guard let url = URL(string: string) else {
            return
        }

        let vc = SFSafariViewController(url: url)
        present(vc, animated: true, completion: nil)
    }

    func showSuccessToast(withTitle title: String,
                          image: UIImage? = UIImage(systemName: "checkmark.circle.fill")!,
                          description: String = "",
                          bottomInset: CGFloat = 60.0,
                          actionHandler: (() -> Void)? = nil) {
        let model = ToastView.Model(title: title,
                                    description: description,
                                    image: image,
                                    autohide: true,
                                    maxPerSession: 100)
        let toast = ToastView(model: model,
                              imageTint: .systemGreen,
                              borderTint: .systemGreen,
                              actionHandler: actionHandler)
        view.present(toast: toast,
                     insets: .init(top: 0, left: 0, bottom: bottomInset, right: 0))
    }

    func showFailureToast(with error: Error, bottomInset: CGFloat = 60.0) {
        let model = ToastView.Model(title: "Oops – that didn't work",
                                    description: "Tap to contact support",
                                    image: UIImage(systemName: "exclamationmark.triangle.fill"),
                                    autohide: true,
                                    maxPerSession: 100)
        let toast = ToastView(model: model, actionHandler: {
            if MFMailComposeViewController.canSendMail() {
                self.sendEmail(to: "support@anydistance.club",
                               subject: "Any Distance Error",
                               message: "",
                               attachment: "\(error)")
            } else {
                let activityVC = UIActivityViewController(activityItems: ["\(error)"],
                                                          applicationActivities: nil)
                UIApplication.shared.topViewController?.present(activityVC, animated: true)
            }
        })
        view.present(toast: toast,
                     insets: .init(top: 0, left: 0, bottom: bottomInset, right: 0))
    }

    func sendEmail(to address: String,
                   subject: String = "",
                   message: String = "",
                   attachment: String? = nil) {
        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = self
            mail.setSubject(subject)
            mail.setMessageBody(message, isHTML: false)
            mail.setToRecipients([address])
            mail.addAttachmentData(generateLogFile(), mimeType: "txt", fileName: "Log.txt")
            if let attachment = attachment,
               let data = attachment.data(using: .utf8) {
                mail.addAttachmentData(data, mimeType: "txt", fileName: "Request.txt")
            }
            present(mail, animated: true, completion: nil)
        } else {
            showMailError()
        }
    }

    func showMailError() {
        let alert = UIAlertController.defaultWith(title: "Oops",
                                                  message: "It looks like you haven't setup Apple Mail. Setup mail in settings, or use your favorite email app and email us at support@anydistance.club.")
        present(alert, animated: true, completion: nil)
    }

    func generateLogFile() -> Data {
        var file = "User ID: \(ADUser.current.id)\n"
        file.append("Build: \(Bundle.main.releaseVersionNumber) (\(Int(Bundle.main.buildVersionNumber)))\n")
        file.append("System version: \(UIDevice.current.systemVersion) on \(UIDevice.modelName)\n")
        file.append("Subscription: \(ADUser.current.subscriptionProductID ?? "Not subscribed")\n")
        file.append("Expires on: \(iAPManager.shared.formattedExpirationDate)\n")
        if let garminAuth = KeychainStore.shared.authorization(for: .garmin) {
            file.append("Garmin token: \(garminAuth.token)\n")
            file.append("Garmin refresh token: \(garminAuth.refreshToken)\n")
            file.append("Garmin secret: \(garminAuth.secret)\n")
        }
        if let wahooAuth = KeychainStore.shared.authorization(for: .wahoo) {
            file.append("Wahoo token: \(wahooAuth.token)\n")
            file.append("Wahoo refresh token: \(wahooAuth.refreshToken)\n")
            file.append("Wahoo secret: \(wahooAuth.secret)\n")
        }

        if let encodedUserStruct = try? JSONEncoder().encode(ADUser.current),
           let userStructString = String(data: encodedUserStruct, encoding: .utf8){
            file.append("\n\n---- Begin ADUser struct ----\n\n")
            file.append(userStructString)
        }

        print("SettingsViewController.generateLogFile: \(file)")
        return file.data(using: .utf8)!
    }
}

extension UIViewController: MFMailComposeViewControllerDelegate {
    public func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
}

extension CKRecord {
    func decode<T: Decodable>(fromKey key: String, asType type: T.Type) -> T? {
        if let string = self[key] as? String,
           let data = string.data(using: .utf8) {
            do {
                return try JSONDecoder().decode(type, from: data)
            } catch {
                print(error.localizedDescription)
            }
        }

        return nil
    }

    func decodeArray<T: Decodable>(fromKey key: String, asType type: T.Type) -> [T] {
        if let stringArray = self[key] as? [String] {
            let dataArray = stringArray.compactMap { $0.data(using: .utf8) }
            return dataArray.compactMap { try? JSONDecoder().decode(type, from: $0) }
        }

        return []
    }

    func encodeArray<T: Encodable>(_ array: [T], toKey key: String) {
        let stringArray: [String] = array.compactMap { item in
            if let encoded = try? JSONEncoder().encode(item),
               let string = String(data: encoded, encoding: .utf8) {
                return string
            }
            return nil
        }

        self[key] = stringArray
    }

    func encode<T: Encodable>(_ value: T, toKey key: String) {
        if let encoded = try? JSONEncoder().encode(value),
           let string = String(data: encoded, encoding: .utf8),
           string != "null" {
            self[key] = string
        } else {
            self[key] = nil
        }
    }
}
