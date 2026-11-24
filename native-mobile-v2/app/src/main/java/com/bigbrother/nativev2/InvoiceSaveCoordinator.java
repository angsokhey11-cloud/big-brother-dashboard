package com.bigbrother.nativev2;

/**
 * Transport-independent atomic-save state machine. No real transport is wired.
 * A single frozen payload may be sent only after durable recording.
 * Unknown outcomes retain the record, even when verification is not-found.
 */
final class InvoiceSaveCoordinator {
    interface Journal {
        void begin(String id,String no,String frozen)throws Exception;
        void acknowledge(String id)throws Exception;
    }
    interface Transport {
        void send(String endpoint,String frozen)throws Exception;
        boolean verify(String id)throws Exception;
    }
    enum Outcome { CONFIRMED, UNRESOLVED }
    static Outcome execute(Journal journal,Transport transport,String endpoint,String id,String no,String frozen)throws Exception{
        if(!java.util.Arrays.asList("bb_sales_save_invoice_bundle","bb_sales_save_invoice_split_payment","bb_sales_save_invoice_multi_bank_v1").contains(endpoint)
            ||id.trim().isEmpty()||no.trim().isEmpty()||frozen.trim().isEmpty())throw new IllegalArgumentException("Incomplete frozen request.");
        journal.begin(id,no,endpoint+"\n"+frozen);
        try{transport.send(endpoint,frozen);}catch(Exception ambiguous){/* Verify, never resend. */}
        boolean found;
        try{found=transport.verify(id);}catch(Exception unavailable){return Outcome.UNRESOLVED;}
        if(!found)return Outcome.UNRESOLVED;
        try{journal.acknowledge(id);}catch(Exception unavailable){return Outcome.UNRESOLVED;}
        return Outcome.CONFIRMED;
    }
}
