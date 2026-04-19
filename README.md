# Negative Converter

Negative Converter is a macOS app for converting black-and-white film negatives into positive images. It can run as a standalone app for batch processing and includes a Photos editing extension for use from Apple Photos.

## Features

- Open one or many image files from Finder.
- Load images from the system Photos Library.
- Invert black-and-white negatives into positives.
- Batch-convert and save multiple selected images.
- Crop a scanned negative once and apply the same crop across a batch.
- Preview the crop on both the negative and positive image.
- Drag crop edges directly on the image.
- Move the whole crop selection across the photo.
- Lock the crop to common negative formats, including 35mm, 6x4.5, 6x6, 6x7, and 4x5.
- Automatically flip locked crop ratios for vertical photos.
- Save file-based edits back to disk or write adjusted Photos Library assets through PhotoKit.

## Requirements

- macOS
- Xcode
- A configured Apple development team for signing the app and Photos extension

## Building

Open `Negative Converter.xcodeproj` in Xcode and run the `Negative Converter` scheme.

From Terminal:

```sh
xcodebuild -project "Negative Converter.xcodeproj" -scheme "Negative Converter" -configuration Debug build
```

## Photos Library Access

The standalone app reads from the system Photos Library through PhotoKit. If you use multiple Photos libraries, macOS exposes the one marked as the System Photo Library to PhotoKit.

The Photos editing extension is available from Apple Photos through `Edit With` / `Bearbeiten mit`. Apple Photos sends one image at a time to editing extensions, so batch processing is handled by the standalone app.

## Privacy

Image processing happens locally on the Mac. The app does not upload photos to a remote service.

## Current Status

This is an early working version focused on black-and-white negative inversion, batch handling, Photos Library access, and repeatable crop workflows.

