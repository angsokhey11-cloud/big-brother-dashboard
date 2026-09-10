/* BIG BROTHER — Supabase Company Features Dashboard Integration V1.3 */
(function(){
'use strict';
const EXTRA={
  'customer-credit-control':{module:'customer_credit_control',url:'https://angsokhey11-cloud.github.io/big-brother-admin-work/company-control.html?embed=1&view=credit&v=1',button:'navCustomerCredit'},
  'stock-alerts':{module:'stock_alerts',url:'https://angsokhey11-cloud.github.io/big-brother-admin-work/company-control.html?embed=1&view=stock-alerts&v=1',button:'navStockAlerts'},
  'management-control-center':{module:'management_control_center',adminOnly:true,url:'https://angsokhey11-cloud.github.io/big-brother-admin-work/company-control.html?embed=1&view=management&v=1',button:'navManagementControl'},
  'system-activity':{module:'system_activity',adminOnly:true,url:'https://angsokhey11-cloud.github.io/big-brother-admin-work/company-control.html?embed=1&view=activity&v=1',button:'navSystemActivity'},
  'notification-center':{module:'notification_center',url:'https://angsokhey11-cloud.github.io/big-brother-admin-work/company-control.html?embed=1&view=notifications&v=1',button:'navNotificationCenter'},

  /* Damaged Stock has NO duplicate key-in page. Stock In-Out is the only key-in workspace. */
  'stock-damaged':{module:'Stock Management',url:'https://angsokhey11-cloud.github.io/big-brother-stock-report/damage-stock-report.html?embed=1&v=20260910-4',button:'navStockDamagedReport'},
  'stock-damaged-report':{module:'Stock Management',url:'https://angsokhey11-cloud.github.io/big-brother-stock-report/damage-stock-report.html?embed=1&v=20260910-4',button:'navStockDamagedReport'},
  'stock-damaged-cleared':{module:'Stock Management',url:'https://angsokhey11-cloud.github.io/big-brother-stock-report/damaged-stock-cleared.html?embed=1&v=20260910-4',button:'navStockDamagedCleared'}
};
let baseLoad=window.loadWorkspace,baseInitial=window.openInitialWorkspace,badgeTimer=null,guardedLoad=null,damagedObserver=null;
const key=v=>String(v||'').trim().toLowerCase();
function profile(){return window.BBDashboardAdapter?.getProfile?.()||null}
function can(route){const r=EXTRA[route],p=profile();if(!r||!p)return false;if(r.adminOnly&&!p.user?.isAdmin)return false;if(p.user?.isAdmin)return true;const mods=Array.isArray(p.modules)?p.modules:[],g=mods.find(x=>key(x.moduleKey)===key(r.module))||mods.find(x=>key(x.moduleKey)==='*');return !!g?.canView}
function addAfter(id,html){const el=document.getElementById(id);if(el&&!document.getElementById((html.match(/id="([^"]+)/)||[])[1]||''))el.insertAdjacentHTML('afterend',html)}
function installDamagedStockMenuFix(){
  /* Remove the old child even if the legacy dashboard rebuilds it later. */
  const duplicate=document.getElementById('navStockDamaged');
  if(duplicate)duplicate.remove();
  const report=document.getElementById('navStockDamagedReport');
  const cleared=document.getElementById('navStockDamagedCleared');
  if(report)report.textContent='📊 Damage Stock Report';
  if(cleared)cleared.textContent='✅ Damaged Stock Cleared';
}
function watchDamagedStockMenu(){
  if(damagedObserver)return;
  damagedObserver=new MutationObserver(()=>installDamagedStockMenuFix());
  damagedObserver.observe(document.documentElement,{childList:true,subtree:true});
}
function install(){
  try{Object.entries(EXTRA).forEach(([k,v])=>MODULE_URLS[k]=v.url)}catch(e){console.error('Company routes:',e)}
  addAfter('navCustomerDetails','<button type="button" hidden class="bb-company-route" id="navCustomerCredit" onclick="BBCompanyFeatures.open(\'customer-credit-control\')">💳 Customer Credit Control</button>');
  addAfter('navStockTransactions','<button type="button" hidden class="bb-company-route" id="navStockAlerts" onclick="BBCompanyFeatures.open(\'stock-alerts\')">🚨 Smart Stock Alerts</button>');
  addAfter('navAdminRequest','<button type="button" hidden class="bb-company-route" id="navManagementControl" onclick="BBCompanyFeatures.open(\'management-control-center\')">📊 Management Control Center</button><button type="button" hidden class="bb-company-route" id="navSystemActivity" onclick="BBCompanyFeatures.open(\'system-activity\')">🕘 System Activity</button><button type="button" hidden class="bb-company-route" id="navNotificationCenter" onclick="BBCompanyFeatures.open(\'notification-center\')">🔔 Notification Center</button>');
  installDamagedStockMenuFix();watchDamagedStockMenu();
  const style=document.createElement('style');style.textContent='#navStockDamaged{display:none!important}.bb-notify-quick{border:0;border-radius:999px;background:#17457a;color:#fff;padding:8px 11px;font-size:11px;font-weight:900;cursor:pointer}.bb-notify-quick[data-count="0"]{background:#e5effc;color:#17457a}';document.head.appendChild(style);
}
function setOpen(subId,btnId){const sub=document.getElementById(subId),btn=document.getElementById(btnId);if(sub)sub.classList.add('open');if(btn){btn.classList.add('open');btn.setAttribute('aria-expanded','true');const a=btn.querySelector('.nav-arrow');if(a)a.textContent='▲'}}
function highlight(route){
  document.querySelectorAll('.nav-submenu button.active').forEach(x=>x.classList.remove('active'));
  const id=EXTRA[route]?.button;document.getElementById(id)?.classList.add('active');
  if(route==='customer-credit-control'){
    setOpen('masterSubmenu','masterMenuButton');setOpen('customersEditorSubmenu','customersEditorMenuButton');
  }else if(route==='stock-alerts'){
    setOpen('stockSubmenu','stockMenuButton');
  }else if(route==='stock-damaged'||route==='stock-damaged-report'||route==='stock-damaged-cleared'){
    setOpen('stockSubmenu','stockMenuButton');setOpen('damagedStockSubmenu','damagedStockMenuButton');
  }else{
    setOpen('adminWorkSubmenu','adminWorkMenuButton');
  }
}
function open(route,updateUrl=true){
  const actual=route==='stock-damaged'?'stock-damaged-report':route;
  if(!can(actual)){alert('Access denied for this function.');return false}
  baseLoad(actual,updateUrl);highlight(actual);return true
}
function routeAwareLoad(route,updateUrl=true){if(EXTRA[route])return open(route,updateUrl);return guardedLoad?guardedLoad.call(window,route,updateUrl):baseLoad(route,updateUrl)}
function installRouteBridge(){if(window.loadWorkspace===routeAwareLoad)return;guardedLoad=window.loadWorkspace;window.loadWorkspace=routeAwareLoad}
function refreshVisibility(){Object.keys(EXTRA).forEach(r=>{const b=document.getElementById(EXTRA[r].button);if(b)b.hidden=!can(r)});installDamagedStockMenuFix();installBell()}
async function unread(){try{const s=JSON.parse(localStorage.getItem('BB_SUPABASE_DEV_SESSION_V1')||'null');if(!s?.access_token||!can('notification-center'))return 0;const r=await fetch('https://sjfhlaclgmkwwofzstok.supabase.co/rest/v1/rpc/bb_notification_unread_count',{method:'POST',headers:{apikey:'sb_publishable_w762jR65CWwlO30fKQsYOw_6L9grx8S',Authorization:'Bearer '+s.access_token,'Content-Type':'application/json'},body:'{}',cache:'no-store'});if(!r.ok)return 0;return Number(await r.json()||0)}catch(_){return 0}}
async function refreshBell(){const b=document.getElementById('bbNotificationQuick');if(!b)return;const n=await unread();b.dataset.count=String(n);b.textContent=n>0?'🔔 '+n:'🔔 Notifications'}
function installBell(){const top=document.querySelector('#dashboardHome .topbar'),tools=document.getElementById('bbUserTools');if(!top||!can('notification-center'))return;let b=document.getElementById('bbNotificationQuick');if(!b){b=document.createElement('button');b.id='bbNotificationQuick';b.className='bb-notify-quick';b.type='button';b.onclick=()=>open('notification-center');(tools||top).prepend(b)}refreshBell();if(!badgeTimer)badgeTimer=setInterval(refreshBell,60000)}
window.openInitialWorkspace=function(){
  refreshVisibility();
  const q=new URLSearchParams(location.search),m=q.get('module')||'';
  if(m==='stock-damaged'&&q.get('autoload')==='1'&&can('stock-damaged-report')){open('stock-damaged-report',false);return}
  if(EXTRA[m]&&q.get('autoload')==='1'&&can(m)){open(m,false);return}
  return baseInitial.apply(window,arguments)
};
window.BBCompanyFeatures={open,can,refreshVisibility,refreshBell,installRouteBridge};
install();
window.addEventListener('DOMContentLoaded',()=>setTimeout(()=>{installRouteBridge();refreshVisibility();installDamagedStockMenuFix()},0));
})();