/* BIG BROTHER — Monthly Overview Dashboard V1 */
(function(){
'use strict';

const SUPABASE_URL='https://sjfhlaclgmkwwofzstok.supabase.co';
const SUPABASE_KEY='sb_publishable_w762jR65CWwlO30fKQsYOw_6L9grx8S';
const SESSION_KEY='BB_SUPABASE_DEV_SESSION_V1';
const COLORS=['#2f6fed','#22a06b','#ff9f1c','#ef5350','#7c4dce','#27a9c7','#f4c20d','#7f8c8d'];
let installed=false;

const $=id=>document.getElementById(id);
const num=v=>Number(v||0)||0;
const money=v=>'$'+num(v).toLocaleString('en-US',{minimumFractionDigits:2,maximumFractionDigits:2});
const qty=v=>num(v).toLocaleString('en-US',{maximumFractionDigits:2});
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const nativeAmount=(v,c)=>String(c||'USD').toUpperCase()==='KHR'?'៛'+Math.round(num(v)).toLocaleString('en-US'):money(v);

function readSession(){
  try{return window.BBDashboardAdapter?.getSession?.()||JSON.parse(localStorage.getItem(SESSION_KEY)||'null')}catch(_){return null}
}
function saveSession(s){try{localStorage.setItem(SESSION_KEY,JSON.stringify(s))}catch(_){}}
async function parseResponse(r){const t=await r.text();let d={};try{d=t?JSON.parse(t):{}}catch(_){d={message:t}}if(!r.ok)throw new Error(d.message||d.error_description||d.error||('Request failed ('+r.status+')'));return d}
async function freshSession(){
  let s=readSession();
  if(!s?.access_token)throw new Error('Please sign in to BIG BROTHER.');
  const now=Math.floor(Date.now()/1000);
  if(s.expires_at&&Number(s.expires_at)<now+45){
    if(!s.refresh_token)throw new Error('Session expired. Please sign in again.');
    const r=await fetch(SUPABASE_URL+'/auth/v1/token?grant_type=refresh_token',{method:'POST',headers:{apikey:SUPABASE_KEY,'Content-Type':'application/json'},body:JSON.stringify({refresh_token:s.refresh_token}),cache:'no-store'});
    s=await parseResponse(r);saveSession(s);
  }
  return s;
}
async function rpc(fn,args={}){
  let s=await freshSession();
  let r=await fetch(SUPABASE_URL+'/rest/v1/rpc/'+fn,{method:'POST',headers:{apikey:SUPABASE_KEY,Authorization:'Bearer '+s.access_token,'Content-Type':'application/json'},body:JSON.stringify(args),cache:'no-store'});
  if(r.status===401){s=await freshSession();r=await fetch(SUPABASE_URL+'/rest/v1/rpc/'+fn,{method:'POST',headers:{apikey:SUPABASE_KEY,Authorization:'Bearer '+s.access_token,'Content-Type':'application/json'},body:JSON.stringify(args),cache:'no-store'})}
  return parseResponse(r);
}

function styles(){
  if($('bbOverviewStyle'))return;
  const s=document.createElement('style');s.id='bbOverviewStyle';s.textContent=`
  .dashboard-home{background:#f1f6fb!important;padding:24px!important}
  .dashboard-home>.topbar{margin-bottom:14px!important}
  .bb-ov{max-width:1760px;margin:0 auto;color:#17324f}
  .bb-ov-monthbar{display:flex;align-items:center;justify-content:space-between;gap:14px;background:#fff;border:1px solid #d7e2ee;border-radius:14px;padding:12px 14px;margin-bottom:12px;box-shadow:0 6px 18px rgba(20,55,90,.05)}
  .bb-ov-monthbar strong{display:block;color:#17457a;font-size:13px}.bb-ov-monthbar span{display:block;margin-top:3px;color:#718398;font-size:10px}
  .bb-ov-monthctl{display:flex;align-items:end;gap:8px}.bb-ov-field label{display:block;font-size:8px;font-weight:900;text-transform:uppercase;color:#718398;margin-bottom:5px}.bb-ov-field input{height:38px;border:1px solid #cad8e7;border-radius:9px;padding:7px 10px;color:#17324f;background:#fff;font-weight:800}
  .bb-ov-btn{height:38px;border:0;border-radius:9px;padding:0 12px;background:#17457a;color:#fff;font-size:10px;font-weight:900;cursor:pointer}.bb-ov-btn:disabled{opacity:.55;cursor:wait}
  .bb-ov-kpis{display:grid;grid-template-columns:repeat(9,minmax(120px,1fr));gap:8px;margin-bottom:12px}
  .bb-ov-kpi{min-width:0;background:#fff;border:1px solid #d7e2ee;border-radius:12px;padding:11px;box-shadow:0 5px 16px rgba(20,55,90,.045);position:relative;overflow:hidden}
  .bb-ov-kpi:before{content:'';position:absolute;left:0;top:0;bottom:0;width:4px;background:var(--a,#2f6fed)}
  .bb-ov-kpi .i{font-size:16px}.bb-ov-kpi small{display:block;margin-top:5px;color:#65798e;font-size:7px;font-weight:900;text-transform:uppercase;line-height:1.3}.bb-ov-kpi strong{display:block;margin-top:5px;color:var(--a,#17457a);font-size:18px;white-space:nowrap}.bb-ov-kpi em{display:block;margin-top:4px;color:#8a9aab;font-style:normal;font-size:8px}
  .bb-ov-grid3{display:grid;grid-template-columns:1.25fr .9fr .9fr;gap:10px;margin-bottom:10px}.bb-ov-grid2{display:grid;grid-template-columns:1.45fr .75fr;gap:10px;margin-bottom:10px}
  .bb-ov-card{background:#fff;border:1px solid #d7e2ee;border-radius:14px;box-shadow:0 6px 20px rgba(20,55,90,.05);overflow:hidden;min-width:0}
  .bb-ov-head{display:flex;align-items:center;justify-content:space-between;gap:8px;padding:11px 13px;border-bottom:1px solid #e3eaf2}.bb-ov-head strong{color:#17457a;font-size:12px}.bb-ov-head span{font-size:8px;color:#8191a2}.bb-ov-link{border:1px solid #d4e2f1;background:#f6faff;color:#2b67aa;border-radius:8px;padding:6px 8px;font-size:8px;font-weight:900;cursor:pointer}
  .bb-ov-locbody{display:grid;grid-template-columns:210px 1fr;gap:12px;padding:14px;align-items:center}.bb-ov-pie{width:180px;height:180px;border-radius:50%;margin:auto;box-shadow:inset 0 0 0 1px rgba(0,0,0,.04);position:relative}.bb-ov-pie:after{content:'';position:absolute;inset:42px;border-radius:50%;background:#fff;box-shadow:0 0 0 1px #e3eaf2}.bb-ov-piecenter{position:absolute;inset:0;display:flex;z-index:1;align-items:center;justify-content:center;text-align:center;pointer-events:none}.bb-ov-piecenter div{font-size:8px;color:#718398}.bb-ov-piecenter strong{display:block;color:#17457a;font-size:13px;margin-top:2px}
  .bb-ov-legend{display:flex;flex-direction:column;gap:7px}.bb-ov-legrow{display:grid;grid-template-columns:10px minmax(90px,1fr) 82px 46px;gap:7px;align-items:center;font-size:9px}.bb-ov-dot{width:9px;height:9px;border-radius:50%}.bb-ov-legname{font-weight:800;color:#31506f;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.bb-ov-legamt{text-align:right;color:#17457a;font-weight:900}.bb-ov-legpct{text-align:right;color:#6f8195;font-weight:800}
  .bb-ov-perf{padding:14px}.bb-ov-perfrow{display:grid;grid-template-columns:95px 1fr 88px;gap:8px;align-items:center;margin:12px 0}.bb-ov-perfrow label{font-size:9px;font-weight:800;color:#60758b}.bb-ov-track{height:14px;border-radius:999px;background:#eaf0f6;overflow:hidden}.bb-ov-fill{height:100%;border-radius:999px;min-width:0}.bb-ov-perfrow b{text-align:right;color:#173f77;font-size:10px}
  .bb-ov-snap{padding:14px}.bb-ov-snapitem{margin-bottom:16px}.bb-ov-snapline{display:flex;justify-content:space-between;gap:10px;font-size:9px;color:#5e738a}.bb-ov-snapline strong{font-size:12px;color:#173f77}.bb-ov-snaptrack{height:15px;border-radius:5px;background:#e7edf4;overflow:hidden;margin-top:7px}.bb-ov-snapfill{height:100%}.bb-ov-diff{border-top:1px solid #e4ebf3;margin-top:8px;padding-top:11px;display:flex;justify-content:space-between;gap:10px;align-items:end}.bb-ov-diff small{color:#7d8ea0;font-size:8px}.bb-ov-diff strong{color:#18864b;font-size:16px}
  .bb-ov-activity{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:8px;padding:12px}.bb-ov-act{border:1px solid #e0e8f1;border-radius:10px;padding:10px;text-align:center;background:linear-gradient(135deg,var(--bg,#eef5ff),#fff)}.bb-ov-act .ic{font-size:19px}.bb-ov-act strong{display:block;margin-top:5px;color:#17457a;font-size:17px}.bb-ov-act span{display:block;margin-top:2px;color:#687c91;font-size:8px;font-weight:800}
  .bb-ov-attn{padding:4px 12px 10px}.bb-ov-attrow{display:grid;grid-template-columns:10px 1fr auto;gap:8px;align-items:center;padding:8px 0;border-bottom:1px solid #edf1f5;font-size:9px}.bb-ov-attrow:last-child{border-bottom:0}.bb-ov-attdot{width:8px;height:8px;border-radius:50%}.bb-ov-attrow strong{min-width:28px;text-align:center;padding:3px 7px;border-radius:999px;background:#f4f7fa;color:#17457a}
  .bb-ov-tablewrap{overflow:auto}.bb-ov-table{width:100%;border-collapse:collapse;min-width:760px}.bb-ov-table th,.bb-ov-table td{padding:8px 10px;border-bottom:1px solid #e8eef5;text-align:left;font-size:8px}.bb-ov-table th{background:#f7faff;color:#61758a;text-transform:uppercase;font-size:7px}.bb-ov-table .amt{text-align:right;font-weight:900;color:#173f77}.bb-ov-badge{display:inline-block;border-radius:999px;padding:3px 7px;background:#edf9f3;color:#18864b;font-weight:900}.bb-ov-badge.warn{background:#fff4e7;color:#a96d00}.bb-ov-badge.bad{background:#fff0ef;color:#b93730}
  .bb-ov-info{padding:8px 12px}.bb-ov-inforow{display:flex;justify-content:space-between;gap:12px;padding:8px 0;border-bottom:1px solid #e8eef5;font-size:9px}.bb-ov-inforow span{color:#6e8094}.bb-ov-inforow strong{color:#17457a;text-align:right}.bb-ov-note{margin:10px 0 2px;padding:9px;border-radius:9px;background:#edf5ff;color:#4f6f91;font-size:8px;line-height:1.45}
  .bb-ov-loading{padding:50px 20px;text-align:center;color:#17457a;font-weight:900}.bb-ov-error{margin-bottom:10px;padding:10px 12px;border:1px solid #efcaca;background:#fff1f1;color:#a5312b;border-radius:10px;font-size:10px;font-weight:800}
  @media(max-width:1450px){.bb-ov-kpis{grid-template-columns:repeat(5,minmax(125px,1fr))}.bb-ov-grid3{grid-template-columns:1.2fr 1fr}.bb-ov-grid3>.bb-ov-card:last-child{grid-column:1/-1}}
  @media(max-width:1000px){.bb-ov-kpis{grid-template-columns:repeat(3,minmax(130px,1fr))}.bb-ov-grid3,.bb-ov-grid2{grid-template-columns:1fr}.bb-ov-locbody{grid-template-columns:1fr}.bb-ov-activity{grid-template-columns:repeat(3,1fr)}}
  @media(max-width:650px){.dashboard-home{padding:12px!important}.bb-ov-monthbar{align-items:flex-start;flex-direction:column}.bb-ov-monthctl{width:100%}.bb-ov-field{flex:1}.bb-ov-field input{width:100%}.bb-ov-kpis{grid-template-columns:1fr 1fr}.bb-ov-activity{grid-template-columns:1fr 1fr}.bb-ov-legrow{grid-template-columns:10px minmax(70px,1fr) 70px 42px}}
  `;document.head.appendChild(s);
}

function layout(){
  const home=$('dashboardHome');if(!home)return false;
  const top=home.querySelector('.topbar');if(!top)return false;
  const title=top.querySelector('.page-title');const sub=top.querySelector('.page-subtitle');
  if(title)title.textContent='Monthly Overview';
  if(sub)sub.textContent='Monthly control center for BIG BROTHER.';
  Array.from(home.children).forEach(el=>{if(el!==top)el.remove()});
  const wrap=document.createElement('div');wrap.className='bb-ov';wrap.id='bbOverview';
  wrap.innerHTML=`
    <div class="bb-ov-monthbar"><div><strong>📊 Management Overview</strong><span>Monthly performance with current A/R, A/P and stock snapshots.</span></div><div class="bb-ov-monthctl"><div class="bb-ov-field"><label>Select Month</label><input id="bbOverviewMonth" type="month"></div><button id="bbOverviewRefresh" class="bb-ov-btn" type="button">Refresh</button></div></div>
    <div id="bbOverviewError" class="bb-ov-error" hidden></div>
    <div id="bbOverviewBody"><div class="bb-ov-loading">Loading monthly overview…</div></div>`;
  home.appendChild(wrap);
  const d=new Date();$('bbOverviewMonth').value=d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0');
  $('bbOverviewMonth').addEventListener('change',load);
  $('bbOverviewRefresh').addEventListener('click',load);
  return true;
}

function kpi(icon,label,value,accent,note){return `<div class="bb-ov-kpi" style="--a:${accent}"><div class="i">${icon}</div><small>${esc(label)}</small><strong>${esc(value)}</strong><em>${esc(note||'')}</em></div>`}
function pie(locations,total){
  const rows=[...(locations||[])].filter(x=>num(x.totalSaleUSD)>0).sort((a,b)=>num(b.totalSaleUSD)-num(a.totalSaleUSD));
  if(!rows.length)return '<div class="bb-ov-locbody"><div style="grid-column:1/-1;text-align:center;color:#7b8c9d;padding:45px 10px">No location sales for this month.</div></div>';
  let at=0;const seg=[];rows.forEach((x,i)=>{const p=total?num(x.totalSaleUSD)/total*100:0;seg.push(`${COLORS[i%COLORS.length]} ${at.toFixed(2)}% ${(at+p).toFixed(2)}%`);at+=p});
  const legend=rows.map((x,i)=>{const p=total?num(x.totalSaleUSD)/total*100:0;return `<div class="bb-ov-legrow"><span class="bb-ov-dot" style="background:${COLORS[i%COLORS.length]}"></span><span class="bb-ov-legname" title="${esc(x.locationName||x.locationCode)}">${esc(x.locationName||x.locationCode)}</span><span class="bb-ov-legamt">${money(x.totalSaleUSD)}</span><span class="bb-ov-legpct">${p.toFixed(1)}%</span></div>`}).join('');
  return `<div class="bb-ov-locbody"><div style="position:relative"><div class="bb-ov-pie" style="background:conic-gradient(${seg.join(',')})"></div><div class="bb-ov-piecenter"><div>Net Sales<strong>${money(total)}</strong></div></div></div><div class="bb-ov-legend">${legend}</div></div>`;
}
function perf(label,val,max,color){const pct=max>0?Math.max(0,Math.min(100,num(val)/max*100)):0;return `<div class="bb-ov-perfrow"><label>${esc(label)}</label><div class="bb-ov-track"><div class="bb-ov-fill" style="width:${pct.toFixed(2)}%;background:${color}"></div></div><b>${money(val)}</b></div>`}
function badge(status){const s=String(status||'').toLowerCase();const cls=s.includes('unpaid')||s.includes('overdue')?'bad':s.includes('partial')||s.includes('pending')?'warn':'';return `<span class="bb-ov-badge ${cls}">${esc(status||'-')}</span>`}
function recentRows(rows){return (rows||[]).map(x=>`<tr><td>${esc(x.tx_date)}</td><td>${esc(x.tx_type)}</td><td><b>${esc(x.ref_no)}</b></td><td>${esc(x.description||'-')}</td><td>${esc(x.party||'-')}</td><td class="amt">${esc(nativeAmount(x.amount,x.currency))}</td><td>${badge(x.status)}</td></tr>`).join('')||'<tr><td colspan="7" style="text-align:center;padding:20px;color:#7b8c9d">No transactions for this month.</td></tr>'}

function render(d){
  const m=d.monthly||{},s=d.currentSnapshot||{},loc=d.salesByLocation||[];
  const total=num(m.netSalesUSD),monthlyExpense=num(m.monthlyExpenseUSD),maxPerf=Math.max(total,num(m.cogsUSD),monthlyExpense,num(m.netProfitUSD),1);
  const maxSnap=Math.max(num(s.receivableUSD),num(s.payableUSD),1),diff=num(s.receivableUSD)-num(s.payableUSD);
  const arPct=num(s.receivableUSD)/maxSnap*100,apPct=num(s.payableUSD)/maxSnap*100;
  $('bbOverviewBody').innerHTML=`
    <section class="bb-ov-kpis">
      ${kpi('🛒','Gross Sales',money(m.grossSalesUSD),'#2f6fed',d.periodLabel)}
      ${kpi('📊','Net Sales',money(m.netSalesUSD),'#18864b',d.periodLabel)}
      ${kpi('💳','Monthly Expense',money(m.monthlyExpenseUSD),'#d64f62','All expense types')}
      ${kpi('📦','COGS',money(m.cogsUSD),'#e98716','Monthly cost of goods')}
      ${kpi('🧾','Operating Expense',money(m.operatingExpenseUSD),'#7652c8','Operating only')}
      ${kpi('💰','Net Profit',money(m.netProfitUSD),'#15965b',d.periodLabel)}
      ${kpi('👥','Accounts Receivable',money(s.receivableUSD),'#2f6fed','Current snapshot')}
      ${kpi('🚚','Accounts Payable',money(s.payableUSD),'#e34b4b','Current snapshot')}
      ${kpi('📦','Stock Value',money(s.stockValueUSD),'#7652c8','Current purchased stock')}
    </section>
    <section class="bb-ov-grid3">
      <div class="bb-ov-card"><div class="bb-ov-head"><strong>📊 Sales by Location</strong><button class="bb-ov-link" onclick="window.BBCompanyFeatures?.open('monthly-sales-report')">View Details</button></div>${pie(loc,total)}</div>
      <div class="bb-ov-card"><div class="bb-ov-head"><strong>📈 Monthly Performance</strong><button class="bb-ov-link" onclick="window.BBCompanyFeatures?.open('income-statement-report')">View Report</button></div><div class="bb-ov-perf">${perf('Net Sales',m.netSalesUSD,maxPerf,'#2f6fed')}${perf('COGS',m.cogsUSD,maxPerf,'#ff9f1c')}${perf('Expense',m.monthlyExpenseUSD,maxPerf,'#ef5350')}${perf('Net Profit',m.netProfitUSD,maxPerf,'#22a06b')}</div></div>
      <div class="bb-ov-card"><div class="bb-ov-head"><strong>↔️ Receivable vs Payable</strong><span>Current snapshot</span></div><div class="bb-ov-snap"><div class="bb-ov-snapitem"><div class="bb-ov-snapline"><span>Accounts Receivable</span><strong>${money(s.receivableUSD)}</strong></div><div class="bb-ov-snaptrack"><div class="bb-ov-snapfill" style="width:${arPct}%;background:#2f6fed"></div></div></div><div class="bb-ov-snapitem"><div class="bb-ov-snapline"><span>Accounts Payable</span><strong>${money(s.payableUSD)}</strong></div><div class="bb-ov-snaptrack"><div class="bb-ov-snapfill" style="width:${apPct}%;background:#ef5350"></div></div></div><div class="bb-ov-diff"><div><small>A/R − A/P Difference</small><strong style="color:${diff>=0?'#18864b':'#b93730'}">${money(diff)}</strong></div><small>${diff>=0?'More receivables than payables':'More payables than receivables'}</small></div></div></div>
    </section>
    <section class="bb-ov-grid2">
      <div class="bb-ov-card"><div class="bb-ov-head"><strong>📋 Monthly Activity</strong><span>${esc(d.periodLabel)}</span></div><div class="bb-ov-activity"><div class="bb-ov-act" style="--bg:#eaf3ff"><div class="ic">🧾</div><strong>${qty(m.invoiceCount)}</strong><span>Invoices</span></div><div class="bb-ov-act" style="--bg:#eaf8f0"><div class="ic">🛒</div><strong>${qty(m.purchaseCount)}</strong><span>Purchases</span></div><div class="bb-ov-act" style="--bg:#f4edff"><div class="ic">👥</div><strong>${qty(m.customerCount)}</strong><span>Customers with Sales</span></div><div class="bb-ov-act" style="--bg:#fff6df"><div class="ic">🏢</div><strong>${qty(m.supplierCount)}</strong><span>Suppliers Used</span></div><div class="bb-ov-act" style="--bg:#eaf4ff"><div class="ic">🏬</div><strong>${qty(m.salesLocationCount)}</strong><span>Sales Locations</span></div></div></div>
      <div class="bb-ov-card"><div class="bb-ov-head"><strong>⚠️ Attention Needed</strong><span>Current</span></div><div class="bb-ov-attn"><div class="bb-ov-attrow"><span class="bb-ov-attdot" style="background:#ef5350"></span><span>Overdue customer invoices</span><strong>${qty(s.overdueARCount)}</strong></div><div class="bb-ov-attrow"><span class="bb-ov-attdot" style="background:#ff9f1c"></span><span>Unpaid supplier invoices</span><strong>${qty(s.payableCount)}</strong></div><div class="bb-ov-attrow"><span class="bb-ov-attdot" style="background:#f4c20d"></span><span>Low-stock alerts</span><strong>${qty(s.lowStockAlerts)}</strong></div><div class="bb-ov-attrow"><span class="bb-ov-attdot" style="background:#2f6fed"></span><span>Pending staff requests</span><strong>${qty(s.pendingStaffRequests)}</strong></div></div></div>
    </section>
    <section class="bb-ov-grid2">
      <div class="bb-ov-card"><div class="bb-ov-head"><strong>🕘 Recent Transactions (${esc(d.periodLabel)})</strong><span>Latest 6</span></div><div class="bb-ov-tablewrap"><table class="bb-ov-table"><thead><tr><th>Date</th><th>Type</th><th>Ref No.</th><th>Description</th><th>Party</th><th style="text-align:right">Amount</th><th>Status</th></tr></thead><tbody>${recentRows(d.recentTransactions)}</tbody></table></div></div>
      <div class="bb-ov-card"><div class="bb-ov-head"><strong>ℹ️ System Info</strong><span>Overview</span></div><div class="bb-ov-info"><div class="bb-ov-inforow"><span>Selected Month</span><strong>${esc(d.periodLabel)}</strong></div><div class="bb-ov-inforow"><span>Active Locations</span><strong>${qty(s.activeLocationCount)}</strong></div><div class="bb-ov-inforow"><span>Current Stock Qty</span><strong>${qty(s.stockQty)}</strong></div><div class="bb-ov-inforow"><span>Last Updated</span><strong>${esc(d.generatedAt||'-')}</strong></div><div class="bb-ov-note">Monthly cards use the selected month. A/R, A/P, stock and attention items are current live snapshots.</div></div></div>
    </section>`;
}

async function load(){
  const e=$('bbOverviewError'),b=$('bbOverviewBody'),btn=$('bbOverviewRefresh');if(!e||!b)return;
  e.hidden=true;e.textContent='';btn.disabled=true;btn.textContent='Loading…';b.innerHTML='<div class="bb-ov-loading">Loading monthly overview…</div>';
  try{const [y,m]=String($('bbOverviewMonth').value||'').split('-').map(Number);if(!y||!m)throw new Error('Please choose a month.');const d=await rpc('bb_dashboard_monthly_overview',{p_year:y,p_month:m});render(d)}catch(err){e.textContent=err?.message||String(err);e.hidden=false;b.innerHTML=''}finally{btn.disabled=false;btn.textContent='Refresh'}
}

function ready(){
  if(installed)return;
  const p=window.BBDashboardAdapter?.getProfile?.();
  if(!p){setTimeout(ready,120);return}
  if(!p.user?.isAdmin)return;
  installed=true;styles();if(layout())load();
}

if(document.readyState==='loading')window.addEventListener('DOMContentLoaded',()=>setTimeout(ready,80));else setTimeout(ready,80);
})();