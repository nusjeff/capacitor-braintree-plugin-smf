import PassKit

// The gateway can be shared by several apps. Its default merchant/country do not
// replace the caller's explicit Apple Pay identity and business country.
enum ApplePayRequestConfiguration {
    static func apply(to request: PKPaymentRequest, merchant: String, country: String, currency: String) -> [String] {
        var mismatches: [String] = []
        if request.currencyCode != currency {
            mismatches.append("currencyCode: checkout=\(currency), gateway=\(request.currencyCode)")
        }
        if request.supportedNetworks.isEmpty { mismatches.append("gateway supportedNetworks is empty") }
        guard mismatches.isEmpty else { return mismatches }
        request.merchantIdentifier = merchant
        request.countryCode = country
        return []
    }
}
