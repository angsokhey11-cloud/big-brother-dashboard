/* BIG BROTHER Mobile PWA service worker V1 */
const CACHE='bb-mobile-shell-v1';
const MOBILE_FILES=new Set([
  'mobile.html',
  'mobile.css',
  'mobile-sales-support.css',
  'mobile.js',
  'mobile-sales-support-home.js',
  'pwa-install.js',
  'manifest.webmanifest',
  'pwa-icon.svg',
  'pwa-icon-maskable.svg'
]);

function fileName(url){
  const parts=url.pathname.split('/');
  return parts[parts.length-1]||'';
}
function isMobileAsset(url){return MOBILE_FILES.has(fileName(url));}

self.addEventListener('install',event=>{
  event.waitUntil(
    caches.open(CACHE)
      .then(cache=>cache.addAll([
        './mobile.html',
        './mobile.css',
        './mobile-sales-support.css',
        './mobile.js',
        './mobile-sales-support-home.js',
        './pwa-install.js',
        './manifest.webmanifest',
        './pwa-icon.svg',
        './pwa-icon-maskable.svg'
      ]).catch(()=>{}))
      .then(()=>self.skipWaiting())
  );
});

self.addEventListener('activate',event=>{
  event.waitUntil(
    caches.keys()
      .then(keys=>Promise.all(keys.filter(k=>k.startsWith('bb-mobile-shell-')&&k!==CACHE).map(k=>caches.delete(k))))
      .then(()=>self.clients.claim())
  );
});

self.addEventListener('fetch',event=>{
  const request=event.request;
  if(request.method!=='GET')return;
  const url=new URL(request.url);
  if(url.origin!==self.location.origin||!isMobileAsset(url))return;

  event.respondWith(
    fetch(request)
      .then(response=>{
        if(response&&response.ok){
          const copy=response.clone();
          caches.open(CACHE).then(cache=>cache.put(request,copy)).catch(()=>{});
        }
        return response;
      })
      .catch(async()=>{
        const cached=await caches.match(request,{ignoreSearch:true});
        if(cached)return cached;
        if(fileName(url)==='mobile.html')return caches.match('./mobile.html');
        throw new Error('Offline and asset is not cached.');
      })
  );
});
