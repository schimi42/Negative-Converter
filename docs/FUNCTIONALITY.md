# Functionality Guide

This document describes what the app currently does and how the main workflows are intended to behave.

## Purpose

Negative Converter is a macOS app for converting black-and-white film negatives into positive images.

It supports two main use cases:

- batch work in the standalone app
- single-image editing from Apple Photos through the Photos extension

## Main workflows

### 1. Open files from Finder

Users can open one or more image files directly from the filesystem.

Typical flow:

1. Click `Open Images`.
2. Choose one or more image files.
3. Review the negative and positive previews.
4. Adjust geometry or crop.
5. Save back to the original files or export new files.

### 2. Open images from the Photos Library

Users can browse the system Photos Library inside the app.

Current picker behavior includes:

- native-style sidebar with albums and smart collections
- searchable thumbnail grid
- multiple selection
- Shift-click range selection

After importing, the selected Photos items become part of the same batch workflow as file-based images.

### 3. Edit from Apple Photos

The Photos extension allows opening a single image through Apple Photos.

This is intended for direct save-back workflows when the source image already lives in Photos.

## Preview layout

The main window is organized into three areas:

- left sidebar
  - import actions
  - list of opened photos
- center previews
  - negative preview
  - positive preview
- right inspector
  - geometry controls
  - crop settings

This layout is designed to feel closer to a native macOS photo-editing utility.

## Geometry controls

The inspector provides these geometry tools:

- rotation
- vertical correction
- horizontal correction
- mirror

Behavior:

- geometry changes are applied immediately to previews and conversions
- sliders can be reset by double-clicking them
- `Reset Geometry` clears all geometry adjustments

## Crop workflow

Crop behavior is intentionally different from geometry behavior.

### Draft crop

Dragging the crop bars changes the draft crop only.

This keeps the UI responsive and avoids reprocessing images on every drag step.

### Applying crop

The draft crop is committed only when the user explicitly chooses one of these actions:

- `Apply Crop`
- `Apply Crop to All`

### Shared crop

By default, crop is shared across the current batch. This is useful when many scans were captured with the same framing.

### Per-photo override

If the user resets or applies crop for a single image, that image becomes independent from the shared crop until the user reapplies crop to all images.

### Reset actions

The current app supports:

- `Reset Crop`
  - reset crop for the selected image only
- `Reset Crop on All`
  - reset crop for the whole batch and re-link all images to the shared crop

## Aspect ratio presets

The crop inspector supports common film and print aspect ratios:

- Free
- 35mm / 6x9 (3:2)
- 6x4.5 (4:3)
- 6x6 (1:1)
- 6x7 (7:6)
- 4x5 (5:4)

If a photo is vertical, the crop ratio is automatically oriented to fit the image.

## Save and export behavior

The footer actions change meaning slightly depending on the image source.

### For Photos-based images

- `Save to Photos`
  - writes the converted result back into the Photos asset
- `Save All to Photos`
  - writes all opened Photos items back to Photos

### For file-based images

- `Save`
  - writes the converted result back to the original file
- `Save All`
  - writes all converted results back to their original files

### Export actions

- `Export...`
  - exports the selected image as a new file
- `Export All...`
  - exports all converted images as new files

## Photos Library specifics

There are two distinct Photos-related workflows:

- browsing the Photos Library inside the standalone app
- editing a single photo from Apple Photos through the extension

The standalone app uses PhotoKit to browse and import images from the system library.

The Photos extension uses the Apple Photos editing pipeline, which is more constrained and intentionally limited to one image at a time.

## Local-only processing

Image processing is performed locally on the Mac.

The app does not depend on a remote image-processing service.

## Current scope

The current release scope is focused on:

- black-and-white negative inversion
- batch-friendly workflows
- Photos Library integration
- crop reuse across similar scans
- save-back and export flows for both file and Photos sources

Future documentation can expand this guide with screenshots, release notes, and troubleshooting tips as the app moves toward public release.
