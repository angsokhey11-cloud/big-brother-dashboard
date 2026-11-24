(function(){
'use strict';
const bridge=window.BBNativeAppUpdate;
const row=document.getElementById('bbAppUpdateSettings'),status=document.getElementById('bbAppUpdateStatus');
if(!bridge||!row||!status)return;
row.hidden=false;
bridge.onmessage=e=>{try{const data=JSON.parse(e.data);status.textContent=String(data.status||data.version||'Application Update')}catch(_){}};
row.addEventListener('click',()=>bridge.postMessage('open'));
const sheet=document.getElementById('settingsSheet');
if(sheet)new MutationObserver(()=>{if(!sheet.hidden)bridge.postMessage('status')}).observe(sheet,{attributes:true,attributeFilter:['hidden']});
bridge.postMessage('status');
})();