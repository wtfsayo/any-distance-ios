// Licensed under the Any Distance Source-Available License
//
//  PhotoLibrarySaver.swift
//  ADAC
//
//  Created by Daniel Kuntz on 3/7/22.
//

import Foundation
import Photos
import UIKit

class PhotoLibrarySaver {
    static func saveImage(_ image: UIImage, completion: ((Bool, PHObjectPlaceholder?, Error?) -> Void)? = nil) {
        guard let pngData = image.pngData() else {
            return
        }

        var placeholder: PHObjectPlaceholder?
        PHPhotoLibrary.requestAuthorization { (status) in
            guard status == .authorized else {
                showPhotosError()
                return
            }

            createOrFetchAssetCollection { collection in
                guard let collection = collection else {
                    return
                }

                PHPhotoLibrary.shared().performChanges {
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    creationRequest.addResource(with: .photo, data: pngData, options: nil)
                    placeholder = creationRequest.placeholderForCreatedAsset
                    let albumChangeRequest = PHAssetCollectionChangeRequest(for: collection)
                    let enumeration: NSArray = [placeholder!]
                    albumChangeRequest?.addAssets(enumeration)
                } completionHandler: { success, error in
                    DispatchQueue.main.async {
                        completion?(success, placeholder, error)
                    }
                }
            }
        }
    }

    static func saveVideo(_ videoUrl: URL, completion: ((Bool, PHObjectPlaceholder?, Error?) -> Void)? = nil) {
        var placeholder: PHObjectPlaceholder?
        PHPhotoLibrary.requestAuthorization { (status) in
            guard status == .authorized else {
                showPhotosError()
                return
            }

            createOrFetchAssetCollection { collection in
                guard let collection = collection else {
                    return
                }

                PHPhotoLibrary.shared().performChanges {
                    let creationRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoUrl)
                    placeholder = creationRequest?.placeholderForCreatedAsset
                    let albumChangeRequest = PHAssetCollectionChangeRequest(for: collection)
                    let enumeration: NSArray = [placeholder!]
                    albumChangeRequest?.addAssets(enumeration)
                } completionHandler: { success, error in
                    DispatchQueue.main.async {
                        completion?(success, placeholder, error)
                    }
                }
            }
        }
    }

    private static func createOrFetchAssetCollection(completion: @escaping (PHAssetCollection?) -> Void) {
        if let collection = assetCollectionForAlbum() {
            completion(collection)
            return
        }

        createAlbum {
            completion(self.assetCollectionForAlbum())
        }
    }

    private static func assetCollectionForAlbum() -> PHAssetCollection? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", "Any Distance")
        let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        return collection.firstObject
    }

    private static func createAlbum(_ completion: @escaping () -> Void) {
        PHPhotoLibrary.shared().performChanges {
            PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: "Any Distance")
        } completionHandler: { success, error in
            completion()
        }
    }

    private static func showPhotosError() {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "To save photos, allow photos access in Settings.", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
            alert.addAction(UIAlertAction(title: "Open Settings", style: .default, handler: { _ in
                let url = URL(string: UIApplication.openSettingsURLString)!
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }))
            UIApplication.shared.topViewController?.present(alert, animated: true, completion: nil)
        }
    }
}
