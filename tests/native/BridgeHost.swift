import Foundation

// Only the NativePHP host boundary is substituted. UIKit/CarPlay/MapKit are real SDKs.
protocol BridgeFunction {
    func execute(parameters: [String: Any]) throws -> [String: Any]
}
enum BridgeResponse {
    static func error(code: String, message: String) -> [String: Any] { ["status": "error", "code": code, "message": message] }
}
final class LaravelBridge {
    static let shared = LaravelBridge()
    var send: ((String, [String: Any]) -> Void)?
}
