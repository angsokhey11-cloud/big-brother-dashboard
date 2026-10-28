/* BIG BROTHER — Your Collection local read-only adapter.
 * It reads only the authenticated user's IndexedDB snapshot through the mobile
 * dashboard. All write actions remain unavailable in the offline workspace.
 */
(function(){
'use strict';
const STORE='offline-your-collection-v1';
const SESSION='BB_SUPABASE_DEV_SESSION_V1';
function userId(){
  try{return String(JSON.parse(localStorage.getItem(SESSION)||'null')?.user?.id||'').trim()}catch(_){return ''}
}
function dashboard(){
  const p=window.parent?.parent;
  const api=p?.BBMobileOfflineWorkspaceV1;
  if(!api||!userId()||api.currentUserId()!==userId())throw Error('Your Collection saved session is unavailable.');
  return {api,bridge:p?.BBMobileCollectionOfflineV1};
}
async function snapshot(){
  const {api}=dashboard();
  const record=await api.read(STORE);
  if(!record?.value?.success||!Array.isArray(record.value.invoices))throw Error('Open Your Collection online once to synchronize its data.');
  return record.value;
}
async function detail(invoiceId,invoiceNo){
  const id=String(invoiceId||'').trim();
  if(!id)throw Error('The invoice ID is required to safely preview this invoice.');
  const {api,bridge}=dashboard();
  const stored=await snapshot();
  if(!stored.invoices.some(x=>String(x.invoiceId||'').trim()===id))throw Error('This invoice is outside your saved Your Collection access.');
  const key='offline-your-collection-detail::'+id;
  const saved=await api.read(key);
  if(saved?.value?.success&&String(saved.value.invoice?.invoiceId||'')===id)return saved.value;
  if(api.canUseNetwork()&&bridge?.detail){
    const fresh=await bridge.detail(id);
    if(fresh?.success&&String(fresh.invoice?.invoiceId||'')===id)return fresh;
  }
  throw Error('Products for this invoice have not been synchronized yet. Preview this invoice online once to save its details.');
}
async function api(params={}){
  const action=String(params.action||'');
  if(action==='invoiceDetail')return detail(params.invoiceId,params.invoiceNo);
  const value=await snapshot();
  if(action==='invoiceList')return {success:true,invoices:value.invoices};
  if(action==='invoiceHistoryRevision')return {success:true,revision:String(value.revision||value.syncedAt||'cached')};
  if(action==='dccMyState')return {success:true,invoiceStates:value.invoiceStates||{}};
  throw Error('Only saved read-only Your Collection information is available.');
}
async function locationMap(){
  const value=await snapshot(),map={};
  for(const x of value.locations||[]){
    const code=String(x.locationCode||'').trim();
    if(code)map[code.toLowerCase()]=String(x.locationName||code).trim();
  }
  return map;
}
async function apiPost(){throw Error('Creating or closing a collection requires the online BIG BROTHER workspace.')}
window.BBCollectionOfflineAdapter={api,apiPost,locationMap};
})();
