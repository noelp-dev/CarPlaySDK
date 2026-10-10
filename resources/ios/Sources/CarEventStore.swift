import Foundation

/** Bounded, atomic on-disk queue. All UI state is owned by CarPlay's main thread. */
final class CarEventStore {
    static let shared = CarEventStore()
    private let lock = NSRecursiveLock()
    private let file: URL
    private var state: [String: Any] = ["events": [[String: Any]](), "dropped": 0]
    private var connection: [String: Any] = ["connected": false, "platform": "carplay", "depth": 0]
    private var persistenceError: String?
    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("NativeCarPlay", isDirectory: true)
        file = base.appendingPathComponent("state.json")
        do {
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            var excluded = base; var values = URLResourceValues(); values.isExcludedFromBackup = true; try excluded.setResourceValues(values)
            if let data = try? Data(contentsOf: file), data.count <= 1048576,
               let restored = try JSONSerialization.jsonObject(with: data) as? [String: Any] { state = restored }
        } catch { persistenceError = error.localizedDescription }
    }
    private func save() {
        do {
            try JSONSerialization.data(withJSONObject: state).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            persistenceError = nil
        } catch { persistenceError = error.localizedDescription }
    }
    func emit(_ type: String, _ payload: [String: Any] = [:]) {
        lock.lock()
        let event: [String: Any] = ["id": UUID().uuidString, "type": type, "platform": "carplay", "timestamp": Date().timeIntervalSince1970, "payload": payload]
        var events = state["events"] as? [[String: Any]] ?? []
        events.append(event)
        if events.count > 256 { events.removeFirst(); state["dropped"] = (state["dropped"] as? Int ?? 0) + 1 }
        state["events"] = events; save(); lock.unlock()
        DispatchQueue.main.async { LaravelBridge.shared.send?("Fatsoenlijk\\CarPlay\\Events\\CarEvent", event) }
    }
    func events(limit: Int) -> [String: Any] {
        lock.lock(); defer { lock.unlock() }
        return ["events": Array((state["events"] as? [[String: Any]] ?? []).prefix(limit)), "dropped": state["dropped"] as? Int ?? 0]
    }
    func acknowledge(_ ids: [String]) -> [String: Any] {
        lock.lock(); defer { lock.unlock() }
        let old = state["events"] as? [[String: Any]] ?? []; let wanted = Set(ids)
        let remaining = old.filter { !wanted.contains($0["id"] as? String ?? "") }
        state["events"] = remaining; save()
        return ["acknowledged": old.count - remaining.count, "persisted": persistenceError == nil]
    }
    func root() -> [String: Any]? { lock.lock(); defer { lock.unlock() }; return state["root"] as? [String: Any] }
    func setRoot(_ root: [String: Any]?) { lock.lock(); defer { lock.unlock() }; state["root"] = root; save() }
    func updateStatus(_ value: [String: Any]) { lock.lock(); defer { lock.unlock() }; connection = value }
    func status() -> [String: Any] {
        lock.lock(); defer { lock.unlock() }
        var result = connection
        result["cachedRoot"] = state["root"] != nil
        result["persistenceError"] = persistenceError ?? NSNull() as Any
        return result
    }
}
