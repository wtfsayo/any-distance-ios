// Licensed under the Any Distance Source-Available License
//
//  WeatherFetcher.swift
//  ADAC
//
//  Created by Daniel Kuntz on 6/27/23.
//

import Foundation
import CoreLocation
import WeatherKit

class WeatherFetcher: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published var userLocation: CLLocation?
    @Published var weather: Weather?

    let locationManager = CLLocationManager()

    static let shared = WeatherFetcher()

    init(accuracy: CLLocationAccuracy = kCLLocationAccuracyHundredMeters) {
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = accuracy
        self.requestNewWeather()
    }

    func requestNewWeather() {
        self.locationManager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        locationManager.stopUpdatingLocation()

        DispatchQueue.main.async {
            self.userLocation = location
            Task(priority: .userInitiated) {
                self.weather = try? await WeatherService.shared.weather(for: self.userLocation!)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error.localizedDescription)
        self.requestNewWeather()
    }
}
