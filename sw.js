/* BIG BROTHER Mobile + Desktop PWA service worker V2.0 — Web Push */
const CACHE='bb-mobile-shell-v140';
const MOBILE_FILES=new Set([
  'mobile.html','mobile-function-icons-v1.js','mobile-home-theme-v5.css','mobile.css','mobile-sales-support.css','pwa-install.css','mobile.js','mobile-offline-workspace-v1.js','mobile-original-photo-cache-v1.js','mobile-original-photo-settings-v1.js','mobile-offline-modules-v1.js','mobile-universal-readonly-v1.js','mobile-offline-calculator.html','mobile-offline-your-customer-v1.html','mobile-offline-your-collection-mobile-v1.html','mobile-offline-your-collection-original-v1.html','mobile-offline-your-collection-adapter-v1.js','mobile-offline-your-collection-skin-v1.html','mobile-offline-calculator-source-v1.html','mobile-offline-calculator-dual-currency-v1.js','mobile-offline-calculator-adapter-v1.js','mobile-offline-history-original-v1.html','mobile-offline-history-mobile-v1.html','mobile-offline-history-adapter-v1.js','mobile-offline-monthly-sales-v1.html','mobile-offline-monthly-common-v1.js','mobile-offline-monthly-style-v1.css','mobile-offline-staff-adapter-v12.js','mobile-offline-your-stock-v12.html','mobile-offline-your-stock-source-v12.html','mobile-offline-tracker-v12.html','mobile-offline-tracker-source-v12.html','mobile-offline-daily-sale-v1.html','mobile-offline-stock.html','mobile-offline-stock-source-v1.html','mobile-user-overview.js',
  'mobile-sales-support-home.js','pwa-install.js','mobile-main-menu-v3.js','mobile-main-menu-stockcontrol-v5.js','mobile-ui-policy-v1.js',
  'mobile-navigation-v5.js','mobile-module-transition-v3.js','mobile-ios-decimal-v1.js','bb-web-push-client-v1.js','bb-native-online-push-v1.js','mobile-theme-v1.js','manifest.webmanifest','pwa-icon.svg','pwa-icon-maskable.svg','pwa-icon-192.png','pwa-icon-512.png','big-brother-angkor-login.png'
]);
function fileName(url){const parts=url.pathname.split('/');return parts[parts.length-1]||''}
function isMobileAsset(url){return MOBILE_FILES.has(fileName(url))}
function injectRouter(html){
  let out=html;
  if(!out.includes('data-bb-router-v4')&&!out.includes('data-bb-main-menu-v4')){const tag='<script data-bb-router-v4 src="mobile-main-menu-v3.js?v=20261029-option-b-mobile4"></script>';out=out.includes('</body>')?out.replace('</body>',tag+'\n</body>'):out+tag}
  if(!out.includes('data-bb-user-overview-v4')){const tag='<script data-bb-user-overview-v4 src="mobile-user-overview.js?v=20260920-liveoverview2"></script>';out=out.includes('</body>')?out.replace('</body>',tag+'\n</body>'):out+tag}
  if(!out.includes('data-bb-mobile-policy-v1')){const tag='<script data-bb-mobile-policy-v1 src="mobile-ui-policy-v1.js?v=20260915-2"></script>';out=out.includes('</body>')?out.replace('</body>',tag+'\n</body>'):out+tag}
  if(!out.includes('data-bb-navigation-v5')){const tag='<script data-bb-navigation-v5 src="mobile-navigation-v5.js?v=20260920-history6"></script>';out=out.includes('</body>')?out.replace('</body>',tag+'\n</body>'):out+tag}
  if(!out.includes('data-bb-ios-decimal-v1')){const tag='<script data-bb-ios-decimal-v1 src="mobile-ios-decimal-v1.js?v=20260920-iosdecimal3"></script>';out=out.includes('</body>')?out.replace('</body>',tag+'\n</body>'):out+tag}
  if(!out.includes('data-bb-theme-v1')){const tag='<script data-bb-theme-v1 src="mobile-theme-v1.js?v=20260920-premiumlight5"></script>';out=out.includes('</body>')?out.replace('</body>',tag+'\n</body>'):out+tag}
  return out;
}

/*
 * Mobile Performance V2
 * - Only the dashboard's public, versioned application files are cached.
 * - App shell is served immediately from cache after installation, then
 *   refreshed in the background so subsequent launches get new HTML.
 * - Versioned CSS/JS remains cache-first until its URL version changes.
 * - Never intercept authentication, Supabase APIs, user files, or writes.
 */
const APP_PREFIX=new URL('./',self.registration.scope).pathname;
const SHELL_URL=new URL('./mobile.html',self.registration.scope).href;
const PRECACHE=[
  './mobile.html',
  './mobile.css?v=20261006-login17',
  './mobile-home-theme-v5.css?v=20261029-header-layout2',
  './mobile-sales-support.css?v=20260921-overviewtap2',
  './pwa-install.css?v=20260920-ios1',
  './mobile-function-icons-v1.js?v=20261025-receivable-collection-v2',
  './mobile-offline-workspace-v1.js?v=20261029-v6-liveget2',
  './mobile.js?v=20261029-option-b-mobile4',
  './mobile-main-menu-stockcontrol-v5.js?v=20261029-option-b-mobile4',
  './mobile-user-overview.js?v=20261028-auto-offline3',
  './mobile-navigation-v5.js?v=20261008-batchtransfer-mobile1',
  './mobile-ios-decimal-v1.js?v=20260920-iosdecimal3',
  './mobile-theme-v1.js?v=20261005-angkor-login16',
  './mobile-sales-support-home.js?v=20261028-collection1',
  './mobile-original-photo-cache-v1.js?v=20261028-photo-cache1',
  './mobile-original-photo-settings-v1.js?v=20261028-photo-cache1',
  './mobile-offline-modules-v1.js?v=20261029-auto-reconnect3',
  './mobile-universal-readonly-v1.js?v=20261029-auto-reconnect3',
  './mobile-offline-your-customer-v1.html?embed=1&v=20261028-interactive1',
  './mobile-offline-your-collection-mobile-v1.html?embed=1&v=20261028-collection1',
  './mobile-offline-your-collection-original-v1.html?embed=1&mobileSkin=1&v=20261028-collection1',
  './mobile-offline-your-collection-adapter-v1.js?v=20261028-collection1',
  './mobile-offline-your-collection-skin-v1.html?v=20261028-collection1',
  './mobile-offline-stock.html?embed=1&v=20261028-seamless1',
  './mobile-offline-stock-source-v1.html?v=20261028-seamless1',
  './mobile-offline-calculator.html?mobile=1&view=calculator&v=20261028-seamless1',
  './mobile-offline-calculator-source-v1.html?v=20261028-seamless1',
  './mobile-offline-history-original-v1.html?embed=1&mobileSkin=1&v=20261028-alllines1',
  './mobile-offline-history-mobile-v1.html?embed=1&v=20261028-alllines1',
  './mobile-offline-history-adapter-v1.js?v=20261028-alllines1',
  './mobile-offline-monthly-sales-v1.html?embed=1&v=20261028-monthly1',
  './mobile-offline-monthly-common-v1.js?v=20261028-monthly1',
  './mobile-offline-monthly-style-v1.css?v=20261028-monthly1',
  './mobile-offline-staff-adapter-v12.js?v=20261028-stock-batchfix1',
  './mobile-offline-your-stock-v12.html?embed=1&v=20261028-stock-batchfix1',
  './mobile-offline-your-stock-source-v12.html?embed=1&mobileSkin=1&v=20261028-stock-batchfix1',
  './mobile-offline-tracker-v12.html?embed=1&v=20261028-v12',
  './mobile-offline-tracker-source-v12.html?mobile=1&v=20261028-v12',
  './mobile-offline-daily-sale-v1.html?embed=1&v=20261028-v12-fast1',
  './mobile-offline-calculator-dual-currency-v1.js?v=20261028-sameui1',
  './mobile-offline-calculator-adapter-v1.js?v=20261028-seamless1',
  './pwa-install.js?v=20261024-mobileperf1',
  './mobile-module-transition-v3.js?v=20261024-module-transition1',
  './bb-web-push-client-v1.js?v=20261025-webpush-v1',
  './mobile-ui-policy-v1.js?v=20260915-2',
  './manifest.webmanifest?v=20261029-localpwa1',
  './pwa-icon-192.png',
  './pwa-icon-512.png',
  './pwa-icon.svg',
  './pwa-icon-maskable.svg',
  './assets/big-brother-angkor-login.png'
];
function withinMobileShell(url){
  return url.origin===self.location.origin &&
    url.pathname.startsWith(APP_PREFIX) &&
    isMobileAsset(url);
}
async function shellResponse(response){
  const html=injectRouter(await response.text());
  return new Response(html,{
    status:200,
    headers:{'Content-Type':'text/html; charset=utf-8'}
  });
}
self.addEventListener('install',event=>{
  event.waitUntil((async()=>{
    const cache=await caches.open(CACHE);
    // The main shell must be present before an updated worker takes control.
    await cache.add(new Request(SHELL_URL,{cache:'reload'}));
    // Never activate the new worker unless its critical offline-first scripts exist.
    // Other decorations remain optional; old worker stays active on failed install.
    const critical=new Set([
      './mobile-offline-workspace-v1.js?v=20261029-v6-liveget2',
      './mobile.js?v=20261029-option-b-mobile4',
      './mobile-main-menu-stockcontrol-v5.js?v=20261029-option-b-mobile4',
      './mobile-sales-support-home.js?v=20261028-collection1',
      './mobile-user-overview.js?v=20261028-auto-offline3',
      './mobile-original-photo-cache-v1.js?v=20261028-photo-cache1',
  './mobile-original-photo-settings-v1.js?v=20261028-photo-cache1',
  './mobile-offline-modules-v1.js?v=20261029-auto-reconnect3',
      './mobile-universal-readonly-v1.js?v=20261029-auto-reconnect3',
      './mobile-offline-your-customer-v1.html?embed=1&v=20261028-interactive1',
  './mobile-offline-your-collection-mobile-v1.html?embed=1&v=20261028-collection1',
  './mobile-offline-your-collection-original-v1.html?embed=1&mobileSkin=1&v=20261028-collection1',
  './mobile-offline-your-collection-adapter-v1.js?v=20261028-collection1',
  './mobile-offline-your-collection-skin-v1.html?v=20261028-collection1',
  './mobile-offline-stock.html?embed=1&v=20261028-seamless1',
      './mobile-offline-stock-source-v1.html?v=20261028-seamless1',
      './mobile-offline-calculator.html?mobile=1&view=calculator&v=20261028-seamless1',
      './mobile-offline-calculator-source-v1.html?v=20261028-seamless1',
      './mobile-offline-history-original-v1.html?embed=1&mobileSkin=1&v=20261028-alllines1',
      './mobile-offline-history-mobile-v1.html?embed=1&v=20261028-alllines1',
      './mobile-offline-history-adapter-v1.js?v=20261028-alllines1',
      './mobile-offline-monthly-sales-v1.html?embed=1&v=20261028-monthly1',
      './mobile-offline-monthly-common-v1.js?v=20261028-monthly1',
      './mobile-offline-monthly-style-v1.css?v=20261028-monthly1',
      './mobile-offline-staff-adapter-v12.js?v=20261028-stock-batchfix1',
      './mobile-offline-your-stock-v12.html?embed=1&v=20261028-stock-batchfix1',
      './mobile-offline-your-stock-source-v12.html?embed=1&mobileSkin=1&v=20261028-stock-batchfix1',
      './mobile-offline-tracker-v12.html?embed=1&v=20261028-v12',
      './mobile-offline-tracker-source-v12.html?mobile=1&v=20261028-v12',
      './mobile-offline-daily-sale-v1.html?embed=1&v=20261028-v12-fast1',
      './mobile-offline-calculator-dual-currency-v1.js?v=20261028-sameui1',
      './mobile-offline-calculator-adapter-v1.js?v=20261028-seamless1'
    ]);
    await Promise.all([...critical].map(path=>
      cache.add(new Request(new URL(path,self.registration.scope),{cache:'reload'}))
    ));
    await Promise.allSettled(PRECACHE.filter(path=>path!=='./mobile.html'&&!critical.has(path))
      .map(path=>cache.add(new Request(new URL(path,self.registration.scope),{cache:'reload'}))));
    await self.skipWaiting();
  })());
});
self.addEventListener('activate',event=>{
  event.waitUntil((async()=>{
    const keys=await caches.keys();
    await Promise.all(keys
      .filter(name=>name.startsWith('bb-mobile-shell-')&&name!==CACHE)
      .map(name=>caches.delete(name)));
    await self.clients.claim();
  })());
});
self.addEventListener('fetch',event=>{
  const request=event.request;
  if(request.method!=='GET')return;
  const url=new URL(request.url);
  if(!withinMobileShell(url))return;

  if(fileName(url)==='mobile.html'){
    // The fresh shell download never blocks displaying an installed app.
    const refresh=fetch(request,{cache:'no-store'}).then(async response=>{
      if(response.ok){
        const cache=await caches.open(CACHE);
        await cache.put(SHELL_URL,response.clone());
      }
      return response;
    }).catch(()=>null);
    event.waitUntil(refresh.then(()=>undefined));
    event.respondWith((async()=>{
      const cache=await caches.open(CACHE);
      const cached=await cache.match(SHELL_URL);
      if(cached)return shellResponse(cached);
      const response=await refresh;
      if(response?.ok)return shellResponse(response);
      return new Response('BIG BROTHER mobile shell unavailable.',{status:503});
    })());
    return;
  }

  event.respondWith((async()=>{
    const cache=await caches.open(CACHE);
    // URLs include ?v=...; a new release gets its own cache entry.
    const cached=await cache.match(request);
    if(cached)return cached;
    try{
      const response=await fetch(request);
      if(response.ok)await cache.put(request,response.clone());
      return response;
    }catch(error){
      // Only fall back across query versions when actually offline.
      const offlineCopy=await cache.match(request,{ignoreSearch:true});
      if(offlineCopy)return offlineCopy;
      throw error;
    }
  })());
});


/* BIG BROTHER Web Push V1: visible notifications only, with no polling. */
self.addEventListener('push',event=>{
  event.waitUntil((async()=>{
    let msg={};
    try{msg=event.data?.json()||{}}catch(_){msg={}}
    const data=msg?.data&&typeof msg.data==='object'?msg.data:{};
    const route=typeof data.route==='string'&&/^[a-z0-9-]{2,70}$/.test(data.route)?data.route:'notification-center';
    await self.registration.showNotification('BIG BROTHER',{
      body:String(msg.body||'New important business activity').slice(0,220),
      icon:new URL('./pwa-icon.svg',self.registration.scope).href,
      badge:new URL('./pwa-icon.svg',self.registration.scope).href,
      tag:String(msg.tag||route).slice(0,180),
      renotify:false,
      data:{
        route,
        entityId:String(data.entityId||'').slice(0,160),
        eventKey:String(data.eventKey||'').slice(0,250)
      }
    });
  })());
});

self.addEventListener('notificationclick',event=>{
  event.notification.close();
  event.waitUntil((async()=>{
    const payload=event.notification.data||{};
    const route=/^[a-z0-9-]{2,70}$/.test(String(payload.route||''))?payload.route:'notification-center';
    const allClients=await self.clients.matchAll({type:'window',includeUncontrolled:true});
    const pages=allClients.filter(c=>{
      try{const url=new URL(c.url);return url.origin===self.location.origin&&
        url.pathname.startsWith(APP_PREFIX)&&
        /\/(mobile|index)\.html$/.test(url.pathname)}catch(_){return false}
    });
    // Prefer the window that the user is already using, not an unrelated
    // mobile tab when the desktop PWA was the origin of the notification.
    const home=pages.find(c=>c.focused)||
      pages.find(c=>c.visibilityState==='visible')||pages[0]||null;
    const ua=String(self.navigator?.userAgent||'');
    const mobile=home ? new URL(home.url).pathname.endsWith('/mobile.html')
      : /Android|iPhone|iPad|iPod|Mobile/i.test(ua);
    const target=new URL(mobile?'./mobile.html':'./index.html',self.registration.scope);
    target.searchParams.set('module',route);
    target.searchParams.set('autoload','1');
    if(payload.eventKey)target.searchParams.set('bb_notice',String(payload.eventKey));
    if(payload.entityId)target.searchParams.set('bb_entity',String(payload.entityId));
    if(home){
      try{
        // Reload the SAME installed PWA window with an explicit module URL.
        // A plain focus() opens Home, losing the record link.
        const navigated=await home.navigate(target.href);
        if(navigated){await navigated.focus();return}
      }catch(_){}
    }
    await self.clients.openWindow(target.href);
  })());
});
