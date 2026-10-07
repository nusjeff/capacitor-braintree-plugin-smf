import { SMFCapacitorBraintreePlugin } from 'capacitor-braintree-plugin-smf';

// Example of using Apple Pay
async function requestApplePay() {
  try {
    const result = await SMFCapacitorBraintreePlugin.requestApplePayPayment({
      amount: "10.00",
      currencyCode: "USD",
      clientToken: "your_braintree_client_token_here",
      appleMerchantId: "merchant.com.yourcompany.yourapp",
      countryCodeAlpha2: "US",
      givenName: "Jeff",
      surname: "Trinh",
      email: "jeff@example.com",
      postalCode: "12345",
      appleMerchantName: "SplitMyFare"
    });

    if (result.cancelled) {
      console.log("Payment was cancelled by user");
      return;
    }

    console.log("Payment successful!");
    console.log("Nonce:", result.nonce);
    console.log("Card type:", result.type);
    console.log("Device data:", result.deviceData);
    console.log("Description:", result.localizedDescription);

    // Access Apple Pay specific contact information
    if (result.applePay) {
      console.log("Billing contact:", result.applePay.billingContact);
      console.log("Shipping contact:", result.applePay.shippingContact);
    }

    // Send the nonce and device data to your server
    await sendToServer(result.nonce, result.deviceData, result.applePay);

  } catch (error) {
    console.error("Apple Pay failed:", error);
  }
}

// Example of using Google Pay (existing functionality)
async function requestGooglePay() {
  try {
    const result = await SMFCapacitorBraintreePlugin.requestGooglePayPayment({
      amount: "10.00",
      currencyCode: "USD"
    });

    console.log("Google Pay result:", result);

  } catch (error) {
    console.error("Google Pay failed:", error);
  }
}

// Helper function to send data to server
async function sendToServer(nonce, deviceData, applePayData) {
  try {
    const response = await fetch('/api/process-payment', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        nonce: nonce,
        deviceData: deviceData,
        applePay: applePayData,
        amount: "10.00",
        currencyCode: "USD"
      })
    });

    const result = await response.json();
    console.log("Server response:", result);

  } catch (error) {
    console.error("Failed to send to server:", error);
  }
}

// Add event listeners
document.addEventListener('DOMContentLoaded', function() {
  const applePayButton = document.getElementById('apple-pay-button');
  const googlePayButton = document.getElementById('google-pay-button');

  if (applePayButton) {
    applePayButton.addEventListener('click', requestApplePay);
  }

  if (googlePayButton) {
    googlePayButton.addEventListener('click', requestGooglePay);
  }
});
