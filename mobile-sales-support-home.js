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
      background:
        radial-gradient(circle at 92% 0%,rgba(45,142,235,.13) 0,transparent 30%),
        linear-gradient(145deg,#fbfdff 0%,#edf6ff 68%,#e5f1fc 100%)!important;
      border-bottom:1px solid #cbdfee!important;
    }

    #mobileHome .overview-panel{
      background:linear-gradient(150deg,#fbfdff,#f5faff)!important;
      border-color:#cddfed!important;
    }

    #mobileHome .quick-panel{
      background:linear-gradient(150deg,#fbfdff,#f7fbff)!important;
      border-color:#d1e1ed!important;
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
      background:linear-gradient(145deg,#f3f9ff,#e7f3ff)!important;
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
      background:linear-gradient(145deg,#fffaf0,#fff2d9)!important;
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
      background:linear-gradient(145deg,#f2fbf7,#e3f6ed)!important;
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
      background:linear-gradient(145deg,#fff6f7,#fde9ec)!important;
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

    /* Attention rows: color communicates status without making the page loud */
    #mobileHome #recentList .bb-att-row{
      border:1px solid transparent!important;
      border-radius:12px!important;
      padding:9px 8px!important;
      transition:none!important;
    }

    #mobileHome #recentList .bb-att-row[data-att-type="receivable"]{
      background:#fff9ec!important;
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
      background:#effaf5!important;
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
      background:#f1f7fd!important;
      border-color:#d4e4f1!important;
      box-shadow:inset 3px 0 0 #67a5d8!important;
    }
    #mobileHome #recentList .bb-att-row[data-att-type="pending"].bb-clear .recent-icon{
      background:#e4f0fa!important;
    }

    /* Stronger but still soft active bottom nav */
    .bottom-nav .nav-btn.active{
      background:linear-gradient(145deg,#e3f0ff,#d7eaff)!important;
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
  if($('mobileHome'))$('mobileHome').hidden=true;
  if($('menuScreen'))$('menuScreen').hidden=true;
  if($('moduleScreen'))$('moduleScreen').hidden=false;
  if($('moduleTitle'))$('moduleTitle').textContent=item.label;
  if($('moduleFrame'))$('moduleFrame').src=item.url;
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

function renderHome(){
  if($('mobileHome')?.hidden)return;
  injectCss();ensureHiddenStaffMeta();installQuickControls();installPicker();
  renderStaffKpis();renderQuick();renderAttention();renderNav('home');
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
  const [prefs,staffOverview,staffPayment,myAttention]=await Promise.all([
    safeRpc('bb_mobile_get_preferences'),
    isAdmin()?null:safeRpc('bb_mobile_user_overview'),
    canRoute('staff-relation')?safeRpc('bb_staff_relation_my_payments',{p_from:null,p_to:null,p_salary_month:null}):null,
    safeRpc('bb_mobile_my_attention')
  ]);
  overview=staffOverview;
  payment=staffPayment;
  attention=myAttention?.success?myAttention:null;
  lastAttentionFetch=Date.now();

  if(prefs?.updatedAt){quick=normalizeQuick(prefs.quickActionOrder);pages=normalizePages(prefs.pinnedPages)}
  else{quick=normalizeQuick(readLocal(quickKey()));pages=normalizePages(readLocal(pageKey()))}
  writeLocal(quickKey(),quick);writeLocal(pageKey(),pages);

  renderHome();renderNav(currentNavState());watchNavReplacement();

  new MutationObserver(()=>{
    if(!$('mobileHome')?.hidden){renderHome();refreshAttention(false)}
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
