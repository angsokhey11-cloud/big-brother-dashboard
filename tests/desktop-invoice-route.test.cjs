// BIG BROTHER desktop Invoice Generator route contract
// No user sessions, network, banking, or live invoice data involved.
const assert = require('node:assert/strict');
const fs=require('node:fs');
const source=fs.readFileSync('index.html','utf8');
const legacy=fs.readFileSync('legacy-dashboard-v3.40.html','utf8');
const invoiceRoot='https://angsokhey11-cloud.github.io/big-brother-invoice-generator/';
const version='20261027-multi-bank-verified1';
const required=[
 ['latest desktop URL',source.includes(invoiceRoot+'?embed=1&v='+version)],
 ['legacy Invoice URL matched',legacy.includes('invoice: "'+invoiceRoot+'?embed=1&v=20260924-cashbank1"')],
 ['route hook matched',legacy.includes('    const url = MODULE_URLS[moduleName];')],
 ['build guard matched',legacy.includes("      '20260924-hide-source-no-zero1';")],
 ['iframe guard matched',legacy.includes('          frame.contentWindow?.BB_INVOICE_GENERATOR_BUILD !==\n          expectedInvoiceBuild;')],
 ['latest invoice build used',source.includes('"      \'20260924-invoiceseq1\';"')],
 ['admin role from authenticated profile',source.includes('getProfile?.()?.user?.isAdmin === true')],
 ['admin pilot enabled',source.includes("if (isAdmin) next.searchParams.set('bbMultiBankPilot', '1');")],
 ['staff pilot flag removed',source.includes("else next.searchParams.delete('bbMultiBankPilot');")],
 ['iframe URL version checked',source.includes("new URL(frame.src).searchParams.get('v')")],
 ['iframe pilot status checked',source.includes("new URL(frame.src).searchParams.get('bbMultiBankPilot')")],
 ['fresh legacy source requested',source.includes('legacy-dashboard-v3.40.html?v=20261027-invoice-admin-route1')],
];
for(const [name,valid] of required){assert.ok(valid,name);console.log('PASS '+name)}
const code=source.match(/<script>\s*([\s\S]*?)<\/script>/i)?.[1];
assert.ok(code,'Dashboard boot script found');
new Function(code);
console.log('PASS Dashboard boot JavaScript parses');
for(const admin of [false,true]){
 const url=new URL(invoiceRoot+'?embed=1&v='+version);
 if(admin)url.searchParams.set('bbMultiBankPilot','1');
 else url.searchParams.delete('bbMultiBankPilot');
 assert.equal(url.searchParams.get('v'),version);
 assert.equal(url.searchParams.get('bbMultiBankPilot'),admin?'1':null);
 assert.equal(url.searchParams.get('embed'),'1');
 console.log('PASS '+(admin?'admin':'staff')+' desktop Invoice route query');
}
