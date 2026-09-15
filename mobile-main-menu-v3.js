/* BIG BROTHER — Mobile Main Menu + Routing V3
   Mobile dashboard only. Desktop dashboard untouched. */
(function(){
'use strict';
const SB='https://sjfhlaclgmkwwofzstok.supabase.co';
const KEY='sb_publishable_w762jR65CWwlO30fKQsYOw_6L9grx8S';
const SESSION_KEY='BB_SUPABASE_DEV_SESSION_V1';
const DASH='https://angsokhey11-cloud.github.io/big-brother-dashboard/index.html';
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
 'daily-cash-collection':['sales','💵','Cash Collection'],

 'purchase-create':['purchase','🛒','Create Purchase'],
 'purchase-history':['purchase','📚','Purchase History'],
 'purchase-payable':['purchase','💵','Purchase Payable'],
 'purchase-payment-history':['purchase','💳','Purchase Payment'],

 'expense-add':['expenses','➕','Add Expense'],
 'expense-accrued':['expenses','⏳','Accrued Expense'],
 'expense-history':['expenses','🧾','Expense History'],
 'expense-monthly-report':['expenses','📊','Monthly Expense'],
 'cogs-daily':['expenses','🏷️','Daily COGS'],
 'cogs-monthly':['expenses','📦','Monthly COGS'],

 'stock-keyin':['stock','📦','Stock In / Out'],
 'stock-damaged':['stock','⚠️','Damaged Stock'],
 'stock-damaged-report':['stock','📋','Damage Stock Report'],
 'stock-damaged-cleared':['stock','✅','Cleared Damaged Stock'],
 'stock-damaged-accounting':['stock','🧮','Damage Accounting'],
 'stock-report':['stock','📋','Stock Report'],
 'batch-report':['stock','🗂️','Batch Report'],
 'closed-batch':['stock','✅','Closed Batch'],
 'stock-transactions':['stock','🔄','Stock Transactions'],
 'stock-alerts':['stock','🚨','Smart Alerts'],

 'ar-all':['receivable','📋','All Receivable'],
 'ar-your':['receivable','💰','Your Receivable'],
 'ar-payment-history':['receivable','🧾','Receivable Payment'],
 'ar-daily-receivable-cash':['receivable','💵','Daily Receivable Cash'],

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

 'monthly-sales-report':['reports','📈','Monthly Sales'],
 'income-statement-report':['reports','📊','Income Statement'],
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
 'notification-center':['system','🔔','Notifications']
};

const MOBILE={
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

const PC={
 'sales-support-calculator':'https://angsokhey11-cloud.github.io/big-brother-sales-support/?embed=1&view=calculator&v=110',
 'sales-support-request-delivery':'https://angsokhey11-cloud.github.io/big-brother-sales-support/?embed=1&view=request-delivery&v=110',
 'sales-support-your-customer':'https://angsokhey11-cloud.github.io/big-brother-sales-support/?embed=1&view=your-customer&v=110',
 'sales-support-successful-delivery':'https://angsokhey11-cloud.github.io/big-brother-sales-support/?embed=1&view=successful-delivery&v=110',
 'stock-damaged':'https://angsokhey11-cloud.github.io/big-brother-stock-managemenet/?embed=1&view=damaged&v=20',
 'ar-daily-receivable-cash':'https://angsokhey11-cloud.github.io/big-brother-daily-receivable-cash-summary/?embed=1',
 'customers-add':'https://angsokhey11-cloud.github.io/big-brother-customers-editor/?embed=1&view=add&v=21',
 'customers-map':'https://angsokhey11-cloud.github.io/big-brother-customers-editor/?embed=1&view=map&v=21',
 'customers-details':'https://angsokhey11-cloud.github.io/big-brother-customers-editor/?embed=1&view=details&v=21',
 'clients-add':'https://angsokhey11-cloud.github.io/big-brother-clients-editor/?embed=1&view=add&v=10',
 'clients-details':'https://angsokhey11-cloud.github.io/big-brother-clients-editor/?embed=1&view=details&v=10',
 'products-add':'https://angsokhey11-cloud.github.io/big-brother-products-editor/?embed=1&view=add&v=10',
 'products-details':'https://angsokhey11-cloud.github.io/big-brother-products-editor/?embed=1&view=details&v=10',
 'master-expense-categories':'https://angsokhey11-cloud.github.io/big-brother-master-data/expense-categories.html?embed=1&v=20260912-3',
 'staff-management':'https://angsokhey11-cloud.github.io/big-brother-master-data/staff-management.html?embed=1',
 'staff-payment-settings':'https://angsokhey11-cloud.github.io/big-brother-master-data/staff-payment-settings.html?embed=1',
 'company-setup-master':'https://angsokhey11-cloud.github.io/big-brother-master-data/company-setup.html?embed=1',
 'admin-deposit-history':'https://angsokhey11-cloud.github.io/big-brother-admin-work/?embed=1&view=deposit-history',
 'admin-staff-request':'https://angsokhey11-cloud.github.io/big-brother-admin-work/?embed=1&view=staff-request',
 'admin-request':'https://angsokhey11-cloud.github.io/big-brother-admin-work/?embed=1&view=admin-request',
 'admin-user-permissions':'https://angsokhey11-cloud.github.io/big-brother-admin-work/user-permissions.html?embed=1',
 'notification-center':'https://angsokhey11-cloud.github.io/big-brother-admin-work/company-control.html?embed=1&view=notifications&v=1'
};

const GROUPS=[['sales-support','🧰','Sales Support'],['sales','🧾','Sales'],['purchase','🛒','Purchase'],['expenses','💸','Expenses & COGS'],['stock','📦','Stock'],['receivable','💰','Accounts Receivable'],['master','🗂️','Master Data'],['staff','🤝','Staff Relation'],['reports','📊','Reports'],['admin','🛠️','Admin Work'],['system','⚙️','System']];
const TAB_GROUPS={sales:['sales-support','sales','receivable'],stock:['stock'],reports:['reports','expenses'],more:GROUPS.map(x=>x[0])};
let session=null,profile=null,lastTab='more';
function readSession(){try{return JSON.parse(localStorage.getItem(SESSION_KEY)||'null')}catch(_){return null}}
async function parse(r){const t=await r.text();let d={};try{d=t?JSON.parse(t):{}}catch(_){d={message:t}}if(!r.ok)throw new Error(d.message||d.error_description||d.error||('Request failed ('+r.status+')'));return d}
async function refresh(){const s=readSession();if(!s?.refresh_token)throw new Error('Please sign in to BIG BROTHER.');const r=await fetch(SB+'/auth/v1/token?grant_type=refresh_token',{method:'POST',headers:{apikey:KEY,'Content-Type':'application/json'},body:JSON.stringify({refresh_token:s.refresh_token}),cache:'no-store'});session=await parse(r);localStorage.setItem(SESSION_KEY,JSON.stringify(session));return session}
async function rpc(fn,args={}){session=readSession();if(!session?.access_token)throw new Error('Please sign in to BIG BROTHER.');if(session.expires_at&&Number(session.expires_at)<Math.floor(Date.now()/1000)+45)await refresh();let r=await fetch(SB+'/rest/v1/rpc/'+fn,{method:'POST',headers:{apikey:KEY,Authorization:'Bearer '+session.access_token,'Content-Type':'application/json'},body:JSON.stringify(args||{}),cache:'no-store'});if(r.status===401){await refresh();r=await fetch(SB+'/rest/v1/rpc/'+fn,{method:'POST',headers:{apikey:KEY,Authorization:'Bearer '+session.access_token,'Content-Type':'application/json'},body:JSON.stringify(args||{}),cache:'no-store'})}return parse(r)}
async function getProfile(force=false){if(profile&&!force)return profile;profile=await rpc('bb_current_access_profile');return profile}
function grant(route){const mods=Array.isArray(profile?.modules)?profile.modules:[];return mods.find(x=>key(x.moduleKey)==='*')||mods.find(x=>key(x.moduleKey)===key('route.'+route))||null}
function allowed(route){const g=grant(route);if(!g)return false;const a=REQUIRED_ACTION[route]||'view';return a==='create'?g.canCreate===true:a==='edit'?g.canEdit===true:a==='approve'?g.canApprove===true:g.canView===true}
function routeUrl(route){return MOBILE[route]||PC[route]||(DASH+'?module='+encodeURIComponent(route)+'&autoload=1')}
function desktopUrl(route){return PC[route]||(DASH+'?module='+encodeURIComponent(route)+'&autoload=1')}
function hide(){['mobileHome','menuScreen','moduleScreen'].forEach(id=>{const e=$(id);if(e)e.hidden=true})}
function toast(t){const e=$('toast');if(!e)return;e.textContent=t;e.hidden=false;clearTimeout(toast.t);toast.t=setTimeout(()=>e.hidden=true,2800)}
function navLabel(){document.querySelectorAll('[data-nav="more"]').forEach(b=>b.innerHTML='<b>☰</b>Menu')}
function style(){if($('bbMainMenuV3Style'))return;const s=document.createElement('style');s.id='bbMainMenuV3Style';s.textContent=`#menuGrid.bb-dd{display:block!important;padding:10px 10px 88px!important;overflow-y:auto!important;background:#eef3f8!important}.bb-ddg{margin:0 0 7px;border:1px solid #d8e3ef;border-radius:12px;background:#fff;overflow:hidden}.bb-ddg>summary{list-style:none;display:flex;align-items:center;justify-content:space-between;min-height:46px;padding:10px 12px;color:#173f77;font-size:12px;font-weight:900;cursor:pointer}.bb-ddg>summary::-webkit-details-marker{display:none}.bb-ddg[open]>summary{background:#f5f9fe;border-bottom:1px solid #e3ebf4}.bb-dditems{padding:4px 7px 7px}.bb-dditem{width:100%;min-height:42px;display:grid;grid-template-columns:28px minmax(0,1fr) auto;align-items:center;gap:7px;border:0;border-bottom:1px solid #edf1f5;background:#fff;padding:7px;text-align:left}.bb-dditem:last-child{border-bottom:0}.bb-dditem strong{display:block;font-size:10px;color:#243b58}.bb-dditem small{display:block;margin-top:2px;font-size:7px;color:#7b8da0}.bb-tag{font-size:6px;font-weight:900;border-radius:999px;padding:3px 5px}.bb-tag.m{background:#eaf6ef;color:#198754}.bb-tag.p{background:#eef1f5;color:#6f7d8c}`;document.head.appendChild(s)}
function groupHtml(g,open){const def=GROUPS.find(x=>x[0]===g);const items=Object.entries(ROUTES).filter(([r,v])=>v[0]===g&&allowed(r));if(!def||!items.length)return'';return `<details class="bb-ddg"${open?' open':''}><summary><span>${def[1]} ${esc(def[2])}</span><span>▼</span></summary><div class="bb-dditems">${items.map(([r,v])=>`<button class="bb-dditem" type="button" data-bb-route="${r}"><span>${v[1]}</span><span><strong>${esc(v[2])}</strong><small>${MOBILE[r]?'Mobile version':'PC fallback'}</small></span><span class="bb-tag ${MOBILE[r]?'m':'p'}">${MOBILE[r]?'MOBILE':'PC'}</span></button>`).join('')}</div></details>`}
async function showMenu(tab='more'){lastTab=TAB_GROUPS[tab]?tab:'more';try{await getProfile()}catch(e){toast(e.message||String(e));return}hide();const s=$('menuScreen'),g=$('menuGrid');if(!s||!g)return;s.hidden=false;g.className='menu-grid bb-dd';const gs=TAB_GROUPS[lastTab]||TAB_GROUPS.more;g.innerHTML=gs.map((x,i)=>groupHtml(x,lastTab!=='more'||i===0)).join('')||'<div style="padding:25px;text-align:center">No functions assigned.</div>';$('menuTitle').textContent=lastTab==='more'?'Main Menu':lastTab==='sales'?'Sales':lastTab==='stock'?'Stock':'Reports';$('menuSubtitle').textContent='Desktop-style dropdown menu';navLabel();}
async function openRoute(r){if(!ROUTES[r])return;try{await getProfile()}catch(e){toast(e.message||String(e));return}if(!allowed(r)){toast('Access denied for this function.');return}hide();const s=$('moduleScreen'),f=$('moduleFrame');if(!s||!f)return;s.hidden=false;$('moduleTitle').textContent=ROUTES[r][2];$('moduleDesktopLink').href=desktopUrl(r);f.src=routeUrl(r);try{const u=new URL(location.href);u.searchParams.set('module',r);history.replaceState({},'',u.pathname+u.search)}catch(_){}navLabel();}
function click(e){const rb=e.target.closest?.('[data-bb-route],[data-route]');if(rb){const r=rb.dataset.bbRoute||rb.dataset.route;if(ROUTES[r]){e.preventDefault();e.stopImmediatePropagation();openRoute(r);return}}const nb=e.target.closest?.('[data-nav]');if(nb){const n=nb.dataset.nav;if(n==='home')return;if(TAB_GROUPS[n]){e.preventDefault();e.stopImmediatePropagation();showMenu(n);return}}if(e.target.closest?.('#moduleBack')){e.preventDefault();e.stopImmediatePropagation();showMenu(lastTab);return}if(e.target.closest?.('#menuBack')){e.preventDefault();e.stopImmediatePropagation();hide();$('mobileHome').hidden=false;return}if(e.target.closest?.('#notificationBtn')){e.preventDefault();e.stopImmediatePropagation();openRoute('notification-center');}}
function boot(){style();navLabel();document.addEventListener('click',click,true);setTimeout(()=>getProfile(true).catch(()=>{}),400);const r=new URLSearchParams(location.search).get('module');if(r&&ROUTES[r])setTimeout(()=>openRoute(r),700)}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',boot,{once:true});else boot();
window.BBMobileMainMenuV3={showMenu,openRoute,refresh:()=>getProfile(true)};
})();