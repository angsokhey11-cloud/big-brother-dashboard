// BIG BROTHER Local Brain V5/V6 — admin multi-bank migration contract.
// No DB connections, no live data writes.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const crypto=require('node:crypto');
const path=require('node:path');
const migrationsDir=path.resolve(__dirname,'../local-db-migrations');
const file='20261027_multi_bank_admin_pilot_local_v1.sql';
const data=fs.readFileSync(path.join(migrationsDir,file));
const sql=data.toString('utf8');
const registry=JSON.parse(fs.readFileSync(path.join(migrationsDir,'manifest.json'),'utf8'));
const record=registry.migrations.find(x=>x.id==='20261027_multi_bank_admin_pilot_local_v1');
assert.ok(record,'Code Sync migration must be registered');
assert.equal(record.file,file,'Registered SQL filename must match');
assert.equal(record.sha256,crypto.createHash('sha256').update(data).digest('hex').toUpperCase(),
 'V3.4 Code Sync checksum must match exact SQL bytes');
assert.equal(registry.migrations.at(-1).id,record.id,'Multi-bank migration must follow bank partial-use migration');
assert.ok(registry.migrations.some(x=>x.id==='20261025_c_bank_partial_use_cloud_parity_v1'),
 'The required Local partial-use bank migration must come first');
for(const [reason,pattern] of [
 ['fail-closed prerequisite check',/LOCAL_MULTI_BANK_SAFE_STOP/],
 ['vetted existing partial bank guard',/private\.bb_bank_guard_payment\(\)/],
 ['Cloud invoice save core',/bb_sales_save_invoice_bundle_core_access_v1/],
 ['atomic allocation reconciliation',/Missing bank allocation after invoice save/],
 ['Source/amount double-check',/Multi-bank allocation source or amount mismatch/],
 ['admin-only SQL authorization',/Multi-bank invoice pilot is Admin-only/],
 ['registered transfer bank metadata fallback',/v_fallback_bank/],
 ['two transfer minimum',/Select between 2 and 30 registered bank transactions/],
 ['Cloud and Local-only record safety',/No business rows altered|no business rows altered|NO INSERT\/UPDATE\/DELETE/],
 ['RLS',/alter table public\.bb_invoice_multi_bank_requests enable row level security/],
 ['anonymous RPC denied',/REVOKE ALL ON FUNCTION public\.bb_sales_save_invoice_multi_bank_v1\(jsonb,jsonb\)[\s\S]*?FROM public,anon,authenticated/],
 ['authenticated pilot grant',/GRANT EXECUTE ON FUNCTION public\.bb_sales_save_invoice_multi_bank_v1\(jsonb,jsonb\)[\s\S]*?TO authenticated/],
 ['installed privilege verifier',/LOCAL_MULTI_BANK_VERIFY_FAIL/],
 ['nonunique prior payment index precheck',/unique payment transaction index blocks partial bank reuse/]
]){
 assert.match(sql,pattern,reason);
 console.log('PASS '+reason);
}
for(const statement of [
 /\bTRUNCATE\s+/i,
 /\bDROP\s+(?:TABLE|SCHEMA|DATABASE)\b/i,
 /\bDELETE\s+FROM\s+public\./i,
 /\bUPDATE\s+public\.(?:invoices|payments|bb_verified_bank_transactions)\b/i,
 /\bCREATE\s+OR\s+REPLACE\s+FUNCTION\s+private\.bb_bank_guard_payment/i,
 /\bCREATE\s+OR\s+REPLACE\s+VIEW\s+public\.bb_bank_balance_snapshot/i
]) assert.doesNotMatch(sql,statement,'Disallowed data-changing or bank-guard SQL');
// Payment INSERT is permitted only inside the protected RPC function when an
// authorized admin later completes an invoice — never at Code Sync time.
const beforeRpc=sql.split('create or replace function public.bb_sales_save_invoice_multi_bank_v1')[0];
const afterRpc=sql.split('end $fn$;').slice(1).join('end $fn$;');
assert.doesNotMatch(beforeRpc+afterRpc,/\\bINSERT\\s+INTO\\s+public\\.(?:invoices|payments|bb_verified_bank_transactions)\\b/i);
assert.match(sql,/insert into public\\.payments \\(/i,'Authorized admin RPC must create one payment per bank source');
const dashboard=fs.readFileSync(path.resolve(__dirname,'../index.html'),'utf8');
assert.match(dashboard,/20261027-multi-bank-verified1/,'Desktop route should remain current');
assert.match(dashboard,/getProfile\?\.\(\)\?\.user\?\.isAdmin === true/,'Pilot routing must use logged-in admin profile');
console.log('PASS registered checksum, source safety, desktop parity');
