// Licensed under the Any Distance Source-Available License
//
//  NoRouteViewController.swift
//  ADAC
//
//  Created by Daniel Kuntz on 6/28/21.
//

import UIKit
import MessageUI
import SwiftRichString

/// UIViewController that alerts the user that the given activity does not have route data and prompts
/// the user to email the developer of the source app for the activity.
final class NoRouteViewController: UIViewController {

    // MARK: - Outlets

    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var emailButton: ContinuousCornerButton!

    // MARK: - Variables

    var source: HealthKitWorkoutSource?

    // MARK: - Setup

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    func setup() {
        guard let source = source else {
            return
        }

        let normal = Style { $0.font = UIFont.systemFont(ofSize: 16) }
        let bold = Style { $0.font = UIFont.systemFont(ofSize: 16, weight: .bold) }
        let group = StyleXML(base: normal, ["bold": bold])
        let string = label.text?.replacingOccurrences(of: "[SOURCE]", with: "<bold>" + source.name + "</bold>")
        label.attributedText = string?.set(style: group)

        if source == .nikeRunClub {
            emailButton.setTitle("Message NRC on Instagram", for: .normal)
        } else {
            let buttonTitle = emailButton.title(for: .normal)?.replacingOccurrences(of: "[SOURCE]", with: source.name)
            emailButton.setTitle(buttonTitle, for: .normal)
        }
    }

    // MARK: - Actions

    @IBAction func closeTapped(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }

    @IBAction func learnMoreTapped(_ sender: Any) {
        openUrl(withString: Links.connectingServices.absoluteString)
    }

    @IBAction func emailTapped(_ sender: Any) {
        guard let source = source else {
            return
        }

        if source.contactIsLink {
            openUrl(withString: source.contact)
            return
        }

        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = self
            mail.setToRecipients([source.contact])
            mail.setMessageBody(source.emailBody, isHTML: true)
            mail.setSubject("Apple Health Route Data")
            present(mail, animated: true, completion: nil)
        } else {
            let alert = UIAlertController.defaultWith(title: "Oops", message: "It looks like you haven't setup Apple Mail. Setup mail in settings, or use your favorite email app and email \(source.name) at \(source.contact).")
            present(alert, animated: true, completion: nil)
        }
    }
}
