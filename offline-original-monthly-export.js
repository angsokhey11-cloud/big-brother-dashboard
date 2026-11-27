(function(){
'use strict';
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const norm=v=>String(v??'').trim().toLocaleLowerCase();
const qty=v=>(Number(v)||0).toLocaleString('en-US',{maximumFractionDigits:6});
const months=['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
const mm=v=>{const m=String(v||'').match(/^(\d{4})-(\d{2})-(\d{2})$/);return m?`${m[3]}-${months[Number(m[2])-1]}-${m[1]}`:String(v||'')};
const slug=v=>String(v||'Product').replace(/[\\/:*?"<>|]/g,' ').replace(/\s+/g,' ').trim().slice(0,65)||'Product';
const back=()=>{try{return new Intl.DateTimeFormat('en-GB',{timeZone:'Asia/Phnom_Penh',year:'numeric',month:'short',day:'2-digit',hour:'2-digit',minute:'2-digit',hour12:false}).format(new Date())}catch(_){return new Date().toLocaleString()}};
const styleText=`
.bb-a4-sheet{box-sizing:border-box;display:flex;flex-direction:column;background:#fff;color:#1b2e46;font-family:Arial,'Noto Sans Khmer',sans-serif;overflow:hidden}
.bb-a4-sheet *{box-sizing:border-box}
.bb-a4-sheet .a4-head{flex:0 0 auto}
.bb-a4-sheet .a4-brand{font-size:18px;color:#173f77;font-weight:900;letter-spacing:.8px}
.bb-a4-sheet .a4-strap{font-size:8px;color:#64778b;margin-top:3px}
.bb-a4-sheet .a4-line{border-top:3px solid #173f77;margin:10px 0 12px}
.bb-a4-sheet h1{font-size:17px;color:#173f77;margin:0 0 10px}
.bb-a4-sheet .a4-meta{display:grid;grid-template-columns:1.1fr 1fr;gap:5px 12px;font-size:10px;line-height:1.35}
.bb-a4-sheet .a4-meta b{color:#315170}
.bb-a4-sheet .a4-member-list{background:#f2f7fd;border:1px solid #d9e7f5;border-radius:6px;padding:7px 9px;margin-top:10px;font-size:8px;line-height:1.45}
.bb-a4-sheet .a4-summary{display:flex;gap:8px;margin:10px 0}
.bb-a4-sheet .a4-summary .a4-stat{flex:1;background:#edf4fb;border:1px solid #d4e2f0;border-radius:6px;padding:9px 11px}
.bb-a4-sheet .a4-summary span{display:block;color:#60768c;font-size:8px;font-weight:900;text-transform:uppercase}
.bb-a4-sheet .a4-summary b{display:block;color:#173f77;font-size:16px;margin-top:4px}
.bb-a4-sheet .a4-title{font-size:10px;font-weight:800;margin:5px 0 9px}
.bb-a4-sheet .a4-body{flex:0 0 auto;min-height:0}
.bb-a4-sheet table{border-collapse:collapse;table-layout:fixed;width:100%;min-width:0!important;margin:0;font-family:Arial,'Noto Sans Khmer',sans-serif}
.bb-a4-sheet th{position:static!important;background:#e7f1fc;border:1px solid #cedce9;color:#173f77;white-space:normal;word-break:break-word;overflow-wrap:anywhere;font-size:8px;font-weight:900;padding:7px 4px;line-height:1.25;text-align:left}
.bb-a4-sheet td{border:1px solid #d5e0ec;color:#1b2e46;font-size:9px;padding:7px 4px;line-height:1.25;vertical-align:top;overflow-wrap:anywhere}
.bb-a4-sheet th.a4-num,.bb-a4-sheet td.a4-num{text-align:right;font-variant-numeric:tabular-nums}
.bb-a4-sheet td.a4-date{white-space:nowrap;font-weight:700}
.bb-a4-sheet td.a4-net{font-weight:900;color:#173f77}
.bb-a4-sheet .a4-footer{margin-top:auto;border-top:1px solid #cbd8e6;padding-top:8px;display:flex;justify-content:space-between;gap:10px;color:#5c7288;font-size:8px}
.bb-a4-sheet .a4-return-note{font-size:8px;color:#637b93;margin-top:8px}
.bb-a4-preview-backdrop{position:fixed;inset:0;z-index:999999;background:rgba(12,26,43,.8);overflow:auto;padding:16px}
.bb-a4-preview-dialog{max-width:1240px;margin:0 auto;background:#eef3f8;padding:16px;border-radius:12px}
.bb-a4-preview-head{display:flex;gap:12px;align-items:center;justify-content:space-between;flex-wrap:wrap;margin-bottom:10px}
.bb-a4-preview-head h2{margin:0;font-size:17px;color:#173f77}
.bb-a4-preview-head button{cursor:pointer;padding:9px 13px;border:1px solid #cbd8e8;background:white;color:#173f77;border-radius:8px;font-size:12px;font-weight:800}
.bb-a4-preview-images{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,450px),1fr));gap:14px}
.bb-a4-preview-page{background:#fff;padding:10px;border-radius:8px;box-shadow:0 2px 12px rgba(20,55,90,.12)}
.bb-a4-preview-page img{display:block;width:100%;height:auto}
.bb-a4-preview-page a{display:inline-block;background:#17457a;color:#fff;text-decoration:none;font-weight:800;padding:10px 13px;border-radius:7px;font-size:12px;margin:12px 0 2px}
@media(max-width:580px){.bb-a4-preview-backdrop{padding:6px}.bb-a4-preview-dialog{padding:8px}}
`;
const style=document.createElement('style');style.textContent=styleText;document.head.appendChild(style);
async function paint(payload){
 if(typeof window.html2canvas!=='function')throw new Error('A4 picture renderer is unavailable. Check your internet connection and reload the report.');
 const product=payload.product,filter=payload.filter||{},month=String(payload.month||'');
 const built=payload.render(payload.report,product,filter);
 if(!built.rows.length)throw new Error('No sales match the selected product, location, and dates.');
 const showReturns=Math.abs(Number(built.totals.returnQty)||0)>.0000001;
 const landscape=!!product.isGroup;
 const width=landscape?1123:794,height=landscape?794:1123;
 const padding=landscape?37:42;
 const candidates=built.rows,columns=product.isGroup?built.columns:[];
 const m=month.match(/^(\d{4})-(\d{2})$/);
 const period=m?months[Number(m[2])-1]+' '+m[1]:month;
 const place=filter.location?(candidates[0]?.locationName||filter.location):'All Locations';
 const from=filter.from||month+'-01';
 const lastDay=m?new Date(Date.UTC(Number(m[1]),Number(m[2]),0)).getUTCDate():31;
 const to=filter.to||month+'-'+String(lastDay).padStart(2,'0');
 const memberList=product.isGroup?columns.map(c=>esc(c.code)+' — '+esc(c.name)).join(' · '):'';
 const stats=[['Gross Qty',qty(built.totals.grossQty)],...(showReturns?[['Return Qty',qty(built.totals.returnQty)]]:[]),['Net Qty',qty(built.totals.netQty)]];
 const fixedCols=4+(showReturns?1:0);
 const allCols=fixedCols+columns.length;
 function colHeader(){
  const memberWidth=columns.length?Math.max(45,Math.floor((width-padding*2-(landscape?370:320))/columns.length)):0;
  return `<colgroup><col style="width:${landscape?83:100}px"><col style="width:${landscape?154:171}px"><col style="width:${landscape?67:90}px">${showReturns?`<col style="width:${landscape?62:85}px">`:''}<col style="width:${landscape?67:90}px">${columns.map(()=>`<col style="width:${memberWidth}px">`).join('')}</colgroup>
  <thead><tr><th>Date</th><th>Location</th><th class="a4-num">Gross Qty</th>${showReturns?'<th class="a4-num">Return Qty</th>':''}<th class="a4-num">Net Qty</th>${columns.map(c=>`<th class="a4-num" title="${esc(c.name)}">${esc(c.code)}</th>`).join('')}</tr></thead>`;
 }
 const rowHtml=r=>`<tr><td class="a4-date">${esc(mm(r.date))}</td><td>${esc(r.locationName)}</td><td class="a4-num">${qty(r.grossQty)}</td>${showReturns?`<td class="a4-num">${r.returnQty?qty(r.returnQty):'—'}</td>`:''}<td class="a4-num a4-net">${qty(r.netQty)}</td>${columns.map(c=>`<td class="a4-num">${r.byCode[norm(c.code)]?qty(r.byCode[norm(c.code)]):'—'}</td>`).join('')}</tr>`;
 const parent=document.createElement('div');
 parent.style.cssText='position:fixed;left:-100000px;top:0;z-index:-1;pointer-events:none';
 document.body.appendChild(parent);
 const pages=[];
 try{
  let start=0;
  while(start<candidates.length){
   const sheet=document.createElement('section');
   sheet.className='bb-a4-sheet';
   sheet.style.width=width+'px';sheet.style.height=height+'px';sheet.style.padding=padding+'px';
   sheet.innerHTML=`<header class="a4-head"><div class="a4-brand">BIG BROTHER</div><div class="a4-strap">Sales &amp; Accounting System</div><div class="a4-line"></div><h1>PRODUCT SOLD REPORT — BY DATE &amp; LOCATION</h1><div class="a4-meta">
    <div><b>Product:</b> ${esc(product.name)}</div><div><b>SKU / Group:</b> ${esc(product.code)}</div>
    <div><b>Month:</b> ${esc(period)}</div><div><b>Location:</b> ${esc(place)}</div>
    <div><b>Date range:</b> ${esc(mm(from))} to ${esc(mm(to))}</div><div><b>Generated:</b> ${esc(back())}</div>
   </div>${memberList?`<div class="a4-member-list"><b>Member SKUs: </b>${memberList}</div>`:''}
   <div class="a4-summary">${stats.map(([name,value])=>`<div class="a4-stat"><span>${esc(name)}</span><b>${esc(value)}</b></div>`).join('')}</div><div class="a4-title">Daily sales by selling location · ${candidates.length} row(s)</div></header>
   <div class="a4-body"><table>${colHeader()}<tbody></tbody></table></div><footer class="a4-footer"><span>BIG BROTHER · Quantity in ${esc(product.unit||'product units')} · ${esc(showReturns?'Returns on return date':'Sold quantities by invoice date')}</span><span class="a4-page-index"></span></footer>`;
   parent.appendChild(sheet);
   const body=sheet.querySelector('tbody'),table=sheet.querySelector('table'),head=sheet.querySelector('.a4-head'),foot=sheet.querySelector('.a4-footer');
   const allowance=height-2*padding-head.offsetHeight-foot.offsetHeight-14;
   let idx=start;
   while(idx<candidates.length){
     body.insertAdjacentHTML('beforeend',rowHtml(candidates[idx]));
     if(table.offsetHeight>allowance){
       if(idx===start){throw new Error('The grouped product has too many columns for an A4 image. Select a smaller group.');}
       body.lastElementChild.remove();
       break;
     }
     idx++;
   }
   if(idx===start)throw new Error('Unable to fit a row on A4 paper.');
   pages.push(sheet);
   start=idx;
  }
  if(document.fonts?.ready)await document.fonts.ready;
  // Fonts can alter row heights; never export a clipped page.
  for(let i=0;i<pages.length;i++){
    pages[i].querySelector('.a4-page-index').textContent='Page '+(i+1)+' of '+pages.length;
    const sheet=pages[i],table=sheet.querySelector('table');
    const allowance=height-2*padding-sheet.querySelector('.a4-head').offsetHeight-sheet.querySelector('.a4-footer').offsetHeight-14;
    if(table.offsetHeight>allowance)throw new Error('The report layout became too tall after loading fonts. Please retry or shorten the date range.');
  }
  const blobs=[];
  for(let i=0;i<pages.length;i++){
    const canvas=await window.html2canvas(pages[i],{backgroundColor:'#ffffff',scale:2,useCORS:true,logging:false,width,height,windowWidth:width,windowHeight:height,scrollX:0,scrollY:0});
    const blob=await new Promise((resolve,reject)=>canvas.toBlob(v=>v?resolve(v):reject(new Error('Unable to create PNG picture.')),'image/png'));
    blobs.push(blob);
  }
  return {blobs,files:blobs.map((_,i)=>slug(product.name)+' - '+slug(period)+' - A4'+(blobs.length>1?' - Page '+(i+1)+' of '+blobs.length:'')+'.png')};
 }finally{parent.remove()}
}
function downloadBlob(blob,file){
 const url=URL.createObjectURL(blob),a=document.createElement('a');
 a.href=url;a.download=file;document.body.appendChild(a);a.click();a.remove();
 setTimeout(()=>URL.revokeObjectURL(url),30000);
}
function viewer(out){
 const urls=out.blobs.map(blob=>URL.createObjectURL(blob));
 const el=document.createElement('div');el.className='bb-a4-preview-backdrop';
 el.innerHTML=`<div class="bb-a4-preview-dialog" role="dialog" aria-modal="true" aria-label="A4 picture preview"><div class="bb-a4-preview-head"><h2>A4 picture preview · ${out.blobs.length} page(s)</h2><button type="button" class="bb-a4-close">Close</button></div><div class="bb-a4-preview-images">${urls.map((src,i)=>`<div class="bb-a4-preview-page"><img src="${src}" alt="A4 report page ${i+1}"><a href="${src}" download="${esc(out.files[i])}">Download Page ${i+1}</a></div>`).join('')}</div></div>`;
 const close=()=>{el.remove();urls.forEach(url=>URL.revokeObjectURL(url));document.removeEventListener('keydown',onKey)};
 const onKey=e=>{if(e.key==='Escape')close()};
 el.querySelector('.bb-a4-close').addEventListener('click',close);
 el.addEventListener('click',e=>{if(e.target===el)close()});
 document.addEventListener('keydown',onKey);
 document.body.appendChild(el);
}
let busy=false;
async function doAction(action,payload){
 if(busy)return;
 busy=true;
 const trigger=payload.button;
 const original=trigger?.textContent;
 if(trigger){trigger.disabled=true;trigger.textContent='Preparing A4 picture…'}
 try{
   const out=await paint(payload);
   if(action==='download'&&out.blobs.length===1)downloadBlob(out.blobs[0],out.files[0]);
   else viewer(out);
 }catch(e){alert('A4 picture: '+(e?.message||e))}
 finally{busy=false;if(trigger){trigger.disabled=false;trigger.textContent=original}}
}
window.BBMonthlyDailyA4Export={
 preview(payload){return doAction('preview',payload)},
 download(payload){return doAction('download',payload)}
};
})();