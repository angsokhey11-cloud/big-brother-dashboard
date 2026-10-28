/* BIG BROTHER Mobile Function Icons V1
 * Lightweight, offline-safe SVG icon system. No emoji fonts, external
 * icon CDNs, scripts or network calls. Appearance only: no routing changes.
 */
(function(){
  'use strict';

  const shapes={
    'receipt':'<path d="M4 3h16v18l-4-2-4 2-4-2-4 2V3Z"/><path d="M8 8h8M8 12h8M8 16h4"/>',
    'file-text':'<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8Z"/><path d="M14 2v6h6M8 13h8M8 17h8"/>',
    'file-plus':'<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8Z"/><path d="M14 2v6h6M12 12v7M8.5 15.5h7"/>',
    'history':'<path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5M12 7v5l3.5 2"/>',
    'users':'<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/>',
    'user-plus':'<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M19 8v6m-3-3h6"/>',
    'map-pin':'<path d="M20 10c0 5-8 12-8 12S4 15 4 10a8 8 0 1 1 16 0Z"/><circle cx="12" cy="10" r="2.5"/>',
    'truck':'<path d="M3 5h11v12H3zM14 9h4l3 4v4h-7"/><circle cx="7.5" cy="18" r="2"/><circle cx="17.5" cy="18" r="2"/>',
    'package':'<path d="m12 2 9 5-9 5-9-5 9-5ZM3 7v10l9 5 9-5V7M12 12v10M7.5 4.5l9 5"/>',
    'packages':'<path d="m12 2 7 4-7 4-7-4 7-4ZM5 6v8l7 4 7-4V6M12 10v8M3 17l9 5 9-5"/>',
    'warehouse':'<path d="M3 22V8l9-5 9 5v14M3 11h18M8 22v-7h8v7M10 18h4"/>',
    'arrow-left-right':'<path d="M8 3 4 7l4 4M4 7h15M16 13l4 4-4 4M20 17H5"/>',
    'rotate-ccw':'<path d="M3 11a9 9 0 1 1 2.5 6.3M3 3v8h8"/>',
    'circle-check':'<circle cx="12" cy="12" r="9"/><path d="m8 12 2.8 2.8L16.5 9"/>',
    'clipboard-list':'<rect x="5" y="4" width="14" height="18" rx="2"/><rect x="9" y="2" width="6" height="4" rx="1"/><path d="M9 11h6M9 15h6M9 19h4"/>',
    'clipboard-check':'<rect x="5" y="4" width="14" height="18" rx="2"/><rect x="9" y="2" width="6" height="4" rx="1"/><path d="m9 14 2 2 4-5"/>',
    'calculator':'<rect x="4" y="2" width="16" height="20" rx="2"/><path d="M8 6h8M8 11h2m4 0h2M8 15h2m4 0h2M8 19h2m4 0h2"/>',
    'chart-column':'<path d="M3 3v18h18M7 17v-5h3v5M12 17V9h3v8M17 17V5h3v12"/>',
    'chart-line':'<path d="M3 3v18h18M6 16l4-5 4 2 5-7"/>',
    'wallet':'<rect x="3" y="6" width="18" height="15" rx="2"/><path d="M3 10h18M7 6V4a2 2 0 0 1 2-2h10v4M16 15h2"/>',
    'banknote':'<rect x="2" y="5" width="20" height="14" rx="2"/><circle cx="12" cy="12" r="3"/><path d="M6 9h.01M18 15h.01"/>',
    'credit-card':'<rect x="2" y="5" width="20" height="14" rx="2"/><path d="M2 10h20M6 15h4"/>',
    'scan-line':'<path d="M4 8V5a1 1 0 0 1 1-1h3M16 4h3a1 1 0 0 1 1 1v3M20 16v3a1 1 0 0 1-1 1h-3M8 20H5a1 1 0 0 1-1-1v-3M3 12h18"/>',
    'alert-triangle':'<path d="m12 3 10 17H2L12 3Z"/><path d="M12 9v5m0 3h.01"/>',
    'bell':'<path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4"/>',
    'shopping-cart':'<circle cx="9" cy="21" r="1"/><circle cx="20" cy="21" r="1"/><path d="M2 3h2l3 13h13l2-9H5"/>',
    'clock':'<circle cx="12" cy="12" r="9"/><path d="M12 7v6l4 2"/>',
    'calendar':'<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M7 3v4m10-4v4M3 10h18M8 14h3m2 0h3M8 17h3"/>',
    'book-open':'<path d="M12 7a9 9 0 0 0-9-2v14a9 9 0 0 1 9 2 9 9 0 0 1 9-2V5a9 9 0 0 0-9 2ZM12 7v14"/>',
    'archive':'<rect x="3" y="4" width="18" height="5" rx="1"/><path d="M5 9v11h14V9M10 13h4"/>',
    'list-filter':'<path d="M4 6h16M7 11h10M10 16h4"/>',
    'search':'<circle cx="10.5" cy="10.5" r="6.5"/><path d="m16 16 5 5"/>',
    'tag':'<path d="M2 10V3h7l12 12-6 6L3 9Z"/><circle cx="6.5" cy="6.5" r="1"/>',
    'building':'<rect x="4" y="3" width="16" height="18" rx="1"/><path d="M8 7h2m4 0h2M8 11h2m4 0h2M8 15h2m4 0h2M10 21v-3h4v3"/>',
    'settings':'<circle cx="12" cy="12" r="3"/><path d="M10 2h4l.8 2.8 2 .9 2.6-1.3 2.5 3.4-2 2.1v2.3l2 2.1-2.5 3.4-2.6-1.3-2 .9L14 22h-4l-.8-2.8-2-.9-2.6 1.3-2.5-3.4 2-2.1v-2.3l-2-2.1 2.5-3.4 2.6 1.3 2-.9L10 2Z"/>',
    'shield-check':'<path d="m12 2 9 4v6c0 6-4.3 9-9 10-4.7-1-9-4-9-10V6l9-4Z"/><path d="m8 12 3 3 5-6"/>',
    'home':'<path d="m3 10 9-7 9 7M5 9v12h14V9M9 21v-8h6v8"/>',
    'menu':'<path d="M4 6h16M4 12h16M4 18h16"/>',
    'plus':'<path d="M12 5v14M5 12h14"/>',
    'layers':'<path d="m12 2 9 6-9 6-9-6 9-6ZM3 12l9 6 9-6M3 16l9 6 9-6"/>',
    'upload':'<path d="M12 16V3M7 8l5-5 5 5M4 17v4h16v-4"/>',
    'database':'<ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M3 5v14c0 1.7 4 3 9 3s9-1.3 9-3V5M3 12c0 1.7 4 3 9 3s9-1.3 9-3"/>',
    'file-box':'<path d="M14 2H5a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V9l-7-7ZM14 2v7h7M7 14h10M7 18h6"/>',
    'circle-dollar':'<circle cx="12" cy="12" r="9"/><path d="M15 8c-1.2-1-5-1.2-6.3.5-1.7 2.4 2 3.2 3.3 3.5 2.2.5 4 1.1 3 3.5-1 2-4.7 2.5-7 .5M12 5v14"/>',
    /* Receivable: one pending record going into a collection tray. */
    'receivable-one':'<rect x="3" y="3" width="12" height="8" rx="1.6"/><path d="M6 6h6M6 8.5h3M18 5v6m-2-2 2 2 2-2M4 15h16l1 5H3l1-5ZM10 17.5h4"/>',
    /* All receivables: stacked records with a single organized tray. */
    'receivable-all':'<path d="M6 2h11v7M4 5h11v8H4zM7 8h5M7 10.5h3M18 9v5m-2-2 2 2 2-2M3 16h18v5H3zM10 18.5h4"/>',
    /* Collection: a single coin received into an open hand. */
    'collection-hand':'<circle cx="15.5" cy="5" r="3"/><path d="M15.5 3.5v3m-1.3-2.2h2.3M3 14h3l2.2-1.8c.6-.5 1.2-.7 2-.7h4.4c1.1 0 1.8.6 1.8 1.5s-.7 1.5-1.8 1.5H12M3 19h3l3.7 2h6c.8 0 1.6-.3 2.1-.8L21 17c1.1-1.2-.7-3.1-2-2l-3 2"/>',
    /* Daily collection: a coin deposited into a cash box. */
    'collection-daily':'<circle cx="12" cy="5" r="3"/><path d="M12 3.5v3m-1.3-2.2h2.3M12 9v2m-2-2 2 2 2-2M4 14h16v7H4zM3 14l2-3h14l2 3M9 17.5h6"/>'
  };

  const routeIcons={
    'invoice':'file-plus','history':'history','sale-return':'rotate-ccw','reversal-history':'history',
    'payment-history':'credit-card','daily-sale-summary':'chart-column','daily-cash-collection':'collection-daily',
    'real-invoice':'scan-line','ar-all':'receivable-all','ar-your':'receivable-one',
    'ar-payment-history':'credit-card','ar-daily-receivable-cash':'banknote',
    'sales-support-calculator':'calculator','sales-support-request-delivery':'truck',
    'sales-support-your-customer':'users','sales-support-add-customer':'user-plus',
    'sales-support-customer-map':'map-pin','sales-support-your-stock':'packages',
    'sales-support-batch-selling-tracker':'search','sales-support-your-collection':'collection-hand',
    'sales-support-your-invoices':'receipt','sales-support-your-receivable':'receivable-one',
    'sales-support-successful-delivery':'circle-check',
    'stock-control-allocation':'packages','stock-control-batch-transfer':'arrow-left-right',
    'stock-control-back-sale':'rotate-ccw','stock-keyin':'package','stock-damaged':'alert-triangle',
    'stock-damaged-report':'clipboard-list','stock-damaged-cleared':'circle-check',
    'stock-damaged-accounting':'calculator','stock-report':'warehouse','batch-report':'layers',
    'closed-batch':'archive','stock-transactions':'arrow-left-right',
    'stock-pending-borrow':'clipboard-list','stock-alerts':'bell',
    'monthly-sales-report':'chart-line','income-statement-report':'chart-column',
    'purchase-order-report':'receipt','cogs-daily':'tag','cogs-monthly':'chart-column',
    'expense-monthly-report':'chart-line','purchase-create':'shopping-cart',
    'purchase-history':'history','purchase-payable':'wallet','purchase-payment-history':'credit-card',
    'expense-add':'circle-dollar','expense-accrued':'clock','expense-history':'history',
    'daily-cash':'wallet','customers-add':'user-plus','customers-map':'map-pin',
    'customers-details':'users','clients-add':'building','clients-details':'building',
    'products-add':'plus','products-details':'package','master-expense-categories':'tag',
    'master-audit-center':'shield-check','staff-relation':'users',
    'admin-pending-receivable':'clipboard-check','admin-pending-daily-cash':'banknote',
    'admin-pending-deposit':'wallet','admin-deposit-history':'history',
    'admin-staff-request':'clipboard-list','admin-request':'clipboard-check',
    'admin-user-permissions':'shield-check','notification-center':'bell'
  };

  const groupIcons={
    'Sales Support':'clipboard-check','Sales':'receipt','Receivable':'wallet',
    'Stock Control':'packages','Stock':'warehouse','Reports':'chart-column',
    'Purchase':'shopping-cart','Expenses':'circle-dollar',
    'Master Data':'database','Admin Work':'shield-check','Company':'settings',
    'Other':'layers'
  };

  function tone(route){
    if(/^(ar-|real-invoice|sales-support-your-receivable|sales-support-your-collection)/.test(route))return 'teal';
    if(/^(stock-|batch-|closed-batch|cogs-|sales-support-your-stock)/.test(route))return 'indigo';
    if(/^(expense-|income-|monthly-|purchase-order-report|daily-sale-summary)/.test(route))return 'violet';
    if(/^(purchase-|clients-|products-|customers-|master-)/.test(route))return 'cyan';
    if(/^(admin-|notification-|stock-alerts)/.test(route))return 'amber';
    return 'blue';
  }
  function svg(icon,theme){
    const body=shapes[icon]||shapes['layers'];
    const safeTheme=/^(blue|teal|indigo|violet|cyan|amber)$/.test(theme)?theme:'blue';
    return '<svg class="bb-function-svg bb-ficon-'+safeTheme+'" width="24" height="24" '+
      'viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.85" '+
      'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">'+body+'</svg>';
  }
  function forRoute(route){
    const key=String(route||'');
    const icon=routeIcons[key]||(
      /invoice|receipt/i.test(key)?'receipt':
      /customer|staff|user/i.test(key)?'users':
      /stock|batch|transfer/i.test(key)?'package':
      /payment|bank/i.test(key)?'credit-card':
      /report|summary/i.test(key)?'chart-column':'layers'
    );
    return svg(icon,tone(key));
  }
  function forGroup(group){
    const key=String(group||'');
    const colors={
      'Receivable':'teal','Stock':'indigo','Stock Control':'indigo',
      'Reports':'violet','Purchase':'cyan','Expenses':'violet',
      'Admin Work':'amber','Company':'amber'
    };
    return svg(groupIcons[key]||'layers',colors[key]||'blue');
  }
  function named(icon){return svg(icon,'blue')}

  const style=document.createElement('style');
  style.id='bbMobileFunctionIconsStyle';
  style.textContent=
    '.bb-function-svg{display:inline-block;vertical-align:middle;flex:none;'+
      'width:24px;height:24px;pointer-events:none;stroke:currentColor}'+
    '.bb-ficon-blue{color:#1267b0}.bb-ficon-teal{color:#087f82}'+
    '.bb-ficon-indigo{color:#4f56ad}.bb-ficon-violet{color:#7a50b5}'+
    '.bb-ficon-cyan{color:#007aa2}.bb-ficon-amber{color:#b66f24}'+
    '#quickActions .quick-icon .bb-function-svg{width:25px;height:25px}'+
    '#menuGrid .menu-card b .bb-function-svg{width:27px;height:27px}'+
    '.bb-picker-icon .bb-function-svg{width:20px;height:20px}'+
    '.bb-dd-icon .bb-function-svg{width:19px;height:19px}'+
    '.bb-dd-left b .bb-function-svg{width:18px;height:18px}'+
    '.bottom-nav .nav-btn b .bb-function-svg{width:21px;height:21px}'+
    '.bb-function-svg *{vector-effect:non-scaling-stroke}';
  (document.head||document.documentElement).appendChild(style);

  window.BBMobileFunctionIconsV1=Object.freeze({
    route:forRoute,group:forGroup,named:named,
    routeNames:Object.freeze(Object.keys(routeIcons))
  });
})();