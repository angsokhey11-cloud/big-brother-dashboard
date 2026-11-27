#!/usr/bin/env python3
"""Stage existing Online Android shell + pinned PWA assets, never edit production source."""
import hashlib, json, pathlib, re, shutil, subprocess, sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
REPO = ROOT.parent
STAGE = ROOT / "build" / "android"
OLD = "angsokhey11-cloud.github.io"
HOST = "app.bigbrother.test"

def replace_once(s, old, new):
    if s.count(old) != 1:
        raise RuntimeError("Expected shell marker missing/duplicated: " + old[:100])
    return s.replace(old, new, 1)

def stage():
    # Keep build-time source packaging separate from the installed app.
    subprocess.run([sys.executable, str(ROOT / "tools/bundle_web.py")], check=True)
    if STAGE.exists(): shutil.rmtree(STAGE)
    shutil.copytree(REPO / "android-online-app", STAGE,
                    ignore=shutil.ignore_patterns("build", ".gradle", "local.properties", ".git"))
    app = STAGE / "app"
    assets = app / "src/main/assets"
    assets.mkdir(parents=True, exist_ok=True)
    shutil.copytree(ROOT / "build/web", assets, dirs_exist_ok=True)
    # Online routes now use the original current UI; cached routes remain offline-only.
    menu = assets / "big-brother-dashboard/mobile-main-menu-stockcontrol-v5.js"
    from history_fast import apply as apply_history_fast
    apply_history_fast(assets)
    from invoice_native_files import apply as apply_invoice_native_files
    apply_invoice_native_files(assets)
    file_adapter=assets/"big-brother-ar/receivable-file-actions-v1.js"
    file_source=file_adapter.read_text(encoding="utf-8")
    file_source=replace_once(file_source,"[\'save\',\'share\',\'open\'].includes(action)","[\'save\',\'share\',\'open\',\'downloadPictures\'].includes(action)")
    file_source=replace_once(file_source,"async function saveMany(files){", """async function downloadMany(files,onProgress){
 requireApkBridge();
 if(!native())throw Error('Android download bridge unavailable.');
 if(!Array.isArray(files)||!files.length||files.some(f=>f.type!=='image/png'))throw Error('Only PNG pages can be downloaded.');
 for(let i=0;i<files.length;i++){
   try{await sendNative('downloadPictures',[files[i]]);if(typeof onProgress==='function')onProgress(i+1,files.length);}
   catch(error){throw Error(i+' of '+files.length+' pictures saved. '+error.message);}
 }
 return 'native';
}
async function saveMany(files){""")
    file_source=replace_once(file_source,"save,saveMany,share,open,diagnostics,ping","save,saveMany,downloadMany,share,open,diagnostics,ping")
    file_adapter.write_text(file_source,encoding="utf-8")
    from scanner_mobile_layout import apply as apply_scanner_mobile_layout
    apply_scanner_mobile_layout(assets)
    # Daily Sale uses two installed paths: the live module and a cached read-only
    # dashboard page. Build the cached UI from the SAME pinned V2 report, retaining
    # its local data adapter and offline export/Telegram restrictions.
    live = assets / "big-brother-daily-sale-summary/legacy-google-v1.html"
    offline_page = assets / "big-brother-dashboard/mobile-offline-daily-sale-v1.html"
    original = offline_page.read_text(encoding="utf-8")
    source = live.read_text(encoding="utf-8")
    assert 'id="bbSaleFilters"' in source and 'function buildDigitalSalePages(' in source
    adapter = '<script src="mobile-offline-staff-adapter-v12.js?v=20261028-v12"></script>'
    assert adapter in original and 'window.BBStaffOfflineV12.dailyApi(params)' in original
    source = replace_once(source, '</head>', adapter + '\n<style>#shareTelegramBtn,#downloadSummaryBtn,#downloadPictureBtn{display:none!important}</style>\n</head>')
    source, count = re.subn(r'async function api\(params\)\{[^\n]*\}', 'async function api(params){return window.BBStaffOfflineV12.dailyApi(params)}', source)
    if count != 1:
        raise RuntimeError("Daily Sale offline API marker changed")
    source, count = re.subn(r'<script src="https://cdnjs\.cloudflare\.com/ajax/libs/(?:html2canvas|jspdf)/[^"]+"></script>\n?', '', source)
    if count != 2:
        raise RuntimeError("Daily Sale offline export dependencies changed")
    offline_page.write_text(source, encoding="utf-8")

    # Native file export: use the existing signed Android bridge and local libraries.
    import tempfile, tarfile
    vendor=assets/"big-brother-dashboard/vendor"
    with tempfile.TemporaryDirectory() as td:
        subprocess.run(["npm","pack","jspdf@2.5.1","--ignore-scripts","--pack-destination",td],check=True)
        with tarfile.open(pathlib.Path(td)/"jspdf-2.5.1.tgz") as tar:
            data=tar.extractfile("package/dist/jspdf.umd.min.js").read()
            assert 100000<len(data)<2000000
            (vendor/"jspdf.umd.min.js").write_bytes(data)
            (vendor/"jspdf-LICENSE.txt").write_bytes(tar.extractfile("package/LICENSE").read())
    source=live.read_text(encoding="utf-8")
    source=replace_once(source,"https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js","/big-brother-dashboard/vendor/html2canvas.min.js")
    source=replace_once(source,"https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js","/big-brother-dashboard/vendor/jspdf.umd.min.js")
    source=replace_once(source,"</head>",'<script src="/big-brother-ar/receivable-file-actions-v1.js"></script>\n</head>')
    source=replace_once(source,"    pdf.save('BIG_BROTHER_Daily_Sale_'+safeFilePart(g.saleDate)+'_'+safeFilePart(g.salesman)+'_'+safeFilePart(g.locationCode)+'.pdf');", """    const bridge=window.BBARFileActionsV1;
    if(!bridge?.isNative())throw Error('Android file bridge unavailable. Reopen BIG BROTHER.');
    await bridge.save(new File([pdf.output('blob')],'BIG_BROTHER_Daily_Sale_'+safeFilePart(g.saleDate)+'_'+safeFilePart(g.salesman)+'_'+safeFilePart(g.locationCode)+'.pdf',{type:'application/pdf'}));""")
    source=replace_once(source,"    await readySaleFonts();\n    for(let i=0;i<pages.length;i++){","    await readySaleFonts();\n    const files=[];\n    for(let i=0;i<pages.length;i++){")
    start=source.index("        const url=URL.createObjectURL(blob),link=document.createElement('a');")
    end=source.index("      }finally{canvas.width=0;canvas.height=0;}",start)
    source=source[:start]+"""        files.push(new File([blob],saleDigitalFilename(g,i,pages.length,'png'),{type:'image/png'}));
"""+source[end:]
    source=replace_once(source,"  }catch(error){console.error(error);alert(error.message||'Could not download Daily Sale picture.');}", """    const bridge=window.BBARFileActionsV1;
    if(!bridge?.isNative())throw Error('Android file bridge unavailable. Reopen BIG BROTHER.');
    const status=document.createElement('div');
    status.setAttribute('role','status');status.setAttribute('aria-live','polite');
    status.style.cssText='position:fixed;bottom:20px;left:12px;right:12px;max-width:440px;margin:auto;z-index:2147483646;background:#fff;border:1px solid #c9d8ec;border-radius:12px;padding:14px;box-shadow:0 6px 24px #17304f40;color:#17304f;font-size:14px';
    const title=document.createElement('strong'),detail=document.createElement('div'),progress=document.createElement('progress');
    title.textContent='Downloading Daily Sale Pictures';detail.style.marginTop='8px';
    progress.max=files.length;progress.value=0;progress.style.cssText='width:100%;height:12px;margin-top:8px;accent-color:#245da8';
    detail.textContent='Saving 0 of '+files.length+' pictures to Downloads';
    status.append(title,detail,progress);document.body.appendChild(status);
    let saved=0;
    try{
      await bridge.downloadMany(files,(done,total)=>{
        saved=done;progress.value=done;detail.textContent=done+' of '+total+' pictures saved · '+Math.round(done/total*100)+'%';
      });
      title.textContent='Download completed';title.style.color='#16754a';
      detail.textContent=saved+' HD PNG pictures saved to Downloads.';
      btn.textContent='Download completed';
      setTimeout(()=>status.remove(),7000);
    }catch(error){
      title.textContent='Download incomplete';title.style.color='#b42318';
      detail.textContent=saved+' of '+files.length+' pictures saved. '+error.message;
      setTimeout(()=>status.remove(),12000);throw error;
    }
  }catch(error){console.error(error);alert(error.message||'Could not download Daily Sale picture.');}""")
    live.write_text(source,encoding="utf-8")
    assert 'await bridge.downloadMany(files,(done,total)' in source and "pdf.output('blob')" in source
    assert 'const rowsPerPage=15' in source and 'bbInvoiceStage' in source

    # Keep live navigation policy and installed route version aligned.
    source = menu.read_text(encoding="utf-8")
    assert "if(!forceLive&&offline?.canUseNetwork()===false&&" in source
    source = replace_once(source,
        "/big-brother-daily-sale-summary/mobile.html?embed=1&v=20260915-1",
        "/big-brother-daily-sale-summary/mobile.html?embed=1&v=20261128-location-pin-v11")
    menu.write_text(source, encoding="utf-8")
    cached_routes = assets / "big-brother-dashboard/mobile-offline-modules-v1.js"
    source = cached_routes.read_text(encoding="utf-8")
    source = replace_once(source, 'mobile-offline-daily-sale-v1.html?embed=1&v=20261028-v12-fast1', 'mobile-offline-daily-sale-v1.html?embed=1&v=20261128-location-pin-v11')
    cached_routes.write_text(source, encoding="utf-8")
    wrapper = (assets / "big-brother-daily-sale-summary/mobile-daily-sale.js").read_text(encoding="utf-8")
    assert "doc.getElementById('bbSaleFilters')" in wrapper
    assert 'window.BBStaffOfflineV12.dailyApi(params)' in offline_page.read_text(encoding="utf-8")
    print("Daily Sale V2: verified live and cached installed routes, offline permissions preserved")

    # The update entry lives in the existing Mobile Settings, not a header.
    mobile=assets/"big-brother-dashboard/mobile.html"
    source=mobile.read_text(encoding="utf-8")
    anchor='        <!-- Real Receivable cache-first mode is now the default for every user. -->'
    source=replace_once(source,anchor,'''        <button id="bbAppUpdateSettings" class="sheet-option" type="button" hidden>
          <span aria-hidden="true">↻</span>
          <div><strong>Application Update</strong><small id="bbAppUpdateStatus">Checking installed version…</small></div>
        </button>
'''+anchor)
    source=replace_once(source,"</body>",'<script src="bb-bundled-update-settings.js"></script>\n</body>')
    mobile.write_text(source,encoding="utf-8")
    shutil.copy2(ROOT/"android/bb-bundled-update-settings.js",mobile.parent/"bb-bundled-update-settings.js")

    # The installed package owns UI versions. Rotate only the existing PWA
    # static-shell cache, not IndexedDB, saved credentials or business snapshots.
    # Include the staged assets and this script, not the Android signing version:
    # identical UI content can share a shell cache across APK builds.
    digest = hashlib.sha256()
    for item in sorted(p for p in assets.rglob("*") if p.is_file()):
        digest.update(item.relative_to(assets).as_posix().encode("utf-8"))
        digest.update(hashlib.sha256(item.read_bytes()).digest())
    digest.update(pathlib.Path(__file__).read_bytes())
    ui_version = digest.hexdigest()[:20]
    worker = assets / "big-brother-dashboard/sw.js"
    worker_source = worker.read_text(encoding="utf-8")
    worker_source, count = re.subn(r"const CACHE='bb-mobile-shell-v[0-9]+';",
        "const CACHE='bb-mobile-shell-bundled-"+ui_version+"';", worker_source)
    if count != 1:
        raise RuntimeError("PWA static shell cache marker changed")
    worker.write_text(worker_source, encoding="utf-8")
    # Report remaining third-party asset URLs as evidence, not as permission
    # to blindly remove dependencies used by maps, invoice export, or Khmer fonts.
    external = {}
    pattern = re.compile(r'https?://[a-zA-Z0-9.-]+', re.I)
    for item in assets.rglob("*"):
        if not item.is_file() or item.suffix.lower() not in {".html",".htm",".js",".mjs",".css"}:
            continue
        for url in set(pattern.findall(item.read_text(encoding="utf-8"))):
            host = url.split("://",1)[1].lower()
            if host == HOST:
                continue
            external.setdefault(host, []).append(item.relative_to(assets).as_posix())
    report_file = ROOT / "build/bundle-report.json"
    report = json.loads(report_file.read_text(encoding="utf-8"))
    report["installedUiVersion"] = ui_version
    report["externalHostFileReferences"] = {host: {"fileCount": len(paths), "examples": sorted(paths)[:8]}
                                             for host, paths in sorted(external.items())}
    report_file.write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
    print("Installed UI shell version:", ui_version)
    print("Remaining external hosts (static references):", ", ".join(sorted(external)))


    java = app / "src/main/java/com/bigbrother/online"
    for name in ("MainActivity.java", "BBNativeFileActions.java", "BBNativePrint.java"):
        p = java / name
        s = p.read_text(encoding="utf-8").replace(OLD, HOST)
        if name == "MainActivity.java":
            s = replace_once(s, 'private static final String STABLE_PACKAGE = "com.bigbrother.online.stable";',
                'private static final String STABLE_PACKAGE = "com.bigbrother.online.bundleddev";')
            s = replace_once(s, '        browser.setWebViewClient(new WebViewClient() {', '''        final androidx.webkit.WebViewAssetLoader localAssets =
            new androidx.webkit.WebViewAssetLoader.Builder()
            .setDomain(TRUSTED_HOST)
            .addPathHandler("/", new androidx.webkit.WebViewAssetLoader.AssetsPathHandler(this))
            .build();
        if (androidx.webkit.WebViewFeature.isFeatureSupported(androidx.webkit.WebViewFeature.SERVICE_WORKER_BASIC_USAGE) &&
            androidx.webkit.WebViewFeature.isFeatureSupported(androidx.webkit.WebViewFeature.SERVICE_WORKER_SHOULD_INTERCEPT_REQUEST)) {
            androidx.webkit.ServiceWorkerControllerCompat.getInstance().setServiceWorkerClient(
                new androidx.webkit.ServiceWorkerClientCompat() {
                    @Override public android.webkit.WebResourceResponse shouldInterceptRequest(WebResourceRequest request) {
                        return localResponse(localAssets, request.getUrl());
                    }
                });
        }
        browser.setWebViewClient(new WebViewClient() {
            @Override public android.webkit.WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
                return localResponse(localAssets, request.getUrl());
            }''')
            s = replace_once(s, '                if (!request.isForMainFrame()) return false;', '''                if ("angsokhey11-cloud.github.io".equalsIgnoreCase(uri.getHost())) return true;
                if (!request.isForMainFrame()) return false;''')
            s = replace_once(s, '    /** Restrict camera, microphone and location to BIG BROTHER\'s HTTPS origin. */', '''    private static android.webkit.WebResourceResponse blocked(int code, String reason) {
        return new android.webkit.WebResourceResponse("text/plain", "UTF-8", code, reason,
            java.util.Collections.singletonMap("Cache-Control", "no-store"),
            new java.io.ByteArrayInputStream(reason.getBytes(java.nio.charset.StandardCharsets.UTF_8)));
    }
    private static android.webkit.WebResourceResponse localResponse(androidx.webkit.WebViewAssetLoader loader, Uri uri) {
        String host = uri.getHost();
        if ("angsokhey11-cloud.github.io".equalsIgnoreCase(host)) return blocked(403, "Remote accounting source blocked");
        if (TRUSTED_HOST.equalsIgnoreCase(host)) {
            if (!"https".equalsIgnoreCase(uri.getScheme()) || (uri.getPort()!=-1 && uri.getPort()!=443))
                return blocked(403, "Invalid local origin");
            String path = uri.getPath();
            if (path == null || path.contains("..") || path.indexOf(92)>=0) return blocked(403, "Invalid local path");
            if (path.endsWith("/")) uri=uri.buildUpon().appendPath("index.html").build();
            android.webkit.WebResourceResponse response=loader.shouldInterceptRequest(uri);
            return response==null?blocked(404,"Bundled asset missing"):response;
        }
        return null;
    }
    /** Restrict camera, microphone and location to BIG BROTHER's installed HTTPS origin. */''')
            s = s.replace('retry.setText("RETRY ONLINE");','retry.setText("REOPEN APP");')
            s = s.replace('overlayTitle.setText("Unable to connect");','overlayTitle.setText("Unable to open installed interface");')
            s = s.replace('overlayMessage.setText("Waiting for Internet. BIG BROTHER will automatically reconnect. " +\n            "Your account and existing saved data have not been cleared.");','overlayMessage.setText("Installed interface could not open. Reopen the app or install a corrected build.");')
            # No automatic reload loop for an installed source failure.
            s = s.replace('        scheduleRetry();\n    }\n    @Override protected void onActivityResult','        stopRetry();\n    }\n    @Override protected void onActivityResult')
            s = s.replace('           retry!=null&&retry.getVisibility()==View.VISIBLE)scheduleRetry();','           retry!=null&&retry.getVisibility()==View.VISIBLE)stopRetry();')
        if name == "BBNativeFileActions.java":
            # Dedicated direct Downloads action for Daily Sale PNGs; leave existing
            # PDF, share, open and other modules' save/ZIP behavior unchanged.
            s = replace_once(s, '!"open".equals(action))', '!"open".equals(action)&&!"downloadPictures".equals(action))')
            s = replace_once(s, '            final int request=requestId;', """            if("downloadPictures".equals(action)){
                try {
                    if(types.size()!=1 || !"image/png".equals(types.get(0)))throw new IllegalArgumentException("Only one PNG per download request.");
                    if(android.os.Build.VERSION.SDK_INT<29)throw new IllegalStateException("Direct Downloads requires Android 10 or newer.");
                    File part=files.get(0);
                    String display=part.getName().replaceFirst("^[0-9]+_[0-9]+_","");
                    if(!display.startsWith("BIG_BROTHER_Daily_Sale_"))throw new IllegalArgumentException("Invalid Daily Sale filename.");
                    android.content.ContentResolver resolver=activity.getContentResolver();
                    android.content.ContentValues values=new android.content.ContentValues();
                    values.put(android.provider.MediaStore.MediaColumns.DISPLAY_NAME,display);
                    values.put(android.provider.MediaStore.MediaColumns.MIME_TYPE,"image/png");
                    values.put(android.provider.MediaStore.MediaColumns.RELATIVE_PATH,android.os.Environment.DIRECTORY_DOWNLOADS);
                    values.put(android.provider.MediaStore.MediaColumns.IS_PENDING,1);
                    Uri dest=resolver.insert(android.provider.MediaStore.Downloads.EXTERNAL_CONTENT_URI,values);
                    if(dest==null)throw new IllegalStateException("Downloads unavailable.");
                    try{
                        try(InputStream in=new java.io.FileInputStream(part);OutputStream out=resolver.openOutputStream(dest)){
                            if(out==null)throw new IllegalStateException("Could not open Downloads file.");
                            byte[] buffer=new byte[65536];int n;while((n=in.read(buffer))!=-1)out.write(buffer,0,n);
                        }
                        values.clear();values.put(android.provider.MediaStore.MediaColumns.IS_PENDING,0);
                        if(resolver.update(dest,values,null,null)<1)throw new IllegalStateException("Could not finalize download.");
                    }catch(Exception e){resolver.delete(dest,null,null);throw e;}
                    report(reply,requestId,true,"PNG saved to Downloads.");
                }finally{for(File part:files)part.delete();}
                return;
            }
            final int request=requestId;""")
            # Multi-page Save creates one ZIP with all original PNG pages.
            s = replace_once(s, 'if(!"share".equals(action)&&entries.length()!=1)', 'if("open".equals(action)&&entries.length()!=1)')
            s = replace_once(s, '            final int request=requestId;', """            if("save".equals(action)&&files.size()>1){
                File zipped=File.createTempFile("BIG-BROTHER-Invoice-Pages-", ".zip",folder);
                try(java.util.zip.ZipOutputStream zip=new java.util.zip.ZipOutputStream(new FileOutputStream(zipped))){
                    for(File part:files){
                        zip.putNextEntry(new java.util.zip.ZipEntry(part.getName().replaceFirst("^[0-9]+_[0-9]+_","")));
                        try(InputStream in=new java.io.FileInputStream(part)){
                            byte[] b=new byte[65536];int n;while((n=in.read(b))!=-1)zip.write(b,0,n);
                        }
                        zip.closeEntry();
                    }
                }
                for(File part:files)part.delete();
                files.clear();types.clear();files.add(zipped);types.add("application/zip");
            }
            final int request=requestId;""")
            s = replace_once(s, '        pendingSave=file;', '        if(pendingSave!=null)throw new IllegalStateException("Finish the current Save to Device first.");\n        pendingSave=file;')
            s = replace_once(s, '        activity.startActivityForResult(intent,SAVE_REQUEST);', '        try{activity.startActivityForResult(intent,SAVE_REQUEST);}catch(Exception e){pendingSave=null;throw e;}')
        if name == "MainActivity.java":
            s = replace_once(s, "    private WebView browser;", "    private WebView browser;\n    private BundledUpdate bundledUpdate;")
            s = replace_once(s, "        nativePrint = BBNativePrint.install(this,browser);", "        nativePrint = BBNativePrint.install(this,browser);\n        bundledUpdate = new BundledUpdate(this);\n        bundledUpdate.attach(browser);")
            s = replace_once(s, "        super.onPause();", "        if(bundledUpdate!=null)bundledUpdate.pause();\n        super.onPause();")
            s = replace_once(s, "        super.onResume();", "        super.onResume();\n        if(bundledUpdate!=null){bundledUpdate.resume();reconnectHandler.postDelayed(()->{if(bundledUpdate!=null)bundledUpdate.check();},250);}")
            s = replace_once(s, "        if(nativePrint!=null)nativePrint.destroy();", "        if(bundledUpdate!=null){bundledUpdate.destroy();bundledUpdate=null;}\n        if(nativePrint!=null)nativePrint.destroy();")
        p.write_text(s, encoding="utf-8")
    shutil.copy2(ROOT / "android/BundledUpdate.java", java / "BundledUpdate.java")
    shutil.copy2(ROOT / "android/UpdateTruckView.java", java / "UpdateTruckView.java")
    paths=app/"src/main/res/xml/bb_camera_paths.xml"
    paths.write_text(replace_once(paths.read_text(encoding="utf-8"), "</paths>", '    <cache-path name="apk_updates" path="apk_updates/"/>\n</paths>'), encoding="utf-8")
    p=app/"build.gradle"
    s=p.read_text(encoding="utf-8")
    s=replace_once(s,"applicationId 'com.bigbrother.online'","applicationId 'com.bigbrother.online.bundleddev'")
    s=replace_once(s,"applicationIdSuffix '.stable'","// Development package identity remains constant.")
    s=replace_once(s,"versionNameSuffix '-stable'","versionNameSuffix '-bundled-dev'")
    p.write_text(s,encoding="utf-8")
    p=app/"src/main/AndroidManifest.xml"
    s=replace_once(p.read_text(encoding="utf-8"),'android:label="BIG BROTHER Online"','android:label="BIG BROTHER Mobile"')
    s=replace_once(s,'    <uses-permission android:name="android.permission.INTERNET"/>','    <uses-permission android:name="android.permission.INTERNET"/>\n    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>')
    p.write_text(s,encoding="utf-8")
    icon=app/"src/main/res/drawable-nodpi/launcher.png"
    icon.parent.mkdir(parents=True,exist_ok=True)
    brand=REPO/"native-mobile-v2/app/src/online/res/drawable-nodpi/bb_brand.png"
    shutil.copy2(brand if brand.is_file() else REPO/"pwa-icon-192.png",icon)
    print("Prepared isolated Online bundled development application:", STAGE)

if __name__=="__main__": stage()
