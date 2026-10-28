/* BIG BROTHER Mobile Offline Workspace V1 — read-only, account-scoped snapshots.
 * A previously signed-in device can open its saved dashboard without an API call.
 * No authenticated API responses or financial writes are cached by the service worker.
 */
(function(){
'use strict';
const DB_NAME='BB_MOBILE_OFFLINE_WORKSPACE_TEST_V1', STORE='snapshots';
const SESSION_KEY='BB_SUPABASE_DEV_SESSION_V1';
const MAX_AGE_MS=7*24*60*60*1000; // require a successful sync at least weekly
let connection=typeof navigator.onLine==='boolean'?navigator.onLine:true;
let latestSync=0;
let dbPromise=null;
function currentUserId(){
  try{
    const session=JSON.parse(localStorage.getItem(SESSION_KEY)||'null');
    // Only this signed-in account can read its snapshots.
    return String(session?.user?.id||'').trim();
  }catch(_){return ''}
}
function openDb(){
  if(!('indexedDB' in window))return Promise.resolve(null);
  if(!dbPromise)dbPromise=new Promise(resolve=>{
    try{
      const request=indexedDB.open(DB_NAME,1);
      request.onupgradeneeded=()=>{const db=request.result;if(!db.objectStoreNames.contains(STORE))db.createObjectStore(STORE,{keyPath:'key'})};
      request.onsuccess=()=>resolve(request.result);
      request.onerror=()=>resolve(null);
      request.onblocked=()=>resolve(null);
    }catch(_){resolve(null)}
  });
  return dbPromise;
}
async function read(name){
  const userId=currentUserId(),db=await openDb();
  if(!userId||!db||!name)return null;
  return new Promise(resolve=>{
    try{
      const tx=db.transaction(STORE,'readonly');
      const req=tx.objectStore(STORE).get(userId+'::'+name);
      req.onsuccess=()=>{
        const record=req.result||null;
        resolve(record&&Date.now()-record.syncedAt<=MAX_AGE_MS?record:null);
      };
      req.onerror=()=>resolve(null);
    }catch(_){resolve(null)}
  });
}
async function write(name,value){
  const userId=currentUserId(),db=await openDb();
  if(!userId||!db||!name||value==null)return false;
  return new Promise(resolve=>{
    try{
      const tx=db.transaction(STORE,'readwrite');
      tx.objectStore(STORE).put({key:userId+'::'+name,userId,syncedAt:Date.now(),value});
      tx.oncomplete=()=>{if(name==='last-sync'){latestSync=Number(value)||Date.now();updateIndicator()}resolve(true)};
      tx.onerror=()=>resolve(false);
      tx.onabort=()=>resolve(false);
    }catch(_){resolve(false)}
  });
}
async function clearUser(userId=currentUserId()){
  const db=await openDb();if(!userId||!db)return;
  return new Promise(resolve=>{
    try{
      const tx=db.transaction(STORE,'readwrite');
      const req=tx.objectStore(STORE).openCursor();
      req.onsuccess=()=>{const c=req.result;if(!c)return;if(c.value?.userId===userId)c.delete();c.continue()};
      tx.oncomplete=()=>resolve();
      tx.onerror=()=>resolve();
    }catch(_){resolve()}
  });
}
function canUseNetwork(){return connection&&navigator.onLine!==false}
function setConnection(ok){
  connection=!!ok;
  updateIndicator();
}
function indicator(){
  const hero=document.querySelector('#mobileHome .hero');
  if(!hero)return null;
  let el=document.getElementById('bbOfflineWorkspaceStatus');
  if(!el){
    el=document.createElement('div');
    el.id='bbOfflineWorkspaceStatus';
    el.setAttribute('role','status');
    el.style.cssText='font-size:11px;font-weight:700;padding:7px 10px;margin:6px 0;border-radius:10px;background:#ecf4ff;color:#215b87';
    hero.appendChild(el);
  }
  return el;
}
function updateIndicator(){
  const el=indicator();if(!el)return;
  const stamp=latestSync?new Date(latestSync).toLocaleString('en-GB',{day:'2-digit',month:'short',year:'numeric',hour:'2-digit',minute:'2-digit'}):'not yet synced';
  el.textContent='TEST MODE · '+(canUseNetwork()?'Online · saved dashboard':'Offline · saved read-only dashboard')+' · Dashboard synced: '+stamp;
}
async function init(){
  const record=await read('last-sync');
  if(record)latestSync=Number(record.value)||0;
  updateIndicator();
}
async function success(){
  setConnection(true);
  await write('last-sync',Date.now());
}
window.addEventListener('offline',()=>setConnection(false));
window.addEventListener('online',()=>{setConnection(true);window.dispatchEvent(new Event('bb:mobile-reconnected'))});
window.BBMobileOfflineWorkspaceV1={
  read,write,clearUser,currentUserId,canUseNetwork,setConnection,success,init,updateIndicator,
  // Other repo modules need separate offline-safe implementation before being enabled.
  previewReadOnly:true,
  offlineRouteAllowed:()=>false
};
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});
else void init();
})();
