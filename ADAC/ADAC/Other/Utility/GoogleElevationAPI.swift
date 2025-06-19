// Licensed under the Any Distance Source-Available License
//
//  GoogleElevationAPI.swift
//  ADAC
//
//  Created by Daniel Kuntz on 11/19/21.
//

import CoreLocation

fileprivate struct GoogleElevation: Codable {
    let elevation: Float?
}

fileprivate struct GoogleElevationResponse: Codable {
    let results: [GoogleElevation]
}

class GoogleElevationAPI {
    static let key = ""

    static func fetchElevationsForRoute(withCoordinates coords: [CLLocation], completion: @escaping ([Float]) -> Void) {
        guard !coords.isEmpty else {
            completion([])
            return
        }

        let reducedCoords = reduceCoordsToMaxRequestSize(coords)

        var coordString: String = reducedCoords.reduce("", { $0 + "\($1.coordinate.latitude.rounded(toPlaces: 4))" + "," + "\($1.coordinate.longitude.rounded(toPlaces: 4))" + "|" })
        
        if !coordString.isEmpty {
            coordString.removeLast()
        }

        let queryItems = [URLQueryItem(name: "locations", value: coordString),
                          URLQueryItem(name: "key", value: key)]
        var urlComps = URLComponents(string: "https://maps.googleapis.com/maps/api/elevation/json")
        urlComps?.queryItems = queryItems
        guard let url = urlComps?.url else {
            completion([])
            return
        }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let json = try JSONDecoder().decode(GoogleElevationResponse.self, from: data)
                let points: [Float] = json.results.map { $0.elevation ?? 0.0 }
                DispatchQueue.main.async {
                    completion(points)
                }
            } catch {
                print("Error - no response data.")
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }

    static private func reduceCoordsToMaxRequestSize(_ coords: [CLLocation]) -> [CLLocation] {
        let maxRequestSize = 512
        if coords.count <= maxRequestSize {
            return coords
        }

        return stride(from: 0, to: Float(coords.count-1), by: Float(coords.count) / Float(maxRequestSize)).map { coords[Int($0)] }
    }
}
