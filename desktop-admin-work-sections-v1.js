/* BIG BROTHER Admin Work — independent collapsible sections, closed by default. */
(function(){
"use strict";
const definitions=[
 {id:"payments",title:"Payment Approvals",ids:["navAdminPendingReceivable","navAdminPendingDeposit","navAdminPendingDepositStage","navAdminDepositHistory"]},
 {id:"staff",title:"Staff & Management",ids:["navAdminStaffRequest","navAdminRequest","navAdminManagementControl","navAdminSystemActivity"]},
 {id:"system",title:"System & Communication",ids:["navAdminNotificationCenter","navAdminTelegramManager","navAdminUserPermissions"]},
 {id:"bank",title:"Bank Management",ids:["navAdminBankRegister","navAdminBankHistory","navAdminBankReview"]}
];
function install(){
 const root=document.getElementById("adminWorkSubmenu");
 if(!root||root.dataset.bbGrouped==="1")return;
 const original=[...root.children].filter(x=>x.matches("button"));
 if(!original.length)return;
 const style=document.createElement("style");
 style.textContent=`
 #adminWorkSubmenu .bb-admin-section{margin:5px 0;border-top:1px solid rgba(177,205,235,.25);padding-top:5px}
 #adminWorkSubmenu .bb-admin-section-toggle{display:flex;align-items:center;justify-content:space-between;width:100%;border:0;background:transparent;color:#b9d9f6;font-size:10px;font-weight:800;letter-spacing:.08em;text-transform:uppercase;padding:11px 10px;cursor:pointer;text-align:left}
 #adminWorkSubmenu .bb-admin-section-toggle:hover,#adminWorkSubmenu .bb-admin-section-toggle:focus-visible{background:rgba(255,255,255,.09);border-radius:7px;color:#fff}
 #adminWorkSubmenu .bb-admin-section-arrow{font-size:11px;transition:transform .15s ease}
 #adminWorkSubmenu .bb-admin-section-toggle[aria-expanded="true"] .bb-admin-section-arrow{transform:rotate(180deg)}
 #adminWorkSubmenu .bb-admin-section-body[hidden]{display:none!important}
 #adminWorkSubmenu .bb-admin-section-body>button{display:block;width:100%}
 `;
 document.head.appendChild(style);
 const sections=new Map();
 for(const def of definitions){
  const wrap=document.createElement("div");wrap.className="bb-admin-section";wrap.dataset.section=def.id;
  const toggle=document.createElement("button");toggle.type="button";toggle.className="bb-admin-section-toggle";
  toggle.setAttribute("aria-expanded","false");toggle.setAttribute("aria-controls","bb-admin-section-"+def.id);
  const title=document.createElement("span");title.textContent=def.title;
  const arrow=document.createElement("span");arrow.className="bb-admin-section-arrow";arrow.textContent="▼";
  toggle.append(title,arrow);
  const body=document.createElement("div");body.className="bb-admin-section-body";body.id="bb-admin-section-"+def.id;body.hidden=true;
  toggle.addEventListener("click",()=>{const open=toggle.getAttribute("aria-expanded")!=="true";toggle.setAttribute("aria-expanded",String(open));body.hidden=!open;});
  wrap.append(toggle,body);root.appendChild(wrap);sections.set(def.id,body);
 }
 const byId=new Map(definitions.flatMap(d=>d.ids.map(id=>[id,d.id])));
 for(const button of original){
  const label=(button.textContent||"").toLowerCase();
  const group=byId.get(button.id)||
   (/bank|transaction|payer/i.test(label)?"bank":/telegram|notification|permission/i.test(label)?"system":/receivable|deposit|cash/i.test(label)?"payments":"staff");
  sections.get(group).appendChild(button);
 }
 root.dataset.bbGrouped="1";
 // Opening Admin Work itself never expands its sections; users choose each group.
}
if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",install,{once:true});
else install();
})();
