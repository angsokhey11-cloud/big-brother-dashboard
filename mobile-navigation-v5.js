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


const NAV_VERSION=6;
const EXIT_WINDOW_MS=1900;
const navSession=String(Date.now());
let restoring=false;
let exitArmedUntil=0;

function currentRoute(){
  try{return new URL(location.href).searchParams.get('module')||''}catch(_){return''}
}
function routeGroup(route){return GROUP[String(route||'')]||''}
function urlFor(view,route=''){
  const u=new URL(location.href);
  if(view==='module'&&route){
    u.searchParams.set('module',route);
    u.searchParams.set('autoload','1');
  }else{
    u.searchParams.delete('module');
    u.searchParams.delete('autoload');
  }
  return u.pathname+u.search+u.hash;
}
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
  if(group){
    details.find(d=>d.open)?.scrollIntoView?.({block:'nearest'});
  }else{
    host.scrollTop=0;
  }
}
function renderHome(){
  hideAll();
  const home=$('mobileHome');
  if(home)home.hidden=false;
}
function renderMenu(group=''){
  hideAll();
  const menu=$('menuScreen');
  if(menu)menu.hidden=false;
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
function currentDepth(){
  const state=history.state||{};
  return state.bbNavSession===navSession?Math.max(0,Number(state.bbDepth)||0):0;
}
function homeRootState(){
  return {bbNavV:NAV_VERSION,bbNavSession:navSession,bbView:'home',bbDepth:0,bbHomeRoot:true};
}
function homeGuardState(){
  return {bbNavV:NAV_VERSION,bbNavSession:navSession,bbView:'home',bbDepth:0,bbHomeGuard:true};
}
function moduleState(route,depth){
  return {bbNavV:NAV_VERSION,bbNavSession:navSession,bbView:'module',bbRoute:route,bbDepth:depth};
}
function menuState(group,depth){
  return {bbNavV:NAV_VERSION,bbNavSession:navSession,bbView:'menu',bbGroup:group||'',bbDepth:depth};
}
function markInitialState(){
  try{
    const route=currentRoute();
    history.replaceState(homeRootState(),'',urlFor('home'));
    history.pushState(homeGuardState(),'',urlFor('home'));
    if(route){
      history.pushState(moduleState(route,1),'',urlFor('module',route));
    }
  }catch(_){}
}
function recordModule(route,push=true){
  route=String(route||'').trim();
  if(!route||restoring)return;
  exitArmedUntil=0;
  try{
    const state=history.state||{};
    if(push){
      if(state.bbNavSession===navSession&&state.bbView==='module'&&state.bbRoute===route){
        history.replaceState({...state,bbRoute:route},'',urlFor('module',route));
        return;
      }
      const depth=currentDepth()+1;
      history.pushState(moduleState(route,depth),'',urlFor('module',route));
    }else{
      const depth=state.bbNavSession===navSession?Math.max(1,Number(state.bbDepth)||1):1;
      history.replaceState(moduleState(route,depth),'',urlFor('module',route));
    }
  }catch(_){}
}
function recordMenu(group='',push=true){
  if(restoring)return;
  exitArmedUntil=0;
  try{
    const state=history.state||{};
    if(push){
      if(state.bbNavSession===navSession&&state.bbView==='menu'&&String(state.bbGroup||'')===String(group||'')){
        history.replaceState({...state,bbGroup:group||''},'',urlFor('menu'));
        return;
      }
      history.pushState(menuState(group,currentDepth()+1),'',urlFor('menu'));
    }else{
      const depth=state.bbNavSession===navSession?Math.max(1,Number(state.bbDepth)||1):1;
      history.replaceState(menuState(group,depth),'',urlFor('menu'));
    }
  }catch(_){}
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
  exitArmedUntil=0;
  const state=history.state||{};
  if(state.bbNavSession===navSession&&state.bbView==='home'){
    renderHome();
    return;
  }
  const depth=currentDepth();
  if(depth>0){
    history.go(-depth);
    return;
  }
  try{
    history.replaceState(homeRootState(),'',urlFor('home'));
    history.pushState(homeGuardState(),'',urlFor('home'));
  }catch(_){}
  renderHome();
}
function tryExitFromHome(){
  const now=Date.now();
  if(now<exitArmedUntil){
    exitArmedUntil=0;
    try{window.close()}catch(_){}
    setTimeout(()=>{try{history.back()}catch(_){}},0);
    return;
  }
  exitArmedUntil=now+EXIT_WINDOW_MS;
  renderHome();
  showToast('Press Back again to exit');
  try{history.pushState(homeGuardState(),'',urlFor('home'))}catch(_){}
}
function restoreState(state){
  state=state||{};
  if(state.bbNavSession!==navSession){
    return;
  }
  if(state.bbHomeRoot){
    tryExitFromHome();
    return;
  }
  exitArmedUntil=0;
  if(state.bbView==='home'){
    renderHome();
    return;
  }
  if(state.bbView==='menu'){
    renderMenu(state.bbGroup||'');
    return;
  }
  if(state.bbView==='module'&&state.bbRoute){
    renderModule(state.bbRoute);
    return;
  }
  renderHome();
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
      const route=(!$('moduleScreen')?.hidden)?currentRoute():'';
      event.preventDefault();event.stopImmediatePropagation();event.stopPropagation();
      openMenu(route?routeGroup(route):'',true);
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
    const state=history.state||{};
    setTimeout(()=>applyOpenGroup(state.bbNavSession===navSession&&state.bbView==='menu'?(state.bbGroup||''):''),80);
  }).observe(menu,{attributes:true,attributeFilter:['hidden']});
}
function start(){
  markInitialState();
  interceptNavigation();
  watchMenu();
  window.addEventListener('popstate',event=>{
    setTimeout(()=>restoreState(event.state||{}),0);
  });
}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});
else start();

window.BBMobileHistoryV6={
  openModule,
  openMenu,
  goHome,
  recordModule,
  recordMenu,
  restoreState,
  isRestoring:()=>restoring,
  currentDepth
};
window.BBMobileNavigationV5=window.BBMobileHistoryV6;
})();
