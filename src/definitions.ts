export interface SMFCapacitorBraintreePluginPlugin {
  requestGooglePayPayment(options: { amount: string, currencyCode: string }): Promise<any>;
}
