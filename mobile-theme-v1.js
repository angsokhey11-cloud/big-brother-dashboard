/* BIG BROTHER — Premium Mobile Theme V2.0 — Modern Tech
   Mobile app shell + same-origin embedded function dark theme.
   Desktop dashboard styling is not modified here. */
(function(){
'use strict';

const STORAGE_KEY='BB_MOBILE_THEME_V2';
const ROOT=document.documentElement;
const $=id=>document.getElementById(id);
let theme='dark';

function readTheme(){
  try{const saved=localStorage.getItem(STORAGE_KEY);return saved==='dark'||saved==='light'?saved:'dark'}catch(_){return'dark'}
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


    /* MODERN TECH V2 — final mobile-only visual layer */
    html[data-bb-theme="dark"] body{
      background:
        radial-gradient(circle at 12% -8%,rgba(11,99,189,.30) 0,transparent 30%),
        radial-gradient(circle at 100% 0%,rgba(0,168,255,.14) 0,transparent 26%),
        linear-gradient(160deg,#020d1d 0%,#041a35 50%,#07264b 100%)!important;
      color:#eaf5ff!important
    }
    html[data-bb-theme="dark"] .mobile-home,
    html[data-bb-theme="dark"] .menu-screen,
    html[data-bb-theme="dark"] .module-screen{
      background:
        radial-gradient(circle at 12% -8%,rgba(11,99,189,.25) 0,transparent 28%),
        radial-gradient(circle at 100% 0%,rgba(0,168,255,.11) 0,transparent 25%),
        linear-gradient(165deg,#031327 0%,#061b36 46%,#082548 100%)!important
    }
    html[data-bb-theme="dark"] .mobile-scroll,
    html[data-bb-theme="dark"] #menuGrid.bb-dropdown-menu{
      background:transparent!important
    }

    html[data-bb-theme="dark"] .hero,
    html[data-bb-theme="dark"] .simple-header,
    html[data-bb-theme="dark"] .module-header{
      background:
        radial-gradient(circle at 92% 0%,rgba(26,167,255,.18) 0,transparent 30%),
        linear-gradient(135deg,#051831 0%,#082c5a 58%,#075fb9 100%)!important;
      border-color:#1a568f!important;
      box-shadow:0 12px 30px rgba(0,17,38,.40),inset 0 -1px 0 rgba(86,184,255,.14)!important
    }

    html[data-bb-theme="dark"] .panel,
    html[data-bb-theme="dark"] .menu-card,
    html[data-bb-theme="dark"] .bb-dd-group,
    html[data-bb-theme="dark"] .sheet-card,
    html[data-bb-theme="dark"] .login-card{
      background:linear-gradient(145deg,#0b2344 0%,#071a33 100%)!important;
      border-color:#1d4f80!important;
      box-shadow:0 10px 26px rgba(0,16,36,.35),inset 0 1px 0 rgba(92,188,255,.07)!important
    }

    html[data-bb-theme="dark"] .hero-chip{
      background:rgba(11,55,104,.84)!important;
      border-color:#3177b6!important;
      color:#dff3ff!important
    }
    html[data-bb-theme="dark"] .icon-btn,
    html[data-bb-theme="dark"] .header-btn,
    html[data-bb-theme="dark"] .desktop-small{
      background:#0d3d72!important;
      border:1px solid #2a6da8!important;
      color:#eef9ff!important
    }

    html[data-bb-theme="dark"] #kpiGrid .kpi,
    html[data-bb-theme="dark"] #kpiGrid .sales-kpi{
      background:linear-gradient(145deg,#0c2c56 0%,#071c37 100%)!important;
      border:1px solid #1e578d!important;
      box-shadow:0 8px 20px rgba(0,16,36,.30),inset 0 1px 0 rgba(101,196,255,.07)!important
    }
    html[data-bb-theme="dark"] #kpiGrid .kpi:nth-child(1),
    html[data-bb-theme="dark"] #kpiGrid .sales-kpi:nth-child(1){box-shadow:0 8px 20px rgba(0,16,36,.30),inset 3px 0 0 #1da1ff!important}
    html[data-bb-theme="dark"] #kpiGrid .kpi:nth-child(2),
    html[data-bb-theme="dark"] #kpiGrid .sales-kpi:nth-child(2){box-shadow:0 8px 20px rgba(0,16,36,.30),inset 3px 0 0 #26c6ff!important}
    html[data-bb-theme="dark"] #kpiGrid .kpi:nth-child(3),
    html[data-bb-theme="dark"] #kpiGrid .sales-kpi:nth-child(3){box-shadow:0 8px 20px rgba(0,16,36,.30),inset 3px 0 0 #4f8cff!important}
    html[data-bb-theme="dark"] #kpiGrid .kpi:nth-child(4),
    html[data-bb-theme="dark"] #kpiGrid .sales-kpi:nth-child(4){box-shadow:0 8px 20px rgba(0,16,36,.30),inset 3px 0 0 #00b7d8!important}
    html[data-bb-theme="dark"] #kpiGrid .kpi small,
    html[data-bb-theme="dark"] #kpiGrid .sales-kpi small{color:#93b4d4!important}
    html[data-bb-theme="dark"] #kpiGrid .kpi strong,
    html[data-bb-theme="dark"] #kpiGrid .sales-kpi strong{color:#f4fbff!important}
    html[data-bb-theme="dark"] #kpiGrid .kpi em,
    html[data-bb-theme="dark"] #kpiGrid .sales-kpi em{color:#7fa6ca!important}

    html[data-bb-theme="dark"] .quick-icon,
    html[data-bb-theme="dark"] .recent-icon{
      background:linear-gradient(145deg,#0d3c72,#08254a)!important;
      border:1px solid #22629c!important;
      box-shadow:0 7px 17px rgba(0,16,36,.34),inset 0 1px 0 rgba(121,204,255,.10)!important
    }
    html[data-bb-theme="dark"] .recent-row{border-bottom-color:#173d63!important}
    html[data-bb-theme="dark"] .recent-side strong{color:#62c7ff!important}

    html[data-bb-theme="dark"] .attention-card{
      background:linear-gradient(145deg,#0b294f,#071d39)!important;
      border:1px solid #1d4f80!important
    }
    html[data-bb-theme="dark"] .attention-card b{color:#f3faff!important}
    html[data-bb-theme="dark"] .attention-card span{color:#8fb1d1!important}

    html[data-bb-theme="dark"] .bottom-nav{
      background:rgba(3,21,43,.97)!important;
      border-top-color:#194978!important;
      box-shadow:0 -10px 28px rgba(0,16,36,.50)!important
    }
    html[data-bb-theme="dark"] .nav-btn{color:#789cbc!important}
    html[data-bb-theme="dark"] .nav-btn b{color:#89add0!important}
    html[data-bb-theme="dark"] .nav-btn.active{
      color:#7bd7ff!important;
      background:linear-gradient(145deg,#0b4784,#082d58)!important;
      box-shadow:inset 0 0 0 1px #2c75b4!important
    }
    html[data-bb-theme="dark"] .nav-btn.active b{color:#6fd4ff!important}

    html[data-bb-theme="dark"] .bb-dd-group>summary,
    html[data-bb-theme="dark"] .bb-dd-item{
      background:linear-gradient(145deg,#0b274a,#071b35)!important;
      border-color:#1d4f80!important
    }
    html[data-bb-theme="dark"] .bb-dd-group[open]>summary{
      background:#0d355f!important;
      border-color:#2771ac!important
    }

    html[data-bb-theme="dark"] .sheet-option{
      background:#0a294f!important;
      border-color:#1f5789!important
    }
    html[data-bb-theme="dark"] .sheet-close{
      background:#102e50!important;
      color:#dcefff!important;
      border:1px solid #225783!important
    }
    html[data-bb-theme="dark"] .bb-theme-pill{
      background:#075d9b!important;
      color:#d9f4ff!important;
      box-shadow:inset 0 0 0 1px rgba(45,168,239,.33)!important
    }

    html[data-bb-theme="dark"] .login-card input{
      background:#051a32!important;
      border-color:#245b8c!important;
      color:#edf8ff!important
    }
    html[data-bb-theme="dark"] .login-card button{
      background:linear-gradient(135deg,#0876ce,#0b55a8)!important;
      box-shadow:0 8px 20px rgba(0,111,189,.23)!important
    }
    html[data-bb-theme="dark"] .boot-screen,
    html[data-bb-theme="dark"] .login-screen{
      background:
        radial-gradient(circle at 75% 15%,rgba(12,104,189,.30) 0,transparent 30%),
        linear-gradient(155deg,#020b18 0%,#04182f 52%,#08284b 100%)!important
    }
    html[data-bb-theme="dark"] .boot-card{
      background:linear-gradient(145deg,#0b2344,#06182e)!important;
      border-color:#1c5488!important
    }
    html[data-bb-theme="dark"] .module-frame{background:#04172e!important}
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
  btn.innerHTML='<span id="bbThemeIcon">⚡</span><div><strong>Modern Tech</strong><small>Deep blue premium mobile interface</small></div><span id="bbThemeState" class="bb-theme-pill">ON</span>';
  btn.addEventListener('click',()=>setTheme(theme==='dark'?'light':'dark',true));
  if(signout)card.insertBefore(btn,signout);else card.appendChild(btn);updateToggle();
}
function updateToggle(){const state=$('bbThemeState'),icon=$('bbThemeIcon');if(state)state.textContent=theme==='dark'?'ON':'OFF';if(icon)icon.textContent=theme==='dark'?'⚡':'☀️'}

function frameDarkCss(){return `

  :root{
    color-scheme:dark!important;
    --bb-mt-bg:#031327;
    --bb-mt-bg-2:#061b36;
    --bb-mt-surface:#0a2344;
    --bb-mt-surface-2:#0d315c;
    --bb-mt-border:#1d4f80;
    --bb-mt-border-strong:#28689f;
    --bb-mt-text:#edf8ff;
    --bb-mt-muted:#8fb0cf;
    --bb-mt-blue:#63cfff;
    --bb-mt-primary:#0b83da;
  }

  html,body{
    min-height:100%!important;
    background:
      radial-gradient(circle at 10% -8%,rgba(11,99,189,.20) 0,transparent 28%),
      linear-gradient(165deg,#031327 0%,#061b36 52%,#082548 100%)!important;
    color:var(--bb-mt-text)!important;
  }

  body,
  main,.app,.page,.screen,.workspace,.wrap,.container,
  .content,.content-wrap,.page-wrap,.main,.main-content,
  .mobile-page,.report-page,.history-page,.workspace-body,
  .page-body,.app-body,.module-body{
    background:transparent!important;
    color:var(--bb-mt-text)!important;
  }

  header,.header,.topbar,.toolbar,.app-header,.page-header,
  .mobile-header,.report-header,.titlebar,.nav-header{
    background:linear-gradient(135deg,#061b37,#0a3768)!important;
    color:#f3fbff!important;
    border-color:#1d568a!important;
    box-shadow:0 7px 20px rgba(0,16,36,.28)!important;
  }

  .card,.panel,.sheet-card,.modal,.dialog,
  .filter-card,.filter-panel,.location-card,.product-card,
  .summary-card,.kpi,.kpi-card,.stat-card,.report-card,
  .history-card,.transaction-card,.request-card,.invoice-card,
  .item-card,.client-card,.customer-card,.batch-card,.stock-card,
  .expense-card,.payment-card,.statement-card,
  .accordion-item,.table-card,.form-card,.form-section,
  .detail-card,.result-card,.list-card,.info-card,.data-card{
    background:linear-gradient(145deg,#0b2344 0%,#071a33 100%)!important;
    color:var(--bb-mt-text)!important;
    border-color:var(--bb-mt-border)!important;
    box-shadow:0 6px 18px rgba(0,16,36,.27),inset 0 1px 0 rgba(107,200,255,.05)!important;
  }

  .section,.section-wrap,.group,.group-wrap,.row,.grid{
    border-color:var(--bb-mt-border)!important;
  }

  h1,h2,h3,h4,h5,h6,
  .title,.page-title,.section-title,.card-title,
  .label,.name,strong,b{
    color:#f2faff!important;
  }

  p,.subtitle,.description,.helper,.hint,.muted,.sub,.meta,
  .caption,.note,small,.small,.secondary,.timestamp,.date,.unit{
    color:var(--bb-mt-muted)!important;
  }

  a{color:#6ed0ff!important;}

  input,select,textarea,
  .input,.select,.search,.search-input,.form-control{
    background:#051a32!important;
    color:#edf8ff!important;
    border-color:#245b8c!important;
    box-shadow:none!important;
  }

  input:focus,select:focus,textarea:focus,
  .input:focus,.select:focus,.search:focus,.search-input:focus,.form-control:focus{
    border-color:#2a9ff0!important;
    box-shadow:0 0 0 3px rgba(20,151,237,.13)!important;
    outline:none!important;
  }

  input::placeholder,textarea::placeholder{color:#6f92b4!important;}
  option{background:#0a2344!important;color:#edf8ff!important;}

  table{
    background:transparent!important;
    color:var(--bb-mt-text)!important;
    border-color:var(--bb-mt-border)!important;
  }
  thead,thead tr{background:transparent!important;}
  th{
    background:#0d315c!important;
    color:#eaf6ff!important;
    border-color:#1a466f!important;
  }
  td{
    background:#081d39!important;
    color:#dcecff!important;
    border-color:#173f66!important;
  }
  tbody tr:nth-child(even) td{background:#0a2344!important;}

  button,.btn,.button{
    color:#eaf6ff!important;
    border-color:#255f93!important;
    box-shadow:none!important;
  }

  .btn-primary,.primary,.primary-btn,.save-btn,.submit-btn,
  button[type="submit"],button.green,.btn.green{
    background:linear-gradient(135deg,#0b83da,#095ab1)!important;
    color:#fff!important;
    border-color:#2a94da!important;
    box-shadow:0 6px 16px rgba(0,104,178,.18)!important;
  }

  .btn-secondary,.secondary-btn,.ghost-btn,.ghost,
  .filter-btn,.chip,.pill,
  .badge:not(.success):not(.danger):not(.warning){
    background:#0e3159!important;
    color:#d8efff!important;
    border-color:#28689f!important;
  }

  .danger,.btn-danger,.error,.status-danger{color:#ffd8de!important;}
  .success,.status-success{color:#b9f6dd!important;}
  .warning,.status-warning{color:#ffe7a8!important;}

  nav,.bottom-nav,.footer,.tabs,.tabbar,.mobile-nav{
    background:rgba(4,23,45,.96)!important;
    border-color:#1b4e7d!important;
  }

  .tab,.nav-btn,.nav-item{color:#85a7c5!important;}
  .tab.active,.nav-btn.active,.nav-item.active{
    color:#6fd4ff!important;
    background:#0b3e73!important;
  }

  .table-wrap,.table-container,.scroll-wrap,.list,.list-wrap{
    background:transparent!important;
    border-color:var(--bb-mt-border)!important;
  }

  hr,.divider,.separator{
    border-color:var(--bb-mt-border)!important;
    background:var(--bb-mt-border)!important;
  }

  details,.collapse,.collapsible{border-color:var(--bb-mt-border)!important;}
  summary{color:#eaf6ff!important;}

  .empty,.empty-state,.loading,.status-text{color:var(--bb-mt-muted)!important;}
  .overlay,.modal-backdrop{background:rgba(0,8,18,.78)!important;}

  [style*="background: white"],
  [style*="background:white"],
  [style*="background: #fff"],
  [style*="background:#fff"],
  [style*="background: rgb(255, 255, 255)"]{
    background:#0a2344!important;
    color:var(--bb-mt-text)!important;
  }

  [style*="color: #18324d"],
  [style*="color:#18324d"],
  [style*="color: #17457a"],
  [style*="color:#17457a"]{
    color:var(--bb-mt-text)!important;
  }

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
  const meta=document.querySelector('meta[name="theme-color"]');if(meta)meta.setAttribute('content',theme==='dark'?'#041a35':'#1267b0');
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
