/* BIG BROTHER — PC Database Cleanup Menu Extension V1.1
   Desktop only. Adds Master Data > Database Cleanup after Supabase auth is ready.
   Mobile navigation remains untouched. */
(function(){
  'use strict';
  if(/mobile\.html/i.test(location.pathname))return;
  if(window.BBDesktopDatabaseCleanupMenuV1)return;
  window.BBDesktopDatabaseCleanupMenuV1={installed:true};

  const SB='https://sjfhlaclgmkwwofzstok.supabase.co';
  const KEY='sb_publishable_w762jR65CWwlO30fKQsYOw_6L9grx8S';
  const SESSION_KEY='BB_SUPABASE_DEV_SESSION_V1';
  const CLEANUP_URL='https://angsokhey11-cloud.github.io/big-brother-master-data/database-cleanup.html?embed=1&v=20260916-2';

  function session(){try{return JSON.parse(localStorage.getItem(SESSION_KEY)||'null')}catch(_){return null}}

  async function access(){
    const s=session();
    if(!s?.access_token)return {ready:false,allowed:false};
    try{
      const r=await fetch(SB+'/rest/v1/rpc/bb_database_cleanup_access',{
        method:'POST',
        headers:{apikey:KEY,Authorization:'Bearer '+s.access_token,'Content-Type':'application/json'},
        body:'{}',cache:'no-store'
      });
      if(r.status===401)return {ready:false,allowed:false};
      if(!r.ok)return {ready:true,allowed:false};
      const d=await r.json();
      return {ready:true,allowed:d?.allowed===true};
    }catch(_){return {ready:false,allowed:false}}
  }

  function setActive(button){
    document.querySelectorAll('.nav button.active,.nav a.active').forEach(el=>el.classList.remove('active'));
    button.classList.add('active');
    const master=document.getElementById('masterSubmenu');
    const masterBtn=document.getElementById('masterMenuButton');
    if(master&&masterBtn){
      master.classList.add('open');
      masterBtn.classList.add('open');
      masterBtn.setAttribute('aria-expanded','true');
      const arrow=masterBtn.querySelector('.nav-arrow');if(arrow)arrow.textContent='▲';
    }
  }

  function openCleanup(button){
    const home=document.getElementById('dashboardHome');
    const workspace=document.getElementById('moduleWorkspace');
    const frame=document.getElementById('moduleFrame');
    if(!home||!workspace||!frame)return;
    home.hidden=true;
    workspace.hidden=false;
    frame.src=CLEANUP_URL;
    setActive(button);
  }

  async function install(){
    if(document.getElementById('navMasterDatabaseCleanup'))return true;
    const submenu=document.getElementById('masterSubmenu');
    if(!submenu)return false;

    const check=await access();
    if(!check.ready)return false; // Supabase auth is still starting; keep retrying.
    if(!check.allowed)return true; // Auth is ready and this user is not permitted.

    const button=document.createElement('button');
    button.type='button';
    button.id='navMasterDatabaseCleanup';
    button.textContent='🧹 Database Cleanup';
    button.title='Admin-only Supabase operational test-data cleanup';
    button.addEventListener('click',()=>openCleanup(button));
    submenu.appendChild(button);
    return true;
  }

  let tries=0;
  const timer=setInterval(async()=>{
    tries++;
    const done=await install();
    if(done||tries>=200)clearInterval(timer);
  },150);

  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',()=>install(),{once:true});
  else install();
})();