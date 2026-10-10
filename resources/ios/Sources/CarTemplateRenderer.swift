import CarPlay
import MapKit
import UIKit

final class CarTemplateRenderer: NSObject, CPSearchTemplateDelegate, CPTabBarTemplateDelegate, CPPointOfInterestTemplateDelegate {
    private var searchData: [ObjectIdentifier: [String: Any]] = [:]
    private var poiData: [ObjectIdentifier: String] = [:]
    private let emit = CarEventStore.shared

    static func image(_ name: String?) -> UIImage {
        let symbols = ["list": "list.bullet", "grid": "square.grid.2x2", "search": "magnifyingglass", "map": "map", "pin": "mappin", "parking": "parkingsign.circle", "charging": "bolt.car", "food": "fork.knife", "music": "music.note", "play": "play.fill", "pause": "pause.fill", "info": "info.circle", "star": "star", "home": "house"]
        return UIImage(systemName: symbols[name ?? "info"] ?? "info.circle")!
    }
    private func selected(_ t: [String: Any], _ row: [String: Any]) {
        emit.emit("itemSelected", ["templateId": t["id"]!, "itemId": row["id"]!, "actionId": row["action"] ?? row["id"]!])
    }
    private func listItem(_ t: [String: Any], _ r: [String: Any]) -> CPListItem {
        let item = CPListItem(text: r["title"] as? String, detailText: r["detail"] as? String, image: r["icon"] == nil ? nil : Self.image(r["icon"] as? String))
        item.userInfo = r
        item.isEnabled = r["enabled"] as? Bool ?? true
        item.handler = { [weak self] _, completion in
            defer { completion() } // Never wait for PHP before completing a host selection.
            self?.selected(t, r)
        }
        return item
    }
    private func buttons(_ t: [String: Any], _ actions: [[String: Any]], pointId: String? = nil) -> [CPTextButton] {
        actions.map { a in
            CPTextButton(title: a["title"] as! String, textStyle: a["style"] as? String == "cancel" ? .cancel : .normal) { [weak self] _ in
                var payload: [String: Any] = ["templateId": t["id"]!, "actionId": a["id"]!]
                if let pointId = pointId { payload["pointId"] = pointId }
                self?.emit.emit("actionPressed", payload)
            }
        }
    }
    func make(_ t: [String: Any]) throws -> CPTemplate {
        let title = t["title"] as! String
        let template: CPTemplate
        switch t["type"] as! String {
        case "list":
            let sections = (t["sections"] as! [[String: Any]]).map { s in
                CPListSection(items: (s["items"] as! [[String: Any]]).map { listItem(t, $0) }, header: s["title"] as? String, sectionIndexTitle: nil)
            }
            let list = CPListTemplate(title: title, sections: sections)
            list.emptyViewTitleVariants = [title]
            list.emptyViewSubtitleVariants = [(t["loading"] as? Bool ?? false) ? "Loading…" : "No items"]
            template = list
        case "grid":
            template = CPGridTemplate(title: title, gridButtons: (t["items"] as! [[String: Any]]).map { r in
                let button = CPGridButton(titleVariants: [r["title"] as! String], image: Self.image(r["icon"] as? String)) { [weak self] _ in self?.selected(t, r) }
                button.isEnabled = r["enabled"] as? Bool ?? true
                return button
            })
        case "information", "message":
            let items = t["type"] as! String == "message" ? [["title": title, "detail": t["message"]!]] : t["items"] as! [[String: Any]]
            template = CPInformationTemplate(title: title, layout: .leading, items: items.map { CPInformationItem(title: $0["title"] as? String, detail: $0["detail"] as? String) }, actions: buttons(t, t["actions"] as? [[String: Any]] ?? []))
        case "search":
            let search = CPSearchTemplate(); search.delegate = self
            searchData[ObjectIdentifier(search)] = t; template = search
        case "tabs":
            let children = try (t["tabs"] as! [[String: Any]]).map { try make($0) }
            let tabs = CPTabBarTemplate(templates: children); tabs.delegate = self; template = tabs
        case "poi":
            let points = try (t["points"] as! [[String: Any]]).map { p -> CPPointOfInterest in
                let (lat, lon) = try CarContract.coordinate(p)
                let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)))
                mapItem.name = p["title"] as? String
                let point = CPPointOfInterest(location: mapItem, title: p["title"] as! String, subtitle: p["subtitle"] as? String, summary: p["summary"] as? String, detailTitle: p["title"] as? String, detailSubtitle: p["subtitle"] as? String, detailSummary: p["summary"] as? String, pinImage: Self.image("pin"))
                point.userInfo = p["id"]
                let actions = buttons(t, p["actions"] as? [[String: Any]] ?? [], pointId: p["id"] as? String)
                point.primaryButton = actions.first; point.secondaryButton = actions.count > 1 ? actions[1] : nil
                return point
            }
            let poi = CPPointOfInterestTemplate(title: title, pointsOfInterest: points, selectedIndex: NSNotFound)
            poi.pointOfInterestDelegate = self; poiData[ObjectIdentifier(poi)] = t["id"] as? String; template = poi
        case "alert":
            let actions = (t["actions"] as! [[String: Any]]).map { a in
                CPAlertAction(title: a["title"] as! String, style: a["style"] as? String == "cancel" ? .cancel : (a["style"] as? String == "destructive" ? .destructive : .default)) { [weak self] _ in
                    self?.emit.emit("actionPressed", ["templateId": t["id"]!, "actionId": a["id"]!])
                    NativeCarPlay.shared.dismissFromAction()
                }
            }
            template = CPAlertTemplate(titleVariants: [title], actions: actions)
        case "nowPlaying": template = CPNowPlayingTemplate.shared
        default: throw CarFailure.unsupported("Unknown template.")
        }
        template.userInfo = ["id": t["id"]!]
        template.tabTitle = title; template.tabImage = Self.image(t["icon"] as? String)
        return template
    }
    func searchTemplate(_ searchTemplate: CPSearchTemplate, updatedSearchText searchText: String, completionHandler: @escaping ([CPListItem]) -> Void) {
        guard let t = searchData[ObjectIdentifier(searchTemplate)] else { completionHandler([]); return }
        let query = String(searchText.prefix(128))
        emit.emit("searchChanged", ["templateId": t["id"]!, "query": query])
        let rows = (t["items"] as? [[String: Any]] ?? []).filter { query.isEmpty || ($0["title"] as? String ?? "").localizedCaseInsensitiveContains(query) }
        completionHandler(rows.prefix(100).map {
            let item = listItem(t, $0); item.handler = nil; return item
        })
    }
    func searchTemplate(_ searchTemplate: CPSearchTemplate, selectedResult item: CPListItem, completionHandler: @escaping () -> Void) {
        defer { completionHandler() }
        if let t = searchData[ObjectIdentifier(searchTemplate)], let row = item.userInfo as? [String: Any] { selected(t, row) }
    }
    func tabBarTemplate(_ tabBarTemplate: CPTabBarTemplate, didSelect selectedTemplate: CPTemplate) {
        emit.emit("tabSelected", ["templateId": (tabBarTemplate.userInfo as? [String: Any])?["id"] ?? "", "tabId": (selectedTemplate.userInfo as? [String: Any])?["id"] ?? ""])
    }
    func pointOfInterestTemplate(_ pointOfInterestTemplate: CPPointOfInterestTemplate, didChangeMapRegion region: MKCoordinateRegion) {
        emit.emit("mapRegionChanged", ["templateId": poiData[ObjectIdentifier(pointOfInterestTemplate)] ?? "", "latitude": region.center.latitude, "longitude": region.center.longitude, "latitudeDelta": region.span.latitudeDelta, "longitudeDelta": region.span.longitudeDelta])
    }
    func pointOfInterestTemplate(_ pointOfInterestTemplate: CPPointOfInterestTemplate, didSelectPointOfInterest pointOfInterest: CPPointOfInterest) {
        emit.emit("pointSelected", ["templateId": poiData[ObjectIdentifier(pointOfInterestTemplate)] ?? "", "pointId": pointOfInterest.userInfo as? String ?? ""])
    }
    func replaceSearch(_ template: CPSearchTemplate, _ document: [String: Any]) { searchData[ObjectIdentifier(template)] = document }
    func release(_ template: CPTemplate) {
        searchData.removeValue(forKey: ObjectIdentifier(template)); poiData.removeValue(forKey: ObjectIdentifier(template))
        if let tabs = template as? CPTabBarTemplate { tabs.templates.forEach { release($0) } }
    }
}
