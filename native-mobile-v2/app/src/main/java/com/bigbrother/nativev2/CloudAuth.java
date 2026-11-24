package com.bigbrother.nativev2;

import org.json.JSONObject;
import java.net.URL;
import javax.net.ssl.HttpsURLConnection;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;

/** Cloud-only transport. Call on a worker thread; tokens remain in memory.
 * Local Brain requires a separately verified authentication contract.
 */
final class CloudAuth {
    private static final String KEY = "sb_publishable_w762jR65CWwlO30fKQsYOw_6L9grx8S";
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
    synchronized void signOut() throws Exception {
        try { if (accessToken != null) post("/auth/v1/logout", new JSONObject(), accessToken); }
        finally { clear(); }
    }
    private void clear() { accessToken = null; refreshToken = null; expiresAt = 0; }
    private String post(String path, JSONObject body, String bearer) throws Exception {
        if (!"online".equals(BuildConfig.FLAVOR)) throw new IOException("Cloud authentication disabled in Local build");
        HttpsURLConnection conn = (HttpsURLConnection) new URL(BuildConfig.ENDPOINT + path).openConnection();
        try {
            conn.setInstanceFollowRedirects(false);
            conn.setConnectTimeout(10000); conn.setReadTimeout(15000);
            conn.setUseCaches(false); conn.setRequestMethod("POST"); conn.setDoOutput(true);
            conn.setRequestProperty("apikey", KEY);
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
