/* Original BIG BROTHER Sales Support UI, offline-only data adapter.
   Uses user-scoped data downloaded by the mobile shell; no Supabase requests or writes. */
(function(){
'use strict';
const SESSION_KEY='BB_SUPABASE_DEV_SESSION_V1';
function accountId(){
  try{return String(JSON.parse(localStorage.getItem(SESSION_KEY)||'null')?.user?.id||'').trim()}catch(_){return ''}
}
function parentApi(){
  try{
    const api=window.parent?.BBMobileOfflineWorkspaceV1;
    if(!api||!accountId()||api.currentUserId()!==accountId())throw Error('Sign in online and sync your Calculator data first.');
    return api;
  }catch(error){throw new Error(error.message||'Saved mobile data is unavailable.')}
}
async function bootstrap(){
  const record=await parentApi().read('offline-calc-bootstrap');
  if(!record?.value?.success)throw new Error('Calculator data has not been downloaded yet. Open online once to sync.');
  return record.value;
}
async function jsonp(_url,params={}){
  const action=String(params.action||'');
  const data=await bootstrap();
  switch(action){
    case 'getLocations':return Array.isArray(data.locations)?data.locations:[];
    case 'getProducts':return Array.isArray(data.products)?data.products:[];
    case 'getCustomers':return Array.isArray(data.customers)?data.customers:[];
    case 'getCustomersByLocation':
      return (data.customers||[]).filter(c=>String(c.locationCode)===String(params.locationCode));
    case 'getCustomerProductPrices':{
      const id=String(params.customerId||'').trim();
      const customer=(data.customers||[]).find(c=>String(c.customerId)===id);
      if(!customer)throw Error('Customer not included in saved assigned-location data.');
      const record=await parentApi().read('calc-price::'+id);
      if(!record?.value?.success){
        throw Error('Customer-specific prices not downloaded. Use manual prices or open this customer online once.');
      }
      return record.value;
    }
    default:throw Error('This function requires an internet connection.');
  }
}
async function apiPost(){throw Error('Cloud changes and delivery requests are disabled offline.')}
async function rpc(name){
  if(name!=='bb_sales_support_calculator_batch_scope')throw Error('Live transactions are unavailable offline.');
  const record=await parentApi().read('offline-calc-batch-scope');
  if(!record?.value?.success)throw Error('Batch product list has not been synced. Open Calculator online once.');
  return record.value;
}
window.BBSalesSupportAdapter={
  bootstrap,jsonp,apiPost,rpc,
  ensureSession:async()=>{parentApi();return {user:{id:accountId()}}},
  clearLegacyCaches:()=>{}
};
})();
