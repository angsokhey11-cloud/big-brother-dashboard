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


const NAV_VERSION=7;
const EXIT_WINDOW_MS=1900;
const navSession=String(Date.now());
let restoring=false;
let exitArmedUntil=0;
let stack=[];

function currentRoute(){
  try{return new URL(location.href).searchParams.get('module')||''}catch(_){return''}
}
function routeGroup(route){return GROUP[String(route||'')]||''}
function homeEntry(){return{view:'home'}}
function menuEntry(group=''){return{view:'menu',group:String(group||'')}}
function moduleEntry(route){return{view:'module',route:String(route||'')}}
function entryKey(entry){
  if(entry?.view==='module')return'module:'+String(entry.route||'');
  if(entry?.view==='menu')return'menu:'+String(entry.group||'');
  return'home';
}
function topEntry(){return stack[stack.length-1]||homeEntry()}
function urlForEntry(entry){
  const u=new URL(location.href);
  if(entry?.view==='module'&&entry.route){
    u.searchParams.set('module',entry.route);
    u.searchParams.set('autoload','1');
  }else{
    u.searchParams.delete('module');
    u.searchParams.delete('autoload');
  }
  return u.pathname+u.search+u.hash;
}
function rootState(){return{bbNavV:NAV_VERSION,bbNavSession:navSession,bbGuard:'root'}}
function activeState(){return{bbNavV:NAV_VERSION,bbNavSession:navSession,bbGuard:'active'}}
function hideAll(){
  ['mobileHome','menuScreen','moduleScreen'].forEach(id=>{const el=$(id);if(el)el.hidden=true});
}
function showToast(message){
  const el=$('toast');if(!el)return;
  el.textContent=message;el.hidden=false;
  clearTimeout(showToast._timer);
  showToast._timer=setTimeout(()=>{el.hidden=true},1700);
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
  if(group)details.find(d=>d.open)?.scrollIntoView?.({block:'nearest'});
  else host.scrollTop=0;
}
function renderHome(){
  hideAll();
  if($('mobileHome'))$('mobileHome').hidden=false;
}
function renderMenu(group=''){
  hideAll();
  if($('menuScreen'))$('menuScreen').hidden=false;
  setTimeout(()=>{
    try{window.BBMobileRouteV4?.rebuildMenu?.()}catch(_){}
    setTimeout(()=>applyOpenGroup(group),25);
  },0);
}
function renderModule(route){
  if(!route)return false;
  restoring=true;
  let ok=false;
  try{
    if(window.BBMobileRouteV4?.render)ok=window.BBMobileRouteV4.render(route)!==false;
    else if(window.BBMobileRouteV4?.open)ok=window.BBMobileRouteV4.open(route,false)!==false;
    else if(window.BBMobile?.open)ok=window.BBMobile.open(route,false)!==false;
  }catch(_){ok=false}
  restoring=false;
  return ok;
}
function renderEntry(entry){
  if(entry?.view==='module')return renderModule(entry.route);
  if(entry?.view==='menu'){renderMenu(entry.group||'');return true}
  renderHome();return true;
}
function syncActiveUrl(){
  try{history.replaceState(activeState(),'',urlForEntry(topEntry()))}catch(_){}
}
function pushActiveGuard(){
  try{history.pushState(activeState(),'',urlForEntry(topEntry()))}catch(_){}
}
function resetStackToHome(){
  stack=[homeEntry()];
  exitArmedUntil=0;
  renderHome();
  syncActiveUrl();
}
function markInitialState(){
  const requested=currentRoute();
  stack=[homeEntry()];
  if(requested)stack.push(moduleEntry(requested));
  try{
    history.replaceState(rootState(),'',urlForEntry(homeEntry()));
    history.pushState(activeState(),'',urlForEntry(topEntry()));
  }catch(_){}
}
function recordModule(route,push=true){
  route=String(route||'').trim();
  if(!route||restoring)return;
  exitArmedUntil=0;
  const next=moduleEntry(route);
  if(push){
    if(entryKey(topEntry())!==entryKey(next))stack.push(next);
    else stack[stack.length-1]=next;
  }else{
    if(stack.length===1)stack.push(next);
    else stack[stack.length-1]=next;
  }
  syncActiveUrl();
}
function recordMenu(group='',push=true){
  if(restoring)return;
  exitArmedUntil=0;
  const next=menuEntry(group);
  if(push){
    if(entryKey(topEntry())!==entryKey(next))stack.push(next);
    else stack[stack.length-1]=next;
  }else{
    if(stack.length===1)stack.push(next);
    else stack[stack.length-1]=next;
  }
  syncActiveUrl();
}
function openModule(route,push=true){
  route=String(route||'').trim();
  if(!route)return false;
  recordModule(route,push);
  return renderModule(route);
}
function openMenu(group='',push=true){
  recordMenu(group,push);
  renderMenu(group);
}
function goHome(){
  resetStackToHome();
}
function handleHomeExit(){
  const now=Date.now();
  if(now<exitArmedUntil){
    exitArmedUntil=0;
    try{window.close()}catch(_){}
    /* Never intentionally traverse stale BIG BROTHER entries from older builds. */
    if(history.length<=2){
      setTimeout(()=>{try{history.back()}catch(_){}},0);
    }else{
      setTimeout(()=>{
        if(document.visibilityState==='visible')pushActiveGuard();
      },220);
    }
    return;
  }
  exitArmedUntil=now+EXIT_WINDOW_MS;
  renderHome();
  showToast('Press Back again to exit');
  pushActiveGuard();
}
function handleBackTrigger(state){
  if(state?.bbNavSession!==navSession||state?.bbGuard!=='root')return;

  /* Menu is a top-level workspace. Android Back from Menu always returns Home,
     regardless of any stale/partial stack state that existed before Menu opened. */
  const menuVisible=!!$('menuScreen')&&!$('menuScreen').hidden;
  if(menuVisible||topEntry()?.view==='menu'){
    stack=[homeEntry()];
    exitArmedUntil=0;
    renderHome();
    pushActiveGuard();
    return;
  }

  if(stack.length>1){
    exitArmedUntil=0;
    stack.pop();
    renderEntry(topEntry());
    pushActiveGuard();
    return;
  }

  handleHomeExit();
}
function interceptNavigation(){
  document.addEventListener('click',event=>{
    const homeBtn=event.target.closest?.('[data-bb-nav="home"],[data-nav="home"]');
    if(homeBtn){
      event.preventDefault();event.stopImmediatePropagation();event.stopPropagation();
      goHome();
      return;
    }
    const menuBtn=event.target.closest?.('[data-bb-nav="menu"],[data-nav="more"]');
    if(menuBtn){
      const current=topEntry();
      const group=current?.view==='module'?routeGroup(current.route):'';
      event.preventDefault();event.stopImmediatePropagation();event.stopPropagation();
      openMenu(group,true);
      return;
    }
    const backBtn=event.target.closest?.('#moduleBack,#menuBack');
    if(backBtn){
      event.preventDefault();event.stopImmediatePropagation();event.stopPropagation();
      history.back();
      return;
    }
    const routeBtn=event.target.closest?.('[data-sales-route],[data-menu-route],[data-bb-route],[data-route],[data-kpi-route],[data-att-route]');
    if(!routeBtn)return;
    const route=routeBtn.dataset.salesRoute||routeBtn.dataset.menuRoute||routeBtn.dataset.bbRoute||routeBtn.dataset.route||routeBtn.dataset.kpiRoute||routeBtn.dataset.attRoute||'';
    if(!route||!GROUP[route])return;
    event.preventDefault();event.stopImmediatePropagation();event.stopPropagation();
    openModule(route,true);
  },true);
}
function watchMenu(){
  const menu=$('menuScreen');if(!menu)return;
  new MutationObserver(()=>{
    if(menu.hidden)return;
    const entry=topEntry();
    setTimeout(()=>applyOpenGroup(entry?.view==='menu'?(entry.group||''):''),80);
  }).observe(menu,{attributes:true,attributeFilter:['hidden']});
}
function start(){
  markInitialState();
  interceptNavigation();
  watchMenu();
  window.addEventListener('popstate',event=>{
    setTimeout(()=>handleBackTrigger(event.state||{}),0);
  });
}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});
else start();

const api={
  openModule,
  openMenu,
  goHome,
  recordModule,
  recordMenu,
  renderEntry,
  isRestoring:()=>restoring,
  stack:()=>stack.map(x=>({...x}))
};
window.BBMobileHistoryV7=api;
/* Compatibility for existing mobile files while they migrate to V7. */
window.BBMobileHistoryV6=api;
window.BBMobileNavigationV5=api;
})();
