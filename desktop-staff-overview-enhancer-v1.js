/* BIG BROTHER — PC Staff Overview Shortcuts + Staff Relation Earnings V1
 * Desktop only. Presentation and local preference layer; never grants permissions.
 */
(function(){
'use strict';

var ORDER_PREFIX='bb_pc_staff_quick_order_v1::';
var arranging=false, draggedRoute='';
var earningCache=null, earningLoading=false, lastEarningAt=0;

function el(id){return document.getElementById(id);}
function profile(){return window.BBDashboardAdapter&&window.BBDashboardAdapter.getProfile&&window.BBDashboardAdapter.getProfile();}
function session(){
  try{return (window.BBDashboardAdapter&&window.BBDashboardAdapter.getSession&&window.BBDashboardAdapter.getSession())||
    JSON.parse(localStorage.getItem('BB_SUPABASE_DEV_SESSION_V1')||'null');}catch(_){return null;}
}
function account(){
  var s=session(),p=profile()||{};
  return String((s&&s.user&&s.user.id)||(p.user&&(p.user.userId||p.user.id))||'').trim();
}
function storageKey(){var a=account();return a?ORDER_PREFIX+a:'';}
function staffRelationAllowed(){
  var p=profile();
  if(!p)return false;
  if(p.user&&p.user.isAdmin)return true;
  return (Array.isArray(p.modules)?p.modules:[]).some(function(x){
    var k=String(x.moduleKey||'').trim().toLowerCase();
    return x.canView===true&&(k==='route.staff-relation'||k==='*');
  });
}
function cards(grid){return Array.from(grid.querySelectorAll(':scope > .bb-staff-action[data-bb-staff-route]'));}
function readOrder(){
  var key=storageKey();
  if(!key)return [];
  try{var v=JSON.parse(localStorage.getItem(key)||'[]');return Array.isArray(v)?v:[];}catch(_){return [];}
}
function saveOrder(){
  var grid=el('bbStaffQuickWorkGrid'),key=storageKey();
  if(!grid||!key)return;
  try{localStorage.setItem(key,JSON.stringify(cards(grid).map(function(c){return c.dataset.bbStaffRoute;})));}catch(_){}
}
function applyOrder(grid){
  var saved=readOrder();
  if(!saved.length)return;
  var all=cards(grid),byRoute=new Map();
  all.forEach(function(c){byRoute.set(c.dataset.bbStaffRoute,c);});
  var ordered=[];
  saved.forEach(function(route){
    var c=byRoute.get(route);
    if(c){ordered.push(c);byRoute.delete(route);}
  });
  byRoute.forEach(function(c){ordered.push(c);});
  ordered.forEach(function(c){grid.appendChild(c);});
}
function toolState(){
  var grid=el('bbStaffQuickWorkGrid'),arrangeBtn=el('bbStaffQuickArrangeBtn'),resetBtn=el('bbStaffQuickResetBtn');
  if(grid){
    grid.classList.toggle('bb-pc-arranging',arranging);
    cards(grid).forEach(function(c){c.draggable=arranging; c.setAttribute('aria-label',c.querySelector('strong')?.textContent+(arranging?' — use arrow keys or drag to arrange':''));});
  }
  if(arrangeBtn){arrangeBtn.textContent=arranging?'Done':'Arrange';arrangeBtn.setAttribute('aria-pressed',String(arranging));}
  if(resetBtn)resetBtn.hidden=!arranging;
}
function toggleArrange(){
  arranging=!arranging;
  if(!arranging)saveOrder();
  toolState();
}
function resetOrder(){
  var grid=el('bbStaffQuickWorkGrid'),key=storageKey();
  if(key)try{localStorage.removeItem(key);}catch(_){}
  arranging=false;
  if(grid)cards(grid).sort(function(a,b){return Number(a.dataset.bbDefaultIndex)-Number(b.dataset.bbDefaultIndex);})
    .forEach(function(c){grid.appendChild(c);});
  toolState();
}
function installDrag(grid){
  if(grid.dataset.bbPcDragReady)return;
  grid.dataset.bbPcDragReady='1';

  grid.addEventListener('click',function(e){
    if(arranging&&e.target.closest('.bb-staff-action')){
      e.preventDefault();e.stopImmediatePropagation();e.stopPropagation();
    }
  },true);

  grid.addEventListener('dragstart',function(e){
    var card=e.target.closest('.bb-staff-action[data-bb-staff-route]');
    if(!arranging||!card){e.preventDefault();return;}
    draggedRoute=card.dataset.bbStaffRoute;
    card.classList.add('bb-pc-dragging');
    if(e.dataTransfer){e.dataTransfer.effectAllowed='move';e.dataTransfer.setData('text/plain',draggedRoute);}
  });
  grid.addEventListener('dragover',function(e){
    if(!arranging||!draggedRoute)return;
    var target=e.target.closest('.bb-staff-action[data-bb-staff-route]');
    if(!target||target.dataset.bbStaffRoute===draggedRoute)return;
    var moving=cards(grid).find(function(c){return c.dataset.bbStaffRoute===draggedRoute;});
    if(!moving)return;
    e.preventDefault();
    var bounds=target.getBoundingClientRect();
    grid.insertBefore(moving,e.clientX<bounds.left+bounds.width/2?target:target.nextSibling);
  });
  grid.addEventListener('drop',function(e){
    if(arranging&&draggedRoute){e.preventDefault();saveOrder();}
  });
  grid.addEventListener('dragend',function(){
    cards(grid).forEach(function(c){c.classList.remove('bb-pc-dragging');});
    if(arranging)saveOrder();
    draggedRoute='';
  });
  grid.addEventListener('keydown',function(e){
    if(!arranging||!['ArrowLeft','ArrowRight','ArrowUp','ArrowDown'].includes(e.key))return;
    var card=e.target.closest('.bb-staff-action[data-bb-staff-route]');
    if(!card)return;
    var ordered=cards(grid),idx=ordered.indexOf(card);
    var backward=e.key==='ArrowLeft'||e.key==='ArrowUp';
    var to=idx+(backward?-1:1);
    if(to<0||to>=ordered.length)return;
    e.preventDefault();
    if(backward)grid.insertBefore(card,ordered[to]);
    else grid.insertBefore(card,ordered[to].nextSibling);
    card.focus();saveOrder();
  });
}
function installTools(grid){
  var panel=grid.closest('.bb-ov-card'),head=panel&&panel.querySelector('.bb-ov-head');
  if(!head)return;
  var group=head.querySelector('.bb-pc-quick-tools');
  if(!group){
    group=document.createElement('div');
    group.className='bb-pc-quick-tools';
    var reset=document.createElement('button');
    reset.id='bbStaffQuickResetBtn';reset.type='button';reset.className='bb-pc-quick-tool';
    reset.textContent='Reset';reset.hidden=true;reset.addEventListener('click',resetOrder);
    var arrange=document.createElement('button');
    arrange.id='bbStaffQuickArrangeBtn';arrange.type='button';arrange.className='bb-pc-quick-tool bb-pc-quick-primary';
    arrange.textContent='Arrange';arrange.addEventListener('click',toggleArrange);
    group.appendChild(reset);group.appendChild(arrange);head.appendChild(group);
  }
}
function installStyles(){
  if(el('bbPcStaffOverviewStyle'))return;
  var style=document.createElement('style');style.id='bbPcStaffOverviewStyle';
  style.textContent=
    '.bb-staff-kpis{grid-template-columns:repeat(6,minmax(125px,1fr))}'+
    '.bb-pc-quick-tools{display:flex;gap:7px;align-items:center;margin-left:auto}'+
    '.bb-pc-quick-tool{border:1px solid #bad1e9;border-radius:8px;background:#f3f8ff;color:#17457a;font-size:10px;font-weight:900;padding:7px 11px;cursor:pointer}'+
    '.bb-pc-quick-tool.bb-pc-quick-primary{background:#245b96;color:white;border-color:#245b96}'+
    '.bb-pc-quick-tool[hidden]{display:none!important}'+
    '.bb-staff-actions.bb-pc-arranging .bb-staff-action{cursor:grab;border-style:dashed;position:relative;padding-right:28px}'+
    '.bb-staff-actions.bb-pc-arranging .bb-staff-action:after{content:"↕";position:absolute;right:10px;top:11px;font-size:19px;color:#7d93ac}'+
    '.bb-staff-actions .bb-staff-action.bb-pc-dragging{opacity:.52;border-color:#2f6fed}'+
    '.bb-staff-actions.bb-pc-arranging .bb-staff-action:focus-visible{outline:3px solid #2f6fed;outline-offset:2px}'+
    '.bb-staff-kpi.bb-pc-earning-unavailable strong{font-size:15px;color:#7b8b9a}'+
    '@media(max-width:1450px){.bb-staff-kpis{grid-template-columns:repeat(3,minmax(150px,1fr))}}'+
    '@media(max-width:900px){.bb-staff-kpis{grid-template-columns:repeat(2,minmax(135px,1fr))}.bb-ov-head:has(.bb-pc-quick-tools){flex-wrap:wrap}}';
  document.head.appendChild(style);
}
function money(v){return '$'+(Number(v)||0).toLocaleString('en-US',{minimumFractionDigits:2,maximumFractionDigits:2});}
function khr(v){return Math.round(Number(v)||0).toLocaleString('en-US');}
function presentEarning(){
  var card=el('bbPcStaffEarningCard');
  if(!card)return;
  var val=card.querySelector('strong'),note=card.querySelector('em');
  var allowed=staffRelationAllowed();
  var current=earningCache&&earningCache.account===account()?earningCache:null;
  if(!allowed){
    val.textContent='—';note.textContent='Staff Relation access required';card.classList.add('bb-pc-earning-unavailable');
  }else if(current&&current.loaded){
    val.textContent=money(current.usd);
    note.textContent=current.count+' available earning'+(current.count===1?'':'s')+(current.khr>0?' · KHR '+khr(current.khr):'');
    card.classList.remove('bb-pc-earning-unavailable');
  }else{
    val.textContent=current&&current.error?'Unavailable':'Loading…';
    note.textContent=current&&current.error?'Unable to refresh earnings':'Available earnings from Staff Relation';
    card.classList.toggle('bb-pc-earning-unavailable',!!(current&&current.error));
  }
  card.classList.toggle('clickable',allowed);
  card.setAttribute('role',allowed?'button':'group');
  if(allowed)card.setAttribute('tabindex','0');else card.removeAttribute('tabindex');
}
function addEarningCard(){
  var grid=document.querySelector('#bbOverviewBody .bb-staff-kpis');
  if(!grid||el('bbPcStaffEarningCard'))return;
  var card=document.createElement('div');
  card.id='bbPcStaffEarningCard';card.className='bb-staff-kpi';card.style.setProperty('--a','#bd8d34');
  card.innerHTML='<div class="ic">👛</div><small>Your Earning</small><strong>Loading…</strong><em>Available earnings from Staff Relation</em>';
  function open(){
    if(staffRelationAllowed()&&window.BBCompanyFeatures&&typeof window.BBCompanyFeatures.open==='function'){
      window.BBCompanyFeatures.open('staff-relation');
    }
  }
  card.addEventListener('click',open);
  card.addEventListener('keydown',function(e){if(e.key==='Enter'||e.key===' '){e.preventDefault();open();}});
  grid.appendChild(card);presentEarning();
}
async function refreshEarning(){
  var user=account();
  if(!user||!staffRelationAllowed()||earningLoading||Date.now()-lastEarningAt<18000)return;
  earningLoading=true;lastEarningAt=Date.now();
  try{
    var payment=await window.BBMonthlyOverview.staffEarnings();
    if(user!==account())return;
    var rows=Array.isArray(payment&&payment.available)?payment.available:[];
    var usd=0,kh=0;
    rows.forEach(function(row){
      if(String(row.currency||'USD').toUpperCase()==='KHR')kh+=Number(row.amount)||0;
      else if(String(row.currency||'USD').toUpperCase()==='USD')usd+=Number(row.amount)||0;
    });
    earningCache={account:user,loaded:true,count:rows.length,usd:usd,khr:kh};
  }catch(error){
    console.warn('Desktop Your Earning:',error&&error.message||error);
    if(user===account()&&(!earningCache||earningCache.account!==user||!earningCache.loaded)){
      earningCache={account:user,error:true};
    }
  }finally{earningLoading=false;presentEarning();}
}
function enhance(){
  var body=el('bbOverviewBody'),grid=body&&body.querySelector('.bb-staff-actions');
  if(!grid||!body.querySelector('.bb-staff-kpis'))return;
  installStyles();
  grid.id='bbStaffQuickWorkGrid';
  Array.from(grid.querySelectorAll(':scope > .bb-staff-action')).forEach(function(card,index){
    var code=card.getAttribute('onclick')||'';
    var match=code.match(/openShortcut\('([a-z0-9-]+)'\)/);
    if(!match)return;
    card.dataset.bbStaffRoute=match[1];
    card.dataset.bbDefaultIndex=String(index);
  });
  applyOrder(grid);
  installTools(grid);installDrag(grid);toolState();
  addEarningCard();presentEarning();
  refreshEarning();
}
window.BBStaffDesktopEnhancer={enhance:enhance};
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',enhance);else enhance();
})();
