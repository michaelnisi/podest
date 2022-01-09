//
//  PodestApp.swift
//  Shared
//
//  Created by Michael Nisi on 09.01.22.
//

import SwiftUI

@main
struct PodestApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
