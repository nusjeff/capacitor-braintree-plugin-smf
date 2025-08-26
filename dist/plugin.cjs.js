'use strict';

var core = require('@capacitor/core');

const SMFCapacitorBraintreePlugin = core.registerPlugin('SMFCapacitorBraintreePlugin', {
    web: () => Promise.resolve().then(function () { return web; }).then((m) => new m.SMFCapacitorBraintreePluginWeb()),
});

class SMFCapacitorBraintreePluginWeb extends core.WebPlugin {
    async echo(options) {
        console.log('ECHO', options);
        return options;
    }
}

var web = /*#__PURE__*/Object.freeze({
    __proto__: null,
    SMFCapacitorBraintreePluginWeb: SMFCapacitorBraintreePluginWeb
});

exports.SMFCapacitorBraintreePlugin = SMFCapacitorBraintreePlugin;
//# sourceMappingURL=plugin.cjs.js.map
