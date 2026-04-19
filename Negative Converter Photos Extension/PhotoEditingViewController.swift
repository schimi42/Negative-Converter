//
//  PhotoEditingViewController.swift
//  Negative Converter Photos Extension
//
//  Created by Michell Schimanski on 19.04.26.
//

import AppKit
import Photos
import PhotosUI

final class PhotoEditingViewController: NSViewController, PHContentEditingController {
    private var input: PHContentEditingInput?
    private let imageView = NSImageView()
    private let statusLabel = NSTextField(labelWithString: "Negative Converter")

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.alignment = .center
        statusLabel.font = .systemFont(ofSize: 15, weight: .medium)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(imageView)
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            statusLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),

            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            imageView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 16),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ])
    }

    func canHandle(_ adjustmentData: PHAdjustmentData) -> Bool {
        adjustmentData.formatIdentifier == Self.adjustmentFormatIdentifier
    }

    func startContentEditing(with contentEditingInput: PHContentEditingInput, placeholderImage: NSImage) {
        input = contentEditingInput
        imageView.image = placeholderImage
        statusLabel.stringValue = "Ready to invert this negative."

        if let fullSizeImageURL = contentEditingInput.fullSizeImageURL,
           let preview = NSImage(contentsOf: fullSizeImageURL),
           let invertedPreview = try? NegativeImageProcessor.invertedImage(from: preview) {
            imageView.image = invertedPreview
            statusLabel.stringValue = "Positive preview ready. Click Save Changes in Photos."
        }
    }

    func finishContentEditing(completionHandler: @escaping (PHContentEditingOutput?) -> Void) {
        guard let input, let inputURL = input.fullSizeImageURL else {
            completionHandler(nil)
            return
        }

        let output = PHContentEditingOutput(contentEditingInput: input)
        output.adjustmentData = PHAdjustmentData(
            formatIdentifier: Self.adjustmentFormatIdentifier,
            formatVersion: "1.0",
            data: Data("invert".utf8)
        )

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try NegativeImageProcessor.invertedImageData(from: inputURL, outputType: .jpeg)
                try data.write(to: output.renderedContentURL, options: .atomic)
                completionHandler(output)
            } catch {
                completionHandler(nil)
            }
        }
    }

    var shouldShowCancelConfirmation: Bool {
        false
    }

    func cancelContentEditing() {
        input = nil
    }

    private static let adjustmentFormatIdentifier = "de.lumirio.Negative-Converter.invert"
}
