/* BIG BROTHER — Premium Mobile Theme V1
   Mobile app only. Desktop styling is not modified here. */
(function(){
'use strict';

const STORAGE_KEY='BB_MOBILE_THEME_V1';
const ROOT=document.documentElement;
const $=id=>document.getElementById(id);
let theme='light';

function readTheme(){
  try{
    const saved=localStorage.getItem(STORAGE_KEY);
    return saved==='dark'||saved==='light'?saved:'light';
  }catch(_){return'light'}
}
function saveTheme(next){try{localStorage.setItem(STORAGE_KEY,next)}catch(_){}}

function injectShellCss(){
  if($('bbPremiumThemeCss'))return;
  const style=document.createElement('style');
  style.id='bbPremiumThemeCss';
  style.textContent=`
    .boot-logo{overflow:hidden!important;padding:0!important;background:#07111f!important;box-shadow:0 0 0 1px #55c7ff33,0 10px 28px #00102555!important}
    .boot-logo img{display:block;width:100%;height:100%;object-fit:cover}
    .bb-theme-option{position:relative}
    .bb-theme-pill{margin-left:auto;min-width:48px;height:25px;border-radius:999px;padding:0 8px;display:grid;place-items:center;background:#e8eef5;color:#46627f;font-size:8px;font-weight:900}

    html[data-bb-theme="dark"]{color-scheme:dark;background:#050b13}
    html[data-bb-theme="dark"] body{background:#050b13!important;color:#dce8f5}
    html[data-bb-theme="dark"] .mobile-home,
    html[data-bb-theme="dark"] .menu-screen,
    html[data-bb-theme="dark"] .module-screen{background:#07111f!important;color:#dce8f5}
    html[data-bb-theme="dark"] .mobile-scroll,
    html[data-bb-theme="dark"] #menuGrid.bb-dropdown-menu{background:#07111f!important}
    html[data-bb-theme="dark"] .hero,
    html[data-bb-theme="dark"] .simple-header,
    html[data-bb-theme="dark"] .module-header{background:linear-gradient(135deg,#07111f,#0b2744 58%,#075d82)!important;box-shadow:0 10px 30px #0008!important}
    html[data-bb-theme="dark"] .panel,
    html[data-bb-theme="dark"] .menu-card,
    html[data-bb-theme="dark"] .bb-dd-group,
    html[data-bb-theme="dark"] .sheet-card,
    html[data-bb-theme="dark"] .login-card{background:#0d1928!important;border-color:#203650!important;box-shadow:0 8px 24px #0005!important}
    html[data-bb-theme="dark"] .section-head strong,
    html[data-bb-theme="dark"] .quick-btn,
    html[data-bb-theme="dark"] .quick-btn>span,
    html[data-bb-theme="dark"] .recent-main strong,
    html[data-bb-theme="dark"] .sheet-card h3,
    html[data-bb-theme="dark"] .sheet-option,
    html[data-bb-theme="dark"] .sheet-option strong,
    html[data-bb-theme="dark"] .bb-dd-copy strong,
    html[data-bb-theme="dark"] .login-brand{color:#e9f4ff!important}
    html[data-bb-theme="dark"] .section-head span,
    html[data-bb-theme="dark"] .recent-main span,
    html[data-bb-theme="dark"] .recent-side span,
    html[data-bb-theme="dark"] .sheet-card p,
    html[data-bb-theme="dark"] .sheet-option small,
    html[data-bb-theme="dark"] .bb-dd-copy small,
    html[data-bb-theme="dark"] .login-sub{color:#8fa7bf!important}
    html[data-bb-theme="dark"] .bottom-nav{background:#081421f7!important;border-top-color:#203650!important;box-shadow:0 -7px 22px #0005!important}
    html[data-bb-theme="dark"] .nav-btn{color:#8197ad!important}
    html[data-bb-theme="dark"] .nav-btn.active{color:#5bc7ff!important;background:#10263b!important}
    html[data-bb-theme="dark"] .quick-icon,
    html[data-bb-theme="dark"] .recent-icon{background:linear-gradient(145deg,#11263a,#0d1b2b)!important;box-shadow:inset 0 0 0 1px #31516d66!important}
    html[data-bb-theme="dark"] .recent-row{border-bottom-color:#1b2f45!important}
    html[data-bb-theme="dark"] .recent-side strong{color:#68cfff!important}
    html[data-bb-theme="dark"] #kpiGrid .sales-kpi{background:#102033!important;box-shadow:inset 0 0 0 1px #29435f!important}
    html[data-bb-theme="dark"] #kpiGrid .sales-kpi small{color:#9ab0c6!important}
    html[data-bb-theme="dark"] #kpiGrid .sales-kpi strong{color:#eaf5ff!important}
    html[data-bb-theme="dark"] #kpiGrid .sales-kpi em{color:#8199b2!important}
    html[data-bb-theme="dark"] .bb-dd-group>summary,
    html[data-bb-theme="dark"] .bb-dd-item{background:#0d1928!important;color:#e4eef8!important;border-color:#1b2f45!important}
    html[data-bb-theme="dark"] .bb-dd-group[open]>summary{background:#102033!important;border-color:#203650!important}
    html[data-bb-theme="dark"] .bb-dd-tag.mobile{background:#0b3e42!important;color:#70e7dc!important}
    html[data-bb-theme="dark"] .bb-dd-tag.pc{background:#202b38!important;color:#a9b8c7!important}
    html[data-bb-theme="dark"] .sheet{background:#000a!important}
    html[data-bb-theme="dark"] .sheet-option{background:#101e2e!important;border-color:#24394f!important}
    html[data-bb-theme="dark"] .sheet-close{background:#182a3d!important;color:#dce8f5!important}
    html[data-bb-theme="dark"] .bb-theme-pill{background:#0b5270!important;color:#a6e8ff!important}
    html[data-bb-theme="dark"] .login-card input{background:#0a1522!important;border-color:#2b435c!important;color:#e7f1fb!important}
    html[data-bb-theme="dark"] .boot-screen,
    html[data-bb-theme="dark"] .login-screen{background:radial-gradient(circle at 70% 20%,#0d3d66 0,#07111f 44%,#03070d 100%)!important}
    html[data-bb-theme="dark"] .boot-card{background:#0d1928!important;border:1px solid #203650!important;box-shadow:0 24px 70px #0009!important}
    html[data-bb-theme="dark"] .boot-card strong{color:#edf7ff!important}
    html[data-bb-theme="dark"] .boot-card span{color:#8da4ba!important}
  `;
  document.head.appendChild(style);
}

function brandLogo(){
  const boot=document.querySelector('.boot-logo');
  if(boot&&!boot.querySelector('img')){
    boot.textContent='';
    const img=document.createElement('img');
    img.src='pwa-icon.svg?v=20260916-premium1';
    img.alt='BIG BROTHER';
    boot.appendChild(img);
  }
  const banner=document.querySelector('.pwa-install-logo');
  if(banner){
    banner.textContent='';
    banner.style.background='url("pwa-icon.svg?v=20260916-premium1") center/cover no-repeat';
  }
}

function ensureToggle(){
  const sheet=$('settingsSheet');
  const card=sheet?.querySelector('.sheet-card');
  if(!card||$('bbThemeToggle'))return;
  const signout=$('signOutBtn');
  const btn=document.createElement('button');
  btn.id='bbThemeToggle';
  btn.type='button';
  btn.className='sheet-option bb-theme-option';
  btn.innerHTML='<span id="bbThemeIcon">🌙</span><div><strong>Dark Mode</strong><small>Premium navy interface</small></div><span id="bbThemeState" class="bb-theme-pill">OFF</span>';
  btn.addEventListener('click',()=>setTheme(theme==='dark'?'light':'dark',true));
  if(signout)card.insertBefore(btn,signout);else card.appendChild(btn);
  updateToggle();
}

function updateToggle(){
  const state=$('bbThemeState'),icon=$('bbThemeIcon');
  if(state)state.textContent=theme==='dark'?'ON':'OFF';
  if(icon)icon.textContent=theme==='dark'?'☀️':'🌙';
}

function dedicatedMobileFrame(frame){
  try{
    const path=new URL(frame.src,location.href).pathname.toLowerCase();
    return path.includes('mobile')||path.includes('accounting-mobile')||path.includes('transactions-mobile')||path.includes('batch-mobile');
  }catch(_){return false}
}

function frameDarkCss(){return `
  html{color-scheme:dark!important;background:#07111f!important}body{background:#07111f!important;color:#dce8f5!important}
  header,.header,.topbar,.toolbar,.app-header{border-color:#203650!important}
  .card,.panel,.box,.section,.sheet-card,.modal,.dialog,.filter-card,.location-card,.product-card,.summary-card,.kpi-card,.report-card,.history-card,.transaction-card,.request-card{background:#0d1928!important;color:#dce8f5!important;border-color:#203650!important;box-shadow:0 5px 18px #0005!important}
  input,select,textarea{background:#091522!important;color:#e7f1fb!important;border-color:#2b435c!important}
  table,thead,tbody,tr,td,th{border-color:#203650!important}th{background:#102033!important;color:#dce8f5!important}td{background:#0b1725!important;color:#dce8f5!important}
  button{border-color:#28445f}
  .muted,.sub,.meta,small{color:#8fa7bf!important}
`}

function applyFrameTheme(){
  const frame=$('moduleFrame');
  if(!frame||!dedicatedMobileFrame(frame))return;
  try{
    const doc=frame.contentDocument;
    if(!doc?.head)return;
    let style=doc.getElementById('bbParentDarkTheme');
    if(theme==='dark'){
      if(!style){style=doc.createElement('style');style.id='bbParentDarkTheme';style.textContent=frameDarkCss();doc.head.appendChild(style)}
      doc.documentElement.setAttribute('data-bb-parent-theme','dark');
    }else{
      style?.remove();
      doc.documentElement.removeAttribute('data-bb-parent-theme');
    }
  }catch(_){ }
}

function setTheme(next,persist=false){
  theme=next==='dark'?'dark':'light';
  ROOT.setAttribute('data-bb-theme',theme);
  if(persist)saveTheme(theme);
  const meta=document.querySelector('meta[name="theme-color"]');
  if(meta)meta.setAttribute('content',theme==='dark'?'#07111f':'#1267b0');
  updateToggle();
  applyFrameTheme();
}

function start(){
  injectShellCss();
  theme=readTheme();
  setTheme(theme,false);
  brandLogo();
  ensureToggle();
  const frame=$('moduleFrame');
  if(frame&&!frame.dataset.bbThemeBound){
    frame.dataset.bbThemeBound='1';
    frame.addEventListener('load',()=>setTimeout(applyFrameTheme,40));
  }
  setTimeout(()=>{brandLogo();ensureToggle();applyFrameTheme()},400);
  setTimeout(()=>{brandLogo();ensureToggle();applyFrameTheme()},1400);
}

if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
window.BBMobileThemeV1={setTheme,getTheme:()=>theme,applyFrameTheme};
})();