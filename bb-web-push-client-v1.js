/* BIG BROTHER Web Push V1 — explicit device opt-in, no background polling. */
(()=>{
'use strict';
if(window.BBPush)return;
const URL='https://sjfhlaclgmkwwofzstok.supabase.co';
const API_KEY='sb_publishable_w762jR65CWwlO30fKQsYOw_6L9grx8S';
const SESSION_KEY='BB_SUPABASE_DEV_SESSION_V1';
const DEVICE_KEY='BB_PUSH_DEVICE_USER_V1';
const VAPID_PUBLIC_KEY='BHNsQrD_joKfgxW38CT8wzh6fhiJpvDANTulzQULA84LRXJnoxKpE2zSq3LJ7OYTbjDuQsgXWQgvcoXnhwLZZOc';
const supported=()=>window.isSecureContext&&'serviceWorker' in navigator&&'PushManager' in window&&'Notification' in window;
const mobile=()=>/\/mobile\.html$/i.test(location.pathname);
const readSession=()=>{try{return JSON.parse(localStorage.getItem(SESSION_KEY)||'null')}catch(_){return null}};
const userFromToken=()=>{
  try{
    const token=readSession()?.access_token||'';
    const payload=token.split('.')[1];
    const base=payload.replace(/-/g,'+').replace(/_/g,'/');
    return JSON.parse(atob(base.padEnd(Math.ceil(base.length/4)*4,'='))).sub||'';
  }catch(_){return ''}
};
function publicKeyBytes(){
  const base=VAPID_PUBLIC_KEY.replace(/-/g,'+').replace(/_/g,'/');
  const raw=atob(base.padEnd(Math.ceil(base.length/4)*4,'='));
  return Uint8Array.from(raw,ch=>ch.charCodeAt(0));
}
async function rpc(fn,args){
  const session=readSession();
  if(!session?.access_token)throw Error('Please sign in to BIG BROTHER before enabling alerts.');
  const res=await fetch(URL+'/rest/v1/rpc/'+fn,{
    method:'POST',
    headers:{apikey:API_KEY,Authorization:'Bearer '+session.access_token,'Content-Type':'application/json'},
    body:JSON.stringify(args),cache:'no-store'
  });
  let body={};try{body=await res.json()}catch(_){}
  if(!res.ok){
    if(res.status===401)throw Error('Your session has expired. Please sign in again.');
    throw Error(body.message||body.msg||body.error_description||body.error||'Could not save this device.');
  }
  return body;
}
function feedback(message,error=false){
  if(!message)return;
  const el=document.getElementById('bbDeviceAlertStatus');
  if(el)el.textContent=message;
  if(error)window.alert(message);
}
async function currentSubscription(){
  if(!supported())return null;
  const registration=await navigator.serviceWorker.getRegistration('./');
  return await registration?.pushManager?.getSubscription()||null;
}
async function updateButtons(){
  const btn=document.getElementById('bbDevicePushButton');
  if(!btn)return;
  const status=document.getElementById('bbDeviceAlertStatus');
  if(!supported()){
    btn.disabled=true;
    if(status)status.textContent='System push is not supported in this browser.';
    return;
  }
  if(Notification.permission==='denied'){
    btn.disabled=true;
    if(status)status.textContent='Notifications are blocked in device settings.';
    return;
  }
  const subscription=await currentSubscription().catch(()=>null);
  const currentOwner=userFromToken();
  const wasOwner=localStorage.getItem(DEVICE_KEY)||'';
  const enabled=!!subscription&&Notification.permission==='granted'&&!!wasOwner&&wasOwner===currentOwner;
  btn.dataset.enabled=enabled?'true':'false';
  const title=btn.querySelector('[data-push-title]');
  if(title)title.textContent=enabled?'Disable Device Alerts':'Enable Device Alerts';
  if(status)status.textContent=enabled?'Important alerts enabled on this device.':'Receive important alerts even when BIG BROTHER is closed.';
}
async function enable(){
  if(!supported())throw Error('System notifications are not supported on this device.');
  if(!readSession()?.access_token)throw Error('Please sign in to BIG BROTHER first.');
  const ios=/iPhone|iPad|iPod/i.test(navigator.userAgent)||
    (navigator.platform==='MacIntel'&&navigator.maxTouchPoints>1);
  if(ios&&!window.matchMedia('(display-mode: standalone)').matches&&!navigator.standalone){
    throw Error('On iPhone or iPad, add BIG BROTHER to your Home Screen first.');
  }
  // MUST happen directly in the user's click handler for iOS/iPadOS.
  const permission=Notification.permission==='granted'
    ? 'granted' : await Notification.requestPermission();
  if(permission!=='granted')throw Error('Notifications were not allowed. You can enable them in device settings.');
  const reg=await navigator.serviceWorker.register('./sw.js',{scope:'./',updateViaCache:'none'});
  await navigator.serviceWorker.ready;
  let sub=await reg.pushManager.getSubscription();
  const owner=userFromToken();
  const previousOwner=localStorage.getItem(DEVICE_KEY)||'';
  if(sub&&previousOwner&&owner&&previousOwner!==owner){
    await sub.unsubscribe();
    sub=null;
  }
  if(!sub)sub=await reg.pushManager.subscribe({userVisibleOnly:true,applicationServerKey:publicKeyBytes()});
  const save=async(s)=>rpc('bb_push_register_v1',{
    p_subscription:s.toJSON(),
    p_device_label:mobile()?'BIG BROTHER Mobile':'BIG BROTHER Desktop'
  });
  try{
    await save(sub);
  }catch(error){
    if(/different account/i.test(String(error?.message||error))){
      await sub.unsubscribe();
      sub=await reg.pushManager.subscribe({userVisibleOnly:true,applicationServerKey:publicKeyBytes()});
      await save(sub);
    }else throw error;
  }
  if(owner)localStorage.setItem(DEVICE_KEY,owner);
  await updateButtons();
  feedback('Device alerts enabled. Important activity can now reach this device.');
}
async function disable({silent=false}={}){
  if(!supported())return;
  const sub=await currentSubscription();
  if(sub){
    try{await rpc('bb_push_unregister_v1',{p_endpoint:sub.endpoint})}
    catch(error){if(!silent)feedback('Device disconnected locally; server registration will expire.',true)}
    try{await sub.unsubscribe()}catch(_){}
  }
  localStorage.removeItem(DEVICE_KEY);
  await updateButtons();
  if(!silent)feedback('Device alerts disabled.');
}
async function choose(){
  const btn=document.getElementById('bbDevicePushButton');
  if(!btn||btn.disabled)return;
  btn.disabled=true;
  try{
    if(btn.dataset.enabled==='true')await disable();
    else await enable();
  }catch(e){
    feedback(String(e?.message||e),true);
  }finally{
    btn.disabled=false;
    await updateButtons();
  }
}
function installControls(){
  if(document.getElementById('bbDevicePushButton'))return;
  const settings=document.getElementById('settingsSheet');
  if(settings){
    const signout=settings.querySelector('#signOutBtn');
    if(!signout)return;
    const button=document.createElement('button');
    button.id='bbDevicePushButton';
    button.type='button';
    button.className='sheet-option';
    button.innerHTML='<span aria-hidden="true">🔔</span><div><strong data-push-title>Enable Device Alerts</strong><small id="bbDeviceAlertStatus">Receive important business notifications.</small></div>';
    signout.parentNode.insertBefore(button,signout);
    button.addEventListener('click',choose);
    updateButtons();
    return;
  }
  const tools=document.getElementById('bbUserTools')||
    document.querySelector('#dashboardHome .topbar');
  if(!tools)return;
  const button=document.createElement('button');
  button.id='bbDevicePushButton';
  button.type='button';
  button.className='bb-notify-quick';
  button.style.cssText='border:1px solid #ced9e6;background:#fff;color:#234d76;border-radius:9px;padding:8px 10px;font-size:12px;font-weight:700;cursor:pointer;margin-left:7px;';
  button.innerHTML='<span data-push-title>🔔 Enable Alerts</span><span id="bbDeviceAlertStatus" style="display:none"></span>';
  button.title='Configure system push alerts on this computer';
  tools.appendChild(button);
  button.addEventListener('click',choose);
  updateButtons();
}
window.BBPush={enable,disable,installControls,updateButtons};
if(document.readyState==='loading')
  document.addEventListener('DOMContentLoaded',installControls,{once:true});
else installControls();
// Dashboard navigation is assembled dynamically; retry UI attachment once, no API call.
setTimeout(installControls,1600);
})();
