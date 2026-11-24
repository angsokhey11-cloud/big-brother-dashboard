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
    # Installed-only: use the EXISTING account-scoped cached Invoice History
    # view online too. Its normal live handoff checks permission and data,
    # and falls back to the original live route if no local snapshot exists.
    # Do not bypass the live invoice permission or allow cached writes.
    menu = assets / "big-brother-dashboard/mobile-main-menu-stockcontrol-v5.js"
    source = menu.read_text(encoding="utf-8")
    source = replace_once(source,
        "if(!forceLive&&(route!=='history'||offline?.canUseNetwork()!==true)&&!liveApproval&&!realPilot&&cached?.canOpen(route)){",
        "if(!forceLive&&!liveApproval&&!realPilot&&cached?.canOpen(route)){")
    menu.write_text(source, encoding="utf-8")
    print("Installed Invoice History: existing cache-first route enabled")
    from history_fast import apply as apply_history_fast
    apply_history_fast(assets)
    from invoice_native_files import apply as apply_invoice_native_files
    apply_invoice_native_files(assets)
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
