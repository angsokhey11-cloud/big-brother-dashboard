/* BIG BROTHER dashboard desktop workspace expansion V1 */
(function(){
'use strict';
const key='BB_DASHBOARD_SIDEBAR_COLLAPSED_V1';
const css=document.createElement('style');
css.textContent=`
@media(min-width:721px){
 body.bb-sidebar-collapsed .sidebar{display:none!important}
 body.bb-sidebar-collapsed .shell-main{margin-left:0!important;width:100%!important}
 body.bb-sidebar-collapsed .main{margin-left:0!important;width:100%!important}
}
#bbSidebarToggle{
 position:fixed;top:50%;left:242px;transform:translateY(-50%);
 z-index:2147481000;width:29px;height:64px;
 border:1px solid #b9cbe0;border-radius:0 10px 10px 0;
 background:#fff;color:#17457a;box-shadow:0 2px 10px #123b6226;
 font-size:18px;font-weight:800;cursor:pointer;
 display:flex;align-items:center;justify-content:center;padding:0;
 transition:left .18s ease
}
body.bb-sidebar-collapsed #bbSidebarToggle{left:0}
#bbSidebarToggle:hover{background:#e8f2fc}
#bbSidebarToggle:focus-visible{outline:3px solid #6ca7eb;outline-offset:2px}
@media(max-width:720px){#bbSidebarToggle{display:none!important}}
`;
document.head.appendChild(css);
function init(){
 if(!document.querySelector('.sidebar')||!document.querySelector('.shell-main'))return;
 const btn=document.createElement('button');
 btn.id='bbSidebarToggle';btn.type='button';
 document.body.appendChild(btn);
 function set(collapsed){
  document.body.classList.toggle('bb-sidebar-collapsed',collapsed);
  btn.textContent=collapsed?'❯':'❮';
  btn.title=collapsed?'Expand Main Menu':'Collapse Main Menu';
  btn.setAttribute('aria-label',btn.title);
  btn.setAttribute('aria-expanded',String(!collapsed));
  try{localStorage.setItem(key,collapsed?'1':'0')}catch(_){}
  window.dispatchEvent(new Event('resize'));
 }
 let previous=false;
 try{previous=localStorage.getItem(key)==='1'}catch(_){}
 set(previous);
 btn.addEventListener('click',()=>set(!document.body.classList.contains('bb-sidebar-collapsed')));
}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});else init();
})();