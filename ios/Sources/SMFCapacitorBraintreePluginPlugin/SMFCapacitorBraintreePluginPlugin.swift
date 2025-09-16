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
        CAPPluginMethod(name: "requestApplePayPayment", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "perform3DSecureVerification", returnType: CAPPluginReturnPromise)
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

    @objc func perform3DSecureVerification(_ call: CAPPluginCall) {
        let nonce = call.getString("nonce") ?? ""
        let clientToken = call.getString("clientToken") ?? ""
        let amount = call.getString("amount") ?? ""
        let bin = call.getString("bin") ?? ""

        guard !nonce.isEmpty else {
            call.reject("Nonce is required")
            return
        }
        guard !clientToken.isEmpty else {
            call.reject("Client token is required")
            return
        }
        guard !amount.isEmpty else {
            call.reject("Amount is required")
            return
        }

        var options: [String: Any] = [
            "nonce": nonce,
            "clientToken": clientToken,
            "amount": amount,
            "bin": bin
        ]

        if let challengeRequested = call.getBool("challengeRequested") { options["challengeRequested"] = challengeRequested }
        if let collectDeviceData = call.getBool("collectDeviceData") { options["collectDeviceData"] = collectDeviceData }
        if let exemptionRequested = call.getBool("exemptionRequested") { options["exemptionRequested"] = exemptionRequested }
        if let email = call.getString("email") { options["email"] = email }
        if let mobilePhoneNumber = call.getString("mobilePhoneNumber") { options["mobilePhoneNumber"] = mobilePhoneNumber }

        if let billingAddress = call.getObject("billingAddress") as? [String: Any] {
            options["billingAddress"] = billingAddress
        }
        if let additionalInformation = call.getObject("additionalInformation") as? [String: Any] {
            options["additionalInformation"] = additionalInformation
        }

        implementation.perform3DSecureVerification(options: options) { response, error in
            if let error = error {
                call.reject("3DS verification failed: \(error.localizedDescription)")
            } else if let response = response {
                call.resolve(response)
            } else {
                call.reject("3DS verification failed: Unknown error")
            }
        }
    }
}
