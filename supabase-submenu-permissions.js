/* BIG BROTHER — Granular Submenu Permission Guard V2.1 */
(function(){
'use strict';

const KNOWN_ROUTES=new Set([
  'invoice','history','sale-return','reversal-history','payment-history','daily-sale-summary','daily-cash-collection',
  'sales-support-calculator','sales-support-request-delivery','sales-support-your-customer','sales-support-successful-delivery',
  'purchase-create','purchase-history','purchase-payable','purchase-payment-history',
  'expense-add','expense-accrued','expense-history','expense-monthly-report','cogs-daily','cogs-monthly',
  'stock-keyin','stock-damaged','stock-damaged-report','stock-damaged-cleared','stock-damaged-accounting',
  'stock-report','batch-report','closed-batch','stock-transactions','stock-alerts',
  'ar-all','ar-your','ar-payment-history','ar-daily-receivable-cash',
  'customers-editor','customers-add','customers-map','customers-details','customer-credit-control',
  'clients-editor','clients-add','clients-details',
  'products-editor','products-add','products-details',
  'master-expense-categories','staff-management','staff-payment-settings','company-setup-master',
  'staff-relation',
  'monthly-sales-report','income-statement-report','purchase-order-report',
  'admin-pending-receivable','admin-pending-daily-cash','admin-pending-deposit','admin-deposit-history',
  'admin-staff-request','admin-request','admin-user-permissions','management-control-center','system-activity','notification-center'
]);

const REQUIRED_ACTION={
  'customers-add':'create',
  'clients-add':'create',
  'products-add':'create',
  'sales-support-request-delivery':'create',
  'invoice':'create',
  'purchase-create':'create',
  'expense-add':'create'
};

let wrappedLoad=null;
let wrappedCompanyOpen=null;
let observer=null;
let initialRouteRestored=false;

const key=v=>String(v||'').trim().toLowerCase();
function profile(){return window.BBDashboardAdapter?.getProfile?.()||null}
function grantFor(moduleKey){
  const p=profile();
  if(p?.user?.isAdmin)return {canView:true,canCreate:true,canEdit:true,canApprove:true};
  const mods=Array.isArray(p?.modules)?p.modules:[];
  return mods.find(x=>key(x.moduleKey)==='*')||mods.find(x=>key(x.moduleKey)===key(moduleKey))||null;
}
function canRoute(route){
  route=String(route||'').trim();
  if(!KNOWN_ROUTES.has(route))return true;
  const g=grantFor('route.'+route);
  if(!g)return false;
  const action=REQUIRED_ACTION[route]||'view';
  return action==='create'?g.canCreate===true:action==='edit'?g.canEdit===true:action==='approve'?g.canApprove===true:g.canView===true;
}
function deny(){
  try{
    const old=document.getElementById('bbSubPermissionToast');
    if(old)old.remove();
    const el=document.createElement('div');
    el.id='bbSubPermissionToast';
    el.textContent='Access denied for this menu/function.';
    el.style.cssText='position:fixed;right:18px;bottom:18px;z-index:1000000;background:#7a271a;color:#fff;padding:11px 14px;border-radius:10px;box-shadow:0 10px 30px rgba(0,0,0,.18);font:800 12px Arial';
    document.body.appendChild(el);
    setTimeout(()=>el.remove(),2600);
  }catch(_){}
}
function persistRoute(route,updateUrl=true){
  route=String(route||'').trim();
  if(updateUrl===false||!KNOWN_ROUTES.has(route))return;
  try{
    const u=new URL(location.href);
    u.searchParams.set('module',route);
    u.searchParams.set('autoload','1');
    history.replaceState({},'',u.pathname+u.search+u.hash);
  }catch(_){}
}
function routeFromElement(el){
  const code=String(el?.getAttribute?.('onclick')||'');
  let m=code.match(/loadWorkspace\(\s*['"]([^'"]+)['"]/);
  if(m)return m[1];
  m=code.match(/BBCompanyFeatures\.open\(\s*['"]([^'"]+)['"]/);
  return m?m[1]:'';
}
function applyVisibility(){
  if(!profile())return;
  document.querySelectorAll('[onclick*="loadWorkspace"],[onclick*="BBCompanyFeatures.open"]').forEach(el=>{
    const route=routeFromElement(el);
    if(!route||!KNOWN_ROUTES.has(route))return;
    el.classList.toggle('bb-subperm-hidden',!canRoute(route));
  });

  [...document.querySelectorAll('.nested-nav-group,.nav-group')].reverse().forEach(group=>{
    const children=[...group.querySelectorAll('[onclick*="loadWorkspace"],[onclick*="BBCompanyFeatures.open"]')]
      .filter(el=>KNOWN_ROUTES.has(routeFromElement(el)));
    if(!children.length)return;
    const anyVisible=children.some(el=>!el.classList.contains('bb-subperm-hidden')&&!el.classList.contains('bb-auth-hidden')&&!el.hidden);
    group.classList.toggle('bb-subperm-group-hidden',!anyVisible);
  });
}
function installStyle(){
  if(document.getElementById('bbSubPermissionStyle'))return;
  const s=document.createElement('style');
  s.id='bbSubPermissionStyle';
  s.textContent='.bb-subperm-hidden,.bb-subperm-group-hidden{display:none!important}';
  document.head.appendChild(s);
}
function wrapLoad(){
  const current=window.loadWorkspace;
  if(typeof current!=='function'||current===wrappedLoad)return;
  const base=current;
  wrappedLoad=function(route,updateUrl=true){
    if(KNOWN_ROUTES.has(String(route||''))&&!canRoute(route)){
      deny();
      return false;
    }
    const result=base.call(window,route,updateUrl);
    if(result!==false)persistRoute(route,updateUrl);
    return result;
  };
  wrappedLoad.__bbSubPermission=true;
  window.loadWorkspace=wrappedLoad;
}
function wrapCompany(){
  const api=window.BBCompanyFeatures;
  if(!api||typeof api.open!=='function'||api.open===wrappedCompanyOpen)return;
  const base=api.open.bind(api);
  wrappedCompanyOpen=function(route,updateUrl=true){
    if(KNOWN_ROUTES.has(String(route||''))&&!canRoute(route)){
      deny();
      return false;
    }
    const result=base(route,updateUrl);
    if(result!==false)persistRoute(route,updateUrl);
    return result;
  };
  wrappedCompanyOpen.__bbSubPermission=true;
  api.open=wrappedCompanyOpen;
}
function protectInitialRoute(){
  try{
    const q=new URLSearchParams(location.search);
    const route=q.get('module')||'';
    if(!route||!KNOWN_ROUTES.has(route)||canRoute(route))return;
    const home=document.getElementById('dashboardHome');
    const workspace=document.getElementById('moduleWorkspace');
    const frame=document.getElementById('moduleFrame');
    if(frame)frame.src='about:blank';
    if(workspace)workspace.hidden=true;
    if(home)home.hidden=false;
    q.delete('module');q.delete('autoload');
    history.replaceState({},'',location.pathname+(q.toString()?'?'+q.toString():'')+location.hash);
    deny();
  }catch(_){}
}
function restoreInitialRoute(){
  if(initialRouteRestored)return;
  try{
    const q=new URLSearchParams(location.search);
    const route=q.get('module')||'';
    if(!route||!KNOWN_ROUTES.has(route)||!canRoute(route))return;

    const workspace=document.getElementById('moduleWorkspace');
    const frame=document.getElementById('moduleFrame');
    if(!workspace||!frame||typeof window.loadWorkspace!=='function'){
      setTimeout(restoreInitialRoute,120);
      return;
    }

    const u=new URL(location.href);
    u.searchParams.set('autoload','1');
    history.replaceState({},'',u.pathname+u.search+u.hash);

    if(workspace.hidden===false&&frame.getAttribute('src')&&frame.getAttribute('src')!=='about:blank'){
      initialRouteRestored=true;
      return;
    }

    initialRouteRestored=true;
    window.loadWorkspace(route,false);
  }catch(_){}
}
function install(){
  installStyle();
  if(!profile()){
    setTimeout(install,120);
    return;
  }
  wrapLoad();
  wrapCompany();
  applyVisibility();
  protectInitialRoute();
  restoreInitialRoute();
  if(!observer){
    observer=new MutationObserver(()=>{
      wrapLoad();wrapCompany();applyVisibility();
    });
    observer.observe(document.documentElement,{childList:true,subtree:true});
  }
  setTimeout(()=>{wrapLoad();wrapCompany();applyVisibility();protectInitialRoute();restoreInitialRoute()},500);
}

window.BBSubmenuPermissions={canRoute,applyVisibility,install,restoreInitialRoute};
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',()=>setTimeout(install,40),{once:true});
else setTimeout(install,40);
})();
