package com.bigbrother.nativev2;

import org.json.JSONObject;
import java.net.URL;
import javax.net.ssl.HttpsURLConnection;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;

/** Flavor-isolated transport. Call on a worker thread; tokens remain in memory.
 */
final class CloudAuth {
    private static final String KEY = "sb_publishable_w762jR65CWwlO30fKQsYOw_6L9grx8S";
    private String localKey;
    synchronized void configureLocalKey(String value) throws Exception {
        if (!"local".equals(BuildConfig.FLAVOR)) throw new IOException("Local configuration unavailable");
        String key = value.trim();
        if (key.equals(KEY)) throw new IOException("Cloud key is not permitted");
        boolean valid = key.matches("sb_publishable_[A-Za-z0-9_-]+");
        if (!valid) {
            String[] parts = key.split("\\.");
            if (parts.length == 3) {
                JSONObject claims = new JSONObject(new String(android.util.Base64.decode(parts[1], android.util.Base64.URL_SAFE | android.util.Base64.NO_WRAP), StandardCharsets.UTF_8));
                valid = "anon".equals(claims.optString("role"));
            }
        }
        if (!valid) throw new IOException("Only a public anon or publishable key is allowed");
        clear(); localKey = key;
    }
    private String accessToken;
    private String refreshToken;
    private long expiresAt;
    synchronized JSONObject signIn(String email, String password) throws Exception {
        clear();
        JSONObject credentials = new JSONObject();
        credentials.put("email", email.trim());
        credentials.put("password", password);
        try {
            accept(new JSONObject(post("/auth/v1/token?grant_type=password", credentials, null)));
            return new JSONObject(post("/rest/v1/rpc/bb_current_access_profile", new JSONObject(), accessToken));
        } catch (Exception e) { clear(); throw e; }
    }
    private void accept(JSONObject session) throws Exception {
        String access = session.getString("access_token");
        String refresh = session.getString("refresh_token");
        long expiry = session.optLong("expires_at", System.currentTimeMillis()/1000 + session.optLong("expires_in", 3600));
        if (access.isEmpty() || refresh.isEmpty()) throw new IOException("Invalid session");
        accessToken = access; refreshToken = refresh; expiresAt = expiry;
    }
    synchronized JSONObject profile() throws Exception {
        if (accessToken == null) throw new IOException("Sign in first");
        if (expiresAt < System.currentTimeMillis()/1000 + 60) {
            JSONObject body = new JSONObject(); body.put("refresh_token", refreshToken);
            try { accept(new JSONObject(post("/auth/v1/token?grant_type=refresh_token", body, null))); }
            catch (Exception e) { clear(); throw e; }
        }
        return new JSONObject(post("/rest/v1/rpc/bb_current_access_profile", new JSONObject(), accessToken));
    }
    synchronized JSONObject invoiceList(String invoiceNo, String customer, String from, String to) throws Exception {
        JSONObject args = new JSONObject();
        args.put("p_invoice_no", invoiceNo.trim());
        args.put("p_customer", customer.trim());
        args.put("p_date_from", from.isEmpty() ? JSONObject.NULL : from);
        args.put("p_date_to", to.isEmpty() ? JSONObject.NULL : to);
        args.put("p_invoice_type", "");
        return readInvoiceRpc("bb_invoice_history_mobile_list", args);
    }
    synchronized JSONObject invoiceDetail(String invoiceId) throws Exception {
        if (invoiceId == null || invoiceId.trim().isEmpty()) throw new IOException("Invoice ID required");
        JSONObject args = new JSONObject();
        args.put("p_invoice_id", invoiceId);
        return readInvoiceRpc("bb_invoice_history_mobile_detail_by_id", args);
    }
    synchronized JSONObject digitalOriginalStatus(String invoiceId) throws Exception {
        if (invoiceId == null || invoiceId.trim().isEmpty()) throw new IOException("Invoice ID required");
        JSONObject args = new JSONObject();
        args.put("p_invoice_id", invoiceId);
        return readInvoiceRpc("bb_real_invoice_digital_status", args);
    }
    private JSONObject readInvoiceRpc(String fn, JSONObject args) throws Exception {
        JSONObject current = profile();
        if ("online".equals(BuildConfig.FLAVOR)) {
            if (!NativeRoutes.allowed(current,"history","canView")) throw new IOException("Invoice History route permission denied");
            JSONObject data = new JSONObject(post("/rest/v1/rpc/" + fn, args, accessToken));
            if (Boolean.FALSE.equals(data.opt("success"))) throw new IOException("Invoice History request failed");
            return data;
        }
        JSONObject user = current.optJSONObject("user");
        boolean allowed = user != null && Boolean.TRUE.equals(user.opt("isAdmin"));
        if (!allowed) {
            org.json.JSONArray grants = current.optJSONArray("modules");
            JSONObject exact = null, wildcard = null;
            if (grants != null) for (int i=0; i<grants.length(); i++) {
                JSONObject grant = grants.optJSONObject(i);
                if (grant == null) continue;
                String key = grant.optString("moduleKey").trim();
                if ("*".equals(key) && wildcard == null) wildcard = grant;
                if ("invoice_history".equalsIgnoreCase(key) && exact == null) exact = grant;
            }
            JSONObject selected = wildcard != null ? wildcard : exact;
            allowed = selected != null && Boolean.TRUE.equals(selected.opt("canView"));
        }
        if (!allowed) throw new IOException("Invoice History permission denied");
        JSONObject data = new JSONObject(post("/rest/v1/rpc/" + fn, args, accessToken));
        if (Boolean.FALSE.equals(data.opt("success"))) throw new IOException("Invoice History request failed");
        return data;
    }
    private JSONObject generatorRead(String fn,JSONObject args)throws Exception{
        if(!"online".equals(BuildConfig.FLAVOR)||!NativeRoutes.allowed(profile(),"invoice","canCreate"))
            throw new IOException("Invoice Generator permission denied");
        JSONObject data=new JSONObject(post("/rest/v1/rpc/"+fn,args,accessToken));
        if(Boolean.FALSE.equals(data.opt("success")))throw new IOException("Invoice Generator request failed");
        return data;
    }
    synchronized boolean generatorValidateBank(String customerId,String transactionId,java.math.BigDecimal actual,String actualCurrency,String invoiceCurrency,java.math.BigDecimal rate,java.math.BigDecimal equivalent)throws Exception{
        if(!"online".equals(BuildConfig.FLAVOR)||!NativeRoutes.allowed(profile(),"invoice","canCreate"))throw new IOException("Bank validation permission denied");
        JSONObject args=new JSONObject().put("p_customer_id",customerId).put("p_transaction_id",transactionId)
            .put("p_actual_amount",actual).put("p_actual_currency",actualCurrency).put("p_invoice_currency",invoiceCurrency)
            .put("p_exchange_rate",rate).put("p_equivalent_amount",equivalent);
        return "true".equals(post("/rest/v1/rpc/bb_bank_validate_invoice_input",args,accessToken).trim());
    }
    synchronized JSONObject generatorBankBalances(String customerId)throws Exception{
        JSONObject current=profile();
        if(!"online".equals(BuildConfig.FLAVOR)||!NativeRoutes.allowed(current,"invoice","canCreate")||customerId.trim().isEmpty())
            throw new IOException("Bank balance permission denied");
        org.json.JSONArray rows=new org.json.JSONArray(post("/rest/v1/rpc/bb_invoice_bank_bulk_sync",new JSONObject(),accessToken));
        validateBankRows(rows);sharedBankSnapshot=rows;bankSyncedAt=System.currentTimeMillis();
        org.json.JSONArray customerRows=new org.json.JSONArray();
        for(int i=0;i<rows.length();i++){
            JSONObject row=rows.optJSONObject(i);
            if(row!=null&&customerId.equals(row.optString("customer_id").trim()))customerRows.put(row);
        }
        return new JSONObject().put("rows",customerRows).put("admin",NativeRoutes.admin(current));
    }
    synchronized JSONObject generatorDuplicateCheck(String no,String customerId)throws Exception{
        if(!no.matches("INV-[0-9]+")||customerId.trim().isEmpty())throw new IOException("Invoice number or customer invalid");
        return generatorRead("bb_sales_check_invoice_customer",new JSONObject().put("p_invoice_no",no).put("p_customer_id",customerId));
    }
    synchronized String generatorAccount()throws Exception{
        if(!"online".equals(BuildConfig.FLAVOR)||!NativeRoutes.allowed(profile(),"invoice","canCreate"))throw new IOException("Invoice permission denied");
        String[] parts=accessToken.split("\\.");
        if(parts.length!=3)throw new IOException("Account identity unavailable");
        JSONObject claims=new JSONObject(new String(android.util.Base64.decode(parts[1],android.util.Base64.URL_SAFE|android.util.Base64.NO_WRAP),StandardCharsets.UTF_8));
        String sub=claims.optString("sub").trim();
        if(sub.isEmpty())throw new IOException("Account identity unavailable");
        return sub;
    }
    synchronized JSONObject generatorVerifySave(String id)throws Exception{
        if(id.trim().isEmpty()||id.length()>128)throw new IOException("Invalid invoice identity");
        return generatorRead("bb_sales_verify_invoice_save",new JSONObject().put("p_invoice_id",id));
    }
    synchronized java.io.File receivableOriginal(String route,String id,java.io.File folder,long limit)throws Exception{
        if(limit<=0||limit>20L*1024*1024)throw new IOException("Original file size limit");
        org.json.JSONArray manifest=receivableOriginalManifest(route,new org.json.JSONArray().put(id));
        if(manifest.length()!=1)throw new IOException("No accessible original");
        JSONObject row=manifest.getJSONObject(0);String path=row.getString("path");
        if(path.length()>1024||path.startsWith("/")||path.indexOf(92)>=0)throw new IOException("Invalid object path");
        StringBuilder encoded=new StringBuilder();
        for(String part:path.split("/",-1)){
            if(part.isEmpty()||".".equals(part)||"..".equals(part)||part.indexOf(0)>=0)throw new IOException("Invalid object path");
            if(encoded.length()>0)encoded.append('/');
            encoded.append(android.net.Uri.encode(part));
        }
        String extension=path.substring(path.lastIndexOf('.')+1).toLowerCase(java.util.Locale.ROOT);
        if(!java.util.Arrays.asList("jpg","jpeg","png","webp","gif","bmp","pdf").contains(extension))throw new IOException("Unsupported original file type");
        String safeNo=row.optString("invoiceNo","Invoice").replaceAll("[^a-zA-Z0-9_-]","_");
        if(safeNo.length()>64)safeNo=safeNo.substring(0,64);
        if(!folder.exists()&&!folder.mkdirs())throw new IOException("Cache unavailable");
        java.io.File output=java.io.File.createTempFile("BB-AR-Original-"+safeNo+"-", "."+extension,folder);
        HttpsURLConnection conn=null;boolean ok=false;
        try{
            conn=(HttpsURLConnection)new URL("https://sjfhlaclgmkwwofzstok.supabase.co/storage/v1/object/authenticated/bb-real-invoices/"+encoded).openConnection();
            conn.setInstanceFollowRedirects(false);conn.setConnectTimeout(10000);conn.setReadTimeout(20000);conn.setUseCaches(false);
            conn.setRequestProperty("apikey",KEY);conn.setRequestProperty("Authorization","Bearer "+accessToken);
            if(conn.getResponseCode()!=200||conn.getContentLengthLong()>limit)throw new IOException("Original download unavailable");
            long size=0;
            try(InputStream in=conn.getInputStream();java.io.FileOutputStream out=new java.io.FileOutputStream(output)){
                byte[] b=new byte[8192];int n;
                while((n=in.read(b))!=-1){size+=n;if(size>limit)throw new IOException("Original exceeds limit");out.write(b,0,n);}
            }
            if(size==0||!ReceivableFiles.validFile(output))throw new IOException("Original content does not match supported file type");
            ok=true;return output;
        }finally{if(conn!=null)conn.disconnect();if(!ok)output.delete();}
    }
    synchronized org.json.JSONArray receivableOriginalManifest(String route,org.json.JSONArray ids)throws Exception{
        JSONObject current=profile();
        if(!"online".equals(BuildConfig.FLAVOR)||!java.util.Arrays.asList("ar-all","ar-your","sales-support-your-receivable").contains(route)||!NativeRoutes.allowed(current,route,"canView")||ids.length()<1||ids.length()>35)
            throw new IOException("Original attachment manifest access denied");
        java.util.HashSet<String> requested=new java.util.HashSet<>();
        for(int i=0;i<ids.length();i++){String id=ids.getString(i);if(id.trim().isEmpty()||!requested.add(id))throw new IOException("Invalid selected invoice ID");}
        org.json.JSONArray rows=new org.json.JSONArray(post("/rest/v1/rpc/bb_ar_original_manifest",new JSONObject().put("p_invoice_ids",ids),accessToken));
        java.util.HashSet<String> seen=new java.util.HashSet<>();
        for(int i=0;i<rows.length();i++){
            JSONObject row=rows.getJSONObject(i);
            if(!requested.contains(row.optString("invoiceId"))||!seen.add(row.optString("invoiceId"))||row.optString("path").trim().isEmpty())
                throw new IOException("Invalid original invoice manifest");
        }
        return rows;
    }
    synchronized JSONObject receivableDetail(String route,String id)throws Exception{
        JSONObject current=profile();
        if(!"online".equals(BuildConfig.FLAVOR)||!java.util.Arrays.asList("ar-all","ar-your","sales-support-your-receivable").contains(route)||!NativeRoutes.allowed(current,route,"canView")||id.trim().isEmpty())
            throw new IOException("Receivable detail access denied");
        String fn="ar-all".equals(route)?"bb_ar_detail_by_id_all":"bb_ar_detail_by_id";
        JSONObject result=new JSONObject(post("/rest/v1/rpc/"+fn,new JSONObject().put("p_invoice_id",id),accessToken));
        if(!Boolean.TRUE.equals(result.opt("success")))throw new IOException("Receivable detail unavailable");
        return result;
    }
    private org.json.JSONArray sharedBankSnapshot;
    private long bankSyncedAt;
    synchronized JSONObject receivableBankSync(String route)throws Exception{
        JSONObject current=profile();
        if(!"online".equals(BuildConfig.FLAVOR)||!java.util.Arrays.asList("ar-all","ar-your","sales-support-your-receivable").contains(route)||!NativeRoutes.allowed(current,route,"canView"))
            throw new IOException("Bank sync access denied");
        org.json.JSONArray fresh=new org.json.JSONArray(post("/rest/v1/rpc/bb_invoice_bank_bulk_sync",new JSONObject(),accessToken));
        validateBankRows(fresh);
        sharedBankSnapshot=fresh;bankSyncedAt=System.currentTimeMillis();
        return new JSONObject().put("count",fresh.length()).put("syncedAt",bankSyncedAt);
    }
    private void validateBankRows(org.json.JSONArray rows)throws Exception{
        java.util.HashSet<String> seen=new java.util.HashSet<>();
        for(int i=0;i<rows.length();i++){
            JSONObject r=rows.getJSONObject(i);String cid=r.getString("customer_id").trim(),tx=r.getString("transaction_id").trim().toUpperCase(java.util.Locale.ROOT);
            if(cid.isEmpty()||tx.isEmpty()||!seen.add(cid+"|"+tx)||!java.util.Arrays.asList("USD","KHR").contains(r.getString("currency").toUpperCase(java.util.Locale.ROOT))||new java.math.BigDecimal(r.getString("remaining_amount")).signum()<=0)
                throw new IOException("Invalid bank snapshot");
        }
    }
    synchronized JSONObject receivableAdminProfile()throws Exception{
        JSONObject current=profile();
        if(!"online".equals(BuildConfig.FLAVOR)||!NativeRoutes.admin(current)||!NativeRoutes.allowed(current,"ar-all","canView"))throw new IOException("Admin payment access required");
        return current;
    }
    synchronized org.json.JSONArray receivableCustomerBank(String customerId)throws Exception{
        receivableAdminProfile();
        if(customerId.trim().isEmpty())throw new IOException("Customer required");
        org.json.JSONArray fresh=new org.json.JSONArray(post("/rest/v1/rpc/bb_customer_bank_balance_list_v2",new JSONObject().put("p_customer_id",customerId),accessToken));
        org.json.JSONArray filtered=new org.json.JSONArray();
        for(int i=0;i<fresh.length();i++){
            JSONObject row=fresh.getJSONObject(i);
            if(row.has("customer_id")&&!customerId.equals(row.optString("customer_id")))throw new IOException("Unexpected bank customer");
            if(new java.math.BigDecimal(row.getString("remaining_amount")).signum()<=0)continue;
            row.put("customer_id",customerId);filtered.put(row);
        }
        validateBankRows(filtered);return filtered;
    }
    synchronized JSONObject receivableList(String route)throws Exception{
        JSONObject current=profile();
        if(!"online".equals(BuildConfig.FLAVOR)||!java.util.Arrays.asList("ar-all","ar-your","sales-support-your-receivable").contains(route)||!NativeRoutes.allowed(current,route,"canView"))
            throw new IOException("Receivable route access denied");
        String fn="ar-all".equals(route)?"bb_ar_list_all":"bb_ar_list";
        JSONObject data=new JSONObject(post("/rest/v1/rpc/"+fn,new JSONObject(),accessToken));
        if(!Boolean.TRUE.equals(data.opt("success"))||data.optJSONArray("receivables")==null)throw new IOException("Receivable list unavailable");
        return data;
    }
    synchronized JSONObject generatorBootstrap()throws Exception{return generatorRead("bb_sales_invoice_bootstrap",new JSONObject());}
    synchronized JSONObject generatorWarehouse()throws Exception{return generatorRead("bb_sales_direct_stock_balances",new JSONObject());}
    synchronized JSONObject generatorBatches()throws Exception{return generatorRead("bb_sales_open_batches",new JSONObject());}
    synchronized JSONObject generatorCustomers(String code)throws Exception{
        return generatorRead("bb_sales_customers_by_location",new JSONObject().put("p_location_code",code));
    }
    synchronized JSONObject generatorPrices(String id)throws Exception{
        return generatorRead("bb_sales_customer_prices",new JSONObject().put("p_customer_id",id));
    }
    synchronized JSONObject generatorNumber(String batch)throws Exception{
        return batch.isEmpty()?generatorRead("bb_sales_next_invoice_no",new JSONObject()):
            generatorRead("bb_sales_batch_next_invoice_no",new JSONObject().put("p_batch_id",batch));
    }
    synchronized JSONObject dashboardOverview() throws Exception {
        JSONObject current=profile();
        if(!"online".equals(BuildConfig.FLAVOR))throw new IOException("Online dashboard only");
        JSONObject args=new JSONObject();
        String fn="bb_mobile_user_overview";
        if(NativeRoutes.admin(current)){
            java.time.LocalDate d=java.time.LocalDate.now(java.time.ZoneId.of("Asia/Phnom_Penh"));
            args.put("p_year",d.getYear());args.put("p_month",d.getMonthValue());
            fn="bb_dashboard_monthly_overview";
        }
        JSONObject data=new JSONObject(post("/rest/v1/rpc/"+fn,args,accessToken));
        if(Boolean.FALSE.equals(data.opt("success")))throw new IOException("Overview unavailable");
        return data;
    }
    synchronized JSONObject myPayments() throws Exception {
        JSONObject current=profile();
        if(!"online".equals(BuildConfig.FLAVOR)||NativeRoutes.admin(current))throw new IOException("Staff overview only");
        JSONObject args=new JSONObject();
        args.put("p_from",JSONObject.NULL);args.put("p_to",JSONObject.NULL);args.put("p_salary_month",JSONObject.NULL);
        return new JSONObject(post("/rest/v1/rpc/bb_staff_relation_my_payments",args,accessToken));
    }
    synchronized void signOut() throws Exception {
        try { if (accessToken != null) post("/auth/v1/logout", new JSONObject(), accessToken); }
        finally { clear(); }
    }
    private void clear() { accessToken = null; refreshToken = null; expiresAt = 0; sharedBankSnapshot=null;bankSyncedAt=0; }
    private String post(String path, JSONObject body, String bearer) throws Exception {
        boolean local = "local".equals(BuildConfig.FLAVOR);
        String key = local ? localKey : KEY;
        if (key == null) throw new IOException("Configure Local Brain public key first");
        URL endpoint = new URL(BuildConfig.ENDPOINT);
        if (!"https".equals(endpoint.getProtocol()) ||
            (local ? (!"bigbrother.local".equals(endpoint.getHost()) || endpoint.getPort()!=8443)
                   : (!"sjfhlaclgmkwwofzstok.supabase.co".equals(endpoint.getHost()) || endpoint.getPort()!=-1)))
            throw new IOException("Unexpected authentication endpoint");
        if(local){
            okhttp3.Request.Builder request=LocalTransport.request(path)
                .header("apikey",key)
                .post(okhttp3.RequestBody.create(body.toString(),okhttp3.MediaType.parse("application/json")));
            if(bearer!=null)request.header("Authorization","Bearer "+bearer);
            try(okhttp3.Response response=LocalTransport.client().newCall(request.build()).execute()){
                if(!response.isSuccessful())throw new IOException("Local server request failed ("+response.code()+")");
                return LocalTransport.read(response,1048576);
            }
        }
        HttpsURLConnection conn = (HttpsURLConnection) new URL(BuildConfig.ENDPOINT + path).openConnection();
        try {
            conn.setInstanceFollowRedirects(false);
            conn.setConnectTimeout(10000); conn.setReadTimeout(15000);
            conn.setUseCaches(false); conn.setRequestMethod("POST"); conn.setDoOutput(true);
            conn.setRequestProperty("apikey", key);
            conn.setRequestProperty("Content-Type", "application/json");
            if (bearer != null) conn.setRequestProperty("Authorization", "Bearer " + bearer);
            byte[] bytes = body.toString().getBytes(StandardCharsets.UTF_8);
            conn.setFixedLengthStreamingMode(bytes.length);
            try (OutputStream out = conn.getOutputStream()) { out.write(bytes); }
            int status = conn.getResponseCode();
            if (status < 200 || status >= 300) throw new IOException("Server request failed (" + status + ")");
            try (InputStream in = conn.getInputStream(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
                byte[] buffer = new byte[8192]; int n;
                while ((n = in.read(buffer)) != -1) {
                    if (out.size() + n > 1048576) throw new IOException("Response exceeds limit");
                    out.write(buffer, 0, n);
                }
                return out.toString("UTF-8");
            }
        } finally { conn.disconnect(); }
    }
}
