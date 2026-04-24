//
//  ImageFileClient.swift
//  Negative Converter
//
//  Created by Michell Schimanski on 19.04.26.
//

import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

nonisolated protocol ImageFileClient {
    func loadImage(from url: URL) throws -> CGImage
    func write(_ image: CGImage, to url: URL) throws
    func write(_ image: CGImage, to url: URL, as outputType: UTType) throws
}

nonisolated struct LocalImageFileClient: ImageFileClient {
    private static let context = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any])
    private static let rawFileExtensions: Set<String> = [
        "3fr", "ari", "arw", "bay", "cr2", "cr3", "crw", "dcr", "dng", "erf",
        "fff", "iiq", "k25", "kdc", "mef", "mos", "mrw", "nef", "nrw", "orf",
        "pef", "raf", "raw", "rwl", "rw2", "sr2", "srf", "srw", "x3f"
    ]
    private static let rawIdentifierHints: [String: String] = [
        "arw": "com.sony.raw-image",
        "cr2": "com.canon.cr2-raw-image",
        "cr3": "com.canon.cr3-raw-image",
        "crw": "com.canon.crw-raw-image",
        "dng": "com.adobe.raw-image",
        "erf": "com.epson.raw-image",
        "mef": "com.mamiya.raw-image",
        "mos": "com.leafamerica.raw-image",
        "nef": "com.nikon.raw-image",
        "nrw": "com.nikon.nrw-raw-image",
        "orf": "com.olympus.raw-image",
        "pef": "com.pentax.raw-image",
        "raf": "com.fuji.raw-image",
        "rw2": "com.panasonic.raw-image",
        "rwl": "com.leica.raw-image",
        "sr2": "com.sony.sr2-raw-image",
        "srf": "com.sony.srf-raw-image",
        "srw": "com.samsung.raw-image"
    ]

    func loadImage(from url: URL) throws -> CGImage {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        if let image = Self.renderRawImage(from: url) {
            return image
        }

        guard let data = try? Data(contentsOf: url) else {
            throw NegativeImageProcessorError.couldNotReadImage
        }

        if let image = Self.renderRawImage(from: data, pathExtension: url.pathExtension) {
            return image
        }

        if let image = Self.renderCoreImage(from: data) {
            return image
        }

        let options = [
            kCGImageSourceShouldCache: true,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options),
              let image = CGImageSourceCreateImageAtIndex(source, 0, options) else {
            throw NegativeImageProcessorError.couldNotReadImage
        }

        return image
    }

    func write(_ image: CGImage, to url: URL) throws {
        let outputType = UTType(filenameExtension: url.pathExtension) ?? .png
        try write(image, to: url, as: outputType)
    }

    func write(_ image: CGImage, to url: URL, as outputType: UTType) throws {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        try NegativeImageProcessor.write(image, to: url, as: outputType)
    }

    private static func renderCoreImage(from data: Data) -> CGImage? {
        guard let image = CIImage(data: data, options: [.applyOrientationProperty: true]) else {
            return nil
        }

        return context.createCGImage(image, from: image.extent.integral)
    }

    private static func renderRawImage(from url: URL) -> CGImage? {
        let pathExtension = url.pathExtension.lowercased()
        guard rawFileExtensions.contains(pathExtension),
              let filter = CIRAWFilter(imageURL: url) else {
            return nil
        }

        filter.scaleFactor = 1
        filter.isDraftModeEnabled = false

        guard let image = filter.outputImage,
              let renderedImage = context.createCGImage(image, from: image.extent.integral) else {
            return nil
        }

        return detachedCopy(of: renderedImage)
    }

    private static func renderRawImage(from data: Data, pathExtension: String) -> CGImage? {
        let normalizedExtension = pathExtension.lowercased()
        let identifierHint = rawIdentifierHints[normalizedExtension] ?? normalizedExtension
        guard rawFileExtensions.contains(normalizedExtension),
              let filter = CIRAWFilter(
                imageData: data,
                identifierHint: identifierHint
              ) else {
            return nil
        }

        filter.scaleFactor = 1
        filter.isDraftModeEnabled = false

        guard let image = filter.outputImage else {
            return nil
        }

        guard let renderedImage = context.createCGImage(image, from: image.extent.integral) else {
            return nil
        }

        return detachedCopy(of: renderedImage)
    }

    private static func detachedCopy(of image: CGImage) -> CGImage? {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage()
    }
}
