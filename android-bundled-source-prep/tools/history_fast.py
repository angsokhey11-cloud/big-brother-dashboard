"""Installed-only Invoice History startup performance patches."""
import json, re

def once(s, old, new):
    if s.count(old)!=1:
        raise RuntimeError("Invoice History performance marker changed: "+old[:100])
    return s.replace(old,new,1)

def fonts(s):
    # Android has Khmer font fallback; do not wait for Google Fonts on startup.
    return re.sub(r'<link\b[^>]*href="https://fonts\.googleapis\.com[^"]*"[^>]*>\s*','',s)

def skin(s):
    s=fonts(s)
    s=once(s,"  style.textContent =\n    MOBILE_CSS;",
           "  if(style.textContent !== MOBILE_CSS) style.textContent = MOBILE_CSS;")
    # Do not reinject/repolish the same document three times after load.
    s,n=re.subn(r"frame\.addEventListener\(\s*'load',\s*\(\) => \{\s*setTimeout\(\s*inject,\s*80\s*\);\s*setTimeout\(\s*inject,\s*450\s*\);\s*setTimeout\(\s*inject,\s*1200\s*\);\s*\}\s*\);",
                "frame.addEventListener('load', inject);",s)
    if n!=1: raise RuntimeError("Invoice History skin load marker changed")
    s,n=re.subn(r"  setTimeout\(\s*\(\) => \{\s*polishRows\(doc\);\s*fitInvoicePreview\(doc\);\s*\},\s*(?:120|600)\s*\);","",s)
    if n!=2: raise RuntimeError("Invoice History repeated skin marker changed")
    return s

def engine(s,offline):
    s=fonts(s)
    s=once(s,"    await populateHistoryLocationFilter();\n\n    // Show previously synced device data immediately when possible.",
           "    void populateHistoryLocationFilter();\n\n    // Show previously synced device data immediately when possible.")
    # Don't build master mapping when server/cache already supplied every code.
    s=once(s,"    if (!rows.length) return rows;\n\n    // Load the Master mapping once",
           '    if (!rows.length || rows.every(r => String(r.locationCode || "").trim())) return rows;\n\n    // Load the Master mapping once')
    # Keep all matched invoices in memory; render the first 60 cards only,
    # then append more at user's request. Exact full-result count retained.
    s=once(s,"  function renderInvoices(invoices) {",'''  let bbHistoryResultRows = [], bbHistoryVisibleCount = 0;
  function renderInvoices(invoices) {
    bbHistoryResultRows = Array.isArray(invoices) ? invoices : [];
    bbHistoryVisibleCount = Math.min(60, bbHistoryResultRows.length);
    renderHistoryVisibleRows();
  }
  function renderHistoryVisibleRows() {
    renderHistoryRowsOriginal(bbHistoryResultRows.slice(0, bbHistoryVisibleCount));
    const count = bbHistoryResultRows.length;
    $("summaryCount").textContent = count + (count === 1 ? " invoice" : " invoices");
    let more = document.getElementById("bbHistoryMoreRows");
    if(!more){
      more=document.createElement("button");
      more.id="bbHistoryMoreRows";more.type="button";more.className="btn btn-secondary";
      more.style.cssText="display:block;margin:12px auto;width:calc(100% - 16px);max-width:420px;";
      const table=$("invoiceBody").closest(".table-card");
      if(table) table.insertAdjacentElement("afterend",more);
      else $("invoiceBody").closest("table").insertAdjacentElement("afterend",more);
      more.onclick=()=>{
        bbHistoryVisibleCount=Math.min(bbHistoryResultRows.length,bbHistoryVisibleCount+60);
        renderHistoryVisibleRows();
      };
    }
    more.style.display=bbHistoryVisibleCount<count?"block":"none";
    more.textContent="Show more invoices ("+bbHistoryVisibleCount+" of "+count+")";
  }
  function renderHistoryRowsOriginal(invoices) {''')
    # Avoid repeated detail reads during the first visible cache frame.
    if offline:
        s=once(s,"const HISTORY_DETAIL_PREFETCH_LIMIT = 6;","const HISTORY_DETAIL_PREFETCH_LIMIT = 0;")
    else:
        s=once(s,'<script src="https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js"></script>',
               '''<script>
let bbHistoryImageLibraryPromise;
function bbHistoryLoadImageLibrary(){
  if(typeof html2canvas==="function")return Promise.resolve();
  if(!bbHistoryImageLibraryPromise)bbHistoryImageLibraryPromise=new Promise((resolve,reject)=>{
    const script=document.createElement("script");
    script.src="https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js";
    const fail=()=>{script.remove();bbHistoryImageLibraryPromise=null;reject(new Error("Image library unavailable. Connect to internet and retry."));};
    const timeout=setTimeout(fail,15000);
    script.onload=()=>{clearTimeout(timeout);if(typeof html2canvas==="function")resolve();else fail();};
    script.onerror=()=>{clearTimeout(timeout);fail();};
    document.head.appendChild(script);
  });
  return bbHistoryImageLibraryPromise;
}
</script>''')
        s=once(s,'    if(typeof html2canvas!=="function")throw new Error("Image library is not loaded.");',
               '    if(typeof html2canvas!=="function")await bbHistoryLoadImageLibrary();')
    return s

def apply(assets):
    dash=assets/"big-brother-dashboard"
    hist=assets/"invoice-history"
    for path,transform in [
        (dash/"mobile-offline-history-original-v1.html",lambda s:engine(s,True)),
        (dash/"mobile-offline-history-mobile-v1.html",skin),
        (hist/"legacy-google-v4.6.3.html",lambda s:engine(s,False)),
    ]:
        path.write_text(transform(path.read_text(encoding="utf-8")),encoding="utf-8")
    # The live mobile wrapper stores its original HTML as a JSON string.
    path=hist/"invoice-history-mobile.html"
    s=path.read_text(encoding="utf-8")
    m=re.search(r'const html=("(?:\\.|[^"\\])*");',s)
    if not m: raise RuntimeError("Live mobile History HTML missing")
    updated=skin(json.loads(m.group(1)))
    encoded=json.dumps(updated,ensure_ascii=False).replace("<",r"\u003c")
    path.write_text(s[:m.start(1)]+encoded+s[m.end(1):],encoding="utf-8")
    # Deduplicate identical concurrent master lookups for the live mobile view.
    path=hist/"supabase-history-mobile-adapter.js"
    s=path.read_text(encoding="utf-8")
    s=once(s,"  async function historyJsonp(_url,params={}){\n    const d=await rpc('bb_invoice_history_mobile_master');",
           """  let bbHistoryMasterPending=null;
  async function historyJsonp(_url,params={}){
    if(!bbHistoryMasterPending)bbHistoryMasterPending=rpc('bb_invoice_history_mobile_master').finally(()=>{bbHistoryMasterPending=null});
    const d=await bbHistoryMasterPending;""")
    path.write_text(s,encoding="utf-8")
    print("Installed Invoice History startup: bounded first render, parallel location lookup, single skin injection")
