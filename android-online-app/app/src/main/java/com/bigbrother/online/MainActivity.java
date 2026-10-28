package com.bigbrother.online;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.Typeface;
import android.net.Uri;
import android.os.Bundle;
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
 * BIG BROTHER Online: dedicated, separately installed online mobile shell.
 *
 * No JavaScript bridge, no SSL error bypass, no local-server URL, and no native
 * push claim. The existing website uses Browser Web Push; Android WebView does
 * NOT deliver background Web Push. Native FCM or a verified TWA is a separate
 * notification project.
 */
public final class MainActivity extends Activity {
    private static final String HOME =
      "https://angsokhey11-cloud.github.io/big-brother-dashboard/mobile.html?source=android-online";
    private static final String TRUSTED_HOST = "angsokhey11-cloud.github.io";
    private static final int FILE_CHOOSE_REQUEST = 4127;
    private WebView browser;
    private View overlay;
    private TextView overlayTitle;
    private TextView overlayMessage;
    private Button retry;
    private WebChromeClient.FileChooserParams unusedChooserParams;
    private android.webkit.ValueCallback<Uri[]> fileChooserCallback;
    private boolean failed;

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
        config.setAllowContentAccess(false);
        config.setJavaScriptCanOpenWindowsAutomatically(false);
        config.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        config.setCacheMode(WebSettings.LOAD_DEFAULT);
        config.setSupportZoom(false);
        CookieManager.getInstance().setAcceptCookie(true);
        browser.setWebChromeClient(new WebChromeClient() {
            @Override public boolean onShowFileChooser(
                WebView webView,
                android.webkit.ValueCallback<Uri[]> callback,
                FileChooserParams fileChooserParams
            ) {
                if (fileChooserCallback != null) fileChooserCallback.onReceiveValue(null);
                fileChooserCallback = callback;
                try {
                    // Android system picker, including gallery/photos/document files.
                    // No broad storage permission and no JavaScript native bridge.
                    Intent intent = fileChooserParams.createIntent();
                    startActivityForResult(intent, FILE_CHOOSE_REQUEST);
                    return true;
                } catch (Exception e) {
                    fileChooserCallback = null;
                    return false;
                }
            }
        });
        browser.setWebViewClient(new WebViewClient() {
            @Override public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                Uri uri = request.getUrl();
                if (!request.isForMainFrame()) return false;
                if ("https".equalsIgnoreCase(uri.getScheme())
                    && TRUSTED_HOST.equalsIgnoreCase(uri.getHost())) return false;
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
                if (!failed) overlay.setVisibility(View.GONE);
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
        subtitle.setText("Accounting System · Online");
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
        retry.setText("RETRY ONLINE");
        retry.setOnClickListener(v -> browser.loadUrl(HOME));
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

    private void showLoading() {
        if (overlay == null) return;
        overlay.setVisibility(View.VISIBLE);
        overlayTitle.setText("");
        overlayMessage.setText("Opening secure BIG BROTHER Online…");
        retry.setVisibility(View.GONE);
    }
    private void showError() {
        if (overlay == null) return;
        overlay.setVisibility(View.VISIBLE);
        overlayTitle.setText("Unable to connect");
        overlayMessage.setText("Check your internet connection and try again. " +
            "Your BIG BROTHER Online account and existing saved data have not been cleared.");
        retry.setVisibility(View.VISIBLE);
    }
    @Override protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode,resultCode,data);
        if (requestCode == FILE_CHOOSE_REQUEST && fileChooserCallback != null) {
            fileChooserCallback.onReceiveValue(
                WebChromeClient.FileChooserParams.parseResult(resultCode,data)
            );
            fileChooserCallback = null;
        }
    }
    @Override public void onBackPressed() {
        if (browser != null && browser.canGoBack()) browser.goBack();
        else super.onBackPressed();
    }
    @Override protected void onDestroy() {
        if (fileChooserCallback != null) {
            fileChooserCallback.onReceiveValue(null);
            fileChooserCallback = null;
        }
        if (browser != null) {
            browser.stopLoading();
            browser.destroy();
            browser = null;
        }
        super.onDestroy();
    }
}
