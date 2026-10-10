import CarPlay
import MapKit
import UIKit

/** Only touched on the main thread, including all asynchronous host completions. */
final class NativeCarPlay: NSObject, CPInterfaceControllerDelegate {
    static let shared = NativeCarPlay()
    private var controller: CPInterfaceController?
    private let renderer = CarTemplateRenderer()
    private let store = CarEventStore.shared
    private var busy = false
    private var operations: [(String, String, [String: Any])] = []
    private var generation = 0
    private var activeOperation: (String, String)?
    private var documents: [ObjectIdentifier: [String: Any]] = [:]

    static var category: String { Bundle.main.object(forInfoDictionaryKey: "NativeCarPlayCategory") as? String ?? "unconfigured" }
    static func supportedTypes() -> [String] {
        switch category {
        case "audio": return ["list", "grid", "tabs", "search", "alert", "nowPlaying"]
        case "parking", "charging", "food": return ["list", "grid", "information", "message", "tabs", "poi", "alert"]
        default: return []
        }
    }
    static func validateSupport(_ t: [String: Any], command: String) throws {
        guard supportedTypes().contains(t["type"] as! String) else { throw CarFailure.unsupported("Template is unavailable for configured CarPlay category \(category).") }
        if t["type"] as? String == "tabs" {
            guard command == "SetRoot" else { throw CarFailure.invalid("Tabs are root-only.") }
            for child in t["tabs"] as! [[String: Any]] {
                guard ["list", "grid"].contains(child["type"] as! String) else { throw CarFailure.unsupported("Tab children must be list or grid.") }
                try validateSupport(child, command: "Tab")
            }
        }
        if (command == "Present") != (t["type"] as? String == "alert") { throw CarFailure.invalid("Alerts require Present; Present requires an alert.") }
        if command == "Replace" && !["list", "information", "message", "search", "poi"].contains(t["type"] as! String) { throw CarFailure.unsupported("This template cannot be updated in place on CarPlay.") }
        if command == "SetRoot" && t["type"] as? String == "nowPlaying" { throw CarFailure.invalid("Now Playing cannot be the root.") }
    }
    func connect(_ interface: CPInterfaceController) {
        generation += 1; controller = interface; interface.delegate = self
        store.emit("connected", ["category": Self.category]); updateStatus()
        if let root = store.root() {
            do { try CarContract.validate(root); try Self.validateSupport(root, command: "SetRoot"); enqueue("SetRoot", ["template": root]) }
            catch {
                store.emit("error", ["code": "INVALID_CACHE", "message": String(describing: error)])
                let fallback: [String: Any] = ["id": "nativephp-waiting", "type": "list", "title": "Open the app to load content", "sections": [["items": []]]]
                interface.setRootTemplate(try! renderer.make(fallback), animated: false, completion: nil)
            }
        } else {
            let placeholder: [String: Any] = ["id": "nativephp-waiting", "type": "list", "title": "Open the app to load content", "sections": [["items": []]]]
            // The placeholder is independent of persisted application data.
            interface.setRootTemplate(try! renderer.make(placeholder), animated: false, completion: nil)
        }
    }
    func disconnect(_ interface: CPInterfaceController) {
        guard controller === interface else { return }
        generation += 1
        if let (id, command) = activeOperation { store.emit("operationCompleted", ["operationId": id, "command": command, "success": false, "code": "NOT_CONNECTED", "message": "Disconnected during the operation."]) }
        activeOperation = nil
        interface.templates.forEach { renderer.release($0) }; documents.removeAll()
        controller = nil; busy = false
        store.emit("disconnected"); updateStatus(); runNext()
    }
    @discardableResult func enqueue(_ command: String, _ parameters: [String: Any], id: String = UUID().uuidString) -> String {
        guard operations.count < 64 else {
            store.emit("operationCompleted", ["operationId": id, "command": command, "success": false, "code": "QUEUE_FULL", "message": "Maximum pending operations reached."]); return id
        }
        operations.append((id, command, parameters)); runNext(); return id
    }
    private func updateStatus() {
        store.updateStatus(["connected": controller != nil, "platform": "carplay", "category": Self.category, "depth": controller?.templates.count ?? 0, "templateId": (controller?.topTemplate?.userInfo as? [String: Any])?["id"] ?? NSNull()])
    }
    private func runNext() {
        guard !busy, !operations.isEmpty else { return }
        let (id, command, p) = operations.removeFirst(); busy = true
        activeOperation = (id, command)
        let token = generation
        let finish: (Bool, Error?) -> Void = { success, error in
            let apply: () -> Void = {
                guard token == self.generation, self.activeOperation?.0 == id else { return }
                let failure = error as? CarFailure
                self.store.emit("operationCompleted", ["operationId": id, "command": command, "success": success, "code": success ? "OK" : (failure?.code ?? "HOST_REJECTED"), "message": failure?.message ?? error.map { String(describing: $0) } ?? ""])
                self.activeOperation = nil; self.busy = false; self.updateStatus(); self.runNext()
            }
            if Thread.isMainThread { apply() } else { DispatchQueue.main.async(execute: apply) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            guard self.activeOperation?.0 == id else { return }
            finish(false, CarFailure.timeout)
        }
        do {
            if command == "SetRoot", controller == nil {
                store.setRoot(p["template"] as? [String: Any]); finish(true, nil); return
            }
            if command == "Clear" {
                store.setRoot(nil)
                if let c = controller {
                    let blank: [String: Any] = ["id": "nativephp-empty", "type": "list", "title": "No content", "sections": [["items": []]]]
                    c.setRootTemplate(try renderer.make(blank), animated: false, completion: finish)
                } else { finish(true, nil) }
                return
            }
            guard let c = controller else { throw CarFailure.disconnected }
            switch command {
            case "SetRoot", "Push", "Replace", "Present":
                let t = p["template"] as! [String: Any]
                if command == "Push" && c.templates.count >= (Self.category == "food" ? 2 : 5) { throw CarFailure.invalid("Maximum template stack depth reached.") }
                var replacementTarget: CPTemplate?
                if command == "Replace" {
                    guard let current = c.topTemplate, let old = documents[ObjectIdentifier(current)], old["id"] as? String == t["id"] as? String,
                          old["type"] as? String == t["type"] as? String else { throw CarFailure.invalid("Replace requires the visible template ID and type.") }
                    if t["type"] as? String == "list" && old["title"] as? String != t["title"] as? String { throw CarFailure.unsupported("CarPlay list titles cannot change in place. Use SetRoot or Push.") }
                    replacementTarget = current
                }
                let template = try renderer.make(t)
                let complete: (Bool, Error?) -> Void = { success, error in
                    let apply: () -> Void = {
                        if success && token == self.generation && self.activeOperation?.0 == id {
                            self.documents[ObjectIdentifier(replacementTarget ?? template)] = t
                            if command == "SetRoot" { self.store.setRoot(t) }
                        } else { self.renderer.release(template) }
                        finish(success, error)
                    }
                    if Thread.isMainThread { apply() } else { DispatchQueue.main.async(execute: apply) }
                }
                switch command {
                case "SetRoot": c.setRootTemplate(template, animated: true, completion: complete)
                case "Push": c.pushTemplate(template, animated: true, completion: complete)
                case "Present": c.presentTemplate(template, animated: true, completion: complete)
                default:
                    guard let current = replacementTarget else { throw CarFailure.invalid("Missing replacement target.") }
                    // In-place updates preserve CarPlay's back stack and task depth.
                    try update(current, from: template, document: t)
                    if c.templates.first === current { store.setRoot(t) }
                    complete(true, nil)
                }
            case "Pop":
                guard c.templates.count > 1 else { throw CarFailure.invalid("Cannot pop the root.") }
                c.popTemplate(animated: true, completion: finish)
            case "PopToRoot": c.popToRootTemplate(animated: true, completion: finish)
            case "Dismiss": c.dismissTemplate(animated: true, completion: finish)
            case "Navigate":
                let (lat, lon) = try CarContract.coordinate(p)
                let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)))
                item.name = p["name"] as? String
                finish(item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]), nil)
            default: throw CarFailure.invalid("Unknown command.")
            }
        } catch { finish(false, error) }
    }
    private func update(_ target: CPTemplate, from source: CPTemplate, document: [String: Any]) throws {
        switch (target, source) {
        case (let a as CPListTemplate, let b as CPListTemplate): a.updateSections(b.sections); a.emptyViewTitleVariants = b.emptyViewTitleVariants; a.emptyViewSubtitleVariants = b.emptyViewSubtitleVariants
        case (let a as CPInformationTemplate, let b as CPInformationTemplate): a.title = b.title; a.items = b.items; a.actions = b.actions
        case (let a as CPPointOfInterestTemplate, let b as CPPointOfInterestTemplate): a.title = b.title; a.setPointsOfInterest(b.pointsOfInterest, selectedIndex: NSNotFound)
        case (let a as CPSearchTemplate, _): renderer.replaceSearch(a, document)
        default: throw CarFailure.unsupported("In-place replacement supports list, information, message, search and poi on CarPlay.")
        }
        renderer.release(source)
    }
    func dismissFromAction() { enqueue("Dismiss", [:]) }
    func templateDidAppear(_ template: CPTemplate, animated: Bool) { updateStatus(); store.emit("templateAppeared", ["templateId": (template.userInfo as? [String: Any])?["id"] ?? ""]) }
    func templateDidDisappear(_ template: CPTemplate, animated: Bool) {
        if controller?.templates.contains(where: { $0 === template }) == false {
            renderer.release(template); documents.removeValue(forKey: ObjectIdentifier(template))
        }
        updateStatus()
    }
}

@objc(NativeCarPlaySceneDelegate)
final class NativeCarPlaySceneDelegate: NSObject, CPTemplateApplicationSceneDelegate {
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) { NativeCarPlay.shared.connect(interfaceController) }
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnectInterfaceController interfaceController: CPInterfaceController) { NativeCarPlay.shared.disconnect(interfaceController) }
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController, to window: CPWindow) { NativeCarPlay.shared.connect(interfaceController) }
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnect interfaceController: CPInterfaceController, from window: CPWindow) { NativeCarPlay.shared.disconnect(interfaceController) }
    func contentStyleDidChange(_ contentStyle: UIUserInterfaceStyle) { CarEventStore.shared.emit("contentStyleChanged", ["style": contentStyle == .dark ? "dark" : "light"]) }
}
