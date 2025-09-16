# capacitor-braintree-plugin-smf

Integrate Braintree

## Install

```bash
npm install capacitor-braintree-plugin-smf
npx cap sync
```

## API

<docgen-index>

* [`requestGooglePayPayment(...)`](#requestgooglepaypayment)
* [`requestApplePayPayment(...)`](#requestapplepaypayment)
* [`perform3DSecureVerification(...)`](#perform3dsecureverification)
* [Interfaces](#interfaces)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

### requestGooglePayPayment(...)

```typescript
requestGooglePayPayment(options: { amount: string; currencyCode: string; }) => Promise<any>
```

| Param         | Type                                                   |
| ------------- | ------------------------------------------------------ |
| **`options`** | <code>{ amount: string; currencyCode: string; }</code> |

**Returns:** <code>Promise&lt;any&gt;</code>

--------------------


### requestApplePayPayment(...)

```typescript
requestApplePayPayment(options: { amount: string; currencyCode: string; clientToken: string; appleMerchantId?: string; countryCodeAlpha2?: string; givenName?: string; surname?: string; email?: string; postalCode?: string; appleMerchantName?: string; }) => Promise<any>
```

Request Apple Pay payment using Braintree iOS SDK

| Param         | Type                                                                                                                                                                                                                                     | Description                                                                       |
| ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| **`options`** | <code>{ amount: string; currencyCode: string; clientToken: string; appleMerchantId?: string; countryCodeAlpha2?: string; givenName?: string; surname?: string; email?: string; postalCode?: string; appleMerchantName?: string; }</code> | Payment options including amount, currency, client token, and contact information |

**Returns:** <code>Promise&lt;any&gt;</code>

--------------------


### perform3DSecureVerification(...)

```typescript
perform3DSecureVerification(options: { nonce: string; clientToken: string; amount: string; bin: string; challengeRequested?: boolean; collectDeviceData?: boolean; exemptionRequested?: boolean; email?: string; mobilePhoneNumber?: string; billingAddress?: ThreeDSecureBillingAddress; additionalInformation?: ThreeDSecureAdditionalInformation; }) => Promise<{ nonce: string; type: string; description: string; binData: ThreeDSecureBinData; liabilityShiftPossible: boolean; liabilityShifted: boolean; threeDSecureInfo: ThreeDSecureInfo; }>
```

iOS only. Perform 3D Secure verification on a card nonce.

| Param         | Type                                                                                                                                                                                                                                                                                                                                                                                                                      |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`options`** | <code>{ nonce: string; clientToken: string; amount: string; bin: string; challengeRequested?: boolean; collectDeviceData?: boolean; exemptionRequested?: boolean; email?: string; mobilePhoneNumber?: string; billingAddress?: <a href="#threedsecurebillingaddress">ThreeDSecureBillingAddress</a>; additionalInformation?: <a href="#threedsecureadditionalinformation">ThreeDSecureAdditionalInformation</a>; }</code> |

**Returns:** <code>Promise&lt;{ nonce: string; type: string; description: string; binData: <a href="#threedsecurebindata">ThreeDSecureBinData</a>; liabilityShiftPossible: boolean; liabilityShifted: boolean; threeDSecureInfo: <a href="#threedsecureinfo">ThreeDSecureInfo</a>; }&gt;</code>

--------------------


### Interfaces


#### ThreeDSecureBinData

| Prop                    | Type                |
| ----------------------- | ------------------- |
| **`prepaid`**           | <code>string</code> |
| **`healthcare`**        | <code>string</code> |
| **`debit`**             | <code>string</code> |
| **`durbinRegulated`**   | <code>string</code> |
| **`commercial`**        | <code>string</code> |
| **`payroll`**           | <code>string</code> |
| **`issuingBank`**       | <code>string</code> |
| **`countryOfIssuance`** | <code>string</code> |
| **`productId`**         | <code>string</code> |


#### ThreeDSecureInfo

| Prop                               | Type                 |
| ---------------------------------- | -------------------- |
| **`liabilityShiftPossible`**       | <code>boolean</code> |
| **`liabilityShifted`**             | <code>boolean</code> |
| **`cavv`**                         | <code>string</code>  |
| **`xid`**                          | <code>string</code>  |
| **`dsTransactionId`**              | <code>string</code>  |
| **`threeDSecureVersion`**          | <code>string</code>  |
| **`eciFlag`**                      | <code>string</code>  |
| **`threeDSecureAuthenticationId`** | <code>string</code>  |


#### ThreeDSecureBillingAddress

| Prop                    | Type                |
| ----------------------- | ------------------- |
| **`givenName`**         | <code>string</code> |
| **`surname`**           | <code>string</code> |
| **`phoneNumber`**       | <code>string</code> |
| **`streetAddress`**     | <code>string</code> |
| **`extendedAddress`**   | <code>string</code> |
| **`locality`**          | <code>string</code> |
| **`region`**            | <code>string</code> |
| **`postalCode`**        | <code>string</code> |
| **`countryCodeAlpha2`** | <code>string</code> |


#### ThreeDSecureAdditionalInformation

| Prop                                | Type                                                                              |
| ----------------------------------- | --------------------------------------------------------------------------------- |
| **`shippingAddress`**               | <code><a href="#threedsecurebillingaddress">ThreeDSecureBillingAddress</a></code> |
| **`shippingMethodIndicator`**       | <code>string</code>                                                               |
| **`productCode`**                   | <code>string</code>                                                               |
| **`deliveryTimeframe`**             | <code>string</code>                                                               |
| **`deliveryEmail`**                 | <code>string</code>                                                               |
| **`reorderIndicator`**              | <code>string</code>                                                               |
| **`preorderIndicator`**             | <code>string</code>                                                               |
| **`preorderDate`**                  | <code>string</code>                                                               |
| **`giftCardAmount`**                | <code>string</code>                                                               |
| **`giftCardCurrencyCode`**          | <code>string</code>                                                               |
| **`giftCardCount`**                 | <code>string</code>                                                               |
| **`accountAgeIndicator`**           | <code>string</code>                                                               |
| **`accountCreateDate`**             | <code>string</code>                                                               |
| **`accountChangeIndicator`**        | <code>string</code>                                                               |
| **`accountChangeDate`**             | <code>string</code>                                                               |
| **`accountPwdChangeIndicator`**     | <code>string</code>                                                               |
| **`accountPwdChangeDate`**          | <code>string</code>                                                               |
| **`shippingAddressUsageIndicator`** | <code>string</code>                                                               |
| **`shippingAddressUsageDate`**      | <code>string</code>                                                               |
| **`transactionCountDay`**           | <code>string</code>                                                               |
| **`transactionCountYear`**          | <code>string</code>                                                               |
| **`addCardAttempts`**               | <code>string</code>                                                               |
| **`accountPurchases`**              | <code>string</code>                                                               |
| **`fraudActivity`**                 | <code>string</code>                                                               |
| **`shippingNameIndicator`**         | <code>string</code>                                                               |
| **`paymentAccountIndicator`**       | <code>string</code>                                                               |
| **`paymentAccountAge`**             | <code>string</code>                                                               |
| **`addressMatch`**                  | <code>string</code>                                                               |
| **`installment`**                   | <code>string</code>                                                               |
| **`recurringEnd`**                  | <code>string</code>                                                               |
| **`recurringFrequency`**            | <code>string</code>                                                               |

</docgen-api>
