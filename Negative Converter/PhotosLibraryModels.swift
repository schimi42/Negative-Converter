//
//  PhotosLibraryModels.swift
//  Negative Converter
//
//  Created by Michell Schimanski on 19.04.26.
//

import AppKit
import Photos

struct PhotosLibraryItem: Identifiable {
    let id: String
    let asset: PHAsset
    var thumbnail: NSImage?
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
