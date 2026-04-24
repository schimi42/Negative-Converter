//
//  PhotosLibraryClient.swift
//  Negative Converter
//
//  Created by Michell Schimanski on 19.04.26.
//

import Foundation
import Photos
import UniformTypeIdentifiers

nonisolated enum PhotosLibraryAuthorization {
    case available
    case unavailable
}

nonisolated protocol PhotosLibraryClient {
    func requestAuthorization() async -> PhotosLibraryAuthorization
    func fetchCollections() -> [PhotosLibraryCollection]
    func fetchItems(in collection: PhotosLibraryCollection?) -> [PhotosLibraryItem]
    func fetchAssetTitles(for assetIDs: [String]) async -> [String: String]
    func imageURL(for item: PhotosLibraryItem) async -> URL?
    func saveEditedImage(
        assetIdentifier: String,
        writeRenderedContent: (URL, UTType) throws -> Void
    ) async throws
}

nonisolated enum PhotosLibraryClientError: Error {
    case assetUnavailable
    case contentEditingInputUnavailable
}

nonisolated struct PhotoKitLibraryClient: PhotosLibraryClient {
    func requestAuthorization() async -> PhotosLibraryAuthorization {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                switch status {
                case .authorized, .limited:
                    continuation.resume(returning: .available)
                default:
                    continuation.resume(returning: .unavailable)
                }
            }
        }
    }

    func fetchCollections() -> [PhotosLibraryCollection] {
        var collections = [
            PhotosLibraryCollection(
                id: "library.all",
                title: "All Photos",
                systemImage: "photo.on.rectangle",
                section: "Library",
                source: .allPhotos
            )
        ]

        collections.append(contentsOf: fetchSmartAlbumCollections())
        collections.append(contentsOf: fetchUserAlbumCollections())
        return collections
    }

    func fetchItems(in collection: PhotosLibraryCollection?) -> [PhotosLibraryItem] {
        fetchAssets(in: collection).enumerated().map { index, asset in
            PhotosLibraryItem(
                id: asset.localIdentifier,
                title: fallbackAssetTitle(asset, fallbackIndex: index)
            )
        }
    }

    func fetchAssetTitles(for assetIDs: [String]) async -> [String: String] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = PHAsset.fetchAssets(withLocalIdentifiers: assetIDs, options: nil)
                var titles: [String: String] = [:]

                result.enumerateObjects { asset, _, _ in
                    guard let resource = PHAssetResource.assetResources(for: asset).first else {
                        return
                    }

                    let filename = URL(fileURLWithPath: resource.originalFilename)
                        .deletingPathExtension()
                        .lastPathComponent

                    if !filename.isEmpty {
                        titles[asset.localIdentifier] = filename
                    }
                }

                continuation.resume(returning: titles)
            }
        }
    }

    func imageURL(for item: PhotosLibraryItem) async -> URL? {
        guard let asset = fetchAsset(with: item.id) else {
            return nil
        }

        return await requestContentEditingInput(for: asset)?.fullSizeImageURL
    }

    func saveEditedImage(
        assetIdentifier: String,
        writeRenderedContent: (URL, UTType) throws -> Void
    ) async throws {
        guard let asset = fetchAsset(with: assetIdentifier) else {
            throw PhotosLibraryClientError.assetUnavailable
        }

        guard let input = await requestContentEditingInput(for: asset) else {
            throw PhotosLibraryClientError.contentEditingInputUnavailable
        }

        let output = PHContentEditingOutput(contentEditingInput: input)
        output.adjustmentData = PHAdjustmentData(
            formatIdentifier: "de.lumirio.Negative-Converter.invert",
            formatVersion: "1.0",
            data: Data("invert".utf8)
        )

        let outputURL = (try? output.renderedContentURL(for: .jpeg)) ?? output.renderedContentURL
        try writeRenderedContent(outputURL, .jpeg)

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetChangeRequest(for: asset)
            request.contentEditingOutput = output
        }
    }

    private func fetchAssets(in collection: PhotosLibraryCollection?) -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

        let result: PHFetchResult<PHAsset>
        switch collection?.source {
        case .assetCollection(let localIdentifier):
            if let assetCollection = fetchAssetCollection(with: localIdentifier) {
                result = PHAsset.fetchAssets(in: assetCollection, options: options)
            } else {
                result = PHAsset.fetchAssets(with: options)
            }
        case .allPhotos, nil:
            result = PHAsset.fetchAssets(with: options)
        }

        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    private func fetchSmartAlbumCollections() -> [PhotosLibraryCollection] {
        let smartAlbumTypes: [(PHAssetCollectionSubtype, String, String)] = [
            (.smartAlbumFavorites, "Favorites", "heart"),
            (.smartAlbumRecentlyAdded, "Recently Saved", "square.and.arrow.down"),
            (.smartAlbumScreenshots, "Screenshots", "camera.viewfinder")
        ]

        return smartAlbumTypes.compactMap { subtype, fallbackTitle, systemImage in
            let result = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: subtype, options: nil)
            guard let collection = result.firstObject else {
                return nil
            }

            return PhotosLibraryCollection(
                id: collection.localIdentifier,
                title: collection.localizedTitle ?? fallbackTitle,
                systemImage: systemImage,
                section: "Pinned",
                source: .assetCollection(collection.localIdentifier)
            )
        }
    }

    private func fetchUserAlbumCollections() -> [PhotosLibraryCollection] {
        let result = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        var collections: [PhotosLibraryCollection] = []

        result.enumerateObjects { collection, _, _ in
            collections.append(PhotosLibraryCollection(
                id: collection.localIdentifier,
                title: collection.localizedTitle ?? "Untitled Album",
                systemImage: "rectangle.stack",
                section: "Albums",
                source: .assetCollection(collection.localIdentifier)
            ))
        }

        return collections.sorted {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }

    private func fetchAsset(with localIdentifier: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject
    }

    private func fetchAssetCollection(with localIdentifier: String) -> PHAssetCollection? {
        PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [localIdentifier], options: nil).firstObject
    }

    private func fallbackAssetTitle(_ asset: PHAsset, fallbackIndex: Int) -> String {
        asset.creationDate.map(Self.photoDateFormatter.string(from:)) ?? "Photo \(fallbackIndex + 1)"
    }

    private func requestContentEditingInput(for asset: PHAsset) async -> PHContentEditingInput? {
        let options = PHContentEditingInputRequestOptions()
        options.isNetworkAccessAllowed = true
        options.canHandleAdjustmentData = { adjustmentData in
            adjustmentData.formatIdentifier == "de.lumirio.Negative-Converter.invert"
        }

        return await withCheckedContinuation { continuation in
            asset.requestContentEditingInput(with: options) { input, _ in
                continuation.resume(returning: input)
            }
        }
    }

    private static let photoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
