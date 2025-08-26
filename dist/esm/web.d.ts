import { WebPlugin } from '@capacitor/core';
import type { SMFCapacitorBraintreePluginPlugin } from './definitions';
export declare class SMFCapacitorBraintreePluginWeb extends WebPlugin implements SMFCapacitorBraintreePluginPlugin {
    echo(options: {
        value: string;
    }): Promise<{
        value: string;
    }>;
}
