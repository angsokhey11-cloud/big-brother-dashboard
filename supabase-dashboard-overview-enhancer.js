/* BIG BROTHER — Monthly Overview V2 class stabilizer */
(function(){
'use strict';
let observer=null;
function apply(){
  document.querySelectorAll('.bb-ov-kpis > [data-route]').forEach(el=>{
    el.classList.add('bb-ov-kpi','bb-ov-clickable');
  });
  document.querySelectorAll('.bb-ov-activity > [data-route]').forEach(el=>{
    el.classList.add('bb-ov-act','bb-ov-clickable');
  });
}
function start(){
  apply();
  if(observer)return;
  observer=new MutationObserver(apply);
  observer.observe(document.documentElement,{childList:true,subtree:true});
}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
})();