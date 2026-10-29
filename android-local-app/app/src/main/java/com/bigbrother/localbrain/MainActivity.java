package com.bigbrother.localbrain;

import android.app.Activity;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
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
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Dedicated BIG BROTHER company-LAN app. No SSL bypass or JS bridge. */
public final class MainActivity extends Activity {
    private static final String HOME =
      "https://bigbrother.local:8443/big-brother-dashboard/mobile.html?localbrain=1";
    private WebView view;
    private View problemOverlay;
    private boolean loadFailed;
    // Separate OS-level HTTPS test. This bypasses WebView cache/service workers
    // and asks the real Caddy/V6 listener; Wi-Fi alone does NOT mean online.
    private final ExecutorService healthWorker=Executors.newSingleThreadExecutor();
    private boolean foreground=false,checkingHost=false,hostChecked=false,hostReachable=false;
    private final Runnable healthTick=new Runnable(){
        @Override public void run(){
            if(!foreground||isFinishing()||view==null||checkingHost)return;
            checkingHost=true;
            healthWorker.execute(()->{
                boolean ready=checkV6Https();
                reconnectHandler.post(()->{
                    checkingHost=false;
                    if(!foreground||isFinishing()||view==null)return;
                    final boolean recovered=ready&&(!hostChecked||!hostReachable);
                    final boolean changed=!hostChecked||hostReachable!=ready;
                    hostChecked=true;
                    hostReachable=ready;
                    if(changed)publishHostState(ready,recovered);
                    if(ready&&problemOverlay!=null&&
                            problemOverlay.getVisibility()==View.VISIBLE){
                        // A genuine startup error needs a new navigation.
                        stopRetry();
                        problemOverlay.setVisibility(View.GONE);
                        view.loadUrl(HOME);
                    }
                    reconnectHandler.postDelayed(healthTick,ready?12000L:5000L);
                });
            });
        }
    };
    private boolean checkV6Https(){
        HttpURLConnection con=null;
        try{
            URL url=new URL(HOME+"&bb_hostcheck=1");
            con=(HttpURLConnection)url.openConnection();
            con.setRequestMethod("HEAD");
            con.setUseCaches(false);
            con.setInstanceFollowRedirects(false);
            con.setConnectTimeout(3500);
            con.setReadTimeout(3500);
            con.setRequestProperty("Cache-Control","no-store, no-cache");
            int code=con.getResponseCode();
            // 405 is legitimate if a V6 proxy accepts GET but rejects HEAD.
            // Redirects, auth failures and server errors are not healthy.
            return (code>=200&&code<300)||code==405;
        }catch(Exception ignored){
            // TLS/hostname verification remains mandatory: never bypass SSL.
            return false;
        }finally{
            if(con!=null)con.disconnect();
        }
    }
    private void publishHostState(boolean ready,boolean recovered){
        if(view==null)return;
        String javascript="(function(){"+
            "window.__BBNativeV6Health=true;"+
            "var w=window.BBMobileOfflineWorkspaceV1;"+
            "if(w&&typeof w.setConnection==='function')w.setConnection("+ready+");"+
            (recovered?
              "window.dispatchEvent(new Event('bb:mobile-reconnected'));":"")+
            "})()";
        // No JavaScript bridge, tokens, or reload: update only connection state.
        view.evaluateJavascript(javascript,null);
    }
    private final Handler reconnectHandler=new Handler(Looper.getMainLooper());
    private int retryAttempts=0;
    private final Runnable retryOpen=new Runnable(){
        @Override public void run(){
            if(isFinishing()||view==null||problemOverlay==null||
                    problemOverlay.getVisibility()!=View.VISIBLE)return;
            view.loadUrl(HOME);
        }
    };
    private void scheduleRetry(){
        if(isFinishing())return;
        reconnectHandler.removeCallbacks(retryOpen);
        // 4s -> 8s -> 15s, then stay at 15s until V6 is ready.
        long delay=Math.min(15000L,4000L << Math.min(retryAttempts++,2));
        reconnectHandler.postDelayed(retryOpen,delay);
    }
    private void stopRetry(){
        reconnectHandler.removeCallbacks(retryOpen);
        retryAttempts=0;
    }

    @Override public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().setStatusBarColor(Color.rgb(10,36,64));
        getWindow().setNavigationBarColor(Color.rgb(10,36,64));
        FrameLayout frame = new FrameLayout(this);
        // Keep Local Brain pages below Android 15+ system status/navigation bars.
        // The dark background makes white status icons legible.
        frame.setBackgroundColor(Color.rgb(10,36,64));
        protectSystemBars(frame);
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
                    scheduleRetry();
                }
            }
            @Override public void onPageFinished(WebView web,String url) {
                if (!loadFailed) {
                    stopRetry();
                    problemOverlay.setVisibility(View.GONE);
                }
                if(hostChecked)publishHostState(hostReachable,hostReachable);
            }
            @Override public void onReceivedSslError(WebView web,SslErrorHandler handler,SslError error) {
                handler.cancel(); // Never accept invalid local HTTPS certificates.
                loadFailed=true;
                problemOverlay.setVisibility(View.VISIBLE);
                scheduleRetry();
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
        hint.setText("Local Brain is unavailable. This app will automatically reconnect when V6 and Caddy HTTPS start. Check company Wi-Fi if needed. Do not clear app data; saved offline screens belong to this app.");
        hint.setTextSize(15f);
        hint.setTextColor(Color.rgb(48,63,80));
        hint.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(-1,-2);
        p.setMargins(0,dp(12),0,dp(18));
        message.addView(hint,p);
        Button retry = new Button(this);
        retry.setText("RETRY LOCAL BRAIN");
        retry.setOnClickListener(v -> {
            reconnectHandler.removeCallbacks(retryOpen);
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

    private int dp(int v){return (int)(getResources().getDisplayMetrics().density*v+0.5f);}
    @Override public void onBackPressed(){
        if(view!=null && view.canGoBack())view.goBack();
        else super.onBackPressed();
    }
    @Override protected void onPause(){
        foreground=false;
        reconnectHandler.removeCallbacks(healthTick);
        reconnectHandler.removeCallbacks(retryOpen);
        super.onPause();
    }
    @Override protected void onResume(){
        super.onResume();
        foreground=true;
        // On every return, check V6 immediately; do not wait for Wi-Fi events.
        reconnectHandler.removeCallbacks(healthTick);
        reconnectHandler.post(healthTick);
        if(problemOverlay!=null&&problemOverlay.getVisibility()==View.VISIBLE)scheduleRetry();
    }
    @Override protected void onDestroy(){
        foreground=false;
        reconnectHandler.removeCallbacks(healthTick);
        reconnectHandler.removeCallbacks(retryOpen);
        healthWorker.shutdownNow();
        if(view!=null){view.stopLoading();view.destroy();view=null;}
        super.onDestroy();
    }
}
