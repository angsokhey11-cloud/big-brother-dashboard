/* BIG BROTHER Native Android Online FCM V1.
 * Loaded only for the Online Android wrapper; no JS bridge, no polling.
 * Native app sends the opaque Firebase token into this trusted top-level
 * page via evaluateJavascript after the user has opted in.
 */
(()=>{
'use strict';
if(new URLSearchParams(location.search).get('source')!=='android-online')return;
const BASE='https://sjfhlaclgmkwwofzstok.supabase.co';
const KEY='sb_publishable_w762jR65CWwlO30fKQsYOw_6L9grx8S';
const SESSION='BB_SUPABASE_DEV_SESSION_V1';
const SAVED='BB_NATIVE_FCM_REGISTER_V1';
let ongoing=false;
function loggedIn(){
  try{
    const session=JSON.parse(localStorage.getItem(SESSION)||'null');
    return session && session.access_token && session.user?.id ? session : null;
  }catch(_){return null}
}
async function onToken(token){
  if(typeof token!=='string'||token.length<20||token.length>4096||ongoing)return;
  const session=loggedIn();
  if(!session)return; // login page: register only when authenticated.
  const deviceKey=session.user.id+'::'+token;
  try{
    const last=JSON.parse(localStorage.getItem(SAVED)||'null');
    if(last?.key===deviceKey && Date.now()-Number(last.at||0)<24*3600000)return;
  }catch(_){}
  ongoing=true;
  try{
    const response=await fetch(BASE+'/rest/v1/rpc/bb_fcm_register_v1',{
      method:'POST',cache:'no-store',headers:{
        'apikey':KEY,
        'authorization':'Bearer '+session.access_token,
        'content-type':'application/json'
      },
      body:JSON.stringify({p_token:token,p_app_id:'com.bigbrother.online.stable'})
    });
    if(!response.ok)throw Error('Could not save Android notification device ('+response.status+')');
    localStorage.setItem(SAVED,JSON.stringify({key:deviceKey,at:Date.now()}));
    updateStatus('Android notifications enabled for this account.');
  }catch(_){updateStatus('Notification connection not ready; reopen the app after login.')}
  finally{ongoing=false}
}
function updateStatus(value){
 const el=document.getElementById('bbNativeFCMStatus');
 if(el)el.textContent=value;
}
function install(){
 const settings=document.getElementById('settingsSheet');
 const signout=settings?.querySelector('#signOutBtn');
 if(!signout||document.getElementById('bbNativeFCMButton'))return;
 const b=document.createElement('button');
 b.type='button';
 b.id='bbNativeFCMButton';
 b.className='sheet-option';
 b.innerHTML='<span aria-hidden="true">🔔</span><div><strong>Enable Android Notifications</strong><small id="bbNativeFCMStatus">Receive BIG BROTHER alerts even when the app is closed.</small></div>';
 signout.parentNode.insertBefore(b,signout);
 b.addEventListener('click',()=>{location.href='bb-notify://enable';});
 const web=document.getElementById('bbDevicePushButton');
 if(web)web.hidden=true; // Browser Web Push is not available in Android WebView.
}
window.BBNativePushV1={onToken,install};
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',install,{once:true});
else install();
setTimeout(install,1500);
})();
