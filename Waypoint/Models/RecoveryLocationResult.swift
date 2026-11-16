import Foundation

enum RecoveryLocationResult: Equatable {
    case systemLocationObserved
    case stillSimulated
    case unavailable(String)

    var detail: String {
        switch self {
        case .systemLocationObserved:
            return "系统已返回新的、未标记为软件模拟的位置。仍请在地图和微信中确认实际位置。"
        case .stillSimulated:
            return "检查期间仍收到标记为软件模拟的位置，尚未确认恢复。"
        case .unavailable(let reason):
            return reason
        }
    }
}

enum RecoveryLocationSample {
    /// Ignore cached, future-dated and invalid fixes. A missing source flag is
    /// unknown, not evidence that a device has returned to its physical location.
    static func isFresh(
        timestamp: Date,
        since startedAt: Date,
        now: Date,
        horizontalAccuracy: Double
    ) -> Bool {
        horizontalAccuracy.isFinite && horizontalAccuracy >= 0 &&
            timestamp >= startedAt && timestamp <= now &&
            now.timeIntervalSince(timestamp) <= 5
    }

    static func isSystemLocation(
        timestamp: Date,
        since startedAt: Date,
        now: Date,
        horizontalAccuracy: Double,
        isSimulated: Bool?
    ) -> Bool {
        isSimulated == false && isFresh(
            timestamp: timestamp, since: startedAt, now: now,
            horizontalAccuracy: horizontalAccuracy
        )
    }
}
