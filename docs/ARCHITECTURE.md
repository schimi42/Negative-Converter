# Architecture

This document explains how the project is structured and how the main pieces fit together.

## Project layout

- `Negative Converter.xcodeproj`
  - The Xcode project for the macOS app and the Photos editing extension.
- `Negative Converter/`
  - The main app target.
- `Negative Converter Photos Extension/`
  - The Apple Photos editing extension target.
- `Shared/`
  - Source files intended to be reused across app targets.
- `docs/`
  - Project documentation for release preparation and future maintenance.

## Main app target

The main app is intentionally small and centered around a straightforward SwiftUI plus view model architecture.

### Entry point

- `Negative_ConverterApp.swift`
  - App bootstrap.
  - Creates the main window and loads `ContentView`.

### User interface

- `ContentView.swift`
  - The primary SwiftUI view tree.
  - Owns the three-pane application layout:
    - left sidebar for import and opened photos
    - center preview area for negative and positive views
    - right inspector for geometry and crop controls
  - Contains the Photos Library sheet and supporting view types used by the main app.
  - Contains small AppKit bridges where macOS-native behavior is needed, such as the resettable slider.

### View model and state

- `ConverterViewModel.swift`
  - Central application state and workflow coordinator.
  - Manages:
    - imported file items
    - Photos Library browsing and selection
    - selection state in the app
    - shared and per-photo crop state
    - geometry adjustment values
    - save and export actions
  - Acts as the boundary between UI events and image-processing or PhotoKit operations.
- `PhotosLibraryModels.swift`
  - macOS app-side models for the custom Photos Library picker.
  - Kept outside shared code because they depend on PhotoKit and AppKit thumbnail types.

## Shared code

The shared area contains code that should remain independent from a specific app surface where possible.

### Models

- `Shared/Models/CropSettings.swift`
  - Stores normalized crop values used by the crop editor and processing pipeline.
- `Shared/Models/ImageAdjustmentSettings.swift`
  - Stores geometry and processing adjustments such as rotation, correction, mirroring, and grayscale output.
- `Shared/Models/BatchImageItem.swift`
  - Stores the platform-neutral image batch item state using `CGImage`.
- `Shared/Models/BatchSourceKind.swift`
  - Describes whether the current batch is file-based, Photos-based, mixed, or empty.
- `Shared/Models/CropAspectRatio.swift`
  - Defines reusable crop aspect-ratio presets.
- `Shared/Models/CropEdge.swift`
  - Identifies the crop edge being edited by the UI.

### Image processing

- `Shared/Processing/NegativeImageProcessor.swift`
  - Contains the image-processing pipeline.
  - Responsible for:
    - building preview images
    - inverting black-and-white negatives
    - applying crop and geometric adjustments
    - writing output files to disk
  - This file is the best place for future work on image quality, inversion tuning, and output formats.
  - It is currently shared by the main macOS app and the Photos editing extension.

### Assets and entitlements

- `Assets.xcassets`
  - App icon and color assets.
- `Negative Converter.entitlements`
  - Sandbox and Photos-related entitlements needed by the app.
- `Info.plist`
  - App metadata, permissions messaging, and bundle configuration.

## Photos editing extension

The Photos extension exists so the app can be called directly from Apple Photos through `Edit With`.

- `PhotoEditingViewController.swift`
  - The extension controller used by Photos.
  - Handles the single-image editing flow Apple Photos provides to editing extensions.

The extension is separate from the standalone batch workflow:

- Apple Photos extensions process one image at a time.
- Batch import, review, crop sharing, and batch export are handled by the standalone app target.

## Data flow

The high-level data flow in the standalone app is:

1. The user imports files or opens the Photos Library picker.
2. `ContentView` forwards actions to `ConverterViewModel`.
3. `ConverterViewModel` loads images and maintains selection and editing state.
4. `NegativeImageProcessor` generates previews and converted output images.
5. The user saves back to the source or exports new files.

## Crop model

The crop workflow is intentionally split into:

- a draft crop shown by the editor bars in the UI
- an applied crop stored for conversion

This allows the app to:

- keep crop editing responsive while dragging
- apply crop only when the user confirms with an action button
- support a shared crop for the whole batch
- let individual photos opt out after a per-photo reset or apply action

## Current architectural style

The project is not heavily abstracted. Most behavior lives in three places:

- SwiftUI views in `ContentView.swift`
- state and workflow in `ConverterViewModel.swift`
- processing in `Shared/Processing/NegativeImageProcessor.swift`

That keeps the code easy to navigate for a small app, but as the project grows it may make sense to split some responsibilities into separate files, for example:

- Photos Library browser state
- export and save services
- reusable inspector controls
- crop and selection state models

## Suggested extension points

If the app grows toward a broader release, these are the most natural extension points:

- improved inversion presets and film-specific profiles
- metadata-aware export naming
- stronger undo/redo support for crop and geometry changes
- more structured separation between standalone app workflows and Photos extension workflows
- unit tests around crop logic and image-processing parameters
