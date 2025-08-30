import Foundation
import Braintree
import PassKit

@objc public class SMFCapacitorBraintreePlugin: NSObject {

    private var braintreeClient: BTAPIClient?
    private var applePayClient: BTApplePayClient?
    private var dataCollector: BTDataCollector?
    private var completionHandler: (([String: Any]?, Error?) -> Void)? = nil
    private var paymentController: PKPaymentAuthorizationController?
    private var isCompleted = false

    @objc public func echo(_ value: String) -> String {
        print(value)
        return value
    }

    @objc public func requestApplePayPayment(
        options: [String: Any],
        completion: @escaping ([String: Any]?, Error?) -> Void
    ) {
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
        self.isCompleted = false

        // Initialize Braintree clients
        braintreeClient = BTAPIClient(authorization: clientToken)
        applePayClient = BTApplePayClient(apiClient: braintreeClient!)
        dataCollector = BTDataCollector(apiClient: braintreeClient!)

        // Check if Apple Pay is available
        guard PKPaymentAuthorizationController.canMakePayments() else {
            completion(nil, NSError(domain: "ApplePayError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Apple Pay is not available on this device"]))
            return
        }

        // Create payment request
        let paymentRequest = PKPaymentRequest()
        paymentRequest.merchantIdentifier = merchantIdentifier
         paymentRequest.supportedNetworks = [.visa, .masterCard, .amex, .discover]
        paymentRequest.merchantCapabilities = .capability3DS
        paymentRequest.countryCode = countryCode
        paymentRequest.currencyCode = currencyCode

        // Set required billing and shipping contact fields
        paymentRequest.requiredBillingContactFields = [.postalAddress, .name]
        paymentRequest.requiredShippingContactFields = [.phoneNumber, .emailAddress]

        // Create payment summary items
        let amountDecimal = NSDecimalNumber(string: amount) ?? NSDecimalNumber.zero
        let paymentItem = PKPaymentSummaryItem(label: appleMerchantName!, amount: amountDecimal)
        paymentRequest.paymentSummaryItems = [paymentItem]

        // Create and present payment authorization controller
        paymentController = PKPaymentAuthorizationController(paymentRequest: paymentRequest)
        paymentController?.delegate = self
        paymentController?.present { presented in
            if !presented {
                completion(nil, NSError(domain: "ApplePayError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to present Apple Pay"]))
            }
        }
    }

    private func collectDeviceData() {
        dataCollector?.collectDeviceData { deviceData, error in
            if let error = error {
                print("Error collecting device data: \(error)")
            }
        }
    }

    private func tokenizeApplePayPayment(_ payment: PKPayment) {
        guard let applePayClient = applePayClient else {
            callCompletionHandler(.failure(NSError(domain: "ApplePayError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Apple Pay client not initialized"])))
            return
        }
        applePayClient.tokenize(payment) { [weak self] tokenizedPayment, error in

            guard let self = self else { return }

            if let error = error {
                self.callCompletionHandler(.failure(error))
                return
            }

            guard let tokenizedPayment = tokenizedPayment else {
                self.callCompletionHandler(.failure(NSError(domain: "ApplePayError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to tokenize Apple Pay payment"])))
                return
            }

            // Collect device data
            self.dataCollector?.collectDeviceData { deviceData, error in
                var result: [String: Any] = [
                    "cancelled": false,
                    "nonce": tokenizedPayment.nonce,
                    "type": tokenizedPayment.type ?? "Unknown",
                    "localizedDescription": tokenizedPayment.description
                ]

                if let deviceData = deviceData {
                    result["deviceData"] = deviceData
                }

                // Add Apple Pay specific contact information
                var applePayData: [String: Any] = [:]

                // Billing contact
                if let billingContact = payment.billingContact {
                    applePayData["billingContact"] = self.formatContact(billingContact)
                }

                // Shipping contact
                if let shippingContact = payment.shippingContact {
                    applePayData["shippingContact"] = self.formatContact(shippingContact)
                }

                result["applePay"] = applePayData

                self.callCompletionHandler(.success(result))
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
        switch result {
        case .success(let data):
            completionHandler!(data, nil)
        case .failure(let error):
            completionHandler!(nil, error)
        }
    }
}

// MARK: - PKPaymentAuthorizationControllerDelegate
extension SMFCapacitorBraintreePlugin: PKPaymentAuthorizationControllerDelegate {

    public func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        // Tokenize the payment
        tokenizeApplePayPayment(payment)
        completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
    }

    public func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss()
        // If we haven't called the completion handler yet, it means the user cancelled
        if !isCompleted {
            handlePaymentCancellation()
        }
    }
}
