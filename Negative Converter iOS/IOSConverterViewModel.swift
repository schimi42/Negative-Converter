//
//  IOSConverterViewModel.swift
//  Lumirio Negative Converter iOS
//
//  Created by Michell Schimanski on 24.04.26.
//

import Combine
import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import Photos
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct IOSImageItem: Identifiable {
    let id = UUID()
    var assetIdentifier: String?
    var title: String
    var originalCGImage: CGImage
    var convertedCGImage: CGImage?
}

private struct IOSEditedPhoto {
    var asset: PHAsset
    var output: PHContentEditingOutput
}

struct IOSPickedImageFile: Transferable {
    var data: Data
    var filename: String?

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { receivedFile in
            let data = try Data(contentsOf: receivedFile.file)
            return IOSPickedImageFile(
                data: data,
                filename: receivedFile.file.lastPathComponent
            )
        }
    }
}

@MainActor
final class IOSConverterViewModel: ObservableObject {
    @Published var items: [IOSImageItem] = []
    @Published var selectedID: IOSImageItem.ID?
    @Published var isImporting = false
    @Published var isSaving = false
    @Published var needsFullPhotosAccess = false
    @Published var message = "Choose photos to start converting."

    private nonisolated static let context = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any])

    var selectedItem: IOSImageItem? {
        guard let selectedID else {
            return items.first
        }

        return items.first { $0.id == selectedID } ?? items.first
    }

    var canSaveSelected: Bool {
        selectedItem?.convertedCGImage != nil
    }

    var canSaveAll: Bool {
        items.contains { $0.convertedCGImage != nil }
    }

    var canChoosePhotos: Bool {
        !isImporting && !needsFullPhotosAccess
    }

    func preparePhotoLibraryAccess() async {
        _ = await requestFullPhotoLibraryAccess()
    }

    func importPhotos(from pickerItems: [PhotosPickerItem]) async {
        guard !pickerItems.isEmpty else {
            return
        }

        guard await requestFullPhotoLibraryAccess() else {
            return
        }

        isImporting = true
        defer {
            isImporting = false
        }

        var importedItems: [IOSImageItem] = []

        for (index, pickerItem) in pickerItems.enumerated() {
            do {
                let assetIdentifier = pickerItem.itemIdentifier
                guard let pickedFile = try await pickerItem.loadTransferable(type: IOSPickedImageFile.self),
                      let originalImage = Self.cgImage(from: pickedFile.data) else {
                    continue
                }

                let convertedImage = try NegativeImageProcessor.invertedCGImage(from: originalImage)
                let title = Self.displayTitle(from: pickedFile.filename, fallbackIndex: index)
                importedItems.append(IOSImageItem(
                    assetIdentifier: assetIdentifier,
                    title: title,
                    originalCGImage: originalImage,
                    convertedCGImage: convertedImage
                ))
            } catch {
                message = "Could not import one of the selected photos."
            }
        }

        guard !importedItems.isEmpty else {
            message = "No supported photos could be imported."
            return
        }

        items = importedItems
        selectedID = importedItems.first?.id
        message = importedItems.count == 1 ? "Converted 1 photo." : "Converted \(importedItems.count) photos."
    }

    func saveSelectedToPhotos() async {
        guard let item = selectedItem else {
            return
        }

        guard item.assetIdentifier != nil else {
            message = "This photo cannot be updated because iOS did not provide an editable Photos asset."
            return
        }

        await saveEditsToPhotos([item])
    }

    func saveAllToPhotos() async {
        let editableItems = items.filter { $0.assetIdentifier != nil && $0.convertedCGImage != nil }
        guard !editableItems.isEmpty else {
            message = "None of the selected photos can be updated because iOS did not provide editable Photos assets."
            return
        }

        await saveEditsToPhotos(editableItems)
    }

    private func saveEditsToPhotos(_ items: [IOSImageItem]) async {
        isSaving = true
        defer {
            isSaving = false
        }

        do {
            let isAuthorized = await requestFullPhotoLibraryAccess()
            guard isAuthorized else {
                return
            }

            var editedPhotos: [IOSEditedPhoto] = []

            for item in items {
                guard let assetIdentifier = item.assetIdentifier,
                      let convertedCGImage = item.convertedCGImage,
                      let editedPhoto = try await editedPhoto(
                        assetIdentifier: assetIdentifier,
                        image: convertedCGImage
                      ) else {
                    continue
                }

                editedPhotos.append(editedPhoto)
            }

            guard !editedPhotos.isEmpty else {
                message = "The selected photo could not be updated."
                return
            }

            try await PHPhotoLibrary.shared().performChanges {
                for editedPhoto in editedPhotos {
                    let request = PHAssetChangeRequest(for: editedPhoto.asset)
                    request.contentEditingOutput = editedPhoto.output
                }
            }

            message = editedPhotos.count == 1 ? "Updated 1 photo in Photos." : "Updated \(editedPhotos.count) photos in Photos."
        } catch {
            message = "Could not update the selected photo\(items.count == 1 ? "" : "s")."
        }
    }

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        UIApplication.shared.open(url)
    }

    private nonisolated static func cgImage(from data: Data) -> CGImage? {
        if let image = CIImage(data: data, options: [.applyOrientationProperty: true]),
           let renderedImage = context.createCGImage(image, from: image.extent.integral) {
            return renderedImage
        }

        let options = [
            kCGImageSourceShouldCache: true,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary

        guard let source = CGImageSourceCreateWithData(data as CFData, options) else {
            return nil
        }

        return CGImageSourceCreateImageAtIndex(source, 0, options)
    }

    private nonisolated static func displayTitle(from filename: String?, fallbackIndex: Int) -> String {
        guard let filename,
              !filename.isEmpty,
              filename != "." else {
            return "Photo \(fallbackIndex + 1)"
        }

        return filename
    }

    private func requestFullPhotoLibraryAccess() async -> Bool {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        let status = currentStatus == .notDetermined
            ? await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            : currentStatus

        switch status {
        case .authorized:
            needsFullPhotosAccess = false
            return true
        case .limited:
            needsFullPhotosAccess = true
            message = "Full Photos access is needed to update original photos. Change access in Settings."
            return false
        case .denied, .restricted:
            needsFullPhotosAccess = true
            message = "Photos access is needed to update original photos. Change access in Settings."
            return false
        default:
            needsFullPhotosAccess = false
            return false
        }
    }

    private func editedPhoto(assetIdentifier: String, image: CGImage) async throws -> IOSEditedPhoto? {
        guard let asset = Self.fetchAsset(with: assetIdentifier),
              let input = await Self.requestContentEditingInput(for: asset) else {
            return nil
        }

        let output = PHContentEditingOutput(contentEditingInput: input)
        output.adjustmentData = PHAdjustmentData(
            formatIdentifier: "de.lumirio.Negative-Converter.invert",
            formatVersion: "1.0",
            data: Data("invert".utf8)
        )

        let outputURL = (try? output.renderedContentURL(for: .jpeg)) ?? output.renderedContentURL
        try NegativeImageProcessor.write(image, to: outputURL, as: .jpeg)
        return IOSEditedPhoto(asset: asset, output: output)
    }

    private nonisolated static func fetchAsset(with localIdentifier: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject
    }

    private nonisolated static func requestContentEditingInput(for asset: PHAsset) async -> PHContentEditingInput? {
        await withCheckedContinuation { continuation in
            let options = PHContentEditingInputRequestOptions()
            options.isNetworkAccessAllowed = true

            asset.requestContentEditingInput(with: options) { input, _ in
                continuation.resume(returning: input)
            }
        }
    }
}
