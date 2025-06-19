// Licensed under the Any Distance Source-Available License
//
//  GoalViewController.swift
//  ADAC
//
//  Created by Daniel Kuntz on 12/23/20.
//

import UIKit
import UICountingLabel
import AVFoundation
import Combine

/// View controller showing details for a goal including percent complete & target date. Navigates
/// to screens for sharing and editing the goal.
final class GoalViewController: VisualGeneratingViewController {

    // MARK: - Outlets
    
    @IBOutlet weak var progressIndicator: CircularGoalProgressIndicator!
    @IBOutlet weak var activityTypeImageView: UIImageView!
    @IBOutlet weak var percentCompleteLabel: UILabel!
    @IBOutlet weak var distanceLabel: UICountingLabel!
    @IBOutlet weak var distanceTotalLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var shareProgressButton: UIButton!
    @IBOutlet weak var confettiView: ConfettiView!
    @IBOutlet var deleteBarButtonItem: UIBarButtonItem!
    @IBOutlet var editBarButtonItem: UIBarButtonItem!
    
    // MARK: - Variables

    var goal: Goal!

    var viewHasAppeared: Bool = false
    let screenName = "Goal"
    let player = try? AVAudioPlayer(contentsOf: Bundle.main.url(forResource: "applause", withExtension: "mp3")!)
    private var subscribers: Set<AnyCancellable> = []

    // MARK: - Setup

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setup()

        goal.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.setup()
                self?.animateIfNecessary()
            }.store(in: &subscribers)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateIfNecessary()
        Analytics.logEvent(screenName, screenName, .screenViewed)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.layer.zPosition = 0
    }

    func setup() {
        tabBarController?.tabBar.shadowImage = UIImage(named: "clear")

        if goal.isCompleted {
            navigationItem.rightBarButtonItems = [deleteBarButtonItem]
        } else {
            navigationItem.rightBarButtonItems = [editBarButtonItem]
        }

        let distanceGoal = goal?.targetDistanceInSelectedUnit ?? 100
        let distance = goal?.distanceInSelectedUnit ?? 1.0
        let progress = Int(((distance / Float(distanceGoal)) * 100).rounded())
        percentCompleteLabel.text = "\(progress)% Complete"

        distanceTotalLabel.text = "\(Int(distanceGoal))" + (goal?.unit.abbreviation.uppercased() ?? "MI")

        distanceLabel.animationDuration = (TimeInterval(progress) * 1.3).clamped(to: 0.5...2.5)
        distanceLabel.method = .easeInOut
        distanceLabel.formatBlock = { percent -> String in
            self.progressIndicator.progress = percent
            let roundedDistance = (percent * CGFloat(distanceGoal)).rounded(toPlaces: 1)

            if percent >= 1.0 {
                self.confettiView.startConfetti()
                self.navigationController?.navigationBar.layer.zPosition = -1
                self.confettiView.layer.zPosition = CGFloat.greatestFiniteMagnitude
            }

            return "\(roundedDistance)"
        }

        distanceLabel.completionBlock = {
            if progress >= 1 {
                self.player?.play()
            }
        }

        dateLabel.text = "By " + (goal?.endDate.formatted(withStyle: .medium) ?? "")
        activityTypeImageView.image = goal?.activityType.glyph
    }

    func animateIfNecessary() {
        let distanceGoal = goal?.targetDistanceInSelectedUnit ?? 100
        let distance = goal?.distanceInSelectedUnit ?? 0
        let progress = (distance / distanceGoal)

        if !viewHasAppeared {
            distanceLabel.countFromZero(to: CGFloat(progress))
            viewHasAppeared = true
        } else {
            distanceLabel.countFromCurrentValue(to: CGFloat(progress))
        }
    }
    
    @IBAction func shareProgressTapped(_ sender: Any) {
        showActivityIndicator()
        GoalShareImageGenerator.generateShareImages(self) { images in
            self.hideActivityIndicator()
            if let vc = UIStoryboard(name: "Activities", bundle: nil).instantiateViewController(withIdentifier: "shareVC") as? ShareViewController {
                vc.images = images
                vc.title = "Share Progress"
                self.present(vc, animated: true, completion: nil)
            }
        }
    }
    
    @IBAction func deleteTapped(_ sender: Any) {
        let alert = UIAlertController(title: "Are you sure you want to delete this forever?", message: nil, preferredStyle: .alert)
        let deleteAction = UIAlertAction(title: "Yes, Delete", style: .destructive) { (_) in
            ADUser.current.goals.removeAll(where: { $0 === self.goal })
            UserManager.shared.updateCurrentUser()
            UserDefaults.appGroup.updateGoalProgress()
            self.navigationController?.popViewController(animated: true)
        }
        let noAction = UIAlertAction(title: "No, Cancel", style: .cancel, handler: nil)
        alert.addActions([deleteAction, noAction])
        present(alert, animated: true, completion: nil)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        Analytics.logEvent("Edit Goal", screenName, .buttonTap)
        if let editGoalVC = segue.destination as? EditGoalViewController {
            editGoalVC.delegate = self
            editGoalVC.goal = goal
        }
    }
}

extension GoalViewController: EditGoalViewControllerDelegate {
    func updateUI() {}

    func dismiss() {
        navigationController?.popViewController(animated: true)
    }
}
