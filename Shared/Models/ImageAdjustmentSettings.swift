//
//  ImageAdjustmentSettings.swift
//  Negative Converter
//
//  Created by Michell Schimanski on 19.04.26.
//

struct ImageAdjustmentSettings: Equatable {
    var rotationDegrees: Double = 0
    var verticalCorrectionDegrees: Double = 0
    var horizontalCorrectionDegrees: Double = 0
    var isMirroredHorizontally = false
    var isTrueGrayscale = false

    var isIdentity: Bool {
        rotationDegrees == 0
        && verticalCorrectionDegrees == 0
        && horizontalCorrectionDegrees == 0
        && !isMirroredHorizontally
        && !isTrueGrayscale
    }
}
