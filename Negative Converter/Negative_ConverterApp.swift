//
//  Negative_ConverterApp.swift
//  Negative Converter
//
//  Created by Michell Schimanski on 19.04.26.
//

import SwiftUI

@main
struct Negative_ConverterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let urls = filenames.map { URL(fileURLWithPath: $0) }
        NotificationCenter.default.post(name: .openedImageURLs, object: nil, userInfo: ["urls": urls])
        sender.reply(toOpenOrPrint: .success)
    }
}

extension Notification.Name {
    static let openedImageURLs = Notification.Name("openedImageURLs")
}
