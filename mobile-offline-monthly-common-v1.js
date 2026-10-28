/* Offline Monthly Sales uses the exact report HTML; only the data source changes. */
(function(){
'use strict';
const clean=v=>String(v??'').trim();
const num=v=>Number.isFinite(Number(v))?Number(v):0;
const esc=v=>clean(v).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const money=v=>'$'+num(v).toLocaleString('en-US',{minimumFractionDigits:2,maximumFractionDigits:2});
const khr=v=>'៛'+num(v).toLocaleString('en-US',{maximumFractionDigits:0});
const qty=v=>num(v).toLocaleString('en-US',{maximumFractionDigits:6});
function monthParts(v){const match=clean(v).match(/^(\d{4})-(\d{2})$/);if(!match)throw Error('Choose a report month.');return{year:Number(match[1]),month:Number(match[2])}}
function setupMonth(id){const el=document.getElementById(id),d=new Date();if(el&&!el.value)el.value=d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0');return el}
function embed(){if(new URLSearchParams(location.search).get('embed')==='1')document.body.classList.add('embed')}
function status(id,msg,type=''){const el=document.getElementById(id);if(el){el.hidden=!msg;el.textContent=msg||'';el.className='status'+(type?' '+type:'')}}
function loading(id,on,label){const el=document.getElementById(id);if(el){el.hidden=!on;const c=el.querySelector('.loadcard');if(c&&label)c.textContent=label}}
function disable(id,on,label){const el=document.getElementById(id);if(el){if(!el.dataset.original)el.dataset.original=el.textContent;el.disabled=!!on;el.textContent=on?(label||'Loading...'):el.dataset.original}}
function api(){
  const a=window.parent?.BBMobileOfflineWorkspaceV1;
  let session=null;
  try{session=JSON.parse(localStorage.getItem('BB_SUPABASE_DEV_SESSION_V1')||'null')}catch(_){}
  if(!a||!session?.user?.id||a.currentUserId()!==String(session.user.id))throw Error('Please synchronize BIG BROTHER once online.');
  return a;
}
async function rpc(fn,args={}){
  if(fn!=='bb_report_monthly_sales')throw Error('Online connection required.');
  const {year,month}=monthParts(String(args.p_year)+'-'+String(args.p_month).padStart(2,'0'));
  const a=api(),key='offline-monthly::'+year+'-'+String(month).padStart(2,'0');
  const existing=await a.read(key);
  const bridge=window.parent?.BBMobileReportSyncV1;
  if(existing?.value?.totals){
    if(a.canUseNetwork())void bridge?.refreshMonth(year,month);
    return existing.value;
  }
  if(a.canUseNetwork()){
    const result=await bridge?.refreshMonth(year,month);
    if(result?.totals)return result;
  }
  throw Error('This month is not synced. Open it online once.');
}
window.BBReport={rpc,clean,num,esc,money,khr,qty,monthParts,setupMonth,embed,status,loading,disable};
embed();
})();