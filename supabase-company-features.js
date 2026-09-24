/* BIG BROTHER — Supabase Company Features Dashboard Integration V1.6.14 */
(function(){
'use strict';
const EXTRA={
  'customer-credit-control':{module:'customer_credit_control',url:'https://angsokhey11-cloud.github.io/big-brother-admin-work/company-control.html?embed=1&view=credit&v=1',button:'navCustomerCredit'},
  'stock-alerts':{module:'stock_alerts',url:'https://angsokhey11-cloud.github.io/big-brother-admin-work/company-control.html?embed=1&view=stock-alerts&v=1',button:'navStockAlerts'},
  'staff-relation':{personal:true,url:'https://angsokhey11-cloud.github.io/big-brother-staff-relation/?embed=1&v=20260913-1',button:'navStaffRelation'},
  'staff-management':{adminOnly:true,url:'https://angsokhey11-cloud.github.io/big-brother-master-data/staff-management.html?embed=1&v=20260913-1',button:'navStaffManagement'},
  'staff-payment-settings':{adminOnly:true,url:'https://angsokhey11-cloud.github.io/big-brother-master-data/staff-payment-settings.html?embed=1&v=20260913-1',button:'navStaffPaymentSettings'},
  'company-setup-master':{adminOnly:true,url:'https://angsokhey11-cloud.github.io/big-brother-master-data/company-setup.html?embed=1&v=20260913-1',button:'navCompanySetupMaster'},
  'reversal-history':{module:'invoice_reversal',url:'https://angsokhey11-cloud.github.io/big-brother-invoice-reversal/history.html?embed=1&v=20260914-1',button:'navReversalHistory'},
  'monthly-sales-report':{adminOnly:true,url:'https://angsokhey11-cloud.github.io/big-brother-report/monthly-sales.html?embed=1&v=20260913-4',button:'navMonthlySalesReport'},
  'income-statement-report':{adminOnly:true,url:'https://angsokhey11-cloud.github.io/big-brother-report/income-statement.html?embed=1&v=20260914-2',button:'navIncomeStatementReport'},
  'purchase-order-report':{adminOnly:true,url:'https://angsokhey11-cloud.github.io/big-brother-report/purchase-order-report.html?embed=1&v=20260913-4',button:'navPurchaseOrderReport'},
  'management-control-center':{module:'management_control_center',adminOnly:true,url:'https://angsokhey11-cloud.github.io/big-brother-admin-work/company-control.html?embed=1&view=management&v=1',button:'navManagementControl'},
  'system-activity':{module:'system_activity',adminOnly:true,url:'https://angsokhey11-cloud.github.io/big-brother-admin-work/company-control.html?embed=1&view=activity&v=1',button:'navSystemActivity'},
  'notification-center':{module:'notification_center',url:'https://angsokhey11-cloud.github.io/big-brother-admin-work/company-control.html?embed=1&view=notifications&v=1',button:'navNotificationCenter'}
};
let baseLoad=window.loadWorkspace,baseInitial=window.openInitialWorkspace,badgeTimer=null,guardedLoad=null;
const key=v=>String(v||'').trim().toLowerCase();
function profile(){return window.BBDashboardAdapter?.getProfile?.()||null}
function can(route){const r=EXTRA[route],p=profile();if(!r||!p)return false;if(r.adminOnly&&!p.user?.isAdmin)return false;if(r.personal)return true;if(p.user?.isAdmin)return true;const mods=Array.isArray(p.modules)?p.modules:[],g=mods.find(x=>key(x.moduleKey)===key(r.module))||mods.find(x=>key(x.moduleKey)==='*');return !!g?.canView}
function addAfter(id,html){const el=document.getElementById(id);if(el&&!document.getElementById((html.match(/id="([^"]+)/)||[])[1]||''))el.insertAdjacentHTML('afterend',html)}
function installReportsMenu(){
  if(document.getElementById('mainReportsNavGroup'))return;
  const old=Array.from(document.querySelectorAll('button.shell-nav-link')).find(b=>String(b.getAttribute('onclick')||'').includes("showDashboardSection('reports')"));
  if(!old)return;
  const wrap=document.createElement('div');
  wrap.className='nav-group';
  wrap.id='mainReportsNavGroup';
  wrap.innerHTML='<button type="button" id="mainReportsMenuButton" class="nav-toggle" aria-expanded="false" aria-controls="mainReportsSubmenu" onclick="BBCompanyFeatures.toggleReports()"><span class="nav-toggle-main"><span>📊</span><span>Reports</span></span><span class="nav-arrow">▼</span></button><div id="mainReportsSubmenu" class="nav-submenu"><button type="button" hidden class="bb-company-route" id="navMonthlySalesReport" onclick="BBCompanyFeatures.open(\'monthly-sales-report\')">📊 Monthly Sales Report</button><button type="button" hidden class="bb-company-route" id="navIncomeStatementReport" onclick="BBCompanyFeatures.open(\'income-statement-report\')">📈 Income Statement (Monthly)</button><button type="button" hidden class="bb-company-route" id="navPurchaseOrderReport" onclick="BBCompanyFeatures.open(\'purchase-order-report\')">🧾 Purchase Order Report</button></div>';
  old.replaceWith(wrap);
}
function installOverview(){
  if(!document.getElementById('bbMonthlyOverviewScript')){
    const s=document.createElement('script');
    s.id='bbMonthlyOverviewScript';
    s.src='supabase-dashboard-overview.js?v=20260921-stafflinks1';
    document.body.appendChild(s);
  }
  if(!document.getElementById('bbMonthlyOverviewEnhancer')){
    const e=document.createElement('script');
    e.id='bbMonthlyOverviewEnhancer';
    e.src='supabase-dashboard-overview-enhancer.js?v=20260924-salesmanbatch1';
    document.body.appendChild(e);
  }
}
function installMobileSwitch(){
  if(window.top!==window.self||document.getElementById('bbSwitchToMobile'))return;
  const top=document.querySelector('#dashboardHome .topbar');
  if(!top)return;
  let style=document.getElementById('bbMobileSwitchStyle');
  if(!style){
    style=document.createElement('style');style.id='bbMobileSwitchStyle';
    style.textContent='.bb-mobile-switch{display:inline-flex;align-items:center;gap:6px;text-decoration:none;border:1px solid #b9d8f5;background:#eaf5ff;color:#0b5f9e;border-radius:999px;padding:8px 11px;font-size:11px;font-weight:900;white-space:nowrap;box-shadow:0 3px 10px #17457a14}.bb-mobile-switch:hover{background:#dff0ff;border-color:#87bde8}';
    document.head.appendChild(style);
  }
  const link=document.createElement('a');
  link.id='bbSwitchToMobile';link.className='bb-mobile-switch';link.href='mobile.html?from=desktop&v=20260916-2';link.innerHTML='<span>📱</span><span>Mobile App</span>';link.title='Switch back to BIG BROTHER Mobile';
  const tools=document.getElementById('bbUserTools');
  if(tools)tools.prepend(link);else top.appendChild(link);
}
function install(){
  try{
    Object.entries(EXTRA).forEach(([k,v])=>MODULE_URLS[k]=v.url);
    MODULE_URLS['admin-staff-request']='https://angsokhey11-cloud.github.io/big-brother-admin-work/staff-request-v2.html?embed=1&v=20260913-4';
  }catch(e){console.error('Company routes:',e)}
  installReportsMenu();
  addAfter('navSaleReturn','<button type="button" hidden class="bb-company-route" id="navReversalHistory" onclick="BBCompanyFeatures.open(\'reversal-history\')">📜 Reversal History</button>');
  addAfter('navCustomerDetails','<button type="button" hidden class="bb-company-route" id="navCustomerCredit" onclick="BBCompanyFeatures.open(\'customer-credit-control\')">💳 Customer Credit Control</button>');
  addAfter('navStockTransactions','<button type="button" hidden class="bb-company-route" id="navStockAlerts" onclick="BBCompanyFeatures.open(\'stock-alerts\')">🚨 Smart Stock Alerts</button>');
  addAfter('adminWorkNavGroup','<button type="button" hidden class="shell-nav-link bb-company-route" id="navStaffRelation" onclick="BBCompanyFeatures.open(\'staff-relation\')">👥 Staff Relation</button>');
  addAfter('navMasterExpenseCategories','<button type="button" hidden class="bb-company-route" id="navStaffManagement" onclick="BBCompanyFeatures.open(\'staff-management\')">👥 Staff Management</button><button type="button" hidden class="bb-company-route" id="navStaffPaymentSettings" onclick="BBCompanyFeatures.open(\'staff-payment-settings\')">💵 Staff Payment Settings</button><button type="button" hidden class="bb-company-route" id="navCompanySetupMaster" onclick="BBCompanyFeatures.open(\'company-setup-master\')">⚙️ Company Setup</button>');
  addAfter('navAdminRequest','<button type="button" hidden class="bb-company-route" id="navManagementControl" onclick="BBCompanyFeatures.open(\'management-control-center\')">📊 Management Control Center</button><button type="button" hidden class="bb-company-route" id="navSystemActivity" onclick="BBCompanyFeatures.open(\'system-activity\')">🕘 System Activity</button><button type="button" hidden class="bb-company-route" id="navNotificationCenter" onclick="BBCompanyFeatures.open(\'notification-center\')">🔔 Notification Center</button>');
  const style=document.createElement('style');style.textContent='.bb-notify-quick{border:0;border-radius:999px;background:#17457a;color:#fff;padding:8px 11px;font-size:11px;font-weight:900;cursor:pointer}.bb-notify-quick[data-count="0"]{background:#e5effc;color:#17457a}';document.head.appendChild(style);
  installOverview();
  installMobileSwitch();
  setTimeout(installMobileSwitch,600);
  setTimeout(installMobileSwitch,1600);
}
function setOpen(subId,btnId){const sub=document.getElementById(subId),btn=document.getElementById(btnId);if(sub)sub.classList.add('open');if(btn){btn.classList.add('open');btn.setAttribute('aria-expanded','true');const a=btn.querySelector('.nav-arrow');if(a)a.textContent='▲'}}
function toggleReports(){const sub=document.getElementById('mainReportsSubmenu'),btn=document.getElementById('mainReportsMenuButton');if(!sub||!btn)return;const open=!sub.classList.contains('open');sub.classList.toggle('open',open);btn.classList.toggle('open',open);btn.setAttribute('aria-expanded',String(open));const a=btn.querySelector('.nav-arrow');if(a)a.textContent=open?'▲':'▼'}
function highlight(route){document.querySelectorAll('.nav-submenu button.active,.shell-nav-link.active').forEach(x=>x.classList.remove('active'));const id=EXTRA[route]?.button;document.getElementById(id)?.classList.add('active');if(route==='staff-relation')return;if(route==='monthly-sales-report'||route==='income-statement-report'||route==='purchase-order-report'){setOpen('mainReportsSubmenu','mainReportsMenuButton');return}if(route==='reversal-history'){setOpen('salesSubmenu','salesMenuButton')}else if(route==='customer-credit-control'){setOpen('masterSubmenu','masterMenuButton');setOpen('customersEditorSubmenu','customersEditorMenuButton')}else if(route==='staff-management'||route==='staff-payment-settings'||route==='company-setup-master'){setOpen('masterSubmenu','masterMenuButton')}else if(route==='stock-alerts'){setOpen('stockSubmenu','stockMenuButton')}else{setOpen('adminWorkSubmenu','adminWorkMenuButton')}}
function openReportDirect(route,updateUrl=true){
  const r=EXTRA[route];
  const home=document.getElementById('dashboardHome');
  const workspace=document.getElementById('moduleWorkspace');
  const frame=document.getElementById('moduleFrame');
  if(!r?.url||!workspace||!frame){alert('Report workspace is not ready. Please refresh once.');return false}
  if(home)home.hidden=true;
  workspace.hidden=false;
  frame.src=r.url;
  if(updateUrl){
    try{
      const u=new URL(location.href);
      u.searchParams.set('module',route);
      u.searchParams.set('autoload','1');
      history.pushState({},'',u.pathname+u.search+u.hash);
    }catch(_){}
  }
  highlight(route);
  return true;
}
function open(route,updateUrl=true){if(!can(route)){alert('Access denied for this function.');return false}if(route==='monthly-sales-report'||route==='income-statement-report'||route==='purchase-order-report')return openReportDirect(route,updateUrl);baseLoad(route,updateUrl);highlight(route);return true}
function routeAwareLoad(route,updateUrl=true){if(EXTRA[route])return open(route,updateUrl);return guardedLoad?guardedLoad.call(window,route,updateUrl):baseLoad(route,updateUrl)}
function installRouteBridge(){if(window.loadWorkspace===routeAwareLoad)return;guardedLoad=window.loadWorkspace;window.loadWorkspace=routeAwareLoad}
function refreshVisibility(){Object.keys(EXTRA).forEach(r=>{const b=document.getElementById(EXTRA[r].button);if(b)b.hidden=!can(r)});const g=document.getElementById('mainReportsNavGroup');if(g)g.hidden=!(can('monthly-sales-report')||can('income-statement-report')||can('purchase-order-report'));installBell();installMobileSwitch()}
async function unread(){try{const s=JSON.parse(localStorage.getItem('BB_SUPABASE_DEV_SESSION_V1')||'null');if(!s?.access_token||!can('notification-center'))return 0;const r=await fetch('https://sjfhlaclgmkwwofzstok.supabase.co/rest/v1/rpc/bb_notification_unread_count',{method:'POST',headers:{apikey:'sb_publishable_w762jR65CWwlO30fKQsYOw_6L9grx8S',Authorization:'Bearer '+s.access_token,'Content-Type':'application/json'},body:'{}',cache:'no-store'});if(!r.ok)return 0;return Number(await r.json()||0)}catch(_){return 0}}
async function refreshBell(){const b=document.getElementById('bbNotificationQuick');if(!b)return;const n=await unread();b.dataset.count=String(n);b.textContent=n>0?'🔔 '+n:'🔔 Notifications'}
function installBell(){const top=document.querySelector('#dashboardHome .topbar'),tools=document.getElementById('bbUserTools');if(!top||!can('notification-center'))return;let b=document.getElementById('bbNotificationQuick');if(!b){b=document.createElement('button');b.id='bbNotificationQuick';b.className='bb-notify-quick';b.type='button';b.onclick=()=>open('notification-center');(tools||top).prepend(b)}refreshBell();if(!badgeTimer)badgeTimer=setInterval(refreshBell,60000)}
window.openInitialWorkspace=function(){refreshVisibility();const q=new URLSearchParams(location.search),m=q.get('module')||'';if(EXTRA[m]&&q.get('autoload')==='1'&&can(m)){open(m,false);return}return baseInitial.apply(window,arguments)};
window.BBCompanyFeatures={open,can,refreshVisibility,refreshBell,installRouteBridge,toggleReports,installMobileSwitch};
install();
window.addEventListener('DOMContentLoaded',()=>setTimeout(()=>{installRouteBridge();refreshVisibility();installMobileSwitch()},0));
})();