import Foundation
import Capacitor

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */
@objc(SMFCapacitorBraintreePluginPlugin)
public class SMFCapacitorBraintreePluginPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "SMFCapacitorBraintreePluginPlugin"
    public let jsName = "SMFCapacitorBraintreePlugin"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "requestApplePayPayment", returnType: CAPPluginReturnPromise)
    ]
    private let implementation = SMFCapacitorBraintreePlugin()

    @objc func requestApplePayPayment(_ call: CAPPluginCall) {
        let amount = call.getString("amount") ?? ""
        let currencyCode = call.getString("currencyCode") ?? ""
        let clientToken = call.getString("clientToken") ?? ""
        let merchantIdentifier = call.getString("appleMerchantId") ?? "merchant.com.yourcompany.yourapp"
        let countryCode = call.getString("countryCodeAlpha2") ?? "UK"
        let givenName = call.getString("givenName")
        let surname = call.getString("surname")
        let email = call.getString("email")
        let postalCode = call.getString("postalCode")
        let countryCodeAlpha2 = call.getString("countryCodeAlpha2")
        let appleMerchantName = call.getString("appleMerchantName") ?? "SplitMyFare"

        // Validate required parameters
        guard !amount.isEmpty else {
            call.reject("Amount is required")
            return
        }

        guard !currencyCode.isEmpty else {
            call.reject("Currency code is required")
            return
        }

        guard !clientToken.isEmpty else {
            call.reject("Client token is required")
            return
        }
        
        let options: [String: Any] = [
            "amount": amount,
            "currencyCode": currencyCode,
            "clientToken": clientToken,
            "merchantIdentifier": merchantIdentifier,
            "countryCode": countryCode,
            "givenName": givenName ?? "",
            "surname": surname ?? "",
            "email": email ?? "",
            "postalCode": postalCode ?? "",
            "countryCodeAlpha2": countryCodeAlpha2 ?? "",
            "appleMerchantName": appleMerchantName
        ]

        // Call the implementation
        implementation.requestApplePayPayment(
            options: options
        ) { response, error in
            if let error = error {
                call.reject("Apple Pay failed: \(error.localizedDescription)")
            } else if let response = response {
                call.resolve(response)
            } else {
                call.reject("Apple Pay failed: Unknown error")
            }
        }
    }
}
