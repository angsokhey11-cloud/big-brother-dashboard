/* BIG BROTHER Desktop Professional UI V1 — 02-Nov-2026
 * Shared offline-safe SVGs from the Mobile Function Icons library.
 * Presentation-only. Does not change accounting, routing, values, events or RPCs.
 */
(function(){
  'use strict';
  if(window.BBDesktopProfessionalUIV1)return;
  window.BBDesktopProfessionalUIV1=true;

  const iconApi=()=>window.BBMobileFunctionIconsV1;
  const navIdRoutes={
    navDashboard:'home',navNewInvoice:'invoice',navInvoiceHistory:'history',
    navSaleReturn:'sale-return',navPaymentHistory:'payment-history',
    navDailySaleSummary:'daily-sale-summary',navDailyCashCollection:'daily-cash-collection',
    navStockAllocation:'stock-control-allocation',navBatchTransfer:'stock-control-batch-transfer',
    navBackSale:'stock-control-back-sale',navSalesSupportCalculator:'sales-support-calculator',
    navCreatePurchase:'purchase-create',navPurchaseHistory:'purchase-history',
    navPurchasePayable:'purchase-payable',navPurchasePaymentHistory:'purchase-payment-history',
    navExpenseAdd:'expense-add',navExpenseAccrued:'expense-accrued',
    navExpenseHistory:'expense-history',navExpenseMonthlyReport:'expense-monthly-report',
    navStockKeyin:'stock-keyin',navStockReport:'stock-report',
    navBatchReport:'batch-report',navClosedBatch:'closed-batch',
    navStockTransactions:'stock-transactions',navStockPendingBorrow:'stock-pending-borrow',
    navRealInvoice:'real-invoice',navARAll:'ar-all',navARYour:'ar-your',
    navARPaymentHistory:'ar-payment-history',navARDailyReceivableCash:'ar-daily-receivable-cash',
    navAdminPendingReceivable:'admin-pending-receivable',
    navAdminPendingDeposit:'admin-pending-daily-cash',
    navAdminStaffRequest:'admin-staff-request',navAdminRequest:'admin-request',
    navStaffRelation:'staff-relation'
  };
  const groupNames={
    salesMenuButton:'Sales',stockControlMenuButton:'Stock Control',
    salesSupportMenuButton:'Sales Support',purchaseMenuButton:'Purchase',
    expensesMenuButton:'Expenses',stockMenuButton:'Stock',
    stockReportMenuButton:'Stock',arMenuButton:'Receivable',
    adminWorkMenuButton:'Admin Work',masterMenuButton:'Master Data',
    customersEditorMenuButton:'Master Data',clientsEditorMenuButton:'Master Data',
    productsEditorMenuButton:'Master Data',mainReportsMenuButton:'Reports'
  };
  const names={
    'gross sales':'shopping-cart','net sales':'chart-line','monthly sales':'chart-line',
    'calculator':'calculator','monthly expense':'credit-card','cogs':'package',
    'operating expense':'receipt','net profit':'circle-dollar',
    'accounts receivable':'receivable-all','accounts payable':'wallet',
    'stock value':'warehouse','stock qty':'packages','receivable':'receivable-one',
    'assigned locations':'map-pin','your earning':'wallet','invoices':'receipt',
    'purchases':'shopping-cart','customers with sales':'users',
    'suppliers used':'building','sales locations':'map-pin',
    'management overview':'chart-column','sales by location':'map-pin',
    'monthly performance':'chart-line','receivable vs payable':'arrow-left-right',
    'monthly activity':'calendar','attention needed':'alert-triangle',
    'recent transactions':'history','system info':'settings',
    'your monthly overview':'chart-line','quick actions':'clipboard-list',
    'account receivable':'receivable-all','your collection':'collection-hand'
  };
  const safeEmojiPrefix=/^\s*(?:[\p{Extended_Pictographic}\u2600-\u27BF\u2190-\u21FF][\uFE0E\uFE0F\u200D\u20E3\p{Extended_Pictographic}\u2600-\u27BF\u2190-\u21FF]*)(?:\s+|(?=[A-Za-z]))/u;
  const svg=(name)=>iconApi()?.named?.(name)||'';
  const routeIcon=(route)=>iconApi()?.route?.(route)||svg('layers');
  const groupIcon=(group)=>iconApi()?.group?.(group)||svg('layers');
  function glyph(markup, cls){
    const span=document.createElement('span');
    span.className=cls||'bb-desktop-glyph';
    span.setAttribute('aria-hidden','true');
    span.innerHTML=markup;
    return span;
  }
  const textValue=el=>String(el?.textContent||'').trim();
  function withoutEmoji(text){
    return String(text||'').replace(safeEmojiPrefix,'').trim();
  }
  function firstText(el){
    for(const node of el.childNodes)if(node.nodeType===Node.TEXT_NODE && node.textContent.trim())return node;
    return null;
  }
  function nameIcon(label){
    const key=withoutEmoji(label).toLowerCase().replace(/\s*\([^)]*\)/g,'').trim();
    return names[key]||(
      key.includes('receivable')?'receivable-all':
      key.includes('invoice')?'receipt':key.includes('profit')?'chart-line':
      key.includes('stock')?'package':key.includes('sale')?'chart-column':
      key.includes('payment')?'credit-card':key.includes('expense')?'wallet':
      key.includes('activity')?'calendar':key.includes('purchase')?'shopping-cart':
      key.includes('report')?'chart-column':key.includes('request')?'clipboard-list':
      key.includes('customer')?'users':key.includes('location')?'map-pin':
      key.includes('earning')?'wallet':'layers'
    );
  }
  function iconizeText(el,iconName,cls){
    if(!el||el.dataset.bbDesktopIcon==='1')return;
    const textNode=firstText(el);
    if(!textNode)return;
    const old=textNode.textContent;
    const next=old.replace(safeEmojiPrefix,'');
    if(old===next && !el.closest('.sidebar'))return;
    textNode.textContent=next;
    el.insertBefore(glyph(svg(iconName),cls),el.firstChild);
    el.dataset.bbDesktopIcon='1';
  }
  function nav(){
    const sidebar=document.querySelector('.sidebar');
    if(!sidebar)return;
    sidebar.querySelectorAll('.nav-toggle-main, .nested-nav-main').forEach(wrap=>{
      const button=wrap.closest('button'),child=wrap.firstElementChild;
      if(!button||!child||child.dataset.bbDesktopIcon==='1')return;
      const group=groupNames[button.id]||textValue(wrap.querySelector('span:nth-child(2)'))||textValue(wrap);
      child.innerHTML=groupIcon(group);
      child.classList.add('bb-desktop-nav-icon');
      child.setAttribute('aria-hidden','true');
      child.dataset.bbDesktopIcon='1';
    });
    sidebar.querySelectorAll('.shell-nav-link,.nav-submenu button').forEach(el=>{
      if(el.dataset.bbDesktopIcon==='1')return;
      const match=(el.getAttribute('onclick')||'').match(/loadWorkspace\(['"]([^'"]+)['"]\)/);
      const route=match?.[1]||navIdRoutes[el.id];
      if(route){
        const textNode=firstText(el);
        if(textNode){
          textNode.textContent=textNode.textContent.replace(safeEmojiPrefix,'');
          el.insertBefore(glyph(routeIcon(route),'bb-desktop-nav-icon'),el.firstChild);
          el.dataset.bbDesktopIcon='1';
        }
      }else{
        const label=textValue(el);
        const node=firstText(el);
        if(node&&safeEmojiPrefix.test(node.textContent)){
          node.textContent=node.textContent.replace(safeEmojiPrefix,'');
          el.insertBefore(glyph(svg(nameIcon(label)),'bb-desktop-nav-icon'),el.firstChild);
          el.dataset.bbDesktopIcon='1';
        }
      }
    });
  }
  function overview(){
    const root=document.querySelector('#bbOverviewBody');
    if(!root)return;
    root.querySelectorAll('.bb-ov-kpi .i,.bb-ov-act .ic,.bb-staff-kpi .ic,.bb-staff-action .ic').forEach(el=>{
      if(el.dataset.bbDesktopIcon==='1')return;
      const host=el.closest('.bb-ov-kpi,.bb-ov-act,.bb-staff-kpi,.bb-staff-action');
      const label=textValue(host?.querySelector('small')||host?.querySelector('span:not(.ic)')||host?.querySelector('strong'));
      el.innerHTML=svg(nameIcon(label));
      el.dataset.bbDesktopIcon='1';
    });
    document.querySelectorAll('.bb-ov-monthbar strong,.bb-ov-head > strong,.bb-staff-scope-head > strong').forEach(el=>{
      if(el.dataset.bbDesktopIcon==='1')return;
      const node=firstText(el),old=node?.textContent||'';
      if(!node||!safeEmojiPrefix.test(old))return;
      node.textContent=old.replace(safeEmojiPrefix,'');
      el.insertBefore(glyph(svg(nameIcon(old)),'bb-desktop-section-icon'),el.firstChild);
      el.dataset.bbDesktopIcon='1';
    });
    document.querySelectorAll('.bb-ov-link,.bb-ov-btn').forEach(btn=>{
      if(btn.dataset.bbDesktopPolished)return;
      btn.dataset.bbDesktopPolished='1';
      btn.setAttribute('title',btn.getAttribute('title')||textValue(btn));
    });
  }
  function frame(){
    const f=document.getElementById('moduleFrame');
    if(!f||f.dataset.bbDesktopFrameBound)return;
    f.dataset.bbDesktopFrameBound='1';
    let innerObserver=null;
    function install(){
      if(innerObserver){innerObserver.disconnect();innerObserver=null}
      try{
        const doc=f.contentDocument;
        if(!doc||!doc.body||!doc.head)return;
        if(!doc.getElementById('bb-desktop-embedded-icon-css')){
          const style=doc.createElement('style');style.id='bb-desktop-embedded-icon-css';
          style.textContent='.bb-desktop-inline-icon{display:inline-flex;vertical-align:middle;align-items:center;justify-content:center;width:20px;height:20px;margin-right:7px;color:#2867a1;flex:none}.bb-desktop-inline-icon svg{width:19px;height:19px;stroke:currentColor}.bb-desktop-inline-icon + *{vertical-align:middle}';
          doc.head.appendChild(style);
        }
        const apply=()=>{
          doc.querySelectorAll('.hero h1,.page-title,h1,h2,h3,.card-head strong,.section-title,.card-title,button').forEach(el=>{
            if(el.dataset.bbDesktopIcon==='1'||el.closest('.sidebar,.bb-desktop-icon-ignore,[contenteditable],svg'))return;
            if(el.closest('.bb-ov,.bb-ov-kpi'))return;
            const t=firstText(el);
            if(!t||!safeEmojiPrefix.test(t.textContent))return;
            const label=t.textContent;
            t.textContent=t.textContent.replace(safeEmojiPrefix,'');
            el.insertBefore(glyph(svg(nameIcon(label)),'bb-desktop-inline-icon'),el.firstChild);
            el.dataset.bbDesktopIcon='1';
          });
        };
        apply();
        let queued=false;
        innerObserver=new MutationObserver(()=>{
          if(queued)return;
          queued=true;
          doc.defaultView.requestAnimationFrame(()=>{queued=false;apply()});
        });
        innerObserver.observe(doc.body,{subtree:true,childList:true});
      }catch(_){
        /* Cross-origin or isolated local module: never interfere with its code. */
      }
    }
    f.addEventListener('load',install);
    install();
  }
  function styles(){
    if(document.getElementById('bb-desktop-professional-style'))return;
    const css=document.createElement('style');css.id='bb-desktop-professional-style';
    css.textContent=[
      'body{--bb-ui-blue:#174b83;--bb-ui-border:#d8e5f0}',
      '.sidebar{background:linear-gradient(180deg,#123c67,#103358)!important}',
      '.sidebar .nav{gap:3px!important}',
      '.sidebar .nav-toggle,.sidebar .shell-nav-link{border-radius:10px!important;min-height:43px;transition:background .15s ease,border-color .15s ease}',
      '.sidebar .nav-submenu button{border-radius:8px!important;min-height:37px;line-height:1.45!important}',
      '.sidebar button:focus-visible{outline:2px solid #a8d4ff!important;outline-offset:2px}',
      '.sidebar .shell-nav-link.active,.sidebar .nav-submenu button.active{background:#ffffff27!important;box-shadow:inset 3px 0 #90c7ff}',
      '.bb-desktop-nav-icon{width:20px;height:20px;display:inline-flex;align-items:center;justify-content:center;flex:none;vertical-align:middle;color:inherit}',
      '.bb-desktop-nav-icon svg{width:19px!important;height:19px!important;stroke:currentColor!important}',
      '.sidebar .bb-desktop-nav-icon svg{color:#d5e8fa!important}',
      '.sidebar .nav-toggle-main,.sidebar .nested-nav-main{min-width:0}',
      '.sidebar .nav-submenu button .bb-desktop-nav-icon{margin-right:7px}',
      '.sidebar .nav-arrow{margin-left:auto;color:#abc7e3}',
      '.dashboard-home{background:#f1f6fb!important}',
      '.bb-ov-monthbar{background:linear-gradient(110deg,#fff,#f5faff)!important;border-color:var(--bb-ui-border)!important;box-shadow:0 4px 16px #12416c0a!important}',
      '.bb-ov-monthbar > div:first-child strong{font-size:17px!important;display:flex!important;gap:9px;align-items:center}',
      '.bb-desktop-section-icon{display:inline-flex;align-items:center;justify-content:center;color:#286cb2;vertical-align:middle;margin-right:7px;flex:none}',
      '.bb-desktop-section-icon svg{width:18px;height:18px;stroke:currentColor}',
      '.bb-ov-head > strong{display:inline-flex!important;align-items:center;gap:3px!important}',
      '.bb-ov-kpis{display:grid!important;grid-template-columns:repeat(4,minmax(0,1fr))!important;gap:12px!important}',
      '.bb-ov-kpi{min-height:128px!important;padding:15px 16px!important;border-radius:15px!important;display:grid!important;grid-template-columns:52px minmax(0,1fr)!important;grid-template-rows:auto auto 1fr!important;column-gap:11px!important;align-items:center!important;background:linear-gradient(145deg,#fff,#f9fcff)!important;box-shadow:0 4px 14px #173b6010!important}',
      '.bb-ov-kpi:before{width:3px!important}',
      '.bb-ov-kpi .i{grid-row:1/4!important;grid-column:1!important;display:grid!important;place-items:center!important;width:48px;height:48px;border:1px solid color-mix(in srgb,var(--a,#2f6fed) 22%,white);border-radius:13px;background:color-mix(in srgb,var(--a,#2f6fed) 9%,white);color:var(--a,#2f6fed)!important;font-size:0!important}',
      '.bb-ov-kpi .i svg{width:25px!important;height:25px!important;color:inherit!important;stroke:currentColor!important}',
      '.bb-ov-kpi small{grid-column:2!important;grid-row:1!important;margin:0!important;font-size:10px!important;color:#687d91!important;line-height:1.5!important}',
      '.bb-ov-kpi strong{grid-column:2!important;grid-row:2!important;font-size:clamp(17px,1.3vw,23px)!important;line-height:1.26!important;margin:3px 0!important;white-space:normal!important;overflow-wrap:anywhere}',
      '.bb-ov-kpi em{grid-column:2!important;grid-row:3!important;margin:1px 0 0!important;font-size:10px!important;line-height:1.4!important;white-space:normal!important}',
      '.bb-ov-card{border-radius:15px!important;border-color:var(--bb-ui-border)!important}',
      '.bb-ov-head{background:linear-gradient(110deg,#fff,#f8fbff)!important;padding:13px 16px!important}',
      '.bb-ov-head strong{font-size:13px!important}',
      '.bb-ov-act{border-radius:12px!important;transition:transform .15s ease,box-shadow .15s ease}',
      '.bb-ov-act:hover{transform:translateY(-2px);box-shadow:0 5px 16px #144e7b19}',
      '.bb-ov-act .ic{font-size:0!important;color:#27629c}',
      '.bb-ov-act .ic svg,.bb-staff-kpi .ic svg,.bb-staff-action .ic svg{width:25px;height:25px;stroke:currentColor}',
      '.bb-staff-kpi .ic,.bb-staff-action .ic{font-size:0!important;display:inline-flex;align-items:center;color:#2868a4}',
      '.bb-ov-link,.bb-ov-btn{border-radius:10px!important;transition:filter .16s ease,transform .16s ease}',
      '.bb-ov-link:hover,.bb-ov-btn:hover{filter:brightness(.97)}',
      '.bb-ov-kpi:focus-visible,.bb-ov-act:focus-visible,.bb-staff-action:focus-visible{outline:2px solid #2f6fed!important;outline-offset:3px}',
      '@media(min-width:1900px){.bb-ov-kpis{grid-template-columns:repeat(5,minmax(0,1fr))!important}}',
      '@media(max-width:1350px){.bb-ov-kpis{grid-template-columns:repeat(3,minmax(0,1fr))!important}}',
      '@media(max-width:980px){.bb-ov-kpis{grid-template-columns:repeat(2,minmax(0,1fr))!important}.bb-ov-kpi{min-height:116px!important}}',
      '@media(max-width:620px){.bb-ov-kpis{grid-template-columns:1fr!important}.bb-ov-kpi{min-height:96px!important}.bb-ov-kpi strong{font-size:21px!important}}',
      '@media(prefers-reduced-motion:reduce){.bb-ov-kpi,.bb-ov-act,.sidebar button{transition:none!important}}'
    ].join('\n');
    document.head.appendChild(css);
  }
  function refresh(){
    styles();nav();overview();frame();
  }
  function init(){
    refresh();
    const root=document.body;
    if(!root)return;
    let queued=false;
    const observer=new MutationObserver(()=>{
      if(queued)return;
      queued=true;
      requestAnimationFrame(()=>{queued=false;nav();overview();frame()});
    });
    observer.observe(root,{subtree:true,childList:true});
    window.BBDesktopProfessionalUIRefresh=refresh;
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});
  else init();
})();