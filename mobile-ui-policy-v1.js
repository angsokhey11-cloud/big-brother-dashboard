/* BIG BROTHER — Mobile UI Policy V1
   Mobile dashboard only. Desktop dashboard untouched. */
(function(){
'use strict';

const HIDDEN_ROUTES=new Set([
  'sales-support-request-delivery',
  'sales-support-successful-delivery'
]);

function routeOf(el){
  return el?.dataset?.salesRoute||el?.dataset?.menuRoute||el?.dataset?.bbRoute||el?.dataset?.pickRoute||el?.dataset?.route||'';
}

function removeHiddenRouteElements(root=document){
  root.querySelectorAll?.('[data-sales-route],[data-menu-route],[data-bb-route],[data-pick-route],[data-route]').forEach(el=>{
    if(HIDDEN_ROUTES.has(routeOf(el)))el.remove();
  });
}

function hideDesktopButtons(){
  document.querySelectorAll('#moduleDesktopLink,.desktop-small,.desktop-link,[data-desktop-link]').forEach(el=>{
    el.hidden=true;
    el.style.setProperty('display','none','important');
  });
}

function cleanEmptyMenuGroups(){
  document.querySelectorAll('.bb-dd-group,.bb-menu-group').forEach(group=>{
    const hasButton=group.querySelector('[data-menu-route],[data-bb-route],[data-route]');
    if(!hasButton)group.remove();
  });
}

function apply(){
  hideDesktopButtons();
  removeHiddenRouteElements();
  cleanEmptyMenuGroups();
}

function patchOpen(){
  const mobile=window.BBMobile;
  if(!mobile||typeof mobile.open!=='function'||mobile.open.__bbPolicyWrapped)return;
  const original=mobile.open.bind(mobile);
  const wrapped=function(route){
    if(HIDDEN_ROUTES.has(String(route||'')))return false;
    return original.apply(null,arguments);
  };
  wrapped.__bbPolicyWrapped=true;
  mobile.open=wrapped;
}

function start(){
  apply();
  patchOpen();
  new MutationObserver(()=>{
    apply();
    patchOpen();
  }).observe(document.documentElement,{childList:true,subtree:true,attributes:true,attributeFilter:['hidden','class']});
  setInterval(()=>{apply();patchOpen()},1200);
}

if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});
else start();

window.BBMobileUIPolicyV1={hiddenRoutes:HIDDEN_ROUTES,apply};
})();
