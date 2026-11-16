import CoreLocation
import Foundation

/// A short foreground check after all simulation transports have disconnected.
/// It reports Core Location evidence; it cannot verify another app's cache.
@MainActor
final class RealLocationVerifier: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<RecoveryLocationResult, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var startedAt = Date.distantFuture
    private var sawSimulatedLocation = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        manager.allowsBackgroundLocationUpdates = false
    }

    func check() async -> RecoveryLocationResult {
        guard continuation == nil else { return .unavailable("已有定位检查正在进行。") }
        startedAt = Date()
        sawSimulatedLocation = false
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            timeoutTask = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(15)) } catch { return }
                guard let self else { return }
                finish(sawSimulatedLocation ? .stillSimulated :
                    .unavailable("15 秒内未取得可确认来源的新位置。可能是系统定位服务关闭、权限不足或暂时无定位信号。"))
            }
            startIfAuthorized()
        }
    }

    /// Permission dialogs also make the app inactive, so only cancel when it
    /// actually backgrounds. Never keep requesting location after this check.
    func cancel() {
        finish(.unavailable("定位检查已中断。回到定点后可点“重新检查系统位置”。"))
    }

    private func startIfAuthorized() {
        guard continuation != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            finish(.unavailable("定位服务或定点的定位权限未开启，无法检查是否恢复。请在设置中允许使用期间访问位置。"))
        @unknown default:
            finish(.unavailable("无法识别定位权限状态，请在系统地图中手动检查。"))
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in self?.startIfAuthorized() }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor [weak self] in
            guard let self, continuation != nil else { return }
            let now = Date()
            for location in locations {
                guard CLLocationCoordinate2DIsValid(location.coordinate),
                      RecoveryLocationSample.isFresh(
                        timestamp: location.timestamp, since: startedAt,
                        now: now, horizontalAccuracy: location.horizontalAccuracy
                      ) else { continue }
                if location.sourceInformation?.isSimulatedBySoftware == true {
                    sawSimulatedLocation = true
                }
                if RecoveryLocationSample.isSystemLocation(
                    timestamp: location.timestamp, since: startedAt, now: now,
                    horizontalAccuracy: location.horizontalAccuracy,
                    isSimulated: location.sourceInformation?.isSimulatedBySoftware
                ) {
                    finish(.systemLocationObserved)
                    return
                }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let nsError = error as NSError
        // A transient inability to locate may recover before the deadline.
        if nsError.domain == kCLErrorDomain && nsError.code == CLError.Code.locationUnknown.rawValue { return }
        let message = error.localizedDescription
        Task { @MainActor [weak self] in
            self?.finish(.unavailable("无法取得新的系统位置：\(message)"))
        }
    }

    private func finish(_ result: RecoveryLocationResult) {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        manager.stopUpdatingLocation()
        continuation.resume(returning: result)
    }
}
