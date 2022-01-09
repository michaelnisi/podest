//
//  PodestApp.swift
//  Watch WatchKit Extension
//
//  Created by Michael Nisi on 09.01.22.
//

import SwiftUI

@main
struct PodestApp: App {
    @SceneBuilder var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
            }
        }

        WKNotificationScene(controller: NotificationController.self, category: "myCategory")
    }
}
