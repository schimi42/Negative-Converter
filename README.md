# Negative Converter

Negative Converter is a macOS app for converting black-and-white film negatives into positive images. It includes:

- a standalone Mac app for batch work
- a Photos editing extension for single-image save-back from Apple Photos

The current app is focused on a practical local workflow: import scans, adjust geometry, define a crop once, and save or export clean positive images.

## Highlights

- Open one or many image files from Finder.
- Browse and import from the system Photos Library.
- Use the Photos editing extension through `Edit With` in Apple Photos.
- Convert black-and-white negatives into positives locally on the Mac.
- Review negative and positive previews side by side in the app.
- Adjust rotation, vertical correction, horizontal correction, and mirroring.
- Reuse one crop across a batch and override it for specific photos when needed.
- Use aspect-ratio presets for common film formats.
- Save back to the original source or export new files.

## Project status

This project is in an early release-preparation phase. The core workflows are already in place:

- file import
- Photos Library import
- Photos extension editing
- geometry adjustment
- shared and per-photo crop workflows
- save and export actions

## Requirements

- macOS
- Xcode
- an Apple development team configured for signing the app and Photos extension

## Build

Open [Negative Converter.xcodeproj](./Negative%20Converter.xcodeproj) in Xcode and run the `Negative Converter` scheme.

From Terminal:

```sh
xcodebuild -project "Negative Converter.xcodeproj" -scheme "Negative Converter" -configuration Debug build
```

## How it works

### Standalone app

The standalone app is the main workspace for batch conversion.

Typical flow:

1. Open images from Finder or the Photos Library.
2. Review the negative and positive previews.
3. Adjust geometry in the right inspector.
4. Define a crop and apply it to the current photo or the whole batch.
5. Save back to the source or export new files.

### Apple Photos extension

The Photos extension is available through Apple Photos via `Edit With`.

Apple Photos sends one image at a time to editing extensions, so the extension is best used for direct single-image save-back. Batch work is handled by the standalone app.

## Photos Library access

The standalone app uses PhotoKit to access the system Photos Library. If multiple Photos libraries exist on the Mac, PhotoKit exposes the library that is currently configured as the System Photo Library.

The in-app picker supports:

- album and smart-album browsing
- search
- multi-selection
- Shift-click range selection

## Privacy

Image processing happens locally on the Mac. The app does not upload images to a remote service.

## License

This project is licensed under the Mozilla Public License 2.0. See [LICENSE](./LICENSE).

## Documentation

- [Architecture](./docs/ARCHITECTURE.md)
- [Functionality Guide](./docs/FUNCTIONALITY.md)
