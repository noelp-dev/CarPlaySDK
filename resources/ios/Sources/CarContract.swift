import Foundation
import CoreFoundation

enum CarFailure: Error {
    case invalid(String)
    case unsupported(String)
    case disconnected
    case timeout
    var code: String {
        switch self { case .invalid: return "INVALID_PARAMETERS"; case .unsupported: return "UNSUPPORTED"; case .disconnected: return "NOT_CONNECTED"; case .timeout: return "HOST_TIMEOUT" }
    }
    var message: String {
        switch self { case .invalid(let s), .unsupported(let s): return s; case .disconnected: return "Connect a CarPlay scene first."; case .timeout: return "Host completion timed out; inspect status before retrying." }
    }
}

enum CarContract {
    static let icons = ["list", "grid", "search", "map", "pin", "parking", "charging", "food", "music", "play", "pause", "info", "star", "home"]
    static let types = ["list", "grid", "information", "message", "search", "tabs", "poi", "alert", "nowPlaying"]
    static func string(_ object: [String: Any], _ key: String, empty: Bool = false) throws -> String {
        guard let s = object[key] as? String, s.utf8.count <= 512, empty || !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CarFailure.invalid("\(key) requires text up to 512 UTF-8 bytes.")
        }
        return s
    }
    static func id(_ value: Any?) throws -> String {
        guard let s = value as? String, s.range(of: "^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}\\z", options: .regularExpression) != nil else {
            throw CarFailure.invalid("Invalid identifier.")
        }
        return s
    }
    static func array(_ object: [String: Any], _ key: String, min: Int, max: Int) throws -> [[String: Any]] {
        guard let items = object[key] as? [[String: Any]], (min...max).contains(items.count) else {
            throw CarFailure.invalid("\(key) requires \(min)..\(max) objects.")
        }
        return items
    }
    static func keys(_ object: [String: Any], _ allowed: [String]) throws {
        guard Set(object.keys).isSubset(of: Set(allowed)) else { throw CarFailure.invalid("Unknown field.") }
    }
    static func coordinate(_ object: [String: Any]) throws -> (Double, Double) {
        guard let lat = object["latitude"] as? NSNumber, let lon = object["longitude"] as? NSNumber,
              CFGetTypeID(lat) != CFBooleanGetTypeID(), CFGetTypeID(lon) != CFBooleanGetTypeID(),
              lat.doubleValue.isFinite, lon.doubleValue.isFinite,
              abs(lat.doubleValue) <= 90, abs(lon.doubleValue) <= 180 else { throw CarFailure.invalid("Invalid coordinates.") }
        return (lat.doubleValue, lon.doubleValue)
    }
    static func validate(_ t: [String: Any]) throws {
        guard JSONSerialization.isValidJSONObject(t), try JSONSerialization.data(withJSONObject: t, options: [.withoutEscapingSlashes]).count <= 262144 else { throw CarFailure.invalid("Template exceeds 256 KiB.") }
        var ids = Set<String>()
        try node(t, ids: &ids, tab: false)
    }
    private static func unique(_ value: Any?, _ ids: inout Set<String>) throws {
        let s = try id(value)
        guard ids.insert(s).inserted else { throw CarFailure.invalid("Duplicate ID.") }
    }
    private static func boolean(_ value: Any?) throws {
        if let value = value {
            guard let n = value as? NSNumber, CFGetTypeID(n) == CFBooleanGetTypeID() else { throw CarFailure.invalid("Expected boolean.") }
        }
    }
    private static func item(_ r: [String: Any], ids: inout Set<String>, grid: Bool = false) throws {
        try keys(r, ["id", "title", "detail", "icon", "action", "enabled"])
        try unique(r["id"], &ids); _ = try string(r, "title")
        if r["detail"] != nil { _ = try string(r, "detail", empty: true) }
        if r["action"] != nil { _ = try id(r["action"]) }
        try boolean(r["enabled"])
        if grid || r["icon"] != nil {
            guard let icon = r["icon"] as? String, icons.contains(icon) else { throw CarFailure.invalid("Unknown icon.") }
        }
    }
    static func actions(_ object: [String: Any], required: Bool = false) throws -> [[String: Any]] {
        if object["actions"] == nil && !required { return [] }
        let actions = try array(object, "actions", min: required ? 1 : 0, max: 2)
        var ids = Set<String>()
        for a in actions {
            try keys(a, ["id", "title", "style"]); try unique(a["id"], &ids); _ = try string(a, "title")
            if let style = a["style"] as? String { guard ["normal", "cancel", "destructive"].contains(style) else { throw CarFailure.invalid("Unknown action style.") } }
            else if a["style"] != nil { throw CarFailure.invalid("Invalid action style.") }
        }
        return actions
    }
    private static func node(_ t: [String: Any], ids: inout Set<String>, tab: Bool) throws {
        try unique(t["id"], &ids); _ = try string(t, "title")
        guard let type = t["type"] as? String, types.contains(type) else { throw CarFailure.invalid("Unknown template type.") }
        if tab && !["list", "grid"].contains(type) { throw CarFailure.invalid("Invalid tab child.") }
        if let icon = t["icon"] as? String { guard icons.contains(icon) else { throw CarFailure.invalid("Unknown icon.") } }
        else if t["icon"] != nil { throw CarFailure.invalid("Invalid icon.") }
        let fields: [String]
        switch type {
        case "list": fields = ["sections", "loading"]
        case "grid": fields = ["items"]
        case "information": fields = ["items", "actions"]
        case "message": fields = ["message", "actions"]
        case "search": fields = ["items", "hint"]
        case "tabs": fields = ["tabs"]
        case "poi": fields = ["points"]
        case "alert": fields = ["actions"]
        default: fields = []
        }
        try keys(t, ["id", "type", "title", "icon"] + fields)
        _ = try actions(t, required: type == "alert")
        var rowIDs = Set<String>()
        switch type {
        case "list":
            try boolean(t["loading"])
            var total = 0
            for section in try array(t, "sections", min: 1, max: 10) {
                try keys(section, ["title", "items"])
                if section["title"] != nil { _ = try string(section, "title", empty: true) }
                let rows = try array(section, "items", min: 0, max: 100); total += rows.count
                for r in rows { try item(r, ids: &rowIDs) }
            }
            guard total <= 100 else { throw CarFailure.invalid("At most 100 list items.") }
        case "grid", "search", "information":
            for r in try array(t, "items", min: type == "search" ? 0 : 1, max: type == "grid" ? 8 : (type == "information" ? 4 : 100)) {
                if type == "information" {
                    try keys(r, ["title", "detail"]); _ = try string(r, "title")
                    if r["detail"] != nil { _ = try string(r, "detail", empty: true) }
                } else { try item(r, ids: &rowIDs, grid: type == "grid") }
            }
            if t["hint"] != nil { _ = try string(t, "hint") }
        case "message": _ = try string(t, "message")
        case "tabs":
            for child in try array(t, "tabs", min: 2, max: 4) { try node(child, ids: &ids, tab: true) }
        case "poi":
            for p in try array(t, "points", min: 1, max: 6) {
                try keys(p, ["id", "title", "subtitle", "summary", "latitude", "longitude", "actions"])
                try unique(p["id"], &rowIDs); _ = try string(p, "title"); _ = try coordinate(p); _ = try actions(p)
                for k in ["subtitle", "summary"] { if p[k] != nil { _ = try string(p, k, empty: true) } }
            }
        default: break
        }
    }
}
