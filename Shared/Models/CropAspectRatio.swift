//
//  CropAspectRatio.swift
//  Negative Converter
//
//  Created by Michell Schimanski on 19.04.26.
//

import Foundation

nonisolated struct CropAspectRatio: Identifiable, Equatable {
    let id: String
    let title: String
    let ratio: Double?

    static let presets = [
        CropAspectRatio(id: "free", title: "Free", ratio: nil),
        CropAspectRatio(id: "35mm-3x2", title: "35mm / 6x9 (3:2)", ratio: 3.0 / 2.0),
        CropAspectRatio(id: "645-4x3", title: "6x4.5 (4:3)", ratio: 4.0 / 3.0),
        CropAspectRatio(id: "6x6-1x1", title: "6x6 (1:1)", ratio: 1.0),
        CropAspectRatio(id: "6x7-7x6", title: "6x7 (7:6)", ratio: 7.0 / 6.0),
        CropAspectRatio(id: "4x5-5x4", title: "4x5 (5:4)", ratio: 5.0 / 4.0)
    ]
}
