package com.bigbrother.nativev2;

import android.content.Context;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.pm.Signature;
import android.os.Build;
import org.json.JSONObject;
import org.json.JSONArray;
import java.io.*;
import java.net.URL;
import javax.net.ssl.HttpsURLConnection;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.HashSet;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/** Updates are separate by flavor. Never executes downloaded code inside the app. */
final class AppUpdater {
    private static final String REPO="angsokhey11-cloud/big-brother-dashboard";
    private static final long LIMIT=150L*1024*1024;
    static final class Offer {
        final long version,size;final String url,digest,name;
        Offer(long version,long size,String url,String digest,String name){
            this.version=version;this.size=size;this.url=url;this.digest=digest;this.name=name;
        }
    }
    private static String channel(){return "native-v2-"+BuildConfig.FLAVOR+"-dev";}
    private static long installedVersion(Context context)throws Exception{
        PackageInfo p=context.getPackageManager().getPackageInfo(context.getPackageName(),0);
        return Build.VERSION.SDK_INT>=28?p.getLongVersionCode():p.versionCode;
    }
    static Offer check(Context context)throws Exception{
        if ("local".equals(BuildConfig.FLAVOR)) return checkLocal(context);
        URL url=new URL("https://api.github.com/repos/"+REPO+"/releases/tags/"+channel());
        HttpsURLConnection conn=open(url);
        try{
            conn.setRequestProperty("Accept","application/vnd.github+json");
            int status=conn.getResponseCode();
            if(status==404)return null;
            if(status!=200)throw new IOException("Update catalog unavailable");
            JSONObject release;
            try(InputStream in=conn.getInputStream();ByteArrayOutputStream out=new ByteArrayOutputStream()){
                byte[] b=new byte[8192];int n;
                while((n=in.read(b))!=-1){if(out.size()+n>1024*1024)throw new IOException("Catalog too large");out.write(b,0,n);}
                release=new JSONObject(out.toString("UTF-8"));
            }
            if(release.optBoolean("draft",true)||!channel().equals(release.optString("tag_name")))throw new IOException("Wrong update channel");
            JSONArray assets=release.getJSONArray("assets");
            long current=installedVersion(context);Offer best=null;
            Pattern pattern=Pattern.compile("BIG-BROTHER-"+BuildConfig.FLAVOR+"-v2dev-([0-9]+)\\.apk");
            for(int i=0;i<assets.length();i++){
                JSONObject a=assets.getJSONObject(i);String name=a.optString("name");
                Matcher m=pattern.matcher(name);if(!m.matches())continue;
                long version=Long.parseLong(m.group(1)),size=a.optLong("size",-1);
                String digest=a.optString("digest"),download=a.optString("browser_download_url");
                String expected="https://github.com/"+REPO+"/releases/download/"+channel()+"/"+name;
                if(version<=current||version>Integer.MAX_VALUE||size<=0||size>LIMIT||
                   !digest.matches("sha256:[a-fA-F0-9]{64}")||!expected.equals(download))continue;
                if(best==null||version>best.version)best=new Offer(version,size,download,digest.substring(7),name);
            }
            return best;
        }finally{conn.disconnect();}
    }
    private static Offer checkLocal(Context context)throws Exception{
        try(okhttp3.Response conn=LocalTransport.client().newCall(LocalTransport.request("/v6-mobile-update/manifest.json").get().build()).execute()){
            int status=conn.code();
            if(status==404)return null;
            if(status!=200)throw new IOException("Local update catalog unavailable");
            JSONObject data=new JSONObject(LocalTransport.read(conn,65536));
            if(!"native-v2-local-dev".equals(data.optString("channel")))throw new IOException("Wrong Local channel");
            long version=data.getLong("versionCode"),size=data.getLong("size");
            String name=data.getString("name"),digest=data.getString("sha256");
            if(version<=installedVersion(context))return null;
            if(version>Integer.MAX_VALUE||size<=0||size>LIMIT||
               !name.equals("BIG-BROTHER-local-v2dev-"+version+".apk")||!digest.matches("[a-fA-F0-9]{64}"))
                throw new IOException("Invalid Local update manifest");
            return new Offer(version,size,BuildConfig.ENDPOINT+"/v6-mobile-update/"+name,digest,name);
        }
    }
    private static HttpsURLConnection open(URL url)throws IOException{
        String host=url.getHost();
        boolean local="local".equals(BuildConfig.FLAVOR);
        boolean allowed=local?("bigbrother.local".equals(host)&&url.getPort()==8443):
            ((url.getPort()==-1||url.getPort()==443)&&("github.com".equals(host)||"api.github.com".equals(host)||"release-assets.githubusercontent.com".equals(host)||"objects.githubusercontent.com".equals(host)));
        if(!"https".equals(url.getProtocol())||url.getUserInfo()!=null||!allowed)
            throw new IOException("Unexpected update server");
        HttpsURLConnection c=(HttpsURLConnection)url.openConnection();
        c.setInstanceFollowRedirects(false);c.setConnectTimeout(10000);c.setReadTimeout(15000);c.setUseCaches(false);
        c.setRequestProperty("User-Agent","BIG-BROTHER-Mobile-V2");return c;
    }
    static File download(Context context,Offer offer)throws Exception{
        File folder=new File(context.getCacheDir(),"apk_updates");
        if(!folder.exists()&&!folder.mkdirs())throw new IOException("Update storage unavailable");
        File apk=File.createTempFile("bb-update-",".apk",folder);
        boolean ok=false;
        try{
            if("local".equals(BuildConfig.FLAVOR)){
                try(okhttp3.Response response=LocalTransport.client().newBuilder().callTimeout(5,java.util.concurrent.TimeUnit.MINUTES).build().newCall(LocalTransport.request("/v6-mobile-update/"+offer.name).get().build()).execute()){
                    if(!response.isSuccessful()||response.body()==null)throw new IOException("Local APK download failed");
                    MessageDigest sha=MessageDigest.getInstance("SHA-256");long total=0;
                    try(InputStream in=response.body().byteStream();FileOutputStream out=new FileOutputStream(apk)){
                        byte[] bytes=new byte[32768];int n;
                        while((n=in.read(bytes))!=-1){total+=n;if(total>offer.size||total>LIMIT)throw new IOException("Update exceeds expected size");sha.update(bytes,0,n);out.write(bytes,0,n);}
                    }
                    if(total!=offer.size||!hex(sha.digest()).equalsIgnoreCase(offer.digest))throw new IOException("Update integrity check failed");
                    verify(context,apk,offer.version);ok=true;return apk;
                }
            }
            URL url=new URL(offer.url);
            for(int redirects=0;redirects<=5;redirects++){
                HttpsURLConnection conn=open(url);
                try{
                    int status=conn.getResponseCode();
                    if(status==301||status==302||status==303||status==307||status==308){
                        if("local".equals(BuildConfig.FLAVOR))throw new IOException("Local update redirects are disabled");
                        String next=conn.getHeaderField("Location");if(next==null)throw new IOException("Missing redirect");
                        url=new URL(url,next);continue;
                    }
                    if(status!=200)throw new IOException("Download failed");
                    MessageDigest sha=MessageDigest.getInstance("SHA-256");long total=0;
                    try(InputStream in=conn.getInputStream();FileOutputStream out=new FileOutputStream(apk)){
                        byte[] bytes=new byte[32768];int n;
                        while((n=in.read(bytes))!=-1){total+=n;if(total>offer.size||total>LIMIT)throw new IOException("Update exceeds expected size");sha.update(bytes,0,n);out.write(bytes,0,n);}
                    }
                    if(total!=offer.size||!hex(sha.digest()).equalsIgnoreCase(offer.digest))throw new IOException("Update integrity check failed");
                    verify(context,apk,offer.version);
                    ok=true;return apk;
                }finally{conn.disconnect();}
            }
            throw new IOException("Too many redirects");
        }finally{if(!ok)apk.delete();}
    }
    private static String hex(byte[] bytes){
        StringBuilder s=new StringBuilder();for(byte b:bytes)s.append(String.format(java.util.Locale.ROOT,"%02x",b&255));return s.toString();
    }
    private static Set<String> signers(PackageInfo p)throws Exception{
        Signature[] signatures=Build.VERSION.SDK_INT>=28?(p.signingInfo==null?null:p.signingInfo.getApkContentsSigners()):p.signatures;
        if(signatures==null||signatures.length==0)throw new IOException("Signing certificate unavailable");
        Set<String> values=new HashSet<>();
        for(Signature s:signatures)values.add(hex(MessageDigest.getInstance("SHA-256").digest(s.toByteArray())));
        return values;
    }
    private static void verify(Context context,File apk,long expected)throws Exception{
        PackageManager pm=context.getPackageManager();
        int flags=Build.VERSION.SDK_INT>=28?PackageManager.GET_SIGNING_CERTIFICATES:PackageManager.GET_SIGNATURES;
        PackageInfo old=pm.getPackageInfo(context.getPackageName(),flags),next=pm.getPackageArchiveInfo(apk.getAbsolutePath(),flags);
        if(next==null||!context.getPackageName().equals(next.packageName))throw new IOException("Wrong application package");
        long version=Build.VERSION.SDK_INT>=28?next.getLongVersionCode():next.versionCode;
        if(version!=expected||version<=installedVersion(context))throw new IOException("Wrong update version");
        if(!signers(old).equals(signers(next)))throw new IOException("Signing certificate mismatch");
    }
}
