/* Restore the selected Admin Work module after Ctrl+R. */
(function(){
"use strict";
function restore(){
 const params=new URLSearchParams(location.search);
 const moduleName=params.get("module")||"";
 if(!/^admin-[a-z0-9-]+$/.test(moduleName))return;
 const adminButton=document.getElementById("adminWorkMenuButton");
 const submenu=document.getElementById("adminWorkSubmenu");
 if(!adminButton||!submenu)return;
 submenu.classList.add("open");adminButton.classList.add("open");
 adminButton.setAttribute("aria-expanded","true");
 const arrow=adminButton.querySelector(".nav-arrow");if(arrow)arrow.textContent="▲";
 if(moduleName==="admin-bank-review"){
  const button=document.getElementById("navAdminBankReview");
  if(!button)return;
  button.closest(".bb-admin-section")?.querySelector(".bb-admin-section-toggle")?.click();
  button.click();
  return;
 }
 // The Dashboard core now restores standard Admin Work routes itself.
 const button=[...submenu.querySelectorAll("button")].find(b=>
  (b.getAttribute("onclick")||"").includes("'"+moduleName+"'"));
 const section=button?.closest(".bb-admin-section");
 const toggle=section?.querySelector(".bb-admin-section-toggle");
 if(toggle&&toggle.getAttribute("aria-expanded")!=="true")toggle.click();
}
if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",()=>setTimeout(restore,0),{once:true});
else setTimeout(restore,0);
})();