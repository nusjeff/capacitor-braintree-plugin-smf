import { WebPlugin } from '@capacitor/core';

import type { SMFCapacitorBraintreePluginPlugin } from './definitions';

export class SMFCapacitorBraintreePluginWeb extends WebPlugin implements SMFCapacitorBraintreePluginPlugin {
  async echo(options: { value: string }): Promise<{ value: string }> {
    console.log('ECHO', options);
    return options;
  }
}
