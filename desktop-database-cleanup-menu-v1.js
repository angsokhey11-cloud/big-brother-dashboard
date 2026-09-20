/* BIG BROTHER — PC Database Cleanup Menu Extension V1.4
   Desktop only. Adds Master Data > Database Cleanup after Supabase auth is ready.
   Also removes accidental duplicate cleanup buttons. Mobile navigation remains untouched. */
(function(){
  'use strict';
  if(/mobile\.html/i.test(location.pathname))return;
  if(window.BBDesktopDatabaseCleanupMenuV1)return;
  window.BBDesktopDatabaseCleanupMenuV1={installed:true};

  const SB='https://sjfhlaclgmkwwofzstok.supabase.co';
  const KEY='sb_publishable_w762jR65CWwlO30fKQsYOw_6L9grx8S';
  const SESSION_KEY='BB_SUPABASE_DEV_SESSION_V1';
  const CLEANUP_URL='https://angsokhey11-cloud.github.io/big-brother-master-data/database-cleanup.html?embed=1&v=20260920-cashreset1';

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

  function cleanupButtons(submenu){
    const matches=[...submenu.querySelectorAll('button')].filter(btn=>{
      const text=(btn.textContent||'').replace(/\s+/g,' ').trim().toLowerCase();
      return btn.id==='navMasterDatabaseCleanup'||text.includes('database cleanup');
    });
    if(matches.length<=1)return matches[0]||null;
    const keep=matches.find(x=>x.id==='navMasterDatabaseCleanup')||matches[0];
    matches.forEach(x=>{if(x!==keep)x.remove()});
    if(!keep.id)keep.id='navMasterDatabaseCleanup';
    return keep;
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
    const submenu=document.getElementById('masterSubmenu');
    if(!submenu)return false;
    const existing=cleanupButtons(submenu);
    if(existing){
      existing.id='navMasterDatabaseCleanup';
      existing.title='Admin-only Supabase accounting test-data cleanup';
      if(!existing.__bbCleanupBound){
        existing.__bbCleanupBound=true;
        existing.addEventListener('click',event=>{event.preventDefault();openCleanup(existing)});
      }
      return true;
    }
    const check=await access();
    if(!check.ready)return false;
    if(!check.allowed)return true;
    const button=document.createElement('button');
    button.type='button';button.id='navMasterDatabaseCleanup';button.textContent='🧹 Database Cleanup';
    button.title='Admin-only Supabase accounting test-data cleanup';button.__bbCleanupBound=true;
    button.addEventListener('click',()=>openCleanup(button));submenu.appendChild(button);cleanupButtons(submenu);return true;
  }

  let tries=0;const timer=setInterval(async()=>{tries++;const done=await install();if(done||tries>=200)clearInterval(timer)},150);
  const observer=new MutationObserver(()=>{const submenu=document.getElementById('masterSubmenu');if(submenu)cleanupButtons(submenu)});
  observer.observe(document.documentElement,{childList:true,subtree:true});
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',()=>install(),{once:true});else install();
})();