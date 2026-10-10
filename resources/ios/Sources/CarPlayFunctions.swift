import Foundation
import CoreFoundation

enum CarPlayFunctions {
    static func call(_ command: String, _ p: [String: Any]) -> [String: Any] {
        do {
            switch command {
            case "Capabilities":
                return ["platform": "carplay", "category": NativeCarPlay.category, "templates": NativeCarPlay.supportedTypes(), "replace": ["list", "information", "message", "search", "poi"].filter { NativeCarPlay.supportedTypes().contains($0) }, "modalAlerts": true, "navigationHandoff": true, "embeddedNavigation": false, "audioPlayback": false, "durableEvents": true, "maxDepth": NativeCarPlay.category == "food" ? 2 : 5, "icons": CarContract.icons]
            case "Status": return CarEventStore.shared.status()
            case "Events":
                var limit = 100
                if let value = p["limit"] {
                    guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue.isFinite,
                          number.doubleValue.rounded() == number.doubleValue, (1.0...256.0).contains(number.doubleValue) else { throw CarFailure.invalid("Event limit must be an integer 1..256.") }
                    limit = number.intValue
                }
                return CarEventStore.shared.events(limit: limit)
            case "Acknowledge":
                guard let ids = p["ids"] as? [String], ids.count <= 256, ids.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 128 }) else { throw CarFailure.invalid("Expected up to 256 event IDs.") }
                return CarEventStore.shared.acknowledge(ids)
            case "BindEvents": return ["bound": true]
            case "SetRoot", "Push", "Replace", "Present":
                guard let template = p["template"] as? [String: Any] else { throw CarFailure.invalid("Expected template object.") }
                try CarContract.validate(template); try NativeCarPlay.validateSupport(template, command: command)
            case "Navigate":
                _ = try CarContract.coordinate(p)
                if p["name"] != nil { _ = try CarContract.string(p, "name", empty: true) }
            case "Pop", "PopToRoot", "Dismiss", "Clear": break
            default: throw CarFailure.invalid("Unknown command.")
            }
            let id = UUID().uuidString
            // A synchronous PHP bridge must never block the UI thread awaiting a host.
            DispatchQueue.main.async { NativeCarPlay.shared.enqueue(command, p, id: id) }
            return ["accepted": true, "operationId": id]
        } catch let error as CarFailure {
            return BridgeResponse.error(code: error.code, message: error.message)
        } catch { return BridgeResponse.error(code: "INVALID_PARAMETERS", message: error.localizedDescription) }
    }
}

extension CarPlayFunctions {
    final class Capabilities: BridgeFunction {
        func execute(parameters: [String: Any]) throws -> [String: Any] { CarPlayFunctions.call("Capabilities", parameters) }
    }
}

extension CarPlayFunctions {
    final class Status: BridgeFunction {
        func execute(parameters: [String: Any]) throws -> [String: Any] { CarPlayFunctions.call("Status", parameters) }
    }
}

extension CarPlayFunctions {
    final class SetRoot: BridgeFunction {
        func execute(parameters: [String: Any]) throws -> [String: Any] { CarPlayFunctions.call("SetRoot", parameters) }
    }
}

extension CarPlayFunctions {
    final class Push: BridgeFunction {
        func execute(parameters: [String: Any]) throws -> [String: Any] { CarPlayFunctions.call("Push", parameters) }
    }
}

extension CarPlayFunctions {
    final class Replace: BridgeFunction {
        func execute(parameters: [String: Any]) throws -> [String: Any] { CarPlayFunctions.call("Replace", parameters) }
    }
}

extension CarPlayFunctions {
    final class Pop: BridgeFunction {
        func execute(parameters: [String: Any]) throws -> [String: Any] { CarPlayFunctions.call("Pop", parameters) }
    }
}

extension CarPlayFunctions {
    final class PopToRoot: BridgeFunction {
        func execute(parameters: [String: Any]) throws -> [String: Any] { CarPlayFunctions.call("PopToRoot", parameters) }
    }
}

extension CarPlayFunctions {
    final class Present: BridgeFunction {
        func execute(parameters: [String: Any]) throws -> [String: Any] { CarPlayFunctions.call("Present", parameters) }
    }
}

extension CarPlayFunctions {
    final class Dismiss: BridgeFunction {
        func execute(parameters: [String: Any]) throws -> [String: Any] { CarPlayFunctions.call("Dismiss", parameters) }
    }
}

extension CarPlayFunctions {
    final class Clear: BridgeFunction {
        func execute(parameters: [String: Any]) throws -> [String: Any] { CarPlayFunctions.call("Clear", parameters) }
    }
}

extension CarPlayFunctions {
    final class Navigate: BridgeFunction {
        func execute(parameters: [String: Any]) throws -> [String: Any] { CarPlayFunctions.call("Navigate", parameters) }
    }
}

extension CarPlayFunctions {
    final class Events: BridgeFunction {
        func execute(parameters: [String: Any]) throws -> [String: Any] { CarPlayFunctions.call("Events", parameters) }
    }
}

extension CarPlayFunctions {
    final class Acknowledge: BridgeFunction {
        func execute(parameters: [String: Any]) throws -> [String: Any] { CarPlayFunctions.call("Acknowledge", parameters) }
    }
}

extension CarPlayFunctions {
    final class BindEvents: BridgeFunction {
        func execute(parameters: [String: Any]) throws -> [String: Any] { CarPlayFunctions.call("BindEvents", parameters) }
    }
}
