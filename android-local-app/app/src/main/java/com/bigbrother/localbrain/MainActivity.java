package com.bigbrother.localbrain;

import android.app.Activity;
import android.os.Bundle;
import android.content.Intent;
import android.net.Uri;
import android.graphics.Color;
import android.graphics.Typeface;
import android.view.Gravity;
import android.view.View;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceError;
import android.webkit.SslErrorHandler;
import android.net.http.SslError;
import android.webkit.WebChromeClient;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;

/** Dedicated BIG BROTHER company-LAN app. No SSL bypass or JS bridge. */
public final class MainActivity extends Activity {
    private static final String HOME =
      "https://bigbrother.local:8443/big-brother-dashboard/mobile.html?localbrain=1";
    private WebView view;
    private View problemOverlay;
    private boolean loadFailed;

    @Override public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().setStatusBarColor(Color.rgb(10,36,64));
        getWindow().setNavigationBarColor(Color.rgb(10,36,64));
        FrameLayout frame = new FrameLayout(this);
        frame.setBackgroundColor(Color.rgb(232,241,250));
        view = new WebView(this);
        view.setBackgroundColor(Color.WHITE);
        view.getSettings().setJavaScriptEnabled(true);
        view.getSettings().setDomStorageEnabled(true);
        view.getSettings().setDatabaseEnabled(true);
        view.getSettings().setAllowFileAccess(false);
        view.getSettings().setAllowContentAccess(false);
        view.getSettings().setJavaScriptCanOpenWindowsAutomatically(false);
        view.getSettings().setMixedContentMode(android.webkit.WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        view.getSettings().setCacheMode(android.webkit.WebSettings.LOAD_DEFAULT);
        WebView.setWebContentsDebuggingEnabled(false);
        view.setWebChromeClient(new WebChromeClient());
        view.setWebViewClient(new WebViewClient() {
            @Override public boolean shouldOverrideUrlLoading(WebView web, WebResourceRequest request) {
                if (!request.isForMainFrame()) return false;
                Uri url = request.getUrl();
                String scheme = url.getScheme();
                if ("https".equalsIgnoreCase(scheme) &&
                    "bigbrother.local".equalsIgnoreCase(url.getHost()) && url.getPort() == 8443) return false;
                if ("https".equalsIgnoreCase(scheme) || "http".equalsIgnoreCase(scheme)) {
                    try { startActivity(new Intent(Intent.ACTION_VIEW,url)); } catch (Exception ignored) {}
                }
                return true;
            }
            @Override public void onPageStarted(WebView web,String url,android.graphics.Bitmap icon) {
                loadFailed=false;
                super.onPageStarted(web,url,icon);
            }
            @Override public void onReceivedError(WebView web, WebResourceRequest request, WebResourceError error) {
                if(request.isForMainFrame()) {
                    loadFailed=true;
                    problemOverlay.setVisibility(View.VISIBLE);
                }
            }
            @Override public void onPageFinished(WebView web,String url) {
                if (!loadFailed) problemOverlay.setVisibility(View.GONE);
            }
            @Override public void onReceivedSslError(WebView web,SslErrorHandler handler,SslError error) {
                handler.cancel(); // Never accept invalid local HTTPS certificates.
                loadFailed=true;
                problemOverlay.setVisibility(View.VISIBLE);
            }
        });
        frame.addView(view,new FrameLayout.LayoutParams(-1,-1));

        LinearLayout message = new LinearLayout(this);
        message.setOrientation(LinearLayout.VERTICAL);
        message.setGravity(Gravity.CENTER);
        message.setPadding(dp(24),dp(24),dp(24),dp(24));
        message.setBackgroundColor(Color.rgb(232,241,250));
        TextView title = new TextView(this);
        title.setText("BIG BROTHER Local");
        title.setTextSize(23f);
        title.setTextColor(Color.rgb(24,66,112));
        title.setTypeface(null,Typeface.BOLD);
        title.setGravity(Gravity.CENTER);
        message.addView(title);
        TextView hint = new TextView(this);
        hint.setText("Local Brain is unavailable. Connect to company Wi-Fi and check V6 and Caddy HTTPS. Do not clear app data; offline cached screens require an initial successful sync in this app.");
        hint.setTextSize(15f);
        hint.setTextColor(Color.rgb(48,63,80));
        hint.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(-1,-2);
        p.setMargins(0,dp(12),0,dp(18));
        message.addView(hint,p);
        Button retry = new Button(this);
        retry.setText("RETRY LOCAL BRAIN");
        retry.setOnClickListener(v -> {
            problemOverlay.setVisibility(View.GONE);
            view.loadUrl(HOME);
        });
        message.addView(retry);
        frame.addView(message,new FrameLayout.LayoutParams(-1,-1));
        problemOverlay=message;
        problemOverlay.setVisibility(View.GONE);
        setContentView(frame);
        view.loadUrl(HOME);
    }
    private int dp(int v){return (int)(getResources().getDisplayMetrics().density*v+0.5f);}
    @Override public void onBackPressed(){
        if(view!=null && view.canGoBack())view.goBack();
        else super.onBackPressed();
    }
    @Override protected void onDestroy(){
        if(view!=null){view.stopLoading();view.destroy();view=null;}
        super.onDestroy();
    }
}
