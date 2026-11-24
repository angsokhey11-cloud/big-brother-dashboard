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
    synchronized void signOut() throws Exception {
        try { if (accessToken != null) post("/auth/v1/logout", new JSONObject(), accessToken); }
        finally { clear(); }
    }
    private void clear() { accessToken = null; refreshToken = null; expiresAt = 0; }
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
