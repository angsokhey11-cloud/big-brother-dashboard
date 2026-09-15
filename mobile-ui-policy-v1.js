/* BIG BROTHER — Mobile UI Policy V1.1
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

function hideDesktopHeaderButton(){
  const el=document.getElementById('moduleDesktopLink');
  if(!el)return;
  if(!el.hidden)el.hidden=true;
  if(el.style.display!=='none')el.style.display='none';
}

function cleanEmptyMenuGroups(){
  document.querySelectorAll('.bb-dd-group,.bb-menu-group').forEach(group=>{
    const hasButton=group.querySelector('[data-menu-route],[data-bb-route],[data-route],[data-sales-route],[data-pick-route]');
    if(!hasButton)group.remove();
  });
}

function apply(){
  hideDesktopHeaderButton();
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

let scheduled=false;
function scheduleApply(){
  if(scheduled)return;
  scheduled=true;
  requestAnimationFrame(()=>{
    scheduled=false;
    apply();
    patchOpen();
  });
}

function start(){
  apply();
  patchOpen();

  /* Child additions only. Do not watch attributes: changing hidden/style
     inside the policy must never trigger a self-sustaining observer loop. */
  new MutationObserver(scheduleApply).observe(document.body,{childList:true,subtree:true});

  document.addEventListener('click',event=>{
    const el=event.target?.closest?.('[data-sales-route],[data-menu-route],[data-bb-route],[data-pick-route],[data-route]');
    if(el&&HIDDEN_ROUTES.has(routeOf(el))){
      event.preventDefault();
      event.stopImmediatePropagation();
    }
  },true);

  setInterval(()=>{apply();patchOpen()},1500);
}

if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});
else start();

window.BBMobileUIPolicyV1={hiddenRoutes:HIDDEN_ROUTES,apply};
})();
