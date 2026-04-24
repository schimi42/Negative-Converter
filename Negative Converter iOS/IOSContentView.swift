//
//  IOSContentView.swift
//  Lumirio Negative Converter iOS
//
//  Created by Michell Schimanski on 24.04.26.
//

import CoreGraphics
import Photos
import PhotosUI
import SwiftUI

struct IOSContentView: View {
    @StateObject private var viewModel = IOSConverterViewModel()
    @State private var pickerItems: [PhotosPickerItem] = []

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .onChange(of: pickerItems) { _, newItems in
            Task {
                await viewModel.importPhotos(from: newItems)
            }
        }
        .task {
            await viewModel.preparePhotoLibraryAccess()
        }
        .safeAreaInset(edge: .bottom) {
            Text(viewModel.message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.bar)
        }
    }

    private var sidebar: some View {
        List(selection: $viewModel.selectedID) {
            ForEach(viewModel.items) { item in
                IOSImageRow(item: item)
                    .tag(item.id)
            }
        }
        .navigationTitle("Photos")
        .overlay {
            if viewModel.items.isEmpty {
                ContentUnavailableView(
                    "No Photos",
                    systemImage: "photo.on.rectangle",
                    description: Text("Choose photos from your library to convert them.")
                )
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if viewModel.needsFullPhotosAccess {
                    Button("Open Settings") {
                        viewModel.openAppSettings()
                    }
                }

                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: 20,
                    matching: .images,
                    preferredItemEncoding: .current,
                    photoLibrary: .shared()
                ) {
                    Label("Choose Photos", systemImage: "photo.badge.plus")
                }
                .disabled(!viewModel.canChoosePhotos)
            }
        }
    }

    private var detail: some View {
        IOSImageDetail(item: viewModel.selectedItem, isImporting: viewModel.isImporting)
            .navigationTitle("Negative Converter")
            .toolbar {
                ToolbarItem(placement: .status) {
                    if viewModel.isImporting || viewModel.isSaving {
                        ProgressView()
                    }
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Save") {
                        Task {
                            await viewModel.saveSelectedToPhotos()
                        }
                    }
                    .disabled(!viewModel.canSaveSelected || viewModel.isSaving)

                    Button("Save All") {
                        Task {
                            await viewModel.saveAllToPhotos()
                        }
                    }
                    .disabled(!viewModel.canSaveAll || viewModel.isSaving)
                }
            }
    }
}

private struct IOSImageRow: View {
    let item: IOSImageItem

    var body: some View {
        HStack(spacing: 12) {
            Image(decorative: item.originalCGImage, scale: 1)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(item.title)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}

private struct IOSImageDetail: View {
    let item: IOSImageItem?
    let isImporting: Bool

    var body: some View {
        ScrollView {
            if let item {
                VStack(alignment: .leading, spacing: 20) {
                    IOSImagePane(title: "Negative", image: item.originalCGImage)

                    if let convertedCGImage = item.convertedCGImage {
                        IOSImagePane(title: "Positive", image: convertedCGImage)
                    }
                }
                .padding()
            } else {
                ContentUnavailableView(
                    isImporting ? "Importing Photos" : "Choose Photos",
                    systemImage: isImporting ? "hourglass" : "camera.filters",
                    description: Text(isImporting ? "The selected photos are being converted." : "Use the Photos button to import negatives from your library.")
                )
                .frame(maxWidth: .infinity, minHeight: 360)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

private struct IOSImagePane: View {
    let title: String
    let image: CGImage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            Image(decorative: image, scale: 1)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

#Preview {
    IOSContentView()
}
