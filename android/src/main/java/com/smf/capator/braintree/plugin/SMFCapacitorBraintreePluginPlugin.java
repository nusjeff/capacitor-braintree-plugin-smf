package com.smf.capator.braintree.plugin;

import androidx.annotation.NonNull;
import androidx.fragment.app.FragmentActivity;
import com.braintreepayments.api.core.PostalAddress;
import com.braintreepayments.api.datacollector.DataCollector;
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
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import java.util.UUID;

@CapacitorPlugin(name = "SMFCapacitorBraintreePlugin")
public class SMFCapacitorBraintreePluginPlugin extends Plugin {

    private static final String GOOGLE_PAY_PROGRESS_EVENT = "googlePayProgress";

    private GooglePayLauncher googlePayLauncher;
    private FragmentActivity activity;
    private ThreeDSecureLauncher threeDSecureLauncher;
    private GooglePayAttempt activeAttempt;
    private GooglePayAttempt googlePayLaunchAttempt;
    private GooglePayAttempt threeDSecureLaunchAttempt;

    private static final class GooglePayAttempt {

        private final PluginCall call;
        private final String attemptId;
        private final PaymentCallSettlement settlement = new PaymentCallSettlement();
        private final GooglePayClient googlePayClient;
        private GooglePayCardNonce cardNonce;
        private ThreeDSecureClient threeDSecureClient;
        private String deviceData;

        private GooglePayAttempt(PluginCall call, String attemptId, GooglePayClient googlePayClient) {
            this.call = call;
            this.attemptId = attemptId;
            this.googlePayClient = googlePayClient;
        }
    }

    @Override
    public void load() {
        Bridge bridge = this.getBridge();
        activity = bridge.getActivity();
        activity.runOnUiThread(() -> {
            googlePayLauncher = new GooglePayLauncher(
                activity,
                new GooglePayLauncherCallback() {
                    @Override
                    public void onGooglePayLauncherResult(@NonNull GooglePayPaymentAuthResult googlePayPaymentAuthResult) {
                        GooglePayAttempt attempt = googlePayLaunchAttempt;
                        if (attempt == null) {
                            return;
                        }
                        notifyGooglePayProgress(attempt, "google_pay_auth_result_received", null);
                        attempt.googlePayClient.tokenize(
                            googlePayPaymentAuthResult,
                            new GooglePayTokenizeCallback() {
                                @Override
                                public void onGooglePayResult(@NonNull GooglePayResult googlePayResult) {
                                    notifyResultReceived(attempt, "google_pay_tokenize_result", googlePayResult);
                                    if (googlePayResult instanceof GooglePayResult.Success) {
                                        GooglePayCardNonce nonce =
                                            (GooglePayCardNonce) ((GooglePayResult.Success) googlePayResult).getNonce();
                                        handleGooglePayNonce(attempt, nonce);
                                    } else if (googlePayResult instanceof GooglePayResult.Cancel) {
                                        settleCancelled(attempt, "google_pay_cancelled");
                                    } else if (googlePayResult instanceof GooglePayResult.Failure) {
                                        settleFailure(
                                            attempt,
                                            "GOOGLE_PAY_TOKENIZE_FAILED",
                                            ((GooglePayResult.Failure) googlePayResult).getError()
                                        );
                                    }
                                }
                            }
                        );
                    }
                }
            );
            threeDSecureLauncher = new ThreeDSecureLauncher(
                activity,
                new ThreeDSecureLauncherCallback() {
                    @Override
                    public void onThreeDSecurePaymentAuthResult(@NonNull ThreeDSecurePaymentAuthResult threeDSecurePaymentAuthResult) {
                        GooglePayAttempt attempt = threeDSecureLaunchAttempt;
                        if (attempt == null || attempt.threeDSecureClient == null) {
                            return;
                        }
                        notifyGooglePayProgress(attempt, "three_ds_auth_result_received", null);
                        attempt.threeDSecureClient.tokenize(
                            threeDSecurePaymentAuthResult,
                            new ThreeDSecureTokenizeCallback() {
                                @Override
                                public void onThreeDSecureResult(@NonNull ThreeDSecureResult threeDSecureResult) {
                                    notifyResultReceived(attempt, "three_ds_tokenize_result", threeDSecureResult);
                                    if (threeDSecureResult instanceof ThreeDSecureResult.Success) {
                                        respondToPlugin(attempt, ((ThreeDSecureResult.Success) threeDSecureResult).getNonce());
                                    } else if (threeDSecureResult instanceof ThreeDSecureResult.Cancel) {
                                        settleCancelled(attempt, "three_ds_cancelled");
                                    } else if (threeDSecureResult instanceof ThreeDSecureResult.Failure) {
                                        settleFailure(
                                            attempt,
                                            "THREE_DS_TOKENIZE_FAILED",
                                            ((ThreeDSecureResult.Failure) threeDSecureResult).getError()
                                        );
                                    }
                                }
                            }
                        );
                    }
                }
            );
        });
    }

    @PluginMethod
    public void requestGooglePayPayment(PluginCall call) {
        String amount = call.getString("amount");
        String currencyCode = call.getString("currencyCode");
        String clientToken = call.getString("clientToken");
        String attemptId = call.getString("attemptId");
        if (attemptId == null || attemptId.isEmpty()) {
            attemptId = UUID.randomUUID().toString();
        }

        GooglePayAttempt attempt;
        synchronized (this) {
            if (activeAttempt != null && !activeAttempt.settlement.isSettled()) {
                call.reject("A Google Pay payment is already in progress", "PAYMENT_IN_PROGRESS");
                return;
            }
            attempt = new GooglePayAttempt(call, attemptId, new GooglePayClient(activity, clientToken));
            activeAttempt = attempt;
        }

        notifyGooglePayProgress(attempt, "request_received", null);
        DataCollector dataCollector = new DataCollector(activity, clientToken);
        dataCollector.collectDeviceData(
            activity,
            new DataCollectorRequest(false),
            new DataCollectorCallback() {
                @Override
                public void onDataCollectorResult(@NonNull DataCollectorResult dataCollectorResult) {
                    if (dataCollectorResult instanceof DataCollectorResult.Success) {
                        attempt.deviceData = ((DataCollectorResult.Success) dataCollectorResult).getDeviceData();
                        JSObject details = new JSObject();
                        details.put("hasDeviceData", true);
                        notifyGooglePayProgress(attempt, "device_data_collected", details);
                    } else if (dataCollectorResult instanceof DataCollectorResult.Failure) {
                        notifyFailure(attempt, "device_data_collection_failed", "DEVICE_DATA_COLLECTION_FAILED");
                    }
                }
            }
        );
        GooglePayRequest googlePayRequest = new GooglePayRequest(
            currencyCode,
            amount,
            GooglePayTotalPriceStatus.TOTAL_PRICE_STATUS_FINAL,
            true
        );
        googlePayRequest.setBillingAddressRequired(true);

        attempt.googlePayClient.createPaymentAuthRequest(
            googlePayRequest,
            new GooglePayPaymentAuthRequestCallback() {
                @Override
                public void onGooglePayPaymentAuthRequest(@NonNull GooglePayPaymentAuthRequest googlePayPaymentAuthRequest) {
                    if (googlePayPaymentAuthRequest instanceof GooglePayPaymentAuthRequest.ReadyToLaunch) {
                        googlePayLaunchAttempt = attempt;
                        notifyGooglePayProgress(attempt, "google_pay_presented", null);
                        googlePayLauncher.launch((GooglePayPaymentAuthRequest.ReadyToLaunch) googlePayPaymentAuthRequest);
                    } else if (googlePayPaymentAuthRequest instanceof GooglePayPaymentAuthRequest.Failure) {
                        settleFailure(
                            attempt,
                            "GOOGLE_PAY_AUTH_REQUEST_FAILED",
                            ((GooglePayPaymentAuthRequest.Failure) googlePayPaymentAuthRequest).getError()
                        );
                    }
                }
            }
        );
    }

    private ThreeDSecurePostalAddress convertToThreeDSecureAddress(PostalAddress postalAddress) {
        ThreeDSecurePostalAddress address = new ThreeDSecurePostalAddress();
        address.setStreetAddress(postalAddress.getStreetAddress());
        address.setExtendedAddress(postalAddress.getExtendedAddress());
        address.setLocality(postalAddress.getLocality());
        address.setRegion(postalAddress.getRegion());
        address.setPostalCode(postalAddress.getPostalCode());
        address.setCountryCodeAlpha2(postalAddress.getCountryCodeAlpha2());
        return address;
    }

    private ThreeDSecureRequest build3DSRequest(PluginCall call, GooglePayCardNonce googlePayNonce) {
        ThreeDSecurePostalAddress address;

        if (googlePayNonce != null && googlePayNonce.getBillingAddress() != null) {
            // Use billing address from Google Pay
            address = convertToThreeDSecureAddress(googlePayNonce.getBillingAddress());

            // Set name from recipient name or fall back to call parameters
            String recipientName = googlePayNonce.getBillingAddress().getRecipientName();
            if (recipientName != null && !recipientName.isEmpty()) {
                // Split the name into given name and surname
                String[] nameParts = recipientName.split(" ", 2);
                address.setGivenName(nameParts.length > 0 ? nameParts[0] : "");
                address.setSurname(nameParts.length > 1 ? nameParts[1] : "");
            } else {
                // Fall back to call parameters if no recipient name
                address.setGivenName(call.getString("givenName"));
                address.setSurname(call.getString("surname"));
            }

            // Use phone number from call parameters since Google Pay doesn't provide it
            address.setPhoneNumber(call.getString("phoneNumber"));
        } else {
            // Fall back to original behavior using call parameters
            address = new ThreeDSecurePostalAddress();
            address.setGivenName(call.getString("givenName"));
            address.setSurname(call.getString("surname"));
            address.setPhoneNumber(call.getString("phoneNumber"));
            address.setStreetAddress(call.getString("streetAddress"));
            address.setLocality(call.getString("locality"));
            address.setPostalCode(call.getString("postalCode"));
            address.setCountryCodeAlpha2(call.getString("countryCodeAlpha2"));
        }

        ThreeDSecureAdditionalInformation additionalInformation = new ThreeDSecureAdditionalInformation();
        additionalInformation.setShippingAddress(address);

        ThreeDSecureRequest threeDSecureRequest = new ThreeDSecureRequest();
        threeDSecureRequest.setAmount(call.getString("amount"));
        threeDSecureRequest.setEmail(call.getString("email"));
        threeDSecureRequest.setBillingAddress(address);
        threeDSecureRequest.setAdditionalInformation(additionalInformation);

        return threeDSecureRequest;
    }

    private void handleGooglePayNonce(GooglePayAttempt attempt, GooglePayCardNonce googlePayNonce) {
        attempt.cardNonce = googlePayNonce;
        notifyGooglePayProgress(attempt, "google_pay_tokenized", null);
        if (googlePayNonce.isNetworkTokenized()) {
            respondToPlugin(attempt, null);
            return;
        }

        ThreeDSecureRequest threeDSecureRequest = build3DSRequest(attempt.call, googlePayNonce);
        threeDSecureRequest.setNonce(googlePayNonce.getString());
        attempt.threeDSecureClient = new ThreeDSecureClient(activity, attempt.call.getString("clientToken"));
        notifyGooglePayProgress(attempt, "three_ds_lookup_started", null);
        attempt.threeDSecureClient.createPaymentAuthRequest(activity, threeDSecureRequest, threeDSecurePaymentAuthRequest -> {
            if (threeDSecurePaymentAuthRequest instanceof ThreeDSecurePaymentAuthRequest.ReadyToLaunch) {
                threeDSecureLaunchAttempt = attempt;
                notifyGooglePayProgress(attempt, "three_ds_challenge_presented", null);
                threeDSecureLauncher.launch((ThreeDSecurePaymentAuthRequest.ReadyToLaunch) threeDSecurePaymentAuthRequest);
            } else if (threeDSecurePaymentAuthRequest instanceof ThreeDSecurePaymentAuthRequest.LaunchNotRequired) {
                ThreeDSecureNonce threeDSecureNonce =
                    ((ThreeDSecurePaymentAuthRequest.LaunchNotRequired) threeDSecurePaymentAuthRequest).getNonce();
                notifyGooglePayProgress(attempt, "three_ds_challenge_not_required", null);
                respondToPlugin(attempt, threeDSecureNonce);
            } else if (threeDSecurePaymentAuthRequest instanceof ThreeDSecurePaymentAuthRequest.Failure) {
                settleFailure(
                    attempt,
                    "THREE_DS_AUTH_REQUEST_FAILED",
                    ((ThreeDSecurePaymentAuthRequest.Failure) threeDSecurePaymentAuthRequest).getError()
                );
            }
        });
    }

    private void respondToPlugin(GooglePayAttempt attempt, ThreeDSecureNonce threeDNonce) {
        if (!attempt.settlement.trySettle()) {
            notifyDuplicateCallback(attempt, "success");
            return;
        }
        JSObject resultMap = new JSObject();
        resultMap.put("cancelled", false);
        resultMap.put("nonce", threeDNonce == null ? attempt.cardNonce.getString() : threeDNonce.getString());
        resultMap.put("deviceData", attempt.deviceData);
        JSObject innerMap = new JSObject();
        //In network tokenized card case, no tokenized card information returned but this is a Raileasy's required field so I put the nonce here to test if it works
        innerMap.put("token", threeDNonce != null ? threeDNonce.toString() : attempt.cardNonce.toString());

        innerMap.put("lastTwo", attempt.cardNonce.getLastTwo());
        innerMap.put("email", attempt.cardNonce.getEmail());
        innerMap.put("network", attempt.cardNonce.getCardType());
        innerMap.put("type", attempt.cardNonce.getCardType());
        innerMap.put("billingAddress", formatAddress(attempt.cardNonce.getBillingAddress()));
        innerMap.put("shippingAddress", formatAddress(attempt.cardNonce.getShippingAddress()));
        resultMap.put("googlePay", innerMap);
        resultMap.put("localizedDescription", "Android Pay");
        resultMap.put("emailAddress", attempt.cardNonce.getEmail());

        JSObject details = new JSObject();
        details.put("hasDeviceData", attempt.deviceData != null);
        notifyGooglePayProgress(attempt, "plugin_call_resolved", details);
        clearActiveAttempt(attempt);
        attempt.call.resolve(resultMap);
    }

    private void settleCancelled(GooglePayAttempt attempt, String step) {
        if (!attempt.settlement.trySettle()) {
            notifyDuplicateCallback(attempt, "cancel");
            return;
        }
        notifyGooglePayProgress(attempt, step, null);
        JSObject resultMap = new JSObject();
        resultMap.put("cancelled", true);
        clearActiveAttempt(attempt);
        attempt.call.resolve(resultMap);
    }

    private void settleFailure(GooglePayAttempt attempt, String errorCode, Exception error) {
        if (!attempt.settlement.trySettle()) {
            notifyDuplicateCallback(attempt, "failure");
            return;
        }
        notifyFailure(attempt, "plugin_call_rejected", errorCode);
        clearActiveAttempt(attempt);
        String message = error.getMessage() == null ? "Native payment failed" : error.getMessage();
        attempt.call.reject(message, errorCode, error);
    }

    private void notifyResultReceived(GooglePayAttempt attempt, String step, Object result) {
        JSObject details = new JSObject();
        details.put("callbackSequence", attempt.settlement.nextCallbackSequence());
        details.put("resultType", result.getClass().getSimpleName());
        notifyGooglePayProgress(attempt, step, details);
    }

    private void notifyFailure(GooglePayAttempt attempt, String step, String errorCode) {
        JSObject details = new JSObject();
        details.put("errorCode", errorCode);
        notifyGooglePayProgress(attempt, step, details);
    }

    private void notifyDuplicateCallback(GooglePayAttempt attempt, String resultType) {
        JSObject details = new JSObject();
        details.put("callbackSequence", attempt.settlement.nextCallbackSequence());
        details.put("resultType", resultType);
        notifyGooglePayProgress(attempt, "duplicate_callback_ignored", details);
    }

    private void notifyGooglePayProgress(GooglePayAttempt attempt, String step, JSObject details) {
        JSObject event = details == null ? new JSObject() : details;
        event.put("attemptId", attempt.attemptId);
        event.put("step", step);
        notifyListeners(GOOGLE_PAY_PROGRESS_EVENT, event);
    }

    private synchronized void clearActiveAttempt(GooglePayAttempt attempt) {
        if (activeAttempt == attempt) {
            activeAttempt = null;
        }
    }

    private JSObject formatAddress(PostalAddress address) {
        JSObject addressMap = new JSObject();
        if (address == null) {
            return addressMap;
        }
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
