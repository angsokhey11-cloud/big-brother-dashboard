/* BIG BROTHER — Supabase Company Features Dashboard Integration V1.4 */
(function(){
'use strict';
const EXTRA={
  'customer-credit-control':{module:'customer_credit_control',url:'https://angsokhey11-cloud.github.io/big-brother-admin-work/company-control.html?embed=1&view=credit&v=1',button:'navCustomerCredit'},
  'stock-alerts':{module:'stock_alerts',url:'https://angsokhey11-cloud.github.io/big-brother-admin-work/company-control.html?embed=1&view=stock-alerts&v=1',button:'navStockAlerts'},
  'staff-relation':{personal:true,url:'https://angsokhey11-cloud.github.io/big-brother-staff-relation/?embed=1&v=20260913-1',button:'navStaffRelation'},
  'staff-management':{adminOnly:true,url:'https://angsokhey11-cloud.github.io/big-brother-master-data/staff-management.html?embed=1&v=20260913-1',button:'navStaffManagement'},
  'staff-payment-settings':{adminOnly:true,url:'https://angsokhey11-cloud.github.io/big-brother-master-data/staff-payment-settings.html?embed=1&v=20260913-1',button:'navStaffPaymentSettings'},
  'management-control-center':{module:'management_control_center',adminOnly:true,url:'https://angsokhey11-cloud.github.io/big-brother-admin-work/company-control.html?embed=1&view=management&v=1',button:'navManagementControl'},
  'system-activity':{module:'system_activity',adminOnly:true,url:'https://angsokhey11-cloud.github.io/big-brother-admin-work/company-control.html?embed=1&view=activity&v=1',button:'navSystemActivity'},
  'notification-center':{module:'notification_center',url:'https://angsokhey11-cloud.github.io/big-brother-admin-work/company-control.html?embed=1&view=notifications&v=1',button:'navNotificationCenter'}
};
let baseLoad=window.loadWorkspace,baseInitial=window.openInitialWorkspace,badgeTimer=null,guardedLoad=null;
const key=v=>String(v||'').trim().toLowerCase();
function profile(){return window.BBDashboardAdapter?.getProfile?.()||null}
function can(route){const r=EXTRA[route],p=profile();if(!r||!p)return false;if(r.adminOnly&&!p.user?.isAdmin)return false;if(r.personal)return true;if(p.user?.isAdmin)return true;const mods=Array.isArray(p.modules)?p.modules:[],g=mods.find(x=>key(x.moduleKey)===key(r.module))||mods.find(x=>key(x.moduleKey)==='*');return !!g?.canView}
function addAfter(id,html){const el=document.getElementById(id);if(el&&!document.getElementById((html.match(/id="([^"]+)/)||[])[1]||''))el.insertAdjacentHTML('afterend',html)}
function install(){
  try{
    Object.entries(EXTRA).forEach(([k,v])=>MODULE_URLS[k]=v.url);
    MODULE_URLS['admin-staff-request']='https://angsokhey11-cloud.github.io/big-brother-admin-work/staff-request.html?embed=1&v=20260913-3';
  }catch(e){console.error('Company routes:',e)}
  addAfter('navCustomerDetails','<button type="button" hidden class="bb-company-route" id="navCustomerCredit" onclick="BBCompanyFeatures.open(\'customer-credit-control\')">💳 Customer Credit Control</button>');
  addAfter('navStockTransactions','<button type="button" hidden class="bb-company-route" id="navStockAlerts" onclick="BBCompanyFeatures.open(\'stock-alerts\')">🚨 Smart Stock Alerts</button>');
  addAfter('adminWorkNavGroup','<button type="button" hidden class="shell-nav-link bb-company-route" id="navStaffRelation" onclick="BBCompanyFeatures.open(\'staff-relation\')">👥 Staff Relation</button>');
  addAfter('navMasterExpenseCategories','<button type="button" hidden class="bb-company-route" id="navStaffManagement" onclick="BBCompanyFeatures.open(\'staff-management\')">👥 Staff Management</button><button type="button" hidden class="bb-company-route" id="navStaffPaymentSettings" onclick="BBCompanyFeatures.open(\'staff-payment-settings\')">💵 Staff Payment Settings</button>');
  addAfter('navAdminRequest','<button type="button" hidden class="bb-company-route" id="navManagementControl" onclick="BBCompanyFeatures.open(\'management-control-center\')">📊 Management Control Center</button><button type="button" hidden class="bb-company-route" id="navSystemActivity" onclick="BBCompanyFeatures.open(\'system-activity\')">🕘 System Activity</button><button type="button" hidden class="bb-company-route" id="navNotificationCenter" onclick="BBCompanyFeatures.open(\'notification-center\')">🔔 Notification Center</button>');
  const style=document.createElement('style');style.textContent='.bb-notify-quick{border:0;border-radius:999px;background:#17457a;color:#fff;padding:8px 11px;font-size:11px;font-weight:900;cursor:pointer}.bb-notify-quick[data-count="0"]{background:#e5effc;color:#17457a}';document.head.appendChild(style);
}
function setOpen(subId,btnId){const sub=document.getElementById(subId),btn=document.getElementById(btnId);if(sub)sub.classList.add('open');if(btn){btn.classList.add('open');btn.setAttribute('aria-expanded','true');const a=btn.querySelector('.nav-arrow');if(a)a.textContent='▲'}}
function highlight(route){document.querySelectorAll('.nav-submenu button.active,.shell-nav-link.active').forEach(x=>x.classList.remove('active'));const id=EXTRA[route]?.button;document.getElementById(id)?.classList.add('active');if(route==='staff-relation')return;if(route==='customer-credit-control'){setOpen('masterSubmenu','masterMenuButton');setOpen('customersEditorSubmenu','customersEditorMenuButton')}else if(route==='staff-management'||route==='staff-payment-settings'){setOpen('masterSubmenu','masterMenuButton')}else if(route==='stock-alerts'){setOpen('stockSubmenu','stockMenuButton')}else{setOpen('adminWorkSubmenu','adminWorkMenuButton')}}
function open(route,updateUrl=true){if(!can(route)){alert('Access denied for this function.');return false}baseLoad(route,updateUrl);highlight(route);return true}
function routeAwareLoad(route,updateUrl=true){if(EXTRA[route])return open(route,updateUrl);return guardedLoad?guardedLoad.call(window,route,updateUrl):baseLoad(route,updateUrl)}
function installRouteBridge(){if(window.loadWorkspace===routeAwareLoad)return;guardedLoad=window.loadWorkspace;window.loadWorkspace=routeAwareLoad}
function refreshVisibility(){Object.keys(EXTRA).forEach(r=>{const b=document.getElementById(EXTRA[r].button);if(b)b.hidden=!can(r)});installBell()}
async function unread(){try{const s=JSON.parse(localStorage.getItem('BB_SUPABASE_DEV_SESSION_V1')||'null');if(!s?.access_token||!can('notification-center'))return 0;const r=await fetch('https://sjfhlaclgmkwwofzstok.supabase.co/rest/v1/rpc/bb_notification_unread_count',{method:'POST',headers:{apikey:'sb_publishable_w762jR65CWwlO30fKQsYOw_6L9grx8S',Authorization:'Bearer '+s.access_token,'Content-Type':'application/json'},body:'{}',cache:'no-store'});if(!r.ok)return 0;return Number(await r.json()||0)}catch(_){return 0}}
async function refreshBell(){const b=document.getElementById('bbNotificationQuick');if(!b)return;const n=await unread();b.dataset.count=String(n);b.textContent=n>0?'🔔 '+n:'🔔 Notifications'}
function installBell(){const top=document.querySelector('#dashboardHome .topbar'),tools=document.getElementById('bbUserTools');if(!top||!can('notification-center'))return;let b=document.getElementById('bbNotificationQuick');if(!b){b=document.createElement('button');b.id='bbNotificationQuick';b.className='bb-notify-quick';b.type='button';b.onclick=()=>open('notification-center');(tools||top).prepend(b)}refreshBell();if(!badgeTimer)badgeTimer=setInterval(refreshBell,60000)}
window.openInitialWorkspace=function(){refreshVisibility();const q=new URLSearchParams(location.search),m=q.get('module')||'';if(EXTRA[m]&&q.get('autoload')==='1'&&can(m)){open(m,false);return}return baseInitial.apply(window,arguments)};
window.BBCompanyFeatures={open,can,refreshVisibility,refreshBell,installRouteBridge};
install();
window.addEventListener('DOMContentLoaded',()=>setTimeout(()=>{installRouteBridge();refreshVisibility()},0));
})();