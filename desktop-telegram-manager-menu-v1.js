/* BIG BROTHER — Desktop Telegram Manager Menu V1.1
   Keep Telegram Manager and LIVE Notification Center as separate menu entries.
   Use a single owned click handler and the dashboard iframe switch token to
   prevent a stale first-click navigation from reopening Notification Center.
   Menu remains admin-only; no Telegram/billing/database writes here. */
(function(){
  'use strict';
  if(/mobile\.html/i.test(location.pathname))return;
  if(window.BBDesktopTelegramManagerMenuV1)return;
  window.BBDesktopTelegramManagerMenuV1={installed:true};

  const SB='https://sjfhlaclgmkwwofzstok.supabase.co';
  const KEY='sb_publishable_w762jR65CWwlO30fKQsYOw_6L9grx8S';
  const SESSION_KEY='BB_SUPABASE_DEV_SESSION_V1';
  const TELEGRAM_MANAGER_URL='https://angsokhey11-cloud.github.io/big-brother-notification-center/?embed=1&v=20260916-1';

  function session(){
    try{return JSON.parse(localStorage.getItem(SESSION_KEY)||'null')}catch(_){return null}
  }

  async function adminAccess(){
    // Dashboard already has an authenticated access profile after login.
    // Avoid a redundant permissions RPC on every menu-install retry.
    const profile=window.BBDashboardAdapter?.getProfile?.();
    if(profile?.user)return {ready:true,allowed:profile.user.isAdmin===true};
    const s=session();
    if(!s?.access_token)return {ready:false,allowed:false};
    try{
      const r=await fetch(SB+'/rest/v1/rpc/bb_current_access_profile',{
        method:'POST',
        headers:{apikey:KEY,Authorization:'Bearer '+s.access_token,'Content-Type':'application/json'},
        body:'{}',cache:'no-store'
      });
      if(r.status===401)return {ready:false,allowed:false};
      if(!r.ok)return {ready:true,allowed:false};
      const d=await r.json();
      return {ready:true,allowed:d?.user?.isAdmin===true};
    }catch(_){
      return {ready:false,allowed:false};
    }
  }

  function existingButton(submenu){
    // The original extension *renamed* the live Notification Center button,
    // but its inline BBCompanyFeatures.open('notification-center') survived.
    // Never repurpose that button; Telegram Manager gets a separate button.
    const matches=[...submenu.querySelectorAll('button')].filter(btn=>{
      const label=(btn.textContent||'').replace(/\s+/g,' ').trim().toLowerCase();
      return btn.id==='navTelegramManager'||label.includes('telegram manager');
    });
    if(!matches.length)return null;
    const keep=matches.find(x=>x.id==='navTelegramManager')||matches[0];
    matches.forEach(x=>{if(x!==keep)x.remove()});
    keep.id='navTelegramManager';
    return keep;
  }

  function setActive(button){
    document.querySelectorAll('.nav button.active,.nav a.active').forEach(el=>el.classList.remove('active'));
    button.classList.add('active');

    const submenu=document.getElementById('adminWorkSubmenu');
    const menuButton=document.getElementById('adminWorkMenuButton');
    if(submenu&&menuButton){
      submenu.classList.add('open');
      menuButton.classList.add('open');
      menuButton.setAttribute('aria-expanded','true');
      const arrow=menuButton.querySelector('.nav-arrow');
      if(arrow)arrow.textContent='▲';
    }
  }

  function openTelegramManager(button){
    const home=document.getElementById('dashboardHome');
    const workspace=document.getElementById('moduleWorkspace');
    const frame=document.getElementById('moduleFrame');
    if(!home||!workspace||!frame)return;

    home.hidden=true;
    workspace.hidden=false;

    // Cooperate with the V3.40 Dashboard's existing module-switch token.
    // A previous loadWorkspace('notification-center') may still have a
    // requestAnimationFrame callback queued; invalidate it before navigation.
    const sameModule=frame.dataset.module==='telegram-manager'&&
      String(frame.src||'').includes('/big-brother-notification-center/');
    if(!sameModule){
      const token=String(Number(frame.dataset.bbSwitchToken||0)+1);
      frame.dataset.bbSwitchToken=token;
      frame.dataset.module='telegram-manager';
      frame.src='about:blank';
      requestAnimationFrame(()=>{
        if(frame.dataset.bbSwitchToken===token&&
           frame.dataset.module==='telegram-manager'&&
           !workspace.hidden){
          frame.src=TELEGRAM_MANAGER_URL;
        }
      });
    }

    // An old notification-center URL must not restore the wrong page
    // when the dashboard is refreshed after opening Telegram Manager.
    try{
      const url=new URL(location.href);
      url.searchParams.delete('module');
      url.searchParams.delete('autoload');
      history.replaceState(null,'',url.pathname+url.search+url.hash);
    }catch(_){}
    setActive(button);
  }

  function bind(button){
    button.type='button';
    button.id='navTelegramManager';
    button.textContent='📨 Telegram Manager';
    button.title='Manage BIG BROTHER Telegram notification routing, rules and delivery logs';
    // Defensive cleanup for any preexisting Telegram button with an old
    // inline Notification Center route. No double-click/double-navigation.
    button.removeAttribute('onclick');
    button.onclick=null;
    if(button.__bbTelegramManagerBound)return;
    button.__bbTelegramManagerBound=true;
    button.addEventListener('click',event=>{
      event.preventDefault();
      event.stopImmediatePropagation(); // own this action, including the first click
      openTelegramManager(button);
    },true);
  }

  async function install(){
    const submenu=document.getElementById('adminWorkSubmenu');
    if(!submenu)return false;

    const check=await adminAccess();
    if(!check.ready)return false;
    const existing=existingButton(submenu);
    if(!check.allowed){
      if(existing)existing.remove();
      return true;
    }
    if(existing){bind(existing);return true;}

    // The timer and DOMContentLoaded install calls can overlap while login
    // is resolving. Recheck after awaited access to prevent duplicate menus.
    const again=existingButton(submenu);
    if(again){bind(again);return true;}

    const button=document.createElement('button');
    bind(button);
    const notification=document.getElementById('navNotificationCenter');
    const permissions=document.getElementById('navAdminUserPermissions');
    const anchor=notification?.parentElement===submenu?notification:
      permissions?.parentElement===submenu?permissions:null;
    if(anchor)anchor.insertAdjacentElement('afterend',button);
    else submenu.appendChild(button);
    return true;
  }

  let tries=0;
  const timer=setInterval(async()=>{
    tries++;
    const done=await install();
    if(done||tries>=200)clearInterval(timer);
  },150);

  if(document.readyState==='loading'){
    document.addEventListener('DOMContentLoaded',()=>install(),{once:true});
  }else{
    install();
  }
})();
