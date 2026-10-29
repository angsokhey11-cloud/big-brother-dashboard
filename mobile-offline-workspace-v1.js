/* BIG BROTHER Mobile Offline Workspace V2 — automatic cache-first dashboard.
 * No manual offline toggle, server-side writes or financial API response interception.
 * The app starts from the last saved account-scoped data, then refreshes in the
 * background whenever the device can reach the cloud.
 */
(function(){
'use strict';
const DB_NAME='BB_MOBILE_OFFLINE_WORKSPACE_V1', STORE='snapshots';
const SESSION_KEY='BB_SUPABASE_DEV_SESSION_V1';
const LEGACY_TEST_KEY_PREFIX='bb_mobile_offline_test_v1::';
const MAX_AGE_MS=7*24*60*60*1000;
const LOCAL_MODE=new URLSearchParams(location.search).get('localbrain')==='1';
let lastLocalResume=0;
let connection=LOCAL_MODE?false:navigator.onLine!==false;
let latestSync=0,dbPromise=null,initializedFor='';
function currentUserId(){
  try{
    const session=JSON.parse(localStorage.getItem(SESSION_KEY)||'null');
    return String(session?.user?.id||'').trim();
  }catch(_){return ''}
}
function openDb(){
  if(!('indexedDB' in window))return Promise.resolve(null);
  if(!dbPromise)dbPromise=new Promise(resolve=>{
    try{
      const request=indexedDB.open(DB_NAME,1);
      request.onupgradeneeded=()=>{
        const db=request.result;
        if(!db.objectStoreNames.contains(STORE))db.createObjectStore(STORE,{keyPath:'key'});
      };
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
      const req=db.transaction(STORE,'readonly').objectStore(STORE).get(userId+'::'+name);
      req.onsuccess=()=>{
        const record=req.result||null;
        resolve(record&&Number.isFinite(record.syncedAt)&&Date.now()-record.syncedAt<=MAX_AGE_MS&&record.syncedAt<=Date.now()+60000?record:null);
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
      tx.oncomplete=()=>{
        if(name==='last-sync'){latestSync=Number(value)||0;updateIndicator()}
        resolve(true);
      };
      tx.onerror=()=>resolve(false);
      tx.onabort=()=>resolve(false);
    }catch(_){resolve(false)}
  });
}
async function clearUser(userId=currentUserId()){
  if(userId){try{localStorage.removeItem(LEGACY_TEST_KEY_PREFIX+userId)}catch(_){}}
  const db=await openDb();
  if(!userId||!db)return;
  return new Promise(resolve=>{
    try{
      const tx=db.transaction(STORE,'readwrite');
      const req=tx.objectStore(STORE).openCursor();
      req.onsuccess=()=>{
        const cursor=req.result;
        if(!cursor)return;
        if(cursor.value?.userId===userId)cursor.delete();
        cursor.continue();
      };
      tx.oncomplete=()=>resolve();
      tx.onerror=()=>resolve();
    }catch(_){resolve()}
  });
}
// navigator.onLine is a hint; do not permanently block retrying cloud reads
// after a transient request failure while Wi-Fi itself remains connected.
// Connection status is UI state, NOT a permission to make requests.
// Blocking live requests when V6 is down caused a permanent offline deadlock.
function canUseNetwork(){return navigator.onLine!==false}
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
    (hero.querySelector('.bb-hero-right')||hero.querySelector('.hero-top')||hero).appendChild(el);
  }
  el.classList.add('bb-header-sync');
  el.removeAttribute('style');
  return el;
}
function updateIndicator(){
  const el=indicator();
  if(!el)return;
  const offline=!canUseNetwork()||!connection;
  // The clock always describes the last successfully saved account-scoped snapshot,
  // never merely a connected Wi-Fi signal.
  const last=new Date(latestSync);
  const stamp=latestSync&&Number.isFinite(last.getTime())
    ?last.toLocaleDateString('en-GB',{day:'2-digit',month:'short',year:'numeric'}).replace(/\s+/g,'-')+', '+
      last.toLocaleTimeString('en-US',{hour:'numeric',minute:'2-digit',hour12:true})
    :'Not synced';
  el.textContent=(offline?'Offline':'Online')+' · Sync: '+stamp;
}
async function init(){
  const user=currentUserId();
  // Remove a previous test-mode setting. Offline mode is now automatic.
  if(user){try{localStorage.removeItem(LEGACY_TEST_KEY_PREFIX+user)}catch(_){}}
  if(user!==initializedFor){latestSync=0;initializedFor=user}
  const record=await read('last-sync');
  // Avoid applying a record that arrived after a different account signed in.
  if(user===currentUserId())latestSync=Number(record?.value)||0;
  updateIndicator();
}
async function success(){
  setConnection(navigator.onLine!==false);
  if(canUseNetwork())await write('last-sync',Date.now());
}
// Android WebView can remain on Wi-Fi while V6 restarts: the browser's
// online event does not fire when the local server comes back. On returning
// to the Local Brain app, retry only if data is stale (no polling of cloud).
function resumeLocalSync(){
  updateIndicator();
  if(!LOCAL_MODE||document.visibilityState==='hidden'||!currentUserId()||!canUseNetwork())return;
  const now=Date.now();
  if(latestSync&&now-latestSync<5*60*1000)return;
  if(now-lastLocalResume<2*60*1000)return;
  lastLocalResume=now;
  window.dispatchEvent(new Event('bb:mobile-reconnected'));
}
/* Reconnect watchdog V4: a genuine GET, not HEAD.
 * The local V6 server can reject HEAD while its GET dashboard routes work.
 * A GET for index.html is deliberately outside MOBILE_FILES and therefore
 * bypasses our cached mobile service worker: it tests the REAL HTTPS server.
 * Do not gate any future requests on this status: it is an indicator only.
 * Cloud mode remains conditional so slow Internet doesn't add background load.
 */
let reconnectProbeRunning=false,lastReconnectProbeAt=0;
function cachedScreenVisible(){
  const screen=document.getElementById('moduleScreen');
  if(!screen||screen.hidden)return false;
  if(window.BBMobileOfflineModulesV1?.isCachedActive?.())return true;
  if(window.BBMobileUniversalReadOnlyV1?.isCachedActive?.())return true;
  const native=document.getElementById('bbOfflineModulesScreen');
  if(native&&native.style.display!=='none')return true;
  const frame=document.getElementById('moduleFrame');
  return !!frame?.hasAttribute('srcdoc');
}
async function probeLiveHost(){
  if(document.visibilityState==='hidden'||reconnectProbeRunning||
     (!LOCAL_MODE&&connection&&!cachedScreenVisible()))return;
  const now=Date.now();
  if(now-lastReconnectProbeAt<(LOCAL_MODE?7000:12000))return;
  lastReconnectProbeAt=now;
  reconnectProbeRunning=true;
  const controller=new AbortController();
  const abort=setTimeout(()=>controller.abort(),6000);
  try{
    // index.html is a real file in this dashboard, NOT in the mobile SW's
    // cached-file allowlist. A unique query and no-store bypass HTTP caches.
    const url=new URL(LOCAL_MODE?'./index.html':'./mobile.html',location.href);
    url.searchParams.set('bb_live_probe',String(Date.now()));
    const response=await fetch(url,{
      method:LOCAL_MODE?'GET':'HEAD',
      cache:'no-store',redirect:'error',signal:controller.signal
    });
    if(!response.ok)throw Error('BIG BROTHER host not ready');
    const wasOffline=!connection;
    setConnection(true);
    // The initial cached page already attempts a seamless live handoff;
    // signal ONLY when connectivity has truly changed after a failure.
    if(wasOffline)window.dispatchEvent(new Event('bb:mobile-reconnected'));
  }catch(_){
    setConnection(false);
  }finally{
    clearTimeout(abort);
    reconnectProbeRunning=false;
  }
}
setInterval(()=>{void probeLiveHost()},LOCAL_MODE?9000:12000);
window.addEventListener('focus',()=>{
  if(LOCAL_MODE)void probeLiveHost();
  resumeLocalSync();
});
document.addEventListener('visibilitychange',()=>{
  if(document.visibilityState==='visible'){
    if(LOCAL_MODE)void probeLiveHost();
    resumeLocalSync();
  }
});
window.addEventListener('offline',()=>setConnection(false));
window.addEventListener('online',()=>{
  if(LOCAL_MODE){
    // Joining Wi-Fi is not proof that V6 has started.
    void probeLiveHost();
  }else{
    setConnection(true);
    window.dispatchEvent(new Event('bb:mobile-reconnected'));
  }
});
// Local mode starts from a verified HTTPS check, not navigator.onLine.
// Start right away; don't force staff to wait for the 12-second timer.
if(LOCAL_MODE)void probeLiveHost();
window.BBMobileOfflineWorkspaceV1={
  read,write,clearUser,currentUserId,canUseNetwork,setConnection,success,init,updateIndicator,
  offlineRouteAllowed:()=>false
};
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',()=>void init(),{once:true});
else void init();
})();