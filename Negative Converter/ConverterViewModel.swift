//
//  ConverterViewModel.swift
//  Negative Converter
//
//  Created by Michell Schimanski on 19.04.26.
//

import AppKit
import Observation
import Photos
import UniformTypeIdentifiers

@Observable
@MainActor
final class ConverterViewModel {
    var items: [BatchImageItem] = []
    var photosLibraryItems: [PhotosLibraryItem] = []
    var photosLibraryCollections: [PhotosLibraryCollection] = []
    var selectedPhotosCollectionID = "library.all"
    var selectedPhotosAssetIDs: Set<String> = []
    var lastSelectedPhotosAssetID: String?
    var selectedID: BatchImageItem.ID?
    var crop = CropSettings()
    var sharedCrop = CropSettings()
    var sharedCropDraft = CropSettings()
    var adjustments = ImageAdjustmentSettings()
    var cropAspectRatios = CropAspectRatio.presets
    var selectedCropAspectRatioID = "free"
    var message = "Choose images or use Photos > Image > Edit With > Lumirio Negative Converter."
    var isLoadingPhotosLibrary = false

    var selectedItem: BatchImageItem? {
        guard let selectedID else {
            return items.first
        }

        return items.first { $0.id == selectedID } ?? items.first
    }

    var originalImage: NSImage? {
        guard let selectedItem else {
            return nil
        }

        return Self.nsImage(from: selectedItem.previewCGImage ?? selectedItem.originalCGImage)
    }

    var convertedImage: NSImage? {
        guard let convertedCGImage = selectedItem?.convertedCGImage else {
            return nil
        }

        return Self.nsImage(from: convertedCGImage)
    }

    var openedURL: URL? {
        selectedItem?.url
    }

    var canSave: Bool {
        items.contains { $0.convertedCGImage != nil }
    }

    var hasPhotosLibrarySelection: Bool {
        !selectedPhotosAssetIDs.isEmpty
    }

    var selectedCropAspectRatio: CropAspectRatio {
        cropAspectRatios.first { $0.id == selectedCropAspectRatioID } ?? cropAspectRatios[0]
    }

    var isCropAspectRatioLocked: Bool {
        selectedCropAspectRatio.ratio != nil
    }

    var selectedPhotosLibraryCollection: PhotosLibraryCollection? {
        photosLibraryCollections.first { $0.id == selectedPhotosCollectionID }
    }

    var hasSelectedItem: Bool {
        selectedIndex != nil
    }

    var hasPendingCropChanges: Bool {
        guard let selectedIndex else {
            return false
        }

        return crop != effectiveCrop(for: selectedIndex)
    }

    var selectedSourceKind: BatchSourceKind {
        guard let selectedItem else {
            return .none
        }

        return selectedItem.isFromPhotosLibrary ? .photos : .files
    }

    var batchSourceKind: BatchSourceKind {
        guard let firstItem = items.first else {
            return .none
        }

        let firstIsPhotos = firstItem.isFromPhotosLibrary
        if items.dropFirst().allSatisfy({ $0.isFromPhotosLibrary == firstIsPhotos }) {
            return firstIsPhotos ? .photos : .files
        }

        return .mixed
    }

    func open(_ url: URL) {
        open([url])
    }

    func open(_ urls: [URL]) {
        let loadedItems = urls.compactMap(loadItem)
        guard !loadedItems.isEmpty else {
            message = "No supported images could be opened."
            return
        }

        items = loadedItems
        selectedID = loadedItems.first?.id
        sharedCrop = loadedItems.first?.crop ?? CropSettings()
        sharedCropDraft = sharedCrop
        crop = sharedCropDraft
        convertAll()
        message = loadedItems.count == 1 ? "Loaded \(loadedItems[0].fileName)." : "Loaded \(loadedItems.count) images."
    }

    func select(_ item: BatchImageItem) {
        selectedID = item.id
        let selectedCrop = item.usesSharedCrop ? sharedCropDraft : item.crop
        crop = isCropAspectRatioLocked
            ? adjustedCrop(selectedCrop, changedEdge: nil)
            : selectedCrop
    }

    func convertSelected() {
        guard let selectedIndex else {
            return
        }

        convertItem(at: selectedIndex)
        message = "Converted \(items[selectedIndex].fileName)."
    }

    func convertAll() {
        guard !items.isEmpty else {
            return
        }

        for index in items.indices {
            convertItem(at: index)
        }

        let failures = items.filter { $0.convertedCGImage == nil }.count
        if failures == 0 {
            message = "Converted \(items.count) image\(items.count == 1 ? "" : "s")."
        } else {
            message = "Converted \(items.count - failures) image\(items.count - failures == 1 ? "" : "s"); \(failures) failed."
        }
    }

    func setCrop(left: Double? = nil, top: Double? = nil, right: Double? = nil, bottom: Double? = nil) {
        var nextCrop = crop
        var changedEdge: CropEdge?
        if let left {
            nextCrop.left = clampedCropValue(left)
            changedEdge = .left
        }
        if let top {
            nextCrop.top = clampedCropValue(top)
            changedEdge = .top
        }
        if let right {
            nextCrop.right = clampedCropValue(right)
            changedEdge = .right
        }
        if let bottom {
            nextCrop.bottom = clampedCropValue(bottom)
            changedEdge = .bottom
        }

        updateCropEditor(adjustedCrop(nextCrop, changedEdge: changedEdge))
    }

    func setCrop(_ crop: CropSettings) {
        updateCropEditor(adjustedCrop(CropSettings(
            left: clampedCropValue(crop.left),
            top: clampedCropValue(crop.top),
            right: clampedCropValue(crop.right),
            bottom: clampedCropValue(crop.bottom)
        ), changedEdge: nil))
    }

    func setCrop(_ crop: CropSettings, changedEdge: CropEdge) {
        updateCropEditor(adjustedCrop(CropSettings(
            left: clampedCropValue(crop.left),
            top: clampedCropValue(crop.top),
            right: clampedCropValue(crop.right),
            bottom: clampedCropValue(crop.bottom)
        ), changedEdge: changedEdge))
    }

    func moveCrop(_ crop: CropSettings) {
        updateCropEditor(limitedCrop(CropSettings(
            left: clampedCropValue(crop.left),
            top: clampedCropValue(crop.top),
            right: clampedCropValue(crop.right),
            bottom: clampedCropValue(crop.bottom)
        )))
    }

    func selectCropAspectRatio(_ id: String) {
        selectedCropAspectRatioID = id
        if isCropAspectRatioLocked {
            updateCropEditor(adjustedCrop(crop, changedEdge: nil))
        }
    }

    func setRotationDegrees(_ value: Double) {
        adjustments.rotationDegrees = value
        convertAll()
    }

    func setVerticalCorrectionDegrees(_ value: Double) {
        adjustments.verticalCorrectionDegrees = value
        convertAll()
    }

    func setHorizontalCorrectionDegrees(_ value: Double) {
        adjustments.horizontalCorrectionDegrees = value
        convertAll()
    }

    func toggleMirroring() {
        adjustments.isMirroredHorizontally.toggle()
        convertAll()
    }

    func setTrueGrayscale(_ isEnabled: Bool) {
        adjustments.isTrueGrayscale = isEnabled
        convertAll()
    }

    func resetAdjustments() {
        adjustments.rotationDegrees = 0
        adjustments.verticalCorrectionDegrees = 0
        adjustments.horizontalCorrectionDegrees = 0
        adjustments.isMirroredHorizontally = false
        convertAll()
    }

    func resetCrop() {
        guard let selectedIndex else {
            return
        }

        let resetCrop = CropSettings()
        items[selectedIndex].crop = resetCrop
        items[selectedIndex].usesSharedCrop = false
        crop = resetCrop
        convertItem(at: selectedIndex)
        message = "Reset crop for \(items[selectedIndex].fileName)."
    }

    func applyCropToSelected() {
        guard let selectedIndex else {
            return
        }

        items[selectedIndex].crop = crop
        items[selectedIndex].usesSharedCrop = false
        convertItem(at: selectedIndex)
        message = crop.isIdentity
            ? "Removed crop for \(items[selectedIndex].fileName)."
            : "Applied crop to \(items[selectedIndex].fileName)."
    }

    func resetCropForAll() {
        sharedCrop = CropSettings()
        sharedCropDraft = sharedCrop
        crop = sharedCropDraft
        for index in items.indices {
            items[index].crop = CropSettings()
            items[index].usesSharedCrop = true
        }

        convertAll()
        message = "Reset crop for all images."
    }

    func applyCropToAll() {
        sharedCrop = crop
        sharedCropDraft = crop
        for index in items.indices {
            items[index].crop = crop
            items[index].usesSharedCrop = true
        }
        convertAll()
        message = crop.isIdentity ? "Crop reset and all images converted." : "Applied crop to \(items.count) image\(items.count == 1 ? "" : "s")."
    }

    func saveSelected() {
        guard let selectedIndex else {
            return
        }

        Task {
            let didSave = await saveItem(at: selectedIndex)
            message = didSave ? "Saved \(items[selectedIndex].fileName)." : "Save failed for \(items[selectedIndex].fileName)."
        }
    }

    func saveAll() {
        guard !items.isEmpty else {
            return
        }

        Task {
            var savedCount = 0
            for index in items.indices {
                if await saveItem(at: index) {
                    savedCount += 1
                }
            }

            message = "Saved \(savedCount) of \(items.count) image\(items.count == 1 ? "" : "s")."
        }
    }

    func exportAllToFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export"

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            return
        }

        var savedCount = 0
        for index in items.indices {
            let outputURL = folderURL.appendingPathComponent(items[index].outputFileName)
            if saveFileItem(at: index, to: outputURL) {
                savedCount += 1
            }
        }

        message = "Exported \(savedCount) positive image\(savedCount == 1 ? "" : "s")."
    }

    func exportSelectedToFolder() {
        guard let selectedIndex else {
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export"

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            return
        }

        let outputURL = folderURL.appendingPathComponent(items[selectedIndex].outputFileName)
        let didExport = saveFileItem(at: selectedIndex, to: outputURL)
        message = didExport ? "Exported \(items[selectedIndex].fileName)." : "Export failed for \(items[selectedIndex].fileName)."
    }

    func loadPhotosLibrary() {
        isLoadingPhotosLibrary = true
        message = "Loading Photos Library..."

        Task {
            let status = await requestPhotosAuthorization()
            guard status == .authorized || status == .limited else {
                isLoadingPhotosLibrary = false
                message = "Photos Library access was not granted."
                return
            }

            let collections = fetchPhotosLibraryCollections()
            photosLibraryCollections = collections
            if !collections.contains(where: { $0.id == selectedPhotosCollectionID }) {
                selectedPhotosCollectionID = collections.first?.id ?? "library.all"
            }
            selectedPhotosAssetIDs.removeAll()
            lastSelectedPhotosAssetID = nil

            let loadedCount = await loadPhotosLibraryItems(for: selectedPhotosCollectionID)
            isLoadingPhotosLibrary = false
            message = "Loaded \(loadedCount) Photos Library image\(loadedCount == 1 ? "" : "s")."
        }
    }

    func selectPhotosLibraryCollection(_ collection: PhotosLibraryCollection) {
        guard collection.id != selectedPhotosCollectionID else {
            return
        }

        selectedPhotosCollectionID = collection.id
        selectedPhotosAssetIDs.removeAll()
        lastSelectedPhotosAssetID = nil
        isLoadingPhotosLibrary = true
        photosLibraryItems = []
        message = "Loading \(collection.title)..."

        Task {
            let loadedCount = await loadPhotosLibraryItems(for: collection.id)
            guard collection.id == selectedPhotosCollectionID else {
                return
            }

            isLoadingPhotosLibrary = false
            message = "Loaded \(loadedCount) image\(loadedCount == 1 ? "" : "s") from \(collection.title)."
        }
    }

    func togglePhotosLibrarySelection(_ item: PhotosLibraryItem) {
        if selectedPhotosAssetIDs.contains(item.id) {
            selectedPhotosAssetIDs.remove(item.id)
        } else {
            selectedPhotosAssetIDs.insert(item.id)
        }

        lastSelectedPhotosAssetID = item.id
    }

    func selectPhotosLibraryRange(to item: PhotosLibraryItem, in orderedItems: [PhotosLibraryItem]) {
        guard let itemIndex = orderedItems.firstIndex(where: { $0.id == item.id }) else {
            togglePhotosLibrarySelection(item)
            return
        }

        guard let anchorID = lastSelectedPhotosAssetID,
              let anchorIndex = orderedItems.firstIndex(where: { $0.id == anchorID }) else {
            selectedPhotosAssetIDs.insert(item.id)
            lastSelectedPhotosAssetID = item.id
            return
        }

        let lowerBound = min(anchorIndex, itemIndex)
        let upperBound = max(anchorIndex, itemIndex)
        for selectedItem in orderedItems[lowerBound...upperBound] {
            selectedPhotosAssetIDs.insert(selectedItem.id)
        }

        lastSelectedPhotosAssetID = item.id
    }

    func addSelectedPhotosToBatch() {
        let selectedItems = photosLibraryItems.filter { selectedPhotosAssetIDs.contains($0.id) }
        guard !selectedItems.isEmpty else {
            message = "Select one or more Photos Library images first."
            return
        }

        isLoadingPhotosLibrary = true
        message = "Importing \(selectedItems.count) Photos Library image\(selectedItems.count == 1 ? "" : "s")..."

        Task {
            let resolvedTitles = await Self.fetchAssetTitles(for: selectedItems.map { $0.asset.localIdentifier })
            var loadedItems: [BatchImageItem] = []
            for selectedItem in selectedItems {
                let resolvedTitle = resolvedTitles[selectedItem.asset.localIdentifier]
                    ?? selectedItem.title

                if let batchItem = await loadBatchItem(from: selectedItem.asset, displayName: resolvedTitle) {
                    loadedItems.append(batchItem)
                }
            }

            items = loadedItems
            selectedID = loadedItems.first?.id
            sharedCrop = loadedItems.first?.crop ?? CropSettings()
            sharedCropDraft = sharedCrop
            crop = sharedCropDraft
            selectedPhotosAssetIDs.removeAll()
            lastSelectedPhotosAssetID = nil
            convertAll()
            isLoadingPhotosLibrary = false
            message = "Imported \(loadedItems.count) Photos Library image\(loadedItems.count == 1 ? "" : "s")."
        }
    }

    private var selectedIndex: Int? {
        guard let selectedID else {
            return items.indices.first
        }

        return items.firstIndex { $0.id == selectedID } ?? items.indices.first
    }

    private func loadItem(from url: URL) -> BatchImageItem? {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let image = NSImage(contentsOf: url),
              let cgImage = Self.cgImage(from: image) else {
            return nil
        }

        return BatchImageItem(
            url: url,
            assetIdentifier: nil,
            displayName: url.lastPathComponent,
            originalCGImage: cgImage,
            previewCGImage: cgImage,
            status: "Loaded"
        )
    }

    private func convertItem(at index: Int) {
        do {
            let previewCGImage = try NegativeImageProcessor.previewCGImage(
                from: items[index].originalCGImage,
                adjustments: adjustments
            )
            let convertedCGImage = try NegativeImageProcessor.invertedCGImage(
                from: items[index].originalCGImage,
                crop: effectiveCrop(for: index),
                adjustments: adjustments
            )
            items[index].previewCGImage = previewCGImage
            items[index].convertedCGImage = convertedCGImage
            items[index].status = "Converted"
        } catch {
            items[index].previewCGImage = items[index].originalCGImage
            items[index].convertedCGImage = nil
            items[index].status = "Conversion failed"
        }
    }

    private func clampedCropValue(_ value: Double) -> Double {
        min(0.98, max(0, value))
    }

    private func effectiveCrop(for index: Int) -> CropSettings {
        items[index].usesSharedCrop ? sharedCrop : items[index].crop
    }

    private func updateCropEditor(_ newCrop: CropSettings) {
        crop = newCrop

        guard let selectedIndex else {
            sharedCropDraft = newCrop
            return
        }

        if items[selectedIndex].usesSharedCrop {
            sharedCropDraft = newCrop
        }
    }

    private func limitedCrop(_ crop: CropSettings) -> CropSettings {
        var limitedCrop = crop
        let maxCombinedMargin = 0.98

        if limitedCrop.left + limitedCrop.right > maxCombinedMargin {
            limitedCrop.right = max(0, maxCombinedMargin - limitedCrop.left)
        }

        if limitedCrop.top + limitedCrop.bottom > maxCombinedMargin {
            limitedCrop.bottom = max(0, maxCombinedMargin - limitedCrop.top)
        }

        return limitedCrop
    }

    private func adjustedCrop(_ crop: CropSettings, changedEdge: CropEdge?) -> CropSettings {
        let constrainedCrop = limitedCrop(crop)
        guard let targetRatio = lockedNormalizedCropRatio else {
            return constrainedCrop
        }

        return limitedCrop(enforceAspectRatio(targetRatio, on: constrainedCrop, changedEdge: changedEdge))
    }

    private var lockedNormalizedCropRatio: Double? {
        guard isCropAspectRatioLocked,
              let targetPixelRatio = selectedCropAspectRatio.ratio,
              let image = selectedItem?.previewCGImage ?? selectedItem?.originalCGImage,
              image.width > 0,
              image.height > 0 else {
            return nil
        }

        let imageWidth = Double(image.width)
        let imageHeight = Double(image.height)
        let orientedTargetRatio = imageHeight > imageWidth ? 1 / targetPixelRatio : targetPixelRatio
        return orientedTargetRatio / (imageWidth / imageHeight)
    }

    private func enforceAspectRatio(_ targetRatio: Double, on crop: CropSettings, changedEdge: CropEdge?) -> CropSettings {
        var rect = crop.normalizedRect
        let minimumSize = 0.02

        switch changedEdge {
        case .left, .right:
            let anchoredRight = rect.maxX
            let anchoredLeft = rect.minX
            rect.size.height = max(minimumSize, rect.width / targetRatio)
            rect.origin.y = crop.normalizedRect.midY - rect.height / 2
            if rect.height > 1 {
                rect.size.height = 1
                rect.size.width = min(1, rect.height * targetRatio)
                if changedEdge == .left {
                    rect.origin.x = anchoredRight - rect.width
                } else {
                    rect.origin.x = anchoredLeft
                }
            }
        case .top, .bottom:
            let anchoredBottom = rect.maxY
            let anchoredTop = rect.minY
            rect.size.width = max(minimumSize, rect.height * targetRatio)
            rect.origin.x = crop.normalizedRect.midX - rect.width / 2
            if rect.width > 1 {
                rect.size.width = 1
                rect.size.height = min(1, rect.width / targetRatio)
                if changedEdge == .top {
                    rect.origin.y = anchoredBottom - rect.height
                } else {
                    rect.origin.y = anchoredTop
                }
            }
        case nil:
            if rect.width / rect.height > targetRatio {
                rect.size.width = rect.height * targetRatio
            } else {
                rect.size.height = rect.width / targetRatio
            }
            rect.origin.x = crop.normalizedRect.midX - rect.width / 2
            rect.origin.y = crop.normalizedRect.midY - rect.height / 2
        }

        rect.size.width = min(1, max(minimumSize, rect.width))
        rect.size.height = min(1, max(minimumSize, rect.height))
        rect.origin.x = min(max(0, rect.origin.x), 1 - rect.width)
        rect.origin.y = min(max(0, rect.origin.y), 1 - rect.height)

        return CropSettings(
            left: rect.minX,
            top: rect.minY,
            right: 1 - rect.maxX,
            bottom: 1 - rect.maxY
        )
    }

    @discardableResult
    private func saveItem(at index: Int) async -> Bool {
        if let assetIdentifier = items[index].assetIdentifier {
            return await savePhotosLibraryItem(at: index, assetIdentifier: assetIdentifier)
        }

        guard let url = items[index].url else {
            items[index].status = "Missing destination"
            return false
        }

        return saveFileItem(at: index, to: url)
    }

    @discardableResult
    private func saveFileItem(at index: Int, to url: URL) -> Bool {
        guard let convertedCGImage = items[index].convertedCGImage else {
            items[index].status = "Not converted"
            return false
        }

        do {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            try NegativeImageProcessor.write(Self.nsImage(from: convertedCGImage), to: url)
            items[index].status = "Saved"
            return true
        } catch {
            items[index].status = "Save failed"
            return false
        }
    }

    private func savePhotosLibraryItem(at index: Int, assetIdentifier: String) async -> Bool {
        guard let convertedCGImage = items[index].convertedCGImage else {
            items[index].status = "Not converted"
            return false
        }

        guard let asset = fetchAsset(with: assetIdentifier),
              let input = await requestContentEditingInput(for: asset) else {
            items[index].status = "Photos asset unavailable"
            return false
        }

        let output = PHContentEditingOutput(contentEditingInput: input)
        output.adjustmentData = PHAdjustmentData(
            formatIdentifier: "de.lumirio.Negative-Converter.invert",
            formatVersion: "1.0",
            data: Data("invert".utf8)
        )

        do {
            let outputURL = (try? output.renderedContentURL(for: .jpeg)) ?? output.renderedContentURL
            try NegativeImageProcessor.write(Self.nsImage(from: convertedCGImage), to: outputURL, as: .jpeg)
        } catch {
            items[index].status = "Render failed"
            return false
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetChangeRequest(for: asset)
                request.contentEditingOutput = output
            }
            items[index].status = "Saved to Photos"
            return true
        } catch {
            items[index].status = "Photos save failed"
            return false
        }
    }

    private func requestPhotosAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func fetchPhotosAssets(in collection: PhotosLibraryCollection?) -> [PHAsset] {
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

    private func fetchPhotosLibraryCollections() -> [PhotosLibraryCollection] {
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

    @discardableResult
    private func loadPhotosLibraryItems(for collectionID: String) async -> Int {
        let collection = photosLibraryCollections.first { $0.id == collectionID }
        let assets = fetchPhotosAssets(in: collection)
        guard collectionID == selectedPhotosCollectionID else {
            return photosLibraryItems.count
        }

        photosLibraryItems = assets.enumerated().map { index, asset in
            PhotosLibraryItem(id: asset.localIdentifier, asset: asset, title: fallbackAssetTitle(asset, fallbackIndex: index))
        }

        return photosLibraryItems.count
    }

    private func loadBatchItem(from asset: PHAsset, displayName: String) async -> BatchImageItem? {
        guard let input = await requestContentEditingInput(for: asset),
              let url = input.fullSizeImageURL,
              let image = NSImage(contentsOf: url),
              let cgImage = Self.cgImage(from: image) else {
            return nil
        }

        return BatchImageItem(
            url: nil,
            assetIdentifier: asset.localIdentifier,
            displayName: displayName,
            originalCGImage: cgImage,
            previewCGImage: cgImage,
            status: "Loaded from Photos"
        )
    }

    private nonisolated static func cgImage(from image: NSImage) -> CGImage? {
        var proposedRect = NSRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil)
    }

    private nonisolated static func nsImage(from cgImage: CGImage) -> NSImage {
        NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    private func fallbackAssetTitle(_ asset: PHAsset, fallbackIndex: Int) -> String {
        return asset.creationDate.map(Self.photoDateFormatter.string(from:)) ?? "Photo \(fallbackIndex + 1)"
    }

    private nonisolated static func fetchAssetTitles(for assetIDs: [String]) async -> [String: String] {
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
