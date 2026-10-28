/* BIG BROTHER mobile V12: read-only data bridge for original stock/tracker/daily UI.
 * Every payload comes from permission-checked, per-user dashboard IndexedDB.
 * All transactional APIs (including Telegram) are intentionally unavailable.
 */
(function(){
'use strict';
const sessionKey='BB_SUPABASE_DEV_SESSION_V1';
function store(){
  const host=window.parent?.BBMobileOfflineWorkspaceV1||
    window.parent?.parent?.BBMobileOfflineWorkspaceV1;
  let id='';
  try{id=String(JSON.parse(localStorage.getItem(sessionKey)||'null')?.user?.id||'').trim()}catch(_){}
  if(!host||!id||host.currentUserId()!==id)throw Error('Your BIG BROTHER offline session is unavailable.');
  return host;
}
function key(route,batchId){
  const safe=String(batchId||'').trim();
  if(safe.length>160)throw Error('Invalid batch.');
  return 'offline-staff-v12::'+route+'::'+(safe||'DEFAULT');
}
async function read(route,batchId){
  const result=await store().read(key(route,batchId));
  if(!result?.value?.success)throw Error('This batch has not been synchronized yet. Open the function online first.');
  return result.value;
}
async function rpc(name,args={}){
  const batch=String(args.p_batch_id||'').trim();
  if(name==='bb_sales_support_your_stock')return read('stock-base');
  if(name==='bb_sales_support_my_stock')return read('stock-my',batch);
  if(name==='bb_sales_support_admin_your_stock')return read('stock-admin',batch);
  if(name==='bb_sales_support_batch_adjustment_totals')return read('stock-adjust',batch);
  if(name==='bb_sales_support_batch_selling_tracker')return read('tracker',batch);
  throw Error('Only synchronized read-only reports can run offline.');
}
async function dailyApi(params={}){
  const action=String(params.action||''),api=store();
  if(action==='invoiceList'){
    const result=await api.read('offline-staff-v12::daily-invoices::DEFAULT');
    if(!result?.value||!Array.isArray(result.value.invoices))throw Error('Daily Sale Summary has not been synchronized yet.');
    // An A/R opening balance is NOT daily sales revenue.
    return {...result.value,invoices:result.value.invoices.filter(row=>!String(row.invoiceId||'').startsWith('AR-MIG-'))};
  }
  if(action==='dailySaleItems'){
    const ids=(Array.isArray(params.invoiceIds)?params.invoiceIds:[]).map(x=>String(x).trim()).filter(Boolean);
    const source=await api.read('offline-history-lines-v1');
    const map=source?.value?.itemsByInvoiceId||{};
    const invoices=(await dailyApi({action:'invoiceList'})).invoices;
    const wanted=new Set(ids);
    const selected=invoices.filter(row=>wanted.has(String(row.invoiceId||'')));
    const response=selected.map(row=>({...row,items:
      Object.prototype.hasOwnProperty.call(map,String(row.invoiceId||''))?map[String(row.invoiceId||'')]:[]}));
    return {success:true,invoices:response};
  }
  throw Error('Sending or changing company data requires an online connection.');
}
window.BBStaffOfflineV12={rpc,dailyApi,read};
})();