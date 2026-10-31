import CoreLocation
import MapKit

/// The Mac's approximate location, through Location Services, for the weather. Asks for
/// permission only when `requestAccess()` is called. Coordinates are rounded to about
/// 10 km before anything is sent.
@MainActor
final class LocationProvider: NSObject, CLLocationManagerDelegate {
  enum Access: Equatable {
    case notAsked, allowed, denied
  }

  private let manager = CLLocationManager()
  private var accessWaiters: [CheckedContinuation<Void, Never>] = []
  private var locationWaiters: [CheckedContinuation<CLLocation?, Never>] = []
  /// Called when the user answers the prompt or changes access in System Settings.
  var onAccessChange: (() -> Void)?

  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyKilometer
  }

  var access: Access {
    switch manager.authorizationStatus {
    case .authorizedAlways: .allowed
    case .denied, .restricted: .denied
    default: .notAsked
    }
  }

  /// Shows the system prompt if the user hasn't answered it yet, and waits for the answer
  /// (at most two minutes).
  func requestAccess() async -> Access {
    guard manager.authorizationStatus == .notDetermined else { return access }
    await withCheckedContinuation { continuation in
      accessWaiters.append(continuation)
      manager.requestWhenInUseAuthorization()
      Task { [weak self] in
        try? await Task.sleep(for: .seconds(120))
        self?.resumeAccessWaiters()
      }
    }
    return access
  }

  /// One location fix, rounded; `nil` without access or when none comes within 20 s.
  func approximateLocation() async -> CLLocation? {
    guard access == .allowed else { return nil }
    let location = await withCheckedContinuation { continuation in
      locationWaiters.append(continuation)
      guard locationWaiters.count == 1 else { return }
      manager.requestLocation()
      Task { [weak self] in
        try? await Task.sleep(for: .seconds(20))
        self?.finishLocation(nil)
      }
    }
    return location.map(Self.rounded)
  }

  /// The city at a location, from Apple Maps; `nil` when it can't be found.
  static func cityName(at location: CLLocation) async -> String? {
    guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
    request.preferredLocale = .current
    do {
      return try await request.mapItems.first?.addressRepresentations?.cityName
    } catch {
      Log.widgets.error("Finding the city failed: \(error.localizedDescription, privacy: .public)")
      return nil
    }
  }

  /// One decimal place: about 11 km north to south, less east to west.
  nonisolated static func rounded(_ location: CLLocation) -> CLLocation {
    CLLocation(
      latitude: (location.coordinate.latitude * 10).rounded() / 10,
      longitude: (location.coordinate.longitude * 10).rounded() / 10)
  }

  // MARK: - CLLocationManagerDelegate (called on the main thread, where it was created)

  nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    MainActor.assumeIsolated {
      guard self.manager.authorizationStatus != .notDetermined else { return }
      resumeAccessWaiters()
      onAccessChange?()
    }
  }

  nonisolated func locationManager(
    _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
  ) {
    let location = locations.last
    MainActor.assumeIsolated { finishLocation(location) }
  }

  nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    let message = error.localizedDescription
    MainActor.assumeIsolated {
      Log.widgets.error("Location request failed: \(message, privacy: .public)")
      finishLocation(nil)
    }
  }

  private func resumeAccessWaiters() {
    let waiters = accessWaiters
    accessWaiters = []
    for waiter in waiters {
      waiter.resume()
    }
  }

  private func finishLocation(_ location: CLLocation?) {
    let waiters = locationWaiters
    locationWaiters = []
    for waiter in waiters {
      waiter.resume(returning: location)
    }
  }
}
