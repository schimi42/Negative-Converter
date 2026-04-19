//
//  ContentView.swift
//  Negative Converter
//
//  Created by Michell Schimanski on 19.04.26.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var viewModel = ConverterViewModel()
    @State private var isShowingImporter = false
    @State private var isShowingPhotosLibrary = false
    @State private var batchThumbnailSize = 126.0

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            cropControls

            Divider()

            HSplitView {
                batchList
                    .frame(minWidth: 260, idealWidth: 380, maxWidth: 760)

                HSplitView {
                    imagePane(title: "Negative", image: viewModel.originalImage, showsCrop: true, isCropEditable: true)
                    imagePane(title: "Positive", image: viewModel.convertedImage, showsCrop: true)
                }
            }
            .frame(minHeight: 420)

            Divider()

            footer
        }
        .frame(minWidth: 860, minHeight: 620)
        .fileImporter(isPresented: $isShowingImporter, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                viewModel.open(urls)
            case .failure(let error):
                viewModel.message = error.localizedDescription
            }
        }
        .sheet(isPresented: $isShowingPhotosLibrary) {
            PhotosLibrarySheet(viewModel: viewModel, isPresented: $isShowingPhotosLibrary)
                .frame(minWidth: 760, minHeight: 560)
        }
        .onOpenURL { url in
            viewModel.open(url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openedImageURLs)) { notification in
            guard let urls = notification.userInfo?["urls"] as? [URL] else {
                return
            }

            viewModel.open(urls)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Negative Converter")
                .font(.largeTitle.bold())
            Text("Open black and white negatives, invert them, then save the positive images.")
                .foregroundStyle(.secondary)

            HStack {
                Button("Open Images") {
                    isShowingImporter = true
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Open Photos Library") {
                    isShowingPhotosLibrary = true
                    viewModel.loadPhotosLibrary()
                }

                Button("Invert Selected") {
                    viewModel.convertSelected()
                }
                .disabled(viewModel.originalImage == nil)

                Button("Invert All") {
                    viewModel.convertAll()
                }
                .disabled(viewModel.items.isEmpty)

                Button("Apply Crop to All") {
                    viewModel.applyCropToAll()
                }
                .disabled(viewModel.items.isEmpty)

                Button("Save Selected") {
                    viewModel.saveSelected()
                }
                .disabled(viewModel.convertedImage == nil)

                Button("Save All") {
                    viewModel.saveAll()
                }
                .disabled(!viewModel.canSave)

                Button("Export All...") {
                    viewModel.exportAllToFolder()
                }
                .disabled(!viewModel.canSave)

                Spacer()
            }
        }
        .padding(24)
    }

    private var cropControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Crop")
                    .font(.headline)

                Text("Use the same border trim for every image in the batch.")
                    .foregroundStyle(.secondary)

                Spacer()

                Picker("Format", selection: Binding(
                    get: { viewModel.selectedCropAspectRatioID },
                    set: { viewModel.selectCropAspectRatio($0) }
                )) {
                    ForEach(viewModel.cropAspectRatios) { ratio in
                        Text(ratio.title).tag(ratio.id)
                    }
                }
                .labelsHidden()
                .frame(width: 180)

                Toggle("Fixed ratio", isOn: Binding(
                    get: { viewModel.isCropAspectRatioLocked },
                    set: { viewModel.setCropAspectRatioLocked($0) }
                ))
                .disabled(viewModel.selectedCropAspectRatio.ratio == nil)

                Button("Reset Crop") {
                    viewModel.resetCrop()
                }
                .disabled(viewModel.crop.isIdentity || viewModel.items.isEmpty)
            }

            Grid(horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    cropSlider(title: "Left", value: viewModel.crop.left) { viewModel.setCrop(left: $0) }
                    cropSlider(title: "Top", value: viewModel.crop.top) { viewModel.setCrop(top: $0) }
                }

                GridRow {
                    cropSlider(title: "Right", value: viewModel.crop.right) { viewModel.setCrop(right: $0) }
                    cropSlider(title: "Bottom", value: viewModel.crop.bottom) { viewModel.setCrop(bottom: $0) }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private func cropSlider(title: String, value: Double, update: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .frame(width: 52, alignment: .leading)
            Slider(value: Binding(get: { value }, set: update), in: 0...0.45)
                .frame(minWidth: 130)
            Text(value.formatted(.percent.precision(.fractionLength(0))))
                .monospacedDigit()
                .frame(width: 42, alignment: .trailing)
        }
    }

    private var batchList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Batch")
                    .font(.headline)

                Spacer()

                Image(systemName: "rectangle.grid.2x2")
                    .foregroundStyle(.secondary)

                Slider(value: $batchThumbnailSize, in: 88...220)
                    .frame(width: 110)

                Text("\(viewModel.items.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding([.top, .horizontal], 16)
            .padding(.bottom, 8)

            if viewModel.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("No images loaded")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: batchThumbnailSize, maximum: batchThumbnailSize + 44), spacing: 10)], spacing: 10) {
                        ForEach(viewModel.items) { item in
                            BatchThumbnailCell(
                                item: item,
                                crop: viewModel.crop,
                                thumbnailSize: batchThumbnailSize,
                                isSelected: item.id == viewModel.selectedItem?.id
                            ) {
                                viewModel.select(item)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
        }
    }

    private func imagePane(title: String, image: NSImage?, showsCrop: Bool = false, isCropEditable: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            ZStack {
                Rectangle()
                    .fill(Color(nsColor: .textBackgroundColor))

                if let image {
                    FittedImageView(
                        image: image,
                        crop: viewModel.crop,
                        showsCrop: showsCrop,
                        isCropEditable: isCropEditable
                    ) { crop, changedEdge in
                        if let changedEdge {
                            viewModel.setCrop(crop, changedEdge: changedEdge)
                        } else {
                            viewModel.moveCrop(crop)
                        }
                    }
                        .padding()
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.system(size: 46))
                            .foregroundStyle(.secondary)
                        Text("No image loaded")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .border(Color(nsColor: .separatorColor))
        }
        .padding(20)
    }

    private var footer: some View {
        HStack {
            Text(viewModel.message)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer()

            if viewModel.selectedItem?.isFromPhotosLibrary == true {
                Text("Opened from Photos Library")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if viewModel.openedURL != nil {
                Text("Opened from Finder or Edit With")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }
}

#Preview {
    ContentView()
}

private struct BatchRow: View {
    let item: BatchImageItem

    private var iconName: String {
        item.convertedImage == nil ? "photo" : "checkmark.circle.fill"
    }

    private var iconColor: Color {
        item.convertedImage == nil ? .secondary : .green
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.fileName)
                    .lineLimit(1)
                Text(item.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }
}

private struct BatchThumbnailCell: View {
    let item: BatchImageItem
    let crop: CropSettings
    let thumbnailSize: Double
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    Rectangle()
                        .fill(Color(nsColor: .textBackgroundColor))

                    FittedImageView(image: item.originalImage, crop: crop, showsCrop: true)
                        .padding(4)
                }
                .aspectRatio(1, contentMode: .fit)
                .frame(minHeight: thumbnailSize)
                .border(isSelected ? Color.accentColor : Color(nsColor: .separatorColor), width: isSelected ? 2 : 1)

                Text(item.fileName)
                    .font(.caption)
                    .lineLimit(1)
                Text(item.status)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(6)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

private struct FittedImageView: View {
    let image: NSImage
    let crop: CropSettings
    let showsCrop: Bool
    var isCropEditable = false
    var onCropChange: ((CropSettings, CropEdge?) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            let imageFrame = fittedFrame(for: image.size, in: geometry.size)

            ZStack {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)

                if showsCrop {
                    CropOverlay(
                        crop: crop,
                        isEditable: isCropEditable,
                        onCropChange: onCropChange
                    )
                        .frame(width: imageFrame.width, height: imageFrame.height)
                        .position(x: imageFrame.midX, y: imageFrame.midY)
                }
            }
        }
    }

    private func fittedFrame(for imageSize: CGSize, in containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, containerSize.width > 0, containerSize.height > 0 else {
            return .zero
        }

        let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (containerSize.width - fittedSize.width) / 2,
            y: (containerSize.height - fittedSize.height) / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }
}

private struct CropOverlay: View {
    let crop: CropSettings
    var isEditable = false
    var onCropChange: ((CropSettings, CropEdge?) -> Void)?
    @State private var edgeDragStartCrop: CropSettings?
    @State private var moveDragStartCrop: CropSettings?

    var body: some View {
        GeometryReader { geometry in
            let rect = cropRect(in: geometry.size)

            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.28)

                Rectangle()
                    .fill(.clear)
                    .frame(width: rect.width, height: rect.height)
                    .background(.clear)
                    .position(x: rect.midX, y: rect.midY)
                    .blendMode(.destinationOut)

                Rectangle()
                    .stroke(Color.yellow, lineWidth: 2)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)

                if isEditable {
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .gesture(moveGesture(in: geometry.size))

                    CropHandle(edge: .left)
                        .frame(width: 18, height: rect.height)
                        .position(x: rect.minX, y: rect.midY)
                        .gesture(dragGesture(for: .left, in: geometry.size))

                    CropHandle(edge: .right)
                        .frame(width: 18, height: rect.height)
                        .position(x: rect.maxX, y: rect.midY)
                        .gesture(dragGesture(for: .right, in: geometry.size))

                    CropHandle(edge: .top)
                        .frame(width: rect.width, height: 18)
                        .position(x: rect.midX, y: rect.minY)
                        .gesture(dragGesture(for: .top, in: geometry.size))

                    CropHandle(edge: .bottom)
                        .frame(width: rect.width, height: 18)
                        .position(x: rect.midX, y: rect.maxY)
                        .gesture(dragGesture(for: .bottom, in: geometry.size))
                }
            }
            .compositingGroup()
        }
        .allowsHitTesting(isEditable)
    }

    private func cropRect(in size: CGSize) -> CGRect {
        CGRect(
            x: crop.left * size.width,
            y: crop.top * size.height,
            width: max(1, (1 - crop.left - crop.right) * size.width),
            height: max(1, (1 - crop.top - crop.bottom) * size.height)
        )
    }

    private func dragGesture(for edge: CropEdge, in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard size.width > 0, size.height > 0 else {
                    return
                }

                if edgeDragStartCrop == nil {
                    edgeDragStartCrop = crop
                }

                var nextCrop = edgeDragStartCrop ?? crop
                switch edge {
                case .left:
                    nextCrop.left += value.translation.width / size.width
                case .top:
                    nextCrop.top += value.translation.height / size.height
                case .right:
                    nextCrop.right -= value.translation.width / size.width
                case .bottom:
                    nextCrop.bottom -= value.translation.height / size.height
                }

                onCropChange?(nextCrop, edge)
            }
            .onEnded { _ in
                edgeDragStartCrop = nil
            }
    }

    private func moveGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard size.width > 0, size.height > 0 else {
                    return
                }

                if moveDragStartCrop == nil {
                    moveDragStartCrop = crop
                }

                let startCrop = moveDragStartCrop ?? crop
                let rect = startCrop.normalizedRect
                let newX = min(max(0, rect.minX + value.translation.width / size.width), 1 - rect.width)
                let newY = min(max(0, rect.minY + value.translation.height / size.height), 1 - rect.height)

                onCropChange?(CropSettings(
                    left: newX,
                    top: newY,
                    right: 1 - newX - rect.width,
                    bottom: 1 - newY - rect.height
                ), nil)
            }
            .onEnded { _ in
                moveDragStartCrop = nil
            }
    }
}

private struct CropHandle: View {
    let edge: CropEdge

    var body: some View {
        Rectangle()
            .fill(Color.yellow.opacity(0.08))
            .overlay(
                Rectangle()
                    .stroke(
                        Color.yellow.opacity(0.85),
                        style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                    )
            )
            .contentShape(Rectangle())
            .help(helpText)
    }

    private var helpText: String {
        switch edge {
        case .left:
            "Drag left crop edge"
        case .top:
            "Drag top crop edge"
        case .right:
            "Drag right crop edge"
        case .bottom:
            "Drag bottom crop edge"
        }
    }
}

private struct PhotosLibrarySheet: View {
    @Bindable var viewModel: ConverterViewModel
    @Binding var isPresented: Bool

    private let columns = [
        GridItem(.adaptive(minimum: 130, maximum: 170), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Photos Library")
                        .font(.title2.bold())
                    Text("Select images to add to the current batch.")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Reload") {
                    viewModel.loadPhotosLibrary()
                }
                .disabled(viewModel.isLoadingPhotosLibrary)

                Button("Cancel") {
                    isPresented = false
                }

                Button("Add Selected") {
                    viewModel.addSelectedPhotosToBatch()
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.hasPhotosLibrarySelection || viewModel.isLoadingPhotosLibrary)
            }
            .padding(20)

            Divider()

            if viewModel.isLoadingPhotosLibrary && viewModel.photosLibraryItems.isEmpty {
                ProgressView("Loading Photos Library...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.photosLibraryItems.isEmpty {
                ContentUnavailableView("No Photos Loaded", systemImage: "photo.on.rectangle", description: Text("Grant access to Photos and reload the library."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(viewModel.photosLibraryItems) { item in
                            PhotosLibraryGridItem(
                                item: item,
                                isSelected: viewModel.selectedPhotosAssetIDs.contains(item.id)
                            ) {
                                viewModel.togglePhotosLibrarySelection(item)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }
}

private struct PhotosLibraryGridItem: View {
    let item: PhotosLibraryItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Rectangle()
                        .fill(Color(nsColor: .textBackgroundColor))
                        .aspectRatio(1, contentMode: .fit)

                    if let thumbnail = item.thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                            .aspectRatio(1, contentMode: .fit)
                            .clipped()
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 30))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? .blue : .white)
                        .shadow(radius: 2)
                        .padding(8)
                }

                Text(item.title)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
            .padding(8)
            .background(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
            .border(isSelected ? Color.accentColor : Color(nsColor: .separatorColor), width: isSelected ? 2 : 1)
        }
        .buttonStyle(.plain)
    }
}
