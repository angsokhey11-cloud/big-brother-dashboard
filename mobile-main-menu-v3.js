/* BIG BROTHER — Mobile Router + Dropdown Menu V4
   Mobile dashboard only. Desktop dashboard remains untouched. */
(function(){
'use strict';

const DASH='https://angsokhey11-cloud.github.io/big-brother-dashboard/index.html';
const $=id=>document.getElementById(id);
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));

const META={
 'sales-support-calculator':['Sales Support','🧮','Calculator'],
 'sales-support-request-delivery':['Sales Support','🚚','Request Delivery'],
 'sales-support-your-customer':['Sales Support','👥','Your Customer'],
 'sales-support-add-customer':['Sales Support','👤','Add Customer'],
 'sales-support-customer-map':['Sales Support','🗺️','Customer Map'],
 'sales-support-your-stock':['Sales Support','📦','Your Stock'],
 'sales-support-your-collection':['Sales Support','💵','Your Collection'],
 'sales-support-your-invoices':['Sales Support','🧾','Your Invoices'],
 'sales-support-your-receivable':['Sales Support','💰','Your Receivable'],
 'sales-support-successful-delivery':['Sales Support','✅','Successful Delivery'],

 'invoice':['Sales','🧾','Create Invoice'],
 'history':['Sales','📚','Invoice History'],
 'sale-return':['Sales','↩️','Invoice Reversal'],
 'reversal-history':['Sales','📜','Reversal History'],
 'payment-history':['Sales','💳','Payment History'],
 'daily-sale-summary':['Sales','📊','Daily Sale Summary'],
 'daily-cash-collection':['Sales','💵','Cash Collection'],

 'ar-all':['Receivable','📋','All Receivables'],
 'ar-your':['Receivable','💰','My Receivables'],
 'ar-payment-history':['Receivable','🧾','Receivable Payments'],
 'ar-daily-receivable-cash':['Receivable','💵','Daily Receivable Cash'],

 'stock-keyin':['Stock','📦','Stock In / Out'],
 'stock-damaged':['Stock','⚠️','Damaged Stock'],
 'stock-damaged-report':['Stock','📋','Damaged Stock Report'],
 'stock-damaged-cleared':['Stock','✅','Cleared Damaged Stock'],
 'stock-damaged-accounting':['Stock','🧮','Damaged Stock Accounting'],
 'stock-report':['Stock','📋','Stock Report'],
 'batch-report':['Stock','🗂️','Batch Report'],
 'closed-batch':['Stock','✅','Closed Batch'],
 'stock-transactions':['Stock','🔄','Stock Transactions'],
 'stock-alerts':['Stock','🚨','Smart Stock Alerts'],

 'monthly-sales-report':['Reports','📈','Monthly Sales'],
 'income-statement-report':['Reports','📊','Income Statement'],
 'purchase-order-report':['Reports','🧾','Purchase Order Report'],
 'cogs-daily':['Reports','🏷️','Daily COGS'],
 'cogs-monthly':['Reports','📦','Monthly COGS'],
 'expense-monthly-report':['Reports','💸','Monthly Expense'],

 'purchase-create':['Purchase','🛒','Create Purchase'],
 'purchase-history':['Purchase','📚','Purchase History'],
 'purchase-payable':['Purchase','💵','Purchase Payable'],
 'purchase-payment-history':['Purchase','💳','Purchase Payment'],

 'expense-add':['Expenses','➕','Add Expense'],
 'expense-accrued':['Expenses','⏳','Accrued Expense'],
 'daily-cash':['Expenses','💵','Daily Cash'],
 'expense-history':['Expenses','🧾','Expense History'],

 'customers-add':['Master Data','👤','Add Customer'],
 'customers-map':['Master Data','🗺️','Customer Map'],
 'customers-details':['Master Data','👥','Customer Details'],
 'clients-add':['Master Data','🏢','Add Client'],
 'clients-details':['Master Data','🏭','Client Details'],
 'products-add':['Master Data','🥛','Add Product'],
 'products-details':['Master Data','📦','Product Details'],
 'master-expense-categories':['Master Data','💸','Expense Categories'],

 'admin-pending-receivable':['Admin Work','💰','Pending Receivable Request'],
 'admin-pending-daily-cash':['Admin Work','💵','Pending Daily Cash Request'],
 'admin-pending-deposit':['Admin Work','🏦','Pending Deposit'],
 'admin-deposit-history':['Admin Work','📚','Deposit History'],
 'admin-staff-request':['Admin Work','👥','Staff Request'],
 'admin-request':['Admin Work','🛠️','Admin Request'],
 'admin-user-permissions':['Admin Work','🔐','User & Permission Manager'],

 'staff-relation':['Company','🤝','Staff Relation'],
 'notification-center':['Company','🔔','Notifications']
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
 'sales-support-your-collection':'https://angsokhey11-cloud.github.io/big-brother-daily-cash-collection/your-collection-mobile.html?embed=1&v=20260921-owner1',
 'sales-support-your-invoices':'https://angsokhey11-cloud.github.io/invoice-history/your-invoices-mobile.html?embed=1&v=20260921-owner1',
 'sales-support-your-receivable':'https://angsokhey11-cloud.github.io/big-brother-ar/your-receivable-mobile.html?embed=1&v=20260915-1',

 'ar-all':'https://angsokhey11-cloud.github.io/big-brother-ar/all-receivable-mobile.html?embed=1&v=20260921-arassigned2',
 'ar-your':'https://angsokhey11-cloud.github.io/big-brother-ar/your-receivable-mobile.html?embed=1&v=20260915-1',
 'ar-payment-history':'https://angsokhey11-cloud.github.io/big-brother-payment-history/receivable-mobile.html?embed=1&v=20260915-clean2',

 'stock-keyin':'https://angsokhey11-cloud.github.io/big-brother-stock-managemenet/mobile.html?embed=1&v=20260923-stockux4',
 'stock-damaged-report':'https://angsokhey11-cloud.github.io/big-brother-stock-report/damage-stock-report-mobile.html?embed=1&v=20260915-3',
 'stock-damaged-cleared':'https://angsokhey11-cloud.github.io/big-brother-stock-report/damaged-stock-cleared-mobile.html?embed=1&v=20260915-2',
 'stock-damaged-accounting':'https://angsokhey11-cloud.github.io/big-brother-damaged-stock/accounting-mobile.html?embed=1&v=20260915-3',
 'stock-report':'https://angsokhey11-cloud.github.io/big-brother-stock-report/mobile.html?embed=1&v=20260923-simple1',
 'batch-report':'https://angsokhey11-cloud.github.io/big-brother-stock-report/batch-mobile.html?embed=1&v=20260915-4',
 'closed-batch':'https://angsokhey11-cloud.github.io/big-brother-stock-report/closed-batch-mobile.html?embed=1&v=20260915-1',
 'stock-transactions':'https://angsokhey11-cloud.github.io/big-brother-stock-report/transactions-mobile.html?embed=1&v=20260915-2',
 'stock-alerts':'https://angsokhey11-cloud.github.io/big-brother-admin-work/stock-alerts-mobile.html?embed=1&v=20260915-1',

 'monthly-sales-report':'https://angsokhey11-cloud.github.io/big-brother-report/monthly-sales-mobile.html?embed=1&v=20260915-3',
 'income-statement-report':'https://angsokhey11-cloud.github.io/big-brother-report/income-statement-mobile.html?embed=1&v=20260920-vaultfx1',
 'purchase-order-report':'https://angsokhey11-cloud.github.io/big-brother-report/purchase-order-report-mobile.html?embed=1&v=20260915-1',
 'cogs-daily':'https://angsokhey11-cloud.github.io/big-brother-cogs/mobile-daily.html?embed=1&v=20260915-1',
 'cogs-monthly':'https://angsokhey11-cloud.github.io/big-brother-cogs/mobile-monthly.html?embed=1&v=20260915-1',
 'expense-monthly-report':'https://angsokhey11-cloud.github.io/big-brother-expenses/mobile-monthly.html?embed=1&v=20260915-1',

 'purchase-create':'https://angsokhey11-cloud.github.io/big-brother-purchase-recorder/mobile.html?embed=1&v=20260915-1',
 'purchase-history':'https://angsokhey11-cloud.github.io/big-brother-puchase-history/mobile.html?embed=1&v=20260915-1',
 'purchase-payable':'https://angsokhey11-cloud.github.io/big-brother-purchase-payable-invoice/mobile.html?embed=1&v=20260915-1',
 'purchase-payment-history':'https://angsokhey11-cloud.github.io/big-brother-purchase-payment-history/mobile.html?embed=1&v=20260915-1',

 'expense-add':'https://angsokhey11-cloud.github.io/big-brother-expenses/mobile.html?embed=1&v=20260915-1',
 'expense-accrued':'https://angsokhey11-cloud.github.io/big-brother-expenses/mobile-accrued.html?embed=1&v=20260915-1',
 'daily-cash':'https://angsokhey11-cloud.github.io/big-brother-expenses/daily-cash.html?embed=1&v=20260920-vaultfx1',
 'expense-history':'https://angsokhey11-cloud.github.io/big-brother-expenses/mobile-history.html?embed=1&v=20260915-1',

 'staff-relation':'https://angsokhey11-cloud.github.io/big-brother-staff-relation/mobile.html?embed=1&v=20260915-1',

 'admin-pending-receivable':'https://angsokhey11-cloud.github.io/big-brother-admin-work/pending-receivable-mobile.html?embed=1&v=20260920-artelegram2',
 'admin-pending-daily-cash':'https://angsokhey11-cloud.github.io/big-brother-admin-work/pending-daily-cash-mobile.html?embed=1&v=20260915-1',
 'admin-pending-deposit':'https://angsokhey11-cloud.github.io/big-brother-admin-work/pending-deposit-mobile.html?embed=1&v=20260920-vaultfx1'
};

const PC={
 'sales-support-calculator':'https://angsokhey11-cloud.github.io/big-brother-sales-support/?embed=1&view=calculator&v=20260922-nodeliverypopup1',
 'sales-support-request-delivery':'https://angsokhey11-cloud.github.io/big-brother-sales-support/?embed=1&view=request-delivery&v=110',
 'sales-support-your-customer':'https://angsokhey11-cloud.github.io/big-brother-sales-support/?embed=1&view=your-customer&v=110',
 'sales-support-successful-delivery':'https://angsokhey11-cloud.github.io/big-brother-sales-support/?embed=1&view=successful-delivery&v=110',
 'daily-cash':'https://angsokhey11-cloud.github.io/big-brother-expenses/daily-cash.html?embed=1&v=20260920-vaultfx1',
 'stock-damaged':'https://angsokhey11-cloud.github.io/big-brother-stock-managemenet/?embed=1&view=damaged&v=20',
 'ar-daily-receivable-cash':'https://angsokhey11-cloud.github.io/big-brother-daily-receivable-cash-summary/?embed=1',
 'customers-add':'https://angsokhey11-cloud.github.io/big-brother-customers-editor/?embed=1&view=add&v=21',
 'customers-map':'https://angsokhey11-cloud.github.io/big-brother-customers-editor/?embed=1&view=map&v=21',
 'customers-details':'https://angsokhey11-cloud.github.io/big-brother-customers-editor/?embed=1&view=details&v=21',
 'clients-add':'https://angsokhey11-cloud.github.io/big-brother-clients-editor/?embed=1&view=add&v=10',
 'clients-details':'https://angsokhey11-cloud.github.io/big-brother-clients-editor/?embed=1&view=details&v=10',
 'products-add':'https://angsokhey11-cloud.github.io/big-brother-products-editor/?embed=1&view=add&v=10',
 'products-details':'https://angsokhey11-cloud.github.io/big-brother-products-editor/?embed=1&view=details&v=10',
 'master-expense-categories':'https://angsokhey11-cloud.github.io/big-brother-master-data/expense-categories.html?embed=1&v=21',
 'admin-deposit-history':'https://angsokhey11-cloud.github.io/big-brother-admin-work/?embed=1&view=deposit-history',
 'admin-staff-request':'https://angsokhey11-cloud.github.io/big-brother-admin-work/?embed=1&view=staff-request',
 'admin-request':'https://angsokhey11-cloud.github.io/big-brother-admin-work/?embed=1&view=admin-request',
 'admin-user-permissions':'https://angsokhey11-cloud.github.io/big-brother-admin-work/user-permissions.html?embed=1',
 'notification-center':'https://angsokhey11-cloud.github.io/big-brother-admin-work/company-control.html?embed=1&view=notifications&v=1'
};

function routeUrl(route){return MOBILE[route]||PC[route]||(DASH+'?module='+encodeURIComponent(route)+'&autoload=1')}
function routeLabel(route){return META[route]?.[2]||route}

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

function renderDirect(route){
 const frame=$('moduleFrame'),screen=$('moduleScreen');
 if(!frame||!screen)return false;
 const url=routeUrl(route);
 if($('mobileHome'))$('mobileHome').hidden=true;
 if($('menuScreen'))$('menuScreen').hidden=true;
 screen.hidden=false;
 if($('moduleTitle'))$('moduleTitle').textContent=routeLabel(route);
 if($('moduleDesktopLink'))$('moduleDesktopLink').href=DASH+'?module='+encodeURIComponent(route)+'&autoload=1';
 replaceFrameUrl(frame,url);
 return true;
}
function openDirect(route,push=true){
 if(!renderDirect(route))return false;
 const nav=window.BBMobileHistoryV7||window.BBMobileHistoryV6;
 if(nav&&!nav.isRestoring?.()){
   nav.recordModule(route,push);
   return true;
 }
 try{
   const u=new URL(location.href);
   u.searchParams.set('module',route);
   u.searchParams.set('autoload','1');
   history.replaceState(history.state||{},'',u.pathname+u.search+u.hash);
 }catch(_){}
 return true;
}

function patchBBMobile(){
 if(!window.BBMobile)window.BBMobile={};
 if(window.BBMobile.open!==openDirect)window.BBMobile.open=openDirect;
}

function injectMenuCss(){
 if($('bbDropdownMenuV4Css'))return;
 const s=document.createElement('style');s.id='bbDropdownMenuV4Css';s.textContent=`
 #menuGrid.bb-dropdown-menu{display:block!important;padding:10px 10px 90px!important;overflow-y:auto!important;background:#eef3f8!important}
 #menuGrid.bb-dropdown-menu .menu-card{display:none!important}
 .bb-dd-group{margin:0 0 8px;border:1px solid #d8e3ef;border-radius:13px;background:#fff;overflow:hidden;box-shadow:0 3px 10px rgba(23,63,119,.04)}
 .bb-dd-group>summary{list-style:none;min-height:48px;padding:10px 12px;display:flex;align-items:center;justify-content:space-between;gap:10px;background:#fff;color:#173f77;font-size:12px;font-weight:900;cursor:pointer}
 .bb-dd-group>summary::-webkit-details-marker{display:none}
 .bb-dd-left{display:flex;align-items:center;gap:9px}.bb-dd-left b{font-size:17px}.bb-dd-arrow{font-size:10px;color:#71849a;transition:transform .15s ease}.bb-dd-group[open]>.bb-dd-arrow{transform:rotate(180deg)}
 .bb-dd-group[open]>summary{background:#f5f9fe;border-bottom:1px solid #e3ebf4}.bb-dd-group[open]>summary .bb-dd-arrow{transform:rotate(180deg)}
 .bb-dd-items{padding:4px 7px 7px}.bb-dd-item{width:100%;min-height:42px;display:grid;grid-template-columns:29px minmax(0,1fr) auto;align-items:center;gap:8px;border:0;border-bottom:1px solid #edf1f5;background:#fff;color:#243b58;padding:7px;text-align:left;font:inherit;cursor:pointer}.bb-dd-item:last-child{border-bottom:0}.bb-dd-item:active{background:#eef5ff}.bb-dd-icon{font-size:16px;text-align:center}.bb-dd-copy strong{display:block;font-size:10px;line-height:1.2}.bb-dd-copy small{display:block;margin-top:2px;font-size:7px;color:#7b8da0;font-weight:800}.bb-dd-tag{padding:3px 6px;border-radius:999px;font-size:6px;font-weight:900}.bb-dd-tag.mobile{background:#eaf6ef;color:#198754}.bb-dd-tag.pc{background:#f1f3f6;color:#7a8796}
 `;document.head.appendChild(s);
}

const GROUP_ICON={'Sales Support':'🧰','Sales':'🧾','Receivable':'💰','Stock':'📦','Reports':'📊','Purchase':'🛒','Expenses':'💸','Master Data':'🗂️','Admin Work':'🛠️','Company':'⚙️'};
let rebuilding=false;
function rebuildMenu(){
 const host=$('menuGrid');
 if(!host||$('menuScreen')?.hidden||rebuilding)return;
 const buttons=[...host.querySelectorAll('[data-menu-route],.menu-card[data-route]')];
 if(!buttons.length)return;
 const routes=[];
 buttons.forEach(btn=>{const r=btn.dataset.menuRoute||btn.dataset.route;if(r&&!routes.includes(r))routes.push(r)});
 if(!routes.length)return;
 rebuilding=true;
 const groups=[];
 routes.forEach(r=>{const g=META[r]?.[0]||'Other';if(!groups.includes(g))groups.push(g)});
 host.classList.add('bb-dropdown-menu');
 host.innerHTML=groups.map((g,gi)=>{
   const rs=routes.filter(r=>(META[r]?.[0]||'Other')===g);
   return `<details class="bb-dd-group"${gi===0?' open':''}><summary><span class="bb-dd-left"><b>${GROUP_ICON[g]||'📁'}</b><span>${esc(g)}</span></span><span class="bb-dd-arrow">▼</span></summary><div class="bb-dd-items">${rs.map(r=>{const m=META[r]||['Other','•',r];const mobile=!!MOBILE[r];return `<button type="button" class="bb-dd-item" data-bb-route="${esc(r)}"><span class="bb-dd-icon">${m[1]}</span><span class="bb-dd-copy"><strong>${esc(m[2])}</strong><small>${mobile?'Mobile version':'PC version'}</small></span><span class="bb-dd-tag ${mobile?'mobile':'pc'}">${mobile?'MOBILE':'PC'}</span></button>`}).join('')}</div></details>`;
 }).join('');
 host.querySelectorAll('[data-bb-route]').forEach(btn=>btn.onclick=e=>{e.preventDefault();e.stopImmediatePropagation();openDirect(btn.dataset.bbRoute,true)});
 rebuilding=false;
}

function installMenuWatcher(){
 const host=$('menuGrid');if(!host||host.dataset.bbDropdownWatch)return;
 host.dataset.bbDropdownWatch='1';
 new MutationObserver(()=>{if(!rebuilding&&!$('menuScreen')?.hidden)setTimeout(rebuildMenu,0)}).observe(host,{childList:true,subtree:false});
 const menu=$('menuScreen');if(menu)new MutationObserver(()=>{if(!menu.hidden)setTimeout(rebuildMenu,0)}).observe(menu,{attributes:true,attributeFilter:['hidden']});
}

function interceptButtons(){
 document.addEventListener('click',event=>{
   const btn=event.target.closest?.('[data-sales-route],[data-menu-route],[data-bb-route],[data-route]');
   if(!btn)return;
   const route=btn.dataset.salesRoute||btn.dataset.menuRoute||btn.dataset.bbRoute||btn.dataset.route;
   if(!META[route])return;
   event.preventDefault();event.stopImmediatePropagation();event.stopPropagation();
   openDirect(route,true);
 },true);
}

function start(){
 injectMenuCss();patchBBMobile();installMenuWatcher();interceptButtons();
 setInterval(patchBBMobile,250);
 setInterval(()=>{if(!$('menuScreen')?.hidden)rebuildMenu()},500);
 setTimeout(()=>{patchBBMobile();rebuildMenu()},300);
 setTimeout(()=>{patchBBMobile();rebuildMenu()},1200);
}

if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
window.BBMobileRouteV4={open:openDirect,render:renderDirect,rebuildMenu};
})();
