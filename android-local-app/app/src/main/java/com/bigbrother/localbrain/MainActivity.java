package com.bigbrother.localbrain;

import android.app.Activity;
import android.Manifest;
import android.content.pm.PackageManager;
import android.content.Intent;
import android.content.ClipData;
import android.provider.MediaStore;
import android.webkit.PermissionRequest;
import android.webkit.GeolocationPermissions;
import android.webkit.ValueCallback;
import androidx.core.content.FileProvider;
import java.io.File;
import java.util.ArrayList;
import java.util.List;
import android.graphics.Color;
import android.graphics.Typeface;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.View;
import android.webkit.CookieManager;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.webkit.WebSettings;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;

/**
 * BIG BROTHER Local: secure LAN-only mobile shell.
 *
 * No JavaScript bridge or SSL bypass. Requires trusted local Caddy HTTPS.
 * Camera, gallery, microphone and geolocation are granted only to the trusted
 * BIG BROTHER Local Brain origin, after Android user approval.
 */
public final class MainActivity extends Activity {
    private static final String HOME =
      "https://bigbrother.local:8443/big-brother-dashboard/mobile.html?localbrain=1";
    private static final String TRUSTED_HOST = "bigbrother.local";
    private static final int FILE_CHOOSE_REQUEST = 4127;
    private static final int REQUEST_CAMERA_CAPTURE = 4129;
    private static final int REQUEST_WEB_MEDIA = 4130;
    private static final int REQUEST_WEB_LOCATION = 4131;
    private WebView browser;
    private BBNativeFileActions nativeFiles;
    private View overlay;
    private TextView overlayTitle;
    private TextView overlayMessage;
    private Button retry;
    private ValueCallback<Uri[]> fileChooserCallback;
    private WebChromeClient.FileChooserParams pendingChooserParams;
    private Uri capturePhotoUri;
    private File capturePhotoFile;
    private PermissionRequest pendingMediaPermission;
    private GeolocationPermissions.Callback pendingGeolocationCallback;
    private String pendingGeolocationOrigin;
    private boolean failed;
    private final Handler reconnectHandler=new Handler(Looper.getMainLooper());
    private int retryAttempts=0;
    private final Runnable retryOpen=new Runnable(){
        @Override public void run(){
            if(isFinishing()||browser==null||overlay==null||
                    overlay.getVisibility()!=View.VISIBLE||
                    retry.getVisibility()!=View.VISIBLE)return;
            browser.loadUrl(HOME);
        }
    };
    private void scheduleRetry(){
        if(isFinishing())return;
        reconnectHandler.removeCallbacks(retryOpen);
        long delay=Math.min(15000L,4000L << Math.min(retryAttempts++,2));
        reconnectHandler.postDelayed(retryOpen,delay);
    }
    private void stopRetry(){
        reconnectHandler.removeCallbacks(retryOpen);
        retryAttempts=0;
    }

    /**
     * Android 15 (API 35) enforces edge-to-edge for targetSdk 35 apps.
     * Apply the device's status/navigation/cutout insets to the native root,
     * rather than patching each web page's CSS or zooming the WebView.
     *
     * After applying system-bar padding, pass a copy with those SAME insets
     * zeroed to the WebView. Otherwise the WebView may apply the inset twice.
     * IME (keyboard) insets are deliberately preserved.
     * On Android 14 and earlier, normal platform content fitting is untouched.
     */
    private void protectSystemBars(FrameLayout container) {
        if (android.os.Build.VERSION.SDK_INT < 35) return;
        container.setOnApplyWindowInsetsListener((view, insets) -> {
            int types = android.view.WindowInsets.Type.systemBars()
                | android.view.WindowInsets.Type.displayCutout();
            android.graphics.Insets system = insets.getInsets(types);
            view.setPadding(system.left, system.top, system.right, system.bottom);
            return new android.view.WindowInsets.Builder(insets)
                .setInsets(types, android.graphics.Insets.NONE)
                .build();
        });
    }

    private int dp(int value) {
        return (int)(getResources().getDisplayMetrics().density * value + 0.5f);
    }

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        cleanExpiredCameraFiles();
        getWindow().setStatusBarColor(Color.rgb(10,36,64));
        getWindow().setNavigationBarColor(Color.rgb(10,36,64));

        FrameLayout root = new FrameLayout(this);
        // Android 15+ draws behind the system status/navigation bars by default.
        // Give the status-bar icons a dark BIG BROTHER background while keeping
        // the WebView and its accounting headers BELOW the system bars.
        root.setBackgroundColor(Color.rgb(10,36,64));
        protectSystemBars(root);
        browser = new WebView(this);
        browser.setBackgroundColor(Color.WHITE);
        WebSettings config = browser.getSettings();
        config.setJavaScriptEnabled(true);
        config.setDomStorageEnabled(true);
        config.setDatabaseEnabled(true);
        config.setAllowFileAccess(false);
        // Gallery and captured photo URIs arrive through the trusted Android picker.
        // Do not enable broad file:// access or JavaScript-to-native bridges.
        config.setAllowContentAccess(true);
        config.setGeolocationEnabled(true);
        config.setJavaScriptCanOpenWindowsAutomatically(false);
        config.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        config.setCacheMode(WebSettings.LOAD_DEFAULT);
        config.setSupportZoom(false);
        CookieManager.getInstance().setAcceptCookie(true);
        // Native invoice exports only from Local Brain's HTTPS origin on :8443.
        nativeFiles = BBNativeFileActions.install(this,browser);
        browser.setWebChromeClient(new WebChromeClient() {
            @Override public boolean onShowFileChooser(WebView webView,
                ValueCallback<Uri[]> callback, FileChooserParams params) {
                if (!isTrustedOrigin(webView.getUrl())) {
                    callback.onReceiveValue(null);
                    return true;
                }
                if (fileChooserCallback != null) fileChooserCallback.onReceiveValue(null);
                fileChooserCallback = callback;
                pendingChooserParams = params;
                if (params.isCaptureEnabled() && isImageUpload(params)) {
                    if (hasAndroidPermission(Manifest.permission.CAMERA)) {
                        openNativeCamera();
                    } else {
                        requestPermissions(new String[]{Manifest.permission.CAMERA},
                            REQUEST_CAMERA_CAPTURE);
                    }
                } else {
                    openFilePicker();
                }
                return true;
            }
            @Override public void onPermissionRequest(PermissionRequest request) {
                runOnUiThread(() -> requestTrustedWebMedia(request));
            }
            @Override public void onPermissionRequestCanceled(PermissionRequest request) {
                if (pendingMediaPermission == request) pendingMediaPermission = null;
            }
            @Override public void onGeolocationPermissionsShowPrompt(
                String origin, GeolocationPermissions.Callback callback) {
                if (!isTrustedOrigin(origin)) {
                    callback.invoke(origin, false, false);
                    return;
                }
                if (hasAndroidPermission(Manifest.permission.ACCESS_FINE_LOCATION) ||
                    hasAndroidPermission(Manifest.permission.ACCESS_COARSE_LOCATION)) {
                    callback.invoke(origin, true, false);
                    return;
                }
                if (pendingGeolocationCallback != null) {
                    pendingGeolocationCallback.invoke(pendingGeolocationOrigin, false, false);
                }
                pendingGeolocationCallback = callback;
                pendingGeolocationOrigin = origin;
                requestPermissions(new String[]{
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION
                }, REQUEST_WEB_LOCATION);
            }
        });
        browser.setWebViewClient(new WebViewClient() {
            @Override public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                Uri uri = request.getUrl();
                if (!request.isForMainFrame()) return false;
                if (isTrustedOrigin(uri)) return false;
                if ("https".equalsIgnoreCase(uri.getScheme()) ||
                    "http".equalsIgnoreCase(uri.getScheme()) ||
                    "mailto".equalsIgnoreCase(uri.getScheme()) ||
                    "tel".equalsIgnoreCase(uri.getScheme())) {
                    try { startActivity(new Intent(Intent.ACTION_VIEW, uri)); }
                    catch (Exception ignored) {}
                }
                return true;
            }
            @Override public void onPageStarted(WebView view, String url, android.graphics.Bitmap icon) {
                failed = false;
                showLoading();
                super.onPageStarted(view, url, icon);
            }
            @Override public void onPageFinished(WebView view, String url) {
                if (!failed) {
                    stopRetry();
                    overlay.setVisibility(View.GONE);
                }
            }
            @Override public void onReceivedError(WebView view, WebResourceRequest request, WebResourceError error) {
                if (request.isForMainFrame()) {
                    failed = true;
                    showError();
                }
            }
            @Override public void onReceivedHttpError(WebView view, WebResourceRequest request,
                    android.webkit.WebResourceResponse response) {
                if (request.isForMainFrame() && response.getStatusCode() >= 400) {
                    failed = true;
                    showError();
                }
            }
            @Override public void onReceivedSslError(WebView view,
                android.webkit.SslErrorHandler handler, android.net.http.SslError error) {
                handler.cancel();
                failed = true;
                showError();
            }
        });
        root.addView(browser,new FrameLayout.LayoutParams(-1,-1));

        LinearLayout panel = new LinearLayout(this);
        panel.setOrientation(LinearLayout.VERTICAL);
        panel.setGravity(Gravity.CENTER);
        panel.setPadding(dp(24),dp(28),dp(24),dp(28));
        panel.setBackgroundColor(Color.rgb(235,243,251));
        TextView brand = new TextView(this);
        brand.setText("BIG BROTHER");
        brand.setTextColor(Color.rgb(17,45,86));
        brand.setTypeface(null,Typeface.BOLD);
        brand.setTextSize(26);
        brand.setGravity(Gravity.CENTER);
        panel.addView(brand);
        TextView subtitle = new TextView(this);
        subtitle.setText("Accounting System · Local Brain");
        subtitle.setTextColor(Color.rgb(55,101,146));
        subtitle.setTextSize(13);
        subtitle.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams subParams = new LinearLayout.LayoutParams(-1,-2);
        subParams.setMargins(0,dp(6),0,dp(18));
        panel.addView(subtitle,subParams);
        ProgressBar loading = new ProgressBar(this);
        LinearLayout.LayoutParams spinnerParams = new LinearLayout.LayoutParams(dp(36),dp(36));
        spinnerParams.gravity = Gravity.CENTER;
        panel.addView(loading,spinnerParams);
        overlayTitle = new TextView(this);
        overlayTitle.setTextColor(Color.rgb(17,45,86));
        overlayTitle.setTypeface(null,Typeface.BOLD);
        overlayTitle.setTextSize(19);
        overlayTitle.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams titleParams = new LinearLayout.LayoutParams(-1,-2);
        titleParams.setMargins(0,dp(14),0,dp(8));
        panel.addView(overlayTitle,titleParams);
        overlayMessage = new TextView(this);
        overlayMessage.setTextColor(Color.rgb(48,63,80));
        overlayMessage.setTextSize(14);
        overlayMessage.setGravity(Gravity.CENTER);
        panel.addView(overlayMessage);
        retry = new Button(this);
        retry.setText("RETRY LOCAL BRAIN");
        retry.setOnClickListener(v -> {
            reconnectHandler.removeCallbacks(retryOpen);
            browser.loadUrl(HOME);
        });
        LinearLayout.LayoutParams retryParams = new LinearLayout.LayoutParams(-2,-2);
        retryParams.gravity = Gravity.CENTER;
        retryParams.setMargins(0,dp(18),0,0);
        panel.addView(retry,retryParams);
        root.addView(panel,new FrameLayout.LayoutParams(-1,-1));
        overlay = panel;
        setContentView(root);
        showLoading();
        browser.loadUrl(HOME);
    }

    /** Restrict camera, microphone and location to BIG BROTHER's HTTPS origin. */
    private boolean isTrustedOrigin(String url) {
        if (url == null) return false;
        try {
            Uri u = Uri.parse(url);
            return "https".equalsIgnoreCase(u.getScheme())
                && TRUSTED_HOST.equalsIgnoreCase(u.getHost())
                && u.getPort() == 8443;
        } catch (Exception e) { return false; }
    }
    private boolean isTrustedOrigin(Uri uri) {
        return uri != null && isTrustedOrigin(uri.toString());
    }
    private boolean hasAndroidPermission(String permission) {
        return checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED;
    }
    private boolean isImageUpload(WebChromeClient.FileChooserParams params) {
        for (String type : params.getAcceptTypes()) {
            if (type != null && (type.toLowerCase().startsWith("image/")
                || type.toLowerCase().contains("image/*"))) return true;
        }
        return false;
    }
    private void finishFileChooser(Uri[] uris) {
        ValueCallback<Uri[]> cb = fileChooserCallback;
        fileChooserCallback = null;
        pendingChooserParams = null;
        capturePhotoFile = null;
        capturePhotoUri = null;
        if (cb != null) cb.onReceiveValue(uris);
    }
    private Uri[] filterPickedFiles(Uri[] uris) {
        if (uris == null || uris.length == 0) return null;
        ArrayList<Uri> safe = new ArrayList<>();
        for (Uri uri : uris) {
            if (uri == null || !"content".equalsIgnoreCase(uri.getScheme())) return null;
            // The private camera URI is only valid when WE initiated capture.
            if ((getPackageName() + ".camera.fileprovider").equals(uri.getAuthority()))
                return null;
            safe.add(uri);
        }
        return safe.toArray(new Uri[0]);
    }
    private void openFilePicker() {
        if (fileChooserCallback == null || pendingChooserParams == null) return;
        try {
            Intent pick = pendingChooserParams.createIntent();
            startActivityForResult(pick, FILE_CHOOSE_REQUEST);
        } catch (Exception e) {
            finishFileChooser(null);
        }
    }
    private void openNativeCamera() {
        if (fileChooserCallback == null || pendingChooserParams == null) return;
        try {
            File folder = new File(getCacheDir(), "bb_invoice_camera");
            if (!folder.isDirectory() && !folder.mkdirs())
                throw new java.io.IOException("Camera cache unavailable");
            capturePhotoFile = File.createTempFile("invoice_", ".jpg", folder);
            capturePhotoUri = FileProvider.getUriForFile(
                this, getPackageName() + ".camera.fileprovider", capturePhotoFile);
            Intent camera = new Intent(MediaStore.ACTION_IMAGE_CAPTURE);
            camera.putExtra(MediaStore.EXTRA_OUTPUT, capturePhotoUri);
            camera.setClipData(ClipData.newRawUri("BIG BROTHER camera photo", capturePhotoUri));
            camera.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION |
                Intent.FLAG_GRANT_READ_URI_PERMISSION);
            startActivityForResult(camera, FILE_CHOOSE_REQUEST);
        } catch (Exception e) {
            if (capturePhotoFile != null) capturePhotoFile.delete();
            capturePhotoFile = null;
            capturePhotoUri = null;
            // Even if the system camera is missing, users can import a photo.
            openFilePicker();
        }
    }
    private void requestTrustedWebMedia(PermissionRequest request) {
        if (!isTrustedOrigin(request.getOrigin()) || browser == null) {
            request.deny();
            return;
        }
        if (pendingMediaPermission != null && pendingMediaPermission != request)
            pendingMediaPermission.deny();
        pendingMediaPermission = null;
        List<String> wanted = new ArrayList<>();
        List<String> missing = new ArrayList<>();
        for (String resource : request.getResources()) {
            String permission;
            if (PermissionRequest.RESOURCE_VIDEO_CAPTURE.equals(resource)) {
                permission = Manifest.permission.CAMERA;
            } else if (PermissionRequest.RESOURCE_AUDIO_CAPTURE.equals(resource)) {
                permission = Manifest.permission.RECORD_AUDIO;
            } else {
                request.deny(); // Never implicitly grant new/unknown WebView resources.
                return;
            }
            if (!wanted.contains(resource)) wanted.add(resource);
            if (!hasAndroidPermission(permission) && !missing.contains(permission))
                missing.add(permission);
        }
        if (wanted.isEmpty()) { request.deny(); return; }
        if (missing.isEmpty()) {
            request.grant(wanted.toArray(new String[0]));
            return;
        }
        pendingMediaPermission = request;
        requestPermissions(missing.toArray(new String[0]), REQUEST_WEB_MEDIA);
    }
    private void finishWebMediaPermission() {
        PermissionRequest req = pendingMediaPermission;
        pendingMediaPermission = null;
        if (req == null) return;
        if (!isTrustedOrigin(req.getOrigin())) { req.deny(); return; }
        ArrayList<String> allowed = new ArrayList<>();
        for (String resource : req.getResources()) {
            if (PermissionRequest.RESOURCE_VIDEO_CAPTURE.equals(resource)
                && hasAndroidPermission(Manifest.permission.CAMERA))
                allowed.add(resource);
            else if (PermissionRequest.RESOURCE_AUDIO_CAPTURE.equals(resource)
                && hasAndroidPermission(Manifest.permission.RECORD_AUDIO))
                allowed.add(resource);
        }
        if (allowed.isEmpty()) req.deny();
        else req.grant(allowed.toArray(new String[0]));
    }
    private void cleanExpiredCameraFiles() {
        File folder = new File(getCacheDir(), "bb_invoice_camera");
        File[] files = folder.listFiles();
        if (files == null) return;
        long before = System.currentTimeMillis() - 24L * 60 * 60 * 1000;
        for (File file : files) {
            if (file.isFile() && file.lastModified() < before) file.delete();
        }
    }

    @Override public void onRequestPermissionsResult(int code,String[] permissions,int[] grants){
        super.onRequestPermissionsResult(code,permissions,grants);
        if(code==REQUEST_CAMERA_CAPTURE) {
            if(hasAndroidPermission(Manifest.permission.CAMERA)) openNativeCamera();
            else openFilePicker(); // Photos/PDF still available if Camera was declined.
            return;
        }
        if(code==REQUEST_WEB_MEDIA) {
            finishWebMediaPermission();
            return;
        }
        if(code==REQUEST_WEB_LOCATION) {
            if(pendingGeolocationCallback != null) {
                boolean granted=hasAndroidPermission(Manifest.permission.ACCESS_FINE_LOCATION)
                    || hasAndroidPermission(Manifest.permission.ACCESS_COARSE_LOCATION);
                pendingGeolocationCallback.invoke(pendingGeolocationOrigin,granted,false);
                pendingGeolocationCallback=null;
                pendingGeolocationOrigin=null;
            }
        }
    }
    private void showLoading() {
        if (overlay == null) return;
        overlay.setVisibility(View.VISIBLE);
        overlayTitle.setText("");
        overlayMessage.setText("Opening secure BIG BROTHER Local Brain…");
        retry.setVisibility(View.GONE);
    }
    private void showError() {
        if (overlay == null) return;
        overlay.setVisibility(View.VISIBLE);
        overlayTitle.setText("Unable to connect");
        overlayMessage.setText("Waiting for BIG BROTHER Local V6 and secure Wi-Fi. " +
            "Offline cache and login have not been cleared.");
        retry.setVisibility(View.VISIBLE);
        scheduleRetry();
    }
    @Override protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode,resultCode,data);
        if(nativeFiles!=null&&nativeFiles.onActivityResult(requestCode,resultCode,data))return;
        if (requestCode != FILE_CHOOSE_REQUEST || fileChooserCallback == null) return;
        Uri[] results = null;
        boolean captured = resultCode == RESULT_OK && capturePhotoUri != null
            && capturePhotoFile != null && capturePhotoFile.length() > 0L;
        if (captured) results = new Uri[]{capturePhotoUri};
        else if (resultCode == RESULT_OK)
            results = filterPickedFiles(WebChromeClient.FileChooserParams.parseResult(resultCode,data));
        if (!captured && capturePhotoFile != null) capturePhotoFile.delete();
        finishFileChooser(results);
    }
    @Override public void onBackPressed() {
        if (browser != null && browser.canGoBack()) browser.goBack();
        else super.onBackPressed();
    }
    @Override protected void onPause() {
        reconnectHandler.removeCallbacks(retryOpen);
        super.onPause();
    }
    @Override protected void onResume() {
        super.onResume();
        if(overlay!=null&&overlay.getVisibility()==View.VISIBLE&&
           retry!=null&&retry.getVisibility()==View.VISIBLE)scheduleRetry();
    }
    @Override protected void onDestroy() {
        reconnectHandler.removeCallbacks(retryOpen);
        if (fileChooserCallback != null) finishFileChooser(null);
        if (pendingMediaPermission != null) {
            pendingMediaPermission.deny();
            pendingMediaPermission = null;
        }
        if (pendingGeolocationCallback != null) {
            pendingGeolocationCallback.invoke(pendingGeolocationOrigin,false,false);
            pendingGeolocationCallback = null;
        }
        if (browser != null) {
            browser.stopLoading();
            browser.destroy();
            browser = null;
        }
        super.onDestroy();
    }
}
