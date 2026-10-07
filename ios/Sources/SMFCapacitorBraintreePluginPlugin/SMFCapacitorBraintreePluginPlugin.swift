import Foundation
import Capacitor
import UIKit
import PassKit
import Braintree

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
        CAPPluginMethod(name: "getApplePayAvailability", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getApplePayStatus", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "cancelApplePayPayment", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "perform3DSecureVerification", returnType: CAPPluginReturnPromise)
    ]
    private let implementation = SMFCapacitorBraintreePlugin()

    // Card 3DS and Apple Pay own separate clients; each Apple Pay attempt owns
    // its callbacks, and remains retained until the native sheet is dismissed.
    private var applePaySession: ApplePaySession?

    @objc func getApplePayStatus(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            if let session = self.applePaySession {
                call.resolve(["active": true, "attemptId": session.attemptId, "phase": session.phase])
            } else {
                call.resolve(["active": false])
            }
        }
    }

    @objc func cancelApplePayPayment(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let attemptId = call.getString("attemptId"),
                  let session = self.applePaySession, session.attemptId == attemptId else {
                call.resolve(["accepted": false, "active": self.applePaySession != nil])
                return
            }
            let accepted = session.cancel()
            call.resolve(["accepted": accepted, "active": self.applePaySession != nil, "phase": session.phase])
        }
    }

    @objc func getApplePayAvailability(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard PKPaymentAuthorizationController.canMakePayments() else {
                call.resolve(["available": false])
                return
            }
            guard let client = BTAPIClient(authorization: call.getString("clientToken") ?? "") else {
                call.reject("Invalid client token", "APPLE_PAY_INVALID_REQUEST")
                return
            }
            let applePayClient = BTApplePayClient(apiClient: client)
            applePayClient.makePaymentRequest { request, error in
                DispatchQueue.main.async {
                    guard let request = request else {
                        let native = error as NSError?
                        call.reject("Apple Pay configuration unavailable", "APPLE_PAY_CONFIGURATION_FAILED", error,
                            ["failureStage": "configuration", "failureKind": "gateway_fetch",
                             "nativeErrorDomain": native?.domain ?? "ApplePayError", "nativeErrorCode": native?.code ?? 8])
                        return
                    }
                    let available = PKPaymentAuthorizationController.canMakePayments(
                        usingNetworks: request.supportedNetworks, capabilities: .capability3DS)
                    call.resolve(["available": available])
                }
            }
        }
    }

    @objc func requestApplePayPayment(_ call: CAPPluginCall) {
        let options: [String: Any] = [
            "attemptId": call.getString("attemptId") ?? "unknown",
            "amount": call.getString("amount") ?? "",
            "currencyCode": call.getString("currencyCode") ?? "",
            "clientToken": call.getString("clientToken") ?? "",
            "merchantIdentifier": call.getString("appleMerchantId") ?? "",
            "countryCode": call.getString("countryCodeAlpha2") ?? "",
            "appleMerchantName": call.getString("appleMerchantName") ?? "SplitMyFare"
        ]
        let attemptId = call.getString("attemptId") ?? "unknown"
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                call.reject("Apple Pay failed: Plugin unavailable", "APPLE_PAY_UNAVAILABLE")
                return
            }
            if let activeSession = self.applePaySession {
                call.reject("Apple Pay failed: Payment already in progress", "APPLE_PAY_BUSY", nil,
                    ["activeAttemptId": activeSession.attemptId, "phase": activeSession.phase,
                     "failureStage": "concurrency", "failureKind": "busy"])
                return
            }
            guard let presenter = self.bridge?.viewController,
                  let window = presenter.viewIfLoaded?.window else {
                call.reject("Apple Pay failed: Presentation window unavailable", "APPLE_PAY_CONTEXT_UNAVAILABLE", nil,
                    ["failureStage": "presentation", "failureKind": "context_unavailable"])
                return
            }
            let session = ApplePaySession(options: options, window: window, presenter: presenter,
                progress: { [weak self] step, details in
                    var data = details
                    data["attemptId"] = attemptId
                    data["step"] = step
                    self?.notifyListeners("applePayProgress", data: data)
                }, completion: { [weak self] response, error in
                    self?.applePaySession = nil
                    if let error = error {
                        let nativeError = error as NSError
                        let codes = [1: "APPLE_PAY_UNAVAILABLE", 2: "APPLE_PAY_PRESENTATION_FAILED",
                                     5: "APPLE_PAY_PRESENTATION_TIMEOUT", 7: "APPLE_PAY_TOKENIZATION_TIMEOUT",
                                     8: "APPLE_PAY_INVALID_REQUEST", 9: "APPLE_PAY_CONTEXT_UNAVAILABLE",
                                     11: "APPLE_PAY_CONFIGURATION_TIMEOUT",
                                     12: "APPLE_PAY_CONFIGURATION_MISMATCH"]
                        let stage = nativeError.userInfo["failureStage"] as? String ?? "unknown"
                        let code = nativeError.domain == "ApplePayError" ? (codes[nativeError.code] ?? "APPLE_PAY_FAILED") :
                            (stage == "configuration" ? "APPLE_PAY_CONFIGURATION_FAILED" : "APPLE_PAY_TOKENIZATION_FAILED")
                        call.reject("Apple Pay failed: \(error.localizedDescription)", code, error,
                            ["nativeErrorDomain": nativeError.domain, "nativeErrorCode": nativeError.code,
                             "failureStage": stage, "failureKind": code])
                    } else {
                        call.resolve(response ?? ["cancelled": true])
                    }
                })
            self.applePaySession = session
            session.start()
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
