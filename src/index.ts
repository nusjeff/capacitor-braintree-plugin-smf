import { registerPlugin } from '@capacitor/core';

import type { SMFCapacitorBraintreePluginPlugin } from './definitions';

const SMFCapacitorBraintreePlugin = registerPlugin<SMFCapacitorBraintreePluginPlugin>('SMFCapacitorBraintreePlugin', {
  web: () => import('./web').then((m) => new m.SMFCapacitorBraintreePluginWeb()),
});

export * from './definitions';
export { SMFCapacitorBraintreePlugin };
