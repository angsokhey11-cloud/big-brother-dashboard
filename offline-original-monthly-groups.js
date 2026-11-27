(function registerMonthlyGroups(){
 'use strict';
 const cols=['grossQty','returnQty','netQty','grossSalesUSD','returnsUSD','totalSaleUSD'];
 const norm=x=>String(x??'').trim().toLocaleLowerCase();
 const asNum=x=>Number(x)||0;
 function combine(rows,groups){
   const sold=Array.isArray(rows)?rows:[];
   const configs=Array.isArray(groups)?groups:[];
   const assigned=new Set(),out=[];
   for(const g of configs){
     const code=String(g.groupCode||'').trim();
     if(!code)continue;
     const codes=new Set([code,...(Array.isArray(g.memberCodes)?g.memberCodes:[])].map(norm));
     const members=sold.filter(r=>!assigned.has(r)&&codes.has(norm(r.code)));
     if(!members.length)continue;
     members.forEach(x=>assigned.add(x));
     members.sort((a,b)=>norm(a.code)===norm(code)?-1:norm(b.code)===norm(code)?1:(a.name||a.code).localeCompare(b.name||b.code));
     const units=new Set(members.map(x=>norm(x.unit)).filter(Boolean));
     const mixedUnits=units.size>1;
     const group={code,name:String(g.groupName||code),unit:mixedUnits?'Mixed units':(members.find(x=>x.unit)?.unit||''),isGroup:true,mixedUnits,memberRows:members};
     for(const k of cols)group[k]=members.reduce((sum,x)=>sum+asNum(x[k]),0);
     const places=new Set();
     for(const m of members)for(const loc of (m.byLocation||m.locations||[]))places.add(norm(loc.code||loc.name));
     group.locationCount=places.size;
     out.push(group);
   }
   for(const r of sold)if(!assigned.has(r))out.push(r);
   return out.sort((a,b)=>(a.name||a.code).localeCompare(b.name||b.code,undefined,{numeric:true}));
 }
 function matches(item,q){
   const key=norm(q);
   if(!key)return true;
   return [item,...(item.memberRows||[])].some(p=>[p.code,p.name,p.unit].map(norm).join(' ').includes(key));
 }
 function desktopCard(p,R){
   const e=R.esc,m=R.money,q=R.qty;
   const textQty=v=>p.mixedUnits?'By SKU':q(v);
   const members=p.memberRows.map(item=>{
     const locations=(item.byLocation||[]).slice().sort((a,b)=>asNum(b.totalSaleUSD)-asNum(a.totalSaleUSD));
     return `<details class="bb-family-member"><summary><span><b>${e(item.name)}</b><small>${e(item.code)} · ${e(item.unit||'—')} · Gross ${q(item.grossQty)} · Returns ${q(item.returnQty)} · Net ${q(item.netQty)}</small></span><strong>${m(item.totalSaleUSD)} ▾</strong></summary><div class="tablewrap"><table><thead><tr><th>Location</th><th class="qty">Gross Qty</th><th class="qty">Returns</th><th class="qty">Net Qty</th><th class="money">Net Sales USD</th></tr></thead><tbody>${locations.map(l=>`<tr><td>${e(l.name)} (${e(l.code)})</td><td class="qty">${q(l.grossQty)}</td><td class="qty">${q(l.returnQty)}</td><td class="qty">${q(l.netQty)}</td><td class="money"><b>${m(l.totalSaleUSD)}</b></td></tr>`).join('')}</tbody></table></div></details>`;
   }).join('');
   return `<details class="monthly-product-card bb-family"><summary><div class="bb-family-heading"><span class="bb-family-badge">ACTIVE PRODUCT GROUP</span><div class="monthly-product-name">${e(p.name)}</div><div class="monthly-product-code">${e(p.code)} · ${p.memberRows.length} sold SKUs · ${p.locationCount} locations · ${e(p.unit||'—')}</div></div><div class="monthly-product-metrics"><div class="monthly-product-metric"><small>Gross Qty</small><strong>${textQty(p.grossQty)}</strong></div><div class="monthly-product-metric"><small>Returns</small><strong>${textQty(p.returnQty)}</strong></div><div class="monthly-product-metric"><small>Net Qty</small><strong>${textQty(p.netQty)}</strong></div><div class="monthly-product-metric"><small>Net Sales USD</small><strong>${m(p.totalSaleUSD)}</strong></div></div><span class="monthly-product-expand">SKU details ▾</span></summary><div class="monthly-product-detail"><h3>Sold SKU breakdown · Gross USD ${m(p.grossSalesUSD)} · Returns USD ${m(p.returnsUSD)}${p.mixedUnits?' · Mixed units, see each SKU':''}</h3>${members}</div></details>`;
 }
 function mobileCard(p,fmt){
   const {esc:e,qty:q,money:m}=fmt;
   const quantity=v=>p.mixedUnits?'By SKU':q(v);
   const members=p.memberRows.map(item=>`<details class="bb-mobile-member"><summary><strong>${e(item.name)}</strong><small>${e(item.code)} · ${e(item.unit||'—')} · Gross ${q(item.grossQty)} · Returns ${q(item.returnQty)} · Net ${q(item.netQty)}</small><b>Net Sales ${m(item.totalSaleUSD)} ▾</b></summary><div class="bb-mobile-member-locations">${(item.locations||[]).slice().sort((a,b)=>asNum(b.totalSaleUSD)-asNum(a.totalSaleUSD)).map(l=>`<div class="m-location-line"><b>${e(l.name)}</b> <span>${e(l.code)}</span><div class="grid"><div class="mini"><small>Gross Qty</small><strong>${q(l.grossQty)}</strong></div><div class="mini"><small>Returns</small><strong>${q(l.returnQty)}</strong></div><div class="mini"><small>Net Sales</small><strong>${m(l.totalSaleUSD)}</strong></div></div></div>`).join('')}</div></details>`).join('');
   return `<details class="m-product-card bb-mobile-family"><summary><span class="bb-family-badge">ACTIVE PRODUCT GROUP</span><div class="m-product-name">${e(p.name)}</div><div class="p-code">${e(p.code)} · ${p.memberRows.length} sold SKUs · ${p.locationCount} locations</div><div class="grid"><div class="mini"><small>Gross Qty</small><strong>${quantity(p.grossQty)}</strong></div><div class="mini"><small>Returns</small><strong>${quantity(p.returnQty)}</strong></div><div class="mini"><small>Net Qty</small><strong>${quantity(p.netQty)}</strong></div><div class="mini"><small>Gross USD</small><strong>${m(p.grossSalesUSD)}</strong></div><div class="mini"><small>Returns USD</small><strong>${m(p.returnsUSD)}</strong></div><div class="mini"><small>Net Sales USD</small><strong>${m(p.totalSaleUSD)}</strong></div></div><div class="m-product-expand">Show sold SKU details ▾</div></summary><div class="m-location-breakdown"><strong>Sold SKUs${p.mixedUnits?' (quantities by unit)':''}</strong>${members}</div></details>`;
 }
 const style=document.createElement('style');
 style.textContent=`
 .bb-family{border-color:#b9d0eb}.bb-family>summary{background:#f7fbff}
 .bb-family-heading{min-width:155px;flex:0 1 235px}
 .bb-family-badge{display:inline-block;color:#245c96;background:#e8f2ff;border:1px solid #bed4eb;border-radius:6px;padding:4px 6px;font-size:8px;font-weight:900;margin-bottom:5px}
 .bb-family-member{border:1px solid #dce7f2;border-radius:9px;margin:7px 0;overflow:hidden;background:#fff}
 .bb-family-member>summary{list-style:none;display:flex;justify-content:space-between;gap:8px;padding:11px;cursor:pointer;align-items:center}
 .bb-family-member>summary::-webkit-details-marker{display:none}
 .bb-family-member b{font-size:11px;color:#173f77}
 .bb-family-member small{display:block;color:#647c93;font-size:9px;margin-top:4px}
 .bb-family-member>summary>strong{font-size:11px;color:#173f77;white-space:nowrap}
 .bb-family-member .tablewrap{padding:0 11px 12px}
 .bb-family-member table{min-width:630px}
 .bb-mobile-family{border-color:#b9d0eb}.bb-mobile-family>summary{background:#f7fbff}
 .bb-mobile-member{border:1px solid #e1e9f2;border-radius:9px;background:#fff;margin-top:8px;overflow:hidden}
 .bb-mobile-member>summary{display:block;list-style:none;cursor:pointer;padding:10px}
 .bb-mobile-member>summary::-webkit-details-marker{display:none}
 .bb-mobile-member>summary>strong{display:block;font-size:10px;line-height:1.4;color:#173f77}
 .bb-mobile-member small{display:block;color:#677d93;font-size:8px;margin-top:4px}
 .bb-mobile-member>summary>b{display:block;color:#173f77;font-size:10px;margin-top:6px}
 .bb-mobile-member-locations{border-top:1px solid #e1e9f2;background:#fbfcff;padding:0 10px 10px}
 @media(max-width:650px){.bb-family-member>summary{display:block}.bb-family-member>summary>strong{display:block;margin-top:7px}}
 `;
 document.head.appendChild(style);
 window.BBMonthlyProductFamilies={combine,matches,desktopCard,mobileCard};
})();
