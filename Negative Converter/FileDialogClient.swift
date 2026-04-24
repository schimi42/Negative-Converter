//
//  FileDialogClient.swift
//  Negative Converter
//
//  Created by Michell Schimanski on 19.04.26.
//

import AppKit
import Foundation

nonisolated protocol FileDialogClient {
    @MainActor
    func selectExportFolder() -> URL?
}

nonisolated struct AppKitFileDialogClient: FileDialogClient {
    @MainActor
    func selectExportFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export"

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.url
    }
}
