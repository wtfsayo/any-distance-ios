// Licensed under the Any Distance Source-Available License
//
//  AppDelegate.swift
//  ADAC
//
//  Created by Daniel Kuntz on 12/14/20.
//

import UIKit
import ffmpegkit
import AVFAudio
import Sentry
import Mixpanel
import SDWebImage
import OneSignal

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    
    private var activitiesAnalytics: ActivitiesAnalyticsObserver?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Remove this method to stop OneSignal Debugging
//        OneSignal.setLogLevel(.LL_VERBOSE, visualLevel: .LL_NONE)

        // Migrate to NSUbiquitousKeyValueStore if necessary
        UbiquitousKeyValueStoreMigrator.migrateIfNecessary()
        NSUbiquitousKeyValueStore.default.hasShownInitialPurchaseScreen = false

        Task(priority: .userInitiated) {
            await Edge.loadInitialAppState()
        }

        Task(priority: .userInitiated) {
            await ActivitiesData.shared.load()
        }

        if NSUbiquitousKeyValueStore.default.hasSetPushReminders {
            ReminderNotificationScheduler.schedule(with: NSUbiquitousKeyValueStore.default.pushReminders)
        }

        // OneSignal initialization
        OneSignal.initWithLaunchOptions(launchOptions)
        OneSignal.setExternalUserId(ADUser.current.id)
        print(ADUser.current.id)
        OneSignal.setEmail(ADUser.current.email)
        if let signupDate = ADUser.current.signupDate?.timeIntervalSince1970 {
            OneSignal.sendTag("signup_date", value: "\(signupDate)")
        }
        OneSignal.sendTag("app_configuration", value: Config.appConfiguration.rawValue)
        OneSignal.sendTag("num_friends", value: "\(ADUser.current.friendIDs.count)")
        OneSignal.sendTagsForTeamADAC()

        activitiesAnalytics = ActivitiesAnalyticsObserver(with: ActivitiesData.shared.$activities.eraseToAnyPublisher())
        activitiesAnalytics?.startObservingActivitiesForAnalytics()
        
        UNUserNotificationCenter.current().delegate = self
        _ = WatchPreferences.shared

        // Register fonts
        let fonts = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil)
        fonts?.forEach({ url in
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        })

        // Sentry
        let user = User()
        user.userId = ADUser.current.id
        user.username = ADUser.current.name
        user.email = ADUser.current.email
        if let garminAuth = KeychainStore.shared.authorization(for: .garmin) {
            user.data = [
                "garmin_access_token": garminAuth.token
            ]
        }
        SentrySDK.setUser(user)

        // Misc
        _ = iAPManager.shared
        _ = ScreenshotObserver.shared

        SDImageCache.shared.config.maxDiskSize = UInt(10e7) // 100 megabytes
        SDImageCache.shared.config.maxMemoryCount = 80

        FFmpegKit.load()

        NSUbiquitousKeyValueStore.default.set(false, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
        UserDefaults.appGroup.updateGoalProgress()

        UITabBarItem.appearance().setTitleTextAttributes([.foregroundColor: UIColor.adOrangeLighter], for: .selected)

        DispatchQueue.global(qos: .background).async {
            FileManager.default.clearTmpDirectory()
            // TODO: come back and check if we need this
            //            LegacyActivityDesignCache.deleteUnusedVideos()
        }
        
        Task {
            let migrator = LegacyActivityDesignMigrator()
            do {
                try await migrator.migrateActivityDesigns()
            } catch {
                SentrySDK.capture(error: error)
            }
        }
        
        ActivitiesData.shared.startObservingNewActivitiesForAuthorizedProviders()

        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        
        NSUbiquitousKeyValueStore.default.numberOfAppLaunches += 1
        
        return true
    }
    
    // MARK: Notifications
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("didRegisterForRemoteNotificationsWithDeviceToken: \(token)")
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard let urlString = (userInfo["custom"] as? [String: Any])?["u"] as? String,
              let url = URL(string: urlString),
              let scheme = url.scheme, let host = url.host,
              scheme.localizedCaseInsensitiveCompare("anydistance") == .orderedSame,
              let urlType = AnyDistanceURL.URLType(rawValue: host) else {
            completionHandler(.noData)
            return
        }

        var parameters: [String: String] = [:]
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.forEach {
            parameters[$0.name] = $0.value
        }
        let adURL = AnyDistanceURL(type: urlType, parameters: parameters)

        switch adURL.type {
        case .post:
            guard let postID = adURL.postID else { break }
            Task(priority: .userInitiated) {
                _ = try await PostManager.shared.getPost(by: postID)
                completionHandler(.newData)
                return
            }
        default:
            break
        }

        completionHandler(.noData)
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        if let type = userInfo["type"] as? String, type == "trackActivity" {
            let url = AnyDistanceURL(type: .trackActivity, parameters: [:])
            AnyDistanceURLHandler.shared.handle(adURL: url)
        } else if let activityId = userInfo["activityId"] as? String {
            let activityURL = AnyDistanceURL(type: .activity, parameters: ["activityId": activityId])
            AnyDistanceURLHandler.shared.handle(adURL: activityURL)
        }
        
        completionHandler()
    }
        
}
