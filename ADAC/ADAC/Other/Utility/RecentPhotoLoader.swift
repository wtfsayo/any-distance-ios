// Licensed under the Any Distance Source-Available License
//
//  RecentPhotoLoader.swift
//  ADAC
//
//  Created by Daniel Kuntz on 6/24/21.
//

import UIKit
import Photos

final class RecentPhotoLoader {
    static func loadPhotos(forDate date: Date, maxCount: Int = 3, completion: @escaping ([UIImage]) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }

            DispatchQueue.global(qos: .userInitiated).async {
                let requestOptions = PHImageRequestOptions()
                requestOptions.isSynchronous = true
                requestOptions.isNetworkAccessAllowed = true

                let startDate = Calendar.current.startOfDay(for: date)
                let endDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate)!

                // Fetch the images between the start and end date
                let fetchOptions = PHFetchOptions()
                fetchOptions.predicate = NSPredicate(format: "creationDate > %@ AND creationDate < %@ AND (NOT ((mediaSubtype & %d) != 0))",
                                                     startDate as NSDate, endDate as NSDate, PHAssetMediaSubtype.photoScreenshot.rawValue)

                let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
                guard fetchResult.count > 0 else {
                    DispatchQueue.main.async {
                        completion([])
                    }
                    return
                }

                var assets: [PHAsset] = []
                for i in 0..<fetchResult.count {
                    let asset = fetchResult.object(at: i)
                    assets.append(asset)
                }

                assets = assets.sorted(by: { asset1, asset2 in
                    let asset1Diff = abs(asset1.creationDate?.timeIntervalSince(date) ?? 1000000)
                    let asset2Diff = abs(asset2.creationDate?.timeIntervalSince(date) ?? 1000000)
                    return asset1Diff < asset2Diff
                })

                var count = min(maxCount, assets.count)

                var images: [UIImage] = []
                for asset in assets[0..<count] {
                    PHImageManager.default().requestImage(for: asset,
                                                          targetSize: CGSize(width: asset.pixelWidth,
                                                                             height: asset.pixelHeight),
                                                          contentMode: .aspectFill,
                                                          options: requestOptions) { image, info in
                        if let image = image {
                            images.append(image)
                        } else {
                            count -= 1
                        }

                        if images.count == count {
                            DispatchQueue.main.async {
                                completion(images)
                            }
                        }
                    }
                }
            }
        }
    }
}
