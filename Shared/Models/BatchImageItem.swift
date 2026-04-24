//
//  BatchImageItem.swift
//  Negative Converter
//
//  Created by Michell Schimanski on 19.04.26.
//

import CoreGraphics
import Foundation

nonisolated struct BatchImageItem: Identifiable {
    let id = UUID()
    let url: URL?
    let assetIdentifier: String?
    var displayName: String
    var originalCGImage: CGImage
    var previewCGImage: CGImage?
    var convertedCGImage: CGImage?
    var crop: CropSettings = CropSettings()
    var usesSharedCrop = true
    var status: String

    var fileName: String {
        displayName
    }

    var outputFileName: String {
        let sourceName = url?.deletingPathExtension().lastPathComponent ?? displayName
        let baseName = sourceName.replacingOccurrences(of: " ", with: "-")
        return "\(baseName)-positive.png"
    }

    var isFromPhotosLibrary: Bool {
        assetIdentifier != nil
    }
}
