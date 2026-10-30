/* BIG BROTHER — Standalone Mobile Dashboard V1 */
(function(){
'use strict';

const SUPABASE_URL='https://sjfhlaclgmkwwofzstok.supabase.co';
const SUPABASE_KEY='sb_publishable_w762jR65CWwlO30fKQsYOw_6L9grx8S';
const SESSION_KEY='BB_SUPABASE_DEV_SESSION_V1';
const LOGIN_EMAIL_KEY='BB_MOBILE_LOGIN_EMAIL_V1';
/* Real A/R pilot opt-in, available inside the installed Android WebView.
 * This only changes the display path. No financial write or DB changes.
 */
const BB_REAL_AR_PILOT_KEY='bb_mobile_real_ar_pilot_v1';
const bbRealArParam=new URLSearchParams(location.search).get('bb_real_ar');
try{
  if(bbRealArParam==='1')localStorage.setItem(BB_REAL_AR_PILOT_KEY,'1');
  if(bbRealArParam==='0')localStorage.removeItem(BB_REAL_AR_PILOT_KEY);
}catch(_){}
function bbRealArPilotEnabled(){
  try{return bbRealArParam==='1'||(bbRealArParam!=='0'&&localStorage.getItem(BB_REAL_AR_PILOT_KEY)==='1')}
  catch(_){return bbRealArParam==='1'}
}
window.BBRealARFastModeV1=Object.freeze({enabled:bbRealArPilotEnabled});
const bbArPilotToggle=document.getElementById('bbRealArPilotToggle');
if(bbArPilotToggle){
  const active=bbRealArPilotEnabled();
  const target=new URL(location.href);
  target.searchParams.delete('module');
  target.searchParams.delete('autoload');
  target.searchParams.delete('bb_cache_pilot');
  target.searchParams.set('bb_real_ar',active?'0':'1');
  bbArPilotToggle.href=target.pathname+target.search;
  const strong=bbArPilotToggle.querySelector('strong');
  const small=bbArPilotToggle.querySelector('small');
  if(strong)strong.textContent=active?'Return to Standard Receivable':'Try Real Receivable Fast Mode';
  if(small)small.textContent=active?
    'Disable pilot and restore existing offline-first routing':
    'Original A/R UI, cached data, automatic live refresh';
}


const REQUIRED_ACTION={
  'customers-add':'create','clients-add':'create','products-add':'create',
  'sales-support-request-delivery':'create','invoice':'create','purchase-create':'create','expense-add':'create'
};

const ROUTES={
  'sales-support-calculator':{tab:'sales',icon:'🧮',label:'Calculator',url:'https://angsokhey11-cloud.github.io/big-brother-sales-support/?embed=1&mobile=1&view=calculator&v=20260923-locationname1'},
  'sales-support-request-delivery':{tab:'sales',icon:'🚚',label:'Request Delivery',url:'https://angsokhey11-cloud.github.io/big-brother-sales-support/?embed=1&view=request-delivery&v=110'},
  'sales-support-your-customer':{tab:'sales',icon:'👥',label:'My Customers',url:'https://angsokhey11-cloud.github.io/big-brother-sales-support/?embed=1&view=your-customer&v=110'},
  'sales-support-successful-delivery':{tab:'sales',icon:'✅',label:'Successful Delivery',url:'https://angsokhey11-cloud.github.io/big-brother-sales-support/?embed=1&view=successful-delivery&v=110'},
  'invoice':{tab:'sales',icon:'🧾',label:'Create Invoice',url:'https://angsokhey11-cloud.github.io/big-brother-invoice-generator/mobile.html?embed=1&v=20261001-scanfix2'},
  'history':{tab:'sales',icon:'📚',label:'Invoice History',url:'https://angsokhey11-cloud.github.io/invoice-history/invoice-history-mobile.html?embed=1&v=20261001-creditdigitalfix4'},
  'sale-return':{tab:'sales',icon:'↩️',label:'Invoice Reversal',url:'https://angsokhey11-cloud.github.io/big-brother-invoice-reversal/mobile.html?embed=1&v=20260924-invoiceid1'},
  'reversal-history':{tab:'sales',icon:'📜',label:'Reversal History',url:'https://angsokhey11-cloud.github.io/big-brother-invoice-reversal/history.html?embed=1&v=20260914-1'},
  'payment-history':{tab:'sales',icon:'💳',label:'Payment History',url:'https://angsokhey11-cloud.github.io/big-brother-payment-history/?embed=1&type=invoice&v=1'},
  'daily-sale-summary':{tab:'sales',icon:'📊',label:'Daily Sale Summary',url:'https://angsokhey11-cloud.github.io/big-brother-daily-sale-summary/?embed=1&v=1'},
  'daily-cash-collection':{tab:'sales',icon:'💵',label:'Cash Collection',url:'https://angsokhey11-cloud.github.io/big-brother-daily-cash-collection/?embed=1&v=1'},
  'ar-your':{tab:'sales',icon:'💰',label:'My Receivables',url:'https://angsokhey11-cloud.github.io/big-brother-ar/your-receivable-mobile.html?embed=1&v=20261030-fourcol1'},

  'stock-control-allocation':{tab:'stock',icon:'📦',label:'Stock Allocation',url:'https://angsokhey11-cloud.github.io/big-brother-stock-allocation/mobile.html?embed=1&v=20261003-tightlines1'},
  'stock-control-batch-transfer':{tab:'stock',icon:'🔀',label:'Batch Transfer',url:'https://angsokhey11-cloud.github.io/big-brother-stock-allocation/batch-transfer-mobile.html?embed=1&v=20261008-mobile1'},
  'stock-control-back-sale':{tab:'stock',icon:'↩️',label:'Back Sale',url:'https://angsokhey11-cloud.github.io/big-brother-stock-allocation/back-sale-mobile.html?embed=1&v=20261003-returncollapse1'},
  'stock-keyin':{tab:'stock',icon:'📦',label:'Stock In / Out',url:'https://angsokhey11-cloud.github.io/big-brother-stock-managemenet/mobile.html?embed=1&v=20261003-damagevisibility1'},
  'stock-damaged':{tab:'stock',icon:'⚠️',label:'Damaged Stock',url:'https://angsokhey11-cloud.github.io/big-brother-stock-managemenet/?embed=1&view=damaged&v=20'},
  'stock-report':{tab:'stock',icon:'📋',label:'Live Stock',url:'https://angsokhey11-cloud.github.io/big-brother-stock-report/mobile.html?embed=1&v=20260923-defaultorder1'},
  'batch-report':{tab:'stock',icon:'🗂️',label:'Batch Report',url:'https://angsokhey11-cloud.github.io/big-brother-stock-report/batch-report.html?embed=1&v=20260923-batchedit2'},
  'closed-batch':{tab:'stock',icon:'✅',label:'Closed Batch',url:'https://angsokhey11-cloud.github.io/big-brother-stock-report/closed-batch.html?embed=1&v=10'},
  'stock-transactions':{tab:'stock',icon:'🔄',label:'Stock Transactions',url:'https://angsokhey11-cloud.github.io/big-brother-stock-report/transactions.html?embed=1&v=10'},
  'stock-pending-borrow':{tab:'stock',icon:'📋',label:'Pending Borrowed Stock',url:'https://angsokhey11-cloud.github.io/big-brother-stock-managemenet/pending-borrowed-stock.html?embed=1&mobile=1&v=20261001-compactreceipt3'},
  'stock-alerts':{tab:'stock',icon:'🚨',label:'Smart Stock Alerts',url:'https://angsokhey11-cloud.github.io/big-brother-admin-work/company-control.html?embed=1&view=stock-alerts&v=1'},

  'monthly-sales-report':{tab:'reports',icon:'📈',label:'Monthly Sales',url:'https://angsokhey11-cloud.github.io/big-brother-report/monthly-sales.html?embed=1&v=20260913-4'},
  'income-statement-report':{tab:'reports',icon:'📊',label:'Income Statement',url:'https://angsokhey11-cloud.github.io/big-brother-report/income-statement.html?embed=1&v=20260920-vaultfx1'},
  'purchase-order-report':{tab:'reports',icon:'🧾',label:'Purchase Order Report',url:'https://angsokhey11-cloud.github.io/big-brother-report/purchase-order-report.html?embed=1&v=20260913-4'},
  'cogs-daily':{tab:'reports',icon:'🏷️',label:'Daily COGS',url:'https://angsokhey11-cloud.github.io/big-brother-cogs/daily.html?embed=1&v=20260912-2'},
  'cogs-monthly':{tab:'reports',icon:'📦',label:'Monthly COGS',url:'https://angsokhey11-cloud.github.io/big-brother-cogs/monthly.html?embed=1&v=20260912-2'},
  'expense-monthly-report':{tab:'reports',icon:'💸',label:'Monthly Expense',url:'https://angsokhey11-cloud.github.io/big-brother-expenses/monthly-report.html?embed=1&v=1'},

  'purchase-create':{tab:'more',icon:'🛒',label:'Create Purchase',url:'https://angsokhey11-cloud.github.io/big-brother-purchase-recorder/?embed=1&v=20260920-iosdecimal1'},
  'purchase-history':{tab:'more',icon:'📚',label:'Purchase History',url:'https://angsokhey11-cloud.github.io/big-brother-puchase-history/?embed=1&v=1'},
  'purchase-payable':{tab:'more',icon:'💵',label:'Purchase Payable',url:'https://angsokhey11-cloud.github.io/big-brother-purchase-payable-invoice/?embed=1&v=1'},
  'purchase-payment-history':{tab:'more',icon:'💳',label:'Purchase Payments',url:'https://angsokhey11-cloud.github.io/big-brother-purchase-payment-history/?embed=1&v=1'},
  'expense-add':{tab:'more',icon:'➕',label:'Add Expense',url:'https://angsokhey11-cloud.github.io/big-brother-expenses/?embed=1&view=add-expense&v=20260920-iosdecimal1'},
  'expense-accrued':{tab:'more',icon:'⏳',label:'Accrued Expense',url:'https://angsokhey11-cloud.github.io/big-brother-expenses/?embed=1&view=accrued-expenses&v=17'},
  'daily-cash':{tab:'more',icon:'💵',label:'Daily Cash',url:'https://angsokhey11-cloud.github.io/big-brother-expenses/daily-cash.html?embed=1&v=20260920-vaultfx1'},
  'expense-history':{tab:'more',icon:'🧾',label:'Expense History',url:'https://angsokhey11-cloud.github.io/big-brother-expenses/?embed=1&view=expense-history&v=17'},
  'real-invoice':{tab:'more',icon:'📷',label:'Real Invoice Scanner',url:'https://angsokhey11-cloud.github.io/big-brother-real-invoice/?embed=1&v=20261018-date1'},
  'ar-all':{tab:'more',icon:'📋',label:'All Receivables',url:'https://angsokhey11-cloud.github.io/big-brother-ar/all-receivable-mobile.html?embed=1&v=20261030-fourcol1'},
  'ar-payment-history':{tab:'more',icon:'🧾',label:'Receivable Payments',url:'https://angsokhey11-cloud.github.io/big-brother-payment-history/?embed=1&type=receivable&v=1'},
  'ar-daily-receivable-cash':{tab:'more',icon:'💵',label:'Daily Receivable Cash',url:'https://angsokhey11-cloud.github.io/big-brother-daily-receivable-cash-summary/?embed=1'},
  'customers-add':{tab:'more',icon:'👤',label:'Add Customer',url:'https://angsokhey11-cloud.github.io/big-brother-customers-editor/?embed=1&view=add&v=20260920-1'},
  'customers-map':{tab:'more',icon:'🗺️',label:'Customer Map',url:'https://angsokhey11-cloud.github.io/big-brother-customers-editor/?embed=1&view=map&v=20260920-1'},
  'customers-details':{tab:'more',icon:'👥',label:'Customer Details',url:'https://angsokhey11-cloud.github.io/big-brother-customers-editor/?embed=1&view=details&v=20260920-1'},
  'clients-add':{tab:'more',icon:'🏢',label:'Add Client',url:'https://angsokhey11-cloud.github.io/big-brother-clients-editor/?embed=1&view=add&v=10'},
  'clients-details':{tab:'more',icon:'🏭',label:'Client Details',url:'https://angsokhey11-cloud.github.io/big-brother-clients-editor/?embed=1&view=details&v=10'},
  'products-add':{tab:'more',icon:'🥛',label:'Add Product',url:'https://angsokhey11-cloud.github.io/big-brother-products-editor/?embed=1&view=add&v=10'},
  'products-details':{tab:'more',icon:'📦',label:'Product Details',url:'https://angsokhey11-cloud.github.io/big-brother-products-editor/?embed=1&view=details&v=10'},
  'master-expense-categories':{tab:'more',icon:'💸',label:'Expense Categories',url:'https://angsokhey11-cloud.github.io/big-brother-master-data/expense-categories.html?embed=1&v=21'},
  'master-audit-center':{tab:'more',icon:'🛡️',label:'Audit & Correction Center',url:'https://angsokhey11-cloud.github.io/big-brother-master-data/audit-center.html?embed=1&v=20260927-2'},
  'staff-relation':{tab:'more',icon:'🤝',label:'Staff Relation',url:'https://angsokhey11-cloud.github.io/big-brother-staff-relation/mobile.html?embed=1&v=20261025-admin-onbehalf2'},
  // Existing admin functions were missing from the mobile routing table.
  // Only openable by an admin or an explicitly authorized route grant.
  // Hidden from the regular mobile menu; notification links can use them.
  'admin-pending-receivable':{tab:'more',notificationOnly:true,icon:'',label:'Review Receivable Request',url:'https://angsokhey11-cloud.github.io/big-brother-admin-work/?embed=1&view=pending-receivable'},
  'admin-pending-daily-cash':{tab:'more',notificationOnly:true,icon:'',label:'Review Cash Request',url:'https://angsokhey11-cloud.github.io/big-brother-admin-work/?embed=1&view=pending-daily-cash'},
  'admin-staff-request':{tab:'more',icon:'👥',label:'Staff Request',url:'https://angsokhey11-cloud.github.io/big-brother-admin-work/staff-request-mobile.html?embed=1&v=20261029-option-b-compact4'},
  'notification-center':{tab:'more',icon:'🔔',label:'Notifications',url:'https://angsokhey11-cloud.github.io/big-brother-admin-work/company-control.html?embed=1&view=notifications&v=20261029-bb-inbox1'}
};

// Authorized original live page URL for the mobile cache-first handoff.
// An offscreen frame can only be prepared for a route that this user may view.
window.BBMobileLiveRoutesV1=Object.freeze({
  url(route){
    const item=ROUTES[String(route||'')];
    return item&&canRoute(route)?item.url:'';
  },
  label(route){return ROUTES[String(route||'')]?.label||'BIG BROTHER'}
});

const QUICK=['sales-support-calculator','invoice','sales-support-your-customer','ar-your','sales-support-request-delivery','daily-cash-collection','stock-report','staff-relation'];
const NAV=[['home','⌂','Home'],['sales','▥','Sales'],['stock','◫','Stock'],['reports','▥','Reports'],['more','•••','More']];

let session=null;
let profile=null;
let overview=null;
let activeTab='home';
let adminOverviewLoading=false;
let adminOverviewLastLoad=0;
let adminOverviewTimer=null;
const LIVE_OVERVIEW_MS=120000;

const $=id=>document.getElementById(id);
const key=v=>String(v||'').trim().toLowerCase();
const num=v=>Number(v||0)||0;
const money=v=>'$'+num(v).toLocaleString('en-US',{minimumFractionDigits:2,maximumFractionDigits:2});
const esc=v=>String(v??'').replace(/[&<>\"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','\"':'&quot',"'":'&#039;'}[c]));

function readSession(){try{return JSON.parse(localStorage.getItem(SESSION_KEY)||'null')}catch(_){return null}}
function saveSession(value){
  session=value||null;
  try{
    if(!value){localStorage.removeItem(SESSION_KEY);return}
    if(!value.expires_at&&value.expires_in)value.expires_at=Math.floor(Date.now()/1000)+Number(value.expires_in);
    localStorage.setItem(SESSION_KEY,JSON.stringify(value));
  }catch(_){}
}
async function parse(response){
  const text=await response.text();let data={};
  try{data=text?JSON.parse(text):{}}catch(_){data={message:text}}
  if(!response.ok){
    const error=new Error(data.message||data.error_description||data.error||('Request failed ('+response.status+')'));
    error.status=response.status;
    error.code=data.code||data.error_code||data.error||'';
    throw error;
  }
  return data;
}
function isSessionAuthError(error){
  const message=String(error?.message||'').toLowerCase();
  const status=Number(error?.status||0);
  if(message==='please sign in to big brother.')return true;
  if(status===401)return true;
  if(status===400&&(
    message.includes('refresh token')||
    message.includes('invalid token')||
    message.includes('token has expired')||
    message.includes('jwt expired')||
    message.includes('session not found')
  ))return true;
  return false;
}
function readRememberedEmail(){
  try{return String(localStorage.getItem(LOGIN_EMAIL_KEY)||'').trim()}catch(_){return ''}
}
function rememberEmail(value){
  const email=String(value||'').trim();
  if(!email)return;
  try{localStorage.setItem(LOGIN_EMAIL_KEY,email)}catch(_){}
}
async function refreshSession(){
  const current=readSession();
  if(!current?.refresh_token)throw new Error('Please sign in to BIG BROTHER.');
  const r=await fetch(SUPABASE_URL+'/auth/v1/token?grant_type=refresh_token',{method:'POST',headers:{apikey:SUPABASE_KEY,'Content-Type':'application/json'},body:JSON.stringify({refresh_token:current.refresh_token}),cache:'no-store'});
  const next=await parse(r);saveSession(next);return next;
}
async function ensureSession(){
  session=readSession();
  if(!session?.access_token)throw new Error('Please sign in to BIG BROTHER.');
  const now=Math.floor(Date.now()/1000);
  if(session.expires_at&&Number(session.expires_at)<now+45)await refreshSession();
  return session;
}
async function rpc(fn,args={}){
  await ensureSession();
  let r=await fetch(SUPABASE_URL+'/rest/v1/rpc/'+fn,{method:'POST',headers:{apikey:SUPABASE_KEY,Authorization:'Bearer '+session.access_token,'Content-Type':'application/json'},body:JSON.stringify(args||{}),cache:'no-store'});
  if(r.status===401){await refreshSession();r=await fetch(SUPABASE_URL+'/rest/v1/rpc/'+fn,{method:'POST',headers:{apikey:SUPABASE_KEY,Authorization:'Bearer '+session.access_token,'Content-Type':'application/json'},body:JSON.stringify(args||{}),cache:'no-store'})}
  return parse(r);
}
async function signIn(email,password){
  const r=await fetch(SUPABASE_URL+'/auth/v1/token?grant_type=password',{method:'POST',headers:{apikey:SUPABASE_KEY,'Content-Type':'application/json'},body:JSON.stringify({email:String(email||'').trim(),password:String(password||'')}),cache:'no-store'});
  const next=await parse(r);saveSession(next);return next;
}
async function signOut(){
  window.BBMobileOfflineModulesV1?.close();
  if(window.BBMobileOfflineWorkspaceV1?.canUseNetwork()!==false){try{await window.BBPush?.disable({silent:true})}catch(_){}}
  const current=readSession();
  try{if(current?.access_token&&window.BBMobileOfflineWorkspaceV1?.canUseNetwork()!==false)await fetch(SUPABASE_URL+'/auth/v1/logout',{method:'POST',headers:{apikey:SUPABASE_KEY,Authorization:'Bearer '+current.access_token},cache:'no-store'})}catch(_){}
  try{await window.BBMobileOfflineWorkspaceV1?.clearUser(current?.user?.id)}catch(_){}
  saveSession(null);profile=null;overview=null;
  void window.BBMobileOfflineWorkspaceV1?.init();
  showLogin('');
}

function isAdmin(){return profile?.user?.isAdmin===true}
function grantFor(moduleKey){
  if(isAdmin())return {canView:true,canCreate:true,canEdit:true,canApprove:true};
  const mods=Array.isArray(profile?.modules)?profile.modules:[];
  return mods.find(x=>key(x.moduleKey)==='*')||mods.find(x=>key(x.moduleKey)===key(moduleKey))||null;
}
function canRoute(route){
  if(!ROUTES[route])return false;
  if(isAdmin())return true;
  const g=grantFor('route.'+route);
  if(!g)return false;
  const action=REQUIRED_ACTION[route]||'view';
  if(action==='create')return g.canCreate===true;
  if(action==='edit')return g.canEdit===true;
  if(action==='approve')return g.canApprove===true;
  return g.canView===true;
}
function permittedRoutes(tab){return Object.entries(ROUTES).filter(([route,item])=>item.tab===tab&&!item.notificationOnly&&canRoute(route))}
function availableCount(){return Object.keys(ROUTES).filter(canRoute).length}

function displayName(){return profile?.staff?.staffName||profile?.user?.staffName||profile?.user?.email?.split('@')[0]||'BIG BROTHER User'}
function locationText(){
  const a=Array.isArray(profile?.locations)?profile.locations:[];
  if(!a.length)return isAdmin()?'All Locations':'No Location';
  if(a.length===1)return a[0].locationName||a[0].locationCode||'1 Location';
  return isAdmin()?'All Locations':a.length+' Locations';
}
function greeting(){const h=new Date().getHours();return h<12?'Good Morning,':h<18?'Good Afternoon,':'Good Evening,'}
function dateText(){return new Date().toLocaleDateString(undefined,{weekday:'short',day:'2-digit',month:'short',year:'numeric'})}
function currentPeriod(){return new Date().toLocaleDateString(undefined,{month:'long',year:'numeric'})}
function statusIcon(type){const t=String(type||'').toLowerCase();if(t.includes('invoice'))return '🧾';if(t.includes('purchase'))return '🛒';if(t.includes('expense'))return '💸';return '•'}

function hideAll(){window.BBMobileUniversalReadOnlyV1?.stop();['bootScreen','loginScreen','mobileHome','menuScreen','moduleScreen'].forEach(id=>$(id).hidden=true)}
function showLogin(message=''){
  hideAll();$('loginScreen').hidden=false;$('loginError').textContent=message||'';
  const email=$('loginEmail');
  const password=$('loginPassword');

  if(email&&!email.value){
    const remembered=readRememberedEmail();
    if(remembered)email.value=remembered;
  }

  /*
   * iPhone first-run rule:
   * do not programmatically focus the login fields while Safari/PWA and the
   * service worker are still settling. The fields stay immediately tappable
   * and the keyboard opens only from the user's own tap.
   */
  [email,password].forEach(input=>{
    if(!input)return;
    input.disabled=false;
    input.readOnly=false;
    input.style.pointerEvents='auto';
  });
}
function toast(message){
  const t=$('toast');t.textContent=message;t.hidden=false;clearTimeout(toast._timer);toast._timer=setTimeout(()=>t.hidden=true,2600);
}
function replaceFrameUrl(frame,url){
 try{
   if(!frame?.parentNode)return;
   // Reopening the already-active function must not reload forms or data.
   if(frame.getAttribute('src')===url)return frame;
   window.BBMobileTransitionV3?.start?.(url);
   const fresh=frame.cloneNode(false);
   fresh.removeAttribute('src');
   fresh.removeAttribute('srcdoc');
   fresh.removeAttribute('sandbox');
   fresh.removeAttribute('aria-hidden');
   fresh.inert=false;
   fresh.removeAttribute('data-bb-theme-bound');
   frame.replaceWith(fresh);
   fresh.addEventListener('load',()=>{
     try{window.BBMobileThemeV1?.applyFrameTheme?.()}catch(_){}
   });
   fresh.src=url;
   return fresh;
 }catch(_){}
 try{frame.src=url}catch(_){}
 return frame;
}

function setUrlRoute(route=''){
  try{const u=new URL(location.href);if(route){u.searchParams.set('module',route)}else{u.searchParams.delete('module')}history.replaceState({},'',u.pathname+u.search+u.hash)}catch(_){}
}

function navHtml(active){return NAV.map(x=>`<button class="nav-btn ${active===x[0]?'active':''}" type="button" data-nav="${x[0]}"><b>${window.BBMobileFunctionIconsV1?.named?.(({home:'home',sales:'receipt',stock:'warehouse',reports:'chart-column',more:'menu'})[x[0]])||x[1]}</b>${x[2]}</button>`).join('')}
function bindNav(host){host.querySelectorAll('[data-nav]').forEach(btn=>btn.onclick=()=>navigate(btn.dataset.nav))}
function refreshNav(active){['bottomNav','menuBottomNav','moduleBottomNav'].forEach(id=>{const el=$(id);el.innerHTML=navHtml(active);bindNav(el)})}

function quickHtml(){
  const items=QUICK.filter(canRoute);
  $('quickCount').textContent=items.length+' available';
  return items.map(route=>{const x=ROUTES[route];return `<button type="button" class="quick-btn" data-route="${route}"><div class="quick-icon">${window.BBMobileFunctionIconsV1?.route?.(route)||x.icon}</div><span>${esc(x.label)}</span></button>`}).join('')||'<div class="menu-empty">No quick actions assigned.</div>';
}
function renderKpis(){
  if(window.BBMobileOverviewV1?.render){
    try{window.BBMobileOverviewV1.render();return}catch(_){}
  }
  const grid=$('kpiGrid');
  if(isAdmin()&&overview){
    const m=overview.monthly||{},s=overview.currentSnapshot||{};
    const data=[
      ['chart-line','Monthly Sales',money(m.grossSalesUSD),overview.periodLabel||currentPeriod()],
      ['wallet','Receivable',money(s.receivableUSD),'Current outstanding'],
      ['warehouse','Stock Value',money(s.stockValueUSD),'Current inventory'],
      ['clipboard-list','Pending Tasks',String(num(s.pendingStaffRequests)),'Staff requests']
    ];
    grid.innerHTML=data.map(x=>`
      <div class="sales-kpi locked">
        <span class="kpi-icon">${window.BBMobileFunctionIconsV1?.named?.(x[0])||esc(x[0])}</span>
        <small>${esc(x[1])}</small>
        <strong>${esc(x[2])}</strong>
        <em>${esc(x[3])}</em>
      </div>
    `).join('');
    $('overviewTitle').textContent='Overview';$('periodLabel').textContent=overview.periodLabel||currentPeriod();
  }else{
    const locs=Array.isArray(profile?.locations)?profile.locations.length:0;
    const role=isAdmin()?'Admin':'User';
    const data=[['My Locations',String(locs),locationText()],['Available Actions',String(availableCount()),'Based on permissions'],['Access Level',role,'BIG BROTHER account'],['Workspace','Mobile','Standalone V1']];
    grid.innerHTML=data.map(x=>`<div class="kpi"><small>${esc(x[0])}</small><strong>${esc(x[1])}</strong><em>${esc(x[2])}</em></div>`).join('');
    $('overviewTitle').textContent='Overview';$('periodLabel').textContent=currentPeriod();
  }
}
function renderAttention(){
  const p=$('attentionPanel'),g=$('attentionGrid');
  if(!isAdmin()||!overview){p.hidden=true;return}
  p.hidden=false;const s=overview.currentSnapshot||{};
  const data=[[num(s.overdueARCount),'Overdue Receivables'],[num(s.lowStockAlerts),'Low Stock Alerts'],[num(s.pendingStaffRequests),'Pending Requests']];
  g.innerHTML=data.map(x=>`<div class="attention-card"><b>${esc(x[0])}</b><span>${esc(x[1])}</span></div>`).join('');
}
function renderRecent(){
  const list=$('recentList');
  if(!isAdmin()||!overview){list.innerHTML='<div class="menu-empty">Recent management activity is available to Admin users.</div>';return}
  const rows=Array.isArray(overview.recentTransactions)?overview.recentTransactions:[];
  if(!rows.length){list.innerHTML='<div class="menu-empty">No recent activity for this period.</div>';return}
  list.innerHTML=rows.slice(0,5).map(r=>`<div class="recent-row"><div class="recent-icon">${statusIcon(r.tx_type)}</div><div class="recent-main"><strong>${esc(r.ref_no||r.tx_type||'Transaction')}</strong><span>${esc(r.party||r.description||'-')}</span></div><div class="recent-side"><strong>${esc(String(r.currency||'USD').toUpperCase()==='KHR'?'៛'+Math.round(num(r.amount)).toLocaleString('en-US'):money(r.amount))}</strong><span>${esc(r.status||'Posted')}</span></div></div>`).join('');
}
function bindRouteButtons(host){host.querySelectorAll('[data-route]').forEach(btn=>btn.onclick=()=>openModule(btn.dataset.route,true))}
function renderHome(){
  $('userName').textContent='Welcome '+displayName()+'!';const chip=$('locationChip');const pin=window.BBMobileFunctionIconsV1?.named?.('map-pin');if(pin){chip.innerHTML=pin;chip.appendChild(document.createTextNode(locationText()))}else{chip.textContent='📍 '+locationText();}$('dateChip').textContent=dateText();
  renderKpis();

  /*
   * Quick Actions are owned by mobile-sales-support-home.js.
   * The old fixed QUICK list is only a fallback for deployments where
   * the unified controller is unavailable. This prevents Admin refreshes
   * and live-overview updates from restoring the legacy 8-item list.
   */
  if(window.BBMobileQuickActionsV1?.render){
    window.BBMobileQuickActionsV1.render();
  }else{
    $('quickActions').innerHTML=quickHtml();
    bindRouteButtons($('quickActions'));
  }

  renderAttention();renderRecent();
  $('notificationBtn').style.opacity=canRoute('notification-center')?'1':'.35';
}
function mobileHomeVisible(){
  const home=$('mobileHome');
  return Boolean(
    home &&
    !home.hidden &&
    document.visibilityState!=='hidden'
  );
}

function showHome(clearRoute=true,skipStartupDuplicateRefresh=false){
  activeTab='home';hideAll();$('mobileHome').hidden=false;
  if(clearRoute){
    if((window.BBMobileHistoryV7||window.BBMobileHistoryV6))(window.BBMobileHistoryV7||window.BBMobileHistoryV6).goHome();
    else setUrlRoute('');
  }
  renderHome();refreshNav('home');$('mobileScroll').scrollTop=0;

  /* Returning Home must immediately refresh Admin management data. */
  if(isAdmin()&&!skipStartupDuplicateRefresh)setTimeout(()=>loadOverview(false),40);
}
function showMenu(tab,clearRoute=true){
  activeTab=tab;hideAll();$('menuScreen').hidden=false;
  if(clearRoute){
    if((window.BBMobileHistoryV7||window.BBMobileHistoryV6))(window.BBMobileHistoryV7||window.BBMobileHistoryV6).recordMenu(tab,true);
    else setUrlRoute('');
  }
  const names={sales:'Sales',stock:'Stock',reports:'Reports',more:'More'};const items=permittedRoutes(tab);
  $('menuTitle').textContent=names[tab]||'Workspace';$('menuSubtitle').textContent=items.length+' available functions';
  $('menuGrid').innerHTML=items.length?(tab==='stock'?'<div style="grid-column:1/-1;font-weight:800;font-size:17px;padding:12px 2px 4px">📦 Stock Control</div>':'')+items.map(([route,x],i)=>`${tab==='stock'&&route==='stock-keyin'?'<div style="grid-column:1/-1;font-weight:800;font-size:17px;padding:12px 2px 4px">📋 Stock Management</div>':''}<button type="button" class="menu-card" data-route="${route}"><b>${window.BBMobileFunctionIconsV1?.route?.(route)||x.icon}</b><strong>${esc(x.label)}</strong><small>Open function</small></button>`).join(''):'<div class="menu-empty">No functions assigned in this section.</div>';
  bindRouteButtons($('menuGrid'));refreshNav(tab);$('menuGrid').scrollTop=0;
}
function openModule(route,updateUrl=true,forceLive=false){
  const item=ROUTES[route];if(!item){toast('This mobile route is not ready yet.');return false}if(!canRoute(route)){toast('Access denied for this function.');return false}
  const offline=window.BBMobileOfflineWorkspaceV1;
  const cached=window.BBMobileOfflineModulesV1;
  // Approval pages are transactional. Never show a cached read-only copy
  // when the user taps Review/Approve or opens a notification.
  const liveApproval=route==='admin-staff-request';
  // Opt-in pilot: the ORIGINAL Your Receivable page opens directly.
  // Other routes keep the existing read-only offline fallback unchanged.
  const realArPilot=(route==='ar-your'||route==='ar-all')&&bbRealArPilotEnabled();
  if(!forceLive&&!liveApproval&&!realArPilot&&cached?.canOpen(route)){
    void cached.open(route).then(ok=>{
      if(!ok){
        if(offline?.canUseNetwork())openModule(route,updateUrl,true);
        else toast('No synced data. Open online once.');
      }
    });
    return true;
  }
  const universal=window.BBMobileUniversalReadOnlyV1;
  if(!forceLive&&!liveApproval&&!realArPilot&&universal&&!['history','monthly-sales-report','sales-support-your-stock','sales-support-batch-selling-tracker','daily-sale-summary'].includes(route)){
    // Every permitted route can use its previously saved, non-executable
    // original UI first, even while internet is slow.
    void universal.open(route).then(ok=>{
      if(!ok){
        if(offline?.canUseNetwork())openModule(route,updateUrl,true);
        else toast('Open this function online once to save its read-only view.');
      }
    });
    return true;
  }
  if(offline&&!offline.canUseNetwork()&&!realArPilot){toast('This function requires internet.');return false}
  window.BBMobileOfflineModulesV1?.close();
  universal?.stop();
  hideAll();$('moduleScreen').hidden=false;$('moduleTitle').textContent=item.label;
  const liveUrl=new URL(item.url,location.href);
  if(realArPilot)liveUrl.searchParams.set('bb_cache_pilot','1');
  const liveFrame=replaceFrameUrl($('moduleFrame'),liveUrl.href);
  universal?.watch(route,liveFrame);
  $('moduleDesktopLink').href='index.html?module='+encodeURIComponent(route)+'&autoload=1';
  if(updateUrl){
    if((window.BBMobileHistoryV7||window.BBMobileHistoryV6))(window.BBMobileHistoryV7||window.BBMobileHistoryV6).recordModule(route,true);
    else setUrlRoute(route);
  }
  refreshNav('');return true;
}
// Notification Center is embedded on this same origin; keep staff inside
// the mobile shell when they open a linked business record.
window.BBMobileOpenNotificationV1=function(route){
  if(typeof route!=='string'||!ROUTES[route]||!canRoute(route))return false;
  // Use the same mobile history/router as normal menu taps.
  const nav=window.BBMobileHistoryV7||window.BBMobileHistoryV6;
  if(nav&&typeof nav.openModule==='function')return nav.openModule(route,true)!==false;
  if(window.BBMobileRouteV4?.open)return window.BBMobileRouteV4.open(route,true)!==false;
  return openModule(route,true);
};
function navigate(tab){
  if(tab==='home')showHome(true);else showMenu(tab,true);
}

function openSettings(){$('settingsSheet').hidden=false}
function closeSettings(){$('settingsSheet').hidden=true}

async function loadOverview(force=false){
  if(window.BBMobileOfflineWorkspaceV1?.canUseNetwork()===false)return;
  if(window.BBMobileOverviewV1?.refresh){
    try{
      await window.BBMobileOverviewV1.refresh(force);
      adminOverviewLastLoad=Date.now();
      return;
    }catch(_){}
  }
  if(!isAdmin())return;
  if(adminOverviewLoading)return;
  if(!force&&Date.now()-adminOverviewLastLoad<LIVE_OVERVIEW_MS-1000)return;
  if(!force&&!mobileHomeVisible())return;

  adminOverviewLoading=true;

  try{
    const d=new Date();
    const fresh=await rpc('bb_dashboard_monthly_overview',{
      p_year:d.getFullYear(),
      p_month:d.getMonth()+1
    });

    overview=fresh;
    void window.BBMobileOfflineWorkspaceV1?.write('admin-overview',fresh).then(ok=>{if(ok)void window.BBMobileOfflineWorkspaceV1.success()});
    adminOverviewLastLoad=Date.now();

    if(mobileHomeVisible())renderHome();
  }catch(error){
    /* Keep the last good admin snapshot visible during a temporary network error. */
    console.warn('Mobile Admin Overview:',error?.message||error);
  }finally{
    adminOverviewLoading=false;
  }
}

function installAdminOverviewLive(){
  if(adminOverviewTimer)return;

  window.addEventListener('focus',()=>{
    if(isAdmin()&&mobileHomeVisible()&&Date.now()-adminOverviewLastLoad>=LIVE_OVERVIEW_MS)loadOverview(false);
  });

  document.addEventListener('visibilitychange',()=>{
    if(
      document.visibilityState==='visible' &&
      isAdmin() &&
      mobileHomeVisible()
    ){
      if(Date.now()-adminOverviewLastLoad>=LIVE_OVERVIEW_MS)loadOverview(false);
    }
  });

  adminOverviewTimer=setInterval(()=>{
    if(
      isAdmin() &&
      mobileHomeVisible() &&
      Date.now()-adminOverviewLastLoad>=LIVE_OVERVIEW_MS-1000
    ){
      loadOverview(false);
    }
  },LIVE_OVERVIEW_MS);
}

async function activate(){
  if(window.BBMobileOfflineWorkspaceV1?.canUseNetwork()===false)return;
  profile=await rpc('bb_current_access_profile');
  const offline=window.BBMobileOfflineWorkspaceV1;
  if(offline){void offline.write('access-profile',profile);offline.setConnection(true)}
  installAdminOverviewLive();
  const requested=new URLSearchParams(location.search).get('module')||'';
  // Direct module links need authentication and permissions, not a blocking Home overview.
  // The unified Home controller still loads independently; returning Home refreshes live data.
  if(requested&&ROUTES[requested]&&canRoute(requested)&&openModule(requested,false))return;
  // Never silently land on Home for a push targeting an unimplemented
  // module. Keep the notification event available in Notification Center.
  if(new URLSearchParams(location.search).has('bb_notice')&&
     canRoute('notification-center')&&openModule('notification-center',false))return;
  // Display the authenticated shell immediately after access is verified.
  // The live overview can refresh without holding the entire mobile app on
  // its loading screen. Server-side permissions and all writes remain live.
  showHome(!requested,true);
  void loadOverview(true);
}
// Browser PWA and Android Firebase both supply the same notification keys.
// Save the exact receivable customer focus before any cached navigation runs.
function captureNotificationDeepLink(){
  try{
    const p=new URLSearchParams(location.search);
    const route=p.get('module')||'';
    const eventKey=p.get('bb_notice')||'';
    const entityId=p.get('bb_entity')||'';
    if(!eventKey||!ROUTES[route])return;
    if(!/^[a-zA-Z0-9_./:-]{1,180}$/.test(eventKey))return;
    if(!/^[a-zA-Z0-9_./:-]{1,120}$/.test(entityId)&&entityId)return;
    sessionStorage.setItem('BB_NOTIFICATION_TARGET_V2',
      JSON.stringify({route,entityId,notificationKey:eventKey}));
    if((route==='ar-your'||route==='ar-all')&&entityId&&
       /^(?:AR-OVERDUE:|OVERDUE-CUSTOMER:)/.test(eventKey)){
      sessionStorage.setItem('BB_NOTIFICATION_AR_FOCUS_V1',
        JSON.stringify({
          route,customerId:entityId,
          view:'Overdue Only',createdAt:Date.now()
        }));
    }
  }catch(_){}
}
async function boot(){
  captureNotificationDeepLink();
  hideAll();$('bootScreen').hidden=false;
  const offline=window.BBMobileOfflineWorkspaceV1;
  const saved=readSession();
  let openedFromCache=false;
  // Every open: render the last saved authorized workspace before calling Supabase.
  if(saved?.access_token&&offline?.currentUserId()){
    const [savedProfile,savedOverview]=await Promise.all([
      offline.read('access-profile'),offline.read('admin-overview')
    ]);
    if(savedProfile?.value){
      profile=savedProfile.value;
      overview=savedOverview?.value||null;
      // A push tap is a one-use deep link. Do not replace its module URL
      // with Home while rendering the cached profile before live auth.
      const pushRoute=new URLSearchParams(location.search).get('module')||'';
      showHome(!pushRoute,true);
      offline.updateIndicator();
      openedFromCache=true;
    }
  }
  try{
    await ensureSession();
    await activate(); // automatically refresh profile and data behind the cached Home
  }catch(error){
    if(isSessionAuthError(error)){
      try{await offline?.clearUser(saved?.user?.id)}catch(_){}
      saveSession(null);
      showLogin(error?.message==='Please sign in to BIG BROTHER.'?'':(error?.message||''));
      return;
    }
    // Network loss must not hide a previously synchronized dashboard.
    if(openedFromCache){offline?.setConnection(false);return}
    showLogin('Connect once to sign in and download your offline workspace.');
  }
}
// Recheck the LIVE permission profile after host recovery, once at a time.
// Never call activate() while a module is open: that would navigate back Home
// and discard staff selections/filters just as their internet returns.
let reconnectInFlight=false;
window.addEventListener('bb:mobile-reconnected',()=>{
  const offline=window.BBMobileOfflineWorkspaceV1;
  if(reconnectInFlight||offline?.canUseNetwork()===false||!readSession()?.access_token)return;
  reconnectInFlight=true;
  void (async()=>{
    try{
      await ensureSession();
      if($('moduleScreen')&&!$('moduleScreen').hidden){
        const verified=await rpc('bb_current_access_profile');
        if(verified){
          profile=verified;
          void offline?.write('access-profile',verified);
          offline?.setConnection(true);
        }
      }else{
        await activate();
      }
    }catch(error){
      offline?.setConnection(false);
    }finally{
      reconnectInFlight=false;
    }
  })();
});

$('loginForm').addEventListener('submit',async event=>{
  event.preventDefault();
  const btn=$('loginButton');
  const email=String($('loginEmail').value||'').trim();
  const password=$('loginPassword');
  $('loginError').textContent='';
  btn.disabled=true;
  btn.textContent='Signing in…';
  try{
    await signIn(email,password.value);
    rememberEmail(email);
    password.value='';
    void window.BBMobileOfflineWorkspaceV1?.init();
    await activate();
  }catch(error){
    $('loginError').textContent=error?.message||String(error);
    setTimeout(()=>{try{password?.focus({preventScroll:true})}catch(_){}},60);
  }finally{
    btn.disabled=false;
    btn.textContent='Sign In';
  }
});

$('toggleLoginPassword')?.addEventListener('click',()=>{
  const input=$('loginPassword');
  const button=$('toggleLoginPassword');
  if(!input||!button)return;
  const showing=input.type==='text';
  input.type=showing?'password':'text';
  button.textContent=showing?'Show':'Hide';
  button.setAttribute('aria-label',showing?'Show password':'Hide password');
  button.setAttribute('aria-pressed',showing?'false':'true');
  try{input.focus({preventScroll:true})}catch(_){}
});
$('settingsBtn').onclick=openSettings;$('menuSettings').onclick=openSettings;$('closeSettings').onclick=closeSettings;$('settingsSheet').onclick=e=>{if(e.target===$('settingsSheet'))closeSettings()};$('signOutBtn').onclick=async()=>{closeSettings();await signOut()};
$('notificationBtn').onclick=()=>{if(canRoute('notification-center'))openModule('notification-center',true);else toast('Notifications are not assigned to this user.')};
$('menuBack').onclick=()=>showHome(true);$('moduleBack').onclick=()=>showMenu(ROUTES[new URLSearchParams(location.search).get('module')||'']?.tab||'home',true);
window.addEventListener('popstate',()=>{if((window.BBMobileHistoryV7||window.BBMobileHistoryV6))return;const route=new URLSearchParams(location.search).get('module')||'';if(route&&ROUTES[route]&&canRoute(route))openModule(route,false);else showHome(false)});

boot();
})();
