/* BIG BROTHER — Unified Mobile Home V3.5
   Locked Home KPIs. User-selected Quick Actions.
   Bottom nav: Home | User Page 1 | User Page 2 | Menu.
   Home attention: Receivable Alert | Stock Alert | Pending Requests.
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
sales-support-batch-selling-tracker|Sales Support|🔎|Batch Selling Tracker
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
  'sales-support-batch-selling-tracker':'big-brother-batch-selling-tracker/mobile.html?embed=1&v=20260925-dashboard1',
  'sales-support-your-collection':'big-brother-daily-cash-collection/your-collection-mobile.html?embed=1&v=20260921-owner1',
  'sales-support-your-invoices':'invoice-history/your-invoices-mobile.html?embed=1&v=20260925-assigned2',
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
let overviewLoading=false;
let overviewFilter={locationCode:'',year:0,month:0};
let preferenceSyncBusy=false;
let preferenceWriteCount=0;
let preferenceUpdatedAt='';
let preferenceSyncTimer=null;
let payment=null;
let stockReport=null;
let attention=null;
let lastAttentionFetch=0;
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
function authAccountId(){
  const s=readSession();
  const direct=clean(s?.user?.id);
  if(direct)return direct;

  /* Fallback only for local preference namespacing. Authorization still
     comes from the server-side access profile / RPCs. */
  try{
    const token=clean(s?.access_token);
    const part=token.split('.')[1];
    if(part){
      const base=part.replace(/-/g,'+').replace(/_/g,'/');
      const padded=base+'='.repeat((4-base.length%4)%4);
      const payload=JSON.parse(atob(padded));
      const sub=clean(payload?.sub);
      if(sub)return sub;
    }
  }catch(_){}

  return clean(profile?.user?.userId||profile?.user?.email||profile?.staff?.staffId||profile?.user?.staffId||'user');
}
function userId(){return authAccountId()}
function quickKey(){return 'bb_mobile_quick_order_v3::'+userId()}
function pageKey(){return 'bb_mobile_pinned_pages_v2::'+userId()}
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

    #periodLabel.bb-overview-period{display:inline-flex;align-items:center;gap:4px;padding:5px 8px;border:1px solid #b9d2e8;border-radius:999px;background:rgba(255,255,255,.58);color:#285f91!important;font-weight:900!important;cursor:pointer;user-select:none;-webkit-user-select:none}
    #periodLabel.bb-overview-period:active{transform:scale(.98)}
    #kpiGrid [data-overview-location]{cursor:pointer}
    #kpiGrid [data-overview-location]:active{transform:scale(.985)}
    .bb-overview-loading{opacity:.58;pointer-events:none}

    #kpiGrid{gap:7px!important}
    #kpiGrid .sales-kpi{grid-template-columns:34px minmax(0,1fr) 23px!important;min-height:78px!important;padding:8px!important;column-gap:7px!important;border-radius:13px!important}
    #kpiGrid .sales-kpi .kpi-icon{width:34px!important;height:34px!important;border-radius:10px!important;font-size:17px!important}
    #kpiGrid .sales-kpi small{font-size:8.6px!important}
    #kpiGrid .sales-kpi strong{font-size:16px!important}
    #kpiGrid .sales-kpi em{font-size:7.4px!important;margin-top:4px!important}
    #kpiGrid .sales-kpi .kpi-arrow{width:23px!important;height:23px!important;font-size:14px!important}

    #quickActions{gap:9px 5px!important}
    #quickActions .quick-btn{min-height:68px!important;padding:5px 2px!important;border-radius:12px!important}
    #quickActions .quick-icon{width:44px!important;height:44px!important;border-radius:13px!important;font-size:21px!important;margin-bottom:5px!important}
    #quickActions .quick-btn>span{font-size:9px!important;line-height:1.1!important}
    #quickActions .menu-empty{grid-column:1/-1;padding:12px 8px!important;text-align:center!important}

    #recentList .bb-att-row{width:100%;font-family:inherit;border:0;text-align:left;cursor:default}
    #recentList button.bb-att-row{cursor:pointer}
    #recentList .bb-att-row+.bb-att-row{margin-top:6px}
    #recentList .bb-att-row .recent-side strong{font-size:15px!important}
    #recentList .bb-att-row.bb-clear .recent-icon{filter:grayscale(.15)}

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


    /* =====================================================
       PREMIUM LIGHT HOME — COLOR POLISH V1
       Layout stays unchanged. Color follows meaning/function.
       ===================================================== */

    /* Slightly richer Home header / panels */
    #mobileHome .hero{
      position:relative!important;
      padding-bottom:42px!important;
      background:
        radial-gradient(circle at 92% 0%,rgba(255,255,255,.20) 0,transparent 31%),
        linear-gradient(150deg,#dbeafb 0%,#c9e1f6 58%,#bed9f0 100%)!important;
      color:#173f77!important;
      border-bottom:1px solid #a9cce8!important;
      box-shadow:0 8px 24px rgba(37,105,168,.11)!important;
    }

    #mobileHome .hero .brand,
    #mobileHome .hero .greeting-name{
      color:#173f77!important;
    }

    #mobileHome .hero .brand-sub,
    #mobileHome .hero .greeting-small{
      color:#527899!important;
    }

    #mobileHome .hero .hero-chip{
      background:rgba(255,255,255,.48)!important;
      color:#1c5f9b!important;
      border:1px solid rgba(137,181,220,.68)!important;
      box-shadow:0 2px 8px rgba(37,105,168,.045)!important;
      backdrop-filter:blur(7px);
      -webkit-backdrop-filter:blur(7px);
    }

    #mobileHome .hero .icon-btn{
      background:rgba(255,255,255,.52)!important;
      color:#1c5f9b!important;
      border:1px solid rgba(137,181,220,.68)!important;
      box-shadow:0 2px 8px rgba(37,105,168,.045)!important;
    }

    #mobileHome .bb-header-quote{
      position:absolute!important;
      right:16px!important;
      bottom:11px!important;
      max-width:72%!important;
      color:#2a6596!important;
      font-size:9px!important;
      line-height:1.2!important;
      font-style:italic!important;
      font-weight:700!important;
      letter-spacing:.15px!important;
      text-align:right!important;
      white-space:nowrap!important;
      opacity:.88!important;
      pointer-events:none!important;
    }


    /* =====================================================
       HOME SPACING + ROUNDED DIVIDER POLISH
       ===================================================== */
    #mobileHome .content{
      padding-top:12px!important;
    }

    #mobileHome .content > .panel{
      position:relative!important;
      margin-bottom:13px!important;
      border-radius:17px!important;
    }

    #mobileHome .overview-panel,
    #mobileHome .quick-panel,
    #mobileHome .bb-attention-panel{
      padding:10px!important;
    }

    #mobileHome .overview-panel::after,
    #mobileHome .quick-panel::after,
    #mobileHome .bb-attention-panel::after{
      content:""!important;
      position:absolute!important;
      left:50%!important;
      bottom:-8px!important;
      width:42px!important;
      height:4px!important;
      transform:translateX(-50%)!important;
      border-radius:999px!important;
      background:#98bfdf!important;
      box-shadow:0 1px 4px rgba(37,105,168,.08)!important;
      opacity:.62!important;
      pointer-events:none!important;
    }

    #mobileHome .overview-panel .section-head,
    #mobileHome .quick-panel .section-head,
    #mobileHome .bb-attention-panel .section-head{
      margin-bottom:8px!important;
    }

    #mobileHome .overview-panel{
      background:linear-gradient(150deg,#dbeafb 0%,#c9e1f6 58%,#bed9f0 100%)!important;
      border-color:#a9cce8!important;
      box-shadow:0 7px 20px rgba(37,105,168,.09)!important;
    }

    #mobileHome .overview-panel .section-head strong{
      color:#173f77!important;
    }

    #mobileHome .overview-panel .section-head span{
      color:#587a98!important;
    }

    #mobileHome .quick-panel{
      background:linear-gradient(150deg,#d9ebfb 0%,#c9e1f6 58%,#bdd9f1 100%)!important;
      border-color:#a9cce8!important;
      box-shadow:0 7px 20px rgba(37,105,168,.10)!important;
    }

    #mobileHome .section-head strong{
      color:#163a60!important;
    }

    /* KPI cards: Sales blue · Receivable amber · Stock green · Earning rose */
    #mobileHome #kpiGrid .sales-kpi{
      border:1px solid transparent!important;
      box-shadow:0 6px 16px rgba(31,72,110,.055)!important;
      overflow:hidden!important;
    }

    #mobileHome #kpiGrid .sales-kpi:nth-child(1){
      background:linear-gradient(145deg,#eef7ff,#dceeff)!important;
      border-color:#c5dff6!important;
      box-shadow:inset 3px 0 0 #2f80ed,0 6px 16px rgba(47,128,237,.07)!important;
    }
    #mobileHome #kpiGrid .sales-kpi:nth-child(1) .kpi-icon{
      background:#dceeff!important;
      color:#166dca!important;
    }
    #mobileHome #kpiGrid .sales-kpi:nth-child(1) .kpi-arrow{
      background:#e5f2ff!important;
      color:#2478cb!important;
    }

    #mobileHome #kpiGrid .sales-kpi:nth-child(2){
      background:linear-gradient(145deg,#fff8e9,#ffeac2)!important;
      border-color:#f0d8a4!important;
      box-shadow:inset 3px 0 0 #e4a326,0 6px 16px rgba(216,154,23,.07)!important;
    }
    #mobileHome #kpiGrid .sales-kpi:nth-child(2) .kpi-icon{
      background:#ffebbd!important;
      color:#a96e00!important;
    }
    #mobileHome #kpiGrid .sales-kpi:nth-child(2) .kpi-arrow{
      background:#fff0cf!important;
      color:#b0780c!important;
    }

    #mobileHome #kpiGrid .sales-kpi:nth-child(3){
      background:linear-gradient(145deg,#edfaf3,#d8f2e5)!important;
      border-color:#bee4d2!important;
      box-shadow:inset 3px 0 0 #27ae60,0 6px 16px rgba(39,174,96,.065)!important;
    }
    #mobileHome #kpiGrid .sales-kpi:nth-child(3) .kpi-icon{
      background:#d9f3e6!important;
      color:#16834b!important;
    }
    #mobileHome #kpiGrid .sales-kpi:nth-child(3) .kpi-arrow{
      background:#e0f6eb!important;
      color:#208d53!important;
    }

    #mobileHome #kpiGrid .sales-kpi:nth-child(4){
      background:linear-gradient(145deg,#fff1f3,#fbdde3)!important;
      border-color:#f0cbd1!important;
      box-shadow:inset 3px 0 0 #e45f70,0 6px 16px rgba(228,95,112,.065)!important;
    }
    #mobileHome #kpiGrid .sales-kpi:nth-child(4) .kpi-icon{
      background:#f9dfe4!important;
      color:#c84558!important;
    }
    #mobileHome #kpiGrid .sales-kpi:nth-child(4) .kpi-arrow{
      background:#fbe7ea!important;
      color:#cf5262!important;
    }

    #mobileHome #kpiGrid .sales-kpi strong{
      color:#173d63!important;
    }

    /* Quick Actions: route colors stay with the function after rearranging */
    #mobileHome #quickActions .quick-btn{
      background:transparent!important;
    }

    #mobileHome #quickActions .quick-icon{
      border:1px solid transparent!important;
      box-shadow:0 4px 12px rgba(29,68,105,.07)!important;
    }

    #mobileHome #quickActions [data-sales-route="sales-support-calculator"] .quick-icon{
      background:linear-gradient(145deg,#e8f3ff,#d5eaff)!important;
      border-color:#bddaf4!important;
    }

    #mobileHome #quickActions [data-sales-route="sales-support-add-customer"] .quick-icon,
    #mobileHome #quickActions [data-sales-route="customers-add"] .quick-icon{
      background:linear-gradient(145deg,#e9f9f1,#d7f2e5)!important;
      border-color:#bfe3d1!important;
    }

    #mobileHome #quickActions [data-sales-route="sales-support-customer-map"] .quick-icon,
    #mobileHome #quickActions [data-sales-route="customers-map"] .quick-icon{
      background:linear-gradient(145deg,#fff1ed,#ffe1da)!important;
      border-color:#f1c9bf!important;
    }

    #mobileHome #quickActions [data-sales-route="sales-support-your-collection"] .quick-icon,
    #mobileHome #quickActions [data-sales-route="daily-cash-collection"] .quick-icon{
      background:linear-gradient(145deg,#fff8e8,#ffedc5)!important;
      border-color:#ecd59d!important;
    }

    #mobileHome #quickActions [data-sales-route="sales-support-your-customer"] .quick-icon,
    #mobileHome #quickActions [data-sales-route="customers-details"] .quick-icon{
      background:linear-gradient(145deg,#e8fbfb,#d7f1f2)!important;
      border-color:#b9dddf!important;
    }

    #mobileHome #quickActions [data-sales-route="sales-support-your-invoices"] .quick-icon,
    #mobileHome #quickActions [data-sales-route="invoice"] .quick-icon,
    #mobileHome #quickActions [data-sales-route="history"] .quick-icon{
      background:linear-gradient(145deg,#f2edff,#e5dcff)!important;
      border-color:#d4c7f1!important;
    }

    #mobileHome #quickActions [data-sales-route="sales-support-your-stock"] .quick-icon,
    #mobileHome #quickActions [data-sales-route="stock-report"] .quick-icon{
      background:linear-gradient(145deg,#ecf9ef,#dcf2e3)!important;
      border-color:#c1dfca!important;
    }

    #mobileHome #quickActions [data-sales-route="sales-support-your-receivable"] .quick-icon,
    #mobileHome #quickActions [data-sales-route="ar-your"] .quick-icon{
      background:linear-gradient(145deg,#fff7e7,#ffe9bd)!important;
      border-color:#edd39b!important;
    }

    #mobileHome #quickActions [data-sales-route*="delivery"] .quick-icon{
      background:linear-gradient(145deg,#e9f6ff,#d8ecfb)!important;
      border-color:#bfdbea!important;
    }

    #mobileHome #quickActions [data-sales-route="staff-relation"] .quick-icon{
      background:linear-gradient(145deg,#f3efff,#e6defa)!important;
      border-color:#d4c7ec!important;
    }


    /* Needs Your Attention — Premium Blue section */
    #mobileHome .bb-attention-panel{
      background:linear-gradient(150deg,#dbeafb 0%,#c9e1f6 58%,#bed9f0 100%)!important;
      border:1px solid #a9cce8!important;
      box-shadow:0 7px 20px rgba(37,105,168,.09)!important;
    }

    #mobileHome .bb-attention-panel .section-head strong{
      color:#173f77!important;
    }

    #mobileHome .bb-attention-panel .section-head span{
      color:#587a98!important;
    }

    /* Attention rows: color communicates status without making the page loud */
    #mobileHome #recentList .bb-att-row{
      border:1px solid transparent!important;
      border-radius:12px!important;
      padding:9px 8px!important;
      transition:none!important;
    }

    #mobileHome #recentList .bb-att-row[data-att-type="receivable"]{
      background:#fff4dc!important;
      border-color:#f0dfb6!important;
      box-shadow:inset 3px 0 0 #e4a326!important;
    }
    #mobileHome #recentList .bb-att-row[data-att-type="receivable"] .recent-icon{
      background:#ffedc3!important;
    }
    #mobileHome #recentList .bb-att-row[data-att-type="receivable"] .recent-side strong{
      color:#b67a0d!important;
    }

    #mobileHome #recentList .bb-att-row[data-att-type="stock"]:not(.bb-clear){
      background:#fff1f2!important;
      border-color:#efccd1!important;
      box-shadow:inset 3px 0 0 #dc5b6b!important;
    }
    #mobileHome #recentList .bb-att-row[data-att-type="stock"]:not(.bb-clear) .recent-icon{
      background:#f9dfe3!important;
    }
    #mobileHome #recentList .bb-att-row[data-att-type="stock"]:not(.bb-clear) .recent-side strong{
      color:#c74859!important;
    }

    #mobileHome #recentList .bb-att-row[data-att-type="stock"].bb-clear{
      background:#e8f8f0!important;
      border-color:#cbe7d9!important;
      box-shadow:inset 3px 0 0 #27ae60!important;
    }
    #mobileHome #recentList .bb-att-row[data-att-type="stock"].bb-clear .recent-icon{
      background:#dbf3e7!important;
    }
    #mobileHome #recentList .bb-att-row[data-att-type="stock"].bb-clear .recent-side strong{
      color:#19864d!important;
    }

    #mobileHome #recentList .bb-att-row[data-att-type="pending"]:not(.bb-clear){
      background:#fff5e9!important;
      border-color:#f0d4ad!important;
      box-shadow:inset 3px 0 0 #e6912d!important;
    }
    #mobileHome #recentList .bb-att-row[data-att-type="pending"]:not(.bb-clear) .recent-icon{
      background:#ffe8c8!important;
    }
    #mobileHome #recentList .bb-att-row[data-att-type="pending"]:not(.bb-clear) .recent-side strong{
      color:#b96b10!important;
    }

    #mobileHome #recentList .bb-att-row[data-att-type="pending"].bb-clear{
      background:#eaf4fc!important;
      border-color:#d4e4f1!important;
      box-shadow:inset 3px 0 0 #67a5d8!important;
    }
    #mobileHome #recentList .bb-att-row[data-att-type="pending"].bb-clear .recent-icon{
      background:#e4f0fa!important;
    }

    /* Stronger but still soft active bottom nav */
    .bottom-nav .nav-btn.active{
      background:linear-gradient(145deg,#d8ebff,#c9e2ff)!important;
      color:#126fd0!important;
      box-shadow:inset 0 0 0 1px #c4dcf2,0 3px 10px rgba(22,119,255,.07)!important;
    }
    .bottom-nav .nav-btn.active b{
      color:#126fd0!important;
    }

    /* Add / Arrange controls join the blue identity */
    #bbQuickAddButton,
    #bbQuickArrangeBtn{
      background:#edf6ff!important;
      color:#176db8!important;
      border-color:#c5daec!important;
    }

    #bbQuickArrangeBtn.active{
      background:#1677ff!important;
      color:#fff!important;
      border-color:#1677ff!important;
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
  pickerMode=mode;pickerSlot=slot;installPicker();
  $('bbPickerTitle').textContent=mode==='quick'?'Quick Actions':'Choose Bottom Page '+(slot+1);
  $('bbPickerSearch').value='';
  $('bbPickerRemove').hidden=!(mode==='page'&&pages[slot]);
  $('bbFunctionPicker').hidden=false;renderPicker();
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
async function saveQuick(){
  quick=normalizeQuick(quick);
  writeLocal(quickKey(),quick);
  preferenceWriteCount+=1;
  try{
    const saved=await safeRpc('bb_mobile_save_quick_action_order',{p_order:quick});
    if(saved?.updatedAt)preferenceUpdatedAt=clean(saved.updatedAt);
  }finally{
    preferenceWriteCount=Math.max(0,preferenceWriteCount-1);
  }
}
async function savePages(){
  pages=normalizePages(pages);
  writeLocal(pageKey(),pages);
  preferenceWriteCount+=1;
  try{
    const saved=await safeRpc('bb_mobile_save_pinned_pages',{p_pages:pages});
    if(saved?.updatedAt)preferenceUpdatedAt=clean(saved.updatedAt);
  }finally{
    preferenceWriteCount=Math.max(0,preferenceWriteCount-1);
  }
}

function sameArray(a,b){return JSON.stringify(a)===JSON.stringify(b)}
async function syncPreferencesFromServer(force=false){
  if(preferenceSyncBusy||preferenceWriteCount>0||!profile)return;
  if(!force&&document.visibilityState==='hidden')return;

  /*
   * If another controller on THIS device has just reordered a Quick Action
   * through localStorage, let the local watcher push it first. This prevents
   * a server pull from overwriting an unsaved local drag/drop.
   */
  const localQuick=normalizeQuick(readLocal(quickKey()));
  const localPages=normalizePages(readLocal(pageKey()));
  if(!sameArray(localQuick,quick)||!sameArray(localPages,pages))return;

  preferenceSyncBusy=true;
  try{
    const prefs=await safeRpc('bb_mobile_get_preferences');
    if(!prefs?.success)return;

    const serverQuick=normalizeQuick(prefs.quickActionOrder);
    const serverPages=normalizePages(prefs.pinnedPages);
    const quickChanged=!sameArray(serverQuick,quick);
    const pagesChanged=!sameArray(serverPages,pages);

    if(quickChanged){
      quick=serverQuick;
      writeLocal(quickKey(),quick);
      renderQuick();
      if(pickerMode==='quick'&&!$('bbFunctionPicker')?.hidden)renderPicker();
    }

    if(pagesChanged){
      pages=serverPages;
      writeLocal(pageKey(),pages);
      renderNav(currentNavState());
    }

    if(prefs.updatedAt)preferenceUpdatedAt=clean(prefs.updatedAt);
  }finally{
    preferenceSyncBusy=false;
  }
}
function installPreferenceSync(){
  if(preferenceSyncTimer)return;

  /*
   * Quick Actions are account preferences, not device preferences.
   * Pull the same Supabase preference row every few seconds so Device B
   * follows changes made on Device A without requiring logout or refresh.
   */
  preferenceSyncTimer=setInterval(()=>syncPreferencesFromServer(false),4000);

  window.addEventListener('focus',()=>syncPreferencesFromServer(true));
  document.addEventListener('visibilitychange',()=>{
    if(document.visibilityState==='visible')syncPreferencesFromServer(true);
  });
}

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

/*
 * Single owner for Home Quick Actions.
 * mobile.js delegates here whenever it refreshes the Admin overview.
 */
window.BBMobileQuickActionsV1={
  render:renderQuick
};

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
      setTimeout(()=>{renderHome();renderNav('home');refreshAttention(true)},0);
      return;
    }
  }catch(_){ }
  if($('mobileHome'))$('mobileHome').hidden=false;
  if($('menuScreen'))$('menuScreen').hidden=true;
  if($('moduleScreen'))$('moduleScreen').hidden=true;
  renderHome();renderNav('home');refreshAttention(true);
}
function showMainMenu(){
  currentRoute='';fallbackRoute='';closePicker();
  if($('mobileHome'))$('mobileHome').hidden=true;
  if($('moduleScreen'))$('moduleScreen').hidden=true;
  if($('menuScreen'))$('menuScreen').hidden=false;
  try{
    const nav=window.BBMobileHistoryV7||window.BBMobileHistoryV6;
    if(nav&&!nav.isRestoring?.())nav.recordMenu('',true);
    else{const u=new URL(location.href);u.searchParams.delete('module');u.searchParams.delete('autoload');history.replaceState(history.state||{},'',u.pathname+u.search+u.hash)}
  }catch(_){ }
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
  if($('mobileHome'))$('mobileHome').hidden=true;
  if($('menuScreen'))$('menuScreen').hidden=true;
  if($('moduleScreen'))$('moduleScreen').hidden=false;
  if($('moduleTitle'))$('moduleTitle').textContent=item.label;
  if($('moduleFrame'))replaceFrameUrl($('moduleFrame'),item.url);
  try{
    const nav=window.BBMobileHistoryV7||window.BBMobileHistoryV6;
    if(nav&&!nav.isRestoring?.())nav.recordModule(route,true);
    else{const u=new URL(location.href);u.searchParams.set('module',route);u.searchParams.set('autoload','1');history.replaceState(history.state||{},'',u.pathname+u.search+u.hash)}
  }catch(_){ }
  renderNav(navState||currentNavState());
}

function overviewFilterKey(){return 'bb_mobile_overview_filter_v1::'+userId()}
function defaultOverviewFilter(){
  const d=new Date();
  return{locationCode:'',year:d.getFullYear(),month:d.getMonth()+1};
}
function loadOverviewFilter(){
  const fallback=defaultOverviewFilter();
  let saved=null;
  try{saved=JSON.parse(localStorage.getItem(overviewFilterKey())||'null')}catch(_){}
  const year=Number(saved?.year);
  const month=Number(saved?.month);
  const allowed=new Set((Array.isArray(profile?.locations)?profile.locations:[]).map(x=>key(x.locationCode)));
  const locationCode=allowed.has(key(saved?.locationCode))?clean(saved.locationCode):'';
  return{
    locationCode,
    year:Number.isInteger(year)&&year>=2000&&year<=2100?year:fallback.year,
    month:Number.isInteger(month)&&month>=1&&month<=12?month:fallback.month
  };
}
function saveOverviewFilter(){
  try{localStorage.setItem(overviewFilterKey(),JSON.stringify(overviewFilter))}catch(_){}
}
function overviewArgs(){
  return{
    p_year:Number(overviewFilter.year),
    p_month:Number(overviewFilter.month),
    p_location_code:clean(overviewFilter.locationCode)||null
  };
}
function monthOptionRows(){
  const rows=[];
  const now=new Date();
  for(let offset=0;offset<36;offset++){
    const d=new Date(now.getFullYear(),now.getMonth()-offset,1);
    rows.push({
      value:d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0'),
      label:d.toLocaleDateString(undefined,{month:'long',year:'numeric'})
    });
  }
  return rows;
}
function selectedSaleLocation(){
  const code=clean(overviewFilter.locationCode);
  if(!code)return null;
  return (Array.isArray(profile?.locations)?profile.locations:[]).find(x=>key(x.locationCode)===key(code))||null;
}
function selectedSaleLocationLabel(){
  const loc=selectedSaleLocation();
  return loc?clean(loc.locationName||loc.locationCode):'All Assigned Locations';
}
function ensureOverviewPicker(){
  let picker=$('bbOverviewPicker');
  if(picker)return picker;

  picker=document.createElement('div');
  picker.id='bbOverviewPicker';
  picker.className='bb-picker';
  picker.hidden=true;
  picker.innerHTML=
    '<div class="bb-picker-box">'+
      '<div class="bb-picker-head"><div><b id="bbOverviewPickerTitle">Select</b><small id="bbOverviewPickerSub" style="display:block;margin-top:2px;color:#718197;font-size:8px"></small></div><button type="button" id="bbOverviewPickerClose">×</button></div>'+
      '<div id="bbOverviewPickerList" class="bb-picker-list" style="margin-top:9px"></div>'+
    '</div>';
  document.body.appendChild(picker);

  $('bbOverviewPickerClose').onclick=()=>picker.hidden=true;
  picker.addEventListener('click',event=>{if(event.target===picker)picker.hidden=true});
  return picker;
}
function openOverviewLocationPicker(){
  const picker=ensureOverviewPicker();
  const list=$('bbOverviewPickerList');
  const title=$('bbOverviewPickerTitle');
  const sub=$('bbOverviewPickerSub');
  if(title)title.textContent='Sale Location';
  if(sub)sub.textContent='Monthly Sales · assigned locations only';

  const locations=Array.isArray(profile?.locations)?profile.locations:[];
  const rows=[
    {locationCode:'',locationName:'All Assigned Locations'},
    ...locations
  ];

  list.innerHTML=rows.map(loc=>{
    const code=clean(loc.locationCode);
    const selected=key(code)===key(overviewFilter.locationCode);
    const name=clean(loc.locationName||loc.locationCode||'All Assigned Locations');
    const note=code?code:'All locations assigned to your account';
    return '<button type="button" class="bb-picker-row '+(selected?'selected':'')+'" data-overview-location-value="'+esc(code)+'">'+
      '<span class="bb-picker-icon">📍</span>'+
      '<span><b>'+esc(name)+'</b><small>'+esc(note)+'</small></span>'+
      '<span class="bb-picker-state">'+(selected?'Selected':'Select')+'</span>'+
    '</button>';
  }).join('');

  list.querySelectorAll('[data-overview-location-value]').forEach(button=>{
    button.onclick=()=>{
      overviewFilter.locationCode=clean(button.dataset.overviewLocationValue);
      saveOverviewFilter();
      picker.hidden=true;
      refreshOverview(true);
    };
  });

  picker.hidden=false;
}
function openOverviewMonthPicker(){
  const picker=ensureOverviewPicker();
  const list=$('bbOverviewPickerList');
  const title=$('bbOverviewPickerTitle');
  const sub=$('bbOverviewPickerSub');
  if(title)title.textContent='Select Month';
  if(sub)sub.textContent='Monthly Sales period';

  const selected=Number(overviewFilter.year)+'-'+String(Number(overviewFilter.month)).padStart(2,'0');
  list.innerHTML=monthOptionRows().map(row=>{
    const active=row.value===selected;
    return '<button type="button" class="bb-picker-row '+(active?'selected':'')+'" data-overview-month-value="'+esc(row.value)+'">'+
      '<span class="bb-picker-icon">🗓️</span>'+
      '<span><b>'+esc(row.label)+'</b><small>Monthly Sales</small></span>'+
      '<span class="bb-picker-state">'+(active?'Selected':'Select')+'</span>'+
    '</button>';
  }).join('');

  list.querySelectorAll('[data-overview-month-value]').forEach(button=>{
    button.onclick=()=>{
      const parts=clean(button.dataset.overviewMonthValue).split('-');
      const year=Number(parts[0]);
      const month=Number(parts[1]);
      if(Number.isInteger(year)&&Number.isInteger(month)&&month>=1&&month<=12){
        overviewFilter.year=year;
        overviewFilter.month=month;
        saveOverviewFilter();
        picker.hidden=true;
        refreshOverview(true);
      }
    };
  });

  picker.hidden=false;
}
function ensureOverviewHeader(){
  const title=$('overviewTitle');
  if(title){
    title.textContent='Overview';
    title.style.fontSize='';
  }

  // Remove the old always-visible selectors if an earlier cached script created them.
  const oldFilters=$('bbOverviewFilters');
  if(oldFilters)oldFilters.remove();

  const period=$('periodLabel');
  if(period){
    period.classList.add('bb-overview-period');
    period.textContent=(overview?.periodLabel||'Month')+' ▾';
    period.setAttribute('role','button');
    period.setAttribute('tabindex','0');
    period.setAttribute('aria-label','Select overview month');
    period.onclick=openOverviewMonthPicker;
    period.onkeydown=event=>{
      if(event.key==='Enter'||event.key===' '){
        event.preventDefault();
        openOverviewMonthPicker();
      }
    };
  }
}

function renderOverview(){
  ensureOverviewHeader();
  if(!overview||!$('kpiGrid'))return;

  const sales=overview.monthlySales||{};
  const ar=overview.receivable||{};
  const stock=overview.stock||{};
  const available=Array.isArray(payment?.available)?payment.available:[];
  const usd=available.filter(x=>key(x.currency||'USD')==='usd').reduce((sum,x)=>sum+num(x.amount),0);
  const saleLocation=selectedSaleLocation();
  const salesSub=(saleLocation?clean(saleLocation.locationName||saleLocation.locationCode):'All assigned')+' · '+Math.round(num(sales.invoiceCount))+' invoices';

  const card=(icon,label,value,sub,route='',action='')=>{
    const routeClickable=route&&canRoute(route);
    const actionClickable=!!action;
    const clickable=routeClickable||actionClickable;
    const tag=clickable?'button':'div';
    const attrs=routeClickable
      ? `type="button" data-kpi-route="${route}"`
      : actionClickable
        ? `type="button" data-overview-action="${action}"`
        : '';
    return `<${tag} class="sales-kpi ${clickable?'clickable':'locked'}" ${attrs}><span class="kpi-icon">${icon}</span><small>${esc(label)}</small><strong>${esc(value)}</strong><em>${esc(sub)}</em>${clickable?'<span class="kpi-arrow">›</span>':''}</${tag}>`;
  };

  const receivableRoute=canRoute('sales-support-your-receivable')?'sales-support-your-receivable':canRoute('ar-all')?'ar-all':canRoute('ar-your')?'ar-your':'';
  const stockRoute=isAdmin()
    ? (canRoute('stock-report')?'stock-report':'')
    : (canRoute('sales-support-your-stock')?'sales-support-your-stock':canRoute('stock-report')?'stock-report':'');

  if(isAdmin()){
    $('kpiGrid').innerHTML=
      card('📊','Monthly Sales',money(sales.netUSD),salesSub,'','location')+
      card('💰','Receivable',money(ar.equivalentUSD),Math.round(num(ar.count))+' open',receivableRoute)+
      card(
        '📦',
        'Stock Value',
        money(stockReport?.totals?.warehouseValue ?? stock.valueUSD),
        'Warehouse · '+qty(stockReport?.totals?.warehousePhysicalQty ?? stock.physicalQty)+' qty',
        stockRoute
      )+
      card('⏳','Pending Tasks',String(Math.round(num(overview.pendingStaffRequests))),'Staff requests');
  }else{
    $('kpiGrid').innerHTML=
      card('📊','Monthly Sales',money(sales.netUSD),salesSub,'','location')+
      card('💰','Receivable',money(ar.equivalentUSD),Math.round(num(ar.count))+' open',receivableRoute)+
      card('📦','Stock Qty',qty(stock.physicalQty),Math.round(num(stock.openBatchCount))+' open batches',stockRoute)+
      card('👛','Your Earning',money(usd),available.length+' available',canRoute('staff-relation')?'staff-relation':'');
  }

  $('kpiGrid').querySelectorAll('[data-kpi-route]').forEach(button=>button.onclick=()=>openRoute(button.dataset.kpiRoute));
  $('kpiGrid').querySelectorAll('[data-overview-action="location"]').forEach(button=>button.onclick=openOverviewLocationPicker);
}

async function refreshOverview(force=false){
  if(overviewLoading)return;
  if(!profile)return;

  overviewLoading=true;
  const panel=document.querySelector('#mobileHome .overview-panel');
  if(panel)panel.classList.add('bb-overview-loading');

  try{
    const [next,nextStockReport]=await Promise.all([
      safeRpc('bb_mobile_overview_filtered',overviewArgs()),
      isAdmin()?safeRpc('bb_stock_report_fast'):Promise.resolve(null)
    ]);
    if(nextStockReport?.success)stockReport=nextStockReport;
    if(next?.success){
      overview=next;
      renderOverview();
    }
  }finally{
    overviewLoading=false;
    if(panel)panel.classList.remove('bb-overview-loading');
  }
}

window.BBMobileOverviewV1={
  render:renderOverview,
  refresh:refreshOverview
};

function attentionRoute(type){
  if(type==='receivable'){
    if(canRoute('sales-support-your-receivable'))return'sales-support-your-receivable';
    if(canRoute('ar-your'))return'ar-your';
    if(canRoute('ar-all'))return'ar-all';
  }
  if(type==='stock'){
    if(canRoute('stock-alerts'))return'stock-alerts';
    if(canRoute('sales-support-your-stock'))return'sales-support-your-stock';
    if(canRoute('stock-report'))return'stock-report';
  }
  return'';
}
function renderAttention(){
  const host=$('recentList');if(!host)return;
  const panel=host.closest('.panel');
  if(panel)panel.classList.add('bb-attention-panel');
  const title=panel?.querySelector('.section-head strong');
  const label=$('activityLabel');
  if(title)title.textContent='Needs Your Attention';
  if(label)label.textContent='Receivable · Stock · Requests';

  const ar=attention?.receivable||{};
  const stock=attention?.stock||{};
  const pending=attention?.pendingRequests||{};
  const arRows=Array.isArray(ar.rows)?ar.rows:[];
  const stockRows=Array.isArray(stock.rows)?stock.rows:[];
  const pendingRows=Array.isArray(pending.rows)?pending.rows:[];

  const arCount=Math.round(num(ar.count));
  const stockCount=Math.round(num(stock.count));
  const pendingCount=Math.round(num(pending.count));

  const arFirst=arRows[0]||{};
  const stockFirst=stockRows[0]||{};
  const pendingFirst=pendingRows[0]||{};

  const arSub=arCount
    ? `${clean(arFirst.customerName)||'Customer'} · ${Math.round(num(arFirst.daysOverdue))}d overdue`
    : 'No overdue receivables';
  const stockSub=stockCount
    ? `${clean(stockFirst.productName)||'Stock item'} · ${qty(stockFirst.currentQty)}/${qty(stockFirst.minimumQty)} ${clean(stockFirst.unit)}`
    : 'Stock levels are healthy';
  const pendingSub=pendingCount
    ? `${clean(pendingFirst.type)||'Request'} · ${clean(pendingFirst.status)||'Pending'}`
    : 'No requests waiting for action';

  const row=(type,icon,name,sub,count,side,route='')=>{
    const clickable=!!route;const tag=clickable?'button':'div';
    return `<${tag} ${clickable?'type="button" data-att-route="'+route+'"':''} data-att-type="${type}" class="recent-row bb-att-row ${count?'':'bb-clear'}">
      <div class="recent-icon">${icon}</div>
      <div class="recent-main"><strong>${esc(name)}</strong><span>${esc(sub)}</span></div>
      <div class="recent-side"><strong>${esc(String(count))}</strong><span>${esc(side)}</span></div>
    </${tag}>`;
  };

  host.innerHTML=
    row('receivable','💳','Receivable Alert',arSub,arCount,arCount?money(ar.equivalentUSD)+' overdue':'All clear',attentionRoute('receivable'))+
    row('stock','🚨','Stock Alert',stockSub,stockCount,stockCount?(Math.round(num(stock.criticalCount))+' critical'):'All clear',attentionRoute('stock'))+
    row('pending','⏳','Pending Requests',pendingSub,pendingCount,pendingCount?'waiting':'All clear','');

  host.querySelectorAll('[data-att-route]').forEach(button=>button.onclick=()=>openRoute(button.dataset.attRoute));
}
async function refreshAttention(force=false){
  const now=Date.now();
  if(!force&&now-lastAttentionFetch<10000)return;
  lastAttentionFetch=now;
  const next=await safeRpc('bb_mobile_my_attention');
  if(next?.success)attention=next;
  renderAttention();
}

function ensureHeaderQuote(){
  const hero=document.querySelector('#mobileHome .hero');
  if(!hero)return;
  let quote=hero.querySelector('.bb-header-quote');
  if(!quote){
    quote=document.createElement('div');
    quote.className='bb-header-quote';
    quote.textContent='“Consistency is the only key”';
    hero.appendChild(quote);
  }
}

function renderHome(){
  if($('mobileHome')?.hidden)return;
  injectCss();ensureHiddenStaffMeta();installQuickControls();installPicker();ensureHeaderQuote();
  renderOverview();renderQuick();renderAttention();renderNav('home');
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
  overviewFilter=loadOverviewFilter();

  const [prefs,overviewData,staffPayment,myAttention,stockReportData]=await Promise.all([
    safeRpc('bb_mobile_get_preferences'),
    safeRpc('bb_mobile_overview_filtered',overviewArgs()),
    canRoute('staff-relation')?safeRpc('bb_staff_relation_my_payments',{p_from:null,p_to:null,p_salary_month:null}):null,
    safeRpc('bb_mobile_my_attention'),
    isAdmin()?safeRpc('bb_stock_report_fast'):null
  ]);
  overview=overviewData?.success?overviewData:null;
  payment=staffPayment;
  stockReport=stockReportData?.success?stockReportData:null;
  attention=myAttention?.success?myAttention:null;
  lastAttentionFetch=Date.now();

  if(prefs?.updatedAt){
    quick=normalizeQuick(prefs.quickActionOrder);
    pages=normalizePages(prefs.pinnedPages);
    preferenceUpdatedAt=clean(prefs.updatedAt);
  }else{
    quick=normalizeQuick(readLocal(quickKey()));
    pages=normalizePages(readLocal(pageKey()));
  }
  writeLocal(quickKey(),quick);writeLocal(pageKey(),pages);

  renderHome();renderNav(currentNavState());watchNavReplacement();installPreferenceSync();

  new MutationObserver(()=>{
    if(!$('mobileHome')?.hidden){renderHome();refreshOverview(true);refreshAttention(false)}
  }).observe($('mobileHome'),{attributes:true,attributeFilter:['hidden']});
  new MutationObserver(()=>{
    if(!$('menuScreen')?.hidden){renderMainMenu();renderNav('menu')}
  }).observe($('menuScreen'),{attributes:true,attributeFilter:['hidden']});

  document.addEventListener('click',event=>{
    if(event.target?.closest?.('#menuBack')){event.preventDefault();event.stopImmediatePropagation();showHome()}
    if(event.target?.closest?.('#moduleBack')&&fallbackRoute){
      event.preventDefault();event.stopImmediatePropagation();
      if($('moduleFrame'))$('moduleFrame').src='about:blank';showHome();
    }
  },true);

  setInterval(()=>{
    const local=normalizeQuick(readLocal(quickKey()));
    if(!sameArray(local,quick)){
      quick=local;
      saveQuick();
      renderQuick();
    }
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
