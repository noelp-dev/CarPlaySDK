import Foundation

@main struct ContractTests {
    static func main() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        let cases = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]
        var passed = 0
        for test in cases {
            var valid = true
            do { try CarContract.validate(test["template"] as! [String: Any]) } catch { valid = false }
            guard valid == test["valid"] as! Bool else { fatalError("Mismatch: \(test["name"]!)") }
            passed += 1
        }
        print("PASS: \(passed) Swift contract fixtures")
    }
}
