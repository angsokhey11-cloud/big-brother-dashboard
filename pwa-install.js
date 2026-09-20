/* BIG BROTHER — Mobile PWA Install V1 */
(function(){
'use strict';

let deferredPrompt=null;
let dismissed=false;
const $=id=>document.getElementById(id);

function isStandalone(){return window.matchMedia?.('(display-mode: standalone)')?.matches===true || window.navigator.standalone===true}
function isIOS(){const ua=navigator.userAgent||'';return /iPhone|iPad|iPod/i.test(ua)||(navigator.platform==='MacIntel'&&Number(navigator.maxTouchPoints||0)>1)}
function isIOSSafari(){const ua=navigator.userAgent||'';return isIOS()&&/Safari/i.test(ua)&&!/CriOS|FxiOS|EdgiOS|OPiOS/i.test(ua)}
function isChromeLike(){const ua=navigator.userAgent||'';return /Chrome|CriOS|EdgA/i.test(ua) && !/Firefox|FxiOS/i.test(ua)}
function homeVisible(){const home=$('mobileHome');return !!home && !home.hidden}
function toast(text){const el=$('toast');if(!el)return;el.textContent=text;el.hidden=false;clearTimeout(toast.t);toast.t=setTimeout(()=>{el.hidden=true},3200)}
function ensureBanner(){
  const content=document.querySelector('#mobileHome .content');if(!content)return null;
  let banner=$('pwaInstallBanner');if(banner)return banner;
  banner=document.createElement('section');banner.id='pwaInstallBanner';banner.className='pwa-install-banner';banner.hidden=true;
  banner.innerHTML=`<div class="pwa-install-logo">BB</div><div class="pwa-install-copy"><strong>Install BIG BROTHER App</strong><small>Open faster from your phone home screen. Your existing BIG BROTHER login stays on this device.</small></div><button id="pwaBannerInstall" class="pwa-install-main" type="button">Install</button><button id="pwaBannerClose" class="pwa-install-close" type="button" aria-label="Hide install message">×</button>`;
  const intro=$('salesmanIntro');if(intro&&intro.parentNode===content)intro.insertAdjacentElement('afterend',banner);else content.insertBefore(banner,content.firstChild);
  $('pwaBannerInstall').addEventListener('click',installApp);$('pwaBannerClose').addEventListener('click',()=>{dismissed=true;render()});return banner;
}
function ensureIOSGuide(){
  let guide=$('bbIOSInstallGuide');if(guide)return guide;
  guide=document.createElement('div');guide.id='bbIOSInstallGuide';guide.className='bb-ios-install-guide';guide.hidden=true;
  guide.innerHTML=`
    <div class="bb-ios-install-card" role="dialog" aria-modal="true" aria-labelledby="bbIOSInstallTitle">
      <button id="bbIOSInstallClose" class="bb-ios-install-close" type="button" aria-label="Close">×</button>
      <div class="bb-ios-install-icon">📲</div>
      <h3 id="bbIOSInstallTitle">Install BIG BROTHER on iPhone / iPad</h3>
      <p id="bbIOSInstallIntro"></p>
      <ol>
        <li>Open BIG BROTHER in <strong>Safari</strong>.</li>
        <li>Tap the <strong>Share</strong> button <span aria-hidden="true">⬆</span>.</li>
        <li>Choose <strong>Add to Home Screen</strong>.</li>
        <li>Turn on <strong>Open as Web App</strong>, then tap <strong>Add</strong>.</li>
      </ol>
      <p class="bb-ios-install-note">If “Add to Home Screen” is missing, scroll to the bottom of the Share menu → <strong>Edit Actions</strong> → add “Add to Home Screen”.</p>
      <button id="bbIOSInstallDone" class="bb-ios-install-done" type="button">Got it</button>
    </div>`;
  document.body.appendChild(guide);
  const close=()=>{guide.hidden=true};
  $('bbIOSInstallClose')?.addEventListener('click',close);
  $('bbIOSInstallDone')?.addEventListener('click',close);
  guide.addEventListener('click',event=>{if(event.target===guide)close()});
  return guide;
}
function showIOSGuide(){
  const guide=ensureIOSGuide();
  const intro=$('bbIOSInstallIntro');
  if(intro)intro.textContent=isIOSSafari()
    ? 'Safari is ready. Follow these steps to place BIG BROTHER on your Home Screen.'
    : 'This page is not open in Safari. Open the same BIG BROTHER page in Safari first, then follow these steps.';
  guide.hidden=false;
}
function settingsState(){
  const btn=$('installAppBtn'),sub=$('installAppStatus');if(!btn)return;
  if(isStandalone()){btn.hidden=true;return}btn.hidden=false;
  if(isIOS()){
    if(sub)sub.textContent=isIOSSafari()?'Safari: Share → Add to Home Screen':'Open in Safari to install on iPhone / iPad';
    return;
  }
  if(sub)sub.textContent=deferredPrompt?'Install BIG BROTHER directly from Chrome':isChromeLike()?'Chrome install becomes available when the app is ready':'Open this page in Chrome to install the app';
}
function render(){
  const banner=ensureBanner(),installed=isStandalone();
  if(banner){
    const copy=banner.querySelector('.pwa-install-copy small');
    const button=$('pwaBannerInstall');
    if(isIOS()){
      if(copy)copy.textContent=isIOSSafari()
        ? 'Tap Install to see the Safari steps: Share → Add to Home Screen.'
        : 'Open BIG BROTHER in Safari, then add it to your Home Screen.';
      if(button)button.textContent='How to Install';
      banner.hidden=installed||dismissed||!homeVisible();
    }else{
      if(copy)copy.textContent='Open faster from your phone home screen. Your existing BIG BROTHER login stays on this device.';
      if(button)button.textContent='Install';
      banner.hidden=installed||!deferredPrompt||dismissed||!homeVisible();
    }
  }
  settingsState();
}
async function installApp(){
  if(isStandalone()){toast('BIG BROTHER is already installed on this device.');render();return}
  if(isIOS()){showIOSGuide();return}
  if(!deferredPrompt){if(isChromeLike())toast('Chrome is preparing the install option. You can also use Chrome ⋮ → Add to Home screen / Install app.');else toast('Open BIG BROTHER in Chrome, then choose Install App.');return}
  const prompt=deferredPrompt;deferredPrompt=null;
  try{await prompt.prompt();const choice=await prompt.userChoice;if(choice?.outcome==='accepted'){dismissed=true;toast('Installing BIG BROTHER…')}else toast('Installation cancelled. You can install later from Mobile Settings.')}catch(error){console.warn('BIG BROTHER PWA install:',error);toast('Could not open the install prompt. Try Chrome ⋮ → Install app.')}render();
}
window.addEventListener('beforeinstallprompt',event=>{event.preventDefault();deferredPrompt=event;dismissed=false;render()});
window.addEventListener('appinstalled',()=>{deferredPrompt=null;dismissed=true;render();toast('BIG BROTHER installed successfully ✓')});

let bbSwReloading=false;
function registerWorker(){
  if(!('serviceWorker' in navigator))return;
  navigator.serviceWorker.register('./sw.js',{scope:'./',updateViaCache:'none'}).then(reg=>{
    const check=()=>reg.update().catch(()=>{});
    check();

    navigator.serviceWorker.addEventListener('controllerchange',()=>{
      if(bbSwReloading)return;
      bbSwReloading=true;
      location.reload();
    });

    const foregroundCheck=()=>{
      if(document.visibilityState==='visible')check();
    };
    document.addEventListener('visibilitychange',foregroundCheck);
    window.addEventListener('focus',check);
  }).catch(error=>console.warn('BIG BROTHER service worker:',error));
}
function loadMainMenuV4(){if(document.querySelector('script[data-bb-main-menu-v4]')||window.BBMobileRouteV4)return;const script=document.createElement('script');script.src='mobile-main-menu-v3.js?v=20260915-4';script.async=false;script.dataset.bbMainMenuV4='1';document.body.appendChild(script)}
function loadMobilePolicy(){if(document.querySelector('script[data-bb-mobile-policy-v1]')||window.BBMobileUIPolicyV1)return;const script=document.createElement('script');script.src='mobile-ui-policy-v1.js?v=20260915-2';script.async=false;script.dataset.bbMobilePolicyV1='1';document.body.appendChild(script)}
function loadNavigationV5(){if(document.querySelector('script[data-bb-navigation-v5]')||window.BBMobileNavigationV5)return;const script=document.createElement('script');script.src='mobile-navigation-v5.js?v=20260920-history6';script.async=false;script.dataset.bbNavigationV5='1';document.body.appendChild(script)}
function loadThemeV1(){if(document.querySelector('script[data-bb-theme-v1]')||window.BBMobileThemeV1)return;const script=document.createElement('script');script.src='mobile-theme-v1.js?v=20260916-2';script.async=false;script.dataset.bbThemeV1='1';document.body.appendChild(script)}
function start(){
  registerWorker();loadMainMenuV4();loadMobilePolicy();loadNavigationV5();loadThemeV1();
  const btn=$('installAppBtn');if(btn)btn.addEventListener('click',installApp);
  const home=$('mobileHome');if(home)new MutationObserver(()=>render()).observe(home,{attributes:true,attributeFilter:['hidden']});
  window.matchMedia?.('(display-mode: standalone)')?.addEventListener?.('change',render);
  setTimeout(loadMainMenuV4,500);setTimeout(loadMobilePolicy,650);setTimeout(loadNavigationV5,750);setTimeout(loadThemeV1,850);
  setTimeout(loadMainMenuV4,1500);setTimeout(loadMobilePolicy,1650);setTimeout(loadNavigationV5,1750);setTimeout(loadThemeV1,1850);
  setTimeout(render,100);setTimeout(render,1200);
}
window.BBPWAInstall={install:installApp,render,isStandalone,isIOS,isIOSSafari};
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
})();
