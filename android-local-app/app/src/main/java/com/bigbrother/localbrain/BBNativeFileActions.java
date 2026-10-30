package com.bigbrother.localbrain;

import android.app.Activity;
import android.content.ClipData;
import android.content.Intent;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.util.Base64;
import android.widget.Toast;
import android.webkit.WebView;
import androidx.core.content.FileProvider;
import androidx.webkit.WebViewCompat;
import androidx.webkit.WebViewFeature;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * The only web-to-native export capability in BIG BROTHER Local Brain.
 * AndroidX's origin-scoped WebMessageListener (NOT addJavascriptInterface)
 * protects this object from unrelated web origins. No read-file, microphone,
 * camera, Supabase or arbitrary intent APIs. Every share/save opens an
 * Android chooser or document picker requiring user confirmation.
 */
final class BBNativeFileActions {
    static final int SAVE_REQUEST=4135;
    private static final String ORIGIN="https://bigbrother.local:8443";
    // Our Local dashboard still embeds the published BIG BROTHER Receivable
    // route from GitHub Pages. Allow only that trusted source origin when
    // the TOP frame remains our Local Brain dashboard.
    private static final String RECEIVABLE_ORIGIN="https://angsokhey11-cloud.github.io";
    private static final int MAX_FILES=12;
    private static final int MAX_FILE=18*1024*1024;
    private static final int MAX_TOTAL=24*1024*1024;
    private final Activity activity;
    private final WebView browser;
    private final Handler ui=new Handler(Looper.getMainLooper());
    private File pendingSave=null;

    private BBNativeFileActions(Activity activity,WebView browser){
        this.activity=activity;this.browser=browser;
    }

    static BBNativeFileActions install(Activity activity,WebView browser){
        if(!WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER))
            return null;
        BBNativeFileActions helper=new BBNativeFileActions(activity,browser);
        WebViewCompat.addWebMessageListener(browser,"BBNativeFiles",
            new java.util.HashSet<>(java.util.Arrays.asList(ORIGIN,RECEIVABLE_ORIGIN)),
            (view,message,sourceOrigin,isMainFrame,reply)->{
                if(!helper.authorized(sourceOrigin))return;
                if(message.getType()!=androidx.webkit.WebMessageCompat.TYPE_STRING)return;
                String content=message.getData();
                if(content==null||content.length()>36*1024*1024){
                    helper.toast("Export too large. Select fewer invoices.");
                    return;
                }
                new Thread(()->helper.process(content,reply),"BB-File-Export").start();
            });
        return helper;
    }

    private boolean authorized(Uri source){
        Uri top=Uri.parse(browser.getUrl()==null?"":browser.getUrl());
        boolean localSource="https".equalsIgnoreCase(source.getScheme()) &&
            "bigbrother.local".equalsIgnoreCase(source.getHost()) && source.getPort()==8443;
        boolean publishedReceivable="https".equalsIgnoreCase(source.getScheme()) &&
            "angsokhey11-cloud.github.io".equalsIgnoreCase(source.getHost()) &&
            (source.getPort()==-1||source.getPort()==443);
        boolean trustedLocalDashboard="https".equalsIgnoreCase(top.getScheme()) &&
            "bigbrother.local".equalsIgnoreCase(top.getHost()) && top.getPort()==8443 &&
            top.getPath()!=null && top.getPath().startsWith("/big-brother-dashboard/");
        return trustedLocalDashboard && (localSource||publishedReceivable);
    }

    private void toast(String msg){
        ui.post(()->Toast.makeText(activity,msg,Toast.LENGTH_LONG).show());
    }

    private String supportedMime(String type,String name){
        String mime=(type==null?"":type).split(";",2)[0].trim().toLowerCase(java.util.Locale.ROOT);
        String lower=(name==null?"":name).toLowerCase(java.util.Locale.ROOT);
        String byName="";
        if(lower.endsWith(".pdf"))byName="application/pdf";
        else if(lower.endsWith(".png"))byName="image/png";
        else if(lower.endsWith(".jpg")||lower.endsWith(".jpeg"))byName="image/jpeg";
        else if(lower.endsWith(".webp"))byName="image/webp";
        else if(lower.endsWith(".gif"))byName="image/gif";
        else if(lower.endsWith(".zip"))byName="application/zip";
        else if(lower.endsWith(".txt"))byName="text/plain";
        boolean allowed=mime.equals("application/pdf")||mime.equals("image/png")||
            mime.equals("image/jpeg")||mime.equals("image/webp")||
            mime.equals("image/gif")||mime.equals("application/zip")||
            mime.equals("text/plain");
        if(allowed){
            if(!byName.isEmpty()&&!byName.equals(mime))
                throw new IllegalArgumentException("File name and MIME type disagree.");
            return mime;
        }
        if(!byName.isEmpty()&&(mime.isEmpty()||mime.equals("application/octet-stream")))
            return byName;
        throw new IllegalArgumentException("Unsupported export MIME type.");
    }

    private String safeName(String value,String type){
        String stem=(value==null?"BIG-BROTHER-export":value)
            .replaceAll("[\\\\/:*?\"<>|\\p{Cntrl}]","_").trim()
            .replaceFirst("(?i)\\.(pdf|png|jpe?g|webp|gif|zip|txt)$","");
        stem=stem.replaceAll("[.\\s]+$","").trim();
        if(stem.isEmpty())stem="BIG-BROTHER-export";
        String ext;
        switch(type){
            case "application/pdf":ext=".pdf";break;
            case "image/png":ext=".png";break;
            case "image/jpeg":ext=".jpg";break;
            case "image/webp":ext=".webp";break;
            case "image/gif":ext=".gif";break;
            case "application/zip":ext=".zip";break;
            case "text/plain":ext=".txt";break;
            default:throw new IllegalArgumentException("Unsupported export MIME type.");
        }
        // Truncate the BASE, not the full filename. Keep UTF-8 under 175
        // bytes and preserve the extension even with long Khmer names.
        int used=ext.getBytes(java.nio.charset.StandardCharsets.UTF_8).length;
        StringBuilder shortened=new StringBuilder();
        for(int pos=0;pos<stem.length();){
            int cp=stem.codePointAt(pos);
            String character=new String(Character.toChars(cp));
            int next=character.getBytes(java.nio.charset.StandardCharsets.UTF_8).length;
            if(used+next>175)break;
            shortened.append(character);
            used+=next;pos+=Character.charCount(cp);
        }
        if(shortened.length()==0)shortened.append("BIG-BROTHER-export");
        return shortened.toString()+ext;
    }

    private void report(androidx.webkit.JavaScriptReplyProxy reply,
        int requestId,boolean accepted,String message){
        if(requestId<0)return;
        try{
            JSONObject status=new JSONObject();
            status.put("requestId",requestId);
            status.put("ok",accepted);
            status.put("message",message==null?"":message);
            String payload=status.toString();
            ui.post(()->{
                try{reply.postMessage(payload);}
                catch(Exception ignored){}
            });
        }catch(Exception ignored){}
    }

    private void process(String json,androidx.webkit.JavaScriptReplyProxy reply){
        int requestId=-1;
        try{
            JSONObject command=new JSONObject(json);
            requestId=command.optInt("requestId",-1);
            String action=command.optString("action","");
            // Read-only health check: confirms trusted frame origin, listener,
            // and reply channel without receiving customer data or opening files.
            if("ping".equals(action)){
                report(reply,requestId,true,"BIG BROTHER native file bridge active");
                return;
            }
            if(!"save".equals(action)&&!"share".equals(action)&&!"open".equals(action))
                throw new IllegalArgumentException("Unsupported action.");
            JSONArray entries=command.getJSONArray("files");
            if(entries.length()<1||entries.length()>MAX_FILES)
                throw new IllegalArgumentException("Select at most 12 files.");
            if(!"share".equals(action)&&entries.length()!=1)
                throw new IllegalArgumentException("Select one file for this action.");
            File folder=new File(activity.getCacheDir(),"bb_exports");
            if(!folder.exists()&&!folder.mkdirs())
                throw new IllegalStateException("Could not create private export folder.");
            List<File> files=new ArrayList<>();
            List<String> types=new ArrayList<>();
            int total=0;
            for(int i=0;i<entries.length();i++){
                JSONObject entry=entries.getJSONObject(i);
                String originalName=entry.getString("name");
                String type=supportedMime(entry.optString("type"),originalName);
                String name=safeName(originalName,type);
                byte[] bytes=Base64.decode(entry.getString("data"),Base64.DEFAULT);
                if(bytes.length<1||bytes.length>MAX_FILE)
                    throw new IllegalArgumentException("Generated file too large.");
                total+=bytes.length;
                if(total>MAX_TOTAL)throw new IllegalArgumentException("Too many bytes in export.");
                File output=new File(folder,System.currentTimeMillis()+"_"+i+"_"+name);
                try(FileOutputStream stream=new FileOutputStream(output)){
                    stream.write(bytes);
                }
                files.add(output);types.add(type);
            }
            final int request=requestId;
            ui.post(()->{
                try{
                    if("save".equals(action))saveFile(files.get(0),types.get(0));
                    else if("open".equals(action))openFile(files.get(0),types.get(0));
                    else shareFiles(files,types);
                    // Accepted means chooser opened, not that a recipient received it.
                    report(reply,request,true,"Android file chooser opened.");
                }catch(Exception error){
                    report(reply,request,false,error.getMessage());
                    Toast.makeText(activity,"Export: "+error.getMessage(),Toast.LENGTH_LONG).show();
                }
            });
        }catch(Exception error){
            report(reply,requestId,false,error.getMessage());
            toast("Export unavailable: "+error.getMessage());
        }
    }

    private Uri contentUri(File file){
        return FileProvider.getUriForFile(activity,activity.getPackageName()+".camera.fileprovider",file);
    }

    private void saveFile(File file,String type){
        pendingSave=file;
        Intent intent=new Intent(Intent.ACTION_CREATE_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType(type);
        String name=file.getName().replaceFirst("^[0-9]+_[0-9]+_","");
        intent.putExtra(Intent.EXTRA_TITLE,name);
        activity.startActivityForResult(intent,SAVE_REQUEST);
    }

    private void openFile(File file,String type){
        Intent intent=new Intent(Intent.ACTION_VIEW);
        intent.setDataAndType(contentUri(file),type);
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        activity.startActivity(Intent.createChooser(intent,"Open BIG BROTHER file"));
    }

    private void shareFiles(List<File> files,List<String> types){
        boolean multiple=files.size()>1;
        String type=types.get(0);
        for(String candidate:types)if(!type.equals(candidate)){type="*/*";break;}
        Intent intent=new Intent(multiple?Intent.ACTION_SEND_MULTIPLE:Intent.ACTION_SEND);
        intent.setType(type);
        ArrayList<Uri> uris=new ArrayList<>();
        for(File file:files)uris.add(contentUri(file));
        if(multiple)intent.putParcelableArrayListExtra(Intent.EXTRA_STREAM,uris);
        else intent.putExtra(Intent.EXTRA_STREAM,uris.get(0));
        ClipData clip=ClipData.newUri(activity.getContentResolver(),"BIG BROTHER Invoice",uris.get(0));
        for(int i=1;i<uris.size();i++)clip.addItem(new ClipData.Item(uris.get(i)));
        intent.setClipData(clip);
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        activity.startActivity(Intent.createChooser(intent,"Share BIG BROTHER invoice"));
    }

    boolean onActivityResult(int requestCode,int resultCode,Intent data){
        if(requestCode!=SAVE_REQUEST)return false;
        File from=pendingSave;pendingSave=null;
        if(resultCode!=Activity.RESULT_OK||data==null||data.getData()==null||from==null)return true;
        Uri destination=data.getData();
        new Thread(()->{
            try(InputStream input=new java.io.FileInputStream(from);
                OutputStream output=activity.getContentResolver().openOutputStream(destination)){
                if(output==null)throw new IllegalStateException("Destination unavailable.");
                byte[] buffer=new byte[65536];
                int read;while((read=input.read(buffer))!=-1)output.write(buffer,0,read);
                toast("BIG BROTHER file saved.");
            }catch(Exception error){toast("Could not save file: "+error.getMessage());}
        },"BB-Save-Export").start();
        return true;
    }
}