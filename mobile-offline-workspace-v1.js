/* BIG BROTHER Mobile Offline Workspace V1 — read-only, account-scoped snapshots.
 * A previously signed-in device can open its saved dashboard without an API call.
 * No authenticated API responses or financial writes are cached by the service worker.
 */
(function(){
'use strict';
const DB_NAME='BB_MOBILE_OFFLINE_WORKSPACE_V1', STORE='snapshots';
const SESSION_KEY='BB_SUPABASE_DEV_SESSION_V1';
const MAX_AGE_MS=7*24*60*60*1000; // Require re-sync after seven days for sensitive snapshots.
const TEST_KEY_PREFIX='bb_mobile_offline_test_v1::';
function testKey(){const id=currentUserId();return id?TEST_KEY_PREFIX+id:''}
function isTestMode(){
  try{const k=testKey();return !!k&&localStorage.getItem(k)==='1'}catch(_){return false}
}
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
  if(userId){try{localStorage.removeItem(TEST_KEY_PREFIX+userId)}catch(_){}}
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
function canUseNetwork(){return !isTestMode()&&connection&&navigator.onLine!==false}
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
  const mode=isTestMode()?'OFFLINE TEST · saved dashboard':canUseNetwork()?'Online · cached dashboard':'Offline · saved dashboard (read-only)';
  el.textContent=mode+' · Last sync: '+stamp;
  el.style.background=isTestMode()?'#fff1de':canUseNetwork()?'#ecf4ff':'#e9f7f0';
  el.style.color=isTestMode()?'#87500e':'#215b87';
}
async function init(){
  latestSync=0;
  const record=await read('last-sync');
  if(record)latestSync=Number(record.value)||0;
  updateIndicator();
}
async function success(){
  // Completing a successful fetch does not override a user's test-mode choice.
  setConnection(navigator.onLine!==false);
  if(!isTestMode())await write('last-sync',Date.now());
}
function setNote(message){
  const el=document.getElementById('bbOfflineTestNote');
  if(el)el.textContent=String(message||'');
}
function updateControls(){
  const toggle=document.getElementById('bbOfflineTestToggle');
  const sync=document.getElementById('bbOfflineSyncNow');
  const active=isTestMode();
  if(toggle){
    toggle.setAttribute('aria-pressed',active?'true':'false');
    toggle.textContent=active?'ON · Return Online':'OFF · Test Offline';
    toggle.style.background=active?'#b96c11':'#176eb6';
  }
  if(sync)sync.disabled=active||navigator.onLine===false;
  setNote(active?
    'Offline Test is ON. Saved dashboard only; live modules are blocked. Turn OFF to resume automatic cloud refresh.':
    'Test the cached dashboard without switching off Wi-Fi. Sync runs while the app is open and online.');
}
async function toggleTest(){
  const id=currentUserId();
  if(!id){setNote('Please sign in once while online first.');return}
  const active=isTestMode();
  if(!active){
    // Never hide a live transaction form behind a simulated disconnected screen.
    if(document.getElementById('mobileHome')?.hidden){
      setNote('Return to Home before enabling Offline Test, to protect unsaved work.');
      return;
    }
    const snapshots=await Promise.all([read('home-overview'),read('staff-overview'),read('admin-overview')]);
    if(!snapshots.some(x=>x?.value)){
      setNote('No saved dashboard yet. Tap Sync Now while online before starting this test.');
      return;
    }
  }
  try{
    const k=testKey();
    if(active)localStorage.removeItem(k);
    else localStorage.setItem(k,'1');
  }catch(_){setNote('Device storage is unavailable. Test mode could not be changed.');return}
  // Close any hidden live module still left in the iframe before simulated offline mode.
  if(!active){
    const frame=document.getElementById('moduleFrame');
    if(frame&&frame.getAttribute('src')!=='about:blank')frame.src='about:blank';
  }
  updateIndicator();updateControls();
  window.dispatchEvent(new Event('bb:mobile-offline-mode-changed'));
  // Explicitly trigger cloud refresh when returning to Normal Mode.
  if(active&&navigator.onLine!==false){setConnection(true);window.dispatchEvent(new Event('bb:mobile-reconnected'))}
}
function installControls(){
  const sheet=document.querySelector('#settingsSheet .sheet-card');
  if(!sheet||document.getElementById('bbOfflineTestPanel'))return;
  const panel=document.createElement('div');
  panel.id='bbOfflineTestPanel';
  panel.style.cssText='padding:13px 12px;margin:12px 0;border:1px solid #cbdceb;border-radius:14px;background:#f3f8fd;display:grid;gap:8px;';
  panel.innerHTML=
    '<strong style="font-size:13px;color:#173f69">Offline Workspace · Dashboard</strong>'+
    '<small id="bbOfflineTestNote" style="font-size:11px;color:#48647e;line-height:1.5"></small>'+
    '<div style="display:flex;gap:8px;flex-wrap:wrap">'+
    '<button type="button" id="bbOfflineTestToggle" aria-pressed="false" style="flex:1;border:0;border-radius:10px;color:#fff;padding:11px;font-weight:800;min-width:130px"></button>'+
    '<button type="button" id="bbOfflineSyncNow" style="flex:1;border:1px solid #b8d1e6;border-radius:10px;background:#fff;color:#1761a1;padding:11px;font-weight:800;min-width:100px">Sync Dashboard</button>'+
    '</div>';
  const install=document.getElementById('installAppBtn');
  if(install?.parentNode===sheet)install.insertAdjacentElement('afterend',panel);
  else sheet.insertBefore(panel,sheet.lastElementChild);
  panel.querySelector('#bbOfflineTestToggle').addEventListener('click',()=>void toggleTest());
  panel.querySelector('#bbOfflineSyncNow').addEventListener('click',()=>{
    if(isTestMode()||navigator.onLine===false){setNote('Internet required. Turn OFF Offline Test first.');return}
    setConnection(true);
    setNote('Sync requested. The timestamp updates after data is saved.');
    window.dispatchEvent(new Event('bb:mobile-reconnected'));
  });
  updateControls();
}

window.addEventListener('offline',()=>{setConnection(false);updateControls()});
window.addEventListener('online',()=>{setConnection(true);updateControls();if(canUseNetwork())window.dispatchEvent(new Event('bb:mobile-reconnected'))});
window.BBMobileOfflineWorkspaceV1={
  read,write,clearUser,currentUserId,canUseNetwork,isTestMode,setConnection,success,init,updateIndicator,updateControls,
  // Other repo modules need separate offline-safe implementation before being enabled.
  offlineRouteAllowed:()=>false
};
function start(){installControls();void init()}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});
else start();
})();
