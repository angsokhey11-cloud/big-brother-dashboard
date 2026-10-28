/* BIG BROTHER Mobile Performance V3 — single-workspace navigation feedback.
 * Presentation only: never preloads auth/data or keeps inactive iframes alive.
 */
(function(){
  'use strict';
  const screen=document.getElementById('moduleScreen');
  if(!screen)return;
  const overlay=document.createElement('div');
  overlay.id='bbMobileModuleTransitionV3';
  overlay.className='bb-mobile-module-transition-v3';
  overlay.hidden=true;
  overlay.setAttribute('role','status');
  overlay.setAttribute('aria-live','polite');
  overlay.innerHTML=
    '<div class="bb-mobile-transition-card">'+
    '<div class="bb-mobile-transition-mark">BB</div>'+
    '<div class="bb-mobile-transition-title">BIG BROTHER</div>'+
    '<div class="bb-mobile-transition-sub">Opening workspace…</div>'+
    '<div class="bb-mobile-transition-line"></div>'+
    '<div class="bb-mobile-transition-line short"></div>'+
    '</div>';
  const style=document.createElement('style');
  style.textContent=`
    .bb-mobile-module-transition-v3{
      position:absolute;
      top:calc(58px + env(safe-area-inset-top));
      bottom:calc(70px + env(safe-area-inset-bottom));
      left:0;right:0;
      z-index:5;
      background:#f3f7fb;
      display:flex;justify-content:center;align-items:center;
      pointer-events:none;
    }
    .bb-mobile-module-transition-v3[hidden]{display:none!important}
    .bb-mobile-transition-card{
      width:min(86%,340px);
      padding:24px;border:1px solid #dce6f1;border-radius:18px;
      box-shadow:0 9px 30px rgba(23,69,122,.06);
      background:#fff;text-align:center;font-family:Arial,sans-serif;
    }
    .bb-mobile-transition-mark{
      width:46px;height:46px;border-radius:13px;margin:0 auto 12px;
      background:#17457a;color:#fff;display:grid;place-items:center;
      font-size:17px;font-weight:900;
    }
    .bb-mobile-transition-title{color:#17457a;font-size:15px;font-weight:900}
    .bb-mobile-transition-sub{font-size:12px;color:#72839a;margin:6px 0 18px}
    .bb-mobile-transition-line{
      height:9px;border-radius:8px;background:#ecf3fa;margin:9px auto;
      width:100%;animation:bb-mobile-loading-pulse 1.6s ease-in-out infinite alternate
    }
    .bb-mobile-transition-line.short{width:66%;animation-delay:.2s}
    @keyframes bb-mobile-loading-pulse{to{opacity:.45}}
    html.bb-bottom-nav-collapsed .bb-mobile-module-transition-v3{bottom:0}
    @media(prefers-reduced-motion:reduce){.bb-mobile-transition-line{animation:none}}
  `;
  document.head.appendChild(style);
  screen.appendChild(overlay);

  let activeUrl='';
  let showTimer=0;
  let timeout=0;
  function hide(){
    clearTimeout(showTimer);
    clearTimeout(timeout);
    overlay.hidden=true;
    activeUrl='';
  }
  function start(url){
    const normalized=String(url||'');
    if(!normalized)return;
    clearTimeout(showTimer);
    clearTimeout(timeout);
    overlay.hidden=true;
    activeUrl=normalized;
    // Avoid a loading flash when the browser already has all static files.
    showTimer=setTimeout(()=>{
      if(activeUrl===normalized && !screen.hidden)overlay.hidden=false;
    },140);
    timeout=setTimeout(()=>{
      if(activeUrl===normalized)hide();
    },14000);
  }
  function finish(url){
    if(activeUrl===String(url||''))hide();
  }
  document.addEventListener('load',event=>{
    const frame=document.getElementById('moduleFrame');
    if(event.target===frame){
      finish(frame.getAttribute('src'));
    }
  },true);
  const observer=new MutationObserver(()=>{
    if(screen.hidden)hide();
  });
  observer.observe(screen,{attributes:true,attributeFilter:['hidden']});
  window.BBMobileTransitionV3={start,finish};
})();
