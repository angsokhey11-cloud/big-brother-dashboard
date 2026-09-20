/* BIG BROTHER — iOS Decimal Input Helper V1
   Mobile shell only. Keeps desktop untouched.
   On iPhone/iPad, WebKit can be awkward with type=number decimal entry.
   Decimal-intended controls are switched to text + inputmode=decimal so
   users can reliably enter values such as 4.20. Locale comma is normalized
   to a dot before page-level input handlers calculate values. */
(function(){
'use strict';

const isIOS=()=>{
  const ua=navigator.userAgent||'';
  return /iPhone|iPad|iPod/i.test(ua) ||
    (navigator.platform==='MacIntel' && Number(navigator.maxTouchPoints||0)>1);
};

if(!isIOS())return;

const observedDocs=new WeakSet();

function decimalCandidate(input){
  if(!input || String(input.tagName||'').toLowerCase()!=='input')return false;
  if(String(input.type||'').toLowerCase()!=='number')return false;

  const mode=String(input.getAttribute('inputmode')||input.inputMode||'').toLowerCase();
  if(mode==='decimal')return true;

  const stepRaw=String(input.getAttribute('step')||'').trim().toLowerCase();
  if(stepRaw==='any')return true;
  if(stepRaw){
    const step=Number(stepRaw);
    if(Number.isFinite(step) && step>0 && !Number.isInteger(step))return true;
  }

  const semantic=[
    input.id,
    input.name,
    input.className,
    input.getAttribute('aria-label'),
    input.getAttribute('placeholder')
  ].filter(Boolean).join(' ').toLowerCase();

  return /(price|amount|rate|discount|cost|cash|paid|payment|credit|balance|total|exchange|qty|quantity|allowance|salary|expense|receiv|value)/.test(semantic);
}

function patchInput(input){
  if(!decimalCandidate(input) || input.dataset.bbIosDecimal==='1')return;

  input.dataset.bbIosDecimal='1';
  input.dataset.bbOriginalType='number';

  /* text + decimal is more reliable in iOS standalone/PWA than number
     for preserving the decimal separator while the user is typing. */
  try{input.type='text'}catch(_){}
  input.setAttribute('inputmode','decimal');
  input.setAttribute('autocapitalize','none');
  input.setAttribute('spellcheck','false');
}

function patchTree(root){
  if(!root)return;

  if(root.matches?.('input'))patchInput(root);

  root.querySelectorAll?.('input[type="number"]').forEach(patchInput);
}

function normalizeDecimal(event){
  const input=event.target;
  if(!input || input.dataset?.bbIosDecimal!=='1')return;

  const raw=String(input.value||'');
  if(!raw.includes(','))return;

  const start=input.selectionStart;
  const next=raw.replace(/,/g,'.');

  if(next===raw)return;
  input.value=next;

  if(typeof start==='number'){
    try{input.setSelectionRange(start,start)}catch(_){}
  }
}

function bindDocument(doc){
  if(!doc || observedDocs.has(doc))return;
  observedDocs.add(doc);

  const apply=()=>patchTree(doc.body||doc.documentElement);
  apply();

  /* Capture phase runs before inline oninput handlers, so a locale comma
     is normalized before existing BIG BROTHER calculations read the value. */
  doc.addEventListener('input',normalizeDecimal,true);

  const root=doc.documentElement||doc.body;
  if(root){
    new MutationObserver(records=>{
      for(const record of records){
        for(const node of record.addedNodes||[]){
          if(node?.nodeType===1)patchTree(node);
        }
      }
    }).observe(root,{childList:true,subtree:true});
  }

  setTimeout(apply,120);
  setTimeout(apply,500);
  setTimeout(apply,1400);
}

function patchModuleFrame(){
  const frame=document.getElementById('moduleFrame');
  if(!frame)return;
  try{
    const doc=frame.contentDocument;
    if(doc?.documentElement)bindDocument(doc);
  }catch(_){}
}

function start(){
  bindDocument(document);

  const frame=document.getElementById('moduleFrame');
  if(frame && !frame.dataset.bbIosDecimalBound){
    frame.dataset.bbIosDecimalBound='1';
    frame.addEventListener('load',()=>{
      setTimeout(patchModuleFrame,20);
      setTimeout(patchModuleFrame,180);
      setTimeout(patchModuleFrame,700);
    });
  }

  setTimeout(patchModuleFrame,250);
  setTimeout(patchModuleFrame,1200);
}

if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});
else start();

window.BBIOSDecimalInputV1={apply:()=>{bindDocument(document);patchModuleFrame();}};
})();