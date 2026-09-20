/* BIG BROTHER Mobile PWA service worker V1.8 */
const CACHE='bb-mobile-shell-v42';
const MOBILE_FILES=new Set([
  'mobile.html','mobile.css','mobile-sales-support.css','pwa-install.css','mobile.js',
  'mobile-sales-support-home.js','pwa-install.js','mobile-main-menu-v3.js','mobile-ui-policy-v1.js',
  'mobile-navigation-v5.js','mobile-ios-decimal-v1.js','mobile-theme-v1.js','manifest.webmanifest','pwa-icon.svg','pwa-icon-maskable.svg'
]);
function fileName(url){const parts=url.pathname.split('/');return parts[parts.length-1]||''}
function isMobileAsset(url){return MOBILE_FILES.has(fileName(url))}
function injectRouter(html){
  let out=html;
  if(!out.includes('data-bb-router-v4')){const tag='<script data-bb-router-v4 src="mobile-main-menu-v3.js?v=20260920-history3"></script>';out=out.includes('</body>')?out.replace('</body>',tag+'\n</body>'):out+tag}
  if(!out.includes('data-bb-mobile-policy-v1')){const tag='<script data-bb-mobile-policy-v1 src="mobile-ui-policy-v1.js?v=20260915-2"></script>';out=out.includes('</body>')?out.replace('</body>',tag+'\n</body>'):out+tag}
  if(!out.includes('data-bb-navigation-v5')){const tag='<script data-bb-navigation-v5 src="mobile-navigation-v5.js?v=20260920-history6"></script>';out=out.includes('</body>')?out.replace('</body>',tag+'\n</body>'):out+tag}
  if(!out.includes('data-bb-ios-decimal-v1')){const tag='<script data-bb-ios-decimal-v1 src="mobile-ios-decimal-v1.js?v=20260920-iosdecimal3"></script>';out=out.includes('</body>')?out.replace('</body>',tag+'\n</body>'):out+tag}
  if(!out.includes('data-bb-theme-v1')){const tag='<script data-bb-theme-v1 src="mobile-theme-v1.js?v=20260920-premiumlight5"></script>';out=out.includes('</body>')?out.replace('</body>',tag+'\n</body>'):out+tag}
  return out;
}
self.addEventListener('install',event=>{event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll([
  './mobile.html','./mobile.css','./mobile-sales-support.css','./pwa-install.css','./mobile.js',
  './mobile-sales-support-home.js','./pwa-install.js','./mobile-main-menu-v3.js','./mobile-ui-policy-v1.js',
  './mobile-navigation-v5.js','./mobile-ios-decimal-v1.js','./mobile-theme-v1.js','./manifest.webmanifest','./pwa-icon.svg','./pwa-icon-maskable.svg'
]).catch(()=>{})).then(()=>self.skipWaiting()))});
self.addEventListener('activate',event=>{
  event.waitUntil(
    caches.keys()
      .then(keys=>Promise.all(keys.filter(k=>k.startsWith('bb-mobile-shell-')&&k!==CACHE).map(k=>caches.delete(k))))
      .then(()=>self.clients.claim())
      .then(()=>self.clients.matchAll({type:'window',includeUncontrolled:true}))
      .then(clients=>Promise.all(clients.map(client=>{
        try{
          const url=new URL(client.url);
          if(url.origin!==self.location.origin)return null;
          const name=fileName(url);
          if(name!=='mobile.html'&&!url.pathname.endsWith('/big-brother-dashboard/'))return null;
          return client.navigate(client.url).catch(()=>null);
        }catch(_){return null}
      })))
  );
});
self.addEventListener('fetch',event=>{
  const request=event.request;if(request.method!=='GET')return;
  const url=new URL(request.url);if(url.origin!==self.location.origin||!isMobileAsset(url))return;
  if(fileName(url)==='mobile.html'){
    event.respondWith(fetch(request,{cache:'no-store'}).then(async response=>{if(!response.ok)return response;const text=injectRouter(await response.text());return new Response(text,{status:response.status,statusText:response.statusText,headers:{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store'}})}).catch(async()=>{const cached=await caches.match('./mobile.html');if(!cached)throw new Error('Offline and mobile shell unavailable.');return new Response(injectRouter(await cached.text()),{headers:{'Content-Type':'text/html; charset=utf-8'}})}));return;
  }
  event.respondWith(fetch(request,{cache:'no-store'}).then(response=>{if(response&&response.ok){const copy=response.clone();caches.open(CACHE).then(cache=>cache.put(request,copy)).catch(()=>{})}return response}).catch(async()=>{const cached=await caches.match(request,{ignoreSearch:true});if(cached)return cached;throw new Error('Offline and asset is not cached.')}));
});
