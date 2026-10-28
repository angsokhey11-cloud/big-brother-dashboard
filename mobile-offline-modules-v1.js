/* BIG BROTHER — Offline Mobile Modules V1
 * Read-only cloud snapshots; Calculator writes ONLY local device history.
 * Uses already-authorized Supabase RPCs and user-scoped IndexedDB.
 */
(function(){
'use strict';
const offline=()=>window.BBMobileOfflineWorkspaceV1;
const SESSION_KEY='BB_SUPABASE_DEV_SESSION_V1';
const $=id=>document.getElementById(id);
const clean=v=>String(v??'').trim();
const num=v=>{const x=Number(v);return Number.isFinite(x)?x:0};
const money=(n,c='USD')=>c==='KHR'?'៛'+Math.round(num(n)).toLocaleString('en-US'):'$'+num(n).toLocaleString('en-US',{minimumFractionDigits:2,maximumFractionDigits:2});
const esc=v=>clean(v).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const mapRoutes={
  'ar-your':'offline-ar-your',
  'sales-support-your-receivable':'offline-ar-your',
  'ar-all':'offline-ar-all',
  'stock-report':'offline-stock-report',
  'sales-support-calculator':'offline-calc-bootstrap'
};
let host=null,route='',dataset=null,calcCustomer=null,calcPrices=null,calcLines=[],calcCurrency='USD',calcRate=4100,calcDiscount=0;
function currentId(){return offline()?.currentUserId()||''}
function historyKey(){return 'bb_sales_support_calc_history_v2_'+currentId()}
function currentKey(){return 'bb_sales_support_calc_current_v2_'+currentId()}
function stored(key,fallback){
  try{const v=JSON.parse(localStorage.getItem(key)||'null');return v??fallback}catch(_){return fallback}
}
function history(){const v=stored(historyKey(),[]);return Array.isArray(v)?v:[]}
function saveLocal(key,value){try{localStorage.setItem(key,JSON.stringify(value));return true}catch(_){return false}}
function canOpen(name){return !!mapRoutes[name]}
async function available(name){
  if(!canOpen(name)||!currentId())return false;
  const data=await offline()?.read(mapRoutes[name]);
  return !!data?.value;
}
function createHost(){
  if(host)return host;
  host=document.createElement('div');
  host.id='bbOfflineModulesScreen';
  host.style.cssText='position:fixed;inset:0;z-index:999999;background:#edf3fa;display:none;overflow:auto;color:#173e66;font-family:system-ui,-apple-system,"Segoe UI",sans-serif;';
  const style=document.createElement('style');
  style.textContent=`
    #bbOfflineModulesScreen .bb-off-header{position:sticky;top:0;z-index:3;padding:12px;background:#14528b;color:#fff;display:flex;gap:10px;align-items:center}
    #bbOfflineModulesScreen button,#bbOfflineModulesScreen select,#bbOfflineModulesScreen input{font:inherit}
    #bbOfflineModulesScreen button{cursor:pointer}
    #bbOfflineModulesScreen .bb-back{border:0;border-radius:9px;background:#ffffff29;color:#fff;padding:8px 14px;font-weight:900}
    #bbOfflineModulesScreen .bb-off-main{padding:14px;max-width:720px;margin:0 auto}
    #bbOfflineModulesScreen .bb-off-note{background:#e6f0fc;padding:11px 13px;border-radius:12px;font-size:12px;line-height:1.5;color:#315879;margin-bottom:12px}
    #bbOfflineModulesScreen .bb-off-card{background:#fff;padding:13px;border:1px solid #d7e3ee;border-radius:12px;margin:8px 0;box-shadow:0 2px 5px #00326008}
    #bbOfflineModulesScreen .bb-off-card strong{display:block;font-size:14px}
    #bbOfflineModulesScreen .bb-off-card small{display:block;color:#657d94;margin-top:4px}
    #bbOfflineModulesScreen .bb-off-data{display:grid;grid-template-columns:1fr auto;gap:7px;align-items:center}
    #bbOfflineModulesScreen .bb-off-data b{color:#1266a4}
    #bbOfflineModulesScreen input,#bbOfflineModulesScreen select{border:1px solid #c7d8e8;background:#fff;border-radius:9px;min-width:0;box-sizing:border-box;padding:11px;width:100%;font-size:14px}
    #bbOfflineModulesScreen .bb-off-form{display:grid;grid-template-columns:1fr 1fr;gap:8px}
    #bbOfflineModulesScreen .bb-off-form .wide{grid-column:1/-1}
    #bbOfflineModulesScreen .bb-off-primary{background:#1267af;color:#fff;border:0;border-radius:9px;padding:11px;font-weight:700}
    #bbOfflineModulesScreen .bb-off-muted{background:#ecf2fa;color:#23496d;border:1px solid #d2e0eb;border-radius:9px;padding:9px}
    #bbOfflineModulesScreen .bb-off-scroll{max-height:56vh;overflow:auto}
  `;
  document.head.appendChild(style);
  host.innerHTML='<header class="bb-off-header"><button type="button" class="bb-back" id="bbOffClose">‹ Back</button><strong id="bbOffTitle">Saved Data</strong></header><main class="bb-off-main"><div class="bb-off-note" id="bbOffNote"></div><div id="bbOffBody"></div></main>';
  document.body.appendChild(host);
  host.querySelector('#bbOffClose').addEventListener('click',close);
  return host;
}
function close(){
  if(host)host.style.display='none';
  route='';dataset=null;
}
function notice(message){const note=$('bbOffNote');if(note)note.textContent=message}
async function open(name){
  if(!canOpen(name))return false;
  // A local screen can open only for a permitted route whose snapshot was saved.
  const rec=await offline()?.read(mapRoutes[name]);
  if(!rec?.value)return false;
  route=name;
  dataset=rec.value;
  createHost().style.display='block';
  $('bbOffTitle').textContent=name.includes('receivable')||name.startsWith('ar-')?'Receivable · Offline':name.includes('calculator')?'Calculator · Offline':'Stock Report · Offline';
  const date=new Date(rec.syncedAt).toLocaleString('en-GB',{day:'2-digit',month:'short',year:'numeric',hour:'2-digit',minute:'2-digit'});
  notice('Saved snapshot: '+date+' · Cloud transactions cannot be created, cleared or edited offline.');
  if(name==='sales-support-calculator')renderCalculator();
  else if(name.includes('receivable')||name.startsWith('ar-'))renderReceivables();
  else renderStock();
  host.scrollTop=0;
  return true;
}
function renderReceivables(){
  const rows=Array.isArray(dataset?.receivables)?dataset.receivables:[];
  const wrap=$('bbOffBody');
  wrap.innerHTML='<div class="bb-off-card"><strong>'+rows.length+' outstanding invoices</strong><small>Saved values may have changed since synchronization</small></div>'+
    '<input id="bbOffSearch" placeholder="Search customer / invoice / location" type="search" aria-label="Search saved receivable">'+
    '<div id="bbOffRows" class="bb-off-scroll"></div>';
  function draw(){
    const q=clean($('bbOffSearch').value).toLowerCase();
    const found=rows.filter(r=>[r.customer,r.invoiceNo,r.locationName,r.locationCode].some(x=>clean(x).toLowerCase().includes(q)));
    $('bbOffRows').innerHTML=found.slice(0,500).map(r=>`<div class="bb-off-card bb-off-data"><div><strong>${esc(r.customer||'Unknown customer')}</strong><small>${esc(r.invoiceNo)} · ${esc(r.invoiceDate)} · ${esc(r.locationName||r.locationCode)} · ${esc(r.arStatus)}</small></div><b>${esc(money(r.outstanding,r.currency))}</b></div>`).join('')||'<div class="bb-off-card">No matching records in saved data.</div>';
  }
  $('bbOffSearch').addEventListener('input',draw);draw();
}
function renderStock(){
  const rows=Array.isArray(dataset?.products)?dataset.products:[];
  const wrap=$('bbOffBody'),total=dataset?.totals||{};
  wrap.innerHTML='<div class="bb-off-card"><strong>'+rows.length+' products</strong><small>Warehouse: '+esc(money(total.warehouseValue))+' · Saved stock snapshot</small></div>'+
    '<input id="bbOffSearch" placeholder="Search product / code" type="search" aria-label="Search saved stock">'+
    '<div id="bbOffRows" class="bb-off-scroll"></div>';
  function draw(){
    const q=clean($('bbOffSearch').value).toLowerCase();
    const filtered=rows.filter(r=>[r.productName,r.productCode].some(x=>clean(x).toLowerCase().includes(q)));
    $('bbOffRows').innerHTML=filtered.map(r=>`<div class="bb-off-card"><strong>${esc(r.productName)}</strong><small>${esc(r.productCode)} · ${esc(r.unit)}</small><div class="bb-off-data"><span>Warehouse ${esc(num(r.warehousePhysical))} · Batch ${esc(num(r.batchPhysical))} · Damaged ${esc(num(r.damaged))}</span><b>${esc(money(r.totalValue))}</b></div></div>`).join('')||'<div class="bb-off-card">No matching products.</div>';
  }
  $('bbOffSearch').addEventListener('input',draw);draw();
}
function selectCustomer(){
  const id=clean($('bbCalcCustomer').value);
  calcCustomer=(dataset.customers||[]).find(x=>clean(x.customerId)===id)||null;
  calcPrices=null;
  void offline()?.read('calc-price::'+id).then(rec=>{
    if(!route||route!=='sales-support-calculator'||clean($('bbCalcCustomer')?.value)!==id)return;
    calcPrices=rec?.value?.products||null;
    setCalculatorPrice();
  });
  setCalculatorPrice();
}
function setCalculatorPrice(){
  const code=clean($('bbCalcProduct')?.value);
  const product=(dataset.products||[]).find(x=>clean(x.code)===code);
  const price=(calcPrices||[]).find(p=>clean(p.productCode)===code);
  const selected=price?num(price.customerPriceUSD):num(product?.usdPrice||product?.priceUSD);
  if($('bbCalcPrice'))$('bbCalcPrice').value=String(selected||'');
  if($('bbCalcPriceInfo'))$('bbCalcPriceInfo').textContent=price?'Saved customer-specific price':'Default product price — verify customer agreement before use';
}
function renderCalculator(){
  const customers=Array.isArray(dataset.customers)?dataset.customers:[];
  const products=Array.isArray(dataset.products)?dataset.products:[];
  const state=stored(currentKey(),{});
  calcCurrency=state.currency==='KHR'?'KHR':'USD';
  calcRate=Math.max(1,num(state.rate)||4100);
  calcDiscount=Math.max(0,num(state.discountUSD));
  calcLines=Array.isArray(state.lines)?state.lines:[];
  $('bbOffBody').innerHTML=`
    <div class="bb-off-card"><strong>Local calculator</strong><small>Calculations and history stay on this device. This is an offline view; customer names/products use saved cloud data.</small></div>
    <div class="bb-off-card bb-off-form">
      <label class="wide">Customer<input id="bbCalcCustomerSearch" placeholder="Search saved customer..." autocomplete="off"></label>
      <label class="wide"><select id="bbCalcCustomer"><option value="">Select customer</option>${customers.slice(0,2000).map(c=>`<option value="${esc(c.customerId)}">${esc(c.name)} — ${esc(c.locationCode)}</option>`).join('')}</select></label>
      <label class="wide">Product<select id="bbCalcProduct"><option value="">Choose product</option>${products.map(p=>`<option value="${esc(p.code)}">${esc(p.name)} (${esc(p.unit)})</option>`).join('')}</select></label>
      <label>Quantity<input id="bbCalcQty" inputmode="decimal" type="number" min="0" step="any" value="1"></label>
      <label>Price USD<input id="bbCalcPrice" inputmode="decimal" type="number" min="0" step="any"></label>
      <small class="wide" id="bbCalcPriceInfo">Default product price</small>
      <button class="bb-off-primary wide" id="bbCalcAdd" type="button">+ Add Product</button>
    </div>
    <div class="bb-off-card"><strong>Calculation lines</strong><div id="bbCalcLines"></div></div>
    <div class="bb-off-card bb-off-form">
      <label>Currency<select id="bbCalcCurrency"><option>USD</option><option>KHR</option></select></label>
      <label>Exchange rate (KHR / USD)<input id="bbCalcRate" inputmode="decimal" type="number" min="1" step="any" value="${esc(calcRate)}"></label>
      <label class="wide">Discount USD<input id="bbCalcDiscount" inputmode="decimal" type="number" min="0" step="any" value="${esc(calcDiscount)}"></label>
      <div class="wide" id="bbCalcTotal"></div>
      <button class="bb-off-primary wide" id="bbCalcSave" type="button">Save to Device History</button>
    </div>
    <div class="bb-off-card"><strong>Saved History</strong><div id="bbCalcHistory"></div></div>`;
  $('bbCalcCustomer').value=clean(state.customerKey).replace(/^id:/,'');
  $('bbCalcCurrency').value=calcCurrency;
  $('bbCalcCustomerSearch').addEventListener('input',()=>{
    const q=clean($('bbCalcCustomerSearch').value).toLowerCase();
    const select=$('bbCalcCustomer');
    select.innerHTML='<option value="">Select customer</option>'+customers.filter(c=>[c.name,c.customerId,c.locationCode].some(x=>clean(x).toLowerCase().includes(q))).slice(0,150).map(c=>`<option value="${esc(c.customerId)}">${esc(c.name)} — ${esc(c.locationCode)}</option>`).join('');
    selectCustomer();drawCalc(true);
  });
  $('bbCalcCustomer').addEventListener('change',()=>{selectCustomer();drawCalc(true)});
  $('bbCalcProduct').addEventListener('change',setCalculatorPrice);
  $('bbCalcCurrency').addEventListener('change',()=>{calcCurrency=$('bbCalcCurrency').value;drawCalc(true)});
  $('bbCalcRate').addEventListener('input',()=>drawCalc(true));
  $('bbCalcDiscount').addEventListener('input',()=>drawCalc(true));
  $('bbCalcAdd').addEventListener('click',()=>{
    const code=clean($('bbCalcProduct').value),product=products.find(p=>clean(p.code)===code);
    const qty=num($('bbCalcQty').value),price=num($('bbCalcPrice').value);
    if(!product||qty<=0||price<0){alert('Choose a product with a valid quantity and price.');return}
    calcLines.push({id:'CALC-'+Date.now()+'-'+Math.random().toString(36).slice(2,7),
      productCode:code,productName:product.name,unit:product.unit,qty,usdPrice:price,defaultUsdPrice:num(product.usdPrice),manualPrice:true});
    drawCalc(true);
  });
  $('bbCalcSave').addEventListener('click',()=>{
    const snapshot=calcState();
    if(!snapshot.customerKey||!calcLines.length){alert('Select a customer and add at least one product.');return}
    const entry={...snapshot,id:'CALCH-'+Date.now()+'-'+Math.random().toString(36).slice(2,7),createdAt:Date.now()};
    const rows=[entry,...history()].slice(0,100);
    if(saveLocal(historyKey(),rows)){saveLocal(currentKey(),snapshot);drawCalc(true);alert('Saved locally on this device. No cloud invoice created.')}
    else alert('Local storage unavailable. The calculation was not saved.');
  });
  selectCustomer();drawCalc();
}
function calcState(){
  const customer=(dataset?.customers||[]).find(c=>clean(c.customerId)===clean($('bbCalcCustomer')?.value));
  return {savedAt:Date.now(),currency:calcCurrency,rate:Math.max(1,num($('bbCalcRate')?.value)||4100),
    discountUSD:Math.max(0,num($('bbCalcDiscount')?.value)),
    locationCode:clean(customer?.locationCode),customerKey:customer?.customerId?'id:'+clean(customer.customerId):'',customerName:clean(customer?.name),
    customerMapUrl:clean(customer?.googleMapsLink),lines:calcLines.map(x=>({...x}))};
}
function drawCalc(saveDraft=false){
  if(route!=='sales-support-calculator')return;
  const totals=calcLines.reduce((sum,p)=>sum+num(p.qty)*num(p.usdPrice),0);
  const discount=Math.max(0,num($('bbCalcDiscount').value));
  const rate=Math.max(1,num($('bbCalcRate').value)||4100);
  const grand=Math.max(0,totals-discount);
  $('bbCalcLines').innerHTML=calcLines.map((l,i)=>`<div class="bb-off-data" style="padding:7px 0;border-bottom:1px solid #e5edf4"><div><strong>${esc(l.productName)} · ${esc(l.qty)} × ${esc(money(l.usdPrice))}</strong><small>${esc(l.unit)} · ${esc(l.productCode)}</small></div><button class="bb-off-muted" data-remove="${i}">×</button></div>`).join('')||'<small>No products added yet.</small>';
  $('bbCalcLines').querySelectorAll('[data-remove]').forEach(btn=>btn.onclick=()=>{calcLines.splice(Number(btn.dataset.remove),1);drawCalc(true)});
  $('bbCalcTotal').innerHTML='<strong>Grand Total: '+esc(calcCurrency==='KHR'?money(grand*rate,'KHR'):money(grand))+'</strong><small>Subtotal USD '+esc(money(totals))+' · Discount USD '+esc(money(discount))+'</small>';
  $('bbCalcHistory').innerHTML=history().slice(0,25).map(h=>`<div class="bb-off-data" style="padding:8px 0;border-bottom:1px solid #e5edf4"><div><strong>${esc(h.customerName)}</strong><small>${esc(new Date(h.createdAt).toLocaleDateString('en-GB'))} · ${(h.lines||[]).length} items</small></div><button class="bb-off-muted" data-load-history="${esc(h.id)}">Open</button></div>`).join('')||'<small>No saved calculations.</small>';
  $('bbCalcHistory').querySelectorAll('[data-load-history]').forEach(btn=>btn.onclick=()=>{
    const entry=history().find(h=>h.id===btn.dataset.loadHistory);if(!entry)return;
    calcLines=Array.isArray(entry.lines)?entry.lines.map(x=>({...x})):[];
    $('bbCalcCustomer').value=clean(entry.customerKey).replace(/^id:/,'');
    $('bbCalcCurrency').value=calcCurrency=entry.currency==='KHR'?'KHR':'USD';
    $('bbCalcRate').value=entry.rate||4100;
    $('bbCalcDiscount').value=entry.discountUSD||0;
    selectCustomer();drawCalc(true);
  });
  // Opening the offline Calculator must never overwrite an existing draft.
  if(saveDraft)saveLocal(currentKey(),calcState());
}
function snapshotFor(key,data){
  if(!data?.success)return null;
  if(key==='offline-ar-your'||key==='offline-ar-all'){
    return {success:true,receivables:(Array.isArray(data.receivables)?data.receivables:[]).map(r=>({
      invoiceId:r.invoiceId,invoiceNo:r.invoiceNo,invoiceDate:r.invoiceDate,
      dueDate:r.dueDate,customer:r.customer,customerId:r.customerId,
      locationCode:r.locationCode,locationName:r.locationName,currency:r.currency,
      outstanding:r.outstanding,arStatus:r.arStatus
    }))};
  }
  if(key==='offline-stock-report'){
    return {success:true,products:(Array.isArray(data.products)?data.products:[]).map(r=>({
      productCode:r.productCode,productName:r.productName,unit:r.unit,
      warehousePhysical:r.warehousePhysical,batchPhysical:r.batchPhysical,
      damaged:r.damaged,totalValue:r.totalValue
    })),totals:{warehouseValue:data?.totals?.warehouseValue||0}};
  }
  if(key==='offline-calc-bootstrap'){
    return {success:true,customers:(Array.isArray(data.customers)?data.customers:[]).map(c=>({
      customerId:c.customerId,name:c.name,locationCode:c.locationCode,googleMapsLink:c.googleMapsLink
    })),products:(Array.isArray(data.products)?data.products:[]).map(p=>({
      code:p.code,name:p.name,unit:p.unit,usdPrice:p.usdPrice
    }))};
  }
  return null;
}
let syncing=false;
async function sync(safeRpc,canRoute,force=false){
  const api=offline();if(!api?.canUseNetwork()||!currentId()||syncing)return;
  const last=await api.read('offline-modules-last-sync');
  if(!force&&last?.value?.at&&Date.now()-last.value.at<30*60*1000)return;
  syncing=true;
  const jobs=[];
  if(canRoute('ar-your')||canRoute('sales-support-your-receivable')){
    jobs.push(['offline-ar-your','bb_ar_list']);
  }
  if(canRoute('ar-all'))jobs.push(['offline-ar-all','bb_ar_list_all']);
  if(canRoute('stock-report'))jobs.push(['offline-stock-report','bb_stock_report_fast']);
  if(canRoute('sales-support-calculator'))jobs.push(['offline-calc-bootstrap','bb_sales_support_bootstrap']);
  let allOK=true;
  try{
    // Make at most two concurrent read-only requests.
    for(let i=0;i<jobs.length;i+=2){
      if(!api.canUseNetwork())return;
      const group=jobs.slice(i,i+2);
      const fetched=await Promise.allSettled(group.map(([,fn])=>safeRpc(fn)));
      for(let j=0;j<group.length;j++){
        const value=fetched[j].status==='fulfilled'?fetched[j].value:null;
        const minimal=snapshotFor(group[j][0],value);
        if(minimal&&api.canUseNetwork())await api.write(group[j][0],minimal);
        else allOK=false;
      }
    }
    if(api.canUseNetwork())await api.write('offline-modules-last-sync',{at:Date.now(),allOK});
  }finally{syncing=false}
}
window.BBMobileOfflineModulesV1={open,canOpen,available,sync,close};
})();
