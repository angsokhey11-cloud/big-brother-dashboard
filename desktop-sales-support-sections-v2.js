/* BIG BROTHER — Desktop Sales Support Menu V2.
   Display-only organization; retain original buttons, handlers, and grants.
   Three independent collapsible groups, with deep-link Ctrl+R restoration. */
(function(){
"use strict";

const groups=[
  {id:"customer",title:"Sales & Customer Tools",buttons:[
    ["navSalesSupportCalculator","sales-support-calculator"],
    ["navSalesSupportYourCustomer","sales-support-your-customer"],
    ["navSalesSupportAddCustomer","sales-support-add-customer"],
    ["navSalesSupportCustomerMap","sales-support-customer-map"]
  ]},
  {id:"stock",title:"Stock & Batch Monitoring",buttons:[
    ["navSalesSupportYourStock","sales-support-your-stock"],
    ["navSalesSupportBatchSellingTracker","sales-support-batch-selling-tracker"]
  ]},
  {id:"records",title:"Collections & Sales Records",buttons:[
    ["navSalesSupportYourCollection","sales-support-your-collection"],
    ["navSalesSupportYourInvoices","sales-support-your-invoices"],
    ["navSalesSupportYourReceivable","sales-support-your-receivable"]
  ]}
];
const routeToGroup=new Map(),routeToButton=new Map(),buttonToRoute=new Map(),buttonToGroup=new Map();
for(const group of groups){
  for(const [buttonId,route] of group.buttons){
    routeToGroup.set(route,group.id);
    routeToButton.set(route,buttonId);
    buttonToRoute.set(buttonId,route);
    buttonToGroup.set(buttonId,group.id);
  }
}

function expandSection(section,expanded){
  if(!section)return;
  const toggle=section.querySelector(":scope > .bb-sales-section-toggle");
  const body=section.querySelector(":scope > .bb-sales-section-body");
  if(!toggle||!body)return;
  toggle.setAttribute("aria-expanded",String(expanded));
  body.hidden=!expanded;
}

function openMainMenu(){
  const sub=document.getElementById("salesSupportSubmenu");
  const toggle=document.getElementById("salesSupportMenuButton");
  sub?.classList.add("open");
  if(toggle){
    toggle.classList.add("open");
    toggle.setAttribute("aria-expanded","true");
    const arrow=toggle.querySelector(".nav-arrow");
    if(arrow)arrow.textContent="▲";
  }
}

function revealRoute(route){
  const groupId=routeToGroup.get(route);
  if(!groupId)return;
  const root=document.getElementById("salesSupportSubmenu");
  const section=root?.querySelector(':scope > .bb-sales-section[data-sales-section="'+groupId+'"]');
  if(!section)return;
  openMainMenu();
  expandSection(section,true);

  // Preserve existing selection logic. Only synchronize the highlight to a
  // confirmed URL route, never activate a function or bypass its permissions.
  const button=document.getElementById(routeToButton.get(route));
  if(!button||button.hidden||button.style.display==="none"||
     button.classList.contains("bb-auth-hidden")||button.classList.contains("bb-subperm-hidden"))return;
  document.querySelectorAll(".nav-submenu button.active,.shell-nav-link.active")
    .forEach(item=>item.classList.remove("active"));
  button.classList.add("active");
}

function currentRoute(){
  try{return new URLSearchParams(location.search).get("module")||""}
  catch(_){return ""}
}
function syncFromUrl(){
  const route=currentRoute();
  if(routeToGroup.has(route))revealRoute(route);
}

function install(){
  const root=document.getElementById("salesSupportSubmenu");
  if(!root||root.dataset.bbSalesSectionsV2==="1")return;

  const style=document.createElement("style");
  style.id="bbSalesSectionsV2Style";
  style.textContent=`
  #salesSupportSubmenu > .bb-sales-section{min-width:0;width:100%;margin:5px 0 0;border-top:1px solid rgba(177,205,235,.26);padding-top:5px}
  #salesSupportSubmenu > .bb-sales-section:first-of-type{margin-top:2px}
  #salesSupportSubmenu > .bb-sales-section > .bb-sales-section-toggle{display:flex!important;align-items:center;justify-content:space-between;width:100%;min-height:36px;padding:10px 8px!important;border:0;border-radius:7px;background:transparent;color:#b9d9f6;text-transform:uppercase;font-size:10px;font-weight:800;letter-spacing:.035em;line-height:1.4;cursor:pointer;text-align:left;gap:5px}
  #salesSupportSubmenu > .bb-sales-section > .bb-sales-section-toggle:hover,
  #salesSupportSubmenu > .bb-sales-section > .bb-sales-section-toggle:focus-visible{background:rgba(255,255,255,.09);color:#fff}
  #salesSupportSubmenu .bb-sales-section-arrow{font-size:10px;flex:none;transition:transform .15s ease}
  #salesSupportSubmenu .bb-sales-section-toggle[aria-expanded="true"] .bb-sales-section-arrow{transform:rotate(180deg)}
  #salesSupportSubmenu .bb-sales-section-body{display:flex;flex-direction:column;gap:4px;min-width:0;width:100%;padding-top:2px}
  #salesSupportSubmenu .bb-sales-section-body[hidden]{display:none!important}
  #salesSupportSubmenu .bb-sales-section-body > button{display:block;width:100%}
  `;
  document.head.appendChild(style);

  const bodies=new Map();
  for(const group of groups){
    const section=document.createElement("div");
    section.className="bb-sales-section";
    section.dataset.salesSection=group.id;
    const toggle=document.createElement("button");
    toggle.type="button";
    toggle.className="bb-sales-section-toggle";
    toggle.setAttribute("aria-expanded","false");
    toggle.setAttribute("aria-controls","bb-sales-section-"+group.id);
    const title=document.createElement("span");
    title.textContent=group.title;
    const arrow=document.createElement("span");
    arrow.className="bb-sales-section-arrow";
    arrow.setAttribute("aria-hidden","true");
    arrow.textContent="▼";
    toggle.append(title,arrow);
    const body=document.createElement("div");
    body.className="bb-sales-section-body";
    body.id="bb-sales-section-"+group.id;
    body.hidden=true;
    toggle.addEventListener("click",()=>expandSection(section,toggle.getAttribute("aria-expanded")!=="true"));
    section.append(toggle,body);
    root.append(section);
    bodies.set(group.id,body);
  }

  function moveOriginalButtons(){
    // Moving actual buttons (never replacing them) preserves event listeners,
    // existing routing, and Supabase staff permission classes.
    for(const group of groups){
      const body=bodies.get(group.id);
      for(const [buttonId] of group.buttons){
        const button=document.getElementById(buttonId);
        if(button&&root.contains(button)&&button.parentNode!==body)body.append(button);
      }
    }
  }
  moveOriginalButtons();
  root.dataset.bbSalesSectionsV2="1";

  // Keep late-inserted Sales Support buttons in their approved group. Watch
  // only direct children, not the entire Dashboard or nested DOM.
  const observer=new MutationObserver(mutations=>{
    if(!mutations.some(m=>[...m.addedNodes].some(node=>
      node.nodeType===1&&buttonToGroup.has(node.id))))return;
    moveOriginalButtons();
  });
  observer.observe(root,{childList:true});

  // Built-in Calculator and Your Customer call setShellActive; independent
  // module buttons use their own open() methods. Cover both navigation paths.
  const oldSetShellActive=window.setShellActive;
  if(typeof oldSetShellActive==="function"&&!oldSetShellActive.__bbSalesSectionsV2){
    const wrapped=function(moduleName){
      const result=oldSetShellActive.apply(this,arguments);
      if(routeToGroup.has(moduleName)){
        openMainMenu();
        const section=document.querySelector('#salesSupportSubmenu > .bb-sales-section[data-sales-section="'+routeToGroup.get(moduleName)+'"]');
        expandSection(section,true);
      }
      return result;
    };
    wrapped.__bbSalesSectionsV2=true;
    window.setShellActive=wrapped;
  }

  // The authenticated Sales Support adapter handles clicks at capture phase.
  // Check the saved URL after its handler returns, so denied actions cannot
  // be highlighted or made active just by clicking a visible button.
  root.addEventListener("click",event=>{
    const button=event.target?.closest?.("button");
    const route=buttonToRoute.get(button?.id);
    if(route)setTimeout(()=>{
      if(currentRoute()===route)revealRoute(route);
    },0);
  },true);

  // New visits: all three groups remain closed. Deep links: open precisely
  // the matching group, keeping other groups independently collapsible.
  syncFromUrl();
  window.addEventListener("popstate",syncFromUrl);
  document.getElementById("moduleFrame")?.addEventListener("load",syncFromUrl);
}

if(document.readyState==="loading"){
  document.addEventListener("DOMContentLoaded",install,{once:true});
}else install();
})();