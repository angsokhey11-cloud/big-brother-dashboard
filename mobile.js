/* BIG BROTHER — Standalone Mobile Dashboard V1 */
(function(){
'use strict';

const SUPABASE_URL='https://sjfhlaclgmkwwofzstok.supabase.co';
const SUPABASE_KEY='sb_publishable_w762jR65CWwlO30fKQsYOw_6L9grx8S';
const SESSION_KEY='BB_SUPABASE_DEV_SESSION_V1';
const LOGIN_EMAIL_KEY='BB_MOBILE_LOGIN_EMAIL_V1';

const REQUIRED_ACTION={
  'customers-add':'create','clients-add':'create','products-add':'create',
  'sales-support-request-delivery':'create','invoice':'create','purchase-create':'create','expense-add':'create'
};

const ROUTES={
  'sales-support-calculator':{tab:'sales',icon:'🧮',label:'Calculator',url:'https://angsokhey11-cloud.github.io/big-brother-sales-support/?embed=1&mobile=1&view=calculator&v=20260922-nodeliverypopup1'},
  'sales-support-request-delivery':{tab:'sales',icon:'🚚',label:'Request Delivery',url:'https://angsokhey11-cloud.github.io/big-brother-sales-support/?embed=1&view=request-delivery&v=110'},
  'sales-support-your-customer':{tab:'sales',icon:'👥',label:'My Customers',url:'https://angsokhey11-cloud.github.io/big-brother-sales-support/?embed=1&view=your-customer&v=110'},
  'sales-support-successful-delivery':{tab:'sales',icon:'✅',label:'Successful Delivery',url:'https://angsokhey11-cloud.github.io/big-brother-sales-support/?embed=1&view=successful-delivery&v=110'},
  'invoice':{tab:'sales',icon:'🧾',label:'Create Invoice',url:'https://angsokhey11-cloud.github.io/big-brother-invoice-generator/mobile.html?embed=1&v=20260920-arrealtime2'},
  'history':{tab:'sales',icon:'📚',label:'Invoice History',url:'https://angsokhey11-cloud.github.io/invoice-history/?embed=1&v=471'},
  'sale-return':{tab:'sales',icon:'↩️',label:'Invoice Reversal',url:'https://angsokhey11-cloud.github.io/big-brother-invoice-reversal/?embed=1&v=1'},
  'reversal-history':{tab:'sales',icon:'📜',label:'Reversal History',url:'https://angsokhey11-cloud.github.io/big-brother-invoice-reversal/history.html?embed=1&v=20260914-1'},
  'payment-history':{tab:'sales',icon:'💳',label:'Payment History',url:'https://angsokhey11-cloud.github.io/big-brother-payment-history/?embed=1&type=invoice&v=1'},
  'daily-sale-summary':{tab:'sales',icon:'📊',label:'Daily Sale Summary',url:'https://angsokhey11-cloud.github.io/big-brother-daily-sale-summary/?embed=1&v=1'},
  'daily-cash-collection':{tab:'sales',icon:'💵',label:'Cash Collection',url:'https://angsokhey11-cloud.github.io/big-brother-daily-cash-collection/?embed=1&v=1'},
  'ar-your':{tab:'sales',icon:'💰',label:'My Receivables',url:'https://angsokhey11-cloud.github.io/big-brother-ar/?embed=1&view=your&v=20260920-artelegram1'},

  'stock-keyin':{tab:'stock',icon:'📦',label:'Stock In / Out',url:'https://angsokhey11-cloud.github.io/big-brother-stock-managemenet/mobile.html?embed=1&v=20260923-stockux4'},
  'stock-damaged':{tab:'stock',icon:'⚠️',label:'Damaged Stock',url:'https://angsokhey11-cloud.github.io/big-brother-stock-managemenet/?embed=1&view=damaged&v=20'},
  'stock-report':{tab:'stock',icon:'📋',label:'Live Stock',url:'https://angsokhey11-cloud.github.io/big-brother-stock-report/mobile.html?embed=1&v=20260923-simple2'},
  'batch-report':{tab:'stock',icon:'🗂️',label:'Batch Report',url:'https://angsokhey11-cloud.github.io/big-brother-stock-report/batch-report.html?embed=1&v=10'},
  'closed-batch':{tab:'stock',icon:'✅',label:'Closed Batch',url:'https://angsokhey11-cloud.github.io/big-brother-stock-report/closed-batch.html?embed=1&v=10'},
  'stock-transactions':{tab:'stock',icon:'🔄',label:'Stock Transactions',url:'https://angsokhey11-cloud.github.io/big-brother-stock-report/transactions.html?embed=1&v=10'},
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
  'ar-all':{tab:'more',icon:'📋',label:'All Receivables',url:'https://angsokhey11-cloud.github.io/big-brother-ar/?embed=1&view=all&v=20260920-artelegram1'},
  'ar-payment-history':{tab:'more',icon:'🧾',label:'Receivable Payments',url:'https://angsokhey11-cloud.github.io/big-brother-payment-history/?embed=1&type=receivable&v=1'},
  'ar-daily-receivable-cash':{tab:'more',icon:'💵',label:'Daily Receivable Cash',url:'https://angsokhey11-cloud.github.io/big-brother-daily-receivable-cash-summary/?embed=1'},
  'customers-add':{tab:'more',icon:'👤',label:'Add Customer',url:'https://angsokhey11-cloud.github.io/big-brother-customers-editor/?embed=1&view=add&v=20260920-1'},
  'customers-map':{tab:'more',icon:'🗺️',label:'Customer Map',url:'https://angsokhey11-cloud.github.io/big-brother-customers-editor/?embed=1&view=map&v=20260920-1'},
  'customers-details':{tab:'more',icon:'👥',label:'Customer Details',url:'https://angsokhey11-cloud.github.io/big-brother-customers-editor/?embed=1&view=details&v=20260920-1'},
  'clients-add':{tab:'more',icon:'🏢',label:'Add Client',url:'https://angsokhey11-cloud.github.io/big-brother-clients-editor/?embed=1&view=add&v=10'},
  'clients-details':{tab:'more',icon:'🏭',label:'Client Details',url:'https://angsokhey11-cloud.github.io/big-brother-clients-editor/?embed=1&view=details&v=10'},
  'products-add':{tab:'more',icon:'🥛',label:'Add Product',url:'https://angsokhey11-cloud.github.io/big-brother-products-editor/?embed=1&view=add&v=10'},
  'products-details':{tab:'more',icon:'📦',label:'Product Details',url:'https://angsokhey11-cloud.github.io/big-brother-products-editor/?embed=1&view=details&v=10'},
  'staff-relation':{tab:'more',icon:'🤝',label:'Staff Relation',url:'https://angsokhey11-cloud.github.io/big-brother-staff-relation/?embed=1&v=20260913-1'},
  'notification-center':{tab:'more',icon:'🔔',label:'Notifications',url:'https://angsokhey11-cloud.github.io/big-brother-admin-work/company-control.html?embed=1&view=notifications&v=1'}
};

const QUICK=['sales-support-calculator','invoice','sales-support-your-customer','ar-your','sales-support-request-delivery','daily-cash-collection','stock-report','staff-relation'];
const NAV=[['home','⌂','Home'],['sales','▥','Sales'],['stock','◫','Stock'],['reports','▥','Reports'],['more','•••','More']];

let session=null;
let profile=null;
let overview=null;
let activeTab='home';
let adminOverviewLoading=false;
let adminOverviewLastLoad=0;
let adminOverviewTimer=null;
const LIVE_OVERVIEW_MS=20000;

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
  const current=readSession();
  try{if(current?.access_token)await fetch(SUPABASE_URL+'/auth/v1/logout',{method:'POST',headers:{apikey:SUPABASE_KEY,Authorization:'Bearer '+current.access_token},cache:'no-store'})}catch(_){}
  saveSession(null);profile=null;overview=null;showLogin('');
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
function permittedRoutes(tab){return Object.entries(ROUTES).filter(([route,item])=>item.tab===tab&&canRoute(route))}
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

function hideAll(){['bootScreen','loginScreen','mobileHome','menuScreen','moduleScreen'].forEach(id=>$(id).hidden=true)}
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
   const fresh=frame.cloneNode(false);
   fresh.removeAttribute('src');
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

function navHtml(active){return NAV.map(x=>`<button class="nav-btn ${active===x[0]?'active':''}" type="button" data-nav="${x[0]}"><b>${x[1]}</b>${x[2]}</button>`).join('')}
function bindNav(host){host.querySelectorAll('[data-nav]').forEach(btn=>btn.onclick=()=>navigate(btn.dataset.nav))}
function refreshNav(active){['bottomNav','menuBottomNav','moduleBottomNav'].forEach(id=>{const el=$(id);el.innerHTML=navHtml(active);bindNav(el)})}

function quickHtml(){
  const items=QUICK.filter(canRoute);
  $('quickCount').textContent=items.length+' available';
  return items.map(route=>{const x=ROUTES[route];return `<button type="button" class="quick-btn" data-route="${route}"><div class="quick-icon">${x.icon}</div><span>${esc(x.label)}</span></button>`}).join('')||'<div class="menu-empty">No quick actions assigned.</div>';
}
function renderKpis(){
  if(window.BBMobileOverviewV1?.render){
    try{window.BBMobileOverviewV1.render();return}catch(_){}
  }
  const grid=$('kpiGrid');
  if(isAdmin()&&overview){
    const m=overview.monthly||{},s=overview.currentSnapshot||{};
    const data=[
      ['📊','Monthly Sales',money(m.grossSalesUSD),overview.periodLabel||currentPeriod()],
      ['💰','Receivable',money(s.receivableUSD),'Current outstanding'],
      ['📦','Stock Value',money(s.stockValueUSD),'Current inventory'],
      ['⏳','Pending Tasks',String(num(s.pendingStaffRequests)),'Staff requests']
    ];
    grid.innerHTML=data.map(x=>`
      <div class="sales-kpi locked">
        <span class="kpi-icon">${esc(x[0])}</span>
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
  $('greeting').textContent=greeting();$('userName').textContent=displayName();$('locationChip').textContent='📍 '+locationText();$('dateChip').textContent=dateText();
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

function showHome(clearRoute=true){
  activeTab='home';hideAll();$('mobileHome').hidden=false;
  if(clearRoute){
    if((window.BBMobileHistoryV7||window.BBMobileHistoryV6))(window.BBMobileHistoryV7||window.BBMobileHistoryV6).goHome();
    else setUrlRoute('');
  }
  renderHome();refreshNav('home');$('mobileScroll').scrollTop=0;

  /* Returning Home must immediately refresh Admin management data. */
  if(isAdmin())setTimeout(()=>loadOverview(true),40);
}
function showMenu(tab,clearRoute=true){
  activeTab=tab;hideAll();$('menuScreen').hidden=false;
  if(clearRoute){
    if((window.BBMobileHistoryV7||window.BBMobileHistoryV6))(window.BBMobileHistoryV7||window.BBMobileHistoryV6).recordMenu(tab,true);
    else setUrlRoute('');
  }
  const names={sales:'Sales',stock:'Stock',reports:'Reports',more:'More'};const items=permittedRoutes(tab);
  $('menuTitle').textContent=names[tab]||'Workspace';$('menuSubtitle').textContent=items.length+' available functions';
  $('menuGrid').innerHTML=items.length?items.map(([route,x])=>`<button type="button" class="menu-card" data-route="${route}"><b>${x.icon}</b><strong>${esc(x.label)}</strong><small>Open function</small></button>`).join(''):'<div class="menu-empty">No functions assigned in this section.</div>';
  bindRouteButtons($('menuGrid'));refreshNav(tab);$('menuGrid').scrollTop=0;
}
function openModule(route,updateUrl=true){
  const item=ROUTES[route];if(!item){toast('This mobile route is not ready yet.');return false}if(!canRoute(route)){toast('Access denied for this function.');return false}
  hideAll();$('moduleScreen').hidden=false;$('moduleTitle').textContent=item.label;replaceFrameUrl($('moduleFrame'),item.url);
  $('moduleDesktopLink').href='index.html?module='+encodeURIComponent(route)+'&autoload=1';
  if(updateUrl){
    if((window.BBMobileHistoryV7||window.BBMobileHistoryV6))(window.BBMobileHistoryV7||window.BBMobileHistoryV6).recordModule(route,true);
    else setUrlRoute(route);
  }
  refreshNav('');return true;
}
function navigate(tab){
  if(tab==='home')showHome(true);else showMenu(tab,true);
}

function openSettings(){$('settingsSheet').hidden=false}
function closeSettings(){$('settingsSheet').hidden=true}

async function loadOverview(force=false){
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
    if(isAdmin()&&mobileHomeVisible())loadOverview(true);
  });

  document.addEventListener('visibilitychange',()=>{
    if(
      document.visibilityState==='visible' &&
      isAdmin() &&
      mobileHomeVisible()
    ){
      loadOverview(true);
    }
  });

  adminOverviewTimer=setInterval(()=>{
    if(
      isAdmin() &&
      mobileHomeVisible() &&
      Date.now()-adminOverviewLastLoad>=LIVE_OVERVIEW_MS-1000
    ){
      loadOverview(true);
    }
  },LIVE_OVERVIEW_MS);
}

async function activate(){
  profile=await rpc('bb_current_access_profile');
  await loadOverview(true);
  installAdminOverviewLive();
  const requested=new URLSearchParams(location.search).get('module')||'';
  if(requested&&ROUTES[requested]&&canRoute(requested)){openModule(requested,false);return}
  showHome(!requested);
}
async function boot(){
  hideAll();$('bootScreen').hidden=false;
  try{
    await ensureSession();
    await activate();
  }catch(error){
    if(isSessionAuthError(error)){
      saveSession(null);
      showLogin(error?.message==='Please sign in to BIG BROTHER.'?'':(error?.message||''));
      return;
    }

    /* iOS/PWA can briefly lose network while opening or resuming.
       Keep the saved session and retry once instead of forcing a new login. */
    try{
      await new Promise(resolve=>setTimeout(resolve,650));
      await ensureSession();
      await activate();
      return;
    }catch(retryError){
      if(isSessionAuthError(retryError))saveSession(null);
      showLogin(
        isSessionAuthError(retryError)
          ? (retryError?.message==='Please sign in to BIG BROTHER.'?'':(retryError?.message||''))
          : 'Could not reconnect yet. Your saved login is still kept. Check internet and try again.'
      );
    }
  }
}

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
