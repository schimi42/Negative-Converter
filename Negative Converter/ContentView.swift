//
//  ContentView.swift
//  Negative Converter
//
//  Created by Michell Schimanski on 19.04.26.
//

import SwiftUI
import Photos
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var viewModel = ConverterViewModel()
    @State private var isShowingImporter = false
    @State private var isShowingPhotosLibrary = false

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
        } detail: {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    VSplitView {
                        imagePane(title: "Negative", image: viewModel.originalImage, showsCrop: true, isCropEditable: true)
                        imagePane(title: "Positive", image: viewModel.convertedImage, showsCrop: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 420)

                    Divider()

                    editingInspector
                        .frame(width: 240)
                }
                .frame(minHeight: 420)

                Divider()

                footer
            }
        }
        .frame(minWidth: 920, minHeight: 620)
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

    private var sidebar: some View {
        List(selection: Binding(
            get: { viewModel.selectedID },
            set: { selectedID in
                guard let selectedID,
                      let item = viewModel.items.first(where: { $0.id == selectedID }) else {
                    return
                }

                viewModel.select(item)
            }
        )) {
            Section("Import") {
                Button {
                    isShowingImporter = true
                } label: {
                    Label("Open Images", systemImage: "folder")
                }
                .buttonStyle(.plain)

                Button {
                    isShowingPhotosLibrary = true
                    viewModel.loadPhotosLibrary()
                } label: {
                    Label("Open Photos Library", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.plain)
            }

            Section("Opened Photos") {
                if viewModel.items.isEmpty {
                    Label("No photos opened", systemImage: "photo.stack")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.items) { item in
                        BatchRow(item: item)
                            .tag(item.id)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private var editingInspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Geometry")
                    .font(.title2.weight(.semibold))

                AdjustmentSliderRow(
                    title: "Rotation",
                    systemImage: "dial.low",
                    value: Binding(
                        get: { viewModel.adjustments.rotationDegrees },
                        set: { viewModel.setRotationDegrees($0) }
                    ),
                    range: -45...45,
                    defaultValue: 0,
                    valueSuffix: "°"
                )

                AdjustmentSliderRow(
                    title: "Vertical",
                    systemImage: "arrow.up.and.down.righttriangle.up.fill.righttriangle.down.fill",
                    value: Binding(
                        get: { viewModel.adjustments.verticalCorrectionDegrees },
                        set: { viewModel.setVerticalCorrectionDegrees($0) }
                    ),
                    range: -20...20,
                    defaultValue: 0,
                    valueSuffix: "°"
                )

                AdjustmentSliderRow(
                    title: "Horizontal",
                    systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill",
                    value: Binding(
                        get: { viewModel.adjustments.horizontalCorrectionDegrees },
                        set: { viewModel.setHorizontalCorrectionDegrees($0) }
                    ),
                    range: -20...20,
                    defaultValue: 0,
                    valueSuffix: "°"
                )

                Button {
                    viewModel.toggleMirroring()
                } label: {
                    Label("Mirror", systemImage: viewModel.adjustments.isMirroredHorizontally ? "flip.horizontal.fill" : "flip.horizontal")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.resetAdjustments()
                } label: {
                    Text("Reset Geometry")
                        .frame(maxWidth: .infinity)
                }
                .disabled(viewModel.adjustments.isIdentity || viewModel.items.isEmpty)

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Crop")
                        .font(.title3.weight(.semibold))

                    Label("Aspect Ratio", systemImage: "aspectratio")
                        .font(.headline)

                    ForEach(viewModel.cropAspectRatios) { ratio in
                        Button {
                            viewModel.selectCropAspectRatio(ratio.id)
                        } label: {
                            HStack {
                                if viewModel.selectedCropAspectRatioID == ratio.id {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.semibold))
                                        .frame(width: 14)
                                } else {
                                    Color.clear
                                        .frame(width: 14, height: 14)
                                }

                                Text(ratio.title)
                                    .foregroundStyle(.primary)

                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    viewModel.applyCropToSelected()
                } label: {
                    Text("Apply Crop")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!viewModel.hasSelectedItem || !viewModel.hasPendingCropChanges)

                Button {
                    viewModel.applyCropToAll()
                } label: {
                    Text("Apply Crop to All")
                        .frame(maxWidth: .infinity)
                }
                .disabled(viewModel.items.isEmpty)

                Button {
                    viewModel.resetCrop()
                } label: {
                    Text("Reset Crop")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!viewModel.hasSelectedItem || (viewModel.crop.isIdentity && !viewModel.hasPendingCropChanges))

                Button {
                    viewModel.resetCropForAll()
                } label: {
                    Text("Reset Crop on All")
                        .frame(maxWidth: .infinity)
                }
                .disabled(viewModel.items.isEmpty || viewModel.items.allSatisfy(\.crop.isIdentity))
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
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

            Spacer(minLength: 20)

            Button(selectedSaveLabel) {
                viewModel.saveSelected()
            }
            .disabled(viewModel.convertedImage == nil)

            Button(saveAllLabel) {
                viewModel.saveAll()
            }
            .disabled(!viewModel.canSave)

            Button(exportSelectedLabel) {
                viewModel.exportSelectedToFolder()
            }
            .disabled(viewModel.convertedImage == nil)

            Button(exportAllLabel) {
                viewModel.exportAllToFolder()
            }
            .disabled(!viewModel.canSave)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private var selectedSaveLabel: String {
        switch viewModel.selectedSourceKind {
        case .photos:
            "Save to Photos"
        case .files, .mixed, .none:
            "Save"
        }
    }

    private var saveAllLabel: String {
        switch viewModel.batchSourceKind {
        case .photos:
            "Save All to Photos"
        case .files, .mixed, .none:
            "Save All"
        }
    }

    private var exportSelectedLabel: String {
        "Export..."
    }

    private var exportAllLabel: String {
        "Export All..."
    }
}

#Preview {
    ContentView()
}

private struct BatchRow: View {
    let item: BatchImageItem

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .textBackgroundColor))

                Image(nsImage: item.originalImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 34, height: 34)
                    .clipped()
            }
            .frame(width: 34, height: 34)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 1)
            }

            Text(item.fileName)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }
}

private struct AdjustmentSliderRow: View {
    let title: String
    let systemImage: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let defaultValue: Double
    let valueSuffix: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)

                Text(title)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(formattedValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            ResettableSlider(
                value: $value,
                range: range,
                defaultValue: defaultValue
            )
            .frame(height: 14)
        }
    }

    private var formattedValue: String {
        "\(Int(value.rounded()))\(valueSuffix)"
    }
}

private struct ResettableSlider: NSViewRepresentable {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let defaultValue: Double

    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value, defaultValue: defaultValue)
    }

    func makeNSView(context: Context) -> NSSlider {
        let slider = DoubleClickResetSlider(value: value, minValue: range.lowerBound, maxValue: range.upperBound, target: context.coordinator, action: #selector(Coordinator.valueChanged(_:)))
        slider.resetDelegate = context.coordinator
        slider.controlSize = .small
        return slider
    }

    func updateNSView(_ nsView: NSSlider, context: Context) {
        if nsView.doubleValue != value {
            nsView.doubleValue = value
        }

        nsView.minValue = range.lowerBound
        nsView.maxValue = range.upperBound
        context.coordinator.value = $value
        context.coordinator.defaultValue = defaultValue
    }

    final class Coordinator: NSObject, DoubleClickResetSliderDelegate {
        var value: Binding<Double>
        var defaultValue: Double

        init(value: Binding<Double>, defaultValue: Double) {
            self.value = value
            self.defaultValue = defaultValue
        }

        @objc func valueChanged(_ sender: NSSlider) {
            value.wrappedValue = sender.doubleValue
        }

        func sliderDidReceiveDoubleClick(_ slider: NSSlider) {
            slider.doubleValue = defaultValue
            value.wrappedValue = defaultValue
        }
    }
}

private protocol DoubleClickResetSliderDelegate: AnyObject {
    func sliderDidReceiveDoubleClick(_ slider: NSSlider)
}

private final class DoubleClickResetSlider: NSSlider {
    weak var resetDelegate: DoubleClickResetSliderDelegate?

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            resetDelegate?.sliderDidReceiveDoubleClick(self)
            return
        }

        super.mouseDown(with: event)
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
    @State private var searchText = ""

    private let columns = [
        GridItem(.adaptive(minimum: 88, maximum: 112), spacing: 14)
    ]

    private var filteredItems: [PhotosLibraryItem] {
        guard !searchText.isEmpty else {
            return viewModel.photosLibraryItems
        }

        return viewModel.photosLibraryItems.filter {
            $0.title.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        HSplitView {
            PhotosLibrarySidebar(
                collections: viewModel.photosLibraryCollections,
                selectedCollectionID: viewModel.selectedPhotosCollectionID
            ) { collection in
                viewModel.selectPhotosLibraryCollection(collection)
            }
                .frame(minWidth: 170, idealWidth: 190, maxWidth: 220)

            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    Text(viewModel.selectedPhotosLibraryCollection?.title ?? "Photos")
                        .font(.headline)
                        .lineLimit(1)
                        .frame(width: 140, alignment: .leading)

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search Library", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    .frame(maxWidth: 360)

                    Spacer()

                    Button {
                        viewModel.loadPhotosLibrary()
                    } label: {
                        Label("Reload", systemImage: "arrow.clockwise")
                    }
                    .labelStyle(.iconOnly)
                    .disabled(viewModel.isLoadingPhotosLibrary)
                    .help("Reload Photos Library")
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)

                Divider()

                if viewModel.isLoadingPhotosLibrary && viewModel.photosLibraryItems.isEmpty {
                    ProgressView("Loading Photos Library...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.photosLibraryItems.isEmpty {
                    ContentUnavailableView("No Photos Loaded", systemImage: "photo.on.rectangle", description: Text("Grant access to Photos and reload the library."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredItems.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                            ForEach(filteredItems) { item in
                                PhotosLibraryGridItem(
                                    item: item,
                                    isSelected: viewModel.selectedPhotosAssetIDs.contains(item.id)
                                ) {
                                    viewModel.togglePhotosLibrarySelection(item)
                                }
                            }
                        }
                        .padding(18)
                    }
                }

                Divider()

                HStack {
                    Spacer()

                    VStack(spacing: 2) {
                        Text("Choose Photos")
                            .font(.caption.bold())
                        Text("\(viewModel.selectedPhotosAssetIDs.count) selected")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Cancel") {
                        isPresented = false
                    }

                    Button("Add") {
                        viewModel.addSelectedPhotosToBatch()
                        isPresented = false
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!viewModel.hasPhotosLibrarySelection || viewModel.isLoadingPhotosLibrary)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
            }
        }
        .onDisappear {
            viewModel.isLoadingPhotosLibrary = false
        }
    }
}

private struct PhotosLibrarySidebar: View {
    let collections: [PhotosLibraryCollection]
    let selectedCollectionID: String
    let onSelect: (PhotosLibraryCollection) -> Void

    private var sections: [String] {
        ["Library", "Pinned", "Albums"].filter { section in
            collections.contains { $0.section == section }
        }
    }

    var body: some View {
        List {
            ForEach(sections, id: \.self) { section in
                Section(section) {
                    ForEach(collections.filter { $0.section == section }) { collection in
                        Button {
                            onSelect(collection)
                        } label: {
                            Label(collection.title, systemImage: collection.systemImage)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(
                            collection.id == selectedCollectionID
                            ? Color.accentColor.opacity(0.18)
                            : Color.clear
                        )
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
}

private struct PhotosLibraryGridItem: View {
    let item: PhotosLibraryItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                Rectangle()
                    .fill(Color(nsColor: .textBackgroundColor))

                PhotosLibraryThumbnailView(asset: item.asset)

                if isSelected {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.white, lineWidth: 3)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.accentColor)
                        .padding(5)
                }
            }
            .frame(width: 88, height: 66)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isSelected ? Color.accentColor : Color(nsColor: .separatorColor).opacity(0.35), lineWidth: isSelected ? 2 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .help(item.title)
    }
}

private struct PhotosLibraryThumbnailView: View {
    let asset: PHAsset
    @State private var thumbnail: NSImage?

    var body: some View {
        Group {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 88, height: 66)
        .clipped()
        .task(id: asset.localIdentifier) {
            thumbnail = await loadThumbnail(for: asset)
        }
    }

    private func loadThumbnail(for asset: PHAsset) async -> NSImage? {
        let manager = PHCachingImageManager()
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        return await withCheckedContinuation { continuation in
            manager.requestImage(
                for: asset,
                targetSize: CGSize(width: 176, height: 132),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}
