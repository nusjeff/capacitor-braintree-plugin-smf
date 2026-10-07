import Foundation
import UIKit
import PassKit
import Braintree

// Each request has independent clients, handlers, timers and controller references.
// The Capacitor bridge retains this object until native dismissal has completed.
final class ApplePaySession: NSObject, PKPaymentAuthorizationControllerDelegate {
    private var lifecycle = ApplePayLifecycle()
    private let dismissalBarrier = ApplePayDismissalBarrier()
    let attemptId: String
    var phase: String { String(describing: lifecycle.phase) }
    private var failureStage: String?
    private let options: [String: Any]
    private let presentationWindow: UIWindow
    private let presenter: UIViewController
    private let progress: (String, [String: Any]) -> Void
    private var completion: (([String: Any]?, Error?) -> Void)?
    private var applePayClient: BTApplePayClient?
    private var dataCollector: BTDataCollector?
    private var controller: PKPaymentAuthorizationController?
    private var deviceData: String?
    private var presentationTimeout: DispatchWorkItem?
    private var authorizationTimeout: DispatchWorkItem?
    private var authorizationHandler: ((PKPaymentAuthorizationResult) -> Void)?

    init(options: [String: Any], window: UIWindow, presenter: UIViewController,
         progress: @escaping (String, [String: Any]) -> Void,
         completion: @escaping ([String: Any]?, Error?) -> Void) {
        self.attemptId = options["attemptId"] as? String ?? "unknown"
        self.options = options
        self.presentationWindow = window
        self.presenter = presenter
        self.progress = progress
        self.completion = completion
    }

    private func error(_ code: Int, _ message: String) -> NSError {
        NSError(domain: "ApplePayError", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private func emit(_ step: String, _ details: [String: Any] = [:]) {
        var data = details
        data["phase"] = phase
        data["appActive"] = UIApplication.shared.applicationState == .active
        data["windowReady"] = presenter.viewIfLoaded?.window === presentationWindow && !presentationWindow.isHidden
        data["presenterBusy"] = presenter.presentedViewController != nil || presenter.isBeingDismissed || presenter.isBeingPresented
        data["pluginRevision"] = "apple-pay-session-v2"
        data["braintreeVersion"] = "6.37.0"
        progress(step, data)
    }

    func cancel() -> Bool {
        dispatchPrecondition(condition: .onQueue(.main))
        guard lifecycle.canCancel else { return false }
        emit("cancellation_requested")
        finish(["cancelled": true], nil)
        return true
    }

    func start() {
        dispatchPrecondition(condition: .onQueue(.main))
        emit("native_request_received")
        guard let amountString = options["amount"] as? String,
              let currency = options["currencyCode"] as? String,
              let country = options["countryCode"] as? String,
              let merchant = options["merchantIdentifier"] as? String,
              let token = options["clientToken"] as? String,
              let label = options["appleMerchantName"] as? String,
              !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              merchant.hasPrefix("merchant."), !merchant.contains("yourcompany"),
              currency.range(of: "^[A-Z]{3}$", options: .regularExpression) != nil,
              country.range(of: "^[A-Z]{2}$", options: .regularExpression) != nil, country != "UK",
              amountString.range(of: "^[0-9]+(?:\\.[0-9]+)?$", options: .regularExpression) != nil else {
            finish(nil, error(8, "Invalid Apple Pay payment parameters"))
            return
        }
        let amount = NSDecimalNumber(string: amountString, locale: Locale(identifier: "en_US_POSIX"))
        guard amount != .notANumber, amount.compare(NSDecimalNumber.zero) == .orderedDescending,
              let client = BTAPIClient(authorization: token) else {
            finish(nil, error(8, "Invalid Apple Pay amount or client token"))
            return
        }
        guard PKPaymentAuthorizationController.canMakePayments() else {
            finish(nil, error(1, "Apple Pay is not available on this device"), stage: "availability")
            return
        }
        let applePayClient = BTApplePayClient(apiClient: client)
        self.applePayClient = applePayClient
        self.dataCollector = BTDataCollector(apiClient: client)
        emit("clients_initialized")
        let configurationTimeout = DispatchWorkItem { [weak self] in
            guard let self = self, self.lifecycle.phase == .preparing else { return }
            self.emit("configuration_timed_out")
            self.finish(nil, self.error(11, "Apple Pay configuration timed out"), stage: "configuration")
        }
        presentationTimeout = configurationTimeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: configurationTimeout)
        // Fetch gateway defaults rather than advertising networks the merchant cannot accept.
        applePayClient.makePaymentRequest { [weak self] request, requestError in
            DispatchQueue.main.async {
                guard let self = self, self.lifecycle.acceptsCallbacks else { return }
                guard let request = request else {
                    self.finish(nil, requestError ?? self.error(8, "Apple Pay configuration unavailable"), stage: "configuration")
                    return
                }
                let mismatches = ApplePayRequestConfiguration.apply(to: request,
                    merchant: merchant, country: country, currency: currency)
                guard mismatches.isEmpty else {
                    self.emit("configuration_mismatch")
                    self.finish(nil, self.error(12, "Apple Pay configuration does not match checkout: " + mismatches.joined(separator: "; ")), stage: "configuration")
                    return
                }
                self.presentationTimeout?.cancel()
                request.merchantCapabilities = .capability3DS
                guard PKPaymentAuthorizationController.canMakePayments(usingNetworks: request.supportedNetworks, capabilities: request.merchantCapabilities) else {
                    self.emit("availability_failed", ["eligibleCard": false])
                    self.finish(nil, self.error(1, "No supported Apple Pay card is available"), stage: "availability")
                    return
                }
                self.emit("availability_succeeded", ["eligibleCard": true])
                request.requiredBillingContactFields = [.postalAddress, .name, .emailAddress]
                request.requiredShippingContactFields = [.phoneNumber, .emailAddress]
                request.paymentSummaryItems = [PKPaymentSummaryItem(label: label, amount: amount)]
                self.collectDeviceData()
                self.present(request)
            }
        }
    }

    private func present(_ request: PKPaymentRequest) {
        guard UIApplication.shared.applicationState == .active,
              presenter.viewIfLoaded?.window === presentationWindow, !presentationWindow.isHidden,
              presenter.presentedViewController == nil,
              !presenter.isBeingPresented, !presenter.isBeingDismissed else {
            emit("presentation_context_unavailable")
            finish(nil, error(9, "Apple Pay presentation context is not ready"), stage: "presentation")
            return
        }
        guard lifecycle.beginPresentation() else { return }
        let paymentController = PKPaymentAuthorizationController(paymentRequest: request)
        controller = paymentController
        paymentController.delegate = self
        emit("presentation_started")
        let timeout = DispatchWorkItem { [weak self] in
            guard let self = self, self.lifecycle.phase == .presenting else { return }
            self.emit("presentation_timed_out")
            self.finish(nil, self.error(5, "Apple Pay presentation timed out"))
        }
        presentationTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: timeout)
        dismissalBarrier.presentationStarted()
        paymentController.present { [weak self] presented in
            DispatchQueue.main.async {
                guard let self = self else {
                    if presented { paymentController.dismiss(completion: nil) }
                    return
                }
                self.dismissalBarrier.presentationReturned()
                guard self.lifecycle.acceptsCallbacks else { return }
                self.presentationTimeout?.cancel()
                // Approval may reach the delegate before the queued presentation
                // completion. Do not dismiss an active tokenization in that case.
                guard self.lifecycle.phase == .presenting else { return }
                if presented {
                    _ = self.lifecycle.didPresent()
                    self.emit("presentation_succeeded")
                } else {
                    self.emit("presentation_failed")
                    // PassKit confirmed there is no sheet to dismiss.
                    paymentController.delegate = nil
                    self.controller = nil
                    self.finish(nil, self.error(2, "Failed to present Apple Pay"))
                }
            }
        }
    }

    private func collectDeviceData() {
        emit("device_data_started")
        dataCollector?.collectDeviceData { [weak self] data, _ in
            DispatchQueue.main.async {
                guard let self = self, self.lifecycle.acceptsCallbacks else { return }
                self.deviceData = data
                self.emit(data == nil ? "device_data_failed" : "device_data_succeeded")
            }
        }
    }

    func presentationWindow(for controller: PKPaymentAuthorizationController) -> UIWindow? {
        controller === self.controller ? presentationWindow : nil
    }

    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController,
        didAuthorizePayment payment: PKPayment,
        handler: @escaping (PKPaymentAuthorizationResult) -> Void) {
        guard controller === self.controller, lifecycle.beginAuthorization() else {
            handler(PKPaymentAuthorizationResult(status: .failure, errors: [error(6, "Apple Pay session is no longer available")]))
            return
        }
        authorizationHandler = handler
        emit("authorization_started")
        let timeout = DispatchWorkItem { [weak self] in
            guard let self = self, self.lifecycle.phase == .tokenizing else { return }
            self.emit("authorization_timed_out")
            self.authorized(nil, self.error(7, "Apple Pay tokenization timed out"))
        }
        authorizationTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 45, execute: timeout)
        emit("tokenization_started")
        applePayClient?.tokenize(payment) { [weak self] nonce, tokenError in
            DispatchQueue.main.async {
                guard let self = self, self.lifecycle.phase == .tokenizing else { return }
                guard let nonce = nonce else {
                    self.emit("tokenization_failed")
                    self.authorized(nil, tokenError ?? self.error(4, "Failed to tokenize Apple Pay payment"))
                    return
                }
                var contacts: [String: Any] = [:]
                if let billing = payment.billingContact { contacts["billingContact"] = self.formatContact(billing) }
                if let shipping = payment.shippingContact { contacts["shippingContact"] = self.formatContact(shipping) }
                var result: [String: Any] = [
                    "cancelled": false, "nonce": nonce.nonce, "type": nonce.type,
                    "localizedDescription": nonce.description, "applePay": contacts,
                    "emailAddress": payment.shippingContact?.emailAddress ?? payment.billingContact?.emailAddress ?? ""
                ]
                if let deviceData = self.deviceData { result["deviceData"] = deviceData }
                self.emit("tokenization_succeeded")
                self.authorized(result, nil)
            }
        }
    }

    private func authorized(_ result: [String: Any]?, _ failure: Error?) {
        guard lifecycle.phase == .tokenizing else { return }
        authorizationTimeout?.cancel()
        let handler = authorizationHandler
        authorizationHandler = nil
        emit(failure == nil ? "authorization_succeeded" : "authorization_failed")
        // Commit the lifecycle before calling PassKit: the authorization handler
        // may synchronously trigger didFinish.
        authorizationHandler = handler
        finish(result, failure, stage: "tokenization")
    }

    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        guard controller === self.controller, lifecycle.acceptsCallbacks else { return }
        emit("payment_cancelled")
        finish(["cancelled": true], nil)
    }

    private func finish(_ result: [String: Any]?, _ failure: Error?, stage: String? = nil) {
        let priorPhase = lifecycle.phase
        guard lifecycle.beginDismissal() else { return }
        if failure != nil {
            failureStage = stage ?? (priorPhase == .preparing ? "validation" : "presentation")
        }
        presentationTimeout?.cancel()
        authorizationTimeout?.cancel()
        let handler = authorizationHandler
        authorizationHandler = nil
        let succeeded = failure == nil && result?["cancelled"] as? Bool != true
        handler?(PKPaymentAuthorizationResult(status: succeeded ? .success : .failure,
            errors: succeeded ? nil : [failure ?? error(10, "Apple Pay cancelled")]))
        emit("dismissal_started")
        dismissalBarrier.finish(dismiss: { [weak self] done in
            if let controller = self?.controller {
                controller.dismiss {
                    DispatchQueue.main.async { done() }
                }
            } else {
                done()
            }
        }, completion: { [weak self] in
            self?.complete(result, failure)
        })
    }

    private func complete(_ result: [String: Any]?, _ failure: Error?) {
        guard lifecycle.completeDismissal() else { return }
        controller?.delegate = nil
        controller = nil
        applePayClient = nil
        dataCollector = nil
        emit("sheet_dismissed")
        emit(failure != nil ? "bridge_rejected" : (result?["cancelled"] as? Bool == true ? "bridge_resolved_cancelled" : "bridge_resolved_success"))
        let callback = completion
        completion = nil
        if let failure = failure {
            let native = failure as NSError
            var info = native.userInfo
            info["failureStage"] = failureStage ?? "unknown"
            callback?(result, NSError(domain: native.domain, code: native.code, userInfo: info))
        } else {
            callback?(result, nil)
        }
    }

    private func formatContact(_ contact: PKContact) -> [String: Any] {
        var contactData: [String: Any] = [:]

        // Name
        if let name = contact.name {
            if let givenName = name.givenName {
                contactData["givenName"] = givenName
            } else {
                contactData["givenName"] = ""
            }

            if let familyName = name.familyName {
                contactData["familyName"] = familyName
            } else {
                contactData["familyName"] = ""
            }
        }


        // Phone
        if let phoneNumber = contact.phoneNumber {
            contactData["phoneNumber"] = phoneNumber.stringValue
        }

        // Email
        if let emailAddress = contact.emailAddress {
            contactData["emailAddress"] = emailAddress
        }

        // Address
        if let postalAddress = contact.postalAddress {
            contactData["addressLines"] = [postalAddress.street]
            contactData["locality"] = postalAddress.city
            contactData["subLocality"] = postalAddress.subLocality
            contactData["administrativeArea"] = postalAddress.state
            contactData["subAdministrativeArea"] = postalAddress.subAdministrativeArea
            contactData["postalCode"] = postalAddress.postalCode
            contactData["countryCode"] = postalAddress.isoCountryCode
            contactData["country"] = postalAddress.country
        } else {
            // Set default empty values for address fields
            contactData["addressLines"] = [""]
            contactData["locality"] = ""
            contactData["subLocality"] = ""
            contactData["administrativeArea"] = ""
            contactData["subAdministrativeArea"] = ""
            contactData["postalCode"] = ""
            contactData["countryCode"] = ""
            contactData["country"] = ""
        }

        return contactData
    }

}
