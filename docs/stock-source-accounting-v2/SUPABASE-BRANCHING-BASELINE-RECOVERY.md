# BIG BROTHER — Supabase Branching Baseline Recovery

**Status: DIAGNOSED / NOT REPAIRED. No production migration/schema changes.**

## What failed on 01-Nov-2026

Supabase development branch `stock-source-v2-validation-20261101` (`lkzssxkbqjlqvlzeujef`) failed while replaying the existing database migration history. Branch Postgres logs showed:

```
relation "public.clients" does not exist
```

The error occurred when the first migration (`20260909162334_clients_editor_auth_rls_rpc_v1`) created `public.bb_client_editor_revision()`, which references the not-yet-created `public.clients` table. **No Stock Source V2 SQL was run on this branch.**

The failed branch was deleted; `list_branches` confirmed production `main` only.

## Read-only migration coverage (checked directly against production)

- 342 recorded migrations; 342 non-null SQL statement arrays.
- 143 current `public` BASE TABLEs, **2,017 columns**, 18 views, 552 public routines, 169 public triggers, and 10 public RLS policies.
- 71 tables have a syntactic `CREATE TABLE` match in recorded migrations.
- **72 current public tables have no recorded CREATE TABLE match** (includes foundational clients, products, invoices, invoice_lines, stock_activity, stock_batches, payments, salary tables).
- This is a **screening result**; it does not guarantee the 71 other tables, functions, triggers, RLS rules or non-public schemas are replayable in order. Some objects might have been renamed or created outside tracked migrations.
- Repeatable inspection: `READONLY-SUPABASE-BRANCH-MIGRATION-COVERAGE.sql`.

## Root cause

This is **historical schema drift**: application tables existed before the current migration history, and later migrations assumed them. Production still works because the tables exist. A preview branch starts with a fresh database and replays migrations, so it cannot reconstruct these missing foundations.

Simply adding `CREATE TABLE public.clients` would hide only the first error, not restore the other missing tables/dependencies.

## Safe path to reproducible development branches

1. **Capture schema-only snapshot** from a verified production-equivalent Local database or a read-only production schema dump. No business rows, bank transactions, salaries, personal customer data or secrets should enter GitHub.
2. Compare with actual Cloud schema, including defaults, constraints, indexes, privileges, triggers, RLS, RPC signatures, extensions, roles and functions. Local can have historical or local-only objects; don't assume a Local dump is identical to Cloud.
3. On a disposable PostgreSQL 17 / Supabase-compatible test environment, restore schema and run a strict integrity audit. Build an approved **replacement baseline and subsequent migration chain** in an isolated source tree; use synthetic seed records.
4. Verify full **blank-database replay** (not just `CREATE FUNCTION` parsing), role/RLS/Auth/Storage access, and legacy Salary V2 / cash/bank / stock behavior. Test replay from empty DB before creating another paid branch.
5. Create a time-limited Supabase branch only after this passes. Verify branch schema integrity **before any V2 SQL install**.
6. Test staged Stock Source V2: mixed and single-source Batch Sale, Back Sale, before/after-close reversal, original COGS, invalid-source rollback, duplicate submission, and old clients.
7. Close/delete branch after tests, separately verify main is untouched and branch is gone.

## Do not do

- Do NOT edit or delete entries in production `supabase_migrations.schema_migrations` as a shortcut. A baseline/squash or history-repair operation must be independently tested, reviewed, separately backed up and explicitly approved before any production migration metadata change.
- Do NOT add 72 placeholder tables or alter live table definitions to make branches pass.
- Do NOT allow migrations to merge automatically or copy customer, bank, salary or invoice data into new development environments.
- Do NOT recreate a billable branch until the migration-replay gate is satisfied.
- Do NOT confuse a GitHub feature branch with a Supabase database branch.

## Working Stock Source V2 test alternative

A read-only Local backup was restored into an isolated no-network Docker PostgreSQL container. Source-aware SQL functions compiled (10/10), 12 arithmetic tests passed, actual Batch Invoice trigger cases passed 6/6 after accounting precision was correctly tested (unit_cost 4dp, line_value 2dp). **Back Sale and Reversal still await real transactional execution**, including release compatibility gates.

This method does not fix Cloud branching, but lets product testing continue without touching production. A single reusable runner with the existing local snapshot is preferable to repeating one-off PowerShell steps. A separately authorized standalone Supabase project would cost more than the previously approved few-cent branch and has not been created.

## Reference

Supabase official [Local development workflow](https://supabase.com/docs/guides/local-development/cli-workflows) describes using `supabase db pull` to build an initial baseline from an existing project, reviewing the generated schema, creating synthetic seed data, and verifying `supabase db reset`. For BIG BROTHER's already-populated 342-migration history, that general guidance alone is insufficient to justify any production history rewrite.

## Automated coverage added 01-Nov-2026
- A no-network GitHub Actions safety job now validates **3 + 6 + 1** staged Stock Source V2 SQL function definitions with PostgreSQL grammar and runs all **12** synthetic source arithmetic cases on an ephemeral PostgreSQL 17 container.
- Verified green CI run: https://github.com/angsokhey11-cloud/big-brother-dashboard/actions/runs/41276642239
- It uses neither billable Supabase branches nor real company data. It does not replace authenticated RPC / trigger integration using the actual business schema.
