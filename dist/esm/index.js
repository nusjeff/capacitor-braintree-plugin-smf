import { registerPlugin } from '@capacitor/core';
const SMFCapacitorBraintreePlugin = registerPlugin('SMFCapacitorBraintreePlugin', {
    web: () => import('./web').then((m) => new m.SMFCapacitorBraintreePluginWeb()),
});
export * from './definitions';
export { SMFCapacitorBraintreePlugin };
//# sourceMappingURL=index.js.map