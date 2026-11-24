"""Installed-only Real Invoice Scanner responsive cards. No scanner logic changes."""
from pathlib import Path

CSS = """
/* BB installed scanner card layout: isolate from generic row/actions rules. */
#items > .bb-scanner-record {
  display:grid!important;
  grid-template-columns:minmax(0,1fr) auto;
  align-items:start!important;
  gap:10px;
  min-width:0;
}
#items > .bb-scanner-record > .bb-scanner-info {
  min-width:0;
  width:100%;
  overflow-wrap:anywhere;
}
#items > .bb-scanner-record .bb-scanner-meta {
  margin:7px 0 0;
  color:#506981;
  font-size:12px;
  line-height:1.55;
  overflow-wrap:anywhere;
}
#items > .bb-scanner-record > .bb-scanner-actions {
  display:flex;
  flex-wrap:wrap;
  justify-content:flex-end;
  gap:8px;
  min-width:0;
}
#items > .bb-scanner-record .bb-scanner-actions > button {
  position:static!important;
  width:auto;
  min-width:0;
  min-height:40px;
  white-space:normal;
  overflow-wrap:normal;
}
#items > .bb-scanner-record .bb-scanner-actions > button[data-id] {
  color:#fff!important;
  background:#1769af!important;
}
@media(max-width:700px) {
  #items > .bb-scanner-record {
    grid-template-columns:minmax(0,1fr);
    padding:12px;
  }
  #items > .bb-scanner-record > .bb-scanner-actions {
    display:grid!important;
    grid-template-columns:repeat(2,minmax(0,1fr));
    width:100%;
  }
  #items > .bb-scanner-record .bb-scanner-actions > button {
    width:100%!important;
    margin:0!important;
    padding:8px 6px;
    font-size:13px;
  }
  #items > .bb-scanner-record .bb-scanner-actions > button:first-child {
    grid-column:1/-1;
  }
}
"""

def apply(assets: Path):
    path = assets / "big-brother-real-invoice/index.html"
    source = path.read_text(encoding="utf-8")
    replacements = [
        ('<article class="card row"><div><strong>', '<article class="card bb-scanner-record"><div class="bb-scanner-info"><strong>'),
        ('</span><div class="meta">Invoice: ', '</span><div class="bb-scanner-meta">Invoice: '),
        ('</div></div><div class="actions"><button data-id=', '</div></div><div class="bb-scanner-actions"><button data-id='),
        ('</style><script src=', CSS + '</style><script src='),
    ]
    for old, new in replacements:
        if source.count(old) != 1:
            raise RuntimeError("Scanner layout marker changed: " + old)
        source = source.replace(old, new, 1)
    # Keep all original click selectors and permission checks intact.
    for marker in ("[data-id]", "[data-replace]", "[data-history]", "manageable.has(r.invoiceId)"):
        if marker not in source:
            raise RuntimeError("Scanner behavior marker missing: " + marker)
    path.write_text(source, encoding="utf-8")
    print("Installed scanner: responsive record grid and accessible action buttons")
