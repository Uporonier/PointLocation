import Foundation

/// Keep recovery pending until a fresh, explicitly non-simulated fix is observed.
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

    func recordVerification(_ result: RecoveryLocationResult) {
        if result == .systemLocationObserved {
            defaults.set(false, forKey: Self.pendingKey)
            defaults.removeObject(forKey: "activeSimulationSessionID")
        } else {
            markRequired()
        }
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
        sendClear: () async throws -> Void,
        disconnect: () async -> Void
    ) async throws {
        store.markRequired()
        do {
            try await sendClearWithRetry(
                hasConnection: hasConnection, reconnect: reconnect, sendClear: sendClear
            )
        } catch {
            await disconnect()
            throw error
        }
        // Release the tunnel even when the clear returned success. A command
        // response alone is not evidence of a new physical location fix.
        await disconnect()
    }

    private static func sendClearWithRetry(
        hasConnection: Bool,
        reconnect: () async throws -> Void,
        sendClear: () async throws -> Void
    ) async throws {
        if hasConnection {
            do {
                try await sendClear()
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
    }
}
