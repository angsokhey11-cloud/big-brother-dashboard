/* BIG BROTHER — Mobile Navigation History V5
   Mobile dashboard only. Desktop dashboard untouched.
   - Main Menu opens with all groups collapsed from Home.
   - From a function, Menu re-opens the group for that function.
   - Android/browser Back follows Home -> Menu -> Function history correctly.
*/
(function(){
'use strict';

const $=id=>document.getElementById(id);

const GROUP={
  'sales-support-calculator':'Sales Support',
  'sales-support-your-customer':'Sales Support',
  'sales-support-add-customer':'Sales Support',
  'sales-support-customer-map':'Sales Support',
  'sales-support-your-stock':'Sales Support',
  'sales-support-your-collection':'Sales Support',
  'sales-support-your-invoices':'Sales Support',
  'sales-support-your-receivable':'Sales Support',

  'invoice':'Sales','history':'Sales','sale-return':'Sales','reversal-history':'Sales',
  'payment-history':'Sales','daily-sale-summary':'Sales','daily-cash-collection':'Sales',

  'ar-all':'Receivable','ar-your':'Receivable','ar-payment-history':'Receivable',
  'ar-daily-receivable-cash':'Receivable',

  'stock-keyin':'Stock','stock-damaged':'Stock','stock-damaged-report':'Stock',
  'stock-damaged-cleared':'Stock','stock-damaged-accounting':'Stock','stock-report':'Stock',
  'batch-report':'Stock','closed-batch':'Stock','stock-transactions':'Stock','stock-alerts':'Stock',

  'monthly-sales-report':'Reports','income-statement-report':'Reports',
  'purchase-order-report':'Reports','cogs-daily':'Reports','cogs-monthly':'Reports',
  'expense-monthly-report':'Reports',

  'purchase-create':'Purchase','purchase-history':'Purchase','purchase-payable':'Purchase',
  'purchase-payment-history':'Purchase',

  'expense-add':'Expenses','expense-accrued':'Expenses','expense-history':'Expenses',

  'customers-add':'Master Data','customers-map':'Master Data','customers-details':'Master Data',
  'clients-add':'Master Data','clients-details':'Master Data','products-add':'Master Data',
  'products-details':'Master Data','master-expense-categories':'Master Data',

  'admin-pending-receivable':'Admin Work','admin-pending-daily-cash':'Admin Work',
  'admin-pending-deposit':'Admin Work','admin-deposit-history':'Admin Work',
  'admin-staff-request':'Admin Work','admin-request':'Admin Work',
  'admin-user-permissions':'Admin Work',

  'staff-relation':'Company','notification-center':'Company'
};

function currentRoute(){
  try{return new URL(location.href).searchParams.get('module')||''}catch(_){return''}
}
function routeGroup(route){return GROUP[String(route||'')]||''}
function urlWithoutModule(){
  const u=new URL(location.href);
  u.searchParams.delete('module');
  u.searchParams.delete('autoload');
  return u.pathname+u.search+u.hash;
}
function hideAll(){
  ['mobileHome','menuScreen','moduleScreen'].forEach(id=>{const el=$(id);if(el)el.hidden=true});
}
function applyOpenGroup(group=''){
  const host=$('menuGrid');if(!host)return;
  const details=[...host.querySelectorAll('.bb-dd-group')];
  if(!details.length){
    setTimeout(()=>applyOpenGroup(group),50);
    return;
  }
  details.forEach(d=>{
    const name=(d.querySelector('.bb-dd-left span')?.textContent||'').trim();
    d.open=!!group&&name===group;
  });
  if(group){
    const opened=details.find(d=>d.open);
    opened?.scrollIntoView?.({block:'nearest'});
  }else{
    host.scrollTop=0;
  }
}
function showMenu(group='',push=true){
  hideAll();
  if($('menuScreen'))$('menuScreen').hidden=false;
  try{
    const state={...(history.state||{}),bbView:'menu',bbGroup:group||''};
    if(push)history.pushState(state,'',urlWithoutModule());
    else history.replaceState(state,'',urlWithoutModule());
  }catch(_){}
  setTimeout(()=>{
    try{window.BBMobileRouteV4?.rebuildMenu?.()}catch(_){}
    setTimeout(()=>applyOpenGroup(group),25);
  },0);
}
function showHomeFromHistory(){
  hideAll();
  if($('mobileHome'))$('mobileHome').hidden=false;
  try{window.BBMobile?.home?.(false)}catch(_){}
}
function restoreState(state){
  const view=state?.bbView||'';
  if(view==='menu'){
    showMenu(state?.bbGroup||'',false);
    return;
  }
  if(view==='home'){
    showHomeFromHistory();
    return;
  }
  const route=currentRoute();
  if(route){
    try{window.BBMobileRouteV4?.open?.(route,false)}catch(_){}
    return;
  }
  showHomeFromHistory();
}
function markInitialState(){
  try{
    const route=currentRoute();
    const state={...(history.state||{})};
    if(!state.bbView){
      state.bbView=route?'module':'home';
      if(route)state.bbRoute=route;
      history.replaceState(state,'',location.pathname+location.search+location.hash);
    }
  }catch(_){}
}
function interceptNavigation(){
  document.addEventListener('click',event=>{
    const menuBtn=event.target.closest?.('[data-bb-nav="menu"],[data-nav="more"]');
    if(menuBtn){
      const route=(!$('moduleScreen')?.hidden)?currentRoute():'';
      const group=route?routeGroup(route):'';
      event.preventDefault();event.stopImmediatePropagation();event.stopPropagation();
      showMenu(group,true);
      return;
    }

    const moduleBack=event.target.closest?.('#moduleBack');
    if(moduleBack){
      event.preventDefault();event.stopImmediatePropagation();event.stopPropagation();
      history.back();
      return;
    }

    const menuBack=event.target.closest?.('#menuBack');
    if(menuBack){
      event.preventDefault();event.stopImmediatePropagation();event.stopPropagation();
      history.back();
      return;
    }
  },true);
}
function watchMenu(){
  const menu=$('menuScreen');if(!menu)return;
  new MutationObserver(()=>{
    if(menu.hidden)return;
    const state=history.state||{};
    setTimeout(()=>applyOpenGroup(state.bbView==='menu'?(state.bbGroup||''):''),80);
  }).observe(menu,{attributes:true,attributeFilter:['hidden']});
}
function start(){
  markInitialState();
  interceptNavigation();
  watchMenu();
  window.addEventListener('popstate',event=>{
    setTimeout(()=>restoreState(event.state||{}),0);
  });
  if(!$('menuScreen')?.hidden){
    setTimeout(()=>applyOpenGroup(history.state?.bbGroup||''),100);
  }
}

if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});
else start();
window.BBMobileNavigationV5={showMenu,applyOpenGroup,restoreState};
})();
