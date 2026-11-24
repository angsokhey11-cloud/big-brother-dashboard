package com.bigbrother.online;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.content.pm.*;
import android.net.Uri;
import android.os.Build;
import android.os.SystemClock;
import android.provider.Settings;
import android.view.View;
import android.widget.*;
import androidx.core.content.FileProvider;
import org.json.*;
import java.io.*;
import java.net.URL;
import javax.net.ssl.HttpsURLConnection;
import java.security.MessageDigest;
import java.util.*;
import java.util.concurrent.*;
import java.util.regex.*;

/** App-only updates; the existing PWA and accounting session remain untouched. */
final class BundledUpdate {
    static final String REPO="angsokhey11-cloud/big-brother-dashboard";
    static final String TAG="bundled-online-dev";
    static final long LIMIT=150L*1024*1024;
    final Activity a;
    private AlertDialog settingsDialog,offerDialog,progressDialog,installDialog;
    private TextView progressTitle,progressDetail;private ProgressBar progressBar;
    private boolean firstCheck=true,installPromptPending=false;
    private final android.os.Handler ui=new android.os.Handler(android.os.Looper.getMainLooper());private boolean foreground;private long promptedVersion;private String actionText="Check";
    private androidx.webkit.JavaScriptReplyProxy settingsReply;
    final ExecutorService worker=Executors.newSingleThreadExecutor();
    private boolean dead,busy;private long lastCheck=-60000;private Offer offer;private File ready;
    private String currentName="Installed version";private String lastStatus="Ready to check for updates";
    static final class Offer {
        final long version,size;final String name,url,digest;
        Offer(long v,long s,String n,String u,String d){version=v;size=s;name=n;url=u;digest=d;}
    }
    BundledUpdate(Activity a){
        this.a=a;
        try{currentName="V"+a.getPackageManager().getPackageInfo(a.getPackageName(),0).versionName.replace("-bundled-dev","");}catch(Exception ignored){}
        show(currentName+" · Ready to check","Check");
    }
    void attach(android.webkit.WebView browser){
        if(!androidx.webkit.WebViewFeature.isFeatureSupported(androidx.webkit.WebViewFeature.WEB_MESSAGE_LISTENER))return;
        androidx.webkit.WebViewCompat.addWebMessageListener(browser,"BBNativeAppUpdate",
            Collections.singleton("https://app.bigbrother.test"),(view,message,origin,main,reply)->{
                if(!main||!"https://app.bigbrother.test".equals(origin.toString()))return;
                Uri page=Uri.parse(view.getUrl()==null?"":view.getUrl());
                if(!"https".equals(page.getScheme())||!"app.bigbrother.test".equals(page.getHost())||
                   !"/big-brother-dashboard/mobile.html".equals(page.getPath()))return;
                if(message.getType()!=androidx.webkit.WebMessageCompat.TYPE_STRING)return;
                String cmd=message.getData();
                if(!"status".equals(cmd)&&!"open".equals(cmd))return;
                a.runOnUiThread(()->{if(dead)return;settingsReply=reply;sendStatus();if("open".equals(cmd)&&foreground)openSettings();});
            });
    }
    void resume(){foreground=true;maybePrompt();maybeInstallPrompt();}
    void pause(){foreground=false;closeProgress();if(offerDialog!=null){offerDialog.dismiss();offerDialog=null;}if(installDialog!=null){installDialog.dismiss();installDialog=null;}}
    private void sendStatus(){
        if(settingsReply==null)return;
        try{JSONObject o=new JSONObject();o.put("version",currentName);o.put("status",lastStatus);o.put("busy",busy);settingsReply.postMessage(o.toString());}
        catch(Exception ignored){settingsReply=null;}
    }
    private void openSettings(){
        if(dead||!foreground||a.isFinishing()||a.isDestroyed())return;
        if(settingsDialog!=null&&settingsDialog.isShowing())return;
        settingsDialog=new AlertDialog.Builder(a).setTitle("Application update")
            .setMessage(lastStatus).setNegativeButton("Close",null).setPositiveButton(actionText,null).create();
        settingsDialog.setOnShowListener(d->{settingsDialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener(v->onAction());refreshSettings();});
        settingsDialog.setOnDismissListener(d->settingsDialog=null);
        settingsDialog.show();
    }
    private void refreshSettings(){
        if(settingsDialog==null||!settingsDialog.isShowing())return;
        settingsDialog.setMessage(lastStatus);
        Button b=settingsDialog.getButton(AlertDialog.BUTTON_POSITIVE);
        if(b!=null){b.setText(actionText);b.setEnabled(!busy);}
    }
    private void maybePrompt(){
        if(dead||!foreground||busy||offer==null||promptedVersion==offer.version||a.isFinishing()||a.isDestroyed())return;
        if(settingsDialog!=null&&settingsDialog.isShowing())return;
        promptedVersion=offer.version;
        offerDialog=new AlertDialog.Builder(a).setTitle("BIG BROTHER Mobile update")
            .setMessage(currentName+" → V3.0."+(offer.version-30000)+"\n\nA newer version is available. Download and install it? You can keep working during the download. Save your work before installing.")
            .setNegativeButton("Later",(d,w)->{})
            .setPositiveButton("Download & Update",(d,w)->onAction()).create();
        offerDialog.setOnDismissListener(d->offerDialog=null);
        offerDialog.show();
    }
    private int dp(float n){return Math.round(n*a.getResources().getDisplayMetrics().density);}
    private TextView line(String text,int size,int color,boolean bold){
        TextView v=new TextView(a);v.setText(text);v.setTextSize(size);v.setTextColor(color);
        v.setGravity(android.view.Gravity.CENTER);if(bold)v.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);return v;
    }
    private void openProgress(String title,String detail,boolean download){
        if(dead||!foreground||a.isFinishing()||a.isDestroyed())return;
        closeProgress();
        LinearLayout content=new LinearLayout(a);content.setOrientation(LinearLayout.VERTICAL);
        content.setGravity(android.view.Gravity.CENTER_HORIZONTAL);content.setPadding(dp(24),dp(24),dp(24),dp(12));
        content.addView(line("BIG BROTHER",24,0xff173b70,true));
        content.addView(line("M O B I L E",13,0xff52718e,true));
        content.addView(new UpdateTruckView(a),new LinearLayout.LayoutParams(-1,dp(155)));
        progressTitle=line(title,16,0xff173b70,true);content.addView(progressTitle);
        progressDetail=line(detail,12,0xff52718e,false);content.addView(progressDetail);
        progressBar=new ProgressBar(a,null,android.R.attr.progressBarStyleHorizontal);progressBar.setMax(100);progressBar.setIndeterminate(!download);
        LinearLayout.LayoutParams p=new LinearLayout.LayoutParams(-1,dp(6));p.topMargin=dp(16);p.bottomMargin=dp(16);content.addView(progressBar,p);
        content.addView(line("Fast. Reliable. Always Moving.",11,0xff52718e,false));
        progressDialog=new AlertDialog.Builder(a).setView(content).setNegativeButton("Continue working",null).create();
        final AlertDialog own=progressDialog;
        own.setOnDismissListener(d->{if(progressDialog==own){progressDialog=null;progressTitle=null;progressDetail=null;progressBar=null;}});
        own.show();
        if(!download)ui.postDelayed(()->{if(progressDialog==own)closeProgress();},7000);
    }
    private void progress(String title,String detail,int percent){
        ui.post(()->{if(dead||progressDialog==null)return;
            progressTitle.setText(title);progressDetail.setText(detail);
            progressBar.setIndeterminate(percent<0);if(percent>=0)progressBar.setProgress(percent);
        });
    }
    private void closeProgress(){if(progressDialog!=null){progressDialog.dismiss();progressDialog=null;progressTitle=null;progressDetail=null;progressBar=null;}}
    private void maybeInstallPrompt(){
        if(!installPromptPending||!foreground||dead||busy||ready==null||!ready.isFile()||a.isFinishing()||a.isDestroyed())return;
        installPromptPending=false;askInstall();
    }
    private void askInstall(){
        if(!foreground||dead||installDialog!=null)return;
        installDialog=new AlertDialog.Builder(a).setTitle("Update ready to install")
            .setMessage("Your new BIG BROTHER Mobile version has been downloaded and verified. Save or complete any unfinished work before installing. Android will close the app during installation.")
            .setNegativeButton("Later",null).setPositiveButton("Install Update",(d,w)->install()).create();
        installDialog.setOnDismissListener(d->installDialog=null);installDialog.show();
    }
    void check(){check(false);}
    private void check(boolean manual){
        if(dead||busy||offer!=null||(!manual&&SystemClock.elapsedRealtime()-lastCheck<60000))return;
        lastCheck=SystemClock.elapsedRealtime();busy=true;
        if(firstCheck||manual)openProgress("Checking for updates…","Finding the latest application version",false);
        firstCheck=false;
        show(currentName+" · Checking for updates…","Checking");
        worker.execute(()->{
            Offer result=null;String error=null;
            try{result=checkCatalog();}catch(Exception e){error=e instanceof java.net.SocketTimeoutException?"Connection timed out":e instanceof java.net.UnknownHostException?"Update server unreachable":e instanceof javax.net.ssl.SSLException?"Secure connection failed":e.getMessage();}
            final Offer found=result;final String failure=error;
            a.runOnUiThread(()->{busy=false;if(dead||a.isFinishing()||a.isDestroyed())return;
                if(found!=null){closeProgress();offer=found;show("V3.0."+(found.version-30000)+" available · "+currentName+" installed","Download");maybePrompt();}
                else {
                    if(failure!=null)show(currentName+" · "+failure,"Retry");else show(currentName+" · Up to date","Check");
                    if(progressDialog!=null){
                        final AlertDialog own=progressDialog;
                        progress(failure==null?"You're up to date!":"Continuing with your installed version…",failure==null?"Your business is on the move":failure,100);
                        ui.postDelayed(()->{if(progressDialog==own)closeProgress();},850);
                    }
                }
            });
        });
    }
    private void show(String text,String button){
        lastStatus=text;actionText=button;refreshSettings();sendStatus();
    }
    private void onAction(){
        if(dead||busy)return;
        if(offer==null){check(true);return;}
        if(ready!=null&&ready.isFile()){
            askInstall();
            return;
        }
        busy=true;show("Downloading update… You can keep working.","Downloading");
        openProgress("Downloading your update…","Preparing the new version",true);
        final Offer selected=offer;
        worker.execute(()->{
            File result=null;try{result=download(selected);}catch(Exception ignored){}
            final File file=result;
            a.runOnUiThread(()->{busy=false;if(dead||a.isDestroyed()||a.isFinishing()){if(file!=null)file.delete();return;}
                closeProgress();ready=file;show(file==null?"Update download failed · retry":"Update verified · save your work first",file==null?"Retry":"Install");
                if(file!=null){installPromptPending=true;maybeInstallPrompt();}
                else if(foreground)Toast.makeText(a,"Update download failed. Retry in Settings.",Toast.LENGTH_LONG).show();
            });
        });
    }
    private void install(){
        if(ready==null||offer==null||busy)return;
        if(!a.getPackageManager().canRequestPackageInstalls()){
            try{a.startActivity(new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,Uri.parse("package:"+a.getPackageName())));}
            catch(Exception e){Toast.makeText(a,"Allow installation from this app in Android settings.",Toast.LENGTH_LONG).show();}
            return;
        }
        busy=true;show("Verifying update…","Verifying");final File file=ready;final Offer selected=offer;
        worker.execute(()->{
            boolean verified=false;try{verify(file,selected.version);verified=hashFile(file,selected);}catch(Exception ignored){}
            final boolean ok=verified;
            a.runOnUiThread(()->{
                busy=false;if(dead||a.isDestroyed()||a.isFinishing())return;show("Update verified · ready to install","Install");
                if(!ok){file.delete();ready=null;show("Update verification failed","Retry");return;}
                try{
                    Uri uri=FileProvider.getUriForFile(a,a.getPackageName()+".camera.fileprovider",file);
                    Intent i=new Intent(Intent.ACTION_VIEW);i.setDataAndType(uri,"application/vnd.android.package-archive");
                    i.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                    i.setClipData(android.content.ClipData.newRawUri("Verified BIG BROTHER APK",uri));
                    a.startActivity(i);
                }catch(Exception e){Toast.makeText(a,"Android installer unavailable.",Toast.LENGTH_LONG).show();}
            });
        });
    }
    void destroy(){dead=true;ui.removeCallbacksAndMessages(null);closeProgress();if(installDialog!=null)installDialog.dismiss();settingsReply=null;if(settingsDialog!=null)settingsDialog.dismiss();if(offerDialog!=null)offerDialog.dismiss();worker.shutdownNow();}
    private long installedVersion()throws Exception{
        PackageInfo p=a.getPackageManager().getPackageInfo(a.getPackageName(),0);
        return Build.VERSION.SDK_INT>=28?p.getLongVersionCode():p.versionCode;
    }
    private static HttpsURLConnection open(URL url)throws IOException{
        String h=url.getHost();
        if(!"https".equals(url.getProtocol())||url.getUserInfo()!=null||(url.getPort()!=-1&&url.getPort()!=443)||
            !Arrays.asList("api.github.com","github.com","release-assets.githubusercontent.com","objects.githubusercontent.com").contains(h))
            throw new IOException("Unexpected update origin");
        HttpsURLConnection c=(HttpsURLConnection)url.openConnection();
        c.setInstanceFollowRedirects(false);c.setConnectTimeout(10000);c.setReadTimeout(20000);c.setUseCaches(false);
        c.setRequestProperty("User-Agent","BIG-BROTHER-Bundled-Android");return c;
    }
    private Offer checkCatalog()throws Exception{
        HttpsURLConnection c=open(new URL("https://api.github.com/repos/"+REPO+"/releases/tags/"+TAG));
        try{
            c.setRequestProperty("Accept","application/vnd.github+json");int status=c.getResponseCode();
            if(status==404)throw new IOException("Update channel not found (404)");
            if(status==403||status==429)throw new IOException("Update service rate limited ("+status+")");
            if(status!=200)throw new IOException("Update check failed (HTTP "+status+")");
            JSONObject release;
            try(InputStream in=c.getInputStream();ByteArrayOutputStream out=new ByteArrayOutputStream()){
                byte[] b=new byte[8192];int n;while((n=in.read(b))!=-1){if(out.size()+n>1024*1024)throw new IOException("Catalog too large");out.write(b,0,n);}
                release=new JSONObject(out.toString("UTF-8"));
            }
            if(release.optBoolean("draft",true)||!release.optBoolean("prerelease",false)||!TAG.equals(release.optString("tag_name")))throw new IOException("Wrong release channel");
            progress("Verifying application version…","Comparing available versions",80);
            JSONArray assets=release.getJSONArray("assets");long current=installedVersion();Offer best=null;boolean eligibleName=false;
            Pattern pattern=Pattern.compile("BIG-BROTHER-Online-Bundled-DEV-([0-9]+)\\.apk");
            for(int i=0;i<assets.length();i++){
                JSONObject row=assets.getJSONObject(i);String name=row.optString("name");Matcher m=pattern.matcher(name);
                if(!m.matches())continue;
                long v=Long.parseLong(m.group(1)),size=row.optLong("size",-1);String digest=row.optString("digest"),url=row.optString("browser_download_url");
                if(v>current)eligibleName=true;
                if(v<=current||v>Integer.MAX_VALUE||size<=0||size>LIMIT||!digest.matches("sha256:[a-fA-F0-9]{64}")||
                    !url.equals("https://github.com/"+REPO+"/releases/download/"+TAG+"/"+name))continue;
                if(best==null||v>best.version)best=new Offer(v,size,name,url,digest.substring(7));
            }
            if(best==null&&eligibleName)throw new IOException("New release metadata incomplete");
            return best;
        }finally{c.disconnect();}
    }
    private File download(Offer offer)throws Exception{
        File folder=new File(a.getCacheDir(),"apk_updates");
        if(!folder.exists()&&!folder.mkdirs())throw new IOException("Update storage unavailable");
        File[] old=folder.listFiles();if(old!=null)for(File item:old)if(item.getName().startsWith("bb-update-")&&System.currentTimeMillis()-item.lastModified()>86400000L)item.delete();
        File apk=File.createTempFile("bb-update-",".apk",folder);boolean ok=false;
        try{
            URL url=new URL(offer.url);
            for(int redirects=0;redirects<=5;redirects++){
                HttpsURLConnection c=open(url);
                try{
                    int status=c.getResponseCode();
                    if(status==301||status==302||status==303||status==307||status==308){String next=c.getHeaderField("Location");if(next==null)throw new IOException("Missing redirect");url=new URL(url,next);continue;}
                    if(status!=200||c.getContentLengthLong()>offer.size)throw new IOException("Download unavailable");
                    MessageDigest sha=MessageDigest.getInstance("SHA-256");long total=0;int lastPercent=-1;
                    try(InputStream in=c.getInputStream();FileOutputStream out=new FileOutputStream(apk)){
                        byte[] bytes=new byte[32768];int n;while((n=in.read(bytes))!=-1){
                            if(Thread.currentThread().isInterrupted())throw new IOException("Cancelled");
                            total+=n;if(total>offer.size||total>LIMIT)throw new IOException("APK too large");sha.update(bytes,0,n);out.write(bytes,0,n);
                            int percent=(int)(100L*total/offer.size);if(percent!=lastPercent){lastPercent=percent;progress("Downloading your update…",percent+"% downloaded",percent);}
                        }
                    }
                    progress("Checking update integrity…","Verifying APK checksum and signing certificate",-1);
                    if(total!=offer.size||!hex(sha.digest()).equalsIgnoreCase(offer.digest))throw new IOException("Update checksum mismatch");
                    verify(apk,offer.version);ok=true;return apk;
                }finally{c.disconnect();}
            }throw new IOException("Too many redirects");
        }finally{if(!ok)apk.delete();}
    }
    private boolean hashFile(File file,Offer offer)throws Exception{
        if(file.length()!=offer.size)return false;
        MessageDigest sha=MessageDigest.getInstance("SHA-256");
        try(InputStream in=new FileInputStream(file)){byte[] b=new byte[32768];int n;while((n=in.read(b))!=-1)sha.update(b,0,n);}
        return hex(sha.digest()).equalsIgnoreCase(offer.digest);
    }
    private static String hex(byte[] bytes){StringBuilder s=new StringBuilder();for(byte b:bytes)s.append(String.format(Locale.ROOT,"%02x",b&255));return s.toString();}
    private static Set<String> signers(PackageInfo p)throws Exception{
        Signature[] signatures=Build.VERSION.SDK_INT>=28?(p.signingInfo==null?null:p.signingInfo.getApkContentsSigners()):p.signatures;
        if(signatures==null||signatures.length==0)throw new IOException("Signing certificate unavailable");
        Set<String> values=new HashSet<>();for(Signature s:signatures)values.add(hex(MessageDigest.getInstance("SHA-256").digest(s.toByteArray())));return values;
    }
    private void verify(File file,long version)throws Exception{
        PackageManager pm=a.getPackageManager();int flags=Build.VERSION.SDK_INT>=28?PackageManager.GET_SIGNING_CERTIFICATES:PackageManager.GET_SIGNATURES;
        PackageInfo installed=pm.getPackageInfo(a.getPackageName(),flags),next=pm.getPackageArchiveInfo(file.getAbsolutePath(),flags);
        if(next==null||!a.getPackageName().equals(next.packageName))throw new IOException("Wrong APK package");
        long v=Build.VERSION.SDK_INT>=28?next.getLongVersionCode():next.versionCode;
        if(v!=version||v<=installedVersion()||!signers(installed).equals(signers(next)))throw new IOException("APK identity mismatch");
    }
}
