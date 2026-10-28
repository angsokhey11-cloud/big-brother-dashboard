/* BIG BROTHER Mobile Settings — original invoice photo cache controls */
(function(){
'use strict';
const cache=()=>window.BBAROriginalPhotoCacheV1;
const $=id=>document.getElementById(id);
function fmt(bytes){return (Math.max(0,bytes||0)/1048576).toFixed(1)+' MB'}
async function update(){
 const status=$('bbPhotoCacheStatus');
 if(!status)return;
 const api=cache();
 if(!api){status.textContent='Photo cache unavailable on this device.';return}
 const uid=api.currentUserId();
 if(!uid){status.textContent='Sign in to manage saved invoice photos.';return}
 try{
  const data=await api.stats();
  if(uid!==api.currentUserId())return;
  status.textContent=data.count+' saved original'+(data.count===1?'':'s')+
    ' · '+fmt(data.bytes)+' / '+fmt(data.limitBytes)+
    ' · unused photos expire after 7 days';
 }catch(error){status.textContent='Could not read device photo cache.'}
}
function install(){
 const button=$('bbClearInvoicePhotos'),sheet=$('settingsSheet');
 if(!button||!sheet)return;
 button.addEventListener('click',async()=>{
  const api=cache();if(!api?.currentUserId())return;
  if(!confirm('Clear the downloaded original invoice photos for this account on this device? Supabase originals will NOT be deleted.'))return;
  button.disabled=true;
  const status=$('bbPhotoCacheStatus');if(status)status.textContent='Clearing device photos…';
  try{
   const ok=await api.clear();
   if(!ok)throw Error('Device storage could not be cleared.');
   await update();
  }catch(error){if(status)status.textContent=error.message||'Unable to clear device photos.'}
  finally{button.disabled=false}
 });
 new MutationObserver(()=>{if(!sheet.hidden)void update()}).observe(sheet,{attributes:true,attributeFilter:['hidden']});
 if(!sheet.hidden)void update();
}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',install,{once:true});
else install();
})();
