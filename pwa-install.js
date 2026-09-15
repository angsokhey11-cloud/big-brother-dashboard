/* BIG BROTHER — Mobile PWA Install V1 */
(function(){
'use strict';

let deferredPrompt=null;
let dismissed=false;
const $=id=>document.getElementById(id);

function isStandalone(){return window.matchMedia?.('(display-mode: standalone)')?.matches===true || window.navigator.standalone===true}
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
function settingsState(){
  const btn=$('installAppBtn'),sub=$('installAppStatus');if(!btn)return;
  if(isStandalone()){btn.hidden=true;return}btn.hidden=false;
  if(sub)sub.textContent=deferredPrompt?'Install BIG BROTHER directly from Chrome':isChromeLike()?'Chrome install becomes available when the app is ready':'Open this page in Chrome to install the app';
}
function render(){const banner=ensureBanner(),installed=isStandalone();if(banner)banner.hidden=installed||!deferredPrompt||dismissed||!homeVisible();settingsState()}
async function installApp(){
  if(isStandalone()){toast('BIG BROTHER is already installed on this device.');render();return}
  if(!deferredPrompt){if(isChromeLike())toast('Chrome is preparing the install option. You can also use Chrome ⋮ → Add to Home screen / Install app.');else toast('Open BIG BROTHER in Chrome, then choose Install App.');return}
  const prompt=deferredPrompt;deferredPrompt=null;
  try{await prompt.prompt();const choice=await prompt.userChoice;if(choice?.outcome==='accepted'){dismissed=true;toast('Installing BIG BROTHER…')}else toast('Installation cancelled. You can install later from Mobile Settings.')}catch(error){console.warn('BIG BROTHER PWA install:',error);toast('Could not open the install prompt. Try Chrome ⋮ → Install app.')}render();
}
window.addEventListener('beforeinstallprompt',event=>{event.preventDefault();deferredPrompt=event;dismissed=false;render()});
window.addEventListener('appinstalled',()=>{deferredPrompt=null;dismissed=true;render();toast('BIG BROTHER installed successfully ✓')});

function registerWorker(){if(!('serviceWorker' in navigator))return;navigator.serviceWorker.register('./sw.js',{scope:'./',updateViaCache:'none'}).then(reg=>reg.update().catch(()=>{})).catch(error=>console.warn('BIG BROTHER service worker:',error))}
function loadMainMenuV4(){if(document.querySelector('script[data-bb-main-menu-v4]')||window.BBMobileRouteV4)return;const script=document.createElement('script');script.src='mobile-main-menu-v3.js?v=20260915-4';script.async=false;script.dataset.bbMainMenuV4='1';document.body.appendChild(script)}
function loadMobilePolicy(){if(document.querySelector('script[data-bb-mobile-policy-v1]')||window.BBMobileUIPolicyV1)return;const script=document.createElement('script');script.src='mobile-ui-policy-v1.js?v=20260915-2';script.async=false;script.dataset.bbMobilePolicyV1='1';document.body.appendChild(script)}
function loadNavigationV5(){if(document.querySelector('script[data-bb-navigation-v5]')||window.BBMobileNavigationV5)return;const script=document.createElement('script');script.src='mobile-navigation-v5.js?v=20260916-1';script.async=false;script.dataset.bbNavigationV5='1';document.body.appendChild(script)}
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
window.BBPWAInstall={install:installApp,render,isStandalone};
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
})();
