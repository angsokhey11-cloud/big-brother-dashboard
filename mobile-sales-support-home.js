/* BIG BROTHER — Unified Mobile Home V3.4
   Home KPIs stay fixed. Quick Actions are user-selected.
   Bottom nav: Home | User Page 1 | User Page 2 | Menu.
   Recent Activity follows the signed-in user's audited actions.
*/
(()=>{
'use strict';

const SUPABASE_URL='https://sjfhlaclgmkwwofzstok.supabase.co';
const SUPABASE_KEY='sb_publishable_w762jR65CWwlO30fKQsYOw_6L9grx8S';
const SESSION_KEY='BB_SUPABASE_DEV_SESSION_V1';
const GH='https://angsokhey11-cloud.github.io/';

const ROUTE_ROWS=`
sales-support-calculator|Sales Support|🧮|Calculator
sales-support-request-delivery|Sales Support|🚚|Request Delivery
sales-support-your-customer|Sales Support|👥|Your Customer
sales-support-add-customer|Sales Support|👤+|Add Customer
sales-support-customer-map|Sales Support|📍|Customer Map
sales-support-your-stock|Sales Support|📦|Your Stock
sales-support-your-collection|Sales Support|💵|Your Collection
sales-support-your-invoices|Sales Support|🧾|Your Invoices
sales-support-your-receivable|Sales Support|💳|Your Receivable
sales-support-successful-delivery|Sales Support|✅|Successful Delivery
invoice|Sales|🧾|Create Invoice
history|Sales|📚|Invoice History
sale-return|Sales|↩️|Invoice Reversal
reversal-history|Sales|📜|Reversal History
payment-history|Sales|💳|Payment History
daily-sale-summary|Sales|📊|Daily Sale Summary
daily-cash-collection|Sales|💵|Cash Collection
ar-all|Receivable|📋|All Receivables
ar-your|Receivable|💰|My Receivables
ar-payment-history|Receivable|🧾|Receivable Payments
ar-daily-receivable-cash|Receivable|💵|Daily Receivable Cash
stock-keyin|Stock|📦|Stock In / Out
stock-damaged|Stock|⚠️|Damaged Stock
stock-report|Stock|📋|Stock Report
batch-report|Stock|🗂️|Batch Report
closed-batch|Stock|✅|Closed Batch
stock-transactions|Stock|🔄|Stock Transactions
stock-alerts|Stock|🚨|Smart Stock Alerts
monthly-sales-report|Reports|📈|Monthly Sales
income-statement-report|Reports|📊|Income Statement
purchase-order-report|Reports|🧾|Purchase Order Report
cogs-daily|Reports|🏷️|Daily COGS
cogs-monthly|Reports|📦|Monthly COGS
expense-monthly-report|Reports|💸|Monthly Expense
purchase-create|Purchase|🛒|Create Purchase
purchase-history|Purchase|📚|Purchase History
purchase-payable|Purchase|💵|Purchase Payable
purchase-payment-history|Purchase|💳|Purchase Payments
expense-add|Expenses|➕|Add Expense
expense-accrued|Expenses|⏳|Accrued Expense
expense-history|Expenses|🧾|Expense History
customers-add|Master Data|👤|Add Customer
customers-map|Master Data|🗺️|Customer Map
customers-details|Master Data|👥|Customer Details
clients-add|Master Data|🏢|Add Client
clients-details|Master Data|🏭|Client Details
products-add|Master Data|🥛|Add Product
products-details|Master Data|📦|Product Details
master-expense-categories|Master Data|💸|Expense Categories
admin-pending-receivable|Admin Work|💰|Pending Receivable Request
admin-pending-daily-cash|Admin Work|💵|Pending Daily Cash Request
admin-pending-deposit|Admin Work|🏦|Pending Deposit
admin-deposit-history|Admin Work|📚|Deposit History
admin-staff-request|Admin Work|👥|Staff Request
admin-request|Admin Work|🛠️|Admin Request
admin-user-permissions|Admin Work|🔐|User & Permission Manager
staff-relation|Company|🤝|Staff Relation
notification-center|Company|🔔|Notifications`.trim().split('\n').map(row=>row.split('|'));

const BASE_ROUTES=new Set([
  'sales-support-calculator','sales-support-request-delivery','sales-support-your-customer','sales-support-successful-delivery',
  'invoice','history','sale-return','reversal-history','payment-history','daily-sale-summary','daily-cash-collection','ar-your',
  'stock-keyin','stock-damaged','stock-report','batch-report','closed-batch','stock-transactions','stock-alerts',
  'monthly-sales-report','income-statement-report','purchase-order-report','cogs-daily','cogs-monthly','expense-monthly-report',
  'purchase-create','purchase-history','purchase-payable','purchase-payment-history','expense-add','expense-accrued','expense-history',
  'ar-all','ar-payment-history','ar-daily-receivable-cash','customers-add','customers-map','customers-details','clients-add','clients-details',
  'products-add','products-details','staff-relation','notification-center'
]);

const MOBILE_URLS={
  'sales-support-add-customer':'big-brother-sales-support/add-customer-mobile.html?embed=1&v=20260914-2',
  'sales-support-customer-map':'big-brother-customers-editor/sales-support-customer-map-mobile.html?embed=1&v=20260914-2',
  'sales-support-your-stock':'big-brother-sales-support/your-stock-mobile.html?embed=1&v=20260914-5',
  'sales-support-your-collection':'big-brother-daily-cash-collection/your-collection-mobile.html?embed=1&v=20260914-8',
  'sales-support-your-invoices':'invoice-history/your-invoices-mobile.html?embed=1&v=20260914-2',
  'sales-support-your-receivable':'big-brother-ar/your-receivable-mobile.html?embed=1&view=your&v=20260914-3',
  'master-expense-categories':'big-brother-master-data/expense-categories.html?embed=1&v=20260912-3',
  'admin-pending-receivable':'big-brother-admin-work/?embed=1&view=pending-receivable',
  'admin-pending-daily-cash':'big-brother-admin-work/?embed=1&view=pending-daily-cash',
  'admin-pending-deposit':'big-brother-admin-work/?embed=1&view=pending-deposit',
  'admin-deposit-history':'big-brother-admin-work/?embed=1&view=deposit-history',
  'admin-staff-request':'big-brother-admin-work/?embed=1&view=staff-request',
  'admin-request':'big-brother-admin-work/?embed=1&view=admin-request',
  'admin-user-permissions':'big-brother-admin-work/user-permissions.html?embed=1&v=1'
};

const CREATE_ROUTES=new Set([
  'sales-support-add-customer','sales-support-request-delivery','customers-add','clients-add','products-add','invoice','purchase-create','expense-add'
]);

const ROUTES=Object.fromEntries(ROUTE_ROWS.map(([route,group,icon,label])=>[route,{
  route,group,icon,label,url:MOBILE_URLS[route]?GH+MOBILE_URLS[route]:''
}]));

let profile=null;
let quick=[];
let pages=[];
let overview=null;
let payment=null;
let activityData=null;
let lastActivityFetch=0;
let pickerMode='quick';
let pickerSlot=0;
let fallbackRoute='';
let currentRoute='';
let navLongPressTimer=null;

const $=id=>document.getElementById(id);
const clean=v=>String(v??'').trim();
const key=v=>clean(v).toLowerCase();
const num=v=>Number(v||0)||0;
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));
const money=v=>'$'+num(v).toLocaleString('en-US',{minimumFractionDigits:2,maximumFractionDigits:2});
const qty=v=>num(v).toLocaleString('en-US',{maximumFractionDigits:2});
const pretty=v=>clean(v).replace(/[_-]+/g,' ').replace(/\b\w/g,m=>m.toUpperCase());

function readSession(){try{return JSON.parse(localStorage.getItem(SESSION_KEY)||'null')}catch(_){return null}}
async function parseResponse(response){
  const text=await response.text();let body={};
  try{body=text?JSON.parse(text):{}}catch(_){body={message:text}}
  if(!response.ok)throw new Error(body.message||body.error_description||body.error||'Request failed');
  return body;
}
async function refreshSession(){
  const s=readSession();if(!s?.refresh_token)throw new Error('Please sign in.');
  const response=await fetch(SUPABASE_URL+'/auth/v1/token?grant_type=refresh_token',{
    method:'POST',headers:{apikey:SUPABASE_KEY,'Content-Type':'application/json'},body:JSON.stringify({refresh_token:s.refresh_token})
  });
  const next=await parseResponse(response);
  if(!next.expires_at&&next.expires_in)next.expires_at=Math.floor(Date.now()/1000)+Number(next.expires_in);
  localStorage.setItem(SESSION_KEY,JSON.stringify(next));return next;
}
async function rpc(fn,args={}){
  let s=readSession();if(!s?.access_token)throw new Error('Please sign in.');
  if(s.expires_at&&Number(s.expires_at)<Math.floor(Date.now()/1000)+45)s=await refreshSession();
  const call=token=>fetch(SUPABASE_URL+'/rest/v1/rpc/'+fn,{
    method:'POST',headers:{apikey:SUPABASE_KEY,Authorization:'Bearer '+token,'Content-Type':'application/json'},
    body:JSON.stringify(args||{}),cache:'no-store'
  });
  let response=await call(s.access_token);
  if(response.status===401){s=await refreshSession();response=await call(s.access_token)}
  return parseResponse(response);
}
async function safeRpc(fn,args={}){try{return await rpc(fn,args)}catch(error){console.warn('Mobile '+fn+':',error?.message||error);return null}}

function isAdmin(){return profile?.user?.isAdmin===true}
function grantFor(route){
  if(isAdmin())return{canView:true,canCreate:true,canEdit:true,canApprove:true};
  const modules=Array.isArray(profile?.modules)?profile.modules:[];
  return modules.find(x=>key(x.moduleKey)==='*')||modules.find(x=>key(x.moduleKey)==='route.'+key(route))||null;
}
function canRoute(route){
  if(!ROUTES[route])return false;
  const grant=grantFor(route);if(!grant)return false;
  return CREATE_ROUTES.has(route)?grant.canView===true&&grant.canCreate===true:grant.canView===true;
}
function userId(){return clean(profile?.staff?.staffId||profile?.user?.staffId||profile?.user?.userId||profile?.user?.email||'user')}
function quickKey(){return 'bb_mobile_quick_order_v2::'+userId()}
function pageKey(){return 'bb_mobile_pinned_pages_v1::'+userId()}
function readLocal(storageKey){try{return JSON.parse(localStorage.getItem(storageKey)||'[]')}catch(_){return[]}}
function writeLocal(storageKey,value){try{localStorage.setItem(storageKey,JSON.stringify(value))}catch(_){}}
function normalizeQuick(value,max=64){
  const out=[],seen=new Set();
  (Array.isArray(value)?value:[]).forEach(route=>{
    route=clean(route);
    if(route&&ROUTES[route]&&canRoute(route)&&!seen.has(route)&&out.length<max){seen.add(route);out.push(route)}
  });
  return out;
}
function normalizePages(value){
  const input=Array.isArray(value)?value:[];
  return [0,1].map(i=>{const route=clean(input[i]);return route&&ROUTES[route]&&canRoute(route)?route:''});
}
function toast(text){
  const el=$('toast');if(!el)return;
  el.textContent=text;el.hidden=false;clearTimeout(toast._timer);toast._timer=setTimeout(()=>el.hidden=true,1900);
}

function injectCss(){
  if($('bbUnifiedHomeCss'))return;
  const style=document.createElement('style');style.id='bbUnifiedHomeCss';
  style.textContent=`
    #bbQuickResetBtn{display:none!important}
    .bb-qa-add{height:29px;border:1px solid #cdddec;background:#eef6ff;color:#1267b0;border-radius:999px;padding:0 10px;font:900 8.5px inherit;cursor:pointer}

    /* Slightly larger locked Monthly Overview */
    #kpiGrid{gap:7px!important}
    #kpiGrid .sales-kpi{grid-template-columns:34px minmax(0,1fr) 23px!important;min-height:78px!important;padding:8px!important;column-gap:7px!important;border-radius:13px!important}
    #kpiGrid .sales-kpi .kpi-icon{width:34px!important;height:34px!important;border-radius:10px!important;font-size:17px!important}
    #kpiGrid .sales-kpi small{font-size:8.6px!important}
    #kpiGrid .sales-kpi strong{font-size:16px!important}
    #kpiGrid .sales-kpi em{font-size:7.4px!important;margin-top:4px!important}
    #kpiGrid .sales-kpi .kpi-arrow{width:23px!important;height:23px!important;font-size:14px!important}

    /* Slightly larger user Quick Actions */
    #quickActions{gap:9px 5px!important}
    #quickActions .quick-btn{min-height:68px!important;padding:5px 2px!important;border-radius:12px!important}
    #quickActions .quick-icon{width:44px!important;height:44px!important;border-radius:13px!important;font-size:21px!important;margin-bottom:5px!important}
    #quickActions .quick-btn>span{font-size:9px!important;line-height:1.1!important}
    #quickActions .menu-empty{grid-column:1/-1;padding:12px 8px!important;text-align:center!important}

    .bb-picker{position:fixed;inset:0;z-index:99999;background:#142b4166;display:flex;align-items:flex-end}
    .bb-picker[hidden]{display:none!important}
    .bb-picker-box{width:100%;max-height:80dvh;background:#f7faff;border-radius:20px 20px 0 0;padding:12px;display:flex;flex-direction:column;box-shadow:0 -12px 40px #10294a24}
    .bb-picker-head{display:flex;align-items:center;justify-content:space-between;gap:10px;color:#173d70}
    .bb-picker-head button{width:32px;height:32px;border:0;border-radius:50%;background:#eaf2fb;font-size:18px}
    .bb-picker-search{height:40px;border:1px solid #d7e2ee;border-radius:10px;padding:0 10px;margin:9px 0;background:#fff}
    .bb-picker-list{overflow:auto;display:grid;gap:6px;padding-bottom:max(4px,env(safe-area-inset-bottom))}
    .bb-picker-row{border:1px solid #dce6f1;background:#fff;border-radius:11px;padding:8px;display:grid;grid-template-columns:34px minmax(0,1fr) auto;gap:8px;align-items:center;text-align:left;color:#173d70}
    .bb-picker-row.selected{border-color:#1267b0;background:#f0f7ff}
    .bb-picker-icon{width:34px;height:34px;border-radius:9px;background:#eef6ff;display:grid;place-items:center;font-size:17px}
    .bb-picker-row b{display:block;font-size:10px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
    .bb-picker-row small{display:block;font-size:7px;color:#718197;margin-top:2px}
    .bb-picker-state{font-size:8px;font-weight:900;color:#1267b0}
    .bb-picker-remove{margin-top:8px;height:37px;border:1px solid #e0e7ef;border-radius:10px;background:#fff;color:#c33;font-weight:800}
    .bottom-nav .nav-btn .bb-nav-label{display:block;max-width:78px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
    .bottom-nav .nav-btn.bb-page-empty b{color:#1267b0}

    @media(max-width:380px){
      #kpiGrid .sales-kpi{grid-template-columns:31px minmax(0,1fr) 20px!important;min-height:73px!important;padding:7px!important;column-gap:6px!important}
      #kpiGrid .sales-kpi .kpi-icon{width:31px!important;height:31px!important;font-size:15px!important}
      #kpiGrid .sales-kpi strong{font-size:14.5px!important}
      #quickActions .quick-btn{min-height:64px!important}
      #quickActions .quick-icon{width:41px!important;height:41px!important;font-size:20px!important}
      #quickActions .quick-btn>span{font-size:8.5px!important}
    }
  `;
  document.head.appendChild(style);
}

function ensureHiddenStaffMeta(){
  if(document.querySelector('#salesmanIntro .salesman-meta'))return;
  const node=document.createElement('div');node.id='salesmanIntro';node.hidden=true;
  node.innerHTML='<span class="salesman-meta">'+esc(userId())+' ·</span>';
  document.body.appendChild(node);
}

function installQuickControls(){
  const grid=$('quickActions');if(!grid)return;
  const panel=grid.closest('.panel');const head=panel?.querySelector('.section-head');
  if(head&&!$('bbQuickAddButton')){
    let tools=head.querySelector('.bb-quick-tools');
    if(!tools){tools=document.createElement('div');tools.className='bb-quick-tools';head.appendChild(tools)}
    const button=document.createElement('button');button.id='bbQuickAddButton';button.className='bb-qa-add';button.type='button';button.textContent='＋ Add';
    button.onclick=()=>openPicker('quick');tools.prepend(button);
  }
  $('bbPages')?.remove();
}

function installPicker(){
  if($('bbFunctionPicker'))return;
  const wrap=document.createElement('div');wrap.id='bbFunctionPicker';wrap.className='bb-picker';wrap.hidden=true;
  wrap.innerHTML=`<div class="bb-picker-box">
    <div class="bb-picker-head"><b id="bbPickerTitle">Choose Function</b><button id="bbPickerClose" type="button">×</button></div>
    <input id="bbPickerSearch" class="bb-picker-search" type="search" placeholder="Search permitted functions…">
    <div id="bbPickerList" class="bb-picker-list"></div>
    <button id="bbPickerRemove" class="bb-picker-remove" type="button" hidden>Remove this page</button>
  </div>`;
  document.body.appendChild(wrap);
  $('bbPickerClose').onclick=closePicker;
  $('bbPickerSearch').oninput=renderPicker;
  $('bbPickerRemove').onclick=removePage;
  wrap.onclick=event=>{if(event.target===wrap)closePicker()};
}

function openPicker(mode,slot=0){
  pickerMode=mode;pickerSlot=slot;
  installPicker();
  $('bbPickerTitle').textContent=mode==='quick'?'Quick Actions':'Choose Bottom Page '+(slot+1);
  $('bbPickerSearch').value='';
  $('bbPickerRemove').hidden=!(mode==='page'&&pages[slot]);
  $('bbFunctionPicker').hidden=false;
  renderPicker();
}
function closePicker(){if($('bbFunctionPicker'))$('bbFunctionPicker').hidden=true}
function renderPicker(){
  const host=$('bbPickerList');if(!host)return;
  const term=key($('bbPickerSearch')?.value);
  const items=ROUTE_ROWS.filter(([route,group,,label])=>canRoute(route)&&(!term||(route+' '+group+' '+label).toLowerCase().includes(term)))
    .sort((a,b)=>(a[1]+a[3]).localeCompare(b[1]+b[3]));
  host.innerHTML=items.map(([route,group,icon,label])=>{
    const selected=pickerMode==='quick'?quick.includes(route):pages[pickerSlot]===route;
    return `<button type="button" class="bb-picker-row ${selected?'selected':''}" data-pick-route="${route}">
      <span class="bb-picker-icon">${icon}</span><span><b>${esc(label)}</b><small>${esc(group)}</small></span>
      <span class="bb-picker-state">${selected?(pickerMode==='quick'?'Added':'Selected'):(pickerMode==='quick'?'+ Add':'Choose')}</span>
    </button>`;
  }).join('')||'<div class="menu-empty">No permitted functions found.</div>';
  host.querySelectorAll('[data-pick-route]').forEach(button=>button.onclick=()=>chooseRoute(button.dataset.pickRoute));
}
async function chooseRoute(route){
  if(pickerMode==='quick'){
    quick=quick.includes(route)?quick.filter(x=>x!==route):quick.concat(route);
    await saveQuick();renderQuick();renderPicker();return;
  }
  pages[pickerSlot]=route;await savePages();closePicker();renderNav(currentNavState());toast('Page '+(pickerSlot+1)+' saved');
}
async function removePage(){pages[pickerSlot]='';await savePages();closePicker();renderNav(currentNavState());toast('Page removed')}
async function saveQuick(){quick=normalizeQuick(quick);writeLocal(quickKey(),quick);await safeRpc('bb_mobile_save_quick_action_order',{p_order:quick})}
async function savePages(){pages=normalizePages(pages);writeLocal(pageKey(),pages);await safeRpc('bb_mobile_save_pinned_pages',{p_pages:pages})}

function renderQuick(){
  const host=$('quickActions');if(!host)return;
  quick=normalizeQuick(quick);
  host.innerHTML=quick.length?quick.map(route=>{
    const item=ROUTES[route];
    return `<button type="button" class="quick-btn" data-sales-route="${route}"><div class="quick-icon">${item.icon}</div><span>${esc(item.label)}</span></button>`;
  }).join(''):'<div class="menu-empty">Tap ＋ Add above to choose your Quick Actions.</div>';
  host.querySelectorAll('[data-sales-route]').forEach(button=>button.onclick=()=>openRoute(button.dataset.salesRoute));
  if($('quickCount'))$('quickCount').textContent=quick.length?quick.length+' selected':'Choose your shortcuts';
}

function navPageButton(slotIndex,active){
  const route=pages[slotIndex];const item=ROUTES[route];
  if(!item)return `<button type="button" class="nav-btn bb-page-empty ${active==='page'+slotIndex?'active':''}" data-bb-page="${slotIndex}"><b>＋</b><span class="bb-nav-label">Page ${slotIndex+1}</span></button>`;
  return `<button type="button" class="nav-btn ${active==='page'+slotIndex?'active':''}" data-bb-page="${slotIndex}" title="Hold to change"><b>${item.icon}</b><span class="bb-nav-label">${esc(item.label)}</span></button>`;
}
function renderNav(active='home'){
  pages=normalizePages(pages);
  const html=`<button type="button" class="nav-btn ${active==='home'?'active':''}" data-bb-nav="home"><b>⌂</b><span class="bb-nav-label">Home</span></button>`+
    navPageButton(0,active)+navPageButton(1,active)+
    `<button type="button" class="nav-btn ${active==='menu'?'active':''}" data-bb-nav="menu"><b>☰</b><span class="bb-nav-label">Menu</span></button>`;
  ['bottomNav','menuBottomNav','moduleBottomNav'].forEach(id=>{
    const host=$(id);if(!host)return;host.innerHTML=html;wireNavHost(host);
  });
}
function wireNavHost(host){
  host.querySelectorAll('[data-bb-nav="home"]').forEach(button=>button.onclick=showHome);
  host.querySelectorAll('[data-bb-nav="menu"]').forEach(button=>button.onclick=showMainMenu);
  host.querySelectorAll('[data-bb-page]').forEach(button=>{
    const slot=Number(button.dataset.bbPage);
    button.onpointerdown=()=>{
      clearTimeout(navLongPressTimer);
      navLongPressTimer=setTimeout(()=>{navLongPressTimer=null;openPicker('page',slot)},600);
    };
    const cancel=()=>{if(navLongPressTimer){clearTimeout(navLongPressTimer);navLongPressTimer=null}};
    button.onpointerup=()=>{
      if(!navLongPressTimer)return;
      cancel();const route=pages[slot];route?openRoute(route,'page'+slot):openPicker('page',slot);
    };
    button.onpointercancel=cancel;button.onpointerleave=cancel;
  });
}
function currentNavState(){
  if(!$('mobileHome')?.hidden)return'home';
  if(!$('menuScreen')?.hidden)return'menu';
  if(currentRoute&&pages[0]===currentRoute)return'page0';
  if(currentRoute&&pages[1]===currentRoute)return'page1';
  return'';
}

function showHome(){
  currentRoute='';fallbackRoute='';closePicker();
  try{
    if(window.BBMobile?.home){
      window.BBMobile.home(true);
      setTimeout(()=>{renderHome();renderNav('home');refreshRecentActivity(true)},0);
      return;
    }
  }catch(_){ }
  if($('mobileHome'))$('mobileHome').hidden=false;if($('menuScreen'))$('menuScreen').hidden=true;if($('moduleScreen'))$('moduleScreen').hidden=true;
  renderHome();renderNav('home');refreshRecentActivity(true);
}
function showMainMenu(){
  currentRoute='';fallbackRoute='';closePicker();
  if($('mobileHome'))$('mobileHome').hidden=true;if($('moduleScreen'))$('moduleScreen').hidden=true;if($('menuScreen'))$('menuScreen').hidden=false;
  try{const u=new URL(location.href);u.searchParams.delete('module');u.searchParams.delete('autoload');history.replaceState({},'',u.pathname+u.search+u.hash)}catch(_){ }
  renderMainMenu();renderNav('menu');
}
function renderMainMenu(){
  const host=$('menuGrid');if(!host||!profile)return;
  if($('menuTitle'))$('menuTitle').textContent='Main Menu';
  const allowed=ROUTE_ROWS.filter(([route])=>canRoute(route));
  if($('menuSubtitle'))$('menuSubtitle').textContent=allowed.length+' available functions';
  const groups=[...new Set(allowed.map(x=>x[1]))];
  host.innerHTML=groups.map(group=>{
    const rows=allowed.filter(x=>x[1]===group);
    return `<div class="bb-menu-group" style="grid-column:1/-1"><div style="font-size:9px;font-weight:900;color:#72849a;margin:5px 2px 2px">${esc(group)}</div></div>`+
      rows.map(([route,,icon,label])=>`<button type="button" class="menu-card" data-menu-route="${route}"><b>${icon}</b><strong>${esc(label)}</strong><small>Open function</small></button>`).join('');
  }).join('')||'<div class="menu-empty">No functions assigned.</div>';
  host.querySelectorAll('[data-menu-route]').forEach(button=>button.onclick=()=>openRoute(button.dataset.menuRoute));
}

function openRoute(route,navState=''){
  if(!canRoute(route))return toast('Access denied.');
  closePicker();currentRoute=route;fallbackRoute='';
  if(BASE_ROUTES.has(route)&&window.BBMobile?.open){
    try{
      const result=window.BBMobile.open(route,true);
      if(result!==false){setTimeout(()=>renderNav(navState||currentNavState()),0);return}
    }catch(_){ }
  }
  const item=ROUTES[route];
  if(!item?.url)return toast('Mobile route is not ready.');
  fallbackRoute=route;
  if($('mobileHome'))$('mobileHome').hidden=true;if($('menuScreen'))$('menuScreen').hidden=true;if($('moduleScreen'))$('moduleScreen').hidden=false;
  if($('moduleTitle'))$('moduleTitle').textContent=item.label;if($('moduleFrame'))$('moduleFrame').src=item.url;
  try{const u=new URL(location.href);u.searchParams.set('module',route);u.searchParams.set('autoload','1');history.replaceState({},'',u.pathname+u.search+u.hash)}catch(_){ }
  renderNav(navState||currentNavState());
}

function renderStaffKpis(){
  if(isAdmin()||!overview||!$('kpiGrid'))return;
  const sales=overview.monthlySales||{},ar=overview.receivable||{},stock=overview.stock||{};
  const available=Array.isArray(payment?.available)?payment.available:[];
  const usd=available.filter(x=>key(x.currency||'USD')==='usd').reduce((sum,x)=>sum+num(x.amount),0);
  const card=(icon,label,value,sub,route='')=>{
    const clickable=route&&canRoute(route);const tag=clickable?'button':'div';
    return `<${tag} class="sales-kpi ${clickable?'clickable':'locked'}" ${clickable?`type="button" data-kpi-route="${route}"`:''}><span class="kpi-icon">${icon}</span><small>${esc(label)}</small><strong>${esc(value)}</strong><em>${esc(sub)}</em>${clickable?'<span class="kpi-arrow">›</span>':''}</${tag}>`;
  };
  const receivableRoute=canRoute('sales-support-your-receivable')?'sales-support-your-receivable':canRoute('ar-your')?'ar-your':'';
  const stockRoute=canRoute('sales-support-your-stock')?'sales-support-your-stock':canRoute('stock-report')?'stock-report':'';
  $('kpiGrid').innerHTML=
    card('📊','Monthly Sales',money(sales.netUSD),Math.round(num(sales.invoiceCount))+' invoices')+
    card('💰','Receivable',money(ar.equivalentUSD),Math.round(num(ar.count))+' open',receivableRoute)+
    card('📦','Stock Qty',qty(stock.physicalQty),Math.round(num(stock.openBatchCount))+' open batches',stockRoute)+
    card('👛','Your Earning',money(usd),available.length+' available',canRoute('staff-relation')?'staff-relation':'');
  $('kpiGrid').querySelectorAll('[data-kpi-route]').forEach(button=>button.onclick=()=>openRoute(button.dataset.kpiRoute));
}

function activityIcon(action,module){
  const a=key(action),m=key(module);
  if(a.includes('delete'))return'🗑️';
  if(a.includes('update')||a.includes('edit'))return'✏️';
  if(a.includes('approve')||a.includes('close'))return'✅';
  if(a.includes('reject'))return'⛔';
  if(a.includes('payment')||m.includes('cash')||m.includes('payment'))return'💵';
  if(a.includes('insert')||a.includes('create'))return'＋';
  if(m.includes('stock'))return'📦';
  if(m.includes('invoice'))return'🧾';
  return'•';
}
function activityVerb(action){
  const a=key(action);
  if(a.includes('insert')||a.includes('create'))return'Created';
  if(a.includes('update')||a.includes('edit'))return'Updated';
  if(a.includes('delete'))return'Deleted';
  if(a.includes('approve'))return'Approved';
  if(a.includes('reject'))return'Rejected';
  if(a.includes('close'))return'Closed';
  return pretty(action||'Activity');
}
function activityTime(value){
  if(!value)return'';
  const d=new Date(value);if(Number.isNaN(d.getTime()))return clean(value);
  const today=new Date();
  const same=today.getFullYear()===d.getFullYear()&&today.getMonth()===d.getMonth()&&today.getDate()===d.getDate();
  return same?d.toLocaleTimeString([], {hour:'2-digit',minute:'2-digit'}):d.toLocaleDateString([], {day:'2-digit',month:'short'});
}
function renderRecentActivity(){
  const host=$('recentList');if(!host)return;
  const label=$('activityLabel');
  const rows=Array.isArray(activityData?.rows)?activityData.rows:[];
  if(label){
    const name=clean(activityData?.userName||profile?.staff?.staffName||profile?.user?.email||'');
    label.textContent=name?'Your activity · '+name:'Your activity';
  }
  if(!rows.length){host.innerHTML='<div class="menu-empty">No recent activity found for your account yet.</div>';return}
  host.innerHTML=rows.slice(0,8).map(row=>{
    const entity=pretty(row.entityType||row.moduleKey||'Activity');
    const title=activityVerb(row.action)+' '+entity;
    const detail=clean(row.entityId)||clean(row.summary)||'Activity recorded';
    const module=pretty(row.moduleKey||'System');
    return `<div class="recent-row"><div class="recent-icon">${activityIcon(row.action,row.moduleKey)}</div><div class="recent-main"><strong>${esc(title)}</strong><span>${esc(detail)}</span></div><div class="recent-side"><strong>${esc(activityTime(row.createdAt))}</strong><span>${esc(module)}</span></div></div>`;
  }).join('');
}
async function refreshRecentActivity(force=false){
  const now=Date.now();
  if(!force&&now-lastActivityFetch<10000)return;
  lastActivityFetch=now;
  const next=await safeRpc('bb_mobile_my_activity',{p_limit:12});
  if(next?.success)activityData=next;
  renderRecentActivity();
}

function renderHome(){
  if($('mobileHome')?.hidden)return;
  injectCss();ensureHiddenStaffMeta();installQuickControls();installPicker();
  renderStaffKpis();renderQuick();renderRecentActivity();renderNav('home');
}

function watchNavReplacement(){
  ['bottomNav','menuBottomNav','moduleBottomNav'].forEach(id=>{
    const host=$(id);if(!host||host.dataset.bbUnifiedWatch)return;host.dataset.bbUnifiedWatch='1';
    new MutationObserver(()=>{
      if(!host.querySelector('[data-bb-nav]')&&!host.querySelector('[data-bb-page]'))setTimeout(()=>renderNav(currentNavState()),0);
    }).observe(host,{childList:true});
  });
}

async function load(){
  profile=await rpc('bb_current_access_profile');
  const [prefs,staffOverview,staffPayment,myActivity]=await Promise.all([
    safeRpc('bb_mobile_get_preferences'),
    isAdmin()?null:safeRpc('bb_mobile_user_overview'),
    canRoute('staff-relation')?safeRpc('bb_staff_relation_my_payments',{p_from:null,p_to:null,p_salary_month:null}):null,
    safeRpc('bb_mobile_my_activity',{p_limit:12})
  ]);
  overview=staffOverview;payment=staffPayment;activityData=myActivity?.success?myActivity:null;lastActivityFetch=Date.now();
  if(prefs?.updatedAt){quick=normalizeQuick(prefs.quickActionOrder);pages=normalizePages(prefs.pinnedPages)}
  else{quick=normalizeQuick(readLocal(quickKey()));pages=normalizePages(readLocal(pageKey()))}
  writeLocal(quickKey(),quick);writeLocal(pageKey(),pages);

  renderHome();renderNav(currentNavState());watchNavReplacement();

  new MutationObserver(()=>{if(!$('mobileHome')?.hidden){renderHome();refreshRecentActivity(false)}}).observe($('mobileHome'),{attributes:true,attributeFilter:['hidden']});
  new MutationObserver(()=>{if(!$('menuScreen')?.hidden){renderMainMenu();renderNav('menu')}}).observe($('menuScreen'),{attributes:true,attributeFilter:['hidden']});

  document.addEventListener('click',event=>{
    if(event.target?.closest?.('#menuBack')){event.preventDefault();event.stopImmediatePropagation();showHome()}
    if(event.target?.closest?.('#moduleBack')&&fallbackRoute){event.preventDefault();event.stopImmediatePropagation();if($('moduleFrame'))$('moduleFrame').src='about:blank';showHome()}
  },true);

  setInterval(()=>{
    const local=normalizeQuick(readLocal(quickKey()));
    if(JSON.stringify(local)!==JSON.stringify(quick)){quick=local;saveQuick();renderQuick()}
  },900);
}

function start(){
  const wait=()=>{
    if(!$('mobileHome'))return setTimeout(wait,100);
    if(!readSession()?.access_token)return setTimeout(wait,500);
    load().catch(error=>console.warn('Unified mobile home:',error));
  };
  wait();
}

if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
})();