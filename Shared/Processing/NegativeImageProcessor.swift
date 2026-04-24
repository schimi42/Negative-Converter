//
//  NegativeImageProcessor.swift
//  Negative Converter
//
//  Created by Michell Schimanski on 19.04.26.
//

import CoreGraphics
import CoreImage
import ImageIO
import UniformTypeIdentifiers

nonisolated enum NegativeImageProcessorError: LocalizedError {
    case couldNotReadImage
    case couldNotRenderImage

    var errorDescription: String? {
        switch self {
        case .couldNotReadImage:
            "The image could not be read."
        case .couldNotRenderImage:
            "The inverted image could not be rendered."
        }
    }
}

nonisolated enum NegativeImageProcessor {
    private static let context = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any])

    static func previewCGImage(
        from image: CGImage,
        adjustments: ImageAdjustmentSettings = ImageAdjustmentSettings()
    ) throws -> CGImage {
        try renderedCGImage(
            from: image,
            crop: CropSettings(),
            adjustments: adjustments,
            shouldInvert: false
        )
    }

    static func invertedCGImage(
        from image: CGImage,
        crop: CropSettings = CropSettings(),
        adjustments: ImageAdjustmentSettings = ImageAdjustmentSettings()
    ) throws -> CGImage {
        try renderedCGImage(
            from: image,
            crop: crop,
            adjustments: adjustments,
            shouldInvert: true
        )
    }

    static func invertedImageData(from url: URL, outputType: UTType = .jpeg) throws -> Data {
        guard let sourceImage = CIImage(contentsOf: url) else {
            throw NegativeImageProcessorError.couldNotReadImage
        }

        let outputImage = sourceImage.applyingFilter("CIColorInvert")
        let colorSpace = sourceImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

        if outputType.conforms(to: .png) {
            guard let data = context.pngRepresentation(of: outputImage, format: .RGBA8, colorSpace: colorSpace, options: [:]) else {
                throw NegativeImageProcessorError.couldNotRenderImage
            }

            return data
        }

        guard let data = context.jpegRepresentation(of: outputImage, colorSpace: colorSpace, options: [:]) else {
            throw NegativeImageProcessorError.couldNotRenderImage
        }

        return data
    }

    static func write(_ image: CGImage, to url: URL) throws {
        let outputType = UTType(filenameExtension: url.pathExtension) ?? .png
        try write(image, to: url, as: outputType)
    }

    static func write(_ image: CGImage, to url: URL, as outputType: UTType) throws {
        let destinationType = outputType.identifier as CFString

        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, destinationType, 1, nil) else {
            throw NegativeImageProcessorError.couldNotRenderImage
        }

        CGImageDestinationAddImage(destination, image, nil)

        guard CGImageDestinationFinalize(destination) else {
            throw NegativeImageProcessorError.couldNotRenderImage
        }
    }

    private static func renderedCGImage(
        from image: CGImage,
        crop: CropSettings,
        adjustments: ImageAdjustmentSettings,
        shouldInvert: Bool
    ) throws -> CGImage {
        let preparedImage = try preparedImage(from: image, adjustments: adjustments)
        let croppedImage = croppedImage(preparedImage, crop: crop)
        let outputImage = shouldInvert ? croppedImage.applyingFilter("CIColorInvert") : croppedImage

        guard let renderedImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            throw NegativeImageProcessorError.couldNotRenderImage
        }

        return renderedImage
    }

    private static func preparedImage(
        from image: CGImage,
        adjustments: ImageAdjustmentSettings
    ) throws -> CIImage {
        let sourceImage = CIImage(cgImage: image)
        guard !adjustments.isIdentity else {
            return sourceImage
        }

        let sourceExtent = sourceImage.extent
        let center = CGPoint(x: sourceExtent.midX, y: sourceExtent.midY)
        let rotationRadians = adjustments.rotationDegrees * .pi / 180
        let verticalRadians = adjustments.verticalCorrectionDegrees * .pi / 180
        let horizontalRadians = adjustments.horizontalCorrectionDegrees * .pi / 180
        let perspectiveTransform = CGAffineTransform(
            a: 1,
            b: tan(verticalRadians),
            c: tan(horizontalRadians),
            d: 1,
            tx: 0,
            ty: 0
        )

        var transform = CGAffineTransform(translationX: -center.x, y: -center.y)
        if adjustments.isMirroredHorizontally {
            transform = transform.scaledBy(x: -1, y: 1)
        }
        transform = transform.rotated(by: rotationRadians)
        transform = transform.concatenating(perspectiveTransform)
        transform = transform.translatedBy(x: center.x, y: center.y)

        let transformedImage = sourceImage.transformed(by: transform)
        let transformedExtent = transformedImage.extent.integral
        let normalizedImage = transformedImage.transformed(by: CGAffineTransform(
            translationX: -transformedExtent.minX,
            y: -transformedExtent.minY
        ))

        return grayscaleImageIfNeeded(normalizedImage, adjustments: adjustments)
    }

    private static func croppedImage(_ image: CIImage, crop: CropSettings) -> CIImage {
        guard !crop.isIdentity else {
            return image
        }

        let extent = image.extent.integral
        let x = extent.minX + crop.left * extent.width
        let y = extent.minY + crop.bottom * extent.height
        let cropWidth = max(1, (1 - crop.left - crop.right) * extent.width)
        let cropHeight = max(1, (1 - crop.top - crop.bottom) * extent.height)
        let cropRect = CGRect(x: x, y: y, width: cropWidth, height: cropHeight).integral

        return image.cropped(to: cropRect)
    }

    private static func grayscaleImageIfNeeded(_ image: CIImage, adjustments: ImageAdjustmentSettings) -> CIImage {
        guard adjustments.isTrueGrayscale else {
            return image
        }

        return image.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0
        ])
    }
}
