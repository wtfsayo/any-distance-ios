// Licensed under the Any Distance Source-Available License
//
//  SettingsConnectViewController.swift
//  ADAC
//
//  Created by Daniel Kuntz on 1/14/21.
//

import UIKit

protocol SettingsConnectViewControllerDelegate: AnyObject {
    func stravaConnectedSuccessfully()
}

final class SettingsConnectViewController: UIViewController {

    // MARK: - Outlets
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var helpButton: UIButton!
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var connectionTypeLabel: UILabel!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var bottomButtonPromptLabel: UILabel!
    @IBOutlet weak var bottomButton: UIButton!

    // MARK: - Variables

    weak var delegate: SettingsConnectViewControllerDelegate?
    var source: HealthKitWorkoutSource = .strava

    var connectionState: SettingsConnectState {
        switch source {
        case .strava:
            return .stravaConnected
        default:
            return .appleHealth
        }
    }

    // MARK: - Setup

    override func viewDidLoad() {
        super.viewDidLoad()
        updateState()
    }

    func updateState() {
        helpButton.isHidden = source == .strava

        switch connectionState {
        case .stravaConnected:
            titleLabel.text = "Strava"
            icon.image = UIImage(named: "glyph_strava_big")
            connectionTypeLabel.text = "Strava"
            messageLabel.text = "Already connected to Any Distance."
            bottomButtonPromptLabel.isHidden = true
            bottomButton.setTitle("Disconnect", for: .normal)
            bottomButton.setImage(nil, for: .normal)
            bottomButton.backgroundColor = .white
        case .stravaNotConnected:
            titleLabel.text = "Strava"
            icon.image = UIImage(named: "glyph_strava_big")
            connectionTypeLabel.text = "Compatible with Strava"
            messageLabel.text = "Any Distance needs permission to read your Strava data for activities.\n\nWe only read the data needed and do not sell or store it."
            bottomButtonPromptLabel.isHidden = true
            bottomButton.setTitle("", for: .normal)
            bottomButton.setImage(UIImage(named: "button_connect_strava_ugly"), for: .normal)
            bottomButton.backgroundColor = .clear
        case .appleHealth:
            titleLabel.text = "Apple Health"
            icon.image = UIImage(named: "glyph_applehealth_big")
            connectionTypeLabel.text = "Apple Health"
            messageLabel.text = "Any Distances needs permission to read your Health data for activities.\n\nWe only read the data needed and do not sell or store it.\n\nTo change permissions, go to Settings > Health > Data Access & Devices > Any Distance"
            bottomButtonPromptLabel.isHidden = true
            bottomButton.setTitle("Open Settings", for: .normal)
            bottomButton.setImage(nil, for: .normal)
            bottomButton.backgroundColor = .white
        }
    }

    // MARK: - Actions

    @IBAction func bottomButtonTapped(_ sender: Any) {
        switch connectionState {
        case .stravaConnected:
            UserManager.shared.updateCurrentUser()
            dismiss(animated: true, completion: nil)
            NotificationCenter.default.post(.connectionStateChanged)
        case .stravaNotConnected:
            break
        case .appleHealth:
            if let url = URL(string: "App-Prefs:") {
                UIApplication.shared.open(url)
            }
        }
    }
    
    @IBAction func helpTapped(_ sender: Any) {
        openUrl(withString: Links.connectingServices.absoluteString)
    }

    @IBAction func cancelTapped(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}

enum SettingsConnectState {
    case stravaConnected
    case stravaNotConnected
    case appleHealth
}
