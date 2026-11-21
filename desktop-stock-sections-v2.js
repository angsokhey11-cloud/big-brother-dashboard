/* BIG BROTHER Desktop Stock Menu V2 — presentational sections only.
   Preserve existing route buttons, permission guards, event listeners, and
   Stock Report / Damaged Stock nested menus. */
(function(){
"use strict";

const sections=[
  {id:"operations",title:"Inventory Operations",elements:[
    "navStockKeyin","navStockAdjustment","navStockPendingBorrow","navStockTransactions"
  ],routes:[
    "stock-keyin","stock-adjustment","stock-pending-borrow","stock-transactions"
  ]},
  {id:"reports",title:"Reports & Monitoring",elements:[
    "stockReportNavGroup","navStockAlerts"
  ],routes:[
    "stock-report","batch-report","closed-batch","stock-alerts"
  ]},
  {id:"damage",title:"Damage Management",elements:[
    "damagedStockNavGroup"
  ],routes:[
    "stock-damaged","stock-damaged-report","stock-damaged-cleared","stock-damaged-accounting"
  ]}
];
const byRoute=new Map(sections.flatMap(group=>group.routes.map(route=>[route,group.id])));

function setExpanded(section,expanded){
  if(!section)return;
  const button=section.querySelector(":scope > .bb-stock-section-toggle");
  const content=section.querySelector(":scope > .bb-stock-section-body");
  if(!button||!content)return;
  button.setAttribute("aria-expanded",String(expanded));
  content.hidden=!expanded;
}

function expandStockParent(){
  const submenu=document.getElementById("stockSubmenu");
  const button=document.getElementById("stockMenuButton");
  submenu?.classList.add("open");
  if(button){
    button.classList.add("open");
    button.setAttribute("aria-expanded","true");
    const arrow=button.querySelector(".nav-arrow");
    if(arrow)arrow.textContent="▲";
  }
}

function showRouteSection(route){
  const sectionId=byRoute.get(route);
  if(!sectionId)return;
  const section=document.querySelector('#stockSubmenu > .bb-stock-section[data-stock-section="'+sectionId+'"]');
  if(!section)return;
  expandStockParent();
  setExpanded(section,true);

  // The existing nested menu code retains its own handlers and active state.
  // On a fresh URL reload, ensure the appropriate nested menu is visible.
  if(sectionId==="reports"&&["stock-report","batch-report","closed-batch"].includes(route)){
    const sub=document.getElementById("stockReportSubmenu");
    const button=document.getElementById("stockReportMenuButton");
    sub?.classList.add("open");
    button?.classList.add("open");
    button?.setAttribute("aria-expanded","true");
    const arrow=button?.querySelector(".nav-arrow");
    if(arrow)arrow.textContent="▲";
  }
  if(sectionId==="damage"){
    const sub=document.getElementById("damagedStockSubmenu");
    const button=document.getElementById("damagedStockMenuButton");
    sub?.classList.add("open");
    button?.classList.add("open");
    button?.setAttribute("aria-expanded","true");
    const arrow=button?.querySelector(".nav-arrow");
    if(arrow)arrow.textContent="▲";
  }
}

function install(){
  const root=document.getElementById("stockSubmenu");
  if(!root||root.dataset.bbStockSectionsV2==="1")return;
  const style=document.createElement("style");
  style.id="bbStockSectionsV2Style";
  style.textContent=`
  #stockSubmenu > .bb-stock-section{min-width:0;width:100%;margin:5px 0 0;border-top:1px solid rgba(177,205,235,.26);padding-top:5px}
  #stockSubmenu > .bb-stock-section:first-child{margin-top:2px}
  #stockSubmenu > .bb-stock-section > .bb-stock-section-toggle{display:flex!important;align-items:center;justify-content:space-between;width:100%;min-height:36px;padding:10px 8px!important;border:0;border-radius:7px;background:transparent;color:#b9d9f6;text-transform:uppercase;font-size:10px;font-weight:800;letter-spacing:.055em;line-height:1.35;cursor:pointer;text-align:left;gap:5px}
  #stockSubmenu > .bb-stock-section > .bb-stock-section-toggle:hover,
  #stockSubmenu > .bb-stock-section > .bb-stock-section-toggle:focus-visible{background:rgba(255,255,255,.09);color:white}
  #stockSubmenu .bb-stock-section-arrow{font-size:10px;flex:none;transition:transform .15s ease}
  #stockSubmenu .bb-stock-section-toggle[aria-expanded="true"] .bb-stock-section-arrow{transform:rotate(180deg)}
  #stockSubmenu .bb-stock-section-body{display:flex;flex-direction:column;gap:4px;min-width:0;width:100%;padding-top:2px}
  #stockSubmenu .bb-stock-section-body[hidden]{display:none!important}
  #stockSubmenu .bb-stock-section-body > button{display:block;width:100%}
  #stockSubmenu .bb-stock-section-body > .nested-nav-group{width:100%;min-width:0}
  `;
  document.head.appendChild(style);

  const containers=new Map();
  for(const config of sections){
    const section=document.createElement("div");
    section.className="bb-stock-section";
    section.dataset.stockSection=config.id;
    const button=document.createElement("button");
    button.type="button";
    button.className="bb-stock-section-toggle";
    button.setAttribute("aria-controls","bb-stock-section-"+config.id);
    button.setAttribute("aria-expanded","false");
    const name=document.createElement("span");
    name.textContent=config.title;
    const arrow=document.createElement("span");
    arrow.className="bb-stock-section-arrow";
    arrow.setAttribute("aria-hidden","true");
    arrow.textContent="▼";
    button.append(name,arrow);
    const body=document.createElement("div");
    body.className="bb-stock-section-body";
    body.id="bb-stock-section-"+config.id;
    body.hidden=true;
    button.addEventListener("click",()=>setExpanded(section,button.getAttribute("aria-expanded")!=="true"));
    section.append(button,body);
    root.append(section);
    containers.set(config.id,body);
  }

  // Move original nodes; do not clone/replace any functional element.
  // Their inline navigation, listeners and permission classes remain intact.
  for(const config of sections){
    const target=containers.get(config.id);
    for(const id of config.elements){
      const element=document.getElementById(id);
      if(element&&root.contains(element)&&element!==target)target.append(element);
    }
  }
  root.dataset.bbStockSectionsV2="1";

  const oldSetShellActive=window.setShellActive;
  if(typeof oldSetShellActive==="function"&&!oldSetShellActive.__bbStockSectionsV2){
    const enhanced=function(moduleName){
      const result=oldSetShellActive.apply(this,arguments);
      showRouteSection(moduleName);
      return result;
    };
    enhanced.__bbStockSectionsV2=true;
    window.setShellActive=enhanced;
  }

  // New dashboard sessions start with all sections collapsed. A deep link
  // only expands the section containing that exact authenticated route.
  const route=new URLSearchParams(location.search).get("module")||"";
  if(byRoute.has(route))showRouteSection(route);

  // Other Stock UI adapters can add a button after startup; retain a target
  // container for those original nodes without watching or rewriting routes.
}

if(document.readyState==="loading"){
  document.addEventListener("DOMContentLoaded",install,{once:true});
}else{
  install();
}
})();
