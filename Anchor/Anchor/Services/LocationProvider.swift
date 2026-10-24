import Foundation
import CoreLocation

/// One-shot location lookup used only during an emergency, so the text to emergency
/// contacts can say *where* the person is. Never tracked, stored, or sent anywhere else.
class LocationProvider: NSObject, CLLocationManagerDelegate {
    static let shared = LocationProvider()

    private let manager = CLLocationManager()
    private(set) var lastLocation: CLLocation?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    /// Asked when the user turns on crisis monitoring, so the permission prompt never
    /// appears in the middle of an emergency.
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
