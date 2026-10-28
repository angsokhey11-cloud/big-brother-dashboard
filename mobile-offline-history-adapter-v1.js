/* BIG BROTHER — Offline original Invoice History adapter.
 * Every operation is a read of this logged-in user's local IndexedDB snapshot.
 * Editing, deleting, reversal, payments, bank and external sync are prohibited.
 */
(function(){
'use strict';
const parentApi=()=>{
  const api=window.parent?.BBMobileOfflineWorkspaceV1;
  let session=null;
  try{session=JSON.parse(localStorage.getItem('BB_SUPABASE_DEV_SESSION_V1')||'null')}catch(_){}
  if(!api||!session?.user?.id||api.currentUserId()!==String(session.user.id))
    throw Error('Please open BIG BROTHER online once to synchronize invoice history.');
  return api;
};
const val=x=>String(x??'').trim();
const keyFor=row=>val(row.invoiceId)||'NO:'+val(row.invoiceNo);
async function all(){
  const r=await parentApi().read('offline-history-list-v1');
  if(!r?.value?.success||!Array.isArray(r.value.invoices))
    throw Error('Invoice History has not synchronized. Connect to internet once.');
  return r.value;
}
async function fetchApi(params={}){
  const action=val(params.action);
  if(action==='verifyInvoiceHistoryPrimaryAdmin')return {success:true,authorized:false,readOnly:true};
  if(action==='invoiceHistoryRevision'){
    const d=await all();return {success:true,revision:val(d.revision||d.syncedAt||'cached')};
  }
  if(action==='invoiceList'){
    const d=await all(),q=val(params.invoiceNo).toLowerCase(),customer=val(params.customer).toLowerCase(),
      start=val(params.dateFrom),end=val(params.dateTo),type=val(params.invoiceType).toLowerCase();
    return {success:true,invoices:d.invoices.filter(row=>{
      const date=val(row.invoiceDate).slice(0,10);
      return (!q||val(row.invoiceNo).toLowerCase().includes(q))&&
        (!customer||val(row.customer).toLowerCase().includes(customer))&&
        (!start||date>=start)&&(!end||date<=end)&&
        (!type||val(row.invoiceType).toLowerCase()===type);
    })};
  }
  if(action==='invoiceDetail'){
    const d=await all(),id=val(params.invoiceId),no=val(params.invoiceNo);
    const row=d.invoices.find(x=>id?val(x.invoiceId)===id:val(x.invoiceNo)===no);
    if(!row)throw Error('Invoice is not in synchronized history.');
    const key=keyFor(row);
    const saved=await parentApi().read('offline-history-detail::'+key);
    if(saved?.value?.invoice)return saved.value;
    // Show the real invoice's date, totals and customer. Product lines require
    // a downloaded detail: do not guess them or claim they are included.
    return {success:true,invoice:{
      ...row,items:[],note:'Full product lines and original invoice photo were not downloaded for this invoice.'
    }};
  }
  throw Error('This Invoice History operation requires an online connection.');
}
async function historyJsonp(_url,params={}){
  const d=await all(),master=d.master||{};
  const action=val(params.action);
  if(action==='getLocations')
    return Array.isArray(master.locations)?master.locations:
      [...new Set(d.invoices.map(x=>val(x.locationCode)).filter(Boolean))].map(locationCode=>({locationCode,locationName:locationCode}));
  if(action==='getCustomers')return master.customers||[];
  if(action==='getProducts')return master.products||[];
  return master;
}
async function postHistoryAction(){throw Error('Cloud invoice changes are disabled offline.')}
async function requirePrimaryAdmin(){return false}
window.BBOfflineHistoryAdapter={fetchApi,historyJsonp,postHistoryAction,requirePrimaryAdmin};
})();