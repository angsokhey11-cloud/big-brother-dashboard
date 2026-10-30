/* BIG BROTHER Mobile — universal account-scoped read-only screen snapshots.
 * Every authorized route can retain a safe static copy of its EXISTING UI after
 * an online visit. No scripts, events, credentials, requests or cloud writes run
 * in a snapshot. Original live pages still load automatically when connected.
 * Detailed interactive offline reports keep their specialized V8 data adapters.
 */
(function(){
'use strict';
const api=()=>window.BBMobileOfflineWorkspaceV1;
const prefix='route-static-ui::';
const MAX_BYTES=1350000;
let live=null,epoch=0;
let cachedEntry=null,retryTimer=null,retryCount=0,lastRetryAt=0;
function clearRetry(){
  if(retryTimer!==null)clearTimeout(retryTimer);
  retryTimer=null;
}
function scheduleCachedRetry(){
  if(retryTimer!==null||!cachedEntry)return;
  const delay=Math.min(45000,9000*Math.pow(2,Math.min(retryCount++,2)));
  retryTimer=setTimeout(()=>{
    retryTimer=null;
    resumeCachedLive();
  },delay);
}
function resumeCachedLive(){
  const saved=cachedEntry,screen=$('moduleScreen');
  if(!saved||!screen||screen.hidden||document.visibilityState==='hidden'||
     !api()?.canUseNetwork()||api().currentUserId()!==saved.user)return;
  if(live){
    // If an old iframe began while Internet was down, it will NOT recover by
    // itself. Restart only a stale hidden preload; never touch visible work.
    if(Date.now()-live.started<15000)return;
    clearInterval(live.interval);clearTimeout(live.timeout);
    try{live.frame.remove()}catch(_){}
    live=null;
  }
  if($('moduleFrame')!==saved.visible||!saved.visible.hasAttribute('srcdoc')){
    cachedEntry=null;clearRetry();return;
  }
  if(Date.now()-lastRetryAt<9000){
    scheduleCachedRetry();return;
  }
  preload(saved.route,saved.url,saved.visible,saved.id);
}
const $=id=>document.getElementById(id);
function access(route){
  const core=window.BBMobileLiveRoutesV1;
  const home=window.BBMobileHomeRouteAccessV1;
  const url=core?.url?.(route)||home?.url?.(route)||'';
  if(!api()?.currentUserId()||!url)return null;
  try{
    const u=new URL(url,location.href);
    if(u.origin!==location.origin||u.protocol!=='https:')return null;
    return u.href;
  }catch(_){return null}
}
function key(route){return prefix+route}
function htmlEscape(str){return String(str??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
async function saved(route){
  if(!/^[a-z0-9-]{2,90}$/.test(String(route||''))||!access(route))return null;
  const data=await api()?.read(key(route));
  const value=data?.value;
  if(!value||value.schema!==1||typeof value.html!=='string'||value.html.length>MAX_BYTES)return null;
  if(value.origin!==location.origin)return null;
  return {value,syncedAt:data.syncedAt};
}
async function available(route){return !!await saved(route)}
function captureCss(doc,clone){
  // Same-origin CSSOM, including linked stylesheets, when readable.
  // Inline styles are preserved by cloneNode; linked CSS is inlined if available.
  const styles=[];
  for(const sheet of [...doc.styleSheets]){
    try{
      const rules=[...sheet.cssRules].map(r=>r.cssText).join('\n');
      if(rules&&rules.length<200000)styles.push(rules);
    }catch(_){}
  }
  if(styles.length){
    const css=styles.join('\n');
    if(css.length<380000){
      const el=clone.ownerDocument.createElement('style');
      el.textContent=css;
      clone.querySelector('head')?.appendChild(el);
    }
  }
}
function scrub(doc){
  const original=doc?.documentElement;
  if(!original||!doc.body)return null;
  const visible=typeof doc.body.innerText==='string'?doc.body.innerText:doc.body.textContent;
  let meaningful=visible.trim().length>=40;
  // Some existing BIG BROTHER mobile pages are a tiny wrapper around the
  // real same-origin report iframe. Capture the real inner document as well.
  if(!meaningful){
    for(const child of doc.querySelectorAll('iframe')){
      try{const body=child.contentDocument?.body;if((body?.innerText||body?.textContent||'').trim().length>=40)meaningful=true}catch(_){}
    }
  }
  if(!meaningful)return null;
  if(/^(?:loading|connecting|sign in|could not load|failed to fetch)/i.test(visible.trim().slice(0,100)) &&
     !doc.querySelector('[data-status="ready"]'))return null;
  const spinner=doc.querySelector('#boot,.bb-loader,#loadingOverlay');
  if(spinner&&!spinner.hidden){
    const display=getComputedStyle(spinner);
    if(display.display!=='none'&&display.visibility!=='hidden'&&Number(display.opacity||1)>0 &&
       !spinner.classList.contains('hide'))return null;
  }
  if(doc.querySelector('input[type=password]:focus'))return null;
  // Never persist authentication screens or session-related controls.
  const login=doc.querySelector('#loginOverlay,#loginScreen,#signInScreen');
  if(login && !login.hidden && getComputedStyle(login).display!=='none' && getComputedStyle(login).visibility!=='hidden')return null;
  const clone=original.cloneNode(true);
  const banned='script,noscript,object,embed,meta[http-equiv],base,template,canvas,video,audio,source,link[rel=preload],link[rel=prefetch]';
  clone.querySelectorAll(banned).forEach(e=>e.remove());
  // Flatten a single same-origin embedded mobile page (e.g. A/R skin).
  const liveFrames=[...doc.querySelectorAll('iframe')],copiedFrames=[...clone.querySelectorAll('iframe')];
  copiedFrames.forEach((frame,i)=>{
    const source=liveFrames[i],replacement=clone.ownerDocument.createElement('div');
    replacement.style.cssText='width:100%;min-height:60vh;overflow:visible;';
    try{
      const inner=source.contentDocument;
      if(inner?.body&&inner.body.textContent.length>45){
        // Use a sanitized clone, never the inner application's scripts/forms.
        const body=inner.body.cloneNode(true);
        body.querySelectorAll(banned+',iframe').forEach(n=>n.remove());
        body.querySelectorAll('*').forEach(stripAttributes);
        captureCss(inner,clone);
        replacement.appendChild(body);
      }
    }catch(_){}
    frame.replaceWith(replacement);
  });
  clone.querySelectorAll('iframe').forEach(e=>e.remove());
  clone.querySelectorAll('*').forEach(stripAttributes);
  // Keep stylesheet links for browser HTTP cache; inline copies already added.
  clone.querySelectorAll('link').forEach(el=>{
    try{
      if(el.rel!=='stylesheet'||!/^https?:$/.test(new URL(el.href,doc.baseURI).protocol))el.remove();
      else el.href=new URL(el.href,doc.baseURI).href;
    }catch(_){el.remove()}
  });
  clone.querySelectorAll('form').forEach(form=>{form.removeAttribute('action');form.removeAttribute('method')});
  clone.querySelectorAll('a').forEach(a=>{a.removeAttribute('href');a.removeAttribute('target')});
  const head=clone.querySelector('head');
  if(!head)return null;
  const csp=clone.ownerDocument.createElement('meta');
  csp.setAttribute('http-equiv','Content-Security-Policy');
  csp.setAttribute('content',"default-src 'none'; script-src 'none'; connect-src 'none'; form-action 'none'; frame-src 'none'; object-src 'none'; style-src 'unsafe-inline' https:; font-src data: https:; img-src data: https:; base-uri 'self'");
  head.prepend(csp);
  const base=clone.ownerDocument.createElement('base');
  base.href=doc.URL.split('#')[0];
  head.appendChild(base);
  // Defensive: don't persist a screenshot of the login or empty loading stage.
  const copy=clone.outerHTML;
  if(copy.length>MAX_BYTES||copy.length<450)return null;
  return '<!DOCTYPE html>\n'+copy;
}
function stripAttributes(el){
  for(const attr of [...el.attributes]){
    const name=attr.name.toLowerCase();
    if(name.startsWith('on')||name==='srcdoc'||name==='integrity'||name==='nonce'||
      name.startsWith('data-auth')||name.includes('token')||name.includes('session')||
      name==='contenteditable'||name==='autofocus'){
      el.removeAttribute(attr.name);
    }
  }
  if(el.matches('input,textarea,select,button')){
    // Preserve visual control dimensions but disable every mutation and submission.
    el.setAttribute('disabled','');
    if(el.matches('input')){
      el.removeAttribute('value');el.setAttribute('autocomplete','off');
      if(el.type==='password'||el.type==='hidden')el.remove();
    }else if(el.matches('textarea'))el.textContent='';
    if(el.matches('select'))el.querySelectorAll('option[selected]').forEach(o=>o.removeAttribute('selected'));
  }
  if(el.matches('[contenteditable]'))el.textContent='';
}
async function capture(route,frame){
  if(!frame||!access(route)||api()?.canUseNetwork()===false||frame.dataset.bbStaticDirty==='1')return false;
  const user=api().currentUserId();
  try{
    const doc=frame.contentDocument;
    if(!doc||doc.location.origin!==location.origin||doc.readyState==='loading'||frame.dataset.bbStaticDirty==='1')return false;
    // A reused iframe must never save Route B's private data under Route A.
    const expected=new URL(access(route)),actual=new URL(doc.URL);
    if(expected.origin!==actual.origin||expected.pathname!==actual.pathname)return false;
    for(const parameter of ['view','type']){
      if(expected.searchParams.has(parameter)&&expected.searchParams.get(parameter)!==actual.searchParams.get(parameter))return false;
    }
    if(frame.dataset.bbStaticWatchRoute!==route)return false;
    const data=scrub(doc);
    if(!data||api().currentUserId()!==user)return false;
    return await api().write(key(route),{schema:1,html:data,origin:location.origin,route});
  }catch(_){return false}
}
function watch(route,frame){
  // Migrated A/R routes must use the real UI, never a DOM-snapshot imitation.
  if(['ar-your','ar-all','sales-support-your-receivable'].includes(route))return;
  if(!frame||!access(route))return;
  const seen=frame.dataset.bbStaticWatchRoute;
  if(seen===route)return;
  frame.dataset.bbStaticWatchRoute=route;
  frame.dataset.bbStaticDirty='0';
  const captured=()=>{
    const liveDoc=frame.contentDocument;
    if(liveDoc&&!liveDoc.__bbReadOnlyCaptureWatch){
      liveDoc.__bbReadOnlyCaptureWatch=true;
      // Never snapshot unsaved staff work: only the initial, untouched live UI.
      ['pointerdown','keydown','input','change'].forEach(type=>
        liveDoc.addEventListener(type,()=>{frame.dataset.bbStaticDirty='1'},{once:true,capture:true}));
    }
    if(frame.id!=='moduleFrame'||$('moduleFrame')!==frame)return;
    [1600,4800,9500,18000].forEach(ms=>setTimeout(()=>{
      if($('moduleFrame')===frame&&frame.dataset.bbStaticWatchRoute===route&&frame.getAttribute('src')&&!frame.srcdoc)
        void capture(route,frame);
    },ms));
  };
  frame.addEventListener('load',captured,{once:true});
  if(frame.contentDocument?.readyState==='complete')captured();
}
function stop(){
  epoch++;
  cachedEntry=null;
  retryCount=0;
  clearRetry();
  if(live){
    clearInterval(live.interval);clearTimeout(live.timeout);
    try{live.frame.remove()}catch(_){}
    live=null;
  }
}
function onlineReady(frame,started){
  try{
    const doc=frame.contentDocument;
    if(!doc||!doc.body||doc.readyState==='loading')return false;
    const text=doc.body.innerText||doc.body.textContent||'';
    if(text.length<140||Date.now()-started<2500)return false;
    const boot=doc.querySelector('#boot,.bb-loader,#loadingOverlay');
    if(boot&&getComputedStyle(boot).display!=='none'&&!boot.hidden&&!boot.classList.contains('hide'))return false;
    if(doc.querySelector('input[type=password]:focus'))return false;
    const ar=doc.getElementById('arMobileFrame')?.contentDocument;
    if(ar&&!/Up to date/i.test(ar.getElementById('syncStatus')?.textContent||''))return false;
    const mainStatus=doc.getElementById('syncStatus')?.textContent||'';
    if(/^(Loading|Syncing|Sign in)/i.test(mainStatus))return false;
    return true;
  }catch(_){return false}
}
async function open(route){
  stop();
  // Keep A/R data snapshots, but never display the obsolete read-only UI.
  if(['ar-your','ar-all','sales-support-your-receivable'].includes(route))return false;
  const user=api()?.currentUserId();
  const id=++epoch,record=await saved(route);
  // A superseded request is not an uncached route: do not start a stale live
  // page from an earlier tap after the user moved elsewhere.
  if(id!==epoch||api()?.currentUserId()!==user)return 'cancelled';
  if(!record)return false;
  if(!access(route))return 'cancelled';
  const screen=$('moduleScreen'),old=$('moduleFrame');
  if(!screen||!old)return false;
  // Clear any previous specialized Calculator/AR/Stock overlay before
  // showing a different saved function in the native module screen.
  window.BBMobileOfflineModulesV1?.close();
  screen.classList.remove('bb-offline-native');
  const url=access(route);
  const snapshot=old.cloneNode(false);
  snapshot.removeAttribute('src');snapshot.removeAttribute('sandbox');
  snapshot.setAttribute('sandbox','allow-same-origin');
  snapshot.setAttribute('referrerpolicy','no-referrer');
  snapshot.srcdoc=record.value.html;
  old.replaceWith(snapshot);
  ['mobileHome','menuScreen','bootScreen','loginScreen'].forEach(key=>{const el=$(key);if(el)el.hidden=true});
  screen.hidden=false;
  const menu=$('moduleTitle');if(menu)menu.textContent=window.BBMobileLiveRoutesV1?.label?.(route)||window.BBMobileHomeRouteAccessV1?.label?.(route)||route;
  const nav=window.BBMobileHistoryV7||window.BBMobileHistoryV6;
  if(nav&&!nav.isRestoring?.())nav.recordModule(route,true);
  cachedEntry={route,url,visible:snapshot,id,user};
  if(!api()?.canUseNetwork())return true;
  // Once the cached read-only UI is painted, load the genuine page out of view.
  requestAnimationFrame(()=>preload(route,url,snapshot,id));
  return true;
}
function preload(route,url,visible,id){
  if(id!==epoch||!api()?.canUseNetwork()||!url)return;
  const screen=$('moduleScreen'),user=api().currentUserId();
  if(!screen||screen.hidden)return;
  const frame=visible.cloneNode(false);
  frame.removeAttribute('srcdoc');frame.removeAttribute('sandbox');
  frame.setAttribute('sandbox','allow-scripts allow-same-origin allow-forms allow-modals allow-popups allow-popups-to-escape-sandbox allow-downloads allow-top-navigation-by-user-activation');
  frame.setAttribute('aria-hidden','true');
  frame.style.cssText='position:absolute!important;visibility:hidden!important;opacity:0!important;pointer-events:none!important;width:100%!important;height:100%!important;z-index:-1!important';
  frame.id='bbUniversalStaged';
  const entry={frame,route,user,started:Date.now(),interval:0,timeout:0};
  lastRetryAt=Date.now();
  live=entry;screen.appendChild(frame);
  const cancel=()=>{if(live===entry||cachedEntry?.visible===visible)stop()};
  visible.addEventListener('pointerdown',cancel,{once:true});
  visible.addEventListener('keydown',cancel,{once:true});
  const check=()=>{
    if(live!==entry)return;
    if(id!==epoch||screen.hidden||api().currentUserId()!==user)return stop();
    if(!api()?.canUseNetwork()){
      // Losing Wi-Fi must NOT forget the saved screen's pending handoff.
      // The reconnect watcher can restart it when the host returns.
      live=null;clearInterval(entry.interval);clearTimeout(entry.timeout);
      try{entry.frame.remove()}catch(_){}
      return;
    }
    if(!onlineReady(frame,entry.started))return;
    live=null;clearInterval(entry.interval);clearTimeout(entry.timeout);
    cachedEntry=null;clearRetry();retryCount=0;
    const liveFrame=frame;const sourceFrame=$('moduleFrame');
    if(!sourceFrame||sourceFrame!==visible){liveFrame.remove();return}
    // Never move the already loaded frame: replaceWith() reparents it and
    // some mobile browsers restart the entire live document.
    try{
      const a=sourceFrame.contentDocument?.scrollingElement;
      const b=liveFrame.contentDocument?.scrollingElement;
      if(a&&b){b.scrollTop=a.scrollTop;b.scrollLeft=a.scrollLeft}
    }catch(_){}
    sourceFrame.id='bbUniversalRetiringFrame';
    liveFrame.id='moduleFrame';
    liveFrame.removeAttribute('aria-hidden');
    liveFrame.style.cssText='visibility:visible!important;opacity:0!important;'+
      'z-index:6!important;pointer-events:none!important;transition:opacity 160ms ease!important;';
    const finish=()=>{
      sourceFrame.remove();
      if(liveFrame.parentNode!==screen||$('moduleFrame')!==liveFrame)return;
      liveFrame.style.cssText='';
      liveFrame.removeAttribute('sandbox');
      liveFrame.inert=false;
      watch(route,liveFrame);
    };
    requestAnimationFrame(()=>requestAnimationFrame(()=>{
      if(liveFrame.parentNode!==screen||$('moduleFrame')!==liveFrame)return finish();
      liveFrame.style.setProperty('opacity','1','important');
      liveFrame.style.setProperty('pointer-events','auto','important');
      setTimeout(finish,205);
    }));
  };
  entry.interval=setInterval(check,250);
  entry.timeout=setTimeout(()=>{
    if(live!==entry)return;
    clearInterval(entry.interval);
    live=null;
    try{entry.frame.remove()}catch(_){}
    // Keep the existing static UI visible and retry the SAME route.
    // Never reset navigation or overwrite the user's current screen.
    scheduleCachedRetry();
  },60000);
  frame.src=url;
}
window.addEventListener('bb:mobile-reconnected',resumeCachedLive);
window.addEventListener('online',resumeCachedLive);
window.addEventListener('focus',resumeCachedLive);
document.addEventListener('visibilitychange',()=>{
  if(document.visibilityState==='visible')resumeCachedLive();
});
window.BBMobileUniversalReadOnlyV1={available,open,watch,capture,stop,
  isCachedActive:()=>!!cachedEntry&&!$('moduleScreen')?.hidden};
})();