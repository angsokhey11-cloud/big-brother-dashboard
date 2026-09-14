/* BIG BROTHER — Sales Support Your Stock menu V1.3 */
(function(){
'use strict';

const ROUTE='sales-support-your-stock';
const URL='https://angsokhey11-cloud.github.io/big-brother-sales-support/your-stock.html?embed=1&v=20260914-4';
const LIVE_REFRESH_MS=10000;
let restoreDone=false;
let liveTimer=null;

const key=v=>String(v||'').trim().toLowerCase();
function profile(){return window.BBDashboardAdapter?.getProfile?.()||null}
function canView(){
  const p=profile();
  if(!p)return false;
  if(p?.user?.isAdmin===true)return true;
  const mods=Array.isArray(p?.modules)?p.modules:[];
  const g=mods.find(x=>key(x.moduleKey)==='*')||mods.find(x=>key(x.moduleKey)==='route.'+ROUTE);
  return g?.canView===true;
}
function hideLegacyDelivery(){
  ['navSalesSupportRequestDelivery','navSalesSupportSuccessfulDelivery'].forEach(id=>{
    const el=document.getElementById(id);
    if(el){el.hidden=true;el.style.display='none';el.setAttribute('aria-hidden','true')}
  });
}
function ensureMenu(){
  hideLegacyDelivery();
  const submenu=document.getElementById('salesSupportSubmenu');
  if(!submenu)return false;
  let btn=document.getElementById('navSalesSupportYourStock');
  if(!btn){
    btn=document.createElement('button');
    btn.type='button';
    btn.id='navSalesSupportYourStock';
    btn.textContent='📦 Your Stock';
    btn.addEventListener('click',()=>open(true));
    const customer=document.getElementById('navSalesSupportYourCustomer');
    if(customer?.parentNode===submenu)customer.insertAdjacentElement('afterend',btn);
    else submenu.appendChild(btn);
  }
  const allowed=canView();
  btn.hidden=!allowed;
  btn.style.display=allowed?'':'none';
  return true;
}
function markActive(){
  document.querySelectorAll('.nav-submenu button.active,.shell-nav-link.active').forEach(el=>el.classList.remove('active'));
  document.getElementById('navSalesSupportYourStock')?.classList.add('active');
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
    history.replaceState({},'',u.pathname+u.search+u.hash);
  }catch(_){}
}
function deny(){
  try{
    const old=document.getElementById('bbYourStockToast');
    old?.remove();
    const el=document.createElement('div');
    el.id='bbYourStockToast';
    el.textContent='Access denied for Your Stock.';
    el.style.cssText='position:fixed;right:18px;bottom:18px;z-index:1000000;background:#7a271a;color:#fff;padding:11px 14px;border-radius:10px;box-shadow:0 10px 30px rgba(0,0,0,.18);font:800 12px Arial';
    document.body.appendChild(el);
    setTimeout(()=>el.remove(),2600);
  }catch(_){}
}
function refreshFrame(frame){
  try{
    if(!frame||document.visibilityState==='hidden')return;
    const src=String(frame.getAttribute('src')||'');
    if(!src.includes('/big-brother-sales-support/your-stock.html'))return;
    const btn=frame.contentDocument?.getElementById('refreshBtn');
    if(btn&&!btn.disabled)btn.click();
  }catch(_){}
}
function startLiveRefresh(frame){
  if(liveTimer){clearInterval(liveTimer);liveTimer=null}
  const arm=()=>{
    refreshFrame(frame);
    liveTimer=setInterval(()=>refreshFrame(frame),LIVE_REFRESH_MS);
  };
  try{
    frame.addEventListener('load',()=>setTimeout(arm,500),{once:true});
  }catch(_){}
  setTimeout(()=>refreshFrame(frame),1200);
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
  startLiveRefresh(frame);
  markActive();
  if(updateUrl!==false)persist();
  return true;
}
function restore(){
  if(restoreDone)return;
  let route='';
  try{route=new URLSearchParams(location.search).get('module')||''}catch(_){}
  if(route!==ROUTE){restoreDone=true;return}
  if(!profile()||!document.getElementById('moduleFrame')){setTimeout(restore,120);return}
  restoreDone=true;
  open(false);
}
function start(){
  let tries=0;
  const tick=()=>{
    tries+=1;
    ensureMenu();
    restore();
    if(tries<25)setTimeout(tick,200);
  };
  tick();
  window.addEventListener('focus',()=>{
    ensureMenu();
    refreshFrame(document.getElementById('moduleFrame'));
  });
  document.addEventListener('visibilitychange',()=>{
    if(document.visibilityState==='visible')refreshFrame(document.getElementById('moduleFrame'));
  });
}

window.BBYourStock={open,ensureMenu,canView,refresh:()=>refreshFrame(document.getElementById('moduleFrame'))};
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});
else start();
})();
