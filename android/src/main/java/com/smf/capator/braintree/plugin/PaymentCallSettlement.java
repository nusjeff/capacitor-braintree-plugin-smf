package com.smf.capator.braintree.plugin;

import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

final class PaymentCallSettlement {

    private final AtomicBoolean settled = new AtomicBoolean(false);
    private final AtomicInteger callbackSequence = new AtomicInteger(0);

    boolean trySettle() {
        return settled.compareAndSet(false, true);
    }

    boolean isSettled() {
        return settled.get();
    }

    int nextCallbackSequence() {
        return callbackSequence.incrementAndGet();
    }
}
