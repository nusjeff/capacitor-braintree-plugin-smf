import Foundation
import Braintree
import PassKit

@objc public class SMFCapacitorBraintreePlugin: NSObject {

    private var braintreeClient: BTAPIClient?
    private var applePayClient: BTApplePayClient?
    private var dataCollector: BTDataCollector?
    private var completionHandler: (([String: Any]?, Error?) -> Void)? = nil
    private var progressHandler: ((String) -> Void)? = nil
    private var paymentController: PKPaymentAuthorizationController?
    private var isCompleted = false
    private var isAuthorizing = false
    private var collectedDeviceData: String?
    private var presentationTimeoutWorkItem: DispatchWorkItem?
    private var authorizationTimeoutWorkItem: DispatchWorkItem?
    private var threeDSecureClient: BTThreeDSecureClient?

    @objc public func echo(_ value: String) -> String {
        print(value)
        return value
    }

    @objc public func perform3DSecureVerification(
        options: [String: Any],
        completion: @escaping ([String: Any]?, Error?) -> Void
    ) {
        guard let nonce = options["nonce"] as? String,
              let amount = options["amount"] as? String,
              let clientToken = options["clientToken"] as? String else {
            completion(nil, NSError(domain: "ThreeDSecureError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing required parameters"]))
            return
        }

        // Initialize API client
        let apiClient = BTAPIClient(authorization: clientToken)
        self.braintreeClient = apiClient
        self.dataCollector = BTDataCollector(apiClient: apiClient!)

        // Build 3DS request
        let threeDSecureRequest = BTThreeDSecureRequest()
        threeDSecureRequest.amount = NSDecimalNumber(string: amount)
        threeDSecureRequest.nonce = nonce
        if let challengeRequested = options["challengeRequested"] as? Bool { threeDSecureRequest.challengeRequested = challengeRequested }
        if let exemptionRequested = options["exemptionRequested"] as? Bool { threeDSecureRequest.exemptionRequested = exemptionRequested }
        threeDSecureRequest.threeDSecureRequestDelegate = self

        // Additional info
        let additionalInfo = BTThreeDSecureAdditionalInformation()
        if let additional = options["additionalInformation"] as? [String: Any], let deliveryEmail = additional["deliveryEmail"] as? String {
            additionalInfo.deliveryEmail = deliveryEmail
        }
        threeDSecureRequest.additionalInformation = additionalInfo

        if let billingAddress = options["billingAddress"] as? [String: Any] {
            let address = BTThreeDSecurePostalAddress()
            address.givenName = billingAddress["givenName"] as? String
            address.surname = billingAddress["surname"] as? String
            address.phoneNumber = billingAddress["phoneNumber"] as? String
            address.streetAddress = billingAddress["streetAddress"] as? String
            address.extendedAddress = billingAddress["extendedAddress"] as? String
            address.locality = billingAddress["locality"] as? String
            address.region = billingAddress["region"] as? String
            address.postalCode = billingAddress["postalCode"] as? String
            address.countryCodeAlpha2 = billingAddress["countryCodeAlpha2"] as? String
            threeDSecureRequest.billingAddress = address
        }

        // Configure client and start payment flow (v6 API)
        let threeDSClient = BTThreeDSecureClient(apiClient: apiClient!)
        self.threeDSecureClient = threeDSClient

        DispatchQueue.main.async {
            threeDSClient.startPaymentFlow(threeDSecureRequest) { result, error in
                if let error = error {
                    // Check if the error is due to user cancellation
                    if let nsError = error as NSError?, nsError.domain == "com.braintreepayments.BTThreeDSecureFlowErrorDomain", nsError.code == 5 {
                        // User cancelled the 3DS flow
                        var response: [String: Any] = [:]
                        response["threeDSecureInfo"] = ["status": "challenge_required"]
                        completion(response, nil)
                        return
                    }
                    completion(nil, error)
                    return
                }
                guard let result = result else {
                    completion(nil, NSError(domain: "ThreeDSecureError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No 3DS result"]))
                    return
                }

                var response: [String: Any] = [:]

                if let tokenizedCard = result.tokenizedCard {
                    response["nonce"] = tokenizedCard.nonce
                    response["type"] = tokenizedCard.type

                    let binData = tokenizedCard.binData
                    var binDict: [String: Any] = [:]
                    binDict["prepaid"] = binData.prepaid
                    binDict["healthcare"] = binData.healthcare
                    binDict["debit"] = binData.debit
                    binDict["durbinRegulated"] = binData.durbinRegulated
                    binDict["commercial"] = binData.commercial
                    binDict["payroll"] = binData.payroll
                    binDict["issuingBank"] = binData.issuingBank
                    binDict["countryOfIssuance"] = binData.countryOfIssuance
                    response["binData"] = binDict

                    let info = tokenizedCard.threeDSecureInfo
                    let liabilityShiftPossible = info.liabilityShiftPossible ?? false
                    let liabilityShifted = info.liabilityShifted ?? false
                    response["liabilityShiftPossible"] = liabilityShiftPossible
                    response["liabilityShifted"] = liabilityShifted

                    var infoDict: [String: Any] = [:]
                    infoDict["liabilityShiftPossible"] = liabilityShiftPossible
                    infoDict["liabilityShifted"] = liabilityShifted
                    infoDict["cavv"] = info.cavv ?? ""
                    infoDict["xid"] = info.xid ?? ""
                    infoDict["dsTransactionId"] = info.dsTransactionID ?? ""
                    infoDict["threeDSecureVersion"] = info.threeDSecureVersion ?? ""
                    infoDict["eciFlag"] = info.eciFlag ?? ""
                    infoDict["threeDSecureAuthenticationId"] = info.threeDSecureAuthenticationID ?? ""
                    response["threeDSecureInfo"] = infoDict
                } else {
                    response["nonce"] = ""
                    response["type"] = ""
                    response["description"] = ""
                    response["binData"] = [:]
                    response["liabilityShiftPossible"] = false
                    response["liabilityShifted"] = false
                    response["threeDSecureInfo"] = [
                        "liabilityShiftPossible": false,
                        "liabilityShifted": false,
                        "cavv": "",
                        "xid": "",
                        "dsTransactionId": "",
                        "threeDSecureVersion": "",
                        "eciFlag": "",
                        "threeDSecureAuthenticationId": ""
                    ]
                }

                completion(response, nil)
            }
        }
    }

    @objc public func requestApplePayPayment(
        options: [String: Any],
        progress: @escaping (String) -> Void,
        completion: @escaping ([String: Any]?, Error?) -> Void
    ) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.requestApplePayPayment(options: options, progress: progress, completion: completion)
            }
            return
        }

        guard completionHandler == nil else {
            completion(nil, NSError(domain: "ApplePayError", code: 6, userInfo: [NSLocalizedDescriptionKey: "An Apple Pay payment is already in progress"]))
            return
        }

        // Extract parameters from options dictionary
        let amount = options["amount"] as! String
        let currencyCode = options["currencyCode"] as! String
        let clientToken = options["clientToken"] as! String
        let merchantIdentifier = options["merchantIdentifier"] as! String
        let countryCode = options["countryCode"] as! String
        let givenName = options["givenName"] as? String
        let surname = options["surname"] as? String
        let email = options["email"] as? String
        let postalCode = options["postalCode"] as? String
        let countryCodeAlpha2 = options["countryCodeAlpha2"] as? String
        let appleMerchantName = options["appleMerchantName"] as? String

        self.completionHandler = completion
        self.progressHandler = progress
        self.isCompleted = false
        self.isAuthorizing = false
        self.collectedDeviceData = nil
        emitProgress("native_request_received")

        // Initialize Braintree clients
        braintreeClient = BTAPIClient(authorization: clientToken)
        applePayClient = BTApplePayClient(apiClient: braintreeClient!)
        dataCollector = BTDataCollector(apiClient: braintreeClient!)
        emitProgress("clients_initialized")
        collectDeviceData()

        // Check if Apple Pay is available
        guard PKPaymentAuthorizationController.canMakePayments() else {
            emitProgress("availability_failed")
            callCompletionHandler(.failure(NSError(domain: "ApplePayError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Apple Pay is not available on this device"])))
            return
        }
        emitProgress("availability_succeeded")

        // Create payment request
        let paymentRequest = PKPaymentRequest()
        paymentRequest.merchantIdentifier = merchantIdentifier
         paymentRequest.supportedNetworks = [.visa, .masterCard, .amex, .discover]
        paymentRequest.merchantCapabilities = .capability3DS
        paymentRequest.countryCode = countryCode
        paymentRequest.currencyCode = currencyCode

        // Set required billing and shipping contact fields
        paymentRequest.requiredBillingContactFields = [.postalAddress, .name, .emailAddress]
        paymentRequest.requiredShippingContactFields = [.phoneNumber, .emailAddress]

        // Create payment summary items
        let amountDecimal = NSDecimalNumber(string: amount) ?? NSDecimalNumber.zero
        let paymentItem = PKPaymentSummaryItem(label: appleMerchantName!, amount: amountDecimal)
        paymentRequest.paymentSummaryItems = [paymentItem]

        // Create and present payment authorization controller
        paymentController = PKPaymentAuthorizationController(paymentRequest: paymentRequest)
        paymentController?.delegate = self
        emitProgress("presentation_started")

        let presentationTimeout = DispatchWorkItem { [weak self] in
            guard let self = self, !self.isCompleted else { return }
            self.emitProgress("presentation_timed_out")
            self.paymentController?.dismiss()
            self.callCompletionHandler(.failure(NSError(domain: "ApplePayError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Apple Pay presentation timed out"])))
        }
        presentationTimeoutWorkItem = presentationTimeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: presentationTimeout)

        paymentController?.present { [weak self] presented in
            guard let self = self else { return }
            self.presentationTimeoutWorkItem?.cancel()
            self.presentationTimeoutWorkItem = nil
            if !presented {
                self.emitProgress("presentation_failed")
                self.callCompletionHandler(.failure(NSError(domain: "ApplePayError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to present Apple Pay"])))
                return
            }
            self.emitProgress("presentation_succeeded")
        }
    }

    private func collectDeviceData() {
        emitProgress("device_data_started")
        dataCollector?.collectDeviceData { [weak self] deviceData, error in
            DispatchQueue.main.async {
                guard let self = self, !self.isCompleted else { return }
                if let deviceData = deviceData {
                    self.collectedDeviceData = deviceData
                    self.emitProgress("device_data_succeeded")
                } else {
                    self.emitProgress("device_data_failed")
                    if let error = error {
                        print("Error collecting device data: \(error)")
                    }
                }
            }
        }
    }

    private func tokenizeApplePayPayment(
        _ payment: PKPayment,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        guard let applePayClient = applePayClient else {
            completion(.failure(NSError(domain: "ApplePayError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Apple Pay client not initialized"])))
            return
        }
        emitProgress("tokenization_started")
        applePayClient.tokenize(payment) { [weak self] tokenizedPayment, error in
            DispatchQueue.main.async {
                guard let self = self, !self.isCompleted else { return }

                if let error = error {
                    self.emitProgress("tokenization_failed")
                    completion(.failure(error))
                    return
                }

                guard let tokenizedPayment = tokenizedPayment else {
                    self.emitProgress("tokenization_failed")
                    completion(.failure(NSError(domain: "ApplePayError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to tokenize Apple Pay payment"])))
                    return
                }

                var result: [String: Any] = [
                    "cancelled": false,
                    "nonce": tokenizedPayment.nonce,
                    "type": tokenizedPayment.type ?? "Unknown",
                    "localizedDescription": tokenizedPayment.description,
                    "emailAddress": ""
                ]

                if let deviceData = self.collectedDeviceData {
                    result["deviceData"] = deviceData
                }

                // Add Apple Pay specific contact information
                var applePayData: [String: Any] = [:]

                // Billing contact
                if let billingContact = payment.billingContact {
                    applePayData["billingContact"] = self.formatContact(billingContact)
                    result["emailAddress"] = billingContact.emailAddress ?? ""
                }

                // Shipping contact
                if let shippingContact = payment.shippingContact {
                    applePayData["shippingContact"] = self.formatContact(shippingContact)
                    result["emailAddress"] = shippingContact.emailAddress ?? ""
                }

                result["applePay"] = applePayData

                self.emitProgress("tokenization_succeeded")
                completion(.success(result))
            }
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

    private func handlePaymentCancellation() {
        emitProgress("payment_cancelled")
        let result: [String: Any] = [
            "cancelled": true,
            "nonce": "",
            "type": "",
            "localizedDescription": "Payment cancelled by user",
            "deviceData": "",
            "applePay": [:]
        ]
        callCompletionHandler(.success(result))
    }

    private func callCompletionHandler(_ result: Result<[String: Any], Error>) {
        guard !isCompleted else { return }
        isCompleted = true
        isAuthorizing = false
        presentationTimeoutWorkItem?.cancel()
        presentationTimeoutWorkItem = nil
        authorizationTimeoutWorkItem?.cancel()
        authorizationTimeoutWorkItem = nil
        let completion = completionHandler
        completionHandler = nil
        switch result {
        case .success(let data):
            emitProgress(data["cancelled"] as? Bool == true ? "bridge_resolved_cancelled" : "bridge_resolved_success")
            completion?(data, nil)
        case .failure(let error):
            emitProgress("bridge_rejected")
            completion?(nil, error)
        }
        progressHandler = nil
    }

    private func emitProgress(_ step: String) {
        progressHandler?(step)
    }
}

// MARK: - BTThreeDSecureRequestDelegate
extension SMFCapacitorBraintreePlugin: BTThreeDSecureRequestDelegate {
    public func onLookupComplete(_ request: BTThreeDSecureRequest, lookupResult result: BTThreeDSecureResult, next: @escaping () -> Void) {
        // Optionally inspect result.lookup?.acsURL or requiresUserAuthentication to prep UI
        next()
    }

}

// MARK: - PKPaymentAuthorizationControllerDelegate
extension SMFCapacitorBraintreePlugin: PKPaymentAuthorizationControllerDelegate {

    public func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        isAuthorizing = true
        emitProgress("authorization_started")

        let authorizationTimeout = DispatchWorkItem { [weak self] in
            guard let self = self, !self.isCompleted else { return }
            let error = NSError(domain: "ApplePayError", code: 7, userInfo: [NSLocalizedDescriptionKey: "Apple Pay tokenization timed out"])
            self.emitProgress("authorization_timed_out")
            self.callCompletionHandler(.failure(error))
            completion(PKPaymentAuthorizationResult(status: .failure, errors: [error]))
        }
        authorizationTimeoutWorkItem = authorizationTimeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 45, execute: authorizationTimeout)

        tokenizeApplePayPayment(payment) { [weak self] result in
            guard let self = self, !self.isCompleted else { return }
            self.authorizationTimeoutWorkItem?.cancel()
            self.authorizationTimeoutWorkItem = nil

            switch result {
            case .success(let data):
                self.emitProgress("authorization_succeeded")
                self.callCompletionHandler(.success(data))
                completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
            case .failure(let error):
                self.emitProgress("authorization_failed")
                self.callCompletionHandler(.failure(error))
                completion(PKPaymentAuthorizationResult(status: .failure, errors: [error]))
            }
        }
    }

    public func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        emitProgress("sheet_dismissed")
        controller.dismiss { [weak self] in
            self?.paymentController = nil
        }
        // No authorization means the user closed the sheet before approving payment.
        if !isCompleted && !isAuthorizing {
            handlePaymentCancellation()
        }
    }
}
