import Foundation
import Braintree

@objc public class SMFCapacitorBraintreePlugin: NSObject {
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
        guard let apiClient = BTAPIClient(authorization: clientToken) else {
            completion(nil, NSError(domain: "ThreeDSecureError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid client token"]))
            return
        }

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
        let threeDSClient = BTThreeDSecureClient(apiClient: apiClient)
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

 }

extension SMFCapacitorBraintreePlugin: BTThreeDSecureRequestDelegate {
    public func onLookupComplete(_ request: BTThreeDSecureRequest, lookupResult result: BTThreeDSecureResult, next: @escaping () -> Void) {
        next()
    }
}
