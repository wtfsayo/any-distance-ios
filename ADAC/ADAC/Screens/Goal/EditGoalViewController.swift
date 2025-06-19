// Licensed under the Any Distance Source-Available License
//
//  EditGoalViewController.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/20/21.
//

import UIKit

<<<<<<<< HEAD:ADAC/ADAC/View Controllers/Progress/EditGoalViewController.swift
========
protocol EditGoalViewControllerDelegate: AnyObject {
    func dismiss()
    func updateUI()
}

/// View controller that allows the user to create or edit a goal.
>>>>>>>> develop:ADAC/ADAC/Screens/Goal/EditGoalViewController.swift
final class EditGoalViewController: UIViewController {

    // MARK: - Outlets

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var activityTypeGlyph: UIImageView!
    @IBOutlet weak var activityTypeButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var unitSegmentedControl: UISegmentedControl!
    @IBOutlet weak var distanceField: NoActionsTextField!
    @IBOutlet weak var startDatePickerBackgroundView: UIView!
    @IBOutlet weak var startDatePicker: UIDatePicker!
    @IBOutlet weak var targetDatePickerBackgroundView: UIView!
    @IBOutlet weak var targetDatePicker: UIDatePicker!
    @IBOutlet weak var bottomButton: UIButton!
    @IBOutlet weak var bottomButtonBottomConstraint: NSLayoutConstraint!

    // MARK: - Variables

    var mode: EditGoalViewControllerMode = .editGoal
    let screenName = "Edit Goal"

    var goal: Goal = Goal.new()
    var unit: DistanceUnit!
    var distanceMeters: Float!
    var doneHandler: ((Goal) -> Void)?

    var selectedActivityType: ActivityType = .run {
        didSet {
            activityTypeButton.setTitle(selectedActivityType.displayName, for: .normal)
            activityTypeGlyph.image = selectedActivityType.glyph
        }
    }

    // MARK: - Setup

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        Analytics.logEvent(screenName, screenName, .screenViewed)
    }

    func setup() {
        let titleTextAttributes: [NSAttributedString.Key : Any] = [.foregroundColor : UIColor.white]
        unitSegmentedControl?.setTitleTextAttributes(titleTextAttributes, for: .normal)
        unitSegmentedControl?.setTitleTextAttributes(titleTextAttributes, for: .selected)

        if #available(iOS 15.0, *) {
            startDatePickerBackgroundView.isHidden = true
            targetDatePickerBackgroundView.isHidden = true
        } else {
            // Hide UIDatePicker background view that I can't change the width of.
            if let platter = targetDatePicker.subviews.first?.value(forKey: "_dateBackgroundPlatter") as? UIView {
                platter.isHidden = true
            }

            if let platter = startDatePicker.subviews.first?.value(forKey: "_dateBackgroundPlatter") as? UIView {
                platter.isHidden = true
            }
        }

        let tapGR = UITapGestureRecognizer(target: self, action: #selector(viewTapped(_:)))
        view.addGestureRecognizer(tapGR)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillShow(_:)),
                                               name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillHide(_:)),
                                               name: UIResponder.keyboardWillHideNotification, object: nil)

        unit = goal.unit
        distanceMeters = goal.distanceMeters

        distanceField.delegate = self
        distanceField.tintColor = .adYellow

        distanceField.text = "\(Int(goal.targetDistanceInSelectedUnit)) \(goal.unit.abbreviation)"
        unitSegmentedControl.selectedSegmentIndex = goal.unit.rawValue

        startDatePicker.date = goal.startDate
        targetDatePicker.date = goal.endDate

        startDatePicker.maximumDate = Date()
        if mode == .editGoal {
            targetDatePicker.minimumDate = Calendar.current.date(byAdding: .day, value: 1, to: goal.startDate)!
        }

        selectedActivityType = goal.activityType

        let menuItems: [UIAction] = ActivityType.allCasesThatAllowGoals.reversed().map { type in
            return UIAction(title: type.displayName, image: type.glyph) { [weak self] action in
                self?.selectedActivityType = type
            }
        }
        let menu = UIMenu(title: "", image: nil, identifier: nil, options: [], children: menuItems)
        activityTypeButton.menu = menu
        activityTypeButton.showsMenuAsPrimaryAction = true

        if mode == .createGoal {
            titleLabel.text = "New Goal"
            deleteButton.isHidden = true
            bottomButton.setTitle("Set Goal", for: .normal)
        }
    }

    // MARK: - Keyboard

    @objc func keyboardWillShow(_ notification: Notification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            if bottomButtonBottomConstraint.constant == 20 {
                bottomButtonBottomConstraint.constant = keyboardSize.height - 20
                UIView.animate(withDuration: 0.4) {
                    self.view.layoutIfNeeded()
                }
            }
        }
    }

    @objc func keyboardWillHide(_ notification: Notification) {
        if bottomButtonBottomConstraint.constant != 20 {
            bottomButtonBottomConstraint.constant = 20
            UIView.animate(withDuration: 0.4) {
                self.view.layoutIfNeeded()
            }
        }
    }

    @objc func viewTapped(_ gestureRecognizer: UITapGestureRecognizer) {
        distanceField.resignFirstResponder()
    }

    // MARK: - Actions

    @IBAction func datePickerBeginEditing(_ sender: UIDatePicker) {
        sender.tintColor = UIColor.white.withAlphaComponent(0.3)
        sender.layoutIfNeeded()
    }

    @IBAction func datePickerEndEditing(_ sender: UIDatePicker) {
        sender.tintColor = UIColor.white
        targetDatePicker.minimumDate = Calendar.current.date(byAdding: .day, value: 1, to: startDatePicker.date)!
    }

    @IBAction func activityTypeButtonTapped(_ sender: Any) {
    }

    @IBAction func unitSegmentedControlChanged(_ sender: UISegmentedControl) {
        unit = sender.selectedSegmentIndex == 0 ? .miles : .kilometers

        if !distanceField.isFirstResponder {
            let distanceInUnit = UnitConverter.meters(goal.distanceMeters, toUnit: unit)
            distanceField.text = "\(Int(distanceInUnit)) \(unit.abbreviation)"
        }
    }

    @IBAction func editCancelTapped(_ sender: Any) {
        dismiss(animated: true, completion: nil)
        Analytics.logEvent("Cancel", screenName, .buttonTap)
    }

    @IBAction func editDeleteTapped(_ sender: Any) {
        let alert = UIAlertController(title: "Are you sure you want to delete this forever?", message: nil, preferredStyle: .alert)
        let deleteAction = UIAlertAction(title: "Yes, Delete", style: .destructive) { (_) in
            ADUser.current.goals.removeAll(where: { $0 === self.goal })
            UserDefaults.appGroup.updateGoalProgress()
            UserManager.shared.updateCurrentUser()
            let presenting = self.presentingViewController
            self.dismiss(animated: true) {
                presenting?.dismiss(animated: true)
            }
        }
        let noAction = UIAlertAction(title: "No, Cancel", style: .cancel, handler: nil)
        alert.addActions([deleteAction, noAction])
        present(alert, animated: true, completion: nil)
    }

    @IBAction func setGoalTapped(_ sender: Any) {
        Analytics.logEvent("Set Goal", screenName, .buttonTap)
        distanceField.resignFirstResponder()

        goal.activityType = selectedActivityType
        goal.distanceMeters = distanceMeters
        goal.unit = unitSegmentedControl.selectedSegmentIndex == 0 ? .miles : .kilometers
        goal.startDate = Calendar.current.startOfDay(for: startDatePicker.date)
        goal.endDate = Calendar.current.startOfDay(for: targetDatePicker.date)

        Task {
            await goal.calculateCurrentDistanceMetersForAllActivities()

            DispatchQueue.main.async {
                self.goal.markAsCompletedIfNecessary()
                self.goal.objectWillChange.send()

                switch self.mode {
                case .editGoal:
                    break
                case .createGoal:
                    ADUser.current.goals.append(self.goal)
                    ADUser.current.goals.sort(by: { $0.endDate < $1.endDate })
                }

                Task {
                    await UserManager.shared.updateCurrentUser()
                    UserDefaults.appGroup.updateGoalProgress()
                    NotificationCenter.default.post(.goalTypeChanged)
                }

                self.dismiss(animated: true) {
                    self.doneHandler?(self.goal)
                }
            }
        }
    }

    @IBAction func viewUnderneathTapped(_ sender: Any) {
        if !distanceField.isFirstResponder {
            dismiss(animated: true, completion: nil)
        }
    }
}

extension EditGoalViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        let distanceInUnit = UnitConverter.meters(distanceMeters, toUnit: unit)
        textField.text = "\(Int(distanceInUnit))"
        textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument,
                                                          to: textField.endOfDocument)
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let maxLength = 6
        let curString = (textField.text ?? "") as NSString
        let newString = curString.replacingCharacters(in: range, with: string)
        return newString.count <= maxLength
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if let text = textField.text,
           let distance = Float(text) {
            let distanceM = UnitConverter.value(distance, inUnitToMeters: unit)
            distanceMeters = max(distanceM, 1000)
        }
        let distanceInUnit = UnitConverter.meters(distanceMeters, toUnit: unit)
        textField.text = "\(Int(distanceInUnit)) \(unit.abbreviation)"
    }
}

enum EditGoalViewControllerMode {
    case editGoal
    case createGoal
}
