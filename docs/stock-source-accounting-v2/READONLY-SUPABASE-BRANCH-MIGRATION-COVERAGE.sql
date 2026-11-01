-- BIG BROTHER: Supabase Branching baseline / migration completeness report
-- READ-ONLY. Never edits production schema or migration history.
-- The scan reports CREATE TABLE coverage by current public table name.
-- This is a screening report, not proof of a fully reproducible schema:
-- renamed/dropped tables, quoted names, constraints, schemas and functions
-- require an independent schema-only restore and ordered migration replay.

WITH history AS (
  SELECT version, name,
         lower(array_to_string(statements, E'\n')) AS sql_text
    FROM supabase_migrations.schema_migrations
),
live_tables AS (
  SELECT table_name
    FROM information_schema.tables
   WHERE table_schema='public'
     AND table_type='BASE TABLE'
),
coverage AS (
  SELECT l.table_name,
         EXISTS (
           SELECT 1
             FROM history h
            WHERE h.sql_text ~ (
              'create[[:space:]]+table[[:space:]]+' ||
              '(if[[:space:]]+not[[:space:]]+exists[[:space:]]+)?' ||
              '(public[.])?' ||
              l.table_name ||
              '([[:space:](]|$)'
            )
         ) AS create_table_seen
    FROM live_tables l
)
SELECT (SELECT count(*) FROM history) AS recorded_migrations,
       count(*) AS live_public_tables,
       count(*) FILTER(WHERE create_table_seen) AS tables_with_create_migration,
       count(*) FILTER(WHERE NOT create_table_seen) AS tables_missing_create_migration
  FROM coverage;

WITH history AS (
  SELECT lower(array_to_string(statements, E'\n')) AS sql_text
    FROM supabase_migrations.schema_migrations
),
live_tables AS (
  SELECT table_name
    FROM information_schema.tables
   WHERE table_schema='public'
     AND table_type='BASE TABLE'
)
SELECT t.table_name,
       CASE WHEN EXISTS(
          SELECT 1 FROM history h
           WHERE h.sql_text ~ (
             'create[[:space:]]+table[[:space:]]+' ||
             '(if[[:space:]]+not[[:space:]]+exists[[:space:]]+)?' ||
             '(public[.])?' ||
             t.table_name ||
             '([[:space:](]|$)'
           )
       ) THEN 'FOUND_IN_HISTORY' ELSE 'MISSING_CREATE_TABLE' END AS migration_coverage
FROM live_tables t
ORDER BY migration_coverage DESC, table_name;

SELECT version,name,
       length(array_to_string(statements,E'\n')) AS sql_chars
  FROM supabase_migrations.schema_migrations
 ORDER BY version
 LIMIT 10;
