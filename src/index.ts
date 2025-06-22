import { registerPlugin } from '@capacitor/core';

import type { SMFCapacitorBraintreePluginPlugin } from './definitions';

const SMFCapacitorBraintreePlugin = registerPlugin<SMFCapacitorBraintreePluginPlugin>('SMFCapacitorBraintreePlugin', {});

export * from './definitions';
export { SMFCapacitorBraintreePlugin };
