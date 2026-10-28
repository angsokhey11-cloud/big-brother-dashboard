/* BIG BROTHER — Offline Mobile Modules V1
 * Read-only cloud snapshots; Calculator writes ONLY local device history.
 * Uses already-authorized Supabase RPCs and user-scoped IndexedDB.
 */
(function(){
'use strict';
const offline=()=>window.BBMobileOfflineWorkspaceV1;
const SESSION_KEY='BB_SUPABASE_DEV_SESSION_V1';
const $=id=>document.getElementById(id);
const clean=v=>String(v??'').trim();
const num=v=>{const x=Number(v);return Number.isFinite(x)?x:0};
const money=(n,c='USD')=>c==='KHR'?'៛'+Math.round(num(n)).toLocaleString('en-US'):'$'+num(n).toLocaleString('en-US',{minimumFractionDigits:2,maximumFractionDigits:2});
const esc=v=>clean(v).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const mapRoutes={
  'ar-your':'offline-ar-your',
  'sales-support-your-receivable':'offline-ar-your',
  'ar-all':'offline-ar-all',
  'stock-report':'offline-stock-report',
  'sales-support-calculator':'offline-calc-bootstrap'
};
let host=null,route='',openEpoch=0,dataset=null,datasetSyncedAt=0,selectedReceivables=new Set(),calcCustomer=null,calcPrices=null,calcLines=[],calcCurrency='USD',calcRate=4100,calcDiscount=0;
function currentId(){return offline()?.currentUserId()||''}
function historyKey(){return 'bb_sales_support_calc_history_v2_'+currentId()}
function currentKey(){return 'bb_sales_support_calc_current_v2_'+currentId()}
function stored(key,fallback){
  try{const v=JSON.parse(localStorage.getItem(key)||'null');return v??fallback}catch(_){return fallback}
}
function history(){const v=stored(historyKey(),[]);return Array.isArray(v)?v:[]}
function saveLocal(key,value){try{localStorage.setItem(key,JSON.stringify(value));return true}catch(_){return false}}
function canOpen(name){return !!mapRoutes[name]}
async function available(name){
  if(!canOpen(name)||!currentId())return false;
  const data=await offline()?.read(mapRoutes[name]);
  return !!data?.value;
}
function createHost(){
  if(host)return host;
  host=document.createElement('div');
  host.id='bbOfflineModulesScreen';
  host.style.cssText='position:absolute;top:0;bottom:calc(68px + env(safe-area-inset-bottom));left:0;right:0;z-index:3;background:#edf3fa;display:none;overflow:auto;color:#173e66;font-family:system-ui,-apple-system,"Segoe UI",sans-serif;';
  const style=document.createElement('style');
  style.textContent=`
    /* Offline and online use the same mobile module shell and bottom navigation.
       The duplicate offline header is intentionally removed. */
    #moduleScreen.bb-offline-native .module-header{display:none!important}
    #moduleScreen.bb-offline-native .module-frame{top:0!important;bottom:calc(68px + env(safe-area-inset-bottom))!important;
      height:calc(100dvh - 68px - env(safe-area-inset-bottom))!important}
    @media print{
      body.bb-offline-summary-print>*:not(#bbOfflineSummaryPrint){display:none!important}
      body.bb-offline-summary-print{background:#fff!important;margin:0!important;padding:0!important}
      #bbOfflineSummaryPrint{position:static!important;width:auto!important;height:auto!important;overflow:visible!important;
        background:#fff!important;padding:0!important}
      #bbOfflineSummaryPrint .bb-summary-actions{display:none!important}
      #bbOfflineSummaryPrint .bb-summary-sheet{width:100%!important;min-height:0!important;padding:11mm!important;
        margin:0!important;border:0!important;box-shadow:none!important}
      #bbOfflineSummaryPrint table{font-size:9px!important}
      @page{size:A4;margin:0}
    }
    #bbOfflineModulesScreen .bb-off-header{position:sticky;top:0;z-index:3;padding:12px;background:#14528b;color:#fff;display:flex;gap:10px;align-items:center}
    #bbOfflineModulesScreen button,#bbOfflineModulesScreen select,#bbOfflineModulesScreen input{font:inherit}
    #bbOfflineModulesScreen button{cursor:pointer}
    #bbOfflineModulesScreen .bb-back{border:0;border-radius:9px;background:#ffffff29;color:#fff;padding:8px 14px;font-weight:900}
    #bbOfflineModulesScreen .bb-off-main{padding:14px;max-width:720px;margin:0 auto}
    #bbOfflineModulesScreen .bb-off-note{background:#e6f0fc;padding:11px 13px;border-radius:12px;font-size:12px;line-height:1.5;color:#315879;margin-bottom:12px}
    #bbOfflineModulesScreen .bb-off-card{background:#fff;padding:13px;border:1px solid #d7e3ee;border-radius:12px;margin:8px 0;box-shadow:0 2px 5px #00326008}
    #bbOfflineModulesScreen .bb-off-card strong{display:block;font-size:14px}
    #bbOfflineModulesScreen .bb-off-card small{display:block;color:#657d94;margin-top:4px}
    #bbOfflineModulesScreen .bb-off-data{display:grid;grid-template-columns:1fr auto;gap:7px;align-items:center}
    #bbOfflineModulesScreen .bb-off-data b{color:#1266a4}
    #bbOfflineModulesScreen input,#bbOfflineModulesScreen select{border:1px solid #c7d8e8;background:#fff;border-radius:9px;min-width:0;box-sizing:border-box;padding:11px;width:100%;font-size:14px}
    #bbOfflineModulesScreen .bb-off-form{display:grid;grid-template-columns:1fr 1fr;gap:8px}
    #bbOfflineModulesScreen .bb-off-form .wide{grid-column:1/-1}
    #bbOfflineModulesScreen .bb-off-primary{background:#1267af;color:#fff;border:0;border-radius:9px;padding:11px;font-weight:700}
    #bbOfflineModulesScreen .bb-off-muted{background:#ecf2fa;color:#23496d;border:1px solid #d2e0eb;border-radius:9px;padding:9px}
    #bbOfflineModulesScreen .bb-off-scroll{max-height:56vh;overflow:auto}

    #bbOfflineModulesScreen .bb-ar-card .check input{height:20px;width:20px;accent-color:#2368bd;cursor:pointer}
    #bbOfflineModulesScreen .bb-ar-toolbar .bb-off-primary:disabled{opacity:.45;cursor:not-allowed}
    #bbOfflineSummaryPrint{position:fixed;inset:0;z-index:1000002;overflow:auto;background:#e8eef6;
      font-family:Arial,"Noto Sans Khmer",sans-serif;color:#17304f}
    #bbOfflineSummaryPrint .bb-summary-actions{position:sticky;top:0;z-index:3;background:#fff;padding:10px;
      border-bottom:1px solid #d4dfeb;display:flex;flex-wrap:wrap;justify-content:flex-end;align-items:center;gap:8px}
    #bbOfflineSummaryPrint .bb-summary-actions strong{margin-right:auto;color:#123f73}
    #bbOfflineSummaryPrint .bb-summary-actions button{font:800 12px Arial;border-radius:8px;min-height:38px;padding:8px 12px;cursor:pointer}
    #bbOfflineSummaryPrint .bb-off-primary{border:0;background:#2468bd;color:#fff}
    #bbOfflineSummaryPrint .bb-off-muted{border:1px solid #d5e0ec;background:#f5f8fc;color:#254e78}
    #bbOfflineSummaryPrint .bb-summary-sheet{width:min(100%,794px);min-height:1123px;box-sizing:border-box;
      margin:14px auto;padding:34px;background:#fff;box-shadow:0 6px 25px #1b476622}
    #bbOfflineSummaryPrint .bb-summary-top{display:flex;justify-content:space-between;gap:20px;border-bottom:2px solid #1f5fbf;padding-bottom:13px}
    #bbOfflineSummaryPrint h1{margin:0;font-size:28px;color:#173f77;line-height:1.1}
    #bbOfflineSummaryPrint .bb-summary-top p{font-size:10px;color:#758599;margin:5px 0}
    #bbOfflineSummaryPrint .bb-summary-meta{text-align:right;font-size:9px;line-height:1.5;min-width:126px}
    #bbOfflineSummaryPrint .bb-summary-meta p{font-size:9px;margin:3px 0}
    #bbOfflineSummaryPrint h2{font-size:17px;letter-spacing:.4px;text-align:center;margin:20px 0;color:#173f77}
    #bbOfflineSummaryPrint .bb-summary-customer{background:#f2f7fd;border:1px solid #dce5ef;border-radius:10px;padding:14px;margin:10px 0}
    #bbOfflineSummaryPrint .bb-summary-customer strong{display:block;font-size:10px;color:#56708b}
    #bbOfflineSummaryPrint .bb-summary-customer div{font-weight:900;font-size:18px;margin:5px 0;color:#173f77}
    #bbOfflineSummaryPrint .bb-summary-customer small{display:block;color:#60758c;font-size:10px}
    #bbOfflineSummaryPrint .bb-summary-period{font-size:10px;color:#60758c;margin:12px 0}
    #bbOfflineSummaryPrint table{width:100%;border-collapse:collapse;font-size:10px;table-layout:auto}
    #bbOfflineSummaryPrint th{background:#173f77;color:#fff;text-align:left;font-weight:800;padding:9px 5px}
    #bbOfflineSummaryPrint td{padding:8px 5px;border-bottom:1px solid #e1e7ef;overflow-wrap:anywhere}
    #bbOfflineSummaryPrint tr{break-inside:avoid}
    #bbOfflineSummaryPrint .bb-summary-totals{margin-top:14px;display:grid;gap:6px}
    #bbOfflineSummaryPrint .bb-summary-totals div{display:flex;justify-content:space-between;gap:10px;
      padding:11px;background:#e8f2ff;color:#15487b;font-weight:800;font-size:12px}
    #bbOfflineSummaryPrint footer{margin-top:35px;border-top:1px solid #dae4ed;padding-top:9px;
      font-size:10px;color:#687b8d;text-align:center}
    @media(max-width:560px){
      #bbOfflineSummaryPrint .bb-summary-sheet{margin:0;padding:16px;min-height:100vh}
      #bbOfflineSummaryPrint .bb-summary-top{gap:8px}
      #bbOfflineSummaryPrint h1{font-size:21px}
      #bbOfflineSummaryPrint table{font-size:7px}
      #bbOfflineSummaryPrint th,#bbOfflineSummaryPrint td{padding:6px 3px}
    }


    /* Receivable cards follow the same grid and amount-box design as the online mobile A/R. */
    #bbOfflineModulesScreen .bb-ar-toolbar{display:flex;align-items:center;justify-content:space-between;gap:8px;margin-bottom:8px}
    #bbOfflineModulesScreen .bb-ar-total{color:#17487d;font-size:13px;font-weight:900}
    #bbOfflineModulesScreen .bb-ar-list{display:grid;gap:8px;margin-top:9px}
    #bbOfflineModulesScreen .bb-ar-card{background:#fff;border:1px solid #dce6f0;border-radius:13px;padding:10px;display:grid;
      grid-template-columns:28px minmax(84px,104px) minmax(0,1fr) auto;
      grid-template-areas:"check inv customer status" ". invdate duedate action" ". location location action" ". total paid outstanding";
      gap:5px 9px;align-items:start;box-shadow:0 2px 8px #173f770b;min-width:0}
    #bbOfflineModulesScreen .bb-ar-card>div{min-width:0;overflow:hidden;text-overflow:ellipsis}
    #bbOfflineModulesScreen .bb-ar-card .check{grid-area:check;color:#93abc1;align-self:center;font-size:17px}
    #bbOfflineModulesScreen .bb-ar-card .invoice{grid-area:inv;padding-left:3px}
    #bbOfflineModulesScreen .bb-ar-card .customer{grid-area:customer}
    #bbOfflineModulesScreen .bb-ar-card .invoice,#bbOfflineModulesScreen .bb-ar-card .customer{font-size:13px;font-weight:900;color:#173f77;white-space:nowrap}
    #bbOfflineModulesScreen .bb-ar-card .status{grid-area:status;justify-self:end;font-weight:800;font-size:8.5px;padding:4px 6px;border-radius:30px;background:#f1f7ff;color:#2463a1}
    #bbOfflineModulesScreen .bb-ar-card .invoice-date{grid-area:invdate}
    #bbOfflineModulesScreen .bb-ar-card .due-date{grid-area:duedate;color:#c94750}
    #bbOfflineModulesScreen .bb-ar-card .invoice-date,#bbOfflineModulesScreen .bb-ar-card .due-date{font-size:9px;white-space:nowrap;color:#647b92}
    #bbOfflineModulesScreen .bb-ar-card .due-date{color:#bb4655}
    #bbOfflineModulesScreen .bb-ar-card .location{grid-area:location;font-size:9px;color:#526b84}
    #bbOfflineModulesScreen .bb-ar-card .amt{background:#f7f9fc;border-radius:8px;padding:6px 7px;font-size:10px;font-weight:900;color:#173f77}
    #bbOfflineModulesScreen .bb-ar-card .amt:before{content:attr(data-label);display:block;color:#758599;font-size:7.5px;font-weight:700;margin-bottom:3px}
    #bbOfflineModulesScreen .bb-ar-card .total{grid-area:total}.bb-ar-card .paid{grid-area:paid}
    #bbOfflineModulesScreen .bb-ar-card .outstanding{grid-area:outstanding;background:#fff2f3;color:#bd3c49}
    /* Live Stock uses two-column summary cards and a nine-column product card grid on mobile. */
    #bbOfflineModulesScreen .bb-stock-summary{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:6px;margin-bottom:10px}
    #bbOfflineModulesScreen .bb-stock-summary .summary-card{background:#fff;border:1px solid #d9e3ee;border-radius:11px;padding:9px 10px}
    #bbOfflineModulesScreen .bb-stock-summary small{font-size:7px;font-weight:900;text-transform:uppercase}
    #bbOfflineModulesScreen .bb-stock-summary strong{font-size:17px;color:#123f73;font-weight:900}
    #bbOfflineModulesScreen .bb-stock-toolbar{position:sticky;top:49px;z-index:2;display:grid;grid-template-columns:1fr;gap:6px;background:#f9fbfd;
      padding:8px;border-radius:11px;border:1px solid #d9e3ee}
    #bbOfflineModulesScreen .bb-stock-line{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));border:1px solid #d9e3ee;border-radius:11px;
      background:#fff;margin:7px 0;overflow:hidden}
    #bbOfflineModulesScreen .bb-stock-line .product{grid-column:1/-1;padding:8px 9px;border-bottom:1px solid #e8eff5}
    #bbOfflineModulesScreen .bb-stock-line .product b{font-size:11px;color:#123f73}
    #bbOfflineModulesScreen .bb-stock-line .product small{font-size:8px;color:#708397}
    #bbOfflineModulesScreen .bb-stock-line .metric{position:relative;display:flex;flex-direction:column;align-items:center;justify-content:center;
      min-height:44px;min-width:0;padding:16px 3px 4px;border-right:1px solid #edf1f5;border-bottom:1px solid #edf1f5;
      font-size:10px;font-weight:900;color:#2368bd}
    #bbOfflineModulesScreen .bb-stock-line .metric:before{content:attr(data-label);position:absolute;top:5px;left:2px;right:2px;overflow:hidden;
      text-overflow:ellipsis;white-space:nowrap;text-align:center;font-size:6px;font-weight:900;color:#718297;text-transform:uppercase}
    #bbOfflineModulesScreen .bb-stock-line .metric:nth-child(4n+1){border-right:0}
    #bbOfflineModulesScreen .bb-stock-line .metric.green{color:#157a51}.bb-stock-line .metric.red{color:#b94141}
    #bbOfflineModulesScreen .bb-stock-line .metric.purple{color:#7450b5}.bb-stock-line .metric.amber{color:#a96900}
    #bbOfflineModulesScreen .bb-stock-line .metric.value{color:#123f73}
  `;
  document.head.appendChild(style);
  host.innerHTML='<main class="bb-off-main"><div class="bb-off-note" id="bbOffNote"></div><div id="bbOffBody"></div></main>';
  const screen=$('moduleScreen');
  if(!screen)throw new Error('BIG BROTHER mobile module shell unavailable.');
  screen.appendChild(host);
  // Hardware Back or bottom-nav changes still use the real navigation stack.
  // Close a summary modal whenever navigation leaves the module.
  new MutationObserver(()=>{
    if(screen.hidden)closeReceivableSummary();
  }).observe(screen,{attributes:true,attributeFilter:['hidden']});
  return host;
}
function close(){
  discardLivePreload();
  openEpoch++;
  closeReceivableSummary();
  if(host)host.style.display='none';
  const screen=$('moduleScreen');
  if(screen)screen.classList.remove('bb-offline-native');
  const frame=$('moduleFrame');if(frame)frame.style.display='';
  const back=$('moduleBack');if(back)back.hidden=false;
  route='';dataset=null;
}
function openNativeRoute(name,useLocalFrame=false,skipRecord=false){
  const screen=$('moduleScreen'),frame=$('moduleFrame');
  if(!screen||!frame)return false;
  // Reuse the EXACT native history stack and bottom navigation as an online module.
  ['mobileHome','menuScreen','loginScreen','bootScreen'].forEach(id=>{
    const element=$(id);if(element)element.hidden=true;
  });
  screen.hidden=false;
  screen.classList.add('bb-offline-native');
  const back=$('moduleBack');
  // Keep native Back wiring installed by mobile.js; no second back handler.
  if(back)back.hidden=true;
  const bottom=$('moduleBottomNav');
  if(bottom)bottom.hidden=false;
  const nav=window.BBMobileHistoryV7||window.BBMobileHistoryV6;
  if(nav&&!skipRecord&&!nav.isRestoring?.())nav.recordModule(name,true);
  if(!useLocalFrame){
    frame.style.display='none';
    if(host)host.style.display='block';
  }else{
    if(host)host.style.display='none';
    frame.style.display='';
  }
  return true;
}
function notice(message){const note=$('bbOffNote');if(note)note.textContent=message}
function announceOpen(name){
  if(offline()?.canUseNetwork()){
    // Prepare the full live function invisibly; the saved screen stays usable.
    stageLivePage(name);
    window.dispatchEvent(new CustomEvent('bb:cached-route-opened',{detail:{route:name}}));
  }
}

/* Seamless live-page handoff: the original cloud page loads fully out of sight.
 * We expose it only after its own data success UI is ready. We never interrupt
 * a user's selected invoice, report filter or in-progress calculation.
 */
let livePreload=null;
function discardLivePreload(){
  const entry=livePreload;
  if(!entry)return;
  livePreload=null;
  try{clearInterval(entry.interval);clearTimeout(entry.timeout)}catch(_){}
  try{entry.frame?.remove()}catch(_){}
}
function livePageReady(name,frame){
  try{
    const doc=frame.contentDocument;
    if(!doc||doc.readyState==='loading')return false;
    if(name==='stock-report'){
      return /Live Stock loaded/i.test(doc.getElementById('status')?.textContent||'') &&
        !!doc.getElementById('rows');
    }
    if(name==='sales-support-calculator'){
      const status=(doc.getElementById('calcStatus')?.textContent||'').trim();
      return !!doc.getElementById('calcCustomerSearch') && !!doc.getElementById('calcProductSearch') &&
        !!doc.getElementById('calcLocation') &&
        /ready|restored|prices loaded|local data|product prices loaded/i.test(status) &&
        !/sign in|loading|could not|error/i.test(status);
    }
    if(name==='ar-your'||name==='ar-all'||name==='sales-support-your-receivable'){
      // The AR mobile wrapper has its own nested same-origin data engine.
      // The wrapper load event alone is NOT proof that A/R data is ready.
      const inner=doc.getElementById('arMobileFrame')?.contentDocument;
      return !!inner?.getElementById('arBody') &&
        /Up to date/i.test(inner.getElementById('syncStatus')?.textContent||'') &&
        !!doc.getElementById('boot')?.classList.contains('hide');
    }
  }catch(_){return false}
  return false;
}
function commitLivePreload(entry){
  if(livePreload!==entry||entry.interacted)return;
  if(!offline()?.canUseNetwork()||route!==entry.route||currentId()!==entry.userId)return discardLivePreload();
  const screen=$('moduleScreen'),old=$('moduleFrame');
  if(!screen||screen.hidden||!old||!entry.frame?.parentNode)return discardLivePreload();
  // Do not replace an active selection, summary or calculation in progress.
  if($('bbOfflineSummaryPrint'))return discardLivePreload();
  livePreload=null;
  clearInterval(entry.interval);clearTimeout(entry.timeout);
  const original=entry.frame;
  try{
    const label=window.BBMobileLiveRoutesV1?.label(entry.route)||'BIG BROTHER';
    close(); // close saved view without adding another navigation history entry
    old.replaceWith(original);
    original.id='moduleFrame';
    original.inert=false;
    original.removeAttribute('aria-hidden');
    original.removeAttribute('tabindex');
    original.style.cssText='';
    screen.hidden=false;
    if($('moduleTitle'))$('moduleTitle').textContent=label;
    if($('moduleDesktopLink'))$('moduleDesktopLink').href='index.html?module='+encodeURIComponent(entry.route)+'&autoload=1';
  }catch(error){
    console.warn('BIG BROTHER seamless live handoff:',error);
    try{original.remove()}catch(_){}
  }
}
function stageLivePage(name){
  discardLivePreload();
  if(!offline()?.canUseNetwork()||!currentId())return;
  const raw=window.BBMobileLiveRoutesV1?.url(name);
  if(!raw)return;
  let url;
  try{
    url=new URL(raw,location.href);
    // Only inspect a trusted same-origin module. Never switch to a remote origin.
    if(url.origin!==location.origin)return;
    url.searchParams.set('bb_handoff','1');
  }catch(_){return}
  const screen=$('moduleScreen'),current=$('moduleFrame');
  if(!screen||!current||screen.hidden||!route)return;
  const entry={route:name,userId:currentId(),frame:null,interacted:false,interval:null,timeout:null};
  const staged=document.createElement('iframe');
  staged.id='bbLiveStagedFrame';
  staged.className=current.className||'module-frame';
  staged.title='BIG BROTHER loading live module';
  staged.setAttribute('aria-hidden','true');
  staged.setAttribute('tabindex','-1');
  // A background auth redirect must never navigate the top-level PWA.
  // Manual, user-activated navigation remains possible after handoff.
  staged.setAttribute('sandbox','allow-scripts allow-same-origin allow-forms allow-modals allow-popups allow-popups-to-escape-sandbox allow-downloads allow-top-navigation-by-user-activation');
  staged.inert=true;
  staged.style.cssText='position:absolute!important;top:0!important;left:0!important;right:0!important;'+
    'bottom:calc(68px + env(safe-area-inset-bottom))!important;width:100%!important;'+
    'height:calc(100dvh - 68px - env(safe-area-inset-bottom))!important;'+
    'visibility:hidden!important;opacity:0!important;pointer-events:none!important;z-index:-1!important;';
  entry.frame=staged;
  livePreload=entry;
  // User interaction always wins over a background page swap.
  const mark=event=>{
    if(livePreload!==entry||event?.isTrusted===false)return;
    entry.interacted=true;
    discardLivePreload();
  };
  if(host&&host.style.display!=='none'){
    ['pointerdown','keydown','input','change'].forEach(event=>host.addEventListener(event,mark,{once:true}));
  }else{
    const attach=()=>{
      if(livePreload!==entry)return;
      try{
        const doc=current.contentDocument;
        ['pointerdown','keydown','input','change'].forEach(event=>doc?.addEventListener(event,mark,{once:true}));
      }catch(_){}
    };
    current.addEventListener('load',attach,{once:true});
    attach();
  }
  const check=()=>{
    if(livePreload!==entry)return;
    if(!offline()?.canUseNetwork()||currentId()!==entry.userId||route!==name||screen.hidden){
      discardLivePreload();return;
    }
    if(document.visibilityState==='hidden')return;
    if(livePageReady(name,staged))commitLivePreload(entry);
  };
  screen.appendChild(staged);
  staged.addEventListener('load',check);
  entry.interval=setInterval(check,180);
  entry.timeout=setTimeout(()=>{if(livePreload===entry)discardLivePreload()},90000);
  // Start after the cached screen has already appeared. No await or spinner.
  staged.src=url.toString();
}

function showRefreshTime(){
  if(!route)return;
  const savedAt=datasetSyncedAt
    ?new Date(datasetSyncedAt).toLocaleString('en-GB',{day:'2-digit',month:'short',year:'numeric',hour:'2-digit',minute:'2-digit'})
    :'not synchronized';
  // A quiet status inside the same screen; never open a separate "live" page.
  notice('Data as of '+savedAt);
}
async function open(name){
  if(!canOpen(name)||!currentId())return false;
  discardLivePreload();
  const epoch=++openEpoch;
  const restoringAtStart=(window.BBMobileHistoryV7||window.BBMobileHistoryV6)?.isRestoring?.()===true;
  const rec=await offline()?.read(mapRoutes[name]);
  if(epoch!==openEpoch||!rec?.value)return false;
  route=name;
  dataset=rec.value;
  datasetSyncedAt=rec.syncedAt;
  selectedReceivables.clear();
  createHost();
  const date=new Date(rec.syncedAt).toLocaleString('en-GB',{day:'2-digit',month:'short',year:'numeric',hour:'2-digit',minute:'2-digit'});
  showRefreshTime();
  const frame=$('moduleFrame');
  if(name==='sales-support-calculator'||name==='stock-report'){
    const full=name==='stock-report'?await offline()?.read('offline-stock-report-full'):null;
    if(epoch!==openEpoch)return false;
    if(name==='sales-support-calculator'||full?.value?.success){
      const url=name==='sales-support-calculator'
        ?'./mobile-offline-calculator.html?mobile=1&view=calculator&v=20261028-seamless1'
        :'./mobile-offline-stock.html?embed=1&v=20261028-seamless1';
      if(!openNativeRoute(name,true,restoringAtStart))return false;
      if(frame.getAttribute('src')!==url){
        // Replace the frame rather than pushing its internal navigation history.
        // Android Back should navigate the parent BIG BROTHER app, not an iframe.
        const fresh=frame.cloneNode(false);
        fresh.removeAttribute('src');
        frame.replaceWith(fresh);
        fresh.setAttribute('src',url);
      }
      announceOpen(name);
      return true;
    }
  }
  if(!openNativeRoute(name,false,restoringAtStart))return false;
  if(name.includes('receivable')||name.startsWith('ar-'))renderReceivables();
  else renderStock();
  if(host)host.scrollTop=0;
  announceOpen(name);
  return true;
}


function invoiceIdentity(r){return clean(r.invoiceId)||[clean(r.invoiceNo),clean(r.customerId),clean(r.locationCode)].join('|')}
function invoiceIsoDate(value){
  const raw=clean(value);
  if(/^\d{4}-\d{2}-\d{2}/.test(raw))return raw.slice(0,10);
  const match=raw.match(/^(\d{1,2})[-\/]([a-z]{3}|\d{1,2})[-\/](\d{4})/i);
  if(match){
    const months=['jan','feb','mar','apr','may','jun','jul','aug','sep','oct','nov','dec'];
    const m=/^\d+$/.test(match[2])?Number(match[2]):months.indexOf(match[2].toLowerCase())+1;
    if(m>=1&&m<=12)return match[3]+'-'+String(m).padStart(2,'0')+'-'+match[1].padStart(2,'0');
  }
  return '';
}
function receivableDate(value){
  if(!value)return '—';
  const raw=clean(value);
  const match=raw.match(/^(\d{4})-(\d{2})-(\d{2})/);
  const parsed=match?new Date(Number(match[1]),Number(match[2])-1,Number(match[3])):new Date(raw);
  if(Number.isNaN(parsed.getTime()))return raw;
  return parsed.toLocaleDateString('en-GB',{day:'2-digit',month:'short',year:'numeric'}).replace(/ /g,'-');
}
function renderReceivables(){
  const rows=Array.isArray(dataset?.receivables)?dataset.receivables:[];
  const locations=[...new Set(rows.map(r=>clean(r.locationName||r.locationCode)).filter(Boolean))].sort();
  const wrap=$('bbOffBody');
  wrap.innerHTML=
    '<div class="bb-ar-toolbar"><strong class="bb-ar-total">'+rows.length+' Outstanding Invoices</strong>'+
    '<button type="button" class="bb-off-primary" id="bbOffSummaryBtn" disabled>🧾 Summary Invoice (0)</button></div>'+
    '<div class="bb-off-form" style="margin-bottom:8px">'+
    '<input id="bbOffSearch" class="wide" placeholder="Search customer / invoice" type="search" aria-label="Search saved receivables">'+
    '<select id="bbOffLocation" aria-label="Filter location"><option value="">All assigned locations</option>'+
      locations.map(loc=>'<option value="'+esc(loc)+'">'+esc(loc)+'</option>').join('')+'</select>'+
    '<select id="bbOffStatus" aria-label="Filter status"><option value="">All statuses</option><option>Outstanding</option><option>Overdue</option><option>Processing</option></select>'+
    '<details class="wide" style="background:#fff;border:1px solid #d9e3ee;border-radius:10px;padding:7px 10px">'+
      '<summary style="font-size:12px;font-weight:800;color:#244f7b">📅 Date & Outstanding Amount</summary>'+
      '<div class="bb-off-form" style="padding-top:10px"><label>From<input id="bbOffDateFrom" type="date"></label>'+
      '<label>To<input id="bbOffDateTo" type="date"></label>'+
      '<label>Minimum Outstanding<input id="bbOffMin" type="number" min="0" step="0.01" inputmode="decimal"></label>'+
      '<label>Maximum Outstanding<input id="bbOffMax" type="number" min="0" step="0.01" inputmode="decimal"></label></div>'+
    '</details></div>'+
    '<div class="bb-ar-toolbar"><button type="button" class="bb-off-muted" id="bbOffSelectAll">Select matching</button>'+
    '<button type="button" class="bb-off-muted" id="bbOffClearSelected">Clear selection</button></div>'+
    '<div id="bbOffRows" class="bb-ar-list"></div><div id="bbOffCount" class="bb-off-note"></div>';
  const fmt=(v,c)=>v==null?'—':money(v,c);
  const getFiltered=()=>{
    const q=clean($('bbOffSearch').value).toLowerCase(),loc=$('bbOffLocation').value,status=$('bbOffStatus').value;
    const from=$('bbOffDateFrom').value,to=$('bbOffDateTo').value;
    const min=clean($('bbOffMin').value),max=clean($('bbOffMax').value);
    return rows.filter(r=>{
      const day=invoiceIsoDate(r.invoiceDate);
      return (!loc||clean(r.locationName||r.locationCode)===loc)&&(!status||clean(r.arStatus)===status)
        &&[r.customer,r.invoiceNo,r.locationName,r.locationCode].some(x=>clean(x).toLowerCase().includes(q))
        &&(!from||day>=from)&&(!to||day<=to)
        &&(min===''||num(r.outstanding)>=num(min))&&(max===''||num(r.outstanding)<=num(max));
    });
  };
  function draw(){
    const filtered=getFiltered();
    $('bbOffRows').innerHTML=filtered.slice(0,500).map(r=>{
      const id=invoiceIdentity(r),enabled=num(r.outstanding)>0&&clean(r.arStatus).toLowerCase()!=='processing';
      return '<article class="bb-ar-card">'+
        '<label class="check"><input type="checkbox" data-ar-select="'+esc(id)+'" aria-label="Select '+esc(r.invoiceNo)+'"'+
        (selectedReceivables.has(id)?' checked':'')+(enabled?'':' disabled')+'></label>'+
        '<div class="invoice">'+esc(r.invoiceNo)+'</div>'+
        '<div class="customer">'+esc(r.customer||'Unknown customer')+'</div>'+
        '<div class="status">'+esc(r.arStatus||'Outstanding')+'</div>'+
        '<div class="invoice-date">Invoice: '+esc(receivableDate(r.invoiceDate))+'</div>'+
        '<div class="due-date">Due: '+esc(receivableDate(r.dueDate))+'</div>'+
        '<div class="location">📍 '+esc(r.locationName||r.locationCode||'—')+'</div>'+
        '<div class="amt total" data-label="Total">'+esc(fmt(r.grandTotal,r.currency))+'</div>'+
        '<div class="amt paid" data-label="Paid">'+esc(fmt(r.amountPaid,r.currency))+'</div>'+
        '<div class="amt outstanding" data-label="Outstanding">'+esc(fmt(r.outstanding,r.currency))+'</div>'+
      '</article>';
    }).join('')||'<div class="bb-off-card">No matching saved invoices.</div>';
    $('bbOffRows').querySelectorAll('input[data-ar-select]').forEach(checkbox=>checkbox.addEventListener('change',()=>{
      if(checkbox.checked)selectedReceivables.add(checkbox.dataset.arSelect);
      else selectedReceivables.delete(checkbox.dataset.arSelect);
      summaryButton();
    }));
    $('bbOffCount').textContent='Showing '+Math.min(500,filtered.length)+' of '+filtered.length+' matched invoices · saved snapshot only';
    summaryButton();
  }
  function summaryButton(){
    const count=rows.filter(r=>selectedReceivables.has(invoiceIdentity(r))&&num(r.outstanding)>0&&clean(r.arStatus).toLowerCase()!=='processing').length;
    $('bbOffSummaryBtn').textContent='🧾 Summary Invoice ('+count+')';
    $('bbOffSummaryBtn').disabled=count===0;
  }
  ['bbOffSearch','bbOffLocation','bbOffStatus','bbOffDateFrom','bbOffDateTo','bbOffMin','bbOffMax'].forEach(id=>
    $(id).addEventListener(['bbOffSearch','bbOffMin','bbOffMax'].includes(id)?'input':'change',draw));
  $('bbOffSelectAll').onclick=()=>{
    getFiltered().filter(r=>num(r.outstanding)>0&&clean(r.arStatus).toLowerCase()!=='processing').forEach(r=>selectedReceivables.add(invoiceIdentity(r)));
    draw();
  };
  $('bbOffClearSelected').onclick=()=>{selectedReceivables.clear();draw()};
  $('bbOffSummaryBtn').onclick=()=>openReceivableSummary(rows.filter(r=>selectedReceivables.has(invoiceIdentity(r))));
  draw();
}
function closeReceivableSummary(){
  document.body.classList.remove('bb-offline-summary-print');
  const overlay=$('bbOfflineSummaryPrint');
  if(overlay)overlay.remove();
}
function openReceivableSummary(input){
  const picked=input.filter(r=>num(r.outstanding)>0&&clean(r.arStatus).toLowerCase()!=='processing')
    .slice().sort((a,b)=>invoiceIsoDate(a.invoiceDate).localeCompare(invoiceIsoDate(b.invoiceDate)));
  if(!picked.length)return;
  closeReceivableSummary();
  // Never convert KHR to USD using an arbitrary or stale exchange rate.
  const currencies=[...new Set(picked.map(r=>clean(r.currency).toUpperCase()||'USD'))];
  const totals=Object.fromEntries(currencies.map(c=>[c,picked.filter(r=>(clean(r.currency).toUpperCase()||'USD')===c)
    .reduce((sum,r)=>sum+num(r.outstanding),0)]));
  const names=[...new Set(picked.map(r=>clean(r.customer)).filter(Boolean))];
  const synced=datasetSyncedAt?new Date(datasetSyncedAt).toLocaleString('en-GB',{day:'2-digit',month:'short',year:'numeric',hour:'2-digit',minute:'2-digit'}):'unknown';
  const dates=picked.map(r=>invoiceIsoDate(r.invoiceDate)).filter(Boolean).sort();
  const label=names.length===1?names[0]:names.length+' Selected Customers';
  const now=new Date(),summaryDay=now.getFullYear()+'-'+String(now.getMonth()+1).padStart(2,'0')+'-'+String(now.getDate()).padStart(2,'0');
  const modal=document.createElement('div');
  modal.id='bbOfflineSummaryPrint';
  modal.innerHTML='<div class="bb-summary-actions">'+
    '<strong>Customer Invoice Summary</strong>'+
    '<button type="button" id="bbSummaryClose" class="bb-off-muted">✕ Close</button>'+
    '<button type="button" id="bbSummaryPrint" class="bb-off-primary">Print / Save PDF</button></div>'+
    '<div class="bb-summary-sheet">'+
      '<div class="bb-summary-top"><div><h1>BIG BROTHER</h1><p>Ready to be your partner</p>'+
      '<small>Phnom Penh, Cambodia</small></div><div class="bb-summary-meta">'+
      '<b>Summary Date:</b> '+esc(receivableDate(summaryDay))+
      '<p><b>Selected Invoices:</b> '+picked.length+'</p>'+
      '<p><b>Data as of:</b> '+esc(synced)+'</p></div></div>'+
      '<h2>CUSTOMER INVOICE SUMMARY</h2>'+
      '<div class="bb-summary-customer"><strong>Customer</strong><div>'+esc(label)+'</div>'+
      (names.length>1?'<small>'+names.map(esc).join(' · ')+'</small>':'')+'</div>'+

      '<div class="bb-summary-period">Invoice range: '+esc(receivableDate(dates[0]))+' to '+esc(receivableDate(dates[dates.length-1]))+'</div>'+
      '<table><thead><tr><th>#</th>'+(names.length>1?'<th>Customer</th>':'')+
      '<th>Invoice</th><th>Date</th><th>Due</th><th>Total</th><th>Paid</th><th>Outstanding</th></tr></thead><tbody>'+
      picked.map((r,i)=>'<tr><td>'+(i+1)+'</td>'+(names.length>1?'<td>'+esc(r.customer)+'</td>':'')+
        '<td><b>'+esc(r.invoiceNo)+'</b></td>'+
        '<td>'+esc(receivableDate(r.invoiceDate))+'</td>'+
        '<td>'+esc(receivableDate(r.dueDate))+'</td>'+
        '<td>'+esc(r.grandTotal==null?'—':money(r.grandTotal,r.currency))+'</td>'+
        '<td>'+esc(r.amountPaid==null?'—':money(r.amountPaid,r.currency))+'</td>'+
        '<td><b>'+esc(money(r.outstanding,r.currency))+'</b></td></tr>').join('')+
      '</tbody></table>'+
      '<div class="bb-summary-totals">'+currencies.map(c=>
        '<div><span>TOTAL OUTSTANDING ('+esc(c)+')</span><strong>'+esc(money(totals[c],c))+'</strong></div>').join('')+'</div>'+
      '<footer>Invoice Summary includes only selected invoice balances. • BIG BROTHER</footer>'+
    '</div>';
  document.body.appendChild(modal);
  document.body.classList.add('bb-offline-summary-print');
  modal.querySelector('#bbSummaryClose').onclick=closeReceivableSummary;
  modal.querySelector('#bbSummaryPrint').onclick=()=>{
    // Printing a cached summary is allowed, but a permanent stale-data label stays on the document.
    window.print();
  };
}
function renderStock(){
  const rows=Array.isArray(dataset?.products)?dataset.products:[];
  const wrap=$('bbOffBody'),total=dataset?.totals||{};
  const aggregate=field=>rows.reduce((sum,row)=>sum+num(row[field]),0);
  const fmt=v=>v==null?'—':num(v).toLocaleString('en-US',{maximumFractionDigits:2});
  const categories=[...new Set(rows.map(r=>clean(r.category)).filter(Boolean))].sort();
  const summary=[
    ['Purchased WH',aggregate('warehousePurchased')],
    ['Zero-cost WH',aggregate('warehouseZeroCost')],
    ['Purchased Batch',aggregate('batchPurchased')],
    ['Zero-cost Batch',aggregate('batchZeroCost')],
    ['Total Good',aggregate('totalGood')],
    ['Stock Value',money(total.warehouseValue||0)]
  ];
  wrap.innerHTML=
    '<div class="bb-stock-summary">'+summary.map(([label,value],index)=>'<div class="summary-card"><small>'+esc(label)+'</small><strong>'+
      esc(index===5?value:fmt(value))+'</strong></div>').join('')+'</div>'+
    '<div class="bb-stock-toolbar">'+
      '<input id="bbOffSearch" placeholder="Search product / code" type="search" aria-label="Search saved stock">'+
      '<div class="bb-chips" id="bbOffChips" style="display:flex;gap:5px;overflow-x:auto;white-space:nowrap"></div>'+
    '</div><div id="bbOffRows"></div>';
  let category='';
  $('bbOffChips').innerHTML=['',...categories].map(c=>'<button class="bb-off-muted" type="button" data-cat="'+esc(c)+'">'+esc(c||'All Products')+'</button>').join('');
  function draw(){
    const q=clean($('bbOffSearch').value).toLowerCase();
    const selected=rows.filter(r=>(!category||clean(r.category)===category)&&[r.productName,r.productCode].some(x=>clean(x).toLowerCase().includes(q)));
    const cell=(name,value,variant='')=>'<div class="metric '+variant+'" data-label="'+esc(name)+'">'+esc(value==null?'—':fmt(value))+'</div>';
    $('bbOffRows').innerHTML=selected.map(r=>
      '<article class="bb-stock-line">'+
        '<div class="product"><b>'+esc(r.productName)+'</b><small>'+esc(r.productCode)+' · '+esc(r.unit)+'</small></div>'+
        cell('Purchased WH',r.warehousePurchased)+cell('Zero-Cost WH',r.warehouseZeroCost,'purple')+
        cell('Purchased Batch',r.batchPurchased,'amber')+cell('Zero-Cost Batch',r.batchZeroCost,'purple')+
        cell('Total Good',r.totalGood,'green')+cell('Damaged',r.damaged,'red')+
        cell('Avg Cost',r.averageCost)+cell('Total Value',r.totalValue,'value')+
      '</article>'
    ).join('')||'<div class="bb-off-card">No matching saved products.</div>';
  }
  $('bbOffSearch').addEventListener('input',draw);
  $('bbOffChips').querySelectorAll('[data-cat]').forEach(btn=>btn.addEventListener('click',()=>{
    category=btn.dataset.cat;draw();
    $('bbOffChips').querySelectorAll('button').forEach(item=>item.style.background=item.dataset.cat===category?'#d9eafd':'#ecf2fa');
  }));
  draw();
}
function selectCustomer(){
  const id=clean($('bbCalcCustomer').value);
  calcCustomer=(dataset.customers||[]).find(x=>clean(x.customerId)===id)||null;
  calcPrices=null;
  void offline()?.read('calc-price::'+id).then(rec=>{
    if(!route||route!=='sales-support-calculator'||clean($('bbCalcCustomer')?.value)!==id)return;
    calcPrices=rec?.value?.products||null;
    setCalculatorPrice();
  });
  setCalculatorPrice();
}
function setCalculatorPrice(){
  const code=clean($('bbCalcProduct')?.value);
  const product=(dataset.products||[]).find(x=>clean(x.code)===code);
  const price=(calcPrices||[]).find(p=>clean(p.productCode)===code);
  const selected=price?num(price.customerPriceUSD):num(product?.usdPrice||product?.priceUSD);
  if($('bbCalcPrice'))$('bbCalcPrice').value=String(selected||'');
  if($('bbCalcPriceInfo'))$('bbCalcPriceInfo').textContent=price?'Saved customer-specific price':'Default product price — verify customer agreement before use';
}
function renderCalculator(){
  const customers=Array.isArray(dataset.customers)?dataset.customers:[];
  const products=Array.isArray(dataset.products)?dataset.products:[];
  const state=stored(currentKey(),{});
  calcCurrency=state.currency==='KHR'?'KHR':'USD';
  calcRate=Math.max(1,num(state.rate)||4100);
  calcDiscount=Math.max(0,num(state.discountUSD));
  calcLines=Array.isArray(state.lines)?state.lines:[];
  $('bbOffBody').innerHTML=`
    <div class="bb-off-card"><strong>Local calculator</strong><small>Calculations and history stay on this device. This is an offline view; customer names/products use saved cloud data.</small></div>
    <div class="bb-off-card bb-off-form">
      <label class="wide">Customer<input id="bbCalcCustomerSearch" placeholder="Search saved customer..." autocomplete="off"></label>
      <label class="wide"><select id="bbCalcCustomer"><option value="">Select customer</option>${customers.slice(0,2000).map(c=>`<option value="${esc(c.customerId)}">${esc(c.name)} — ${esc(c.locationCode)}</option>`).join('')}</select></label>
      <label class="wide">Product<select id="bbCalcProduct"><option value="">Choose product</option>${products.map(p=>`<option value="${esc(p.code)}">${esc(p.name)} (${esc(p.unit)})</option>`).join('')}</select></label>
      <label>Quantity<input id="bbCalcQty" inputmode="decimal" type="number" min="0" step="any" value="1"></label>
      <label>Price USD<input id="bbCalcPrice" inputmode="decimal" type="number" min="0" step="any"></label>
      <small class="wide" id="bbCalcPriceInfo">Default product price</small>
      <button class="bb-off-primary wide" id="bbCalcAdd" type="button">+ Add Product</button>
    </div>
    <div class="bb-off-card"><strong>Calculation lines</strong><div id="bbCalcLines"></div></div>
    <div class="bb-off-card bb-off-form">
      <label>Currency<select id="bbCalcCurrency"><option>USD</option><option>KHR</option></select></label>
      <label>Exchange rate (KHR / USD)<input id="bbCalcRate" inputmode="decimal" type="number" min="1" step="any" value="${esc(calcRate)}"></label>
      <label class="wide">Discount USD<input id="bbCalcDiscount" inputmode="decimal" type="number" min="0" step="any" value="${esc(calcDiscount)}"></label>
      <div class="wide" id="bbCalcTotal"></div>
      <button class="bb-off-primary wide" id="bbCalcSave" type="button">Save to Device History</button>
    </div>
    <div class="bb-off-card"><strong>Saved History</strong><div id="bbCalcHistory"></div></div>`;
  $('bbCalcCustomer').value=clean(state.customerKey).replace(/^id:/,'');
  $('bbCalcCurrency').value=calcCurrency;
  $('bbCalcCustomerSearch').addEventListener('input',()=>{
    const q=clean($('bbCalcCustomerSearch').value).toLowerCase();
    const select=$('bbCalcCustomer');
    select.innerHTML='<option value="">Select customer</option>'+customers.filter(c=>[c.name,c.customerId,c.locationCode].some(x=>clean(x).toLowerCase().includes(q))).slice(0,150).map(c=>`<option value="${esc(c.customerId)}">${esc(c.name)} — ${esc(c.locationCode)}</option>`).join('');
    selectCustomer();drawCalc(true);
  });
  $('bbCalcCustomer').addEventListener('change',()=>{selectCustomer();drawCalc(true)});
  $('bbCalcProduct').addEventListener('change',setCalculatorPrice);
  $('bbCalcCurrency').addEventListener('change',()=>{calcCurrency=$('bbCalcCurrency').value;drawCalc(true)});
  $('bbCalcRate').addEventListener('input',()=>drawCalc(true));
  $('bbCalcDiscount').addEventListener('input',()=>drawCalc(true));
  $('bbCalcAdd').addEventListener('click',()=>{
    const code=clean($('bbCalcProduct').value),product=products.find(p=>clean(p.code)===code);
    const qty=num($('bbCalcQty').value),price=num($('bbCalcPrice').value);
    if(!product||qty<=0||price<0){alert('Choose a product with a valid quantity and price.');return}
    calcLines.push({id:'CALC-'+Date.now()+'-'+Math.random().toString(36).slice(2,7),
      productCode:code,productName:product.name,unit:product.unit,qty,usdPrice:price,defaultUsdPrice:num(product.usdPrice),manualPrice:true});
    drawCalc(true);
  });
  $('bbCalcSave').addEventListener('click',()=>{
    const snapshot=calcState();
    if(!snapshot.customerKey||!calcLines.length){alert('Select a customer and add at least one product.');return}
    const entry={...snapshot,id:'CALCH-'+Date.now()+'-'+Math.random().toString(36).slice(2,7),createdAt:Date.now()};
    const rows=[entry,...history()].slice(0,100);
    if(saveLocal(historyKey(),rows)){saveLocal(currentKey(),snapshot);drawCalc(true);alert('Saved locally on this device. No cloud invoice created.')}
    else alert('Local storage unavailable. The calculation was not saved.');
  });
  selectCustomer();drawCalc();
}
function calcState(){
  const customer=(dataset?.customers||[]).find(c=>clean(c.customerId)===clean($('bbCalcCustomer')?.value));
  return {savedAt:Date.now(),currency:calcCurrency,rate:Math.max(1,num($('bbCalcRate')?.value)||4100),
    discountUSD:Math.max(0,num($('bbCalcDiscount')?.value)),
    locationCode:clean(customer?.locationCode),customerKey:customer?.customerId?'id:'+clean(customer.customerId):'',customerName:clean(customer?.name),
    customerMapUrl:clean(customer?.googleMapsLink),lines:calcLines.map(x=>({...x}))};
}
function drawCalc(saveDraft=false){
  if(route!=='sales-support-calculator')return;
  const totals=calcLines.reduce((sum,p)=>sum+num(p.qty)*num(p.usdPrice),0);
  const discount=Math.max(0,num($('bbCalcDiscount').value));
  const rate=Math.max(1,num($('bbCalcRate').value)||4100);
  const grand=Math.max(0,totals-discount);
  $('bbCalcLines').innerHTML=calcLines.map((l,i)=>`<div class="bb-off-data" style="padding:7px 0;border-bottom:1px solid #e5edf4"><div><strong>${esc(l.productName)} · ${esc(l.qty)} × ${esc(money(l.usdPrice))}</strong><small>${esc(l.unit)} · ${esc(l.productCode)}</small></div><button class="bb-off-muted" data-remove="${i}">×</button></div>`).join('')||'<small>No products added yet.</small>';
  $('bbCalcLines').querySelectorAll('[data-remove]').forEach(btn=>btn.onclick=()=>{calcLines.splice(Number(btn.dataset.remove),1);drawCalc(true)});
  $('bbCalcTotal').innerHTML='<strong>Grand Total: '+esc(calcCurrency==='KHR'?money(grand*rate,'KHR'):money(grand))+'</strong><small>Subtotal USD '+esc(money(totals))+' · Discount USD '+esc(money(discount))+'</small>';
  $('bbCalcHistory').innerHTML=history().slice(0,25).map(h=>`<div class="bb-off-data" style="padding:8px 0;border-bottom:1px solid #e5edf4"><div><strong>${esc(h.customerName)}</strong><small>${esc(new Date(h.createdAt).toLocaleDateString('en-GB'))} · ${(h.lines||[]).length} items</small></div><button class="bb-off-muted" data-load-history="${esc(h.id)}">Open</button></div>`).join('')||'<small>No saved calculations.</small>';
  $('bbCalcHistory').querySelectorAll('[data-load-history]').forEach(btn=>btn.onclick=()=>{
    const entry=history().find(h=>h.id===btn.dataset.loadHistory);if(!entry)return;
    calcLines=Array.isArray(entry.lines)?entry.lines.map(x=>({...x})):[];
    $('bbCalcCustomer').value=clean(entry.customerKey).replace(/^id:/,'');
    $('bbCalcCurrency').value=calcCurrency=entry.currency==='KHR'?'KHR':'USD';
    $('bbCalcRate').value=entry.rate||4100;
    $('bbCalcDiscount').value=entry.discountUSD||0;
    selectCustomer();drawCalc(true);
  });
  // Opening the offline Calculator must never overwrite an existing draft.
  if(saveDraft)saveLocal(currentKey(),calcState());
}
function snapshotFor(key,data){
  if(!data?.success)return null;
  if(key==='offline-ar-your'||key==='offline-ar-all'){
    return {success:true,receivables:(Array.isArray(data.receivables)?data.receivables:[]).map(r=>({
      invoiceId:r.invoiceId,invoiceNo:r.invoiceNo,invoiceDate:r.invoiceDate,
      dueDate:r.dueDate,customer:r.customer,customerId:r.customerId,
      locationCode:r.locationCode,locationName:r.locationName,currency:r.currency,
      grandTotal:r.grandTotal,amountPaid:r.amountPaid,outstanding:r.outstanding,arStatus:r.arStatus
    }))};
  }
  if(key==='offline-stock-report'){
    return {success:true,products:(Array.isArray(data.products)?data.products:[]).map(r=>({
      productCode:r.productCode,productName:r.productName,unit:r.unit,category:r.category,
      warehousePurchased:r.warehousePurchased,warehouseZeroCost:r.warehouseZeroCost,
      warehousePhysical:r.warehousePhysical,batchPurchased:r.batchPurchased,
      batchZeroCost:r.batchZeroCost,batchPhysical:r.batchPhysical,
      totalGood:r.totalGood,damaged:r.damaged,averageCost:r.averageCost,totalValue:r.totalValue
    })),totals:{warehouseValue:data?.totals?.warehouseValue||0}};
  }
  if(key==='offline-calc-batch-scope'){
    const items=Array.isArray(data.items)?data.items:[];
    return {success:true,openBatchCount:num(data.openBatchCount),
      items:items.map(item=>({code:clean(item.code||item.productCode||item.product_code)})).filter(item=>item.code)};
  }
  if(key==='offline-calc-bootstrap'){
    return {success:true,locations:(Array.isArray(data.locations)?data.locations:[]).map(l=>({
      locationCode:l.locationCode,locationName:l.locationName,salespersonName:l.salespersonName
    })),customers:(Array.isArray(data.customers)?data.customers:[]).map(c=>({
      customerId:c.customerId,name:c.name,locationCode:c.locationCode,googleMapsLink:c.googleMapsLink
    })),products:(Array.isArray(data.products)?data.products:[]).map(p=>({
      code:p.code,name:p.name,unit:p.unit,usdPrice:p.usdPrice
    }))};
  }
  return null;
}
let syncing=false;
async function sync(safeRpc,canRoute,force=false){
  const api=offline();if(!api?.canUseNetwork()||!currentId()||syncing)return;
  const last=await api.read('offline-modules-last-sync-v5');
  if(!force&&last?.value?.at&&Date.now()-last.value.at<30*60*1000)return;
  syncing=true;
  const jobs=[];
  if(canRoute('ar-your')||canRoute('sales-support-your-receivable')){
    jobs.push(['offline-ar-your','bb_ar_list']);
  }
  if(canRoute('ar-all'))jobs.push(['offline-ar-all','bb_ar_list_all']);
  if(canRoute('stock-report'))jobs.push(['offline-stock-report','bb_stock_report_fast']);
  if(canRoute('sales-support-calculator')){
    jobs.push(['offline-calc-bootstrap','bb_sales_support_bootstrap']);
    jobs.push(['offline-calc-batch-scope','bb_sales_support_calculator_batch_scope']);
  }
  let allOK=true;
  try{
    // Make at most two concurrent read-only requests.
    for(let i=0;i<jobs.length;i+=2){
      if(!api.canUseNetwork())return;
      const group=jobs.slice(i,i+2);
      const fetched=await Promise.allSettled(group.map(([,fn])=>safeRpc(fn)));
      for(let j=0;j<group.length;j++){
        const value=fetched[j].status==='fulfilled'?fetched[j].value:null;
        const minimal=snapshotFor(group[j][0],value);
        if(minimal&&api.canUseNetwork()){
          await api.write(group[j][0],minimal);
          if(group[j][0]==='offline-stock-report'){
            await api.write('offline-stock-report-full',value);
          }
          // If a cached view is open, refresh it in place rather than navigating.
          if(mapRoutes[route]===group[j][0])updateVisibleDataset(group[j][0],minimal);
        }else allOK=false;
      }
    }
    if(api.canUseNetwork())await api.write('offline-modules-last-sync-v5',{at:Date.now(),allOK});
  }finally{syncing=false}
}

const refreshPending=new Map();
const refreshedAt=new Map();
const routeRpcs={
  'ar-your':[['offline-ar-your','bb_ar_list']],
  'sales-support-your-receivable':[['offline-ar-your','bb_ar_list']],
  'ar-all':[['offline-ar-all','bb_ar_list_all']],
  'stock-report':[['offline-stock-report','bb_stock_report_fast']],
  'sales-support-calculator':[
    ['offline-calc-bootstrap','bb_sales_support_bootstrap'],
    ['offline-calc-batch-scope','bb_sales_support_calculator_batch_scope']
  ]
};
function updateVisibleDataset(key,value){
  if(!route||$('moduleScreen')?.hidden)return;
  if(route==='sales-support-calculator'&&(key==='offline-calc-bootstrap'||key==='offline-calc-batch-scope')){
    try{$('moduleFrame')?.contentWindow?.postMessage({type:'bb:calc-snapshot-refreshed',key},location.origin)}catch(_){}
    return;
  }
  if(mapRoutes[route]!==key)return;
  // A displayed summary must remain a stable historical selection while printing.
  if($('bbOfflineSummaryPrint'))return;
  dataset=value;
  datasetSyncedAt=Date.now();
  showRefreshTime();
  if(key==='offline-ar-your'||key==='offline-ar-all'){
    const ids=['bbOffSearch','bbOffLocation','bbOffStatus','bbOffDateFrom','bbOffDateTo','bbOffMin','bbOffMax'];
    const selection=Object.fromEntries(ids.map(id=>[id,$(id)?.value]));
    const y=host?.scrollTop||0;
    const availableIds=new Set((value.receivables||[]).map(invoiceIdentity));
    for(const id of selectedReceivables)if(!availableIds.has(id))selectedReceivables.delete(id);
    renderReceivables();
    ids.forEach(id=>{if($(id)&&selection[id]!=null)$(id).value=selection[id]});
    $('bbOffSearch')?.dispatchEvent(new Event('input'));
    if(host)host.scrollTop=y;
  }else if(key==='offline-stock-report'){
    // Refresh the original Stock Report data inside the same iframe, without navigation.
    try{$('moduleFrame')?.contentWindow?.postMessage({type:'bb:stock-snapshot-refreshed'},location.origin)}catch(_){}
  }
}
async function refreshRoute(name,safeRpc,canRoute){
  const api=offline(),jobs=routeRpcs[name];
  if(!jobs||!api?.canUseNetwork()||!currentId()||!canRoute(name))return false;
  const key=name+'::'+currentId();
  if(Date.now()-(refreshedAt.get(key)||0)<120000)return false;
  if(refreshPending.has(key))return refreshPending.get(key);
  const request=(async()=>{
    let any=false;
    const user=currentId();
    for(const [storeKey,rpcName] of jobs){
      if(!api.canUseNetwork()||currentId()!==user)return any;
      // These are read-only permission-checked RPCs; don't block cached rendering.
      let response;
      try{response=await safeRpc(rpcName)}catch(_){response=null}
      const minimal=snapshotFor(storeKey,response);
      if(!minimal||!api.canUseNetwork()||currentId()!==user)continue;
      const wrote=await api.write(storeKey,minimal);
      if(!wrote)continue;
      if(storeKey==='offline-stock-report')await api.write('offline-stock-report-full',response);
      any=true;
      if(route===name)updateVisibleDataset(storeKey,minimal);
    }
    if(any)refreshedAt.set(key,Date.now());
    return any;
  })();
  refreshPending.set(key,request);
  try{return await request}finally{refreshPending.delete(key)}
}

window.BBMobileOfflineModulesV1={open,canOpen,available,sync,refreshRoute,close};
})();
