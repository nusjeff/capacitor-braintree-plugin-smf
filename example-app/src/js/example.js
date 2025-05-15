import { SMFCapacitorBraintreePlugin } from 'capacitor-braintree-plugin-smf';

window.testEcho = () => {
    const inputValue = document.getElementById("echoInput").value;
    SMFCapacitorBraintreePlugin.echo({ value: inputValue })
}
