// Licensed under the Any Distance Source-Available License
//
//  SceneDelegate.swift
//  ADAC
//
//  Created by Daniel Kuntz on 12/14/20.
//

import UIKit
import OAuthSwift
import Combine
import SafariServices
import SwiftUI
import Mixpanel
import OneSignal

extension UIViewController {
    func asyncDismiss() async {
        await withCheckedContinuation { continuation in
            dismiss(animated: false) {
                continuation.resume(returning: ())
            }
        }
    }
    
    func asyncDismissAnyModal() async {
        if let presentingVC = UIApplication.shared.topmostViewController?.presentingViewController {
            await presentingVC.asyncDismiss()
            await asyncDismissAnyModal()
        }
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var subscribers: Set<AnyCancellable> = []

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let _ = (scene as? UIWindowScene) else { return }

        #if targetEnvironment(simulator)
        ADUser.current.id = "sim"
        ADUser.current.distanceUnit = .miles

        let showOnboarding = true

        if showOnboarding {
            guard let windowScene = (scene as? UIWindowScene) else { return }
            let window = UIWindow(windowScene: windowScene)
            let vc = OnboardingViewController()
            window.rootViewController = vc
            self.window = window
            window.makeKeyAndVisible()
        } else {
            guard let windowScene = (scene as? UIWindowScene) else { return }
            let window = UIWindow(windowScene: windowScene)
            let mainTabBar = UIStoryboard(name: "TabBar", bundle: nil).instantiateViewController(withIdentifier: "mainTabBar")
            window.rootViewController = mainTabBar
            self.window = window
            window.makeKeyAndVisible()
        }
        #else
        if ADUser.current.hasFinishedOnboarding {
            guard let windowScene = (scene as? UIWindowScene) else { return }
            let window = UIWindow(windowScene: windowScene)
            let mainTabBar = UIStoryboard(name: "TabBar", bundle: nil).instantiateViewController(withIdentifier: "mainTabBar") as? ADTabBarController
            mainTabBar?.setSelectedTab(.track)
            window.rootViewController = mainTabBar

            if let shortcutItem = connectionOptions.shortcutItem,
               let tabBar = mainTabBar?.tabBar as? ADTabBar {
                tabBar.shortcutItem = shortcutItem
            }

            self.window = window
            window.makeKeyAndVisible()
        } else {
            guard let windowScene = (scene as? UIWindowScene) else { return }
            let window = UIWindow(windowScene: windowScene)
            let vc = OnboardingViewController()
            window.rootViewController = vc
            self.window = window
            window.makeKeyAndVisible()
        }
        #endif

        let topMostVC = UIApplication.shared.topmostViewController

        let willRestoreState = NSUbiquitousKeyValueStore.default.activityRecorderState != nil
        guard !willRestoreState else {
            return
        }

        if connectionOptions.urlContexts.isEmpty && connectionOptions.shortcutItem == nil {
            UIApplication.shared.topViewController?.showLaunchSequence()
        }
        
        AnyDistanceURLHandler.shared.handleURL
            .receive(on: DispatchQueue.main)
            .sink { [weak self] url in
                guard let self = self else { return }

                let screenName = "Push Notifications"
                                
                switch url.type {
                case .activity, .activities:
                    ADTabBarController.current?.setSelectedTab(.you)

                    if url.type == .activity {
                        Task {
                            guard let activity = await url.activity else {
                                return
                            }
                            
                            await topMostVC?.asyncDismissAnyModal()
                            
                            DispatchQueue.main.async {
                                Analytics.logEvent("Notification Tapped - Activity Synced", screenName, .buttonTap)
                                UIApplication.shared.topViewController?.showPostDraft(for: activity)
                            }
                        }
                    }
                case .goals:
                    ADTabBarController.current?.setSelectedTab(.you)
                case .trackActivity:
                    Task {
                        await topMostVC?.asyncDismissAnyModal()
                        
                        let activityType = url.activityType
                        
                        DispatchQueue.main.async {
                            ADTabBarController.current?.setSelectedTab(.track)
                            ADTabBar.current?.startActivityFromURL(type: activityType,
                                                                   goalType: url.goalType,
                                                                   goalTarget: url.goalTarget)
                            Analytics.logEvent("Notification Tapped - Start Activity", screenName, .buttonTap)
                        }
                    }
                case .collectibles, .collectible:
                    Task {
                        guard let collectibleTypeRawValue = url.collectibleTypeRawValue else {
                            return
                        }

                        if collectibleTypeRawValue.hasPrefix("remote") &&
                           CollectibleType(rawValue: collectibleTypeRawValue) == nil {
                            // Fetch collectibles from CloudKit if we can't find this one
                            await CollectibleLoader.shared.loadCollectibles()
                        }
                        await topMostVC?.asyncDismissAnyModal()
                        
                        DispatchQueue.main.async {
                            let storyboard = UIStoryboard(name: "Collectibles", bundle: nil)
                            guard let vc = storyboard.instantiateViewController(withIdentifier: "collectibleDetail") as? CollectibleDetailViewController else {
                                return
                            }

                            if let collectible = ADUser.current.collectibles
                                .first(where: { $0.type.rawValue == collectibleTypeRawValue }) {
                                vc.collectible = collectible
                                vc.collectibleEarned = true
                            } else if let type = CollectibleType(rawValue: collectibleTypeRawValue) {
                                vc.collectible = Collectible(type: type, dateEarned: Date())
                                vc.collectibleEarned = false
                            } else {
                                return
                            }

                            UIApplication.shared.topViewController?.present(vc, animated: true) {
                                if url.showAR {
                                    vc.arTapped(0)
                                }
                            }
                            
                            Analytics.logEvent("Notification Tapped - Collectible",
                                               screenName, .buttonTap,
                                               withParameters: ["collectibleRawValue": collectibleTypeRawValue])
                        }
                    }
                case .settings:
                    Analytics.logEvent("Notification Tapped - Settings", screenName, .buttonTap)
                case .externalURL:
                    guard let externalURL = url.externalURL else { break }

                    Task {
                        await topMostVC?.asyncDismissAnyModal()
                     
                        DispatchQueue.main.async {
                            let vc = SFSafariViewController(url: externalURL)
                            UIApplication.shared.topViewController?.present(vc, animated: true, completion: nil)
                            Analytics.logEvent("Notification Tapped - External URL", screenName, .buttonTap)
                        }
                    }
                case .post:
                    guard let postID = url.postID,
                          PostManager.shared.currentUserHasPostedThisWeek else { break }

                    Task {
                        guard let post = try? await PostManager.shared.getPost(by: postID) else {
                            return
                        }

                        await topMostVC?.asyncDismissAnyModal()

                        DispatchQueue.main.async {
                            UIApplication.shared.topViewController?.showPost(post)
                            Analytics.logEvent("Notification Tapped - Post", screenName, .buttonTap)
                        }
                    }
                case .friends:
                    let selectedSegment = url.friendsTabSelectedSegment

                    Task {
                        await topMostVC?.asyncDismissAnyModal()

                        let hostingView = UIHostingController(rootView: FriendManagerView(selectedSegment: selectedSegment))
                        DispatchQueue.main.async {
                            UIApplication.shared.topViewController?.present(hostingView, animated: true)
                            Analytics.logEvent("Notification Tapped - Friends", screenName, .buttonTap)
                        }
                    }
                case .profile:
                    guard let username = url.username else { break }

                    Task {
                        let user = try? await UserManager.shared.searchUsers(by: username)
                            .first(where: { $0.username == username })
                        guard let user = user else {
                            return
                        }

                        await topMostVC?.asyncDismissAnyModal()

                        let hostingView = UIHostingController(rootView: ProfileView(model: ProfileViewModel(user: user),
                                                                                    presentedInSheet: true))
                        DispatchQueue.main.async {
                            UIApplication.shared.topViewController?.present(hostingView, animated: true)
                            Analytics.logEvent("Open Profile Deep Link", screenName, .buttonTap)
                        }
                    }
                }
            }
            .store(in: &subscribers)

        for urlContext in connectionOptions.urlContexts {
            let _ = AnyDistanceURLHandler.shared.handle(url: urlContext.url)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else {
            print("No URL")
            return
        }
        
        if AnyDistanceURLHandler.shared.handle(url: url) {
            print("Opening URL: \(url)")
        } else {
            OAuthSwift.handle(url: url)
        }
    }

    func windowScene(_ windowScene: UIWindowScene,
                     performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        if let tabBar = (window?.rootViewController as? UITabBarController)?.tabBar as? ADTabBar {
            tabBar.handleShortcut(shortcutItem)
        }
        completionHandler(true)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
        setShortcutItems()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
        setShortcutItems()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }

    private func setShortcutItems() {
        let feedbackItem = UIApplicationShortcutItem(type: "feedback", 
                                                     localizedTitle: "Something wrong?",
                                                     localizedSubtitle: "Please leave us feedback before deleting!",
                                                     icon: UIApplicationShortcutIcon(systemImageName: "heart.fill"))

        UIApplication.shared.shortcutItems = [feedbackItem]
    }
}

