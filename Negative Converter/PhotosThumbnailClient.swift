//
//  PhotosThumbnailClient.swift
//  Negative Converter
//
//  Created by Michell Schimanski on 19.04.26.
//

import AppKit
import CoreGraphics
import Foundation
import Photos

nonisolated protocol PhotosThumbnailClient {
    func thumbnail(for item: PhotosLibraryItem, targetSize: CGSize) async -> CGImage?
}

nonisolated final class PhotoKitThumbnailClient: PhotosThumbnailClient {
    private let manager = PHCachingImageManager()

    func thumbnail(for item: PhotosLibraryItem, targetSize: CGSize) async -> CGImage? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [item.id], options: nil).firstObject else {
            return nil
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        return await withCheckedContinuation { continuation in
            manager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image?.cgImage)
            }
        }
    }
}

private extension NSImage {
    var cgImage: CGImage? {
        var proposedRect = NSRect(origin: .zero, size: size)
        return cgImage(forProposedRect: &proposedRect, context: nil, hints: nil)
    }
}
