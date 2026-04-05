import Foundation
import Photos

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@Observable
final class PhotosService: NSObject {

    // MARK: - Published State

    private(set) var authorizationStatus: PHAuthorizationStatus = .notDetermined
    private(set) var hasChanges: Bool = false

    // MARK: - Change Observation

    private var isObserving: Bool = false

    // MARK: - Authorization

    @discardableResult
    func requestAuthorization() async -> Bool {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if current == .authorized || current == .limited {
            authorizationStatus = current
            return true
        }

        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status
        return status == .authorized || status == .limited
    }

    // MARK: - Fetching Screenshots

    func fetchScreenshots(limit: Int? = nil) async -> [PHAsset] {
        let granted = await requestAuthorization()
        guard granted else { return [] }

        return await Task.detached(priority: .userInitiated) {
            let options = PHFetchOptions()
            options.predicate = NSPredicate(
                format: "mediaType == %d AND (mediaSubtypes & %d) != 0",
                PHAssetMediaType.image.rawValue,
                PHAssetMediaSubtype.photoScreenshot.rawValue
            )
            options.sortDescriptors = [
                NSSortDescriptor(key: "creationDate", ascending: false)
            ]
            if let limit {
                options.fetchLimit = limit
            }

            let result = PHAsset.fetchAssets(with: .image, options: options)
            var assets: [PHAsset] = []
            assets.reserveCapacity(result.count)
            result.enumerateObjects { asset, _, _ in
                assets.append(asset)
            }
            return assets
        }.value
    }

    // MARK: - Loading Full-Resolution Image Data

    func loadImageData(for asset: PHAsset) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.version = .current
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { data, _, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }
                if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(
                        throwing: PhotosServiceError.imageDataUnavailable
                    )
                }
            }
        }
    }

    // MARK: - Loading Thumbnails

    func loadThumbnail(
        for asset: PHAsset,
        size: CGSize = CGSize(width: 300, height: 300)
    ) async throws -> Data {
        #if os(iOS)
        let image: UIImage = try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.version = .current
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            options.resizeMode = .exact

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if isDegraded { return }

                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }
                if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(
                        throwing: PhotosServiceError.thumbnailUnavailable
                    )
                }
            }
        }

        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            throw PhotosServiceError.thumbnailEncodingFailed
        }
        return jpegData

        #elseif os(macOS)
        let image: NSImage = try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.version = .current
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            options.resizeMode = .exact

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if isDegraded { return }

                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }
                if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(
                        throwing: PhotosServiceError.thumbnailUnavailable
                    )
                }
            }
        }

        guard let tiffData = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData),
              let jpegData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            throw PhotosServiceError.thumbnailEncodingFailed
        }
        return jpegData
        #endif
    }

    // MARK: - Change Observation

    func startObservingChanges() {
        guard !isObserving else { return }
        PHPhotoLibrary.shared().register(self)
        isObserving = true
    }

    func stopObservingChanges() {
        guard isObserving else { return }
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
        isObserving = false
    }

    deinit {
        if isObserving {
            PHPhotoLibrary.shared().unregisterChangeObserver(self)
        }
    }
}

// MARK: - PHPhotoLibraryChangeObserver

extension PhotosService: @preconcurrency PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        hasChanges = true
    }
}

// MARK: - Errors

enum PhotosServiceError: LocalizedError {
    case imageDataUnavailable
    case thumbnailUnavailable
    case thumbnailEncodingFailed

    var errorDescription: String? {
        switch self {
        case .imageDataUnavailable:
            return "Could not load image data for the requested asset."
        case .thumbnailUnavailable:
            return "Could not generate a thumbnail for the requested asset."
        case .thumbnailEncodingFailed:
            return "Failed to encode thumbnail image as JPEG."
        }
    }
}
