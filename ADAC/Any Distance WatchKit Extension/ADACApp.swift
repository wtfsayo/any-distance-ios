// Licensed under the Any Distance Source-Available License
//
//  ADACApp.swift
//  Any Distance WatchKit Extension
//
//  Created by Any Distance on 8/16/22.
//

import SwiftUI

@main
struct ADACApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationView {
                ActivitiesListView()
            }
        }
    }
}
