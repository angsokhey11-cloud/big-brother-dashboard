/* BIG BROTHER — PC Telegram Manager Menu Extension V1.0
   Desktop only. Adds Admin Work > Telegram Manager.
   Notification Center remains in its own repository and is loaded inside the Dashboard workspace.
   Uses the existing BIG BROTHER Supabase session and exposes the menu to admins only. */
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
    const matches=[...submenu.querySelectorAll('button')].filter(btn=>{
      const text=(btn.textContent||'').replace(/\s+/g,' ').trim().toLowerCase();
      return btn.id==='navTelegramManager'||text.includes('telegram manager')||text.includes('notification center');
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
    frame.src=TELEGRAM_MANAGER_URL;
    setActive(button);
  }

  function bind(button){
    button.type='button';
    button.id='navTelegramManager';
    button.textContent='📨 Telegram Manager';
    button.title='Manage BIG BROTHER Telegram notification routing, rules and delivery logs';
    if(button.__bbTelegramManagerBound)return;
    button.__bbTelegramManagerBound=true;
    button.addEventListener('click',event=>{
      event.preventDefault();
      openTelegramManager(button);
    });
  }

  async function install(){
    const submenu=document.getElementById('adminWorkSubmenu');
    if(!submenu)return false;

    const existing=existingButton(submenu);
    if(existing){bind(existing);return true;}

    const check=await adminAccess();
    if(!check.ready)return false;
    if(!check.allowed)return true;

    const button=document.createElement('button');
    bind(button);

    const permissions=document.getElementById('navAdminUserPermissions');
    if(permissions&&permissions.parentElement===submenu){
      permissions.insertAdjacentElement('afterend',button);
    }else{
      submenu.appendChild(button);
    }
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
