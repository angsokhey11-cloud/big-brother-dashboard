/* BIG BROTHER — Desktop PWA Install V1 */
(function(){
'use strict';

let deferredPrompt=null;
let installed=false;

const $=id=>document.getElementById(id);

function isStandalone(){
  return window.matchMedia?.('(display-mode: standalone)')?.matches===true ||
    window.navigator.standalone===true;
}

function isChromium(){
  const ua=navigator.userAgent||'';
  return /Chrome|Chromium|Edg\//i.test(ua) && !/Firefox/i.test(ua);
}

function ensureStyle(){
  if($('bbDesktopInstallStyle'))return;
  const style=document.createElement('style');
  style.id='bbDesktopInstallStyle';
  style.textContent=`
    .bb-desktop-install{
      display:inline-flex;
      align-items:center;
      gap:6px;
      min-height:34px;
      border:1px solid #9ec7ea;
      border-radius:999px;
      padding:0 12px;
      background:linear-gradient(180deg,#f4faff,#e8f4ff);
      color:#0b5f9e;
      font:900 11px Arial,sans-serif;
      cursor:pointer;
      white-space:nowrap;
      box-shadow:0 3px 10px rgba(23,69,122,.08);
    }
    .bb-desktop-install:hover{
      background:#dff0ff;
      border-color:#75afe0;
      transform:translateY(-1px);
    }
    .bb-desktop-install:disabled{
      opacity:.58;
      cursor:default;
      transform:none;
    }
    .bb-desktop-install-note{
      position:fixed;
      right:20px;
      bottom:20px;
      z-index:1000000;
      max-width:360px;
      padding:11px 14px;
      border-radius:11px;
      background:#173f77;
      color:#fff;
      box-shadow:0 12px 30px rgba(17,45,79,.22);
      font:800 11px/1.45 Arial,sans-serif;
    }
  `;
  document.head.appendChild(style);
}

function note(message){
  let el=$('bbDesktopInstallNote');
  if(!el){
    el=document.createElement('div');
    el.id='bbDesktopInstallNote';
    el.className='bb-desktop-install-note';
    el.hidden=true;
    document.body.appendChild(el);
  }
  el.textContent=message;
  el.hidden=false;
  clearTimeout(note.timer);
  note.timer=setTimeout(()=>{el.hidden=true},3600);
}

function ensureButton(){
  ensureStyle();

  let button=$('bbDesktopInstallApp');
  if(button)return button;

  const top=document.querySelector('#dashboardHome .topbar');
  if(!top)return null;

  button=document.createElement('button');
  button.id='bbDesktopInstallApp';
  button.className='bb-desktop-install';
  button.type='button';
  button.innerHTML='<span>📲</span><span>Install Desktop App</span>';
  button.title='Install the BIG BROTHER desktop dashboard on this computer';
  button.addEventListener('click',installApp);

  const tools=$('bbUserTools');
  const mobile=$('bbSwitchToMobile');

  if(tools){
    if(mobile?.parentNode===tools)mobile.insertAdjacentElement('afterend',button);
    else tools.prepend(button);
  }else{
    top.appendChild(button);
  }

  return button;
}

function render(){
  const button=ensureButton();
  if(!button)return;

  if(isStandalone()||installed){
    button.hidden=true;
    return;
  }

  button.hidden=false;
  button.disabled=false;
  button.innerHTML=deferredPrompt
    ? '<span>📲</span><span>Install Desktop App</span>'
    : '<span>📲</span><span>Install Desktop App</span>';
}

async function installApp(){
  if(isStandalone()||installed){
    note('BIG BROTHER Desktop is already installed on this device.');
    render();
    return;
  }

  if(!deferredPrompt){
    if(isChromium()){
      note('Install is not ready yet. Wait a moment, then tap Install Desktop App again. You can also use the browser Install icon in the address bar.');
    }else{
      note('For direct app installation, open BIG BROTHER in Chrome or Microsoft Edge and tap Install Desktop App.');
    }
    return;
  }

  const prompt=deferredPrompt;
  deferredPrompt=null;

  try{
    await prompt.prompt();
    const choice=await prompt.userChoice;

    if(choice?.outcome==='accepted'){
      note('Installing BIG BROTHER Desktop…');
    }else{
      note('Installation cancelled.');
    }
  }catch(error){
    console.warn('BIG BROTHER desktop install:',error);
    note('Could not open the install prompt. Try the browser Install icon in the address bar.');
  }

  render();
}

function registerWorker(){
  if(!('serviceWorker' in navigator))return;

  navigator.serviceWorker
    .register('./sw.js',{scope:'./',updateViaCache:'none'})
    .then(reg=>{
      reg.update().catch(()=>{});
    })
    .catch(error=>console.warn('BIG BROTHER desktop service worker:',error));
}

function start(){
  ensureButton();
  registerWorker();

  window.addEventListener('beforeinstallprompt',event=>{
    event.preventDefault();
    deferredPrompt=event;
    render();
  });

  window.addEventListener('appinstalled',()=>{
    deferredPrompt=null;
    installed=true;
    render();
    note('BIG BROTHER Desktop installed successfully ✓');
  });

  window.matchMedia?.('(display-mode: standalone)')?.addEventListener?.('change',render);

  const home=$('dashboardHome');
  if(home){
    new MutationObserver(()=>render()).observe(home,{attributes:true,attributeFilter:['hidden']});
  }

  setTimeout(render,120);
  setTimeout(render,1000);
  setTimeout(render,2500);
}

window.BBDesktopPWAInstall={install:installApp,render};

if(document.readyState==='loading'){
  document.addEventListener('DOMContentLoaded',start,{once:true});
}else{
  start();
}
})();