/* BIG BROTHER — Dashboard Supabase Auth & Permission Adapter V1.1 */
(function(){
  'use strict';

  const SUPABASE_URL='https://sjfhlaclgmkwwofzstok.supabase.co';
  const SUPABASE_KEY='sb_publishable_w762jR65CWwlO30fKQsYOw_6L9grx8S';
  const SESSION_KEY='BB_SUPABASE_DEV_SESSION_V1';

  const ROUTE_ACCESS={
    'customers-editor':             {module:'customers_editor',action:'view'},
    'customers-add':                {module:'customers_editor',action:'create'},
    'customers-map':                {module:'customers_editor',action:'view'},
    'customers-details':            {module:'customers_editor',action:'view'},
    'clients-editor':               {module:'clients_editor',action:'view'},
    'clients-add':                  {module:'clients_editor',action:'create'},
    'clients-details':              {module:'clients_editor',action:'view'},
    'products-editor':              {module:'products_editor',action:'view'},
    'products-add':                 {module:'products_editor',action:'create'},
    'products-details':             {module:'products_editor',action:'view'},

    'sales-support-calculator':     {module:'sales_support',action:'view'},
    'sales-support-request-delivery':{module:'sales_support',action:'create'},
    'sales-support-your-customer':  {module:'sales_support',action:'view'},
    'sales-support-successful-delivery':{module:'sales_support',action:'view'},

    'invoice':                      {module:'invoice_generator',action:'create'},
    'history':                      {module:'invoice_history',action:'view'},
    'sale-return':                  {module:'invoice_reversal',action:'view'},
    'payment-history':              {module:'payment_history',action:'view'},
    'daily-sale-summary':           {module:'daily_sale_summary',action:'view'},
    'daily-cash-collection':        {module:'daily_cash_collection',action:'view'},

    'purchase-create':              {module:'purchase_create',action:'create'},
    'purchase-history':             {module:'purchase_history',action:'view'},
    'purchase-payable':             {module:'purchase_payable',action:'view'},
    'purchase-payment-history':     {module:'purchase_payment_history',action:'view'},

    'expense-add':                  {module:'expenses',action:'create'},
    'expense-accrued':              {module:'expenses',action:'view'},
    'expense-history':              {module:'expenses',action:'view'},
    'expense-monthly-report':       {module:'expenses',action:'view'},

    'stock-keyin':                  {module:'Stock Management',action:'view'},
'stock-damaged':                {module:'Stock Management',action:'view'},

'stock-damaged-report':         {module:'Stock Management',action:'view'},
'stock-damaged-cleared':        {module:'Stock Management',action:'view'},
'stock-damaged-accounting':     {module:'Stock Management',action:'view'},

'stock-report':                 {module:'Stock Report',action:'view'},
    'batch-report':                 {module:'Stock Report',action:'view'},
    'closed-batch':                 {module:'Stock Report',action:'view'},
    'stock-transactions':           {module:'Stock Report',action:'view'},

    'ar-all':                       {module:'accounts_receivable',action:'view'},
    'ar-your':                      {module:'accounts_receivable',action:'view'},
    'ar-payment-history':           {module:'ar_payment_history',action:'view'},
    'ar-daily-receivable-cash':     {module:'daily_receivable_cash_summary',action:'view'},

    'admin-pending-receivable':     {module:'admin_work',action:'view'},
    'admin-pending-daily-cash':     {module:'admin_work',action:'view'},
    'admin-pending-deposit':        {module:'admin_work',action:'view'},
    'admin-deposit-history':        {module:'admin_work',action:'view'},
    'admin-staff-request':          {module:'admin_work',action:'view'},
    'admin-request':                {module:'admin_work',action:'view'},
    'admin-user-permissions':       {module:'admin_work',action:'view',adminOnly:true}
  };

  let session=null;
  let profile=null;
  let originalLoadWorkspace=null;
  let started=false;

  function readSession(){
    try{return JSON.parse(localStorage.getItem(SESSION_KEY)||'null')}
    catch(_){return null}
  }

  function saveSession(value){
    session=value||null;
    try{
      if(!value){localStorage.removeItem(SESSION_KEY);return;}
      if(!value.expires_at&&value.expires_in){
        value.expires_at=Math.floor(Date.now()/1000)+Number(value.expires_in);
      }
      localStorage.setItem(SESSION_KEY,JSON.stringify(value));
    }catch(_){}
  }

  async function parse(response){
    const text=await response.text();
    let data={};
    try{data=text?JSON.parse(text):{}}
    catch(_){data={message:text}}
    if(!response.ok){
      throw new Error(data.message||data.error_description||data.error||('Supabase request failed ('+response.status+')'));
    }
    return data;
  }

  async function refreshSession(){
    const current=readSession();
    if(!current?.refresh_token)throw new Error('Please sign in to BIG BROTHER.');
    const response=await fetch(SUPABASE_URL+'/auth/v1/token?grant_type=refresh_token',{
      method:'POST',
      headers:{apikey:SUPABASE_KEY,'Content-Type':'application/json'},
      body:JSON.stringify({refresh_token:current.refresh_token}),
      cache:'no-store'
    });
    const next=await parse(response);
    saveSession(next);
    return next;
  }

  async function ensureSession(){
    session=readSession();
    if(!session?.access_token)throw new Error('Please sign in to BIG BROTHER.');
    const now=Math.floor(Date.now()/1000);
    if(session.expires_at&&Number(session.expires_at)<now+45){
      await refreshSession();
    }
    return session;
  }

  async function rpc(fn,args={}){
    await ensureSession();
    let response=await fetch(SUPABASE_URL+'/rest/v1/rpc/'+fn,{
      method:'POST',
      headers:{apikey:SUPABASE_KEY,Authorization:'Bearer '+session.access_token,'Content-Type':'application/json'},
      body:JSON.stringify(args||{}),
      cache:'no-store'
    });
    if(response.status===401){
      await refreshSession();
      response=await fetch(SUPABASE_URL+'/rest/v1/rpc/'+fn,{
        method:'POST',
        headers:{apikey:SUPABASE_KEY,Authorization:'Bearer '+session.access_token,'Content-Type':'application/json'},
        body:JSON.stringify(args||{}),
        cache:'no-store'
      });
    }
    return parse(response);
  }

  async function signIn(email,password){
    const response=await fetch(SUPABASE_URL+'/auth/v1/token?grant_type=password',{
      method:'POST',
      headers:{apikey:SUPABASE_KEY,'Content-Type':'application/json'},
      body:JSON.stringify({email:String(email||'').trim(),password:String(password||'')}),
      cache:'no-store'
    });
    const next=await parse(response);
    saveSession(next);
    return next;
  }

  async function signOut(){
    const current=readSession();
    try{
      if(current?.access_token){
        await fetch(SUPABASE_URL+'/auth/v1/logout',{
          method:'POST',
          headers:{apikey:SUPABASE_KEY,Authorization:'Bearer '+current.access_token},
          cache:'no-store'
        });
      }
    }catch(_){}
    saveSession(null);
    location.href=location.pathname;
  }

  function key(value){return String(value||'').trim().toLowerCase()}

  function grantFor(moduleKey){
    if(profile?.user?.isAdmin)return {canView:true,canCreate:true,canEdit:true,canApprove:true};
    const modules=Array.isArray(profile?.modules)?profile.modules:[];
    const wildcard=modules.find(m=>key(m.moduleKey)==='*');
    if(wildcard)return wildcard;
    return modules.find(m=>key(m.moduleKey)===key(moduleKey))||null;
  }

  function canRoute(route){
    const rule=ROUTE_ACCESS[route];
    if(!rule)return false;
    if(rule.adminOnly)return profile?.user?.isAdmin===true;
    const grant=grantFor(rule.module);
    if(!grant)return false;
    const field={view:'canView',create:'canCreate',edit:'canEdit',approve:'canApprove'}[rule.action]||'canView';
    return grant[field]===true;
  }

  function extractRoute(el){
    const code=el.getAttribute('onclick')||'';
    const match=code.match(/loadWorkspace\(\s*['\"]([^'\"]+)['\"]/);
    return match?match[1]:'';
  }

  function installStyles(){
    if(document.getElementById('bbDashboardAuthStyle'))return;
    const style=document.createElement('style');
    style.id='bbDashboardAuthStyle';
    style.textContent=`
      .bb-auth-hidden{display:none!important}
      .bb-auth-overlay{position:fixed;inset:0;z-index:999999;background:#eef3f8;display:flex;align-items:center;justify-content:center;padding:18px}
      .bb-auth-card{width:min(430px,100%);background:#fff;border:1px solid #d9e2ef;border-radius:18px;padding:24px;box-shadow:0 18px 55px rgba(18,56,97,.16)}
      .bb-auth-brand{color:#17457a;font-size:24px;font-weight:900;letter-spacing:.5px}.bb-auth-sub{margin:6px 0 20px;color:#667085;font-size:13px;line-height:1.45}
      .bb-auth-field{display:block;margin:10px 0 5px;color:#445b76;font-size:11px;font-weight:900;text-transform:uppercase}.bb-auth-input{width:100%;min-height:46px;border:1px solid #cbd8e7;border-radius:10px;padding:10px 12px;font:inherit;color:#172b4d;background:#fff}
      .bb-auth-btn{width:100%;min-height:46px;border:0;border-radius:10px;margin-top:15px;background:#17457a;color:#fff;font-weight:900;cursor:pointer}.bb-auth-btn:disabled{opacity:.55;cursor:wait}
      .bb-auth-error{min-height:18px;margin-top:10px;color:#b42318;font-size:12px;font-weight:700}.bb-auth-note{margin-top:12px;color:#7a8da1;font-size:10px;line-height:1.45}
      .bb-user-tools{display:flex;align-items:center;gap:8px;flex-wrap:wrap;justify-content:flex-end}.bb-user-signout{border:0;border-radius:999px;background:#fff0ef;color:#b42318;padding:8px 11px;font-size:11px;font-weight:900;cursor:pointer}
      .bb-access-toast{position:fixed;right:18px;bottom:18px;z-index:999998;background:#7a271a;color:#fff;padding:11px 14px;border-radius:10px;box-shadow:0 10px 30px rgba(0,0,0,.18);font-size:12px;font-weight:800}
    `;
    document.head.appendChild(style);
  }

  function toast(message){
    document.querySelector('.bb-access-toast')?.remove();
    const el=document.createElement('div');
    el.className='bb-access-toast';
    el.textContent=message;
    document.body.appendChild(el);
    setTimeout(()=>el.remove(),2600);
  }

  function showLogin(message=''){
    document.getElementById('bbDashboardLogin')?.remove();
    const overlay=document.createElement('div');
    overlay.id='bbDashboardLogin';
    overlay.className='bb-auth-overlay';
    overlay.innerHTML=`<form class="bb-auth-card" id="bbDashboardLoginForm">
      <div class="bb-auth-brand">BIG BROTHER</div>
      <div class="bb-auth-sub">Sign in to the Accounting System with your Supabase user account.</div>
      <label class="bb-auth-field" for="bbLoginEmail">Email</label>
      <input class="bb-auth-input" id="bbLoginEmail" type="email" autocomplete="username" required>
      <label class="bb-auth-field" for="bbLoginPassword">Password</label>
      <input class="bb-auth-input" id="bbLoginPassword" type="password" autocomplete="current-password" required>
      <button class="bb-auth-btn" id="bbLoginButton" type="submit">Sign In</button>
      <div class="bb-auth-error" id="bbLoginError"></div>
      <div class="bb-auth-note">Only BIG BROTHER accounts approved in Supabase can access this dashboard.</div>
    </form>`;
    document.body.appendChild(overlay);
    const err=document.getElementById('bbLoginError');
    if(message)err.textContent=message;
    const form=document.getElementById('bbDashboardLoginForm');
    form.addEventListener('submit',async event=>{
      event.preventDefault();
      const btn=document.getElementById('bbLoginButton');
      err.textContent='';
      btn.disabled=true;
      btn.textContent='Signing in…';
      try{
        await signIn(document.getElementById('bbLoginEmail').value,document.getElementById('bbLoginPassword').value);
        profile=await rpc('bb_current_access_profile');
        overlay.remove();
        activateDashboard();
      }catch(error){
        err.textContent=error?.message||String(error);
        btn.disabled=false;
        btn.textContent='Sign In';
      }
    });
  }

  function applyRouteVisibility(){
    const launchers=[...document.querySelectorAll('[onclick*="loadWorkspace"]')];
    launchers.forEach(el=>{
      const route=extractRoute(el);
      if(!route)return;
      const allowed=canRoute(route);
      el.classList.toggle('bb-auth-hidden',!allowed);
      if(el.closest('.module')&&el.matches('a,button')){
        el.closest('.module').classList.toggle('bb-auth-hidden',!allowed);
      }
    });

    [...document.querySelectorAll('.nested-nav-group')].reverse().forEach(group=>{
      const launch=[...group.querySelectorAll('[onclick*="loadWorkspace"]')];
      if(launch.length&&!launch.some(el=>!el.classList.contains('bb-auth-hidden'))){
        group.classList.add('bb-auth-hidden');
      }
    });

    [...document.querySelectorAll('.nav-group')].reverse().forEach(group=>{
      const launch=[...group.querySelectorAll('[onclick*="loadWorkspace"]')];
      if(launch.length&&!launch.some(el=>!el.classList.contains('bb-auth-hidden'))){
        group.classList.add('bb-auth-hidden');
      }
    });
  }

  function updateUserUI(){
    const topbar=document.querySelector('#dashboardHome .topbar');
    const pill=topbar?.querySelector('.system-pill');
    const user=profile?.user||{};
    const staff=profile?.staff||{};
    const locationCount=Array.isArray(profile?.locations)?profile.locations.length:0;
    const displayName=staff.staffName||user.email||'BIG BROTHER User';
    if(pill){
      pill.textContent=(user.isAdmin?'ADMIN':'USER')+' • '+locationCount+' LOCATION'+(locationCount===1?'':'S');
      pill.title=displayName;
    }
    if(topbar&&!document.getElementById('bbUserTools')){
      const tools=document.createElement('div');
      tools.id='bbUserTools';
      tools.className='bb-user-tools';
      const name=document.createElement('div');
      name.className='system-pill';
      name.textContent=displayName;
      const btn=document.createElement('button');
      btn.type='button';
      btn.className='bb-user-signout';
      btn.textContent='Sign Out';
      btn.addEventListener('click',signOut);
      tools.append(name,btn);
      topbar.appendChild(tools);
    }
  }

  function installWorkspaceGuard(){
    if(originalLoadWorkspace)return;
    originalLoadWorkspace=window.loadWorkspace;
    window.loadWorkspace=function(moduleName,updateUrl=true){
      if(!canRoute(moduleName)){
        toast('Access denied for this module.');
        return false;
      }
      return originalLoadWorkspace.call(window,moduleName,updateUrl);
    };
  }

  function activateDashboard(){
    installWorkspaceGuard();
    applyRouteVisibility();
    updateUserUI();
    window.openInitialWorkspace();
  }

  async function start(){
    if(started)return;
    started=true;
    installStyles();
    try{
      await ensureSession();
      profile=await rpc('bb_current_access_profile');
      activateDashboard();
    }catch(error){
      saveSession(null);
      showLogin(error?.message&&error.message!=='Please sign in to BIG BROTHER.'?error.message:'');
    }
  }

  window.BBDashboardAdapter={start,signOut,canRoute,getProfile:()=>profile,getSession:()=>readSession()};
})();
