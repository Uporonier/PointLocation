import Foundation

enum ProbeError: Error { case disconnected, clearFailed }

@main
struct RestorationChecks {
    @MainActor
    static func main() async throws {
        let suite = "Pinpoint.RestorationChecks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LocationRecoveryStore(defaults: defaults)

        // Reopening after a write must retain the marker; clearing the old
        // notification marker alone must not claim recovery.
        store.markRequired()
        precondition(LocationRecoveryStore(defaults: defaults).isRequired)
        defaults.set(UUID().uuidString, forKey: "activeSimulationSessionID")
        defaults.removeObject(forKey: LocationRecoveryStore.pendingKey)
        precondition(LocationRecoveryStore(defaults: defaults).isRequired)
        defaults.removeObject(forKey: "activeSimulationSessionID")
        precondition(store.isRequired)

        var calls: [String] = []
        try await LocationRestoration.clear(hasConnection: true, store: store,
            reconnect: { calls.append("connect") },
            sendClear: { calls.append("clear") })
        precondition(calls == ["clear"] && !store.isRequired)

        // After relaunch there is no retained connection or coordinate.
        calls = []
        try await LocationRestoration.clear(hasConnection: false, store: store,
            reconnect: { calls.append("connect") },
            sendClear: { calls.append("clear") })
        precondition(calls == ["connect", "clear"] && !store.isRequired)

        // A stale connection retries exactly once through a fresh tunnel.
        calls = []
        var clearCount = 0
        try await LocationRestoration.clear(hasConnection: true, store: store,
            reconnect: { calls.append("connect") },
            sendClear: {
                calls.append("clear")
                clearCount += 1
                if clearCount == 1 { throw ProbeError.disconnected }
            })
        precondition(calls == ["clear", "connect", "clear"] && !store.isRequired)

        calls = []
        do {
            try await LocationRestoration.clear(hasConnection: false, store: store,
                reconnect: { calls.append("connect"); throw ProbeError.disconnected },
                sendClear: { calls.append("clear") })
            fatalError("A failed reconnect must propagate")
        } catch ProbeError.disconnected {}
        precondition(calls == ["connect"] && store.isRequired)

        calls = []
        do {
            try await LocationRestoration.clear(hasConnection: true, store: store,
                reconnect: { calls.append("connect") },
                sendClear: { calls.append("clear"); throw ProbeError.clearFailed })
            fatalError("A failed clear must preserve recovery state")
        } catch ProbeError.clearFailed {}
        precondition(calls == ["clear", "connect", "clear"] && store.isRequired)
        precondition(LocationRecoveryStore(defaults: defaults).isRequired)

        calls = []
        do {
            try await LocationRestoration.clear(hasConnection: true, store: store,
                reconnect: { calls.append("connect") },
                sendClear: { calls.append("clear"); throw CancellationError() })
            fatalError("Cancellation must not reconnect")
        } catch is CancellationError {}
        precondition(calls == ["clear"] && store.isRequired)

        let gate = LocationWriteGate()
        let queuedBeforeRestore = try gate.ticket()
        gate.suspend()
        do {
            try gate.validate(queuedBeforeRestore)
            fatalError("An old queued write must be rejected during recovery")
        } catch is CancellationError {}
        do {
            _ = try gate.ticket()
            fatalError("Recovery must block new writes")
        } catch is CancellationError {}
        gate.resume()
        do {
            try gate.validate(queuedBeforeRestore)
            fatalError("An old write must stay invalid after a new simulation starts")
        } catch is CancellationError {}
        try gate.validate(gate.ticket())
        print("Restoration checks passed: relaunch, legacy marker, retained/fresh/stale tunnel, failures, cancellation, stale writes.")
    }
}
