/* BIG BROTHER — Monthly Overview shortcut mapping V4.8 */
(function(){
'use strict';

let observer=null;

function installSubmenuPermissions(){
  if(document.getElementById('bbSubmenuPermissionScript'))return;
  const s=document.createElement('script');
  s.id='bbSubmenuPermissionScript';
  s.src='supabase-submenu-permissions.js?v=20260914-2';
  s.async=false;
  document.body.appendChild(s);
}

function installSalesSupportYourStock(){
  if(document.getElementById('bbSalesSupportYourStockScript'))return;
  const s=document.createElement('script');
  s.id='bbSalesSupportYourStockScript';
  s.src='supabase-sales-support-your-stock.js?v=20260924-salesmanbatch1';
  s.async=false;
  document.body.appendChild(s);
}

function installSalesSupportYourCollection(){
  if(document.getElementById('bbSalesSupportYourCollectionScript'))return;
  const s=document.createElement('script');
  s.id='bbSalesSupportYourCollectionScript';
  s.src='supabase-sales-support-your-collection.js?v=20260914-1';
  s.async=false;
  document.body.appendChild(s);
}

function installSalesSupportYourInvoices(){
  if(document.getElementById('bbSalesSupportYourInvoicesScript'))return;
  const s=document.createElement('script');
  s.id='bbSalesSupportYourInvoicesScript';
  s.src='supabase-sales-support-your-invoices.js?v=20260914-1';
  s.async=false;
  document.body.appendChild(s);
}

function installSalesSupportAddCustomer(){
  if(document.getElementById('bbSalesSupportAddCustomerScript'))return;
  const s=document.createElement('script');
  s.id='bbSalesSupportAddCustomerScript';
  s.src='supabase-sales-support-add-customer.js?v=20260914-1';
  s.async=false;
  document.body.appendChild(s);
}

function installSalesSupportCustomerMap(){
  if(document.getElementById('bbSalesSupportCustomerMapScript'))return;
  const s=document.createElement('script');
  s.id='bbSalesSupportCustomerMapScript';
  s.src='supabase-sales-support-customer-map.js?v=20260914-1';
  s.async=false;
  document.body.appendChild(s);
}

function installSalesSupportYourReceivable(){
  if(document.getElementById('bbSalesSupportYourReceivableScript'))return;
  const s=document.createElement('script');
  s.id='bbSalesSupportYourReceivableScript';
  s.src='supabase-sales-support-your-receivable.js?v=20260914-1';
  s.async=false;
  document.body.appendChild(s);
}

function openRoute(route){
  if(!route)return false;
  if(['monthly-sales-report','income-statement-report','purchase-order-report'].includes(route)){
    return window.BBCompanyFeatures?.open?.(route) ?? false;
  }
  if(typeof window.loadWorkspace==='function'){
    return window.loadWorkspace(route,true);
  }
  return false;
}

function filterOperatingExpenseInFrame(){
  const frame=document.getElementById('moduleFrame');
  if(!frame)return false;

  let attempts=0;
  const applyFilter=()=>{
    attempts+=1;
    try{
      const doc=frame.contentDocument;
      const select=doc?.getElementById('historyType');
      if(select){
        select.value='OPERATING EXPENSE';
        select.dispatchEvent(new Event('change',{bubbles:true}));
        return true;
      }
    }catch(_){ }

    if(attempts<60)setTimeout(applyFilter,150);
    return false;
  };

  frame.addEventListener('load',()=>setTimeout(applyFilter,120),{once:true});
  setTimeout(applyFilter,250);
  return true;
}

function openOperatingExpenseHistory(){
  if(typeof window.loadWorkspace!=='function')return false;
  const result=window.loadWorkspace('expense-history',true);
  filterOperatingExpenseInFrame();
  return result;
}

function bindCard(el,handler,title,route){
  if(!el)return;
  el.classList.add('bb-ov-clickable');
  el.setAttribute('role','button');
  el.setAttribute('tabindex','0');
  el.setAttribute('title',title);
  el.setAttribute('aria-label',title);
  if(route)el.dataset.route=route;
  else delete el.dataset.route;
  el.removeAttribute('onclick');
  el.removeAttribute('onkeydown');
  el.onclick=handler;
  el.onkeydown=function(event){
    if(event.key==='Enter'||event.key===' '){
      event.preventDefault();
      handler(event);
    }
  };
}

function normalizeCards(body){
  const kpis=Array.from(body.querySelectorAll('.bb-ov-kpis > div'));
  kpis.forEach(el=>el.classList.add('bb-ov-kpi','bb-ov-clickable'));

  const activity=Array.from(body.querySelectorAll('.bb-ov-activity > div'));
  activity.forEach(el=>el.classList.add('bb-ov-act','bb-ov-clickable'));

  return {kpis,activity};
}

function apply(){
  const body=document.getElementById('bbOverviewBody');
  if(!body)return;

  const {kpis,activity}=normalizeCards(body);

  if(kpis.length>=9){
    const calculator=kpis[1];
    calculator.style.setProperty('--a','#245fae');
    if(calculator.dataset.bbGuideCard!=='calculator'){
      calculator.innerHTML='<div class="i">🧮</div><small>Calculator</small><strong>Sale Support</strong><em>Open Sales Support Calculator</em>';
      calculator.dataset.bbGuideCard='calculator';
    }
    bindCard(calculator,()=>openRoute('sales-support-calculator'),'Open Sale Support Calculator','sales-support-calculator');
    bindCard(kpis[2],()=>openRoute('expense-monthly-report'),'Open Monthly Expense Report','expense-monthly-report');
    bindCard(kpis[3],()=>openRoute('cogs-monthly'),'Open Monthly COGS Report','cogs-monthly');
    bindCard(kpis[4],openOperatingExpenseHistory,'Open Expense History — Operating Expense',null);
  }

  if(activity.length>=5){
    bindCard(activity[0],()=>openRoute('history'),'Open Invoice History','history');
    bindCard(activity[2],()=>openRoute('sales-support-your-customer'),'Open Your Customer','sales-support-your-customer');
  }
}

function start(){
  installSubmenuPermissions();
  installSalesSupportYourStock();
  installSalesSupportYourCollection();
  installSalesSupportYourInvoices();
  installSalesSupportAddCustomer();
  installSalesSupportCustomerMap();
  installSalesSupportYourReceivable();
  apply();
  if(observer)return;
  observer=new MutationObserver(()=>apply());
  observer.observe(document.documentElement,{childList:true,subtree:true});
}

window.BBOverviewGuide={apply,openRoute,openOperatingExpenseHistory};

if(document.readyState==='loading'){
  document.addEventListener('DOMContentLoaded',start,{once:true});
}else{
  start();
}
})();
