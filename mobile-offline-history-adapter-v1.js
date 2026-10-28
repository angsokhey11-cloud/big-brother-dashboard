/* BIG BROTHER — Offline original Invoice History adapter.
 * Every operation is a read of this logged-in user's local IndexedDB snapshot.
 * Editing, deleting, reversal, payments, bank and external sync are prohibited.
 */
(function(){
'use strict';
const parentApi=()=>{
  // Original Invoice History mobile skin nests its document one iframe deep.
  // Resolve the trusted dashboard data store through that same-origin wrapper.
  const api=window.parent?.parent?.BBMobileOfflineWorkspaceV1||
    window.parent?.BBMobileOfflineWorkspaceV1;
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
    const key=keyFor(row),api=parentApi();
    const [saved,lineRecord]=await Promise.all([
      api.read('offline-history-detail::'+key),
      api.read('offline-history-lines-v1')
    ]);
    // A single permission-scoped sync downloads ORIGINAL line items for ALL
    // invoices, not just the six most recent complete documents.
    const map=lineRecord?.value?.itemsByInvoiceId;
    const own=map&&Object.prototype.hasOwnProperty.call(map,val(row.invoiceId));
    const realLines=own?map[val(row.invoiceId)]:null;
    const cached=saved?.value?.invoice;
    if(Array.isArray(realLines)){
      return {success:true,invoice:{
        ...(cached||{}),...row,
        items:realLines,
        // Do not describe a known, synchronized product list as missing.
        note:val(row.note)||val(cached?.note)
      }};
    }
    if(cached&&Array.isArray(cached.items)&&cached.items.length){
      return {success:true,invoice:{...cached,...row,items:cached.items}};
    }
    if(api.canUseNetwork()){
      // An invoice opened before the all-products sync finishes can request
      // its real detail on demand without leaving the original preview.
      const bridge=window.parent?.parent?.BBMobileReportSyncV1||
        window.parent?.BBMobileReportSyncV1;
      try{
        const fresh=await bridge?.refreshDetail(row.invoiceId,row.invoiceNo);
        if(fresh?.invoice&&Array.isArray(fresh.invoice.items))return fresh;
      }catch(_){}
    }
    // Never fabricate products: an unsynchronized invoice has no known lines.
    return {success:true,invoice:{
      ...row,items:[],note:'Product lines are not synchronized yet. Open Invoice History online to download them.'
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