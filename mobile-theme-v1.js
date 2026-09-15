/* BIG BROTHER — Premium Mobile Theme V1.1
   Mobile app shell + same-origin embedded function dark theme.
   Desktop dashboard styling is not modified here. */
(function(){
'use strict';

const STORAGE_KEY='BB_MOBILE_THEME_V1';
const ROOT=document.documentElement;
const $=id=>document.getElementById(id);
let theme='light';

function readTheme(){
  try{const saved=localStorage.getItem(STORAGE_KEY);return saved==='dark'||saved==='light'?saved:'light'}catch(_){return'light'}
}
function saveTheme(next){try{localStorage.setItem(STORAGE_KEY,next)}catch(_){}}

function injectShellCss(){
  if($('bbPremiumThemeCss'))return;
  const style=document.createElement('style');
  style.id='bbPremiumThemeCss';
  style.textContent=`
    .boot-logo{overflow:hidden!important;padding:0!important;background:#07111f!important;box-shadow:0 0 0 1px #55c7ff33,0 10px 28px #00102555!important}
    .boot-logo img{display:block;width:100%;height:100%;object-fit:cover}
    .bb-theme-option{position:relative}.bb-theme-pill{margin-left:auto;min-width:48px;height:25px;border-radius:999px;padding:0 8px;display:grid;place-items:center;background:#e8eef5;color:#46627f;font-size:8px;font-weight:900}

    html[data-bb-theme="dark"]{color-scheme:dark;background:#050b13}
    html[data-bb-theme="dark"] body{background:#050b13!important;color:#dce8f5!important}
    html[data-bb-theme="dark"] .mobile-home,
    html[data-bb-theme="dark"] .menu-screen,
    html[data-bb-theme="dark"] .module-screen,
    html[data-bb-theme="dark"] .mobile-scroll,
    html[data-bb-theme="dark"] #menuGrid.bb-dropdown-menu{background:#07111f!important;color:#dce8f5!important}
    html[data-bb-theme="dark"] .hero,
    html[data-bb-theme="dark"] .simple-header,
    html[data-bb-theme="dark"] .module-header{background:linear-gradient(135deg,#07111f,#0b2744 58%,#075d82)!important;box-shadow:0 10px 30px #0008!important}
    html[data-bb-theme="dark"] .panel,
    html[data-bb-theme="dark"] .menu-card,
    html[data-bb-theme="dark"] .bb-dd-group,
    html[data-bb-theme="dark"] .sheet-card,
    html[data-bb-theme="dark"] .login-card{background:#0d1928!important;border-color:#203650!important;box-shadow:0 8px 24px #0005!important}

    html[data-bb-theme="dark"] .section-head strong,
    html[data-bb-theme="dark"] #quickActions .quick-btn,
    html[data-bb-theme="dark"] #quickActions .quick-btn>span,
    html[data-bb-theme="dark"] .quick-btn>span,
    html[data-bb-theme="dark"] .recent-main strong,
    html[data-bb-theme="dark"] .sheet-card h3,
    html[data-bb-theme="dark"] .sheet-option,
    html[data-bb-theme="dark"] .sheet-option strong,
    html[data-bb-theme="dark"] .bb-dd-copy strong,
    html[data-bb-theme="dark"] .login-brand{color:#e9f4ff!important}
    html[data-bb-theme="dark"] #quickActions .quick-btn>span{color:#dbe8ff!important;text-shadow:0 1px 0 #0004!important}
    html[data-bb-theme="dark"] #quickActions .quick-btn:active>span{color:#fff!important}
    html[data-bb-theme="dark"] .section-head span,
    html[data-bb-theme="dark"] #quickCount,
    html[data-bb-theme="dark"] .recent-main span,
    html[data-bb-theme="dark"] .recent-side span,
    html[data-bb-theme="dark"] .sheet-card p,
    html[data-bb-theme="dark"] .sheet-option small,
    html[data-bb-theme="dark"] .bb-dd-copy small,
    html[data-bb-theme="dark"] .login-sub{color:#9bb3ca!important}

    html[data-bb-theme="dark"] .bottom-nav{background:#081421f7!important;border-top-color:#203650!important;box-shadow:0 -7px 22px #0005!important}
    html[data-bb-theme="dark"] .nav-btn{color:#9fb2c5!important}
    html[data-bb-theme="dark"] .nav-btn b{color:#b9d4eb!important}
    html[data-bb-theme="dark"] .nav-btn.active{color:#69d1ff!important;background:#10263b!important}
    html[data-bb-theme="dark"] .nav-btn.active b{color:#72d8ff!important}
    html[data-bb-theme="dark"] .quick-icon,
    html[data-bb-theme="dark"] .recent-icon{background:linear-gradient(145deg,#14304a,#0d1b2b)!important;box-shadow:inset 0 0 0 1px #31516d88,0 4px 12px #0004!important}
    html[data-bb-theme="dark"] .recent-row{border-bottom-color:#1b2f45!important}
    html[data-bb-theme="dark"] .recent-side strong{color:#68cfff!important}
    html[data-bb-theme="dark"] #kpiGrid .sales-kpi{background:#102033!important;box-shadow:inset 0 0 0 1px #29435f!important}
    html[data-bb-theme="dark"] #kpiGrid .sales-kpi small{color:#a8bdd1!important}
    html[data-bb-theme="dark"] #kpiGrid .sales-kpi strong{color:#edf8ff!important}
    html[data-bb-theme="dark"] #kpiGrid .sales-kpi em{color:#93aac1!important}
    html[data-bb-theme="dark"] .attention-card{background:#111f2f!important;border:1px solid #24394f!important}
    html[data-bb-theme="dark"] .attention-card b{color:#f3f8fd!important}
    html[data-bb-theme="dark"] .attention-card span{color:#9eb3c8!important}

    html[data-bb-theme="dark"] .bb-dd-group>summary,
    html[data-bb-theme="dark"] .bb-dd-item{background:#0d1928!important;color:#e4eef8!important;border-color:#1b2f45!important}
    html[data-bb-theme="dark"] .bb-dd-group[open]>summary{background:#102033!important;border-color:#203650!important}
    html[data-bb-theme="dark"] .bb-dd-left span{color:#eaf4ff!important}
    html[data-bb-theme="dark"] .bb-dd-arrow{color:#93abc2!important}
    html[data-bb-theme="dark"] .bb-dd-tag.mobile{background:#0b3e42!important;color:#70e7dc!important}
    html[data-bb-theme="dark"] .bb-dd-tag.pc{background:#202b38!important;color:#b7c4d1!important}
    html[data-bb-theme="dark"] .sheet{background:#000a!important}
    html[data-bb-theme="dark"] .sheet-option{background:#101e2e!important;border-color:#24394f!important}
    html[data-bb-theme="dark"] .sheet-close{background:#182a3d!important;color:#dce8f5!important}
    html[data-bb-theme="dark"] .bb-theme-pill{background:#0b5270!important;color:#b7efff!important}
    html[data-bb-theme="dark"] .login-card input{background:#0a1522!important;border-color:#2b435c!important;color:#e7f1fb!important}
    html[data-bb-theme="dark"] .boot-screen,
    html[data-bb-theme="dark"] .login-screen{background:radial-gradient(circle at 70% 20%,#0d3d66 0,#07111f 44%,#03070d 100%)!important}
    html[data-bb-theme="dark"] .boot-card{background:#0d1928!important;border:1px solid #203650!important;box-shadow:0 24px 70px #0009!important}
    html[data-bb-theme="dark"] .boot-card strong{color:#edf7ff!important}
    html[data-bb-theme="dark"] .boot-card span{color:#9bb1c5!important}
  `;
  document.head.appendChild(style);
}

function brandLogo(){
  const boot=document.querySelector('.boot-logo');
  if(boot&&!boot.querySelector('img')){
    boot.textContent='';const img=document.createElement('img');img.src='pwa-icon.svg?v=20260916-premium2';img.alt='BIG BROTHER';boot.appendChild(img);
  }
  const banner=document.querySelector('.pwa-install-logo');
  if(banner){banner.textContent='';banner.style.background='url("pwa-icon.svg?v=20260916-premium2") center/cover no-repeat'}
}

function ensureToggle(){
  const card=$('settingsSheet')?.querySelector('.sheet-card');
  if(!card||$('bbThemeToggle'))return;
  const signout=$('signOutBtn'),btn=document.createElement('button');
  btn.id='bbThemeToggle';btn.type='button';btn.className='sheet-option bb-theme-option';
  btn.innerHTML='<span id="bbThemeIcon">🌙</span><div><strong>Dark Mode</strong><small>Premium navy interface</small></div><span id="bbThemeState" class="bb-theme-pill">OFF</span>';
  btn.addEventListener('click',()=>setTheme(theme==='dark'?'light':'dark',true));
  if(signout)card.insertBefore(btn,signout);else card.appendChild(btn);updateToggle();
}
function updateToggle(){const state=$('bbThemeState'),icon=$('bbThemeIcon');if(state)state.textContent=theme==='dark'?'ON':'OFF';if(icon)icon.textContent=theme==='dark'?'☀️':'🌙'}

function frameDarkCss(){return `
  :root{color-scheme:dark!important;--bb-bg:#07111f;--bb-card:#0d1928;--bb-card-2:#102033;--bb-border:#203650;--bb-text:#e7f1fb;--bb-muted:#9bb0c6;--bb-blue:#63cfff}
  html,body{background:#07111f!important;color:#e7f1fb!important}
  body,main,.app,.page,.screen,.workspace,.container,.content,.content-wrap,.page-wrap,.main,.main-content,.mobile-page,.report-page,.history-page{color:#e7f1fb!important}
  header,.header,.topbar,.toolbar,.app-header,.page-header,.mobile-header,.report-header{border-color:#203650!important}
  .card,.panel,.box,.section,.sheet-card,.modal,.dialog,.filter-card,.filter-panel,.location-card,.product-card,.summary-card,.kpi,.kpi-card,.stat-card,.report-card,.history-card,.transaction-card,.request-card,.invoice-card,.item-card,.client-card,.customer-card,.batch-card,.stock-card,.expense-card,.payment-card,.statement-card,.accordion,.accordion-item,.table-wrap,.table-card,.form-card,.form-section,.detail-card,.result-card,.list-card{background:#0d1928!important;color:#e7f1fb!important;border-color:#203650!important;box-shadow:0 5px 18px #0005!important}
  h1,h2,h3,h4,h5,h6,.title,.page-title,.section-title,.card-title,.label,.name,strong,b{color:#eaf5ff!important}
  p,.subtitle,.description,.helper,.hint,.muted,.sub,.meta,.caption,.note,small,.small,.secondary,.timestamp,.date,.unit{color:#9bb0c6!important}
  a{color:#69cfff!important}
  input,select,textarea,.input,.select,.search,.search-input{background:#091522!important;color:#edf7ff!important;border-color:#2b435c!important;box-shadow:none!important}
  input::placeholder,textarea::placeholder{color:#718ba4!important}
  option{background:#0d1928!important;color:#edf7ff!important}
  table,thead,tbody,tr,td,th{border-color:#203650!important}th{background:#102033!important;color:#eaf5ff!important}td{background:#0b1725!important;color:#dce8f5!important}
  tbody tr:nth-child(even) td{background:#0d1a29!important}
  button,.btn,.button{border-color:#28445f}
  .btn-secondary,.secondary-btn,.ghost-btn,.filter-btn,.chip,.pill,.badge:not(.success):not(.danger):not(.warning){background:#13263a!important;color:#cfe4f6!important;border-color:#29445e!important}
  nav,.bottom-nav,.footer,.tabs,.tabbar{border-color:#203650!important}
  .tab,.nav-btn,.nav-item{color:#9eb2c6!important}.tab.active,.nav-btn.active,.nav-item.active{color:#64cfff!important;background:#10263b!important}
  hr,.divider,.separator{border-color:#203650!important;background:#203650!important}
  details,.collapse,.collapsible{border-color:#203650!important}summary{color:#e7f1fb!important}
  .empty,.empty-state,.loading,.status-text{color:#9bb0c6!important}
  .overlay,.modal-backdrop{background:#0009!important}
`}

function applyFrameTheme(){
  const frame=$('moduleFrame');if(!frame)return;
  try{
    const doc=frame.contentDocument;if(!doc?.head)return;
    let style=doc.getElementById('bbParentDarkTheme');
    if(theme==='dark'){
      if(!style){style=doc.createElement('style');style.id='bbParentDarkTheme';style.textContent=frameDarkCss();doc.head.appendChild(style)}
      else style.textContent=frameDarkCss();
      doc.documentElement.setAttribute('data-bb-parent-theme','dark');
      doc.body?.setAttribute('data-bb-parent-theme','dark');
    }else{
      style?.remove();doc.documentElement.removeAttribute('data-bb-parent-theme');doc.body?.removeAttribute('data-bb-parent-theme');
    }
  }catch(_){/* cross-origin fallback pages keep their native theme */}
}

function setTheme(next,persist=false){
  theme=next==='dark'?'dark':'light';ROOT.setAttribute('data-bb-theme',theme);if(persist)saveTheme(theme);
  const meta=document.querySelector('meta[name="theme-color"]');if(meta)meta.setAttribute('content',theme==='dark'?'#07111f':'#1267b0');
  updateToggle();applyFrameTheme();
}

function start(){
  injectShellCss();theme=readTheme();setTheme(theme,false);brandLogo();ensureToggle();
  const frame=$('moduleFrame');if(frame&&!frame.dataset.bbThemeBound){frame.dataset.bbThemeBound='1';frame.addEventListener('load',()=>{setTimeout(applyFrameTheme,20);setTimeout(applyFrameTheme,180);setTimeout(applyFrameTheme,700)})}
  setTimeout(()=>{brandLogo();ensureToggle();applyFrameTheme()},350);
  setTimeout(()=>{brandLogo();ensureToggle();applyFrameTheme()},1300);
}

if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
window.BBMobileThemeV1={setTheme,getTheme:()=>theme,applyFrameTheme};
})();
