import Foundation

/// Invalidates already-scheduled writes across a restore/restart boundary.
final class LocationWriteGate: @unchecked Sendable {
    private let lock = NSLock()
    private var generation: UInt64 = 0
    private var enabled = true

    func suspend() {
        lock.lock()
        defer { lock.unlock() }
        enabled = false
        generation &+= 1
    }

    func resume() {
        lock.lock()
        defer { lock.unlock() }
        enabled = true
        generation &+= 1
    }

    func ticket() throws -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        guard enabled else { throw CancellationError() }
        return generation
    }

    func validate(_ ticket: UInt64) throws {
        lock.lock()
        defer { lock.unlock() }
        guard enabled, ticket == generation else { throw CancellationError() }
    }
}
