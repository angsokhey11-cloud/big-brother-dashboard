package com.bigbrother.nativev2;

import android.content.Context;
import android.content.SharedPreferences;
import org.json.JSONObject;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.io.IOException;

/** Future atomic save guard. Not called by any development submit path. Stores metadata, not customer or bank payload. */
final class InvoiceSaveJournal {
    private static final Object LOCK=new Object();
    private final SharedPreferences store;
    private final String key;
    InvoiceSaveJournal(Context context,String account)throws Exception{
        if(account==null||account.trim().isEmpty())throw new IOException("Account required");
        store=context.getApplicationContext().getSharedPreferences("bb_online_invoice_recovery_v1",Context.MODE_PRIVATE);
        key="account_"+digest(account);
    }
    static String digest(String data)throws Exception{
        byte[] hash=MessageDigest.getInstance("SHA-256").digest(data.getBytes(StandardCharsets.UTF_8));
        StringBuilder out=new StringBuilder();
        for(byte b:hash)out.append(String.format(java.util.Locale.ROOT,"%02x",b&255));
        return out.toString();
    }
    JSONObject pending()throws Exception{
        synchronized(LOCK){
            String raw=store.getString(key,null);
            if(raw==null)return null;
            JSONObject record=new JSONObject(raw);
            if(record.getString("invoiceId").isEmpty()||!record.getString("fingerprint").matches("[a-f0-9]{64}"))throw new IOException("Recovery record damaged. Admin reconciliation required.");
            return record;
        }
    }
    /** Call exactly once before transport; any existing record blocks new submission.
     * Fingerprint must be from the exact frozen serialized RPC arguments, including bank allocations. */
    void begin(String invoiceId,String invoiceNo,String frozenRpcArgs)throws Exception{
        synchronized(LOCK){
            if(pending()!=null)throw new IOException("Prior save unresolved. Verify original invoice first.");
            if(invoiceId.trim().isEmpty()||invoiceNo.trim().isEmpty()||frozenRpcArgs.trim().isEmpty())throw new IOException("Incomplete save metadata");
            JSONObject record=new JSONObject().put("invoiceId",invoiceId).put("invoiceNo",invoiceNo)
                .put("fingerprint",digest(frozenRpcArgs)).put("createdAt",System.currentTimeMillis());
            if(!store.edit().putString(key,record.toString()).commit())throw new IOException("Recovery storage unavailable; do not submit.");
        }
    }
    /**
     * Adapter for the tested coordinator. A verifier must be the authoritative
     * server and return true only for the exact recorded ID. No live transport
     * is currently connected to this adapter.
     */
    InvoiceSaveCoordinator.Journal coordinatorJournal(){
        return new InvoiceSaveCoordinator.Journal(){
            public void begin(String id,String no,String frozen)throws Exception{InvoiceSaveJournal.this.begin(id,no,frozen);}
            public void acknowledge(String id)throws Exception{
                synchronized(LOCK){
                    JSONObject record=pending();
                    if(record==null||!id.equals(record.getString("invoiceId")))throw new IOException("Recovery identity mismatch.");
                    if(!store.edit().remove(key).commit())throw new IOException("Could not clear recovery record.");
                }
            }
        };
    }
    /** Only clear a matching record after the server confirms it exists. A not-found response is not proof of rollback. */
    boolean acknowledgeVerified(String invoiceId,JSONObject verification)throws Exception{
        synchronized(LOCK){
            JSONObject record=pending();
            if(record==null||!invoiceId.equals(record.getString("invoiceId"))||!Boolean.TRUE.equals(verification.opt("found")))return false;
            if(!store.edit().remove(key).commit())throw new IOException("Could not clear recovery record.");
            return true;
        }
    }
}
