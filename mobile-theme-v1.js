/* BIG BROTHER — Premium Mobile Theme V3.0
   Soft Premium Light Blue.
   Mobile shell + same-origin embedded functions only.
   Desktop dashboard is not modified. */
(function(){
'use strict';

const ROOT=document.documentElement;
const $=id=>document.getElementById(id);
const frameThemeObservers=new WeakMap();
const frameThemePending=new WeakSet();

function shellCss(){return `
  :root{
    color-scheme:light;
    --bb-bg:#edf5fb;
    --bb-bg-2:#e7f1fa;
    --bb-surface:#f9fcff;
    --bb-surface-2:#f2f7fc;
    --bb-border:#d2e1ee;
    --bb-border-strong:#bdd3e6;
    --bb-text:#16324f;
    --bb-soft:#4f6d89;
    --bb-muted:#7892aa;
    --bb-primary:#1677ff;
    --bb-primary-2:#2f8cff;
    --bb-primary-soft:#e7f2ff;
    --bb-success:#15966a;
    --bb-warning:#c98a12;
    --bb-danger:#d84f5f;
    --bb-shadow:0 8px 24px rgba(29,68,105,.08);
  }

  html[data-bb-theme="premium-light"]{
    color-scheme:light;
    background:var(--bb-bg);
  }

  html[data-bb-theme="premium-light"] body{
    background:
      radial-gradient(circle at 12% 0%,rgba(72,160,238,.13) 0,transparent 30%),
      radial-gradient(circle at 100% 8%,rgba(112,190,247,.10) 0,transparent 26%),
      linear-gradient(180deg,#f5f9fd 0%,#edf5fb 48%,#e8f2fa 100%)!important;
    color:var(--bb-text)!important;
  }

  html[data-bb-theme="premium-light"] .mobile-home,
  html[data-bb-theme="premium-light"] .menu-screen,
  html[data-bb-theme="premium-light"] .module-screen{
    background:
      radial-gradient(circle at 15% -5%,rgba(65,155,235,.11) 0,transparent 29%),
      linear-gradient(180deg,#f5f9fd 0%,#edf5fb 55%,#e8f1f9 100%)!important;
    color:var(--bb-text)!important;
  }

  html[data-bb-theme="premium-light"] .mobile-scroll,
  html[data-bb-theme="premium-light"] #menuGrid.bb-dropdown-menu{
    background:transparent!important;
  }

  html[data-bb-theme="premium-light"] .hero{
    background:
      radial-gradient(circle at 95% 0%,rgba(64,156,239,.14) 0,transparent 30%),
      linear-gradient(145deg,#f9fcff 0%,#eaf4fd 70%,#e2effa 100%)!important;
    color:var(--bb-text)!important;
    border-bottom:1px solid var(--bb-border)!important;
    box-shadow:0 8px 24px rgba(29,68,105,.08)!important;
  }

  html[data-bb-theme="premium-light"] .simple-header,
  html[data-bb-theme="premium-light"] .module-header{
    background:linear-gradient(135deg,#fafdff 0%,#eaf4fd 100%)!important;
    color:var(--bb-text)!important;
    border-bottom:1px solid var(--bb-border)!important;
    box-shadow:0 4px 16px rgba(29,68,105,.07)!important;
  }

  html[data-bb-theme="premium-light"] .brand,
  html[data-bb-theme="premium-light"] .greeting-name,
  html[data-bb-theme="premium-light"] .greeting-small,
  html[data-bb-theme="premium-light"] .brand-sub,
  html[data-bb-theme="premium-light"] .simple-header strong,
  html[data-bb-theme="premium-light"] .module-title-wrap strong,
  html[data-bb-theme="premium-light"] .simple-header span,
  html[data-bb-theme="premium-light"] .module-title-wrap span{
    color:var(--bb-text)!important;
  }

  html[data-bb-theme="premium-light"] .icon-btn,
  html[data-bb-theme="premium-light"] .header-btn,
  html[data-bb-theme="premium-light"] .desktop-small{
    background:#e6f1fb!important;
    color:#245c8d!important;
    border:1px solid #c5dced!important;
    box-shadow:none!important;
  }

  html[data-bb-theme="premium-light"] .hero-chip{
    background:#f7fbff!important;
    color:#43627d!important;
    border:1px solid #cfe0ed!important;
  }

  html[data-bb-theme="premium-light"] .panel,
  html[data-bb-theme="premium-light"] .menu-card,
  html[data-bb-theme="premium-light"] .bb-dd-group,
  html[data-bb-theme="premium-light"] .sheet-card,
  html[data-bb-theme="premium-light"] .login-card{
    background:rgba(249,252,255,.97)!important;
    color:var(--bb-text)!important;
    border:1px solid var(--bb-border)!important;
    box-shadow:var(--bb-shadow)!important;
  }

  html[data-bb-theme="premium-light"] .section-head strong,
  html[data-bb-theme="premium-light"] #quickActions .quick-btn,
  html[data-bb-theme="premium-light"] #quickActions .quick-btn>span,
  html[data-bb-theme="premium-light"] .quick-btn>span,
  html[data-bb-theme="premium-light"] .recent-main strong,
  html[data-bb-theme="premium-light"] .sheet-card h3,
  html[data-bb-theme="premium-light"] .sheet-option,
  html[data-bb-theme="premium-light"] .sheet-option strong,
  html[data-bb-theme="premium-light"] .bb-dd-copy strong,
  html[data-bb-theme="premium-light"] .login-brand{
    color:var(--bb-text)!important;
  }

  html[data-bb-theme="premium-light"] .section-head span,
  html[data-bb-theme="premium-light"] #quickCount,
  html[data-bb-theme="premium-light"] .recent-main span,
  html[data-bb-theme="premium-light"] .recent-side span,
  html[data-bb-theme="premium-light"] .sheet-card p,
  html[data-bb-theme="premium-light"] .sheet-option small,
  html[data-bb-theme="premium-light"] .bb-dd-copy small,
  html[data-bb-theme="premium-light"] .login-sub{
    color:var(--bb-muted)!important;
  }

  html[data-bb-theme="premium-light"] #kpiGrid .kpi,
  html[data-bb-theme="premium-light"] #kpiGrid .sales-kpi{
    background:linear-gradient(145deg,#fbfdff,#eef6fd)!important;
    border:1px solid #d3e3f0!important;
    box-shadow:0 5px 16px rgba(29,68,105,.06)!important;
  }

  html[data-bb-theme="premium-light"] #kpiGrid .kpi small,
  html[data-bb-theme="premium-light"] #kpiGrid .sales-kpi small{color:#63809a!important}
  html[data-bb-theme="premium-light"] #kpiGrid .kpi strong,
  html[data-bb-theme="premium-light"] #kpiGrid .sales-kpi strong{color:#173e67!important}
  html[data-bb-theme="premium-light"] #kpiGrid .kpi em,
  html[data-bb-theme="premium-light"] #kpiGrid .sales-kpi em{color:#7892aa!important}

  html[data-bb-theme="premium-light"] .quick-icon,
  html[data-bb-theme="premium-light"] .recent-icon{
    background:linear-gradient(145deg,#eef7ff,#dfeffc)!important;
    border:1px solid #c9deee!important;
    box-shadow:0 4px 12px rgba(29,68,105,.06)!important;
  }

  html[data-bb-theme="premium-light"] .recent-row{border-bottom-color:#e3edf5!important}
  html[data-bb-theme="premium-light"] .recent-side strong{color:#1a6fbc!important}

  html[data-bb-theme="premium-light"] .attention-card{
    background:#f8fbfe!important;
    border:1px solid #d9e6f1!important;
  }
  html[data-bb-theme="premium-light"] .attention-card b{color:#20496f!important}
  html[data-bb-theme="premium-light"] .attention-card span{color:#708ba3!important}

  html[data-bb-theme="premium-light"] .bottom-nav{
    background:rgba(249,252,255,.97)!important;
    border-top:1px solid #d4e2ed!important;
    box-shadow:0 -6px 20px rgba(29,68,105,.08)!important;
  }
  html[data-bb-theme="premium-light"] .nav-btn{color:#6e879e!important}
  html[data-bb-theme="premium-light"] .nav-btn b{color:#718ba4!important}
  html[data-bb-theme="premium-light"] .nav-btn.active{
    color:#1677ff!important;
    background:#e7f2ff!important;
  }
  html[data-bb-theme="premium-light"] .nav-btn.active b{color:#1677ff!important}

  html[data-bb-theme="premium-light"] .bb-dd-group>summary,
  html[data-bb-theme="premium-light"] .bb-dd-item{
    background:#f8fbfe!important;
    color:var(--bb-text)!important;
    border-color:#d7e5f0!important;
  }
  html[data-bb-theme="premium-light"] .bb-dd-group[open]>summary{
    background:#edf6ff!important;
    border-color:#c7dced!important;
  }
  html[data-bb-theme="premium-light"] .bb-dd-left span{color:var(--bb-text)!important}
  html[data-bb-theme="premium-light"] .bb-dd-arrow{color:#66839d!important}

  html[data-bb-theme="premium-light"] .sheet{background:rgba(31,55,80,.28)!important}
  html[data-bb-theme="premium-light"] .sheet-option{
    background:#f7fbff!important;
    color:var(--bb-text)!important;
    border-color:#d4e3ef!important;
  }
  html[data-bb-theme="premium-light"] .sheet-close{
    background:#eaf3fa!important;
    color:#315674!important;
    border:1px solid #cfdeea!important;
  }

  html[data-bb-theme="premium-light"] .login-card input{
    background:#f5f9fd!important;
    color:var(--bb-text)!important;
    border-color:#c4d8e8!important;
  }
  html[data-bb-theme="premium-light"] .login-card input:focus{
    border-color:#4e9ee7!important;
    box-shadow:0 0 0 3px rgba(22,119,255,.10)!important;
  }
  html[data-bb-theme="premium-light"] .login-card button{
    background:linear-gradient(135deg,#1677ff,#2f8cff)!important;
    color:#fff!important;
    box-shadow:0 6px 16px rgba(22,119,255,.18)!important;
  }

  html[data-bb-theme="premium-light"] .boot-screen,
  html[data-bb-theme="premium-light"] .login-screen{
    background:
      radial-gradient(circle at 80% 10%,rgba(73,162,239,.14) 0,transparent 30%),
      linear-gradient(155deg,#f7fbff 0%,#edf5fb 52%,#e5f0f9 100%)!important;
  }
  html[data-bb-theme="premium-light"] .boot-card{
    background:#f9fcff!important;
    border:1px solid #d5e3ee!important;
    box-shadow:0 18px 50px rgba(29,68,105,.12)!important;
  }
  html[data-bb-theme="premium-light"] .boot-card strong{color:#173e67!important}
  html[data-bb-theme="premium-light"] .boot-card span{color:#7790a7!important}

  html[data-bb-theme="premium-light"] .module-frame{background:#edf5fb!important}

  @media(min-width:620px){
    html[data-bb-theme="premium-light"] body{
      background:
        radial-gradient(circle at 50% 0%,rgba(65,155,235,.12) 0,transparent 33%),
        #dfeaf4!important;
    }
  }

  /* PREMIUM LIGHT V3.1 — formal tabs + icons */
  html[data-bb-theme="premium-light"] .tabs,
  html[data-bb-theme="premium-light"] .tabbar,
  html[data-bb-theme="premium-light"] .segmented,
  html[data-bb-theme="premium-light"] .segment-control,
  html[data-bb-theme="premium-light"] .top-switch,
  html[data-bb-theme="premium-light"] [role="tablist"]{
    background:#edf4fb!important;
    border:1px solid #d3e1ec!important;
    border-radius:16px!important;
    padding:4px!important;
    gap:6px!important;
    box-shadow:none!important;
  }

  html[data-bb-theme="premium-light"] .tabs button,
  html[data-bb-theme="premium-light"] .tabbar button,
  html[data-bb-theme="premium-light"] .segmented button,
  html[data-bb-theme="premium-light"] .segment-control button,
  html[data-bb-theme="premium-light"] .top-switch button,
  html[data-bb-theme="premium-light"] [role="tab"]{
    background:#f8fbff!important;
    color:#4f6d89!important;
    border:1px solid #d4e2ee!important;
    border-radius:12px!important;
    box-shadow:none!important;
    font-weight:700!important;
  }

  html[data-bb-theme="premium-light"] .tabs button.active,
  html[data-bb-theme="premium-light"] .tabbar button.active,
  html[data-bb-theme="premium-light"] .segmented button.active,
  html[data-bb-theme="premium-light"] .segment-control button.active,
  html[data-bb-theme="premium-light"] .top-switch button.active,
  html[data-bb-theme="premium-light"] [role="tab"].active,
  html[data-bb-theme="premium-light"] [role="tab"][aria-selected="true"]{
    background:linear-gradient(135deg,#e3f0ff,#d4e8ff)!important;
    color:#1c5fa8!important;
    border:1px solid #aecaea!important;
    box-shadow:0 3px 10px rgba(22,119,255,.09)!important;
  }

  html[data-bb-theme="premium-light"] .bb-formal-icon{
    width:18px;
    height:18px;
    display:inline-flex;
    align-items:center;
    justify-content:center;
    flex:0 0 auto;
    color:currentColor;
    vertical-align:middle;
  }
  html[data-bb-theme="premium-light"] .bb-formal-icon svg{
    width:18px;
    height:18px;
    display:block;
    fill:none;
    stroke:currentColor;
    stroke-width:1.8;
    stroke-linecap:round;
    stroke-linejoin:round;
  }
  html[data-bb-theme="premium-light"] .bb-formal-label{
    min-width:0;
  }
  html[data-bb-theme="premium-light"] button[data-bb-formalized="1"],
  html[data-bb-theme="premium-light"] a[data-bb-formalized="1"]{
    display:inline-flex!important;
    align-items:center!important;
    justify-content:center!important;
    gap:7px!important;
  }
  html[data-bb-theme="premium-light"] .quick-icon svg,
  html[data-bb-theme="premium-light"] .menu-card>b svg,
  html[data-bb-theme="premium-light"] .nav-btn>b svg{
    width:21px;
    height:21px;
    fill:none;
    stroke:currentColor;
    stroke-width:1.8;
    stroke-linecap:round;
    stroke-linejoin:round;
  }

`}

function injectShellCss(){
  let style=$('bbPremiumThemeCss');
  if(!style){
    style=document.createElement('style');
    style.id='bbPremiumThemeCss';
    document.head.appendChild(style);
  }
  style.textContent=shellCss();
}

function brandLogo(){
  const boot=document.querySelector('.boot-logo');
  if(boot&&!boot.querySelector('img')){
    boot.textContent='';
    const img=document.createElement('img');
    img.src='pwa-icon.svg?v=20260920-premiumlight1';
    img.alt='BIG BROTHER';
    boot.appendChild(img);
  }
  const banner=document.querySelector('.pwa-install-logo');
  if(banner){
    banner.textContent='';
    banner.style.background='url("pwa-icon.svg?v=20260920-premiumlight1") center/cover no-repeat';
  }
}

function removeOldThemeToggle(){
  $('bbThemeToggle')?.remove();
}


const BB_FORMAL_ICONS={
  home:'<svg viewBox="0 0 24 24"><path d="M3 10.5 12 3l9 7.5"></path><path d="M5 9.5V21h14V9.5"></path><path d="M9 21v-7h6v7"></path></svg>',
  calculator:'<svg viewBox="0 0 24 24"><rect x="5" y="3" width="14" height="18" rx="2"></rect><path d="M8 7h8"></path><path d="M8 11h1"></path><path d="M12 11h1"></path><path d="M16 11h1"></path><path d="M8 15h1"></path><path d="M12 15h1"></path><path d="M16 15h1"></path></svg>',
  history:'<svg viewBox="0 0 24 24"><path d="M3 12a9 9 0 1 0 3-6.7"></path><path d="M3 3v6h6"></path><path d="M12 7v5l3 2"></path></svg>',
  users:'<svg viewBox="0 0 24 24"><path d="M16 21v-2a4 4 0 0 0-4-4H7a4 4 0 0 0-4 4v2"></path><circle cx="9.5" cy="7" r="3"></circle><path d="M20 21v-2a4 4 0 0 0-3-3.87"></path><path d="M16 4.13a4 4 0 0 1 0 7.75"></path></svg>',
  user:'<svg viewBox="0 0 24 24"><circle cx="12" cy="8" r="4"></circle><path d="M4 21a8 8 0 0 1 16 0"></path></svg>',
  userPlus:'<svg viewBox="0 0 24 24"><circle cx="9" cy="8" r="4"></circle><path d="M2 21a7 7 0 0 1 14 0"></path><path d="M19 8v6"></path><path d="M16 11h6"></path></svg>',
  cart:'<svg viewBox="0 0 24 24"><circle cx="8" cy="20" r="1.5"></circle><circle cx="18" cy="20" r="1.5"></circle><path d="M3 4h2l2.2 10.2a2 2 0 0 0 2 1.6h8.5a2 2 0 0 0 2-1.6L21 7H6"></path></svg>',
  package:'<svg viewBox="0 0 24 24"><path d="M21 8.5 12 13 3 8.5"></path><path d="M3 8.5 12 4l9 4.5v7L12 20l-9-4.5z"></path><path d="M12 13v7"></path></svg>',
  boxes:'<svg viewBox="0 0 24 24"><path d="m4 8 4-2 4 2-4 2z"></path><path d="m12 8 4-2 4 2-4 2z"></path><path d="m8 14 4-2 4 2-4 2z"></path><path d="M4 8v5l4 2 4-2V8"></path><path d="M12 8v5l4 2 4-2V8"></path><path d="M8 14v5l4 2 4-2v-5"></path></svg>',
  chart:'<svg viewBox="0 0 24 24"><path d="M4 20V10"></path><path d="M10 20V4"></path><path d="M16 20v-7"></path><path d="M22 20H2"></path></svg>',
  file:'<svg viewBox="0 0 24 24"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><path d="M14 2v6h6"></path><path d="M8 13h8"></path><path d="M8 17h6"></path></svg>',
  wallet:'<svg viewBox="0 0 24 24"><path d="M20 7H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h14a1 1 0 0 0 1-1V8a1 1 0 0 0-1-1z"></path><path d="M17 12h4"></path><path d="M6 7V5a2 2 0 0 1 2-2h10"></path></svg>',
  creditCard:'<svg viewBox="0 0 24 24"><rect x="2" y="5" width="20" height="14" rx="2"></rect><path d="M2 10h20"></path><path d="M6 15h3"></path></svg>',
  truck:'<svg viewBox="0 0 24 24"><path d="M10 17H3V6h12v11"></path><path d="M15 9h3l3 4v4h-2"></path><circle cx="7" cy="18" r="2"></circle><circle cx="17" cy="18" r="2"></circle></svg>',
  mapPin:'<svg viewBox="0 0 24 24"><path d="M12 21s6-5.4 6-11a6 6 0 1 0-12 0c0 5.6 6 11 6 11z"></path><circle cx="12" cy="10" r="2.5"></circle></svg>',
  bell:'<svg viewBox="0 0 24 24"><path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9"></path><path d="M10 21h4"></path></svg>',
  menu:'<svg viewBox="0 0 24 24"><path d="M4 6h16"></path><path d="M4 12h16"></path><path d="M4 18h16"></path></svg>',
  settings:'<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="3"></circle><path d="M19.4 15a1.7 1.7 0 0 0 .34 1.88l.06.06-2.83 2.83-.06-.06A1.7 1.7 0 0 0 15 19.4a1.7 1.7 0 0 0-1 .6 1.7 1.7 0 0 0-.4 1.1V21H9.6v-.1A1.7 1.7 0 0 0 8.6 19.4a1.7 1.7 0 0 0-1.88.34l-.06.06-2.83-2.83.06-.06A1.7 1.7 0 0 0 4.2 15a1.7 1.7 0 0 0-.6-1 1.7 1.7 0 0 0-1.1-.4H2.4V9.6h.1A1.7 1.7 0 0 0 4.2 8.6a1.7 1.7 0 0 0-.34-1.88l-.06-.06 2.83-2.83.06.06A1.7 1.7 0 0 0 8.6 4.2a1.7 1.7 0 0 0 1-.6A1.7 1.7 0 0 0 10 2.5V2.4h4v.1a1.7 1.7 0 0 0 1 1.7 1.7 1.7 0 0 0 1.88-.34l.06-.06 2.83 2.83-.06.06A1.7 1.7 0 0 0 19.4 8.6a1.7 1.7 0 0 0 .6 1 1.7 1.7 0 0 0 1.1.4h.1v4h-.1a1.7 1.7 0 0 0-1.7 1z"></path></svg>',
  phone:'<svg viewBox="0 0 24 24"><path d="M22 16.9v3a2 2 0 0 1-2.2 2 19.8 19.8 0 0 1-8.6-3.1 19.5 19.5 0 0 1-6-6A19.8 19.8 0 0 1 2.1 4.2 2 2 0 0 1 4.1 2h3a2 2 0 0 1 2 1.7c.1 1 .4 2 .7 2.9a2 2 0 0 1-.5 2.1L8 10a16 16 0 0 0 6 6l1.3-1.3a2 2 0 0 1 2.1-.5c.9.3 1.9.6 2.9.7a2 2 0 0 1 1.7 2z"></path></svg>',
  search:'<svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="7"></circle><path d="m20 20-3.5-3.5"></path></svg>',
  pencil:'<svg viewBox="0 0 24 24"><path d="M12 20h9"></path><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z"></path></svg>',
  trash:'<svg viewBox="0 0 24 24"><path d="M3 6h18"></path><path d="M8 6V4h8v2"></path><path d="M19 6l-1 15H6L5 6"></path><path d="M10 11v5"></path><path d="M14 11v5"></path></svg>',
  plus:'<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"></circle><path d="M12 8v8"></path><path d="M8 12h8"></path></svg>',
  check:'<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"></circle><path d="m8 12 2.5 2.5L16 9"></path></svg>',
  download:'<svg viewBox="0 0 24 24"><path d="M12 3v12"></path><path d="m7 10 5 5 5-5"></path><path d="M5 21h14"></path></svg>',
  monitor:'<svg viewBox="0 0 24 24"><rect x="2" y="3" width="20" height="14" rx="2"></rect><path d="M8 21h8"></path><path d="M12 17v4"></path></svg>',
  receipt:'<svg viewBox="0 0 24 24"><path d="M5 3v18l3-2 4 2 4-2 3 2V3l-3 2-4-2-4 2z"></path><path d="M8 9h8"></path><path d="M8 13h6"></path></svg>',
  arrowLeft:'<svg viewBox="0 0 24 24"><path d="m15 18-6-6 6-6"></path></svg>'
};

function bbFormalIcon(name){
  return '<span class="bb-formal-icon" aria-hidden="true">'+(BB_FORMAL_ICONS[name]||BB_FORMAL_ICONS.file)+'</span>';
}
function bbCleanLabel(value){
  return String(value||'')
    .replace(/^[\s\u2190-\u2BFF\uFE0F\u200D]+/gu,'')
    .replace(/^[\s\u{1F000}-\u{1FAFF}\uFE0F\u200D]+/gu,'')
    .replace(/\s+/g,' ')
    .trim();
}
function bbIconNameForLabel(value){
  const s=bbCleanLabel(value).toLowerCase();
  if(!s)return '';
  if(s==='home')return'home';
  if(s==='menu'||s==='more')return'menu';
  if(s.includes('calculator'))return'calculator';
  if(s.includes('history'))return'history';
  if(s.includes('customer'))return s.startsWith('add ')?'userPlus':'users';
  if(s.includes('delivery'))return s.includes('successful')?'check':'truck';
  if(s.includes('map'))return'mapPin';
  if(s.includes('stock')||s.includes('inventory')||s.includes('product'))return s.includes('price')?'wallet':'boxes';
  if(s.includes('receivable')||s.includes('payable'))return'wallet';
  if(s.includes('payment')||s.includes('cash collection'))return'creditCard';
  if(s.includes('invoice')||s.includes('statement'))return'file';
  if(s.includes('report')||s.includes('summary')||s.includes('income'))return'chart';
  if(s.includes('expense'))return'receipt';
  if(s.includes('purchase')||s==='sales'||s.includes('new sale'))return'cart';
  if(s.includes('notification')||s.includes('alert'))return'bell';
  if(s.includes('staff'))return'users';
  if(s==='call')return'phone';
  if(s==='edit')return'pencil';
  if(s.includes('clear')||s.includes('delete'))return'trash';
  if(s.startsWith('add ')||s.startsWith('new '))return'plus';
  if(s==='search')return'search';
  if(s.includes('install'))return'download';
  if(s.includes('desktop'))return'monitor';
  return '';
}
function bbReplaceSimpleLabel(el,label,iconName){
  if(!el||el.dataset.bbFormalized==='1'||!iconName)return;
  const text=bbCleanLabel(label);
  if(!text)return;
  el.textContent='';
  const holder=el.ownerDocument.createElement('span');
  holder.innerHTML=bbFormalIcon(iconName);
  const icon=holder.firstElementChild;
  const textSpan=el.ownerDocument.createElement('span');
  textSpan.className='bb-formal-label';
  textSpan.textContent=text;
  el.append(icon,textSpan);
  el.dataset.bbFormalized='1';
}
function bbFormalizeIcons(doc){
  if(!doc?.querySelectorAll)return;

  doc.querySelectorAll('.quick-btn').forEach(btn=>{
    const label=bbCleanLabel(btn.querySelector('span:last-child')?.textContent||'');
    const host=btn.querySelector('.quick-icon');
    const icon=bbIconNameForLabel(label);
    if(host&&icon&&host.dataset.bbFormalized!=='1'){
      host.innerHTML=BB_FORMAL_ICONS[icon]||'';
      host.dataset.bbFormalized='1';
    }
  });

  doc.querySelectorAll('.menu-card').forEach(card=>{
    const label=bbCleanLabel(card.querySelector('strong')?.textContent||'');
    const host=card.querySelector(':scope > b');
    const icon=bbIconNameForLabel(label);
    if(host&&icon&&host.dataset.bbFormalized!=='1'){
      host.innerHTML=BB_FORMAL_ICONS[icon]||'';
      host.dataset.bbFormalized='1';
    }
  });

  const navMap={home:'home',sales:'cart',stock:'boxes',reports:'chart',more:'menu'};
  doc.querySelectorAll('.nav-btn[data-nav]').forEach(btn=>{
    const host=btn.querySelector(':scope > b');
    const icon=navMap[btn.dataset.nav]||'';
    if(host&&icon&&host.dataset.bbFormalized!=='1'){
      host.innerHTML=BB_FORMAL_ICONS[icon]||'';
      host.dataset.bbFormalized='1';
    }
  });

  const fixed=[
    ['#notificationBtn','bell'],
    ['#settingsBtn','user'],
    ['#menuSettings','settings'],
    ['#moduleBack','arrowLeft'],
    ['#menuBack','arrowLeft']
  ];
  fixed.forEach(([selector,icon])=>{
    const el=doc.querySelector(selector);
    if(el&&el.dataset.bbFormalized!=='1'){
      el.innerHTML=bbFormalIcon(icon);
      el.dataset.bbFormalized='1';
    }
  });

  doc.querySelectorAll('.sheet-option').forEach(el=>{
    const strong=el.querySelector('strong');
    const iconHost=el.querySelector(':scope > span');
    const label=bbCleanLabel(strong?.textContent||'');
    const icon=bbIconNameForLabel(label);
    if(iconHost&&icon&&iconHost.dataset.bbFormalized!=='1'){
      iconHost.innerHTML=BB_FORMAL_ICONS[icon]||'';
      iconHost.dataset.bbFormalized='1';
    }
  });

  const candidates='button,[role="tab"],a.btn,a.button,a[role="button"]';
  doc.querySelectorAll(candidates).forEach(el=>{
    if(el.dataset.bbFormalized==='1')return;
    if(el.classList.contains('quick-btn')||el.classList.contains('menu-card')||el.classList.contains('nav-btn'))return;
    if(el.querySelector('input,select,textarea'))return;
    const raw=el.textContent||el.getAttribute('aria-label')||'';
    const text=bbCleanLabel(raw);
    if(!text||text.length>42)return;
    const icon=bbIconNameForLabel(text);
    if(icon)bbReplaceSimpleLabel(el,text,icon);
  });

  doc.querySelectorAll('h1,h2,h3').forEach(el=>{
    if(el.dataset.bbFormalized==='1')return;
    const raw=String(el.textContent||'');
    const text=bbCleanLabel(raw);
    if(!text||text===raw.trim())return;
    const icon=bbIconNameForLabel(text);
    if(icon)bbReplaceSimpleLabel(el,text,icon);
  });
}

let shellIconObserver=null;
let shellIconPending=false;
function ensureShellIconWatch(){
  if(shellIconObserver||!document.body)return;
  shellIconObserver=new MutationObserver(()=>{
    if(shellIconPending)return;
    shellIconPending=true;
    requestAnimationFrame(()=>{
      shellIconPending=false;
      try{bbFormalizeIcons(document)}catch(_){}
    });
  });
  shellIconObserver.observe(document.body,{childList:true,subtree:true});
}

function frameCss(){return `
  :root[data-bb-parent-theme="premium-light"]{
    color-scheme:light!important;

    --bb-bg:#edf5fb!important;
    --bb-bg-2:#e8f2fa!important;
    --bb-card:#f9fcff!important;
    --bb-card-2:#f2f7fc!important;
    --bb-border:#d2e1ee!important;
    --bb-border-strong:#bdd3e6!important;
    --bb-text:#16324f!important;
    --bb-muted:#7892aa!important;
    --bb-primary:#1677ff!important;

    /* Legacy function tokens */
    --bg:#edf5fb!important;
    --background:#edf5fb!important;
    --page-bg:#edf5fb!important;
    --card:#f9fcff!important;
    --surface:#f9fcff!important;
    --surface-1:#f9fcff!important;
    --surface-2:#f2f7fc!important;
    --panel:#f9fcff!important;
    --line:#d2e1ee!important;
    --border:#d2e1ee!important;
    --border-color:#d2e1ee!important;
    --text:#16324f!important;
    --text-color:#16324f!important;
    --muted:#7892aa!important;
    --muted-color:#7892aa!important;
    --navy:#1b4f7b!important;
    --blue:#1677ff!important;
    --blue2:#2f8cff!important;
    --primary:#1677ff!important;
    --primary-color:#1677ff!important;
    --green:#15966a!important;
    --greenbg:#e8f7f1!important;
    --amber:#c98a12!important;
    --amberbg:#fff5dc!important;
    --red:#d84f5f!important;
    --redbg:#fdecef!important;
  }

  html[data-bb-parent-theme="premium-light"],
  html[data-bb-parent-theme="premium-light"] body{
    min-height:100%!important;
    background:
      radial-gradient(circle at 12% -6%,rgba(65,155,235,.10) 0,transparent 28%),
      linear-gradient(180deg,#f5f9fd 0%,#edf5fb 52%,#e8f1f9 100%)!important;
    color:#16324f!important;
  }

  html[data-bb-parent-theme="premium-light"] body,
  html[data-bb-parent-theme="premium-light"] main,
  html[data-bb-parent-theme="premium-light"] .app,
  html[data-bb-parent-theme="premium-light"] .page,
  html[data-bb-parent-theme="premium-light"] .screen,
  html[data-bb-parent-theme="premium-light"] .workspace,
  html[data-bb-parent-theme="premium-light"] .wrap,
  html[data-bb-parent-theme="premium-light"] .container,
  html[data-bb-parent-theme="premium-light"] .content,
  html[data-bb-parent-theme="premium-light"] .content-wrap,
  html[data-bb-parent-theme="premium-light"] .page-wrap,
  html[data-bb-parent-theme="premium-light"] .main,
  html[data-bb-parent-theme="premium-light"] .main-content,
  html[data-bb-parent-theme="premium-light"] .mobile-page,
  html[data-bb-parent-theme="premium-light"] .report-page,
  html[data-bb-parent-theme="premium-light"] .history-page,
  html[data-bb-parent-theme="premium-light"] .workspace-body,
  html[data-bb-parent-theme="premium-light"] .page-body,
  html[data-bb-parent-theme="premium-light"] .app-body,
  html[data-bb-parent-theme="premium-light"] .module-body{
    background:transparent!important;
    color:#16324f!important;
  }

  html[data-bb-parent-theme="premium-light"] header,
  html[data-bb-parent-theme="premium-light"] .header,
  html[data-bb-parent-theme="premium-light"] .topbar,
  html[data-bb-parent-theme="premium-light"] .toolbar,
  html[data-bb-parent-theme="premium-light"] .app-header,
  html[data-bb-parent-theme="premium-light"] .page-header,
  html[data-bb-parent-theme="premium-light"] .mobile-header,
  html[data-bb-parent-theme="premium-light"] .report-header,
  html[data-bb-parent-theme="premium-light"] .titlebar,
  html[data-bb-parent-theme="premium-light"] .nav-header{
    background:linear-gradient(135deg,#fafdff 0%,#eaf4fd 100%)!important;
    color:#16324f!important;
    border-color:#d2e1ee!important;
    box-shadow:0 4px 16px rgba(29,68,105,.07)!important;
  }

  html[data-bb-parent-theme="premium-light"] .card,
  html[data-bb-parent-theme="premium-light"] [class$="-card"],
  html[data-bb-parent-theme="premium-light"] [class*="-card "],
  html[data-bb-parent-theme="premium-light"] .panel,
  html[data-bb-parent-theme="premium-light"] [class$="-panel"],
  html[data-bb-parent-theme="premium-light"] [class*="-panel "],
  html[data-bb-parent-theme="premium-light"] .sheet-card,
  html[data-bb-parent-theme="premium-light"] .modal-card,
  html[data-bb-parent-theme="premium-light"] .dialog,
  html[data-bb-parent-theme="premium-light"] .total-box,
  html[data-bb-parent-theme="premium-light"] .loginbox,
  html[data-bb-parent-theme="premium-light"] .meta,
  html[data-bb-parent-theme="premium-light"] .notice,
  html[data-bb-parent-theme="premium-light"] .empty,
  html[data-bb-parent-theme="premium-light"] .empty-state,
  html[data-bb-parent-theme="premium-light"] .result,
  html[data-bb-parent-theme="premium-light"] .info-box,
  html[data-bb-parent-theme="premium-light"] .summary-box{
    background:rgba(249,252,255,.98)!important;
    color:#16324f!important;
    border-color:#d2e1ee!important;
    box-shadow:0 6px 18px rgba(29,68,105,.065)!important;
  }

  html[data-bb-parent-theme="premium-light"] h1,
  html[data-bb-parent-theme="premium-light"] h2,
  html[data-bb-parent-theme="premium-light"] h3,
  html[data-bb-parent-theme="premium-light"] h4,
  html[data-bb-parent-theme="premium-light"] h5,
  html[data-bb-parent-theme="premium-light"] h6,
  html[data-bb-parent-theme="premium-light"] .title,
  html[data-bb-parent-theme="premium-light"] .page-title,
  html[data-bb-parent-theme="premium-light"] .section-title,
  html[data-bb-parent-theme="premium-light"] .card-title,
  html[data-bb-parent-theme="premium-light"] .label,
  html[data-bb-parent-theme="premium-light"] .name,
  html[data-bb-parent-theme="premium-light"] strong,
  html[data-bb-parent-theme="premium-light"] b{
    color:#173e67!important;
  }

  html[data-bb-parent-theme="premium-light"] p,
  html[data-bb-parent-theme="premium-light"] .subtitle,
  html[data-bb-parent-theme="premium-light"] .description,
  html[data-bb-parent-theme="premium-light"] .helper,
  html[data-bb-parent-theme="premium-light"] .hint,
  html[data-bb-parent-theme="premium-light"] .muted,
  html[data-bb-parent-theme="premium-light"] .sub,
  html[data-bb-parent-theme="premium-light"] .caption,
  html[data-bb-parent-theme="premium-light"] .note,
  html[data-bb-parent-theme="premium-light"] small,
  html[data-bb-parent-theme="premium-light"] .small,
  html[data-bb-parent-theme="premium-light"] .secondary,
  html[data-bb-parent-theme="premium-light"] .timestamp,
  html[data-bb-parent-theme="premium-light"] .date,
  html[data-bb-parent-theme="premium-light"] .unit,
  html[data-bb-parent-theme="premium-light"] .status-line{
    color:#718aa2!important;
  }

  html[data-bb-parent-theme="premium-light"] label,
  html[data-bb-parent-theme="premium-light"] .field label,
  html[data-bb-parent-theme="premium-light"] .form-label,
  html[data-bb-parent-theme="premium-light"] .calc-field-label{
    color:#4f6d89!important;
  }

  html[data-bb-parent-theme="premium-light"] a{color:#1677ff!important;}

  html[data-bb-parent-theme="premium-light"] input,
  html[data-bb-parent-theme="premium-light"] select,
  html[data-bb-parent-theme="premium-light"] textarea,
  html[data-bb-parent-theme="premium-light"] .input,
  html[data-bb-parent-theme="premium-light"] .select,
  html[data-bb-parent-theme="premium-light"] .search,
  html[data-bb-parent-theme="premium-light"] .search-input,
  html[data-bb-parent-theme="premium-light"] .form-control{
    background:#f5f9fd!important;
    color:#16324f!important;
    border-color:#bfd3e4!important;
    box-shadow:none!important;
    opacity:1!important;
  }

  html[data-bb-parent-theme="premium-light"] input:focus,
  html[data-bb-parent-theme="premium-light"] select:focus,
  html[data-bb-parent-theme="premium-light"] textarea:focus,
  html[data-bb-parent-theme="premium-light"] .form-control:focus{
    border-color:#4b9ce5!important;
    box-shadow:0 0 0 3px rgba(22,119,255,.10)!important;
    outline:none!important;
  }

  html[data-bb-parent-theme="premium-light"] input::placeholder,
  html[data-bb-parent-theme="premium-light"] textarea::placeholder{
    color:#7897b3!important;
    opacity:1!important;
  }

  html[data-bb-parent-theme="premium-light"] input[readonly],
  html[data-bb-parent-theme="premium-light"] textarea[readonly],
  html[data-bb-parent-theme="premium-light"] input[disabled],
  html[data-bb-parent-theme="premium-light"] textarea[disabled],
  html[data-bb-parent-theme="premium-light"] select[disabled]{
    background:#eaf2f9!important;
    color:#486783!important;
    border-color:#cadce9!important;
    opacity:1!important;
    -webkit-text-fill-color:#486783!important;
  }

  html[data-bb-parent-theme="premium-light"] option{
    background:#f9fcff!important;
    color:#16324f!important;
  }

  html[data-bb-parent-theme="premium-light"] .customer-suggestions,
  html[data-bb-parent-theme="premium-light"] .product-suggestions,
  html[data-bb-parent-theme="premium-light"] .suggestions,
  html[data-bb-parent-theme="premium-light"] .dropdown-menu,
  html[data-bb-parent-theme="premium-light"] .autocomplete-list{
    background:#f9fcff!important;
    color:#16324f!important;
    border-color:#c8dbea!important;
    box-shadow:0 14px 30px rgba(29,68,105,.14)!important;
  }

  html[data-bb-parent-theme="premium-light"] .customer-suggestion,
  html[data-bb-parent-theme="premium-light"] .product-suggestion,
  html[data-bb-parent-theme="premium-light"] .suggestion-item,
  html[data-bb-parent-theme="premium-light"] .dropdown-item{
    background:#f9fcff!important;
    color:#16324f!important;
    border-color:#dbe8f2!important;
  }

  html[data-bb-parent-theme="premium-light"] .customer-suggestion:hover,
  html[data-bb-parent-theme="premium-light"] .customer-suggestion:focus,
  html[data-bb-parent-theme="premium-light"] .product-suggestion:hover,
  html[data-bb-parent-theme="premium-light"] .product-suggestion:focus,
  html[data-bb-parent-theme="premium-light"] .suggestion-item:hover,
  html[data-bb-parent-theme="premium-light"] .dropdown-item:hover{
    background:#edf6ff!important;
  }

  html[data-bb-parent-theme="premium-light"] table{
    background:transparent!important;
    color:#16324f!important;
    border-color:#d6e4ef!important;
  }
  html[data-bb-parent-theme="premium-light"] thead,
  html[data-bb-parent-theme="premium-light"] thead tr{background:transparent!important;}
  html[data-bb-parent-theme="premium-light"] th{
    background:#eef5fb!important;
    color:#45647f!important;
    border-color:#d6e4ef!important;
  }
  html[data-bb-parent-theme="premium-light"] td{
    background:#f9fcff!important;
    color:#244966!important;
    border-color:#e2ebf3!important;
  }
  html[data-bb-parent-theme="premium-light"] tbody tr:nth-child(even) td{
    background:#f4f9fd!important;
  }

  html[data-bb-parent-theme="premium-light"] .line-table tr,
  html[data-bb-parent-theme="premium-light"] .responsive-table tr,
  html[data-bb-parent-theme="premium-light"] .mobile-table-row{
    background:#f9fcff!important;
    border-color:#d6e4ef!important;
  }

  html[data-bb-parent-theme="premium-light"] button,
  html[data-bb-parent-theme="premium-light"] .btn,
  html[data-bb-parent-theme="premium-light"] .button{
    color:#2c5373!important;
    border-color:#bfd3e4!important;
    opacity:1!important;
  }

  html[data-bb-parent-theme="premium-light"] .btn-primary,
  html[data-bb-parent-theme="premium-light"] .primary,
  html[data-bb-parent-theme="premium-light"] .primary-btn,
  html[data-bb-parent-theme="premium-light"] .save-btn,
  html[data-bb-parent-theme="premium-light"] .submit-btn,
  html[data-bb-parent-theme="premium-light"] button[type="submit"],
  html[data-bb-parent-theme="premium-light"] button.green,
  html[data-bb-parent-theme="premium-light"] .btn.green,
  html[data-bb-parent-theme="premium-light"] .btn.success{
    background:linear-gradient(135deg,#1677ff,#2f8cff)!important;
    color:#fff!important;
    border-color:#1677ff!important;
    box-shadow:0 5px 14px rgba(22,119,255,.16)!important;
  }

  html[data-bb-parent-theme="premium-light"] .btn-secondary,
  html[data-bb-parent-theme="premium-light"] .secondary-btn,
  html[data-bb-parent-theme="premium-light"] .ghost-btn,
  html[data-bb-parent-theme="premium-light"] .ghost,
  html[data-bb-parent-theme="premium-light"] .filter-btn,
  html[data-bb-parent-theme="premium-light"] .chip,
  html[data-bb-parent-theme="premium-light"] .pill{
    background:#f1f7fc!important;
    color:#315978!important;
    border-color:#c6d9e8!important;
  }

  html[data-bb-parent-theme="premium-light"] button[disabled],
  html[data-bb-parent-theme="premium-light"] .btn[disabled]{
    background:#e8f0f7!important;
    color:#6f879b!important;
    border-color:#cedde9!important;
    opacity:1!important;
    -webkit-text-fill-color:#6f879b!important;
  }

  html[data-bb-parent-theme="premium-light"] .tabs,
  html[data-bb-parent-theme="premium-light"] .tabbar,
  html[data-bb-parent-theme="premium-light"] .segmented,
  html[data-bb-parent-theme="premium-light"] .segment-control,
  html[data-bb-parent-theme="premium-light"] .calc-currency-wrap{
    background:#eaf3fa!important;
    border-color:#caddeb!important;
  }

  html[data-bb-parent-theme="premium-light"] .tabs button,
  html[data-bb-parent-theme="premium-light"] .segmented button,
  html[data-bb-parent-theme="premium-light"] .segment-control button,
  html[data-bb-parent-theme="premium-light"] .currency-btn{
    background:transparent!important;
    color:#58758f!important;
    border-color:transparent!important;
  }

  html[data-bb-parent-theme="premium-light"] .tabs button.active,
  html[data-bb-parent-theme="premium-light"] .segmented button.active,
  html[data-bb-parent-theme="premium-light"] .segment-control button.active,
  html[data-bb-parent-theme="premium-light"] .currency-btn.active{
    background:#fff!important;
    color:#1677ff!important;
    border-color:#c6dbee!important;
    box-shadow:0 4px 12px rgba(29,68,105,.07)!important;
  }

  html[data-bb-parent-theme="premium-light"] .total-box,
  html[data-bb-parent-theme="premium-light"] .grand-total,
  html[data-bb-parent-theme="premium-light"] .grand-total-box,
  html[data-bb-parent-theme="premium-light"] .calc-total-card,
  html[data-bb-parent-theme="premium-light"] .summary-total,
  html[data-bb-parent-theme="premium-light"] .payment-summary{
    background:linear-gradient(145deg,#f8fbfe,#eaf4fd)!important;
    border-color:#c7dceb!important;
    color:#16324f!important;
  }

  html[data-bb-parent-theme="premium-light"] .grand-total strong,
  html[data-bb-parent-theme="premium-light"] .grand-total-box strong,
  html[data-bb-parent-theme="premium-light"] .calc-total-card strong,
  html[data-bb-parent-theme="premium-light"] .summary-total strong,
  html[data-bb-parent-theme="premium-light"] .total-row.grand{
    color:#126fc8!important;
  }

  html[data-bb-parent-theme="premium-light"] .badge.green,
  html[data-bb-parent-theme="premium-light"] .badge.success,
  html[data-bb-parent-theme="premium-light"] .status-success{
    background:#e7f7f0!important;
    color:#137d5a!important;
  }
  html[data-bb-parent-theme="premium-light"] .badge.amber,
  html[data-bb-parent-theme="premium-light"] .badge.warning,
  html[data-bb-parent-theme="premium-light"] .status-warning{
    background:#fff4d8!important;
    color:#a66f09!important;
  }
  html[data-bb-parent-theme="premium-light"] .badge.red,
  html[data-bb-parent-theme="premium-light"] .badge.danger,
  html[data-bb-parent-theme="premium-light"] .status-danger{
    background:#fdecef!important;
    color:#c33f50!important;
  }
  html[data-bb-parent-theme="premium-light"] .badge.blue{
    background:#e8f3ff!important;
    color:#176fbd!important;
  }

  html[data-bb-parent-theme="premium-light"] nav,
  html[data-bb-parent-theme="premium-light"] .bottom-nav,
  html[data-bb-parent-theme="premium-light"] .footer,
  html[data-bb-parent-theme="premium-light"] .mobile-nav{
    background:rgba(249,252,255,.97)!important;
    border-color:#d3e1ec!important;
  }

  html[data-bb-parent-theme="premium-light"] .tab,
  html[data-bb-parent-theme="premium-light"] .nav-btn,
  html[data-bb-parent-theme="premium-light"] .nav-item{color:#71899f!important;}
  html[data-bb-parent-theme="premium-light"] .tab.active,
  html[data-bb-parent-theme="premium-light"] .nav-btn.active,
  html[data-bb-parent-theme="premium-light"] .nav-item.active{
    color:#1677ff!important;
    background:#e7f2ff!important;
  }

  html[data-bb-parent-theme="premium-light"] .table-wrap,
  html[data-bb-parent-theme="premium-light"] .table-container,
  html[data-bb-parent-theme="premium-light"] .scroll-wrap,
  html[data-bb-parent-theme="premium-light"] .list,
  html[data-bb-parent-theme="premium-light"] .list-wrap{
    background:transparent!important;
    border-color:#d6e4ef!important;
  }

  html[data-bb-parent-theme="premium-light"] hr,
  html[data-bb-parent-theme="premium-light"] .divider,
  html[data-bb-parent-theme="premium-light"] .separator{
    border-color:#d6e4ef!important;
    background:#d6e4ef!important;
  }

  html[data-bb-parent-theme="premium-light"] details,
  html[data-bb-parent-theme="premium-light"] .collapse,
  html[data-bb-parent-theme="premium-light"] .collapsible{
    border-color:#d6e4ef!important;
  }
  html[data-bb-parent-theme="premium-light"] summary{color:#234965!important;}

  html[data-bb-parent-theme="premium-light"] .loading,
  html[data-bb-parent-theme="premium-light"] .status-text{color:#708aa2!important;}
  html[data-bb-parent-theme="premium-light"] .overlay,
  html[data-bb-parent-theme="premium-light"] .modal-backdrop{
    background:rgba(38,61,82,.30)!important;
  }

  html[data-bb-parent-theme="premium-light"] .bb-loader{background:transparent!important;}
  html[data-bb-parent-theme="premium-light"] .bb-loader-card{
    background:#f9fcff!important;
    color:#173e67!important;
    border-color:#d2e1ee!important;
    box-shadow:0 10px 28px rgba(29,68,105,.10)!important;
  }
  html[data-bb-parent-theme="premium-light"] .bb-loader-card span{color:#7892aa!important;}

  /* Legacy hardcoded white / pale blocks */
  html[data-bb-parent-theme="premium-light"] [style*="background: white"],
  html[data-bb-parent-theme="premium-light"] [style*="background:white"],
  html[data-bb-parent-theme="premium-light"] [style*="background: #fff"],
  html[data-bb-parent-theme="premium-light"] [style*="background:#fff"],
  html[data-bb-parent-theme="premium-light"] [style*="background: rgb(255, 255, 255)"]{
    background:#f9fcff!important;
    color:#16324f!important;
    border-color:#d2e1ee!important;
  }

  html[data-bb-parent-theme="premium-light"] [style*="color: #18324d"],
  html[data-bb-parent-theme="premium-light"] [style*="color:#18324d"],
  html[data-bb-parent-theme="premium-light"] [style*="color: #17457a"],
  html[data-bb-parent-theme="premium-light"] [style*="color:#17457a"]{
    color:#16324f!important;
  }

  /* PREMIUM LIGHT V3.1 — universal tabs / segmented controls */
  html[data-bb-parent-theme="premium-light"] #bbCalcPageNav,
  html[data-bb-parent-theme="premium-light"] .tabs,
  html[data-bb-parent-theme="premium-light"] .tabbar,
  html[data-bb-parent-theme="premium-light"] .segmented,
  html[data-bb-parent-theme="premium-light"] .segment-control,
  html[data-bb-parent-theme="premium-light"] .calc-currency-wrap,
  html[data-bb-parent-theme="premium-light"] .currency-switch,
  html[data-bb-parent-theme="premium-light"] .top-switch,
  html[data-bb-parent-theme="premium-light"] .history-switch,
  html[data-bb-parent-theme="premium-light"] .tab-switch,
  html[data-bb-parent-theme="premium-light"] [role="tablist"]{
    background:#edf4fb!important;
    border:1px solid #d3e1ec!important;
    border-radius:16px!important;
    padding:4px!important;
    gap:6px!important;
    box-shadow:none!important;
  }

  html[data-bb-parent-theme="premium-light"] #bbCalcPageNav button,
  html[data-bb-parent-theme="premium-light"] .tabs button,
  html[data-bb-parent-theme="premium-light"] .tabbar button,
  html[data-bb-parent-theme="premium-light"] .segmented button,
  html[data-bb-parent-theme="premium-light"] .segment-control button,
  html[data-bb-parent-theme="premium-light"] .calc-currency-wrap button,
  html[data-bb-parent-theme="premium-light"] .currency-btn,
  html[data-bb-parent-theme="premium-light"] .currency-switch button,
  html[data-bb-parent-theme="premium-light"] .top-switch button,
  html[data-bb-parent-theme="premium-light"] .history-switch button,
  html[data-bb-parent-theme="premium-light"] .tab-switch button,
  html[data-bb-parent-theme="premium-light"] [role="tab"]{
    background:#f8fbff!important;
    color:#4f6d89!important;
    border:1px solid #d4e2ee!important;
    border-radius:12px!important;
    box-shadow:none!important;
    font-weight:700!important;
  }

  html[data-bb-parent-theme="premium-light"] #bbCalcPageNav button.active,
  html[data-bb-parent-theme="premium-light"] .tabs button.active,
  html[data-bb-parent-theme="premium-light"] .tabbar button.active,
  html[data-bb-parent-theme="premium-light"] .segmented button.active,
  html[data-bb-parent-theme="premium-light"] .segment-control button.active,
  html[data-bb-parent-theme="premium-light"] .calc-currency-wrap button.active,
  html[data-bb-parent-theme="premium-light"] .currency-btn.active,
  html[data-bb-parent-theme="premium-light"] .currency-switch button.active,
  html[data-bb-parent-theme="premium-light"] .top-switch button.active,
  html[data-bb-parent-theme="premium-light"] .history-switch button.active,
  html[data-bb-parent-theme="premium-light"] .tab-switch button.active,
  html[data-bb-parent-theme="premium-light"] [role="tab"].active,
  html[data-bb-parent-theme="premium-light"] [role="tab"][aria-selected="true"]{
    background:linear-gradient(135deg,#e3f0ff,#d4e8ff)!important;
    color:#1c5fa8!important;
    border:1px solid #aecaea!important;
    box-shadow:0 3px 10px rgba(22,119,255,.09)!important;
  }

  html[data-bb-parent-theme="premium-light"] #bbCalcPageNav button:focus-visible,
  html[data-bb-parent-theme="premium-light"] [role="tab"]:focus-visible{
    outline:2px solid #7fb7e8!important;
    outline-offset:2px!important;
  }

  html[data-bb-parent-theme="premium-light"] .bb-formal-icon{
    width:17px;
    height:17px;
    display:inline-flex;
    align-items:center;
    justify-content:center;
    flex:0 0 auto;
    color:currentColor;
    vertical-align:middle;
  }
  html[data-bb-parent-theme="premium-light"] .bb-formal-icon svg{
    width:17px;
    height:17px;
    display:block;
    fill:none;
    stroke:currentColor;
    stroke-width:1.8;
    stroke-linecap:round;
    stroke-linejoin:round;
  }
  html[data-bb-parent-theme="premium-light"] button[data-bb-formalized="1"],
  html[data-bb-parent-theme="premium-light"] a[data-bb-formalized="1"],
  html[data-bb-parent-theme="premium-light"] [role="tab"][data-bb-formalized="1"]{
    display:inline-flex!important;
    align-items:center!important;
    justify-content:center!important;
    gap:7px!important;
  }
  html[data-bb-parent-theme="premium-light"] h1[data-bb-formalized="1"],
  html[data-bb-parent-theme="premium-light"] h2[data-bb-formalized="1"],
  html[data-bb-parent-theme="premium-light"] h3[data-bb-formalized="1"]{
    display:flex!important;
    align-items:center!important;
    gap:7px!important;
  }

`}

function stopFrameThemeWatch(doc){
  const observer=frameThemeObservers.get(doc);
  if(observer){
    observer.disconnect();
    frameThemeObservers.delete(doc);
  }
}

function ensureFrameTheme(doc){
  if(!doc?.head)return;

  doc.documentElement?.setAttribute('data-bb-parent-theme','premium-light');
  doc.body?.setAttribute('data-bb-parent-theme','premium-light');

  let style=doc.getElementById('bbParentTheme');
  if(!style){
    style=doc.createElement('style');
    style.id='bbParentTheme';
    style.textContent=frameCss();
    doc.head.appendChild(style);
  }else if(style.textContent!==frameCss()){
    style.textContent=frameCss();
  }

  doc.getElementById('bbParentDarkTheme')?.remove();

  if(doc.head.lastElementChild!==style){
    doc.head.appendChild(style);
  }

  bbFormalizeIcons(doc);

  if(!frameThemeObservers.has(doc)){
    const observer=new MutationObserver(()=>{
      if(frameThemePending.has(doc))return;
      frameThemePending.add(doc);
      requestAnimationFrame(()=>{
        frameThemePending.delete(doc);
        try{ensureFrameTheme(doc)}catch(_){}
      });
    });
    observer.observe(doc.documentElement,{childList:true,subtree:true});
    frameThemeObservers.set(doc,observer);
  }
}

function applyFrameTheme(){
  const frame=$('moduleFrame');
  if(!frame)return;
  try{
    const doc=frame.contentDocument;
    if(!doc?.head)return;
    ensureFrameTheme(doc);
  }catch(_){/* cross-origin fallback pages keep their native design */}
}

function setTheme(){
  ROOT.setAttribute('data-bb-theme','premium-light');
  const meta=document.querySelector('meta[name="theme-color"]');
  if(meta)meta.setAttribute('content','#edf5fb');
  removeOldThemeToggle();
  bbFormalizeIcons(document);
  ensureShellIconWatch();
  applyFrameTheme();
}

function start(){
  injectShellCss();
  setTheme();
  brandLogo();
  removeOldThemeToggle();
  bbFormalizeIcons(document);
  ensureShellIconWatch();

  const frame=$('moduleFrame');
  if(frame&&!frame.dataset.bbThemeBound){
    frame.dataset.bbThemeBound='1';
    frame.addEventListener('load',()=>{
      setTimeout(applyFrameTheme,20);
      setTimeout(applyFrameTheme,180);
      setTimeout(applyFrameTheme,700);
    });
  }

  setTimeout(()=>{brandLogo();removeOldThemeToggle();bbFormalizeIcons(document);applyFrameTheme()},350);
  setTimeout(()=>{brandLogo();removeOldThemeToggle();bbFormalizeIcons(document);applyFrameTheme()},1300);
}

if(document.readyState==='loading'){
  document.addEventListener('DOMContentLoaded',start,{once:true});
}else{
  start();
}

window.BBMobileThemeV1={
  setTheme,
  getTheme:()=> 'premium-light',
  applyFrameTheme
};
})();
