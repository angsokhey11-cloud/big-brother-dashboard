/* BIG BROTHER — Sales Support Batch Selling Tracker menu V1 */
(function(){
'use strict';

const ROUTE='sales-support-batch-selling-tracker';
const URL='https://angsokhey11-cloud.github.io/big-brother-batch-selling-tracker/?embed=1&v=20260925-dashboard1';
let restoreDone=false;

const key=v=>String(v||'').trim().toLowerCase();
function profile(){return window.BBDashboardAdapter?.getProfile?.()||null}
function canView(){
  const p=profile();
  if(!p)return false;
  if(p?.user?.isAdmin===true)return true;
  const mods=Array.isArray(p?.modules)?p.modules:[];
  const g=mods.find(x=>key(x.moduleKey)==='*')
    ||mods.find(x=>key(x.moduleKey)==='route.sales-support-your-stock');
  return g?.canView===true;
}
function ensureMenu(){
  const submenu=document.getElementById('salesSupportSubmenu');
  if(!submenu)return false;

  let btn=document.getElementById('navSalesSupportBatchSellingTracker');
  if(!btn){
    btn=document.createElement('button');
    btn.type='button';
    btn.id='navSalesSupportBatchSellingTracker';
    btn.textContent='🔎 Batch Selling Tracker';
    btn.addEventListener('click',()=>open(true));

    const stock=document.getElementById('navSalesSupportYourStock');
    const customer=document.getElementById('navSalesSupportYourCustomer');
    if(stock?.parentNode===submenu)stock.insertAdjacentElement('afterend',btn);
    else if(customer?.parentNode===submenu)customer.insertAdjacentElement('afterend',btn);
    else submenu.appendChild(btn);
  }

  const allowed=canView();
  btn.hidden=!allowed;
  btn.style.display=allowed?'':'none';
  return true;
}
function markActive(){
  document.querySelectorAll('.nav-submenu button.active,.shell-nav-link.active').forEach(el=>el.classList.remove('active'));
  document.getElementById('navSalesSupportBatchSellingTracker')?.classList.add('active');

  const submenu=document.getElementById('salesSupportSubmenu');
  const menuBtn=document.getElementById('salesSupportMenuButton');
  if(submenu)submenu.classList.add('open');
  if(menuBtn){
    menuBtn.classList.add('open');
    menuBtn.setAttribute('aria-expanded','true');
    const arrow=menuBtn.querySelector('.nav-arrow');
    if(arrow)arrow.textContent='▲';
  }
}
function persist(){
  try{
    const u=new URL(location.href);
    u.searchParams.set('module',ROUTE);
    u.searchParams.set('autoload','1');
    history.pushState({module:ROUTE},'',u.pathname+u.search+u.hash);
  }catch(_){}
}
function deny(){
  try{
    document.getElementById('bbBatchSellingTrackerToast')?.remove();
    const el=document.createElement('div');
    el.id='bbBatchSellingTrackerToast';
    el.textContent='Access denied for Batch Selling Tracker.';
    el.style.cssText='position:fixed;right:18px;bottom:18px;z-index:1000000;background:#7a271a;color:#fff;padding:11px 14px;border-radius:10px;box-shadow:0 10px 30px rgba(0,0,0,.18);font:800 12px Arial';
    document.body.appendChild(el);
    setTimeout(()=>el.remove(),2600);
  }catch(_){}
}
function open(updateUrl=true){
  ensureMenu();
  if(!canView()){deny();return false}

  const home=document.getElementById('dashboardHome');
  const workspace=document.getElementById('moduleWorkspace');
  const frame=document.getElementById('moduleFrame');
  if(!workspace||!frame)return false;

  if(home)home.hidden=true;
  workspace.hidden=false;
  frame.src=URL;
  markActive();
  if(updateUrl!==false)persist();
  return true;
}
function restore(){
  if(restoreDone)return;
  let route='';
  let autoload='';
  try{
    const q=new URLSearchParams(location.search);
    route=q.get('module')||'';
    autoload=q.get('autoload')||'';
  }catch(_){}
  if(route===ROUTE&&autoload==='1'){
    if(!profile())return;
    restoreDone=true;
    setTimeout(()=>open(false),60);
  }
}
function install(){
  ensureMenu();
  restore();
}
window.BBBatchSellingTracker={open,canView,ensureMenu};
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',install,{once:true});
else install();

window.addEventListener('popstate',()=>{
  try{
    const q=new URLSearchParams(location.search);
    if(q.get('module')===ROUTE)open(false);
  }catch(_){}
});

setTimeout(install,300);
setTimeout(install,1200);
})();