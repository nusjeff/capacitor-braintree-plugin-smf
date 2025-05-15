package com.smf.capator.braintree.plugin;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

@CapacitorPlugin(name = "SMFCapacitorBraintreePlugin")
public class SMFCapacitorBraintreePluginPlugin extends Plugin {

    private SMFCapacitorBraintreePlugin implementation = new SMFCapacitorBraintreePlugin();

    @PluginMethod
    public void echo(PluginCall call) {
        String value = call.getString("value");

        JSObject ret = new JSObject();
        ret.put("value", implementation.echo(value));
        call.resolve(ret);
    }
}
