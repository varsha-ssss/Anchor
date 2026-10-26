import Foundation
import CoreLocation

// only used during an emergency for the text to contacts. not stored or tracked
class LocationProvider: NSObject, CLLocationManagerDelegate {
    static let shared = LocationProvider()

    private let manager = CLLocationManager()
    private(set) var lastLocation: CLLocation?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    // called when monitoring is turned on so the prompt doesn't pop up mid-emergency
    func requestPermission() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    func requestCurrentLocation() {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    var mapsLink: String? {
        guard let coordinate = lastLocation?.coordinate else { return nil }
        return String(format: "https://maps.apple.com/?ll=%.5f,%.5f&q=Here", coordinate.latitude, coordinate.longitude)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[Location] \(error.localizedDescription)")
    }
}
