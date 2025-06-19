// Licensed under the Any Distance Source-Available License
//
//  URLSession+AsyncAwait.swift
//  ADAC
//
//  Created by Jarod Luebbert on 4/21/22.
//

import Foundation

@available(iOS, deprecated: 15.0, message: "Use the built-in API instead")
extension URLSession {
    
    func data(from url: URL) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = self.dataTask(with: url) { data, response, error in
                guard let data = data, let response = response else {
                    let error = error ?? URLError(.badServerResponse)
                    return continuation.resume(throwing: error)
                }

                continuation.resume(returning: (data, response))
            }

            task.resume()
        }
    }
    
    func download(from url: URL) async throws -> (URL, URLResponse) {
        let (data, response) = try await data(from: url)
        let localURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).tmp")
        try data.write(to: localURL)
        return (localURL, response)
    }
    
}
