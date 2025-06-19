// Licensed under the Any Distance Source-Available License
//
//  ActivityDesignCache.swift
//  ADAC
//
//  Created by Daniel Kuntz on 1/18/21.
//

import UIKit

final class LegacyActivityDesignCache {
    static func legacyDesign(for activityId: String) -> LegacyActivityDesign? {
        do {
            let documentsDirectory = try FileManager.default.url(for: .documentDirectory,
                                                                 in: .userDomainMask,
                                                                 appropriateFor: nil,
                                                                 create: true)
            let cacheFileName = "\(activityId)\(LegacyActivityDesign.cacheFileSuffix)"
            let url = documentsDirectory.appendingPathComponent(cacheFileName)

            let design = try JSONDecoder().decode(LegacyActivityDesign.self,
                                                  from: Data(contentsOf: url))
            return design
        } catch {
            print(error)
        }

        return nil
    }

    static func legacyDesign(for stepCount: DailyStepCount) -> LegacyActivityDesign? {
        let id = "\(stepCount.startDate.timeIntervalSince1970))"
        return legacyDesign(for: id)
    }

    static func photo(with fileName: String) -> UIImage? {
        do {
            let documentsDirectory = try FileManager.default.url(for: .documentDirectory,
                                                                 in: .userDomainMask,
                                                                 appropriateFor: nil,
                                                                 create: true)
            let path = documentsDirectory.appendingPathComponent(fileName).path
            return UIImage(contentsOfFile: path)
        } catch {
            print(error)
        }

        return nil
    }

    static func deleteUnusedVideos() {
        do {
            let documentsDirectory = try FileManager.default.url(for: .documentDirectory,
                                                                 in: .userDomainMask,
                                                                 appropriateFor: nil,
                                                                 create: true)
            let documents = try FileManager.default.contentsOfDirectory(atPath: documentsDirectory.path)

            let designFilenames = documents.filter { $0.contains("activity_design") }
            var designs: [ActivityDesign] = []
            for file in designFilenames {
                let url = documentsDirectory.appendingPathComponent(file)
                
                guard FileManager.default.fileExists(atPath: url.absoluteString) else { continue }
                
                do {
                    let design = try JSONDecoder().decode(ActivityDesign.self,
                                                          from: Data(contentsOf: url))
                    designs.append(design)
                } catch {
                    print("Error deleting unused videos: \(error.localizedDescription)")
                }
            }

            var designVideoFilenames: Set<String> = Set<String>()
            for design in designs {
                if let url = design.legacyVideoURL {
                    designVideoFilenames.insert(url.lastPathComponent)
                }
            }

            let allVideoUrls = documents.filter { $0.contains(".MOV") || $0.contains(".mov") }
                .map { documentsDirectory.appendingPathComponent($0) }
            for videoUrl in allVideoUrls {
                if !designVideoFilenames.contains(videoUrl.lastPathComponent) {
                    try? FileManager.default.removeItem(at: videoUrl)
                    print("deleting video \(videoUrl.path)")
                }
            }
        } catch {
            print(error)
        }

    }
}
