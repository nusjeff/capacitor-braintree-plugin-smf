export interface SMFCapacitorBraintreePluginPlugin {
    requestGooglePayPayment(options: {
        amount: string;
        currencyCode: string;
    }): Promise<any>;
    /**
     * Request Apple Pay payment using Braintree iOS SDK
     * @param options Payment options including amount, currency, client token, and contact information
     * @returns Promise that resolves with payment result or rejects with error
     *
     * @example
     * ```typescript
     * const result = await SMFCapacitorBraintreePlugin.requestApplePayPayment({
     *   amount: "10.00",
     *   currencyCode: "USD",
     *   clientToken: "your_braintree_client_token",
     *   appleMerchantId: "merchant.com.yourcompany.yourapp",
     *   countryCodeAlpha2: "US",
     *   givenName: "Jeff",
     *   surname: "Trinh",
     *   email: "jeff@example.com",
     *   postalCode: "12345",
     *   appleMerchantName: "SplitMyFare"
     * });
     *
     * // Result format:
     * // {
     * //   "applePay": {
     * //     "billingContact": {
     * //       "administrativeArea": "AL",
     * //       "subAdministrativeArea": "",
     * //       "countryCode": "US",
     * //       "familyName": "Tr",
     * //       "addressLines": ["Sss\nAsj"],
     * //       "locality": "HCM",
     * //       "subLocality": "",
     * //       "givenName": "Jeff",
     * //       "country": "United States",
     * //       "postalCode": "12345"
     * //     },
     * //     "shippingContact": {
     * //       "familyName": "",
     * //       "givenName": "",
     * //       "phoneNumber": "+84983111111",
     * //       "emailAddress": "jeff@nustechnology.com"
     * //     }
     * //   },
     * //   "cancelled": false,
     * //   "deviceData": "{\"correlation_id\":\"c1f83fb505bd44d79c54b20010ea17cc\"}",
     * //   "nonce": "7d17b38c-b908-10e4-1714-a994d93fe896",
     * //   "localizedDescription": "<BTApplePayCardNonce: 0x600000dbc030>",
     * //   "type": "Visa"
     * // }
     * ```
     */
    requestApplePayPayment(options: {
        amount: string;
        currencyCode: string;
        clientToken: string;
        appleMerchantId?: string;
        countryCodeAlpha2?: string;
        givenName?: string;
        surname?: string;
        email?: string;
        postalCode?: string;
        appleMerchantName?: string;
    }): Promise<any>;
    /**
     * iOS only. Perform 3D Secure verification on a card nonce.
     */
    perform3DSecureVerification(options: {
        nonce: string;
        clientToken: string;
        amount: string;
        bin: string;
        challengeRequested?: boolean;
        collectDeviceData?: boolean;
        exemptionRequested?: boolean;
        email?: string;
        mobilePhoneNumber?: string;
        billingAddress?: ThreeDSecureBillingAddress;
        additionalInformation?: ThreeDSecureAdditionalInformation;
    }): Promise<{
        nonce: string;
        type: string;
        description: string;
        binData: ThreeDSecureBinData;
        liabilityShiftPossible: boolean;
        liabilityShifted: boolean;
        threeDSecureInfo: ThreeDSecureInfo;
    }>;
}
export interface ThreeDSecureBillingAddress {
    givenName?: string;
    surname?: string;
    phoneNumber?: string;
    streetAddress?: string;
    extendedAddress?: string;
    locality?: string;
    region?: string;
    postalCode?: string;
    countryCodeAlpha2?: string;
}
export interface ThreeDSecureAdditionalInformation {
    shippingAddress?: ThreeDSecureBillingAddress;
    shippingMethodIndicator?: string;
    productCode?: string;
    deliveryTimeframe?: string;
    deliveryEmail?: string;
    reorderIndicator?: string;
    preorderIndicator?: string;
    preorderDate?: string;
    giftCardAmount?: string;
    giftCardCurrencyCode?: string;
    giftCardCount?: string;
    accountAgeIndicator?: string;
    accountCreateDate?: string;
    accountChangeIndicator?: string;
    accountChangeDate?: string;
    accountPwdChangeIndicator?: string;
    accountPwdChangeDate?: string;
    shippingAddressUsageIndicator?: string;
    shippingAddressUsageDate?: string;
    transactionCountDay?: string;
    transactionCountYear?: string;
    addCardAttempts?: string;
    accountPurchases?: string;
    fraudActivity?: string;
    shippingNameIndicator?: string;
    paymentAccountIndicator?: string;
    paymentAccountAge?: string;
    addressMatch?: string;
    installment?: string;
    recurringEnd?: string;
    recurringFrequency?: string;
}
export interface ThreeDSecureBinData {
    prepaid?: string;
    healthcare?: string;
    debit?: string;
    durbinRegulated?: string;
    commercial?: string;
    payroll?: string;
    issuingBank?: string;
    countryOfIssuance?: string;
    productId?: string;
}
export interface ThreeDSecureInfo {
    liabilityShiftPossible: boolean;
    liabilityShifted: boolean;
    cavv: string;
    xid: string;
    dsTransactionId: string;
    threeDSecureVersion: string;
    eciFlag: string;
    threeDSecureAuthenticationId: string;
}
