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
            sendClear: { calls.append("clear") },
            disconnect: { calls.append("disconnect") })
        precondition(calls == ["clear", "disconnect"] && store.isRequired)

        // After relaunch there is no retained connection or coordinate.
        calls = []
        try await LocationRestoration.clear(hasConnection: false, store: store,
            reconnect: { calls.append("connect") },
            sendClear: { calls.append("clear") },
            disconnect: { calls.append("disconnect") })
        precondition(calls == ["connect", "clear", "disconnect"] && store.isRequired)

        // A stale connection retries exactly once through a fresh tunnel.
        calls = []
        var clearCount = 0
        try await LocationRestoration.clear(hasConnection: true, store: store,
            reconnect: { calls.append("connect") },
            sendClear: {
                calls.append("clear")
                clearCount += 1
                if clearCount == 1 { throw ProbeError.disconnected }
            }, disconnect: { calls.append("disconnect") })
        precondition(calls == ["clear", "connect", "clear", "disconnect"] && store.isRequired)

        calls = []
        do {
            try await LocationRestoration.clear(hasConnection: false, store: store,
                reconnect: { calls.append("connect"); throw ProbeError.disconnected },
                sendClear: { calls.append("clear") },
                disconnect: { calls.append("disconnect") })
            fatalError("A failed reconnect must propagate")
        } catch ProbeError.disconnected {}
        precondition(calls == ["connect", "disconnect"] && store.isRequired)

        calls = []
        do {
            try await LocationRestoration.clear(hasConnection: true, store: store,
                reconnect: { calls.append("connect") },
                sendClear: { calls.append("clear"); throw ProbeError.clearFailed },
                disconnect: { calls.append("disconnect") })
            fatalError("A failed clear must preserve recovery state")
        } catch ProbeError.clearFailed {}
        precondition(calls == ["clear", "connect", "clear", "disconnect"] && store.isRequired)
        precondition(LocationRecoveryStore(defaults: defaults).isRequired)

        calls = []
        do {
            try await LocationRestoration.clear(hasConnection: true, store: store,
                reconnect: { calls.append("connect") },
                sendClear: { calls.append("clear"); throw CancellationError() },
                disconnect: { calls.append("disconnect") })
            fatalError("Cancellation must not reconnect")
        } catch is CancellationError {}
        precondition(calls == ["clear", "disconnect"] && store.isRequired)

        // No success from an accepted clear, simulated fix, missing evidence or
        // a denied/timed-out observation. Only the explicit observation clears it.
        store.recordVerification(.stillSimulated)
        precondition(store.isRequired)
        store.recordVerification(.unavailable("Permission denied"))
        precondition(store.isRequired)
        store.recordVerification(.systemLocationObserved)
        precondition(!store.isRequired)
        precondition(!LocationRecoveryStore(defaults: defaults).isRequired)

        let began = Date(timeIntervalSince1970: 1_000)
        let now = began.addingTimeInterval(10)
        func accepts(_ timestamp: Date, accuracy: Double = 10, simulated: Bool? = false) -> Bool {
            RecoveryLocationSample.isSystemLocation(
                timestamp: timestamp, since: began, now: now,
                horizontalAccuracy: accuracy, isSimulated: simulated
            )
        }
        precondition(accepts(now))
        precondition(!accepts(began.addingTimeInterval(-1))) // pre-clear cache
        precondition(!accepts(now.addingTimeInterval(-6)))  // stale callback
        precondition(!accepts(now.addingTimeInterval(1)))   // future timestamp
        precondition(!accepts(now, accuracy: -1))
        precondition(!accepts(now, accuracy: .nan))
        precondition(!accepts(now, simulated: true))
        precondition(!accepts(now, simulated: nil))

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
        print("Restoration checks passed: relaunch, full disconnect on every clear outcome, pending until observed, cached/unknown/simulated fixes, cancellation, stale writes.")
    }
}
