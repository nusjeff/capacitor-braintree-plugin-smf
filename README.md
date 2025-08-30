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

</docgen-api>
