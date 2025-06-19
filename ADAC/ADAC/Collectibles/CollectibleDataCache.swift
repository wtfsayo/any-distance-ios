// Licensed under the Any Distance Source-Available License
//
//  CollectibleDataCache.swift
//  ADAC
//
//  Created by Daniel Kuntz on 5/18/22.
//

import Foundation
import Alamofire

class CollectibleDataCache {

    private static let forceReload: Bool = false
    private static let folderName = "collectible-cache"

    static private var documentsDirectory: URL? {
        return try? FileManager.default.url(for: .documentDirectory,
                                            in: .userDomainMask,
                                            appropriateFor: nil,
                                            create: true)
    }

    static func hasLoadedItem(atUrl url: URL) -> Bool {
        guard let baseUrl = documentsDirectory?.appendingPathComponent(folderName) else {
            return false
        }

        let localUrl = baseUrl.appendingPathComponent(url.lastPathComponent)
        return FileManager.default.fileExists(atPath: localUrl.path) && !forceReload
    }

    static func loadItem(atUrl url: URL) async -> URL? {
        guard let baseUrl = documentsDirectory?.appendingPathComponent(folderName) else {
            return nil
        }

        let localUrl = baseUrl.appendingPathComponent(url.lastPathComponent)
        if FileManager.default.fileExists(atPath: localUrl.path) && !forceReload {
            return localUrl
        }

        if !FileManager.default.fileExists(atPath: baseUrl.path) {
            try? FileManager.default.createDirectory(at: baseUrl, withIntermediateDirectories: false)
        }

        return await withCheckedContinuation { continuation in
            AF.request(url, method: .get).response { response in
                guard let data = response.data else {
                    continuation.resume(returning: nil)
                    return
                }

                try? data.write(to: localUrl)
                continuation.resume(returning: localUrl)
            }
        }
    }

    static func clearUnusedFiles(withExistingCollectibles collectibles: [RemoteCollectible]) {
        guard let baseUrl = documentsDirectory?.appendingPathComponent(folderName),
              let contents = try? FileManager.default.contentsOfDirectory(atPath: baseUrl.path) else {
            return
        }

        let filenames = collectibles.flatMap { collectible in
            return [collectible.usdzUrl, collectible.videoUrl, collectible.previewVideoUrl].compactMap { $0?.lastPathComponent }
        }

        for file in contents {
            if !filenames.contains(file) {
                do {
                    let url = baseUrl.appendingPathComponent(file)
                    try FileManager.default.removeItem(at: url)
                    print("Removed \(file)")
                } catch {
                    print(error)
                }
            }
        }
    }
}
