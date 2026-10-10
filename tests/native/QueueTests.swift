import Foundation

@main struct QueueTests {
    static func main() throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CarEventStore(directory: directory)
        store.setRoot(["id": "offline-root", "type": "list"])
        for i in 0..<300 { store.emit("itemSelected", ["index": i]) }
        let result = store.events(limit: 256)
        let events = result["events"] as! [[String: Any]]
        precondition(events.count == 256 && result["dropped"] as! Int == 44)
        precondition((events[0]["payload"] as! [String: Any])["index"] as! Int == 44)
        precondition((store.events(limit: 256)["events"] as! [[String: Any]]).count == 256)
        let restored = CarEventStore(directory: directory)
        precondition((restored.events(limit: 256)["events"] as! [[String: Any]]).count == 256)
        precondition(restored.root()?["id"] as? String == "offline-root")
        let ids = events.prefix(100).map { $0["id"] as! String }
        precondition(restored.acknowledge(ids)["acknowledged"] as! Int == 100)
        precondition(restored.acknowledge(ids)["acknowledged"] as! Int == 0)
        let afterAck = CarEventStore(directory: directory)
        precondition((afterAck.events(limit: 256)["events"] as! [[String: Any]]).count == 156)
        afterAck.setRoot(nil)
        precondition(CarEventStore(directory: directory).root() == nil)
        precondition(afterAck.status()["persistenceError"] is NSNull)
        print("PASS: Swift queue overflow, read replay, restart, acknowledgement and cache clearing")
    }
}
