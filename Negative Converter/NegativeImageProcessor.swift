//
//  NegativeImageProcessor.swift
//  Negative Converter
//
//  Created by Michell Schimanski on 19.04.26.
//

import AppKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers

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

enum NegativeImageProcessorError: LocalizedError {
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

enum NegativeImageProcessor {
    private static let context = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any])

    static func invertedImage(from image: NSImage, crop: CropSettings = CropSettings()) throws -> NSImage {
        let cgImage = try invertedCGImage(from: image, crop: crop)
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
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

    static func write(_ image: NSImage, to url: URL) throws {
        let outputType = UTType(filenameExtension: url.pathExtension) ?? .png
        try write(image, to: url, as: outputType)
    }

    static func write(_ image: NSImage, to url: URL, as outputType: UTType) throws {
        let cgImage = try invertedSourceIfNeeded(image)
        let destinationType = outputType.identifier as CFString

        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, destinationType, 1, nil) else {
            throw NegativeImageProcessorError.couldNotRenderImage
        }

        CGImageDestinationAddImage(destination, cgImage, nil)

        guard CGImageDestinationFinalize(destination) else {
            throw NegativeImageProcessorError.couldNotRenderImage
        }
    }

    private static func invertedCGImage(from image: NSImage, crop: CropSettings) throws -> CGImage {
        let cgImage = try croppedSource(image, crop: crop)
        let inputImage = CIImage(cgImage: cgImage)
        let outputImage = inputImage.applyingFilter("CIColorInvert")

        guard let renderedImage = context.createCGImage(outputImage, from: inputImage.extent) else {
            throw NegativeImageProcessorError.couldNotRenderImage
        }

        return renderedImage
    }

    private static func croppedSource(_ image: NSImage, crop: CropSettings) throws -> CGImage {
        let cgImage = try invertedSourceIfNeeded(image)
        guard !crop.isIdentity else {
            return cgImage
        }

        let width = Double(cgImage.width)
        let height = Double(cgImage.height)
        let x = crop.left * width
        let y = crop.top * height
        let cropWidth = max(1, (1 - crop.left - crop.right) * width)
        let cropHeight = max(1, (1 - crop.top - crop.bottom) * height)
        let cropRect = CGRect(x: x, y: y, width: cropWidth, height: cropHeight).integral

        guard let croppedImage = cgImage.cropping(to: cropRect) else {
            throw NegativeImageProcessorError.couldNotRenderImage
        }

        return croppedImage
    }

    private static func invertedSourceIfNeeded(_ image: NSImage) throws -> CGImage {
        var proposedRect = NSRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
            throw NegativeImageProcessorError.couldNotReadImage
        }

        return cgImage
    }
}
