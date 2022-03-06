//
//  PodestApp.swift
//  Podest WatchKit Extension
//
//  Created by Michael Nisi on 15.01.22.
//

import SwiftUI

@main
struct PodestApp: App {
    @SceneBuilder var body: some Scene {
        WindowGroup {
          ContentView()
        }

        WKNotificationScene(controller: NotificationController.self, category: "myCategory")
    }
}
