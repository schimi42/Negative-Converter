//
//  PhotosLibraryModels.swift
//  Negative Converter
//
//  Created by Michell Schimanski on 19.04.26.
//

struct PhotosLibraryItem: Identifiable {
    let id: String
    var title: String
}

struct PhotosLibraryCollection: Identifiable {
    enum Source {
        case allPhotos
        case assetCollection(String)
    }

    let id: String
    let title: String
    let systemImage: String
    let section: String
    let source: Source
}

struct PhotosLibraryPickerState {
    var items: [PhotosLibraryItem] = []
    var collections: [PhotosLibraryCollection] = []
    var selectedCollectionID = "library.all"
    var selectedItemIDs: Set<String> = []
    var lastSelectedItemID: String?
    var isLoading = false

    var hasSelection: Bool {
        !selectedItemIDs.isEmpty
    }

    var selectedCollection: PhotosLibraryCollection? {
        collections.first { $0.id == selectedCollectionID }
    }

    mutating func clearSelection() {
        selectedItemIDs.removeAll()
        lastSelectedItemID = nil
    }

    mutating func toggleSelection(_ item: PhotosLibraryItem) {
        if selectedItemIDs.contains(item.id) {
            selectedItemIDs.remove(item.id)
        } else {
            selectedItemIDs.insert(item.id)
        }

        lastSelectedItemID = item.id
    }

    mutating func selectRange(to item: PhotosLibraryItem, in orderedItems: [PhotosLibraryItem]) {
        guard let itemIndex = orderedItems.firstIndex(where: { $0.id == item.id }) else {
            toggleSelection(item)
            return
        }

        guard let anchorID = lastSelectedItemID,
              let anchorIndex = orderedItems.firstIndex(where: { $0.id == anchorID }) else {
            selectedItemIDs.insert(item.id)
            lastSelectedItemID = item.id
            return
        }

        let lowerBound = min(anchorIndex, itemIndex)
        let upperBound = max(anchorIndex, itemIndex)
        for selectedItem in orderedItems[lowerBound...upperBound] {
            selectedItemIDs.insert(selectedItem.id)
        }

        lastSelectedItemID = item.id
    }
}
