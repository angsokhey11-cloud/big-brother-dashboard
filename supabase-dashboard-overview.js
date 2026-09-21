/* BIG BROTHER — Desktop Overview Dashboard V3 · Admin + Staff */
(function(){
'use strict';

const SUPABASE_URL='https://sjfhlaclgmkwwofzstok.supabase.co';
const SUPABASE_KEY='sb_publishable_w762jR65CWwlO30fKQsYOw_6L9grx8S';
const SESSION_KEY='BB_SUPABASE_DEV_SESSION_V1';
const COLORS=['#2f6fed','#22a06b','#ff9f1c','#ef5350','#7c4dce','#27a9c7','#f4c20d','#7f8c8d'];
let installed=false;
let loading=false;
let liveTimer=null;
let homeObserver=null;
let lastRefreshAt=0;
const LIVE_REFRESH_MS=20000;

const $=id=>document.getElementById(id);
const num=v=>Number(v||0)||0;
const money=v=>'$'+num(v).toLocaleString('en-US',{minimumFractionDigits:2,maximumFractionDigits:2});
const qty=v=>num(v).toLocaleString('en-US',{maximumFractionDigits:2});
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const nativeAmount=(v,c)=>String(c||'USD').toUpperCase()==='KHR'?'៛'+Math.round(num(v)).toLocaleString('en-US'):money(v);
const profile=()=>window.BBDashboardAdapter?.getProfile?.()||null;
const isAdmin=()=>Boolean(profile()?.user?.isAdmin);
const moduleKey=v=>String(v||'').trim().toLowerCase();
function canModule(name){
  const p=profile();
  if(!p)return false;
  if(p.user?.isAdmin)return true;
  const wanted=moduleKey(name);
  return (Array.isArray(p.modules)?p.modules:[]).some(x=>
    moduleKey(x.moduleKey)===wanted && x.canView===true
  );
}

function readSession(){
  try{return window.BBDashboardAdapter?.getSession?.()||JSON.parse(localStorage.getItem(SESSION_KEY)||'null')}catch(_){return null}
}
function saveSession(s){try{localStorage.setItem(SESSION_KEY,JSON.stringify(s))}catch(_){}}
async function parseResponse(r){const t=await r.text();let d={};try{d=t?JSON.parse(t):{}}catch(_){d={message:t}}if(!r.ok)throw new Error(d.message||d.error_description||d.error||('Request failed ('+r.status+')'));return d}
async function freshSession(){
  let s=readSession();
  if(!s?.access_token)throw new Error('Please sign in to BIG BROTHER.');
  const now=Math.floor(Date.now()/1000);
  if(s.expires_at&&Number(s.expires_at)<now+45){
    if(!s.refresh_token)throw new Error('Session expired. Please sign in again.');
    const r=await fetch(SUPABASE_URL+'/auth/v1/token?grant_type=refresh_token',{method:'POST',headers:{apikey:SUPABASE_KEY,'Content-Type':'application/json'},body:JSON.stringify({refresh_token:s.refresh_token}),cache:'no-store'});
    s=await parseResponse(r);saveSession(s);
  }
  return s;
}
async function rpc(fn,args={}){
  let s=await freshSession();
  let r=await fetch(SUPABASE_URL+'/rest/v1/rpc/'+fn,{method:'POST',headers:{apikey:SUPABASE_KEY,Authorization:'Bearer '+s.access_token,'Content-Type':'application/json'},body:JSON.stringify(args),cache:'no-store'});
  if(r.status===401){s=await freshSession();r=await fetch(SUPABASE_URL+'/rest/v1/rpc/'+fn,{method:'POST',headers:{apikey:SUPABASE_KEY,Authorization:'Bearer '+s.access_token,'Content-Type':'application/json'},body:JSON.stringify(args),cache:'no-store'})}
  return parseResponse(r);
}

function openShortcut(route){
  if(!route)return false;

  /*
   * Sales Support "Your ..." desktop pages are installed by their own
   * controllers and are not part of the legacy MODULE_URLS map.
   * Open them through their real controller so Overview cards behave
   * exactly like the matching left-menu function.
   */
  const personalOpeners={
    'sales-support-your-invoices':()=>window.BBYourInvoices?.open?.(true),
    'sales-support-your-collection':()=>window.BBYourCollection?.open?.(true),
    'sales-support-your-receivable':()=>window.BBYourReceivable?.open?.(true),
    'sales-support-your-stock':()=>window.BBYourStock?.open?.(true)
  };

  if(personalOpeners[route]){
    const result=personalOpeners[route]();
    if(result!==undefined)return result;
  }

  if(['monthly-sales-report','income-statement-report','purchase-order-report'].includes(route)){
    return window.BBCompanyFeatures?.open?.(route)??false;
  }

  if(typeof window.loadWorkspace==='function')return window.loadWorkspace(route,true);
  return false;
}
function shortcutAttrs(route,label){
  const r=String(route||'');
  const a=String(label||'Open report');
  return `class="bb-ov-clickable" role="button" tabindex="0" title="${esc(a)}" aria-label="${esc(a)}" data-route="${esc(r)}" onclick="window.BBMonthlyOverview?.openShortcut('${esc(r)}')" onkeydown="if(event.key==='Enter'||event.key===' '){event.preventDefault();window.BBMonthlyOverview?.openShortcut('${esc(r)}')}"`;
}

function styles(){
  if($('bbOverviewStyle'))return;
  const s=document.createElement('style');s.id='bbOverviewStyle';s.textContent=`
  .dashboard-home{background:#f1f6fb!important;padding:24px!important}
  .dashboard-home>.topbar{margin-bottom:14px!important}
  .bb-ov{max-width:1760px;margin:0 auto;color:#17324f}
  .bb-ov-monthbar{display:flex;align-items:center;justify-content:space-between;gap:14px;background:#fff;border:1px solid #d7e2ee;border-radius:14px;padding:14px 16px;margin-bottom:12px;box-shadow:0 6px 18px rgba(20,55,90,.05)}
  .bb-ov-monthbar strong{display:block;color:#17457a;font-size:15px}.bb-ov-monthbar span{display:block;margin-top:4px;color:#718398;font-size:11px}
  .bb-ov-monthctl{display:flex;align-items:end;gap:8px}.bb-ov-field label{display:block;font-size:9px;font-weight:900;text-transform:uppercase;color:#718398;margin-bottom:5px}.bb-ov-field input{height:40px;border:1px solid #cad8e7;border-radius:9px;padding:7px 10px;color:#17324f;background:#fff;font-size:12px;font-weight:800}
  .bb-ov-btn{height:40px;border:0;border-radius:9px;padding:0 14px;background:#17457a;color:#fff;font-size:11px;font-weight:900;cursor:pointer}.bb-ov-btn:disabled{opacity:.55;cursor:wait}
  .bb-ov-kpis{display:grid;grid-template-columns:repeat(9,minmax(120px,1fr));gap:8px;margin-bottom:12px}
  .bb-ov-kpi{min-width:0;background:#fff;border:1px solid #d7e2ee;border-radius:12px;padding:13px 12px;box-shadow:0 5px 16px rgba(20,55,90,.045);position:relative;overflow:hidden}
  .bb-ov-kpi:before{content:'';position:absolute;left:0;top:0;bottom:0;width:4px;background:var(--a,#2f6fed)}
  .bb-ov-kpi .i{font-size:21px}.bb-ov-kpi small{display:block;margin-top:6px;color:#65798e;font-size:9px;font-weight:900;text-transform:uppercase;line-height:1.3}.bb-ov-kpi strong{display:block;margin-top:6px;color:var(--a,#17457a);font-size:21px;white-space:nowrap}.bb-ov-kpi em{display:block;margin-top:5px;color:#8a9aab;font-style:normal;font-size:9px}
  .bb-ov-clickable{cursor:pointer;transition:transform .16s ease,box-shadow .16s ease,border-color .16s ease}
  .bb-ov-clickable:hover{transform:translateY(-2px);box-shadow:0 10px 24px rgba(24,74,130,.13)!important;border-color:#8fb5df!important}
  .bb-ov-clickable:focus-visible{outline:3px solid rgba(47,111,237,.25);outline-offset:2px}
  .bb-ov-clickable .i,.bb-ov-clickable .ic{transition:transform .16s ease}.bb-ov-clickable:hover .i,.bb-ov-clickable:hover .ic{transform:scale(1.12)}
  .bb-ov-grid3{display:grid;grid-template-columns:1.25fr .9fr .9fr;gap:10px;margin-bottom:10px}.bb-ov-grid2{display:grid;grid-template-columns:1.45fr .75fr;gap:10px;margin-bottom:10px}
  .bb-ov-card{background:#fff;border:1px solid #d7e2ee;border-radius:14px;box-shadow:0 6px 20px rgba(20,55,90,.05);overflow:hidden;min-width:0}
  .bb-ov-head{display:flex;align-items:center;justify-content:space-between;gap:8px;padding:12px 14px;border-bottom:1px solid #e3eaf2}.bb-ov-head strong{color:#17457a;font-size:14px}.bb-ov-head span{font-size:9px;color:#8191a2}.bb-ov-link{border:1px solid #d4e2f1;background:#f6faff;color:#2b67aa;border-radius:8px;padding:7px 10px;font-size:9px;font-weight:900;cursor:pointer}
  .bb-ov-locbody{display:grid;grid-template-columns:220px 1fr;gap:14px;padding:16px;align-items:center}.bb-ov-pie{width:190px;height:190px;border-radius:50%;margin:auto;box-shadow:inset 0 0 0 1px rgba(0,0,0,.04);position:relative}.bb-ov-pie:after{content:'';position:absolute;inset:45px;border-radius:50%;background:#fff;box-shadow:0 0 0 1px #e3eaf2}.bb-ov-piecenter{position:absolute;inset:0;display:flex;z-index:1;align-items:center;justify-content:center;text-align:center;pointer-events:none}.bb-ov-piecenter div{font-size:9px;color:#718398}.bb-ov-piecenter strong{display:block;color:#17457a;font-size:15px;margin-top:2px}
  .bb-ov-legend{display:flex;flex-direction:column;gap:8px}.bb-ov-legrow{display:grid;grid-template-columns:10px minmax(90px,1fr) 90px 48px;gap:8px;align-items:center;font-size:10px}.bb-ov-dot{width:9px;height:9px;border-radius:50%}.bb-ov-legname{font-weight:800;color:#31506f;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.bb-ov-legamt{text-align:right;color:#17457a;font-weight:900}.bb-ov-legpct{text-align:right;color:#6f8195;font-weight:800}
  .bb-ov-perf{padding:16px}.bb-ov-perfrow{display:grid;grid-template-columns:100px 1fr 92px;gap:9px;align-items:center;margin:13px 0}.bb-ov-perfrow label{font-size:10px;font-weight:800;color:#60758b}.bb-ov-track{height:15px;border-radius:999px;background:#eaf0f6;overflow:hidden}.bb-ov-fill{height:100%;border-radius:999px;min-width:0}.bb-ov-perfrow b{text-align:right;color:#173f77;font-size:11px}
  .bb-ov-snap{padding:16px}.bb-ov-snapitem{margin-bottom:17px}.bb-ov-snapline{display:flex;justify-content:space-between;gap:10px;font-size:10px;color:#5e738a}.bb-ov-snapline strong{font-size:14px;color:#173f77}.bb-ov-snaptrack{height:16px;border-radius:5px;background:#e7edf4;overflow:hidden;margin-top:8px}.bb-ov-snapfill{height:100%}.bb-ov-diff{border-top:1px solid #e4ebf3;margin-top:8px;padding-top:12px;display:flex;justify-content:space-between;gap:10px;align-items:end}.bb-ov-diff small{color:#7d8ea0;font-size:9px}.bb-ov-diff strong{color:#18864b;font-size:18px}
  .bb-ov-activity{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:9px;padding:13px}.bb-ov-act{border:1px solid #e0e8f1;border-radius:10px;padding:12px 10px;text-align:center;background:linear-gradient(135deg,var(--bg,#eef5ff),#fff)}.bb-ov-act .ic{font-size:23px}.bb-ov-act strong{display:block;margin-top:6px;color:#17457a;font-size:22px}.bb-ov-act span{display:block;margin-top:3px;color:#687c91;font-size:10px;font-weight:800}
  .bb-ov-attn{padding:4px 13px 11px}.bb-ov-attrow{display:grid;grid-template-columns:10px 1fr auto;gap:9px;align-items:center;padding:9px 0;border-bottom:1px solid #edf1f5;font-size:10px}.bb-ov-attrow:last-child{border-bottom:0}.bb-ov-attdot{width:8px;height:8px;border-radius:50%}.bb-ov-attrow strong{min-width:30px;text-align:center;padding:3px 7px;border-radius:999px;background:#f4f7fa;color:#17457a}
  .bb-ov-tablewrap{overflow:auto}.bb-ov-table{width:100%;border-collapse:collapse;min-width:760px}.bb-ov-table th,.bb-ov-table td{padding:9px 10px;border-bottom:1px solid #e8eef5;text-align:left;font-size:9px}.bb-ov-table th{background:#f7faff;color:#61758a;text-transform:uppercase;font-size:8px}.bb-ov-table .amt{text-align:right;font-weight:900;color:#173f77}.bb-ov-badge{display:inline-block;border-radius:999px;padding:4px 8px;background:#edf9f3;color:#18864b;font-weight:900}.bb-ov-badge.warn{background:#fff4e7;color:#a96d00}.bb-ov-badge.bad{background:#fff0ef;color:#b93730}
  .bb-ov-info{padding:8px 13px}.bb-ov-inforow{display:flex;justify-content:space-between;gap:12px;padding:9px 0;border-bottom:1px solid #e8eef5;font-size:10px}.bb-ov-inforow span{color:#6e8094}.bb-ov-inforow strong{color:#17457a;text-align:right}.bb-ov-note{margin:10px 0 2px;padding:10px;border-radius:9px;background:#edf5ff;color:#4f6f91;font-size:9px;line-height:1.45}
  .bb-ov-loading{padding:50px 20px;text-align:center;color:#17457a;font-size:13px;font-weight:900}.bb-ov-error{margin-bottom:10px;padding:10px 12px;border:1px solid #efcaca;background:#fff1f1;color:#a5312b;border-radius:10px;font-size:11px;font-weight:800}

  .bb-staff-hero{display:grid;grid-template-columns:minmax(0,1.4fr) minmax(320px,.8fr);gap:12px;margin-bottom:12px}
  .bb-staff-welcome{position:relative;overflow:hidden;background:linear-gradient(135deg,#173f77 0%,#245f9f 58%,#2f78bb 100%);border-radius:16px;padding:20px 22px;color:#fff;box-shadow:0 10px 28px rgba(23,63,119,.16)}
  .bb-staff-welcome:after{content:'';position:absolute;width:220px;height:220px;border-radius:50%;right:-90px;top:-105px;background:rgba(255,255,255,.09)}
  .bb-staff-welcome small{display:block;font-size:10px;font-weight:900;letter-spacing:.6px;text-transform:uppercase;opacity:.78}
  .bb-staff-welcome h2{margin:7px 0 5px;font-size:27px;line-height:1.15}
  .bb-staff-welcome p{margin:0;max-width:760px;font-size:11px;line-height:1.55;opacity:.88}
  .bb-staff-meta{display:flex;flex-wrap:wrap;gap:7px;margin-top:15px}
  .bb-staff-meta span{display:inline-flex;align-items:center;min-height:29px;padding:0 10px;border:1px solid rgba(255,255,255,.18);border-radius:999px;background:rgba(255,255,255,.10);font-size:9px;font-weight:900}
  .bb-staff-scope{background:#fff;border:1px solid #d7e2ee;border-radius:16px;padding:16px;box-shadow:0 7px 22px rgba(20,55,90,.055)}
  .bb-staff-scope-head{display:flex;align-items:center;justify-content:space-between;gap:10px}
  .bb-staff-scope-head strong{color:#17457a;font-size:14px}.bb-staff-scope-head span{color:#75889c;font-size:9px;font-weight:800}
  .bb-staff-locations{display:flex;flex-wrap:wrap;gap:7px;margin-top:12px}
  .bb-staff-loc{display:inline-flex;align-items:center;gap:5px;padding:7px 9px;border:1px solid #d3e2f0;border-radius:999px;background:#f4f9fe;color:#285b8a;font-size:9px;font-weight:900}
  .bb-staff-scope-note{margin-top:12px;padding-top:11px;border-top:1px solid #edf1f5;color:#718398;font-size:9px;line-height:1.45}
  .bb-staff-kpis{display:grid;grid-template-columns:repeat(5,minmax(145px,1fr));gap:9px;margin-bottom:12px}
  .bb-staff-kpi{position:relative;min-width:0;min-height:112px;padding:15px;border:1px solid #d7e2ee;border-radius:14px;background:#fff;box-shadow:0 6px 18px rgba(20,55,90,.045);overflow:hidden}
  .bb-staff-kpi:before{content:'';position:absolute;left:0;top:0;bottom:0;width:4px;background:var(--a,#2f6fed)}
  .bb-staff-kpi .ic{font-size:22px}.bb-staff-kpi small{display:block;margin-top:8px;color:#64798f;font-size:9px;font-weight:900;text-transform:uppercase;letter-spacing:.2px}
  .bb-staff-kpi strong{display:block;margin-top:6px;color:#173f77;font-size:23px;line-height:1.05}
  .bb-staff-kpi em{display:block;margin-top:7px;color:#8797a8;font-style:normal;font-size:9px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
  .bb-staff-kpi.clickable{cursor:pointer;transition:transform .16s ease,box-shadow .16s ease,border-color .16s ease}
  .bb-staff-kpi.clickable:hover{transform:translateY(-2px);box-shadow:0 10px 25px rgba(24,74,130,.12);border-color:#8fb5df}
  .bb-staff-grid{display:grid;grid-template-columns:1.15fr .85fr;gap:10px;margin-bottom:10px}
  .bb-staff-actions{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:9px;padding:13px}
  .bb-staff-action{border:1px solid #dce7f1;border-radius:12px;padding:13px;background:linear-gradient(145deg,#f7fbff,#eef6fd);color:#173f77;text-align:left;cursor:pointer;min-height:88px}
  .bb-staff-action:hover{border-color:#9ec2e2;box-shadow:0 7px 18px rgba(31,79,126,.09)}
  .bb-staff-action .ic{font-size:22px}.bb-staff-action strong{display:block;margin-top:7px;font-size:11px}.bb-staff-action span{display:block;margin-top:4px;color:#72869a;font-size:8.5px;line-height:1.35}
  .bb-staff-sales{padding:15px}
  .bb-staff-sales-row{display:grid;grid-template-columns:150px 1fr 105px;gap:10px;align-items:center;padding:10px 0;border-bottom:1px solid #edf1f5}
  .bb-staff-sales-row:last-child{border-bottom:0}.bb-staff-sales-row span{color:#61778d;font-size:10px;font-weight:800}.bb-staff-sales-row b{text-align:right;color:#173f77;font-size:11px}
  .bb-staff-sales-track{height:12px;border-radius:999px;background:#eaf0f6;overflow:hidden}.bb-staff-sales-fill{height:100%;border-radius:999px}
  .bb-staff-account{padding:7px 14px 13px}
  .bb-staff-account-row{display:flex;justify-content:space-between;gap:16px;padding:10px 0;border-bottom:1px solid #edf1f5;font-size:10px}.bb-staff-account-row:last-child{border-bottom:0}.bb-staff-account-row span{color:#718398}.bb-staff-account-row strong{color:#173f77;text-align:right}
  @media(min-width:1460px){
    .bb-ov-monthbar strong{font-size:17px}.bb-ov-monthbar span{font-size:12px}.bb-ov-field label{font-size:10px}.bb-ov-field input{font-size:13px}.bb-ov-btn{font-size:12px}
    .bb-ov-kpi{padding:15px 13px}.bb-ov-kpi .i{font-size:24px}.bb-ov-kpi small{font-size:10px}.bb-ov-kpi strong{font-size:24px}.bb-ov-kpi em{font-size:10px}
    .bb-ov-head{padding:14px 15px}.bb-ov-head strong{font-size:15px}.bb-ov-head span{font-size:10px}.bb-ov-link{font-size:10px}
    .bb-ov-legrow{font-size:11px}.bb-ov-piecenter div{font-size:10px}.bb-ov-piecenter strong{font-size:17px}
    .bb-ov-perfrow label{font-size:11px}.bb-ov-perfrow b{font-size:12px}.bb-ov-snapline{font-size:11px}.bb-ov-snapline strong{font-size:15px}.bb-ov-diff small{font-size:10px}.bb-ov-diff strong{font-size:19px}
    .bb-ov-act .ic{font-size:25px}.bb-ov-act strong{font-size:24px}.bb-ov-act span{font-size:11px}.bb-ov-attrow{font-size:11px}
    .bb-ov-table th,.bb-ov-table td{font-size:10px}.bb-ov-table th{font-size:9px}.bb-ov-inforow{font-size:11px}.bb-ov-note{font-size:10px}
  }
  @media(max-width:1450px){.bb-ov-kpis{grid-template-columns:repeat(5,minmax(125px,1fr))}.bb-ov-grid3{grid-template-columns:1.2fr 1fr}.bb-ov-grid3>.bb-ov-card:last-child{grid-column:1/-1}.bb-staff-kpis{grid-template-columns:repeat(3,minmax(150px,1fr))}}
  @media(max-width:1000px){.bb-ov-kpis{grid-template-columns:repeat(3,minmax(130px,1fr))}.bb-ov-grid3,.bb-ov-grid2{grid-template-columns:1fr}.bb-ov-locbody{grid-template-columns:1fr}.bb-ov-activity{grid-template-columns:repeat(3,1fr)}.bb-staff-hero,.bb-staff-grid{grid-template-columns:1fr}.bb-staff-actions{grid-template-columns:repeat(2,minmax(0,1fr))}}
  @media(max-width:650px){.dashboard-home{padding:12px!important}.bb-ov-monthbar{align-items:flex-start;flex-direction:column}.bb-ov-monthctl{width:100%}.bb-ov-field{flex:1}.bb-ov-field input{width:100%}.bb-ov-kpis{grid-template-columns:1fr 1fr}.bb-ov-activity{grid-template-columns:1fr 1fr}.bb-ov-legrow{grid-template-columns:10px minmax(70px,1fr) 70px 42px}}
  `;document.head.appendChild(s);
}

function layout(){
  const home=$('dashboardHome');if(!home)return false;
  const top=home.querySelector('.topbar');if(!top)return false;
  const title=top.querySelector('.page-title');const sub=top.querySelector('.page-subtitle');
  const p=profile();

  if(title)title.textContent=isAdmin()?'Monthly Overview':'Overview';
  if(sub)sub.textContent=isAdmin()
    ?'Monthly control center for BIG BROTHER.'
    :'Your assigned-location sales and work center.';

  Array.from(home.children).forEach(el=>{if(el!==top)el.remove()});
  const wrap=document.createElement('div');wrap.className='bb-ov';wrap.id='bbOverview';

  if(isAdmin()){
    wrap.innerHTML=`
      <div class="bb-ov-monthbar"><div><strong>📊 Management Overview</strong><span>Live management data · auto-updates every 20 seconds while this Dashboard is open.</span></div><div class="bb-ov-monthctl"><div class="bb-ov-field"><label>Select Month</label><input id="bbOverviewMonth" type="month"></div><button id="bbOverviewRefresh" class="bb-ov-btn" type="button">Refresh</button></div></div>
      <div id="bbOverviewError" class="bb-ov-error" hidden></div>
      <div id="bbOverviewBody"><div class="bb-ov-loading">Loading monthly overview…</div></div>`;
  }else{
    const staff=p?.staff||{};
    const name=staff.staffName||p?.user?.email||'BIG BROTHER Staff';
    const position=staff.position||'Staff';
    const staffId=staff.staffId||p?.user?.staffId||'-';
    const locations=Array.isArray(p?.locations)?p.locations:[];
    const locHtml=locations.length
      ? locations.map(loc=>'<span class="bb-staff-loc">📍 '+esc(loc.locationName||loc.locationCode)+' · '+esc(loc.locationCode)+'</span>').join('')
      : '<span class="bb-staff-loc">No assigned location</span>';

    wrap.innerHTML=`
      <section class="bb-staff-hero">
        <div class="bb-staff-welcome">
          <small>BIG BROTHER · STAFF OVERVIEW</small>
          <h2>Welcome, ${esc(name)} 👋</h2>
          <p>Your desktop overview shows sales activity and live work information from the locations assigned to your account.</p>
          <div class="bb-staff-meta">
            <span>👤 ${esc(staffId)}</span>
            <span>💼 ${esc(position)}</span>
            <span>📍 ${locations.length} assigned location${locations.length===1?'':'s'}</span>
          </div>
        </div>
        <div class="bb-staff-scope">
          <div class="bb-staff-scope-head"><strong>Assigned Locations</strong><span>Your access scope</span></div>
          <div class="bb-staff-locations">${locHtml}</div>
          <div class="bb-staff-scope-note">Sales, receivable and stock information shown here is limited by your BIG BROTHER account access.</div>
        </div>
      </section>
      <div class="bb-ov-monthbar">
        <div><strong>📊 Your Monthly Overview</strong><span>Sales uses the selected month. Receivable and stock are current live snapshots.</span></div>
        <div class="bb-ov-monthctl"><div class="bb-ov-field"><label>Select Month</label><input id="bbOverviewMonth" type="month"></div><button id="bbOverviewRefresh" class="bb-ov-btn" type="button">Refresh</button></div>
      </div>
      <div id="bbOverviewError" class="bb-ov-error" hidden></div>
      <div id="bbOverviewBody"><div class="bb-ov-loading">Loading your overview…</div></div>`;
  }

  home.appendChild(wrap);
  const d=new Date();$('bbOverviewMonth').value=d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0');
  $('bbOverviewMonth').addEventListener('change',load);
  $('bbOverviewRefresh').addEventListener('click',load);
  return true;
}


function kpi(icon,label,value,accent,note,route){return `<div ${shortcutAttrs(route,'Open '+label)} class="bb-ov-kpi bb-ov-clickable" style="--a:${accent}"><div class="i">${icon}</div><small>${esc(label)}</small><strong>${esc(value)}</strong><em>${esc(note||'')}</em></div>`}
function pie(locations,total){
  const rows=[...(locations||[])].filter(x=>num(x.totalSaleUSD)>0).sort((a,b)=>num(b.totalSaleUSD)-num(a.totalSaleUSD));
  if(!rows.length)return '<div class="bb-ov-locbody"><div style="grid-column:1/-1;text-align:center;color:#7b8c9d;padding:45px 10px">No location sales for this month.</div></div>';
  let at=0;const seg=[];rows.forEach((x,i)=>{const p=total?num(x.totalSaleUSD)/total*100:0;seg.push(`${COLORS[i%COLORS.length]} ${at.toFixed(2)}% ${(at+p).toFixed(2)}%`);at+=p});
  const legend=rows.map((x,i)=>{const p=total?num(x.totalSaleUSD)/total*100:0;return `<div class="bb-ov-legrow"><span class="bb-ov-dot" style="background:${COLORS[i%COLORS.length]}"></span><span class="bb-ov-legname" title="${esc(x.locationName||x.locationCode)}">${esc(x.locationName||x.locationCode)}</span><span class="bb-ov-legamt">${money(x.totalSaleUSD)}</span><span class="bb-ov-legpct">${p.toFixed(1)}%</span></div>`}).join('');
  return `<div class="bb-ov-locbody"><div style="position:relative"><div class="bb-ov-pie" style="background:conic-gradient(${seg.join(',')})"></div><div class="bb-ov-piecenter"><div>Net Sales<strong>${money(total)}</strong></div></div></div><div class="bb-ov-legend">${legend}</div></div>`;
}
function perf(label,val,max,color){const pct=max>0?Math.max(0,Math.min(100,num(val)/max*100)):0;return `<div class="bb-ov-perfrow"><label>${esc(label)}</label><div class="bb-ov-track"><div class="bb-ov-fill" style="width:${pct.toFixed(2)}%;background:${color}"></div></div><b>${money(val)}</b></div>`}
function badge(status){const s=String(status||'').toLowerCase();const cls=s.includes('unpaid')||s.includes('overdue')?'bad':s.includes('partial')||s.includes('pending')?'warn':'';return `<span class="bb-ov-badge ${cls}">${esc(status||'-')}</span>`}
function recentRows(rows){return (rows||[]).map(x=>`<tr><td>${esc(x.tx_date)}</td><td>${esc(x.tx_type)}</td><td><b>${esc(x.ref_no)}</b></td><td>${esc(x.description||'-')}</td><td>${esc(x.party||'-')}</td><td class="amt">${esc(nativeAmount(x.amount,x.currency))}</td><td>${badge(x.status)}</td></tr>`).join('')||'<tr><td colspan="7" style="text-align:center;padding:20px;color:#7b8c9d">No transactions for this month.</td></tr>'}
function activity(icon,value,label,bg,route){return `<div ${shortcutAttrs(route,'Open '+label)} class="bb-ov-act bb-ov-clickable" style="--bg:${bg}"><div class="ic">${icon}</div><strong>${qty(value)}</strong><span>${esc(label)}</span></div>`}

function renderAdmin(d){
  const m=d.monthly||{},s=d.currentSnapshot||{},loc=d.salesByLocation||[];
  const total=num(m.netSalesUSD),monthlyExpense=num(m.monthlyExpenseUSD),maxPerf=Math.max(total,num(m.cogsUSD),monthlyExpense,num(m.netProfitUSD),1);
  const maxSnap=Math.max(num(s.receivableUSD),num(s.payableUSD),1),diff=num(s.receivableUSD)-num(s.payableUSD);
  const arPct=num(s.receivableUSD)/maxSnap*100,apPct=num(s.payableUSD)/maxSnap*100;
  $('bbOverviewBody').innerHTML=`
    <section class="bb-ov-kpis">
      ${kpi('🛒','Gross Sales',money(m.grossSalesUSD),'#2f6fed',d.periodLabel,'monthly-sales-report')}
      ${kpi('📊','Net Sales',money(m.netSalesUSD),'#18864b',d.periodLabel,'monthly-sales-report')}
      ${kpi('💳','Monthly Expense',money(m.monthlyExpenseUSD),'#d64f62','All expense types','income-statement-report')}
      ${kpi('📦','COGS',money(m.cogsUSD),'#e98716','Monthly cost of goods','income-statement-report')}
      ${kpi('🧾','Operating Expense',money(m.operatingExpenseUSD),'#7652c8','Operating only','income-statement-report')}
      ${kpi('💰','Net Profit',money(m.netProfitUSD),'#15965b',d.periodLabel,'income-statement-report')}
      ${kpi('👥','Accounts Receivable',money(s.receivableUSD),'#2f6fed','Current snapshot','ar-all')}
      ${kpi('🚚','Accounts Payable',money(s.payableUSD),'#e34b4b','Current snapshot','purchase-payable')}
      ${kpi('📦','Stock Value',money(s.stockValueUSD),'#7652c8','Current purchased stock','stock-report')}
    </section>
    <section class="bb-ov-grid3">
      <div class="bb-ov-card"><div class="bb-ov-head"><strong>📊 Sales by Location</strong><button class="bb-ov-link" onclick="window.BBCompanyFeatures?.open('monthly-sales-report')">View Details</button></div>${pie(loc,total)}</div>
      <div class="bb-ov-card"><div class="bb-ov-head"><strong>📈 Monthly Performance</strong><button class="bb-ov-link" onclick="window.BBCompanyFeatures?.open('income-statement-report')">View Report</button></div><div class="bb-ov-perf">${perf('Net Sales',m.netSalesUSD,maxPerf,'#2f6fed')}${perf('COGS',m.cogsUSD,maxPerf,'#ff9f1c')}${perf('Expense',m.monthlyExpenseUSD,maxPerf,'#ef5350')}${perf('Net Profit',m.netProfitUSD,maxPerf,'#22a06b')}</div></div>
      <div class="bb-ov-card"><div class="bb-ov-head"><strong>↔️ Receivable vs Payable</strong><span>Current snapshot</span></div><div class="bb-ov-snap"><div class="bb-ov-snapitem"><div class="bb-ov-snapline"><span>Accounts Receivable</span><strong>${money(s.receivableUSD)}</strong></div><div class="bb-ov-snaptrack"><div class="bb-ov-snapfill" style="width:${arPct}%;background:#2f6fed"></div></div></div><div class="bb-ov-snapitem"><div class="bb-ov-snapline"><span>Accounts Payable</span><strong>${money(s.payableUSD)}</strong></div><div class="bb-ov-snaptrack"><div class="bb-ov-snapfill" style="width:${apPct}%;background:#ef5350"></div></div></div><div class="bb-ov-diff"><div><small>A/R − A/P Difference</small><strong style="color:${diff>=0?'#18864b':'#b93730'}">${money(diff)}</strong></div><small>${diff>=0?'More receivables than payables':'More payables than receivables'}</small></div></div></div>
    </section>
    <section class="bb-ov-grid2">
      <div class="bb-ov-card"><div class="bb-ov-head"><strong>📋 Monthly Activity</strong><span>${esc(d.periodLabel)}</span></div><div class="bb-ov-activity">${activity('🧾',m.invoiceCount,'Invoices','#eaf3ff','monthly-sales-report')}${activity('🛒',m.purchaseCount,'Purchases','#eaf8f0','purchase-order-report')}${activity('👥',m.customerCount,'Customers with Sales','#f4edff','monthly-sales-report')}${activity('🏢',m.supplierCount,'Suppliers Used','#fff6df','purchase-order-report')}${activity('🏬',m.salesLocationCount,'Sales Locations','#eaf4ff','monthly-sales-report')}</div></div>
      <div class="bb-ov-card"><div class="bb-ov-head"><strong>⚠️ Attention Needed</strong><span>Current</span></div><div class="bb-ov-attn"><div class="bb-ov-attrow"><span class="bb-ov-attdot" style="background:#ef5350"></span><span>Overdue customer invoices</span><strong>${qty(s.overdueARCount)}</strong></div><div class="bb-ov-attrow"><span class="bb-ov-attdot" style="background:#ff9f1c"></span><span>Unpaid supplier invoices</span><strong>${qty(s.payableCount)}</strong></div><div class="bb-ov-attrow"><span class="bb-ov-attdot" style="background:#f4c20d"></span><span>Low-stock alerts</span><strong>${qty(s.lowStockAlerts)}</strong></div><div class="bb-ov-attrow"><span class="bb-ov-attdot" style="background:#2f6fed"></span><span>Pending staff requests</span><strong>${qty(s.pendingStaffRequests)}</strong></div></div></div>
    </section>
    <section class="bb-ov-grid2">
      <div class="bb-ov-card"><div class="bb-ov-head"><strong>🕘 Recent Transactions (${esc(d.periodLabel)})</strong><span>Latest 6</span></div><div class="bb-ov-tablewrap"><table class="bb-ov-table"><thead><tr><th>Date</th><th>Type</th><th>Ref No.</th><th>Description</th><th>Party</th><th style="text-align:right">Amount</th><th>Status</th></tr></thead><tbody>${recentRows(d.recentTransactions)}</tbody></table></div></div>
      <div class="bb-ov-card"><div class="bb-ov-head"><strong>ℹ️ System Info</strong><span>Overview</span></div><div class="bb-ov-info"><div class="bb-ov-inforow"><span>Selected Month</span><strong>${esc(d.periodLabel)}</strong></div><div class="bb-ov-inforow"><span>Active Locations</span><strong>${qty(s.activeLocationCount)}</strong></div><div class="bb-ov-inforow"><span>Current Stock Qty</span><strong>${qty(s.stockQty)}</strong></div><div class="bb-ov-inforow"><span>Last Updated</span><strong>${esc(d.generatedAt||'-')}</strong></div><div class="bb-ov-note">Monthly cards use the selected month. A/R, A/P, stock and attention items are current live snapshots.</div></div></div>
    </section>`;
}

function staffKpi(icon,label,value,note,accent,route,module){
  const allowed=!module||canModule(module);
  const clickable=Boolean(route&&allowed);
  const attrs=clickable
    ? `class="bb-staff-kpi clickable" role="button" tabindex="0" style="--a:${accent}" onclick="window.BBMonthlyOverview.openShortcut('${esc(route)}')" onkeydown="if(event.key==='Enter'||event.key===' '){event.preventDefault();window.BBMonthlyOverview.openShortcut('${esc(route)}')}"`
    : `class="bb-staff-kpi" style="--a:${accent}"`;
  return `<div ${attrs}><div class="ic">${icon}</div><small>${esc(label)}</small><strong>${esc(value)}</strong><em>${esc(note||'')}</em></div>`;
}
function staffAction(icon,title,note,route,module){
  if(module&&!canModule(module))return '';
  return `<button type="button" class="bb-staff-action" onclick="window.BBMonthlyOverview.openShortcut('${esc(route)}')"><span class="ic">${icon}</span><strong>${esc(title)}</strong><span>${esc(note)}</span></button>`;
}
function renderStaff(d){
  const p=profile()||{};
  const staff=p.staff||{};
  const sales=d.monthlySales||{};
  const ar=d.receivable||{};
  const stock=d.stock||{};
  const locations=Array.isArray(d.saleLocations)?d.saleLocations:(Array.isArray(p.locations)?p.locations:[]);
  const net=num(sales.netUSD);
  const gross=num(sales.grossUSD);
  const returns=num(sales.returnsUSD);
  const avg=num(sales.invoiceCount)>0?net/num(sales.invoiceCount):0;
  const maxSales=Math.max(gross,returns,net,1);
  const bar=(label,value,color)=>`
    <div class="bb-staff-sales-row">
      <span>${esc(label)}</span>
      <div class="bb-staff-sales-track"><div class="bb-staff-sales-fill" style="width:${Math.max(0,Math.min(100,num(value)/maxSales*100)).toFixed(2)}%;background:${color}"></div></div>
      <b>${money(value)}</b>
    </div>`;

  const actions=[
    staffAction('🧮','Calculator','Price check and customer calculation','sales-support-calculator','route.sales-support-calculator'),
    staffAction('🧾','Your Invoices','Invoices under your current responsibility','sales-support-your-invoices','route.sales-support-your-invoices'),
    staffAction('💵','Your Collection','Cash collection for your responsibility','sales-support-your-collection','route.sales-support-your-collection'),
    staffAction('💰','Your Receivable','Receivables under your responsibility','sales-support-your-receivable','route.sales-support-your-receivable'),
    staffAction('📦','Your Stock','Stock for your permitted locations','sales-support-your-stock','route.sales-support-your-stock'),
    staffAction('👥','Your Customer','Customers in your Sales Support access','sales-support-your-customer','route.sales-support-your-customer')
  ].filter(Boolean).join('');

  $('bbOverviewBody').innerHTML=`
    <section class="bb-staff-kpis">
      ${staffKpi('📊','Monthly Sales',money(net),d.periodLabel,'#2f6fed')}
      ${staffKpi('🧾','Invoices',qty(sales.invoiceCount),money(avg)+' average','#22a06b','sales-support-your-invoices','route.sales-support-your-invoices')}
      ${staffKpi('💰','Receivable',money(ar.equivalentUSD),qty(ar.count)+' open','#ff9f1c','sales-support-your-receivable','route.sales-support-your-receivable')}
      ${staffKpi('📦','Stock Qty',qty(stock.physicalQty),qty(stock.openBatchCount)+' open batches','#7c4dce','sales-support-your-stock','route.sales-support-your-stock')}
      ${staffKpi('📍','Assigned Locations',qty(locations.length),'Account access scope','#27a9c7')}
    </section>
    <section class="bb-staff-grid">
      <div class="bb-ov-card">
        <div class="bb-ov-head"><strong>⚡ Quick Work</strong><span>Only functions available to your account</span></div>
        <div class="bb-staff-actions">${actions||'<div style="padding:18px;color:#718398;font-size:10px">No quick actions are available for this account.</div>'}</div>
      </div>
      <div class="bb-ov-card">
        <div class="bb-ov-head"><strong>📈 Sales Summary</strong><span>${esc(d.periodLabel||'')}</span></div>
        <div class="bb-staff-sales">
          ${bar('Gross Sales',gross,'#2f6fed')}
          ${bar('Sales Returns',returns,'#ef5350')}
          ${bar('Net Sales',net,'#22a06b')}
          <div class="bb-staff-sales-row"><span>Average / Invoice</span><div></div><b>${money(avg)}</b></div>
        </div>
      </div>
    </section>
    <section class="bb-staff-grid">
      <div class="bb-ov-card">
        <div class="bb-ov-head"><strong>📍 Location Access</strong><span>${locations.length} assigned</span></div>
        <div class="bb-staff-locations" style="padding:14px">
          ${locations.length?locations.map(loc=>'<span class="bb-staff-loc">📍 '+esc(loc.locationName||loc.locationCode)+' · '+esc(loc.locationCode)+'</span>').join(''):'<span class="bb-staff-loc">No assigned location</span>'}
        </div>
      </div>
      <div class="bb-ov-card">
        <div class="bb-ov-head"><strong>ℹ️ Your Account</strong><span>Live scope</span></div>
        <div class="bb-staff-account">
          <div class="bb-staff-account-row"><span>Staff</span><strong>${esc(staff.staffName||p.user?.email||'-')}</strong></div>
          <div class="bb-staff-account-row"><span>Staff ID</span><strong>${esc(staff.staffId||p.user?.staffId||'-')}</strong></div>
          <div class="bb-staff-account-row"><span>Position</span><strong>${esc(staff.position||'-')}</strong></div>
          <div class="bb-staff-account-row"><span>Selected Month</span><strong>${esc(d.periodLabel||'-')}</strong></div>
          <div class="bb-staff-account-row"><span>Last Updated</span><strong>${esc(d.generatedAt||'-')}</strong></div>
        </div>
      </div>
    </section>`;
}

function homeVisible(){
  const home=$('dashboardHome');
  return Boolean(
    home &&
    !home.hidden &&
    document.visibilityState!=='hidden'
  );
}

async function load(options={}){
  const silent=options?.silent===true;
  const e=$('bbOverviewError'),b=$('bbOverviewBody'),btn=$('bbOverviewRefresh');
  if(!e||!b||loading)return;
  if(silent&&!homeVisible())return;

  loading=true;

  if(!silent){
    e.hidden=true;
    e.textContent='';
    btn.disabled=true;
    btn.textContent='Loading…';
    b.innerHTML='<div class="bb-ov-loading">Loading monthly overview…</div>';
  }

  try{
    const [y,m]=String($('bbOverviewMonth').value||'').split('-').map(Number);
    if(!y||!m)throw new Error('Please choose a month.');

    const d=isAdmin()
      ? await rpc('bb_dashboard_monthly_overview',{
          p_year:y,
          p_month:m
        })
      : await rpc('bb_mobile_overview_filtered',{
          p_year:y,
          p_month:m,
          p_location_code:null
        });

    if(isAdmin())renderAdmin(d);
    else renderStaff(d);
    lastRefreshAt=Date.now();
    e.hidden=true;
    e.textContent='';
  }catch(err){
    e.textContent=err?.message||String(err);
    e.hidden=false;

    /* Keep the last good overview visible during silent live refresh errors. */
    if(!silent)b.innerHTML='';
  }finally{
    loading=false;
    if(btn){
      btn.disabled=false;
      btn.textContent='Refresh';
    }
  }
}

function refreshLive(){
  if(!homeVisible())return;
  load({silent:true}).catch(()=>{});
}

function installLiveRefresh(){
  if(liveTimer)return;

  const home=$('dashboardHome');

  if(home&&!homeObserver){
    homeObserver=new MutationObserver(()=>{
      if(!home.hidden){
        /* Refresh immediately whenever the user returns from a module. */
        setTimeout(refreshLive,60);
      }
    });

    homeObserver.observe(home,{
      attributes:true,
      attributeFilter:['hidden']
    });
  }

  window.addEventListener('focus',refreshLive);

  document.addEventListener('visibilitychange',()=>{
    if(document.visibilityState==='visible')refreshLive();
  });

  liveTimer=setInterval(()=>{
    if(
      homeVisible() &&
      Date.now()-lastRefreshAt>=LIVE_REFRESH_MS-1000
    ){
      refreshLive();
    }
  },LIVE_REFRESH_MS);
}

function ready(){
  if(installed)return;
  const p=window.BBDashboardAdapter?.getProfile?.();
  if(!p){setTimeout(ready,120);return}
  installed=true;
  styles();
  if(layout()){
    load();
    installLiveRefresh();
  }
}

window.BBMonthlyOverview={
  openShortcut,
  load,
  refreshLive
};
if(document.readyState==='loading')window.addEventListener('DOMContentLoaded',()=>setTimeout(ready,80));else setTimeout(ready,80);
})();