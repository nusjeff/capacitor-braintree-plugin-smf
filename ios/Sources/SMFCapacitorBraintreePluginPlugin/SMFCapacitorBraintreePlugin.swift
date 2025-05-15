import Foundation

@objc public class SMFCapacitorBraintreePlugin: NSObject {
    @objc public func echo(_ value: String) -> String {
        print(value)
        return value
    }
}
