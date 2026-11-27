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

def apply(assets):
    dash=assets/"big-brother-dashboard"
    hist=assets/"invoice-history"
    path=dash/"mobile-offline-history-mobile-v1.html"
    path.write_text(skin(path.read_text(encoding="utf-8")),encoding="utf-8")
    path=hist/"legacy-google-v4.6.3.html"
    s=fonts(path.read_text(encoding="utf-8"))
    assert "installHistoryProgressiveV2" in s
    path.write_text(s,encoding="utf-8")
    path=hist/"invoice-history-mobile.html"
    s=path.read_text(encoding="utf-8")
    m=re.search(r'const html=("(?:\\.|[^"\\])*");',s)
    if not m: raise RuntimeError("Live mobile History HTML missing")
    updated=skin(json.loads(m.group(1)))
    encoded=json.dumps(updated,ensure_ascii=False).replace("<",r"\u003c")
    path.write_text(s[:m.start(1)]+encoded+s[m.end(1):],encoding="utf-8")
    print("Installed Invoice History V2: original priority paging retained")
