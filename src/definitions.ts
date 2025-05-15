export interface SMFCapacitorBraintreePluginPlugin {
  echo(options: { value: string }): Promise<{ value: string }>;
}
