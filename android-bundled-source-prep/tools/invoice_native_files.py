"""Reuse existing A/R native file adapter for installed invoice export."""
import pathlib, re, subprocess, tempfile, tarfile

def once(s,old,new):
    if s.count(old)!=1: raise RuntimeError("Invoice file action marker changed: "+old[:100])
    return s.replace(old,new,1)

def head_script(s, script):
    # Original invoice document also has embedded print HTML templates with
    # closing head tags. Only modify the actual document head.
    pos=s.lower().find("</head>")
    if pos<0: raise RuntimeError("Invoice document head missing")
    return s[:pos]+script+"\n"+s[pos:]

def apply(assets):
    # Reuse the proven A/R adapter with its existing acknowledgements, limits,
    # filename handling and same-origin Android bridge.
    adapter=assets/"big-brother-ar/receivable-file-actions-v1.js"
    s=adapter.read_text(encoding="utf-8")
    s=once(s,"async function share(files,title,text){",'''async function saveMany(files){
 requireApkBridge();
 if(!Array.isArray(files)||!files.length)throw Error('No invoice pages to save.');
 if(files.length===1)return save(files[0]);
 if(!native())throw Error('Multi-page native export unavailable.');
 await sendNative('save',files);return 'native';
}
async function share(files,title,text){''')
    s=once(s,"save,share,open,diagnostics,ping","save,saveMany,share,open,diagnostics,ping")
    adapter.write_text(s,encoding="utf-8")
    # Bundle exact existing html2canvas version once at build time.
    # npm pack validates the registry package integrity; never run install scripts.
    vendor=assets/"big-brother-dashboard/vendor/html2canvas.min.js"
    vendor.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory() as td:
        subprocess.run(["npm","pack","html2canvas@1.4.1","--ignore-scripts","--pack-destination",td],check=True)
        with tarfile.open(pathlib.Path(td)/"html2canvas-1.4.1.tgz") as tar:
            data=tar.extractfile("package/dist/html2canvas.min.js").read()
            if not 100000<len(data)<1000000: raise RuntimeError("Unexpected html2canvas size")
            vendor.write_bytes(data)
            license=tar.extractfile("package/LICENSE").read()
            (vendor.parent/"html2canvas-LICENSE.txt").write_bytes(license)
    library="/big-brother-dashboard/vendor/html2canvas.min.js"
    bridge='<script src="/big-brother-ar/receivable-file-actions-v1.js"></script>'
    gen=assets/"big-brother-invoice-generator/desktop-source-v20260924-invoiceseq1.html"
    s=gen.read_text(encoding="utf-8")
    s=s.replace("https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js",library)
    s=head_script(s,bridge)
    s=once(s,"    const url = URL.createObjectURL(blob);\n    const link = document.createElement(\"a\");",'''    if(!window.BBARFileActionsV1?.isNative())throw Error("Android file bridge unavailable. Reopen BIG BROTHER Mobile.");
    await window.BBARFileActionsV1.save(new File([blob],"BIG-BROTHER-"+safeInvoice+"-"+date+".png",{type:"image/png"}));
    return;
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");''')
    s=once(s,"    if (isMobile) {\n\n      if (!navigator.share) {",'''    if (isMobile) {
      if(!window.BBARFileActionsV1?.isNative())throw Error("Android file bridge unavailable. Reopen BIG BROTHER Mobile.");
      await window.BBARFileActionsV1.share([file],"BIG BROTHER Invoice",text);
      return;

      if (!navigator.share) {''')
    s=once(s,'alert("Could not save the invoice image. Please try again.");','alert("Could not save invoice: "+String(error?.message||error));')
    gen.write_text(s,encoding="utf-8")
    for path in [assets/"invoice-history/legacy-google-v4.6.3.html",assets/"big-brother-dashboard/offline-original-history.html"]:
        s=path.read_text(encoding="utf-8")
        # Live engine already has lazy image library; offline original lacked it.
        s=s.replace("https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js",library)
        if "function bbHistoryLoadImageLibrary()" not in s:
            s=head_script(s,f'<script src="{library}"></script>')
        s=head_script(s,bridge)
        s=once(s,"      downloadHistoryInvoicePages(blobs,baseName);",'''      if(!window.BBARFileActionsV1?.isNative())throw Error("Android file bridge unavailable. Reopen BIG BROTHER Mobile.");
      const files=blobs.map((blob,index)=>new File([blob],blobs.length>1?baseName+"-Page-"+(index+1)+".png":baseName+".png",{type:"image/png"}));
      await window.BBARFileActionsV1.saveMany(files);
      return;''')
        s=once(s,"      if(isMobile){\n        if(!navigator.share){",'''      if(isMobile){
        if(!window.BBARFileActionsV1?.isNative())throw Error("Android file bridge unavailable. Reopen BIG BROTHER Mobile.");
        await window.BBARFileActionsV1.share(files,"BIG BROTHER Invoice",text);
        return;
        if(!navigator.share){''')
        s=once(s,'alert("Could not save the invoice picture. Please try again.");','alert("Could not save invoice: "+String(error?.message||error));')
        s=once(s,'alert("Could not share the invoice picture. Please try again.");','alert("Could not share invoice: "+String(error?.message||error));')
        path.write_text(s,encoding="utf-8")
    print("Installed invoice generator and history share/save use existing native A/R bridge")
