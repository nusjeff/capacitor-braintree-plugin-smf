package com.smf.capator.braintree.plugin;

import androidx.annotation.NonNull;
import androidx.fragment.app.FragmentActivity;

import com.braintreepayments.api.core.PostalAddress;
import com.braintreepayments.api.datacollector.DataCollectorCallback;
import com.braintreepayments.api.datacollector.DataCollectorRequest;
import com.braintreepayments.api.datacollector.DataCollectorResult;
import com.braintreepayments.api.googlepay.GooglePayCardNonce;
import com.braintreepayments.api.googlepay.GooglePayClient;
import com.braintreepayments.api.googlepay.GooglePayLauncher;
import com.braintreepayments.api.googlepay.GooglePayLauncherCallback;
import com.braintreepayments.api.googlepay.GooglePayPaymentAuthRequest;
import com.braintreepayments.api.googlepay.GooglePayPaymentAuthRequestCallback;
import com.braintreepayments.api.googlepay.GooglePayPaymentAuthResult;
import com.braintreepayments.api.googlepay.GooglePayRequest;
import com.braintreepayments.api.googlepay.GooglePayResult;
import com.braintreepayments.api.googlepay.GooglePayTokenizeCallback;
import com.braintreepayments.api.googlepay.GooglePayTotalPriceStatus;
import com.braintreepayments.api.threedsecure.ThreeDSecureAdditionalInformation;
import com.braintreepayments.api.threedsecure.ThreeDSecureClient;
import com.braintreepayments.api.threedsecure.ThreeDSecureLauncher;
import com.braintreepayments.api.threedsecure.ThreeDSecureLauncherCallback;
import com.braintreepayments.api.threedsecure.ThreeDSecureNonce;
import com.braintreepayments.api.threedsecure.ThreeDSecurePaymentAuthRequest;
import com.braintreepayments.api.threedsecure.ThreeDSecurePaymentAuthResult;
import com.braintreepayments.api.threedsecure.ThreeDSecurePostalAddress;
import com.braintreepayments.api.threedsecure.ThreeDSecureRequest;
import com.braintreepayments.api.threedsecure.ThreeDSecureResult;
import com.braintreepayments.api.threedsecure.ThreeDSecureTokenizeCallback;
import com.getcapacitor.Bridge;
import com.getcapacitor.JSObject;
import com.getcapacitor.Logger;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.braintreepayments.api.datacollector.DataCollector;


@CapacitorPlugin(name = "SMFCapacitorBraintreePlugin")
public class SMFCapacitorBraintreePluginPlugin extends Plugin {
    GooglePayLauncher googlePayLauncher;
    GooglePayClient googlePayClient;
    FragmentActivity activity;
    PluginCall pluginCall;
    ThreeDSecureClient threeDSecureClient;
    ThreeDSecureLauncher threeDSecureLauncher;
    GooglePayCardNonce gCardNonce;
    DataCollector dataCollector;
    String deviceData;

    @Override
    public void load() {
        Bridge bridge = this.getBridge();
        activity = bridge.getActivity();
        activity.runOnUiThread(() -> {
            googlePayLauncher = new GooglePayLauncher(activity, new GooglePayLauncherCallback() {
                @Override
                public void onGooglePayLauncherResult(@NonNull GooglePayPaymentAuthResult googlePayPaymentAuthResult) {
                    googlePayClient.tokenize(googlePayPaymentAuthResult, new GooglePayTokenizeCallback() {
                        @Override
                        public void onGooglePayResult(@NonNull GooglePayResult googlePayResult) {
                            if(googlePayResult instanceof GooglePayResult.Success) {
                                GooglePayCardNonce nonce = (GooglePayCardNonce) ((GooglePayResult.Success) googlePayResult).getNonce();
                                handleGooglePayNonce(nonce);
                            }
                        }
                    });
                    Logger.debug(googlePayPaymentAuthResult.toString());
                }
            });
            threeDSecureLauncher = new ThreeDSecureLauncher(activity, new ThreeDSecureLauncherCallback() {
                @Override
                public void onThreeDSecurePaymentAuthResult(@NonNull ThreeDSecurePaymentAuthResult threeDSecurePaymentAuthResult) {
                    threeDSecureClient.tokenize(threeDSecurePaymentAuthResult, new ThreeDSecureTokenizeCallback() {
                        @Override
                        public void onThreeDSecureResult(@NonNull ThreeDSecureResult threeDSecureResult) {
                            if (threeDSecureResult instanceof ThreeDSecureResult.Success) {
                                respondToPlugin(((ThreeDSecureResult.Success) threeDSecureResult).getNonce());
                            } else {
                                JSObject resultMap = new JSObject();
                                resultMap.put("cancelled", true);
                                pluginCall.resolve(resultMap);
                            }
                        }
                    });
                }
            });
        });
    }
    @PluginMethod
    public void requestGooglePayPayment(PluginCall call) {
        pluginCall = call;
        gCardNonce = null;
        String amount = call.getString("amount");
        String currencyCode = call.getString("currencyCode");
        String clientToken = call.getString("clientToken");
        dataCollector = new DataCollector(activity, clientToken);
        dataCollector.collectDeviceData(activity, new DataCollectorRequest(false), new DataCollectorCallback() {
            @Override
            public void onDataCollectorResult(@NonNull DataCollectorResult dataCollectorResult) {
                deviceData = ((DataCollectorResult.Success) dataCollectorResult).getDeviceData();
            }
        });
        GooglePayRequest googlePayRequest = new GooglePayRequest(currencyCode, amount, GooglePayTotalPriceStatus.TOTAL_PRICE_STATUS_FINAL);
        googlePayRequest.setBillingAddressRequired(true);

        googlePayClient = new GooglePayClient(activity, clientToken);
        googlePayClient.createPaymentAuthRequest(googlePayRequest, new GooglePayPaymentAuthRequestCallback() {
            @Override
            public void onGooglePayPaymentAuthRequest(@NonNull GooglePayPaymentAuthRequest googlePayPaymentAuthRequest) {
                if(googlePayPaymentAuthRequest instanceof GooglePayPaymentAuthRequest.ReadyToLaunch) {
                    googlePayLauncher.launch((GooglePayPaymentAuthRequest.ReadyToLaunch) googlePayPaymentAuthRequest);
                } else {
                    Logger.debug("PluginError");
                    pluginCall.reject("Cannot create payment auth request");
                }
            }
        });
    }

    private ThreeDSecureRequest build3DSRequest(PluginCall call) {
        ThreeDSecurePostalAddress address = new ThreeDSecurePostalAddress();
        address.setGivenName(call.getString("givenName"));
        address.setSurname(call.getString("surname"));
        address.setPhoneNumber(call.getString("phoneNumber"));
        address.setStreetAddress(call.getString("streetAddress"));
        address.setLocality(call.getString("locality"));
        address.setPostalCode(call.getString("postalCode"));
        address.setCountryCodeAlpha2(call.getString("countryCodeAlpha2"));

        ThreeDSecureAdditionalInformation additionalInformation = new ThreeDSecureAdditionalInformation();
        additionalInformation.setShippingAddress(address);

        ThreeDSecureRequest threeDSecureRequest = new ThreeDSecureRequest();
        threeDSecureRequest.setAmount(call.getString("amount"));
        threeDSecureRequest.setEmail(call.getString("email"));
        threeDSecureRequest.setBillingAddress(address);
        threeDSecureRequest.setAdditionalInformation(additionalInformation);

        return threeDSecureRequest;
    }

    private void handleGooglePayNonce(GooglePayCardNonce googlePayNonce) {
        gCardNonce = googlePayNonce;
        if (googlePayNonce.isNetworkTokenized()) {
            respondToPlugin(null);
            return;
        }

        ThreeDSecureRequest threeDSecureRequest = build3DSRequest(pluginCall);
        threeDSecureRequest.setNonce(googlePayNonce.getString());
        threeDSecureClient = new ThreeDSecureClient(activity, pluginCall.getString("clientToken"));
        threeDSecureClient.createPaymentAuthRequest(activity, threeDSecureRequest, threeDSecurePaymentAuthRequest -> {
            if (threeDSecurePaymentAuthRequest instanceof ThreeDSecurePaymentAuthRequest.ReadyToLaunch) {
                threeDSecureLauncher.launch((ThreeDSecurePaymentAuthRequest.ReadyToLaunch)threeDSecurePaymentAuthRequest);
            }
        });

    }

    private void respondToPlugin(ThreeDSecureNonce threeDNonce) {
        JSObject resultMap = new JSObject();
        resultMap.put("cancelled", false);
        resultMap.put("nonce", threeDNonce == null ? gCardNonce.getString() : threeDNonce.getString());
        resultMap.put("deviceData", deviceData);
        JSObject innerMap = new JSObject();
        //In network tokenized card case, no tokenized card information returned but this is a Raileasy's required field so I put the nonce here to test if it works
        innerMap.put("token", threeDNonce != null ? threeDNonce.toString() : gCardNonce.toString());

        innerMap.put("lastTwo", gCardNonce.getLastTwo());
        innerMap.put("email", gCardNonce.getEmail());
        innerMap.put("network", gCardNonce.getCardType());
        innerMap.put("type", gCardNonce.getCardType());
        innerMap.put("billingAddress", formatAddress(gCardNonce.getBillingAddress()));
        innerMap.put("shippingAddress", formatAddress(gCardNonce.getShippingAddress()));
        resultMap.put("googlePay", innerMap);
        resultMap.put("localizedDescription", "Android Pay");

        pluginCall.resolve(resultMap);
    }

    private JSObject formatAddress(PostalAddress address) {
        JSObject addressMap = new JSObject();
        addressMap.put("name", address.getRecipientName());
        addressMap.put("address1", address.getStreetAddress());
        addressMap.put("address2", address.getExtendedAddress());
        addressMap.put("locality", address.getLocality());
        addressMap.put("administrativeArea", address.getRegion());
        addressMap.put("postalCode", address.getPostalCode());
        addressMap.put("countryCode", address.getCountryCodeAlpha2());
        return addressMap;
    }
}
