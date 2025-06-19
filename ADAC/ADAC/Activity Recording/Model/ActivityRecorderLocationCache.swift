// Licensed under the Any Distance Source-Available License
//
//  ActivityRecorderLocationWriter.swift
//  ADAC
//
//  Created by Daniel Kuntz on 9/11/22.
//

import Foundation
import CoreLocation

class ActivityRecorderLocationCache {
    private var stream: OutputStream?

    func deleteFile(forActivityWith startDate: Date) throws {
        let filename = filename(for: startDate)
        let documentsDirectory = try FileManager.default.url(for: .documentDirectory,
                                                             in: .userDomainMask,
                                                             appropriateFor: nil,
                                                             create: true)
        let fileUrl = documentsDirectory.appendingPathComponent(filename)
        try FileManager.default.removeItemIfExists(at: fileUrl)
    }

    func writeLocations(_ locations: [CLLocation], forActivityWith startDate: Date) throws {
        guard !locations.isEmpty else {
            return
        }

        let filename = "\(startDate.timeIntervalSince1970)-activity-locations.txt"
        let documentsDirectory = try FileManager.default.url(for: .documentDirectory,
                                                             in: .userDomainMask,
                                                             appropriateFor: nil,
                                                             create: true)
        let fileUrl = documentsDirectory.appendingPathComponent(filename)
        if !FileManager.default.fileExists(atPath: fileUrl.path) {
            FileManager.default.createFile(atPath: fileUrl.path, contents: nil)
        }

        guard let fileData = FileManager.default.contents(atPath: fileUrl.path) else {
            return
        }

        let fileContents = String(data: fileData, encoding: .utf8)
        let currentNumberOfLocations = (fileContents?.components(separatedBy: .newlines).count ?? 1) - 1

        let numberOfLocationsToAppend = locations.count - currentNumberOfLocations
        guard numberOfLocationsToAppend > 0 else {
            return
        }

        if stream == nil {
            stream = OutputStream(toFileAtPath: fileUrl.path, append: true)
            stream?.open()
        }

        guard let newlineData = "\n".data(using: .utf8) else {
            return
        }

        for i in (locations.count - numberOfLocationsToAppend).clamped(to: 0...(locations.count - 1))...(locations.count - 1) {
            let wrappedLocation = LocationWrapper(from: locations[i])
            var encodedWrappedLocation = try JSONEncoder().encode(wrappedLocation)
            encodedWrappedLocation.append(newlineData)
            encodedWrappedLocation.withUnsafeBytes { rawBufferPointer in
                let bufferPointer = rawBufferPointer.bindMemory(to: UInt8.self)
                stream?.write(bufferPointer.baseAddress!, maxLength: encodedWrappedLocation.count)
            }
        }
    }

    func locations(forActivityWith startDate: Date) throws -> [CLLocation] {
        let filename = filename(for: startDate)
        let documentsDirectory = try FileManager.default.url(for: .documentDirectory,
                                                             in: .userDomainMask,
                                                             appropriateFor: nil,
                                                             create: true)
        let fileUrl = documentsDirectory.appendingPathComponent(filename)

        guard let fileData = FileManager.default.contents(atPath: fileUrl.path),
              let fileContents = String(data: fileData, encoding: .utf8) else {
            return []
        }

        let components = fileContents.components(separatedBy: .newlines)
        return components.compactMap { string in
            if let data = string.data(using: .utf8) {
                let wrappedLocation = try? JSONDecoder().decode(LocationWrapper.self, from: data)
                return CLLocation(wrapper: wrappedLocation)
            }

            return nil
        }
    }

    private func filename(for startDate: Date) -> String {
        return "\(startDate.timeIntervalSince1970)-activity-locations.txt"
    }
}
