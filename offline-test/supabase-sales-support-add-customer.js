/* BIG BROTHER — Sales Support Add Customer menu V1 */
(function(){
'use strict';
const ROUTE='sales-support-add-customer';
const URL='https://angsokhey11-cloud.github.io/big-brother-sales-support/add-customer.html?embed=1&v=20260914-1';
let restoreDone=false;
const key=v=>String(v||'').trim().toLowerCase();
function profile(){return window.BBDashboardAdapter?.getProfile?.()||null}
function grant(){
  const p=profile();
  if(!p)return null;
  if(p?.user?.isAdmin===true)return {canView:true,canCreate:true};
  const mods=Array.isArray(p?.modules)?p.modules:[];
  return mods.find(x=>key(x.moduleKey)==='*')||mods.find(x=>key(x.moduleKey)==='route.'+ROUTE)||null;
}
function canUse(){const g=grant();return g?.canView===true&&g?.canCreate===true}
function hideLegacyDelivery(){
  ['navSalesSupportRequestDelivery','navSalesSupportSuccessfulDelivery'].forEach(id=>{
    const el=document.getElementById(id);if(el){el.hidden=true;el.style.display='none';el.setAttribute('aria-hidden','true')}
  });
}
function ensureMenu(){
  hideLegacyDelivery();
  const submenu=document.getElementById('salesSupportSubmenu');
  if(!submenu)return false;
  let btn=document.getElementById('navSalesSupportAddCustomer');
  if(!btn){
    btn=document.createElement('button');btn.type='button';btn.id='navSalesSupportAddCustomer';btn.textContent='➕ Add Customer';btn.addEventListener('click',()=>open(true));
    const customer=document.getElementById('navSalesSupportYourCustomer');
    if(customer?.parentNode===submenu)customer.insertAdjacentElement('afterend',btn);else submenu.appendChild(btn);
  }
  const allowed=canUse();btn.hidden=!allowed;btn.style.display=allowed?'':'none';return true;
}
function markActive(){
  document.querySelectorAll('.nav-submenu button.active,.shell-nav-link.active').forEach(el=>el.classList.remove('active'));
  document.getElementById('navSalesSupportAddCustomer')?.classList.add('active');
  const submenu=document.getElementById('salesSupportSubmenu');const menuBtn=document.getElementById('salesSupportMenuButton');
  if(submenu)submenu.classList.add('open');
  if(menuBtn){menuBtn.classList.add('open');menuBtn.setAttribute('aria-expanded','true');const arrow=menuBtn.querySelector('.nav-arrow');if(arrow)arrow.textContent='▲'}
}
function persist(){try{const u=new URL(location.href);u.searchParams.set('module',ROUTE);u.searchParams.set('autoload','1');history.replaceState({},'',u.pathname+u.search+u.hash)}catch(_){}}
function deny(){
  try{document.getElementById('bbAddCustomerToast')?.remove();const el=document.createElement('div');el.id='bbAddCustomerToast';el.textContent='Create permission is required for Add Customer.';el.style.cssText='position:fixed;right:18px;bottom:18px;z-index:1000000;background:#7a271a;color:#fff;padding:11px 14px;border-radius:10px;box-shadow:0 10px 30px rgba(0,0,0,.18);font:800 12px Arial';document.body.appendChild(el);setTimeout(()=>el.remove(),2800)}catch(_){}
}
function open(updateUrl=true){
  ensureMenu();if(!canUse()){deny();return false}
  const home=document.getElementById('dashboardHome');const workspace=document.getElementById('moduleWorkspace');const frame=document.getElementById('moduleFrame');
  if(!workspace||!frame)return false;if(home)home.hidden=true;workspace.hidden=false;frame.src=URL;markActive();if(updateUrl!==false)persist();return true;
}
function restore(){
  if(restoreDone)return;let route='';try{route=new URLSearchParams(location.search).get('module')||''}catch(_){}
  if(route!==ROUTE){restoreDone=true;return}
  if(!profile()||!document.getElementById('moduleFrame')){setTimeout(restore,120);return}
  restoreDone=true;open(false);
}
function start(){let tries=0;const tick=()=>{tries+=1;ensureMenu();restore();if(tries<25)setTimeout(tick,200)};tick();window.addEventListener('focus',()=>ensureMenu())}
window.BBAddCustomer={open,ensureMenu,canUse};
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
})();
