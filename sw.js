/* BIG BROTHER Mobile PWA service worker V1.3 */
const CACHE='bb-mobile-shell-v4';
const MOBILE_FILES=new Set([
  'mobile.html','mobile.css','mobile-sales-support.css','pwa-install.css','mobile.js',
  'mobile-sales-support-home.js','pwa-install.js','mobile-main-menu-v3.js','manifest.webmanifest',
  'pwa-icon.svg','pwa-icon-maskable.svg'
]);
function fileName(url){const parts=url.pathname.split('/');return parts[parts.length-1]||'';}
function isMobileAsset(url){return MOBILE_FILES.has(fileName(url));}
function injectRouter(html){
  if(html.includes('mobile-main-menu-v3.js'))return html;
  const tag='<script src="mobile-main-menu-v3.js?v=20260915-3"></script>';
  return html.includes('</body>')?html.replace('</body>',tag+'\n</body>'):html+tag;
}
self.addEventListener('install',event=>{
  event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll([
    './mobile.html','./mobile.css','./mobile-sales-support.css','./pwa-install.css','./mobile.js',
    './mobile-sales-support-home.js','./pwa-install.js','./mobile-main-menu-v3.js','./manifest.webmanifest',
    './pwa-icon.svg','./pwa-icon-maskable.svg'
  ]).catch(()=>{})).then(()=>self.skipWaiting()));
});
self.addEventListener('activate',event=>{
  event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k.startsWith('bb-mobile-shell-')&&k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()));
});
self.addEventListener('fetch',event=>{
  const request=event.request;if(request.method!=='GET')return;
  const url=new URL(request.url);if(url.origin!==self.location.origin||!isMobileAsset(url))return;
  if(fileName(url)==='mobile.html'){
    event.respondWith(fetch(request,{cache:'no-store'}).then(async response=>{
      if(!response.ok)return response;
      const text=injectRouter(await response.text());
      return new Response(text,{status:response.status,statusText:response.statusText,headers:{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store'}});
    }).catch(async()=>{
      const cached=await caches.match('./mobile.html');
      if(!cached)throw new Error('Offline and mobile shell unavailable.');
      return new Response(injectRouter(await cached.text()),{headers:{'Content-Type':'text/html; charset=utf-8'}});
    }));
    return;
  }
  event.respondWith(fetch(request,{cache:'no-store'}).then(response=>{
    if(response&&response.ok){const copy=response.clone();caches.open(CACHE).then(cache=>cache.put(request,copy)).catch(()=>{});}return response;
  }).catch(async()=>{const cached=await caches.match(request,{ignoreSearch:true});if(cached)return cached;throw new Error('Offline and asset is not cached.');}));
});