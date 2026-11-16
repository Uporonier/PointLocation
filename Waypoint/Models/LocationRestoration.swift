import Foundation

/// This marker means a clear has not been acknowledged, not that GPS was verified.
struct LocationRecoveryStore {
    static let pendingKey = "locationRecoveryRequired"
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Preserve recovery information when upgrading from 0.1.3.
        if defaults.string(forKey: "activeSimulationSessionID") != nil {
            markRequired()
        }
    }

    var isRequired: Bool { defaults.bool(forKey: Self.pendingKey) }

    func markRequired() {
        defaults.set(true, forKey: Self.pendingKey)
    }

    func acknowledgeClear() {
        defaults.set(false, forKey: Self.pendingKey)
        defaults.removeObject(forKey: "activeSimulationSessionID")
    }
}

@MainActor
enum LocationRestoration {
    /// Prefer the retained session (which can work on cellular). Reconnect only
    /// when needed, and never substitute a new simulated coordinate for a clear.
    static func clear(
        hasConnection: Bool,
        store: LocationRecoveryStore,
        reconnect: () async throws -> Void,
        sendClear: () async throws -> Void
    ) async throws {
        store.markRequired()
        if hasConnection {
            do {
                try await sendClear()
                store.acknowledgeClear()
                return
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // A stale tunnel must not turn a failed clear into UI success.
            }
        }
        try Task.checkCancellation()
        try await reconnect()
        try Task.checkCancellation()
        try await sendClear()
        store.acknowledgeClear()
    }
}
