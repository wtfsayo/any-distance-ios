// Licensed under the Any Distance Source-Available License
//
//  AllGoalsViewController.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/20/21.
//

import UIKit
import AuthenticationServices

/// View controller that shows a list of goals, completed and uncompleted
final class AllGoalsViewController: UITableViewController {

    // MARK: - Variables

    var activeGoals: [Goal] = []
    var completedGoals: [Goal] = []
    private let generator = UIImpactFeedbackGenerator(style: .medium)

    // MARK: - Setup

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    func setup() {
        navigationController?.navigationBar.setValue(true, forKey: "hidesShadow")
        navigationController?.navigationBar.isTranslucent = false
        extendedLayoutIncludesOpaqueBars = true

        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }

        refreshControl = UIRefreshControl()
        tableView.refreshControl = refreshControl
        refreshControl?.addTarget(self, action: #selector(pullAndReload), for: .valueChanged)

        reload()
    }

    @objc func pullAndReload() {
        Task {
            await UserManager.shared.fetchCurrentUser()
            DispatchQueue.main.async {
                self.reload()
                self.refreshControl?.endRefreshing()
            }
        }
    }

    func reload() {
        let allGoals = ADUser.current.goals ?? []
        activeGoals = allGoals.filter { !$0.isCompleted }
        completedGoals = allGoals.filter { $0.isCompleted }

        if activeGoals.isEmpty && completedGoals.isEmpty {
            // Set empty state if necessary.
            let emptyStateView = TableViewEmptyStateView()
            emptyStateView.label.text = "Looks like you don’t have any goals yet. Add one or more when you are ready."
            emptyStateView.bigLabel.text = nil
            emptyStateView.imageView.image = UIImage(named: "glyph_goal_big")
            emptyStateView.button.setTitle("Start New Goal", for: .normal)
            emptyStateView.buttonHandler = {
                self.showNewGoalOrSignIn()
            }
            tableView.backgroundView = emptyStateView
            tableView.isScrollEnabled = false
        } else {
            tableView.backgroundView = nil
            tableView.isScrollEnabled = true
        }

        tableView.reloadData()
    }

    @IBAction func newGoalTapped(_ sender: Any) {
        showNewGoalOrSignIn()
    }

    func showNewGoalOrSignIn() {
        performSegue(withIdentifier: "allGoalsToNewGoal", sender: nil)
    }

    // MARK: - Table View

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: GoalTableViewCell.reuseId) as? GoalTableViewCell {
            cell.setGoal([activeGoals, completedGoals][indexPath.section][indexPath.row])
            return cell
        }

        return UITableViewCell()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        generator.impactOccurred()
        performSegue(withIdentifier: "allGoalsToGoalDetail",
                     sender: [activeGoals, completedGoals][indexPath.section][indexPath.row])
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? activeGoals.count : completedGoals.count
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if activeGoals.isEmpty && completedGoals.isEmpty {
            return UIView()
        }

        if completedGoals.isEmpty {
            return section == 0 ? TableViewHeader(title: "Active") : UIView()
        }

        return TableViewHeader(title: section == 0 ? "Active" : "Completed")
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "allGoalsToGoalDetail",
           let goalVC = segue.destination as? GoalViewController,
           let goal = sender as? Goal {
            goalVC.goal = goal
        }

        if segue.identifier == "allGoalsToNewGoal",
           let createGoalVC = segue.destination as? EditGoalViewController {
            createGoalVC.mode = .createGoal
            createGoalVC.delegate = self
        }
    }
}

extension AllGoalsViewController: SignInViewControllerDelegate {
    func authorizationController(didCompleteWithAuthorization authorization: ASAuthorization) {}
}

extension AllGoalsViewController: EditGoalViewControllerDelegate {
    func updateUI() {
        UIView.transition(with: tableView, duration: 0.2, options: [.transitionCrossDissolve], animations: {
            self.reload()
        }, completion: nil)
    }

    func dismiss() {}
}
