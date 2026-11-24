package com.bigbrother.nativev2;

import java.net.URL;
import javax.net.ssl.HttpsURLConnection;
import java.io.IOException;

/** Non-authenticated TLS connectivity probe; does not load a page into the UI. */
final class LocalConnection {
    static String check() throws IOException {
        if (!"local".equals(BuildConfig.FLAVOR)) throw new IOException("Local connection disabled in Online build");
        URL target = new URL(BuildConfig.ENDPOINT + "/");
        if (!"https".equals(target.getProtocol()) || !"bigbrother.local".equals(target.getHost()) || target.getPort()!=8443)
            throw new IOException("Unexpected Local Brain endpoint");
        HttpsURLConnection conn = (HttpsURLConnection) target.openConnection();
        try {
            conn.setInstanceFollowRedirects(false);
            conn.setConnectTimeout(5000);
            conn.setReadTimeout(5000);
            conn.setRequestMethod("HEAD");
            conn.setUseCaches(false);
            int status=conn.getResponseCode();
            return "Local Brain HTTPS reachable (HTTP " + status + "). Authentication not verified.";
        } finally { conn.disconnect(); }
    }
}
