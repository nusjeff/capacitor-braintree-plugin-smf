package com.smf.capator.braintree.plugin;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class PaymentCallSettlementTest {

    @Test
    public void settlesExactlyOnce() {
        PaymentCallSettlement settlement = new PaymentCallSettlement();

        assertTrue(settlement.trySettle());
        assertTrue(settlement.isSettled());
        assertFalse(settlement.trySettle());
    }

    @Test
    public void numbersCallbacksInArrivalOrder() {
        PaymentCallSettlement settlement = new PaymentCallSettlement();

        assertEquals(1, settlement.nextCallbackSequence());
        assertEquals(2, settlement.nextCallbackSequence());
    }
}
