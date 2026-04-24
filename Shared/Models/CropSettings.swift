//
//  CropSettings.swift
//  Negative Converter
//
//  Created by Michell Schimanski on 19.04.26.
//

import CoreGraphics

struct CropSettings: Equatable {
    var left: Double = 0
    var top: Double = 0
    var right: Double = 0
    var bottom: Double = 0

    var isIdentity: Bool {
        left == 0 && top == 0 && right == 0 && bottom == 0
    }

    var normalizedRect: CGRect {
        CGRect(
            x: left,
            y: top,
            width: max(0.01, 1 - left - right),
            height: max(0.01, 1 - top - bottom)
        )
    }
}
