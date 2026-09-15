/* BIG BROTHER — Mobile Main Menu + Routing V2
   Mobile dashboard only. Desktop dashboard is not modified. */
(function(){
'use strict';

const SB='https://sjfhlaclgmkwwofzstok.supabase.co';
const KEY='sb_publishable_w762jR65CWwlO30fKQsYOw_6L9grx8S';
const SESSION_KEY='BB_SUPABASE_DEV_SESSION_V1';
const DESKTOP='https://angsokhey11-cloud.github.io/big-brother-dashboard/index.html';
const $=id=>document.getElementById(id);
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));
const key=v=>String(v||'').trim().toLowerCase();

const REQUIRED_ACTION={
  'invoice':'create','sales-support-add-customer':'create','purchase-create':'create','expense-add':'create',
  'customers-add':'create','clients-add':'create','products-add':'create'
};

const ROUTES={
  'sales-support-calculator':['sales-support','🧮','Calculator'],
  'sales-support-request-delivery':['sales-support','🚚','Request Delivery'],
  'sales-support-your-customer':['sales-support','👥','Your Customer'],
  'sales-support-successful-delivery':['sales-support','✅','Successful Delivery'],
  'sales-support-add-customer':['sales-support','👤','Add Customer'],
  'sales-support-customer-map':['sales-support','🗺️','Customer Map'],
  'sales-support-your-stock':['sales-support','📦','Your Stock'],
  'sales-support-your-collection':['sales-support','💵','Your Collection'],
  'sales-support-your-invoices':['sales-support','🧾','Your Invoices'],
  'sales-support-your-receivable':['sales-support','💰','Your Receivable'],

  'invoice':['sales','🧾','Create Invoice'],
  'history':['sales','📚','Invoice History'],
  'sale-return':['sales','↩️','Invoice Reversal'],
  'reversal-history':['sales','📜','Reversal History'],
  'payment-history':['sales','💳','Payment History'],
  'daily-sale-summary':['sales','📊','Daily Sale Summary'],
  'daily-cash-collection':['sales','💵','Daily Cash Collection'],

  'purchase-create':['purchase','🛒','Create Purchase'],
  'purchase-history':['purchase','📚','Purchase History'],
  'purchase-payable':['purchase','💵','Purchase Payable'],
  'purchase-payment-history':['purchase','💳','Purchase Payment History'],

  'expense-add':['expenses','➕','Add Expense'],
  'expense-accrued':['expenses','⏳','Accrued Expenses'],
  'expense-history':['expenses','🧾','Expense History'],
  'expense-monthly-report':['expenses','📊','Monthly Expense Report'],
  'cogs-daily':['expenses','🏷️','Daily COGS Report'],
  'cogs-monthly':['expenses','📦','Monthly COGS Report'],

  'stock-keyin':['stock','📦','Stock Key In / Receiving'],
  'stock-damaged':['stock','⚠️','Damaged Stock'],
  'stock-damaged-report':['stock','📋','Damaged Stock Report'],
  'stock-damaged-cleared':['stock','✅','Cleared Damaged Stock'],
  'stock-damaged-accounting':['stock','🧮','Damaged Stock Accounting'],
  'stock-report':['stock','📋','Stock Report'],
  'batch-report':['stock','🗂️','Batch Report'],
  'closed-batch':['stock','✅','Closed Batch'],
  'stock-transactions':['stock','🔄','Stock Transactions'],
  'stock-alerts':['stock','🚨','Smart Stock Alerts'],

  'ar-all':['receivable','📋','All Receivables'],
  'ar-your':['receivable','💰','Your Receivables'],
  'ar-payment-history':['receivable','🧾','Receivable Payment History'],
  'ar-daily-receivable-cash':['receivable','💵','Daily Receivable Cash Summary'],

  'customers-add':['master','👤','Add Customer'],
  'customers-map':['master','🗺️','Customer Map'],
  'customers-details':['master','👥','Customer Details & Prices'],
  'customer-credit-control':['master','💳','Customer Credit Control'],
  'clients-add':['master','🏢','Add Client'],
  'clients-details':['master','🏭','Client Details & Prices'],
  'products-add':['master','🥛','Add Product'],
  'products-details':['master','📦','Product Details & Price'],
  'master-expense-categories':['master','💸','Expense Categories'],
  'staff-management':['master','👥','Staff Management'],
  'staff-payment-settings':['master','💵','Staff Payment Settings'],
  'company-setup-master':['master','⚙️','Company Setup'],

  'staff-relation':['staff','🤝','Staff Relation'],

  'monthly-sales-report':['reports','📈','Monthly Sales Report'],
  'income-statement-report':['reports','📊','Income Statement (Monthly)'],
  'purchase-order-report':['reports','🧾','Purchase Order Report'],

  'admin-pending-receivable':['admin','💰','Pending Receivable'],
  'admin-pending-daily-cash':['admin','💵','Pending Daily Cash'],
  'admin-pending-deposit':['admin','🏦','Pending Deposit'],
  'admin-deposit-history':['admin','📚','Deposit History'],
  'admin-staff-request':['admin','👥','Staff Requests'],
  'admin-request':['admin','🛠️','Admin Request'],
  'admin-user-permissions':['admin','🔐','User & Permission Manager'],

  'management-control-center':['system','🎛️','Management Control Center'],
  'system-activity':['system','📡','System Activity'],
  'notification-center':['system','🔔','Notification Center']
};

/* Only routes with a purpose-built mobile page belong here.
   Everything else automatically falls back to the PC route. */
const MOBILE_URL={
  'invoice':'https://angsokhey11-cloud.github.io/big-brother-invoice-generator/mobile.html?embed=1&v=20260914-1',
  'history':'https://angsokhey11-cloud.github.io/invoice-history/invoice-history-mobile.html?embed=1&v=20260915-1',
  'sale-return':'https://angsokhey11-cloud.github.io/big-brother-invoice-reversal/mobile.html?embed=1&v=20260915-1',
  'reversal-history':'https://angsokhey11-cloud.github.io/big-brother-invoice-reversal/mobile-history.html?embed=1&v=20260915-1',
  'payment-history':'https://angsokhey11-cloud.github.io/big-brother-payment-history/mobile.html?embed=1&v=20260915-1',
  'daily-sale-summary':'https://angsokhey11-cloud.github.io/big-brother-daily-sale-summary/mobile.html?embed=1&v=20260915-1',
  'daily-cash-collection':'https://angsokhey11-cloud.github.io/big-brother-daily-cash-collection/mobile.html?embed=1&v=20260915-1',

  'sales-support-add-customer':'https://angsokhey11-cloud.github.io/big-brother-sales-support/add-customer-mobile.html?embed=1&v=20260915-1',
  'sales-support-customer-map':'https://angsokhey11-cloud.github.io/big-brother-customers-editor/sales-support-customer-map-mobile.html?embed=1&v=20260915-1',
  'sales-support-your-stock':'https://angsokhey11-cloud.github.io/big-brother-sales-support/your-stock-mobile.html?embed=1&v=20260915-1',
  'sales-support-your-collection':'https://angsokhey11-cloud.github.io/big-brother-daily-cash-collection/your-collection-mobile.html?embed=1&v=20260915-1',
  'sales-support-your-invoices':'https://angsokhey11-cloud.github.io/invoice-history/your-invoices-mobile.html?embed=1&v=20260915-1',
  'sales-support-your-receivable':'https://angsokhey11-cloud.github.io/big-brother-ar/your-receivable-mobile.html?embed=1&v=20260915-1',

  'purchase-create':'https://angsokhey11-cloud.github.io/big-brother-purchase-recorder/mobile.html?embed=1&v=20260915-1',
  'purchase-history':'https://angsokhey11-cloud.github.io/big-brother-puchase-history/mobile.html?embed=1&v=20260915-1',
  'purchase-payable':'https://angsokhey11-cloud.github.io/big-brother-purchase-payable-invoice/mobile.html?embed=1&v=20260915-1',
  'purchase-payment-history':'https://angsokhey11-cloud.github.io/big-brother-purchase-payment-history/mobile.html?embed=1&v=20260915-1',

  'expense-add':'https://angsokhey11-cloud.github.io/big-brother-expenses/mobile.html?embed=1&v=20260915-1',
  'expense-accrued':'https://angsokhey11-cloud.github.io/big-brother-expenses/mobile-accrued.html?embed=1&v=20260915-1',
  'expense-history':'https://angsokhey11-cloud.github.io/big-brother-expenses/mobile-history.html?embed=1&v=20260915-1',
  'expense-monthly-report':'https://angsokhey11-cloud.github.io/big-brother-expenses/mobile-monthly.html?embed=1&v=20260915-1',
  'cogs-daily':'https://angsokhey11-cloud.github.io/big-brother-cogs/mobile-daily.html?embed=1&v=20260915-1',
  'cogs-monthly':'https://angsokhey11-cloud.github.io/big-brother-cogs/mobile-monthly.html?embed=1&v=20260915-1',

  'stock-keyin':'https://angsokhey11-cloud.github.io/big-brother-stock-managemenet/mobile.html?embed=1&v=20260915-1',
  'stock-damaged-report':'https://angsokhey11-cloud.github.io/big-brother-stock-report/damage-stock-report-mobile.html?embed=1&v=20260915-3',
  'stock-damaged-cleared':'https://angsokhey11-cloud.github.io/big-brother-stock-report/damaged-stock-cleared-mobile.html?embed=1&v=20260915-2',
  'stock-damaged-accounting':'https://angsokhey11-cloud.github.io/big-brother-damaged-stock/accounting-mobile.html?embed=1&v=20260915-3',
  'stock-report':'https://angsokhey11-cloud.github.io/big-brother-stock-report/mobile.html?embed=1&v=20260915-1',
  'batch-report':'https://angsokhey11-cloud.github.io/big-brother-stock-report/batch-mobile.html?embed=1&v=20260915-4',
  'closed-batch':'https://angsokhey11-cloud.github.io/big-brother-stock-report/closed-batch-mobile.html?embed=1&v=20260915-1',
  'stock-transactions':'https://angsokhey11-cloud.github.io/big-brother-stock-report/transactions-mobile.html?embed=1&v=20260915-2',
  'stock-alerts':'https://angsokhey11-cloud.github.io/big-brother-admin-work/stock-alerts-mobile.html?embed=1&v=20260915-1',

  'ar-all':'https://angsokhey11-cloud.github.io/big-brother-ar/all-receivable-mobile.html?embed=1&v=20260915-1',
  'ar-your':'https://angsokhey11-cloud.github.io/big-brother-ar/your-receivable-mobile.html?embed=1&v=20260915-1',
  'ar-payment-history':'https://angsokhey11-cloud.github.io/big-brother-payment-history/receivable-mobile.html?embed=1&v=20260915-clean2',

  'staff-relation':'https://angsokhey11-cloud.github.io/big-brother-staff-relation/mobile.html?embed=1&v=20260915-1',
  'monthly-sales-report':'https://angsokhey11-cloud.github.io/big-brother-report/monthly-sales-mobile.html?embed=1&v=20260915-3',
  'income-statement-report':'https://angsokhey11-cloud.github.io/big-brother-report/income-statement-mobile.html?embed=1&v=20260915-3',
  'purchase-order-report':'https://angsokhey11-cloud.github.io/big-brother-report/purchase-order-report-mobile.html?embed=1&v=20260915-1',

  'admin-pending-receivable':'https://angsokhey11-cloud.github.io/big-brother-admin-work/pending-receivable-mobile.html?embed=1&v=20260915-3',
  'admin-pending-daily-cash':'https://angsokhey11-cloud.github.io/big-brother-admin-work/pending-daily-cash-mobile.html?embed=1&v=20260915-1',
  'admin-pending-deposit':'https://angsokhey11-cloud.github.io/big-brother-admin-work/pending-deposit-mobile.html?embed=1&v=20260915-2'
};

const GROUPS=[
  ['sales-support','🧰','Sales Support'],
  ['sales','🧾','Sales'],
  ['purchase','🛒','Purchase'],
  ['expenses','💸','Expenses & COGS'],
  ['stock','📦','Stock'],
  ['receivable','💰','Accounts Receivable'],
  ['master','🗂️','Master Data'],
  ['staff','🤝','Staff Relation'],
  ['reports','📊','Reports'],
  ['admin','🛠️','Admin Work'],
  ['system','⚙️','System']
];

const TAB_GROUPS={
  sales:['sales-support','sales','receivable'],
  stock:['stock'],
  reports:['reports','expenses'],
  more:GROUPS.map(x=>x[0])
};

let session=null,profile=null,lastTab='more',rendering=false;

function readSession(){try{return JSON.parse(localStorage.getItem(SESSION_KEY)||'null')}catch(_){return null}}
async function parse(r){const t=await r.text();let d={};try{d=t?JSON.parse(t):{}}catch(_){d={message:t}}if(!r.ok)throw new Error(d.message||d.error_description||d.error||('Request failed ('+r.status+')'));return d}
async function refresh(){const s=readSession();if(!s?.refresh_token)throw new Error('Please sign in to BIG BROTHER.');const r=await fetch(SB+'/auth/v1/token?grant_type=refresh_token',{method:'POST',headers:{apikey:KEY,'Content-Type':'application/json'},body:JSON.stringify({refresh_token:s.refresh_token}),cache:'no-store'});session=await parse(r);localStorage.setItem(SESSION_KEY,JSON.stringify(session));return session}
async function rpc(fn,args={}){session=readSession();if(!session?.access_token)throw new Error('Please sign in to BIG BROTHER.');if(session.expires_at&&Number(session.expires_at)<Math.floor(Date.now()/1000)+45)await refresh();let r=await fetch(SB+'/rest/v1/rpc/'+fn,{method:'POST',headers:{apikey:KEY,Authorization:'Bearer '+session.access_token,'Content-Type':'application/json'},body:JSON.stringify(args||{}),cache:'no-store'});if(r.status===401){await refresh();r=await fetch(SB+'/rest/v1/rpc/'+fn,{method:'POST',headers:{apikey:KEY,Authorization:'Bearer '+session.access_token,'Content-Type':'application/json'},body:JSON.stringify(args||{}),cache:'no-store'})}return parse(r)}
async function getProfile(force=false){if(profile&&!force)return profile;profile=await rpc('bb_current_access_profile');return profile}
function grant(route){const mods=Array.isArray(profile?.modules)?profile.modules:[];return mods.find(x=>key(x.moduleKey)==='*')||mods.find(x=>key(x.moduleKey)===key('route.'+route))||null}
function allowed(route){const g=grant(route);if(!g)return false;const a=REQUIRED_ACTION[route]||'view';return a==='create'?g.canCreate===true:a==='edit'?g.canEdit===true:a==='approve'?g.canApprove===true:g.canView===true}
function desktopUrl(route){return DESKTOP+'?module='+encodeURIComponent(route)+'&autoload=1'}
function routeUrl(route){return MOBILE_URL[route]||desktopUrl(route)}
function toast(text){const el=$('toast');if(!el)return;el.textContent=text;el.hidden=false;clearTimeout(toast.t);toast.t=setTimeout(()=>{el.hidden=true},2800)}
function setUrl(route,push=true){try{const u=new URL(location.href);if(route)u.searchParams.set('module',route);else u.searchParams.delete('module');history[push?'pushState':'replaceState']({},'',u.pathname+u.search+u.hash)}catch(_){}}
function hideScreens(){['mobileHome','menuScreen','moduleScreen'].forEach(id=>{const el=$(id);if(el)el.hidden=true})}

function navLabels(){document.querySelectorAll('[data-nav="more"]').forEach(btn=>{btn.innerHTML='<b>☰</b>Menu'});}

function injectStyle(){if($('bbMainMenuV2Style'))return;const s=document.createElement('style');s.id='bbMainMenuV2Style';s.textContent=`
#menuGrid.bb-desktop-menu{display:block!important;padding:10px 10px 88px!important;overflow-y:auto!important;background:#eef3f8!important}
.bb-menu-group{margin:0 0 7px;border:1px solid #d8e3ef;border-radius:12px;background:#fff;overflow:hidden;box-shadow:0 3px 10px rgba(23,63,119,.04)}
.bb-menu-group>summary{list-style:none;display:flex;align-items:center;justify-content:space-between;gap:10px;min-height:46px;padding:10px 12px;color:#173f77;font-size:12px;font-weight:900;cursor:pointer;background:#fff}
.bb-menu-group>summary::-webkit-details-marker{display:none}.bb-menu-group>summary .bb-g-left{display:flex;align-items:center;gap:9px}.bb-menu-group>summary .bb-g-icon{font-size:17px}.bb-menu-group>summary .bb-g-arrow{font-size:10px;color:#71849a;transition:transform .15s ease}.bb-menu-group[open]>summary{background:#f5f9fe;border-bottom:1px solid #e3ebf4}.bb-menu-group[open]>summary .bb-g-arrow{transform:rotate(180deg)}
.bb-menu-items{padding:4px 7px 7px}.bb-menu-item{width:100%;min-height:40px;display:grid;grid-template-columns:27px minmax(0,1fr) auto;align-items:center;gap:7px;border:0;border-bottom:1px solid #edf1f5;background:#fff;color:#243b58;padding:7px 7px;text-align:left;font:inherit;cursor:pointer}.bb-menu-item:last-child{border-bottom:0}.bb-menu-item:active{background:#eef5ff}.bb-menu-item .bb-mi-icon{font-size:15px;text-align:center}.bb-menu-item strong{font-size:9.5px;line-height:1.2}.bb-menu-item small{font-size:7px;color:#7b8da0;font-weight:800}.bb-menu-item .bb-mobile-tag{padding:3px 5px;border-radius:999px;background:#eaf6ef;color:#198754;font-size:6px;font-weight:900}.bb-menu-item .bb-pc-tag{padding:3px 5px;border-radius:999px;background:#f1f3f6;color:#7a8796;font-size:6px;font-weight:900}.bb-menu-empty{padding:30px 14px;text-align:center;color:#74869a;font-size:10px}.simple-header #menuTitle{font-size:14px}.simple-header #menuSubtitle{font-size:8px}
`;
document.head.appendChild(s)}

function groupHtml(groupId,open){const def=GROUPS.find(x=>x[0]===groupId);if(!def)return'';const items=Object.entries(ROUTES).filter(([r,v])=>v[0]===groupId&&allowed(r));if(!items.length)return'';return `<details class="bb-menu-group"${open?' open':''}><summary><span class="bb-g-left"><span class="bb-g-icon">${def[1]}</span><span>${esc(def[2])}</span></span><span class="bb-g-arrow">▼</span></summary><div class="bb-menu-items">${items.map(([r,v])=>`<button type="button" class="bb-menu-item" data-bb-route="${esc(r)}"><span class="bb-mi-icon">${v[1]}</span><span><strong>${esc(v[2])}</strong><small>${MOBILE_URL[r]?'Mobile version':'PC version'}</small></span><span class="${MOBILE_URL[r]?'bb-mobile-tag':'bb-pc-tag'}">${MOBILE_URL[r]?'MOBILE':'PC'}</span></button>`).join('')}</div></details>`}

async function showMenu(tab='more',push=true){lastTab=TAB_GROUPS[tab]?tab:'more';try{await getProfile()}catch(e){toast(e.message||String(e));return}hideScreens();const screen=$('menuScreen'),grid=$('menuGrid');if(!screen||!grid)return;screen.hidden=false;grid.classList.add('bb-desktop-menu');const groups=TAB_GROUPS[lastTab]||TAB_GROUPS.more;const html=groups.map((g,i)=>groupHtml(g,lastTab!=='more'||i===0)).join('');grid.innerHTML=html||'<div class="bb-menu-empty">No functions assigned in this section.</div>';$('menuTitle').textContent=lastTab==='more'?'Main Menu':lastTab==='sales'?'Sales':lastTab==='stock'?'Stock':'Reports';$('menuSubtitle').textContent=Object.keys(ROUTES).filter(allowed).length+' available functions';navLabels();if(push)setUrl('',false);grid.scrollTop=0}

async function openRoute(route,push=true){if(!ROUTES[route]){toast('This function is not configured.');return}try{await getProfile()}catch(e){toast(e.message||String(e));return}if(!allowed(route)){toast('Access denied for this function.');return}const item=ROUTES[route];hideScreens();const screen=$('moduleScreen'),frame=$('moduleFrame');if(!screen||!frame)return;screen.hidden=false;$('moduleTitle').textContent=item[2];$('moduleDesktopLink').href=desktopUrl(route);frame.src=routeUrl(route);navLabels();if(push)setUrl(route,true)}

function intercept(e){const routeBtn=e.target.closest?.('[data-bb-route],[data-route]');if(routeBtn){const r=routeBtn.dataset.bbRoute||routeBtn.dataset.route;if(ROUTES[r]){e.preventDefault();e.stopImmediatePropagation();openRoute(r,true);return}}
  const nav=e.target.closest?.('[data-nav]');if(nav){const n=nav.dataset.nav;if(n==='home')return;if(TAB_GROUPS[n]){e.preventDefault();e.stopImmediatePropagation();showMenu(n,true);return}}
  if(e.target.closest?.('#moduleBack')){e.preventDefault();e.stopImmediatePropagation();showMenu(lastTab,false);return}
  if(e.target.closest?.('#menuBack')){e.preventDefault();e.stopImmediatePropagation();const home=$('mobileHome');if(home){hideScreens();home.hidden=false;setUrl('',false);navLabels()}return}
  if(e.target.closest?.('#notificationBtn')){e.preventDefault();e.stopImmediatePropagation();openRoute('notification-center',true);return}
}

function syncRoute(){const r=new URLSearchParams(location.search).get('module')||'';if(r&&ROUTES[r])openRoute(r,false)}

function start(){injectStyle();navLabels();document.addEventListener('click',intercept,true);new MutationObserver(()=>{if(rendering)return;rendering=true;requestAnimationFrame(()=>{navLabels();rendering=false})}).observe(document.body,{childList:true,subtree:true});window.addEventListener('popstate',()=>setTimeout(syncRoute,0));setTimeout(()=>getProfile(true).catch(()=>{}),600);setTimeout(syncRoute,1000);setTimeout(navLabels,1300)}

if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
window.BBMobileMainMenuV2={showMenu,openRoute,refreshPermissions:()=>getProfile(true)};
})();
