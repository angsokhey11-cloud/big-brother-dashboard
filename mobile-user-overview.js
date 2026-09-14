/* BIG BROTHER — Mobile Normal User Overview V1 */
(function(){
'use strict';

const SUPABASE_URL='https://sjfhlaclgmkwwofzstok.supabase.co';
const SUPABASE_KEY='sb_publishable_w762jR65CWwlO30fKQsYOw_6L9grx8S';
const SESSION_KEY='BB_SUPABASE_DEV_SESSION_V1';

let cached=null;
let loading=false;
let lastLoad=0;

const $=id=>document.getElementById(id);
const num=v=>Number(v||0)||0;
const money=v=>'$'+num(v).toLocaleString('en-US',{minimumFractionDigits:2,maximumFractionDigits:2});
const khr=v=>'៛'+Math.round(num(v)).toLocaleString('en-US');
const qty=v=>num(v).toLocaleString('en-US',{maximumFractionDigits:2});
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));

function readSession(){
  try{return JSON.parse(localStorage.getItem(SESSION_KEY)||'null')}catch(_){return null}
}
function saveSession(value){
  try{
    if(!value){localStorage.removeItem(SESSION_KEY);return}
    if(!value.expires_at&&value.expires_in)value.expires_at=Math.floor(Date.now()/1000)+Number(value.expires_in);
    localStorage.setItem(SESSION_KEY,JSON.stringify(value));
  }catch(_){}
}
async function parse(response){
  const text=await response.text();
  let data={};
  try{data=text?JSON.parse(text):{}}catch(_){data={message:text}}
  if(!response.ok)throw new Error(data.message||data.error_description||data.error||('Request failed ('+response.status+')'));
  return data;
}
async function refreshSession(){
  const current=readSession();
  if(!current?.refresh_token)throw new Error('Please sign in to BIG BROTHER.');
  const r=await fetch(SUPABASE_URL+'/auth/v1/token?grant_type=refresh_token',{
    method:'POST',
    headers:{apikey:SUPABASE_KEY,'Content-Type':'application/json'},
    body:JSON.stringify({refresh_token:current.refresh_token}),
    cache:'no-store'
  });
  const next=await parse(r);saveSession(next);return next;
}
async function rpc(fn,args={}){
  let session=readSession();
  if(!session?.access_token)throw new Error('Please sign in to BIG BROTHER.');
  if(session.expires_at&&Number(session.expires_at)<Math.floor(Date.now()/1000)+45){
    session=await refreshSession();
  }
  const request=token=>fetch(SUPABASE_URL+'/rest/v1/rpc/'+fn,{
    method:'POST',
    headers:{apikey:SUPABASE_KEY,Authorization:'Bearer '+token,'Content-Type':'application/json'},
    body:JSON.stringify(args||{}),
    cache:'no-store'
  });
  let r=await request(session.access_token);
  if(r.status===401){session=await refreshSession();r=await request(session.access_token)}
  return parse(r);
}

function homeVisible(){
  const home=$('mobileHome');
  return !!home&&!home.hidden;
}

function applyOverview(data){
  if(!data||!homeVisible())return;
  const grid=$('kpiGrid');
  if(!grid)return;

  const locations=Array.isArray(data.saleLocations)?data.saleLocations:[];
  const locationNames=locations.map(x=>x.locationName||x.locationCode).filter(Boolean);
  const locationValue=locations.length===0?'No Location':locations.length===1?(locationNames[0]||'1 Location'):locations.length+' Locations';
  const locationSub=locationNames.length?locationNames.join(' · '):'No assigned sale location';

  const ar=data.receivable||{};
  const stock=data.stock||{};
  const openBatches=Math.max(0,Math.round(num(stock.openBatchCount)));
  const physicalQty=num(stock.physicalQty);
  const actionCount=(()=>{
    const text=$('quickCount')?.textContent||'';
    const m=text.match(/\d+/);
    return m?Number(m[0]):0;
  })();

  const cards=[
    ['Sale Location',locationValue,locationSub],
    ['Receivable',money(ar.equivalentUSD),'USD '+money(ar.USD)+' · KHR '+khr(ar.KHR)],
    ['Stock Value',money(stock.valueUSD),openBatches+' assigned open batch'+(openBatches===1?'':'es')],
    ['Assigned Batch',String(openBatches),qty(physicalQty)+' remaining qty · '+actionCount+' quick actions']
  ];

  grid.innerHTML=cards.map(x=>'<div class="kpi"><small>'+esc(x[0])+'</small><strong>'+esc(x[1])+'</strong><em>'+esc(x[2])+'</em></div>').join('');
  if($('overviewTitle'))$('overviewTitle').textContent='My Overview';
  if($('periodLabel'))$('periodLabel').textContent='Live';
}

async function refresh(force=false){
  if(loading||!homeVisible()||!readSession()?.access_token)return;
  if(!force&&cached&&Date.now()-lastLoad<15000){applyOverview(cached);return}
  loading=true;
  try{
    const profile=await rpc('bb_current_access_profile');
    if(profile?.user?.isAdmin===true)return;
    const data=await rpc('bb_mobile_user_overview');
    cached=data;
    lastLoad=Date.now();
    applyOverview(data);
  }catch(error){
    console.warn('Mobile user overview:',error?.message||error);
  }finally{
    loading=false;
  }
}

function start(){
  const home=$('mobileHome');
  if(!home){setTimeout(start,100);return}
  const observer=new MutationObserver(()=>{
    if(homeVisible())setTimeout(()=>refresh(false),40);
  });
  observer.observe(home,{attributes:true,attributeFilter:['hidden']});
  window.addEventListener('focus',()=>refresh(false));
  if(homeVisible())refresh(true);
  window.BBMobileUserOverview={refresh:()=>refresh(true)};
}

if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});
else start();
})();
