# BIG BROTHER — Local schema-only vs Cloud structural baseline audit

**Date:** 01-Nov-2026  
**Classification:** READ-ONLY AUDIT. NO SCHEMA MIGRATION APPLIED. NO PREVIEW BRANCH CREATED.

## Inputs

- Uploaded user-provided `BIG-BROTHER-LOCAL-SCHEMA-ONLY.sql`, extracted from their earlier Local PostgreSQL 17.6 custom-format snapshot using `pg_restore --schema-only`.
- Local schema file: 2,799,289 UTF-8 bytes, 99,881 newline characters; SHA-256 `de30982e55d698ef66fbdb7cb9513e17f0cd6dd5d3d179b3e22b36334e82aeb1`.
- Supabase project `sjfhlaclgmkwwofzstok`: production schema catalog inspected **read-only** via `information_schema` and `pg_catalog`. No production rows exported.
- Local raw schema dump is **not** attached to or published in GitHub.

## Verified shared PUBLIC table structure

| Check | Local schema-only dump | Supabase Cloud | Result |
|---|---:|---:|---|
| Public base tables | 144 | 143 | Exactly 1 additional Local-only table |
| Common public base tables | 143 | 143 | MATCH |
| Common table columns | 1,803 | 1,803 | MATCH |
| Ordered table + column NAME fingerprint (MD5) | `3cb4997a687c43f4bcf3f3ec5daa772a` | same | MATCH |
| Ordered table + column NAME:DATA-TYPE fingerprint (MD5) | `68f70dbb22fa2af6ba3cc5d89f5be9d7` | same | MATCH |
| Ordered column NOT NULL fingerprint (MD5) | `e9d263f4b6d32e57332071dc490d4046` | same | MATCH |
| Ordered column DEFAULT PRESENCE fingerprint (MD5) | `36e142ace9fd4d889165a20aca6ba4a8` | same | MATCH |
| Common columns NOT NULL | 1,049 | 1,049 | MATCH |
| Common columns with a DEFAULT | 571 | 571 | MATCH |

The one Local-only public table is `bb_local_sync_history` (13 columns); **do not import it into Cloud**. One column has a quoted identifier `"position"`; structural comparison correctly handles the quoted name.

The column checks are structural fingerprints, **not proof of equivalent default expressions, CHECK constraints, foreign keys, indexes, functions, RLS policies, privileges or dependencies**.

## Differences still requiring inspection

| Object family | Local schema-only dump | Cloud current | Status |
|---|---:|---:|---|
| Public functions | 520 `CREATE FUNCTION` declarations | 552 routines in `pg_proc` | **32-function count difference** |
| Private functions | 37 `CREATE FUNCTION` declarations | 38 routines in `pg_proc` | **1-function count difference** |
| Public triggers | 161 `CREATE TRIGGER` declarations | 169 noninternal triggers | **8-trigger count difference** |
| Public views | 18 `CREATE VIEW` declarations | 18 views | Count matches; definitions not compared |
| Public RLS policy definitions | not fully compared | 10 policies | Requires separate audit |

Function/trigger count differences could include Cloud-only functions or Local-only objects: the counts alone **do not identify which**. They prohibit claiming an exact full schema clone at this stage.

The Local dump includes `auth`, `storage`, `realtime`, `pg_cron`, `pg_net`, `bb_local_maintenance`, and multiple Supabase-managed schemas, grants and extensions. **Never restore this whole dump directly onto an existing Supabase branch or production**. Managed schemas would conflict with the initialized Supabase platform, and local-only sync maintenance logic does not belong in Cloud.

## Exact Local vs Cloud routine and trigger inventory (read-only verification)

Cross-checked the uploaded schema-only `pg_dump` FUNCTION/TRIGGER names with the Cloud `pg_proc`/`pg_trigger` catalog (excluding PostgreSQL internal triggers). The comparison uses 20-bit MD5 lookup prefixes of object names as a private analysis aid; verified no Cloud hash collisions. The 49 renamed permanent-ID triggers were **independently checked by a complete table-name + primary-ID-column checksum**.

**Functions (names, not executable bodies):**
- Common names: **556** (Cloud 590; Local 557).
- Cloud-only function names: **34**, including:
  - Notification/FCM/push: `bb_notification_v2_capture`, `bb_notification_v2_extra_capture`, `bb_notification_v2_feed`, `bb_fcm_*`, `bb_push_*`, overdue inbox;
  - Staff relation: `bb_staff_relation_admin_*`, `bb_staff_relation_sync_due_salary_months`, staff assistant workflow;
  - Cloud linking / infrastructure: `bb_local_cloud_link_*`, bot cron gates;
  - Accounting-sensitive: `bb_purchase_edit_costs` (MUST separately review), plus photo-expiration handling.
- Local-only function name: **`private.bb_local_reject_infrastructure_replay_v1()`**. Keep it Local-only.
- Names matching does **NOT** prove function bodies/security attributes match. The 34 Cloud-only functions are not automatically safe to install on Local.

**Triggers (actual table + trigger-name inventory):**
- **105** exact table/trigger-name matches.
- **49** Local `bb_pid_<hash>` triggers vs Cloud `bb_permanent_id_<table>` trigger names: ALL 49 verified **semantically equivalent in their permanent-ID capture target**. Both are AFTER INSERT and invoke the same `bb_capture_permanent_primary_id(column)` function; all table/column mappings match. Sorted table + column SHA-compatible MD5 (independent local/cloud computation): `a83d85c680d92ec6e9ae777fce5ef4b7`. They should NOT both be installed on one database.
- **15** remaining Cloud-only triggers: eight notification-v2 triggers (including `stock_activity.bb_notify_v2_stock`), four bot cron gates, two FCM/push queue hooks, one staff assistant request-status hook.
- **7** remaining Local-only triggers: `bb_local_business_only_replay_guard_v1` on notification, FCM and push infrastructure tables. These protect Local from copying Cloud-only infrastructure records.
- Totals: Cloud = **105 + 49 + 15 = 169**; Local = **105 + 49 + 7 = 161**. Net count difference = 8, but there are 22 genuinely environment-specific triggers plus 49 naming variants.
- Reconstructing a Cloud test baseline must use **Cloud-style trigger identities** and Cloud notification semantics, not blindly load Local-specific guard triggers.

**Conclusion:** The count discrepancy is explained at the object-name/trigger-target level. A full comparison of function bodies, function security settings, CHECK/FK/default expressions, policies and reproducible fresh migration replay remains **NOT DONE**. Do not merge or deploy V2 yet.

## Data / secrets risk screening

- `COPY` top-level data-copy sections: 0.
- No obvious JWT-shaped keys, `sb_secret_*`, `sb_publishable_*`, Telegram bot token shapes, PostgreSQL connection URLs or PEM private keys detected by targeted regex checks.
- This is **not a comprehensive secret audit**. Security-definer function bodies, literals, grants and embedded HTTP endpoints can still disclose sensitive configuration.
- Do **not publish** the uploaded raw schema or use it as an unrestricted seed file. Keep actual customers, bank transactions, invoices and staff earning rows out of source control.

## Migration-history blocker remains

Production has 342 existing recorded migrations, but historical `CREATE TABLE` declarations are missing for 72 of the present 143 public tables (screening regex). A new Supabase Branching environment cannot replay the first migration because `public.clients` does not exist on the empty database. The failed branch was deleted.

**A fresh preview branch requires a reproducible BASELINE preceding those dependent migrations**, with a carefully reviewed strategy to reconcile existing migration history. Appending a migration at the end cannot make the already-failing first migration succeed. Do not rewrite production migration history or merge a test branch automatically.

## Recommended nonproduction next gates

1. Establish a clean PostgreSQL/Supabase-compatible **baseline source** from approved shared public table DDL and required functions, indexes, constraints, RLS and dependencies; exclude all Local-only and Supabase-managed objects.
2. Compare the **32 + 1 function** and **8 trigger** count differences by exact signatures/names and inspect privileges. Check defaults, FK and CHECK expressions.
3. Verify **blank-database replay** of the ordered baseline and later migrations on an isolated instance, with **synthetic** seed data and no contact to the live company DB.
4. Only then create another temporary paid Supabase Branching preview and confirm migration success **before** installing Stock Source V2.
5. Finish actual Back Sale and exact-source pre/post-close Reversal transactional rollback tests, plus compatibility and salary regression; keep all existing staged feature PRs unmerged.

**Production / real Local impact:** None from the schema comparison. The uploaded file was only read and analyzed.
