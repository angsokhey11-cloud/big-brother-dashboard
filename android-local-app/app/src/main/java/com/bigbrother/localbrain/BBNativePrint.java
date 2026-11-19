package com.bigbrother.localbrain;

import android.app.Activity;
import android.content.Context;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.os.Bundle;
import android.os.CancellationSignal;
import android.os.ParcelFileDescriptor;
import android.print.PageRange;
import android.print.PrintAttributes;
import android.print.PrintDocumentAdapter;
import android.print.PrintManager;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceError;
import android.widget.Toast;
import androidx.webkit.WebViewCompat;
import androidx.webkit.WebViewFeature;
import org.json.JSONObject;
import java.util.Arrays;
import java.util.HashSet;

/** Print only an explicitly submitted invoice in an isolated, non-networked WebView. */
final class BBNativePrint {
    private final Activity activity;
    private final WebView browser;
    private final Handler ui = new Handler(Looper.getMainLooper());
    private WebView renderer;
    private boolean launched;
    private Runnable loadTimeout;
    private BBNativePrint(Activity a, WebView b) { activity=a; browser=b; }

    static BBNativePrint install(Activity a,WebView b) {
        if(!WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)) return null;
        BBNativePrint helper=new BBNativePrint(a,b);
        WebViewCompat.addWebMessageListener(b,"BBNativePrint",
            new HashSet<>(Arrays.asList("https://bigbrother.local:8443","https://angsokhey11-cloud.github.io")),
            (view,msg,origin,mainFrame,reply)->{
                if(msg.getType()!=androidx.webkit.WebMessageCompat.TYPE_STRING) return;
                final String data=msg.getData();
                a.runOnUiThread(()->{
                    if(!helper.authorized(origin)||a.isFinishing()||a.isDestroyed())return;
                    if(data==null||data.length()>2_000_000){helper.toast("Invoice print document is too large.");return;}
                    try{
                        JSONObject p=new JSONObject(data);
                        if(!"printInvoice".equals(p.optString("action"))) return;
                        String html=p.getString("html");
                        String layout=p.optString("layout","a4");
                        if(html.isEmpty()||!("a4".equals(layout)||"a5x2".equals(layout)))
                            throw new IllegalArgumentException("Unsupported print document.");
                        helper.start(html,p.optString("title","BIG BROTHER Invoice"),"a5x2".equals(layout));
                    }catch(Exception e){helper.toast("Could not print invoice: "+e.getMessage());}
                });
            });
        return helper;
    }

    private boolean authorized(Uri source) {
        Uri top=Uri.parse(browser.getUrl()==null?"":browser.getUrl());
        boolean local="https".equalsIgnoreCase(source.getScheme())&&"bigbrother.local".equalsIgnoreCase(source.getHost())&&source.getPort()==8443;
        boolean online="https".equalsIgnoreCase(source.getScheme())&&"angsokhey11-cloud.github.io".equalsIgnoreCase(source.getHost())&&(source.getPort()==-1||source.getPort()==443);
        return (local||online)&&"https".equalsIgnoreCase(top.getScheme())&&"bigbrother.local".equalsIgnoreCase(top.getHost())&&top.getPort()==8443&&top.getPath()!=null&&top.getPath().startsWith("/big-brother-dashboard/");
    }
    private void toast(String message){Toast.makeText(activity,message,Toast.LENGTH_LONG).show();}
    private void release(WebView view){
        if(renderer!=view)return;
        if(loadTimeout!=null){ui.removeCallbacks(loadTimeout);loadTimeout=null;}
        renderer=null;
        launched=false;
        view.stopLoading();
        view.destroy();
    }
    private void start(String html,String title,boolean landscape) {
        if(renderer!=null){toast("Finish the current print preview first.");return;}
        PrintManager pm=(PrintManager)activity.getSystemService(Context.PRINT_SERVICE);
        if(pm==null){toast("Android print service unavailable.");return;}
        String clean=title.replaceAll("[\\p{Cntrl}]"," ").trim();
        final String name=clean.isEmpty()?"BIG BROTHER Invoice":clean.substring(0,Math.min(clean.length(),120));
        WebView view=new WebView(activity);
        renderer=view;
        launched=false;
        // No privileged bridge, script execution, files, cookies written by scripts or network fetches.
        view.getSettings().setJavaScriptEnabled(false);
        view.getSettings().setAllowFileAccess(false);
        view.getSettings().setAllowContentAccess(false);
        view.getSettings().setBlockNetworkLoads(true);
        view.getSettings().setDomStorageEnabled(false);
        view.getSettings().setSupportMultipleWindows(false);
        view.getSettings().setJavaScriptCanOpenWindowsAutomatically(false);
        view.setWebViewClient(new WebViewClient(){
            @Override public boolean shouldOverrideUrlLoading(WebView v,WebResourceRequest r){return true;}
            @Override public void onReceivedError(WebView v,WebResourceRequest r,WebResourceError error){
                if(r.isForMainFrame()&&renderer==v&&!launched){toast("Invoice print document could not be loaded.");release(v);}
            }
            @Override public void onPageFinished(WebView v,String url){
                if(renderer!=v||launched||activity.isFinishing()||activity.isDestroyed())return;
                launched=true;
                if(loadTimeout!=null){ui.removeCallbacks(loadTimeout);loadTimeout=null;}
                try{
                    PrintDocumentAdapter delegate=v.createPrintDocumentAdapter(name);
                    PrintDocumentAdapter adapter=new PrintDocumentAdapter(){
                        @Override public void onStart(){delegate.onStart();}
                        @Override public void onLayout(PrintAttributes oldA,PrintAttributes newA,CancellationSignal c,LayoutResultCallback cb,Bundle extras){delegate.onLayout(oldA,newA,c,cb,extras);}
                        @Override public void onWrite(PageRange[] pages,ParcelFileDescriptor dest,CancellationSignal c,WriteResultCallback cb){delegate.onWrite(pages,dest,c,cb);}
                        @Override public void onFinish(){try{delegate.onFinish();}finally{ui.post(()->release(v));}}
                    };
                    PrintAttributes attrs=new PrintAttributes.Builder()
                        .setMediaSize(landscape?PrintAttributes.MediaSize.ISO_A4.asLandscape():PrintAttributes.MediaSize.ISO_A4.asPortrait())
                        .setMinMargins(landscape?PrintAttributes.Margins.NO_MARGINS:new PrintAttributes.Margins(394,394,394,394))
                        .setColorMode(PrintAttributes.COLOR_MODE_COLOR).build();
                    pm.print(name,adapter,attrs);
                }catch(Exception e){toast("Could not open Android print dialog.");release(v);}
            }
        });
        loadTimeout=()->{if(renderer==view&&!launched){toast("Invoice print preparation timed out.");release(view);}};
        ui.postDelayed(loadTimeout,15000);
        try{view.loadDataWithBaseURL(null,html,"text/html","UTF-8",null);}
        catch(Exception e){release(view);throw e;}
    }
    void destroy(){
        // Activity destruction must not invalidate a live spooler adapter.
        // The framework adapter's onFinish releases the active renderer.
        if(renderer!=null&&!launched)release(renderer);
    }
}
