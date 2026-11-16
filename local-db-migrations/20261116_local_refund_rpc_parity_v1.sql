-- BIG BROTHER Local Brain V5/V6: missing Refund Overview RPC, plus Staff Refund Available RPC.
-- Safe targeted LOCAL SCHEMA/RPC parity. No refund, cash close or payment data is inserted, edited or deleted.
-- Execute only inside the verified local Docker container supabase_db_Local_Brain, database postgres.
-- Cloud/Local Data Sync is NOT part of this migration.
BEGIN;
SET LOCAL lock_timeout = '10s';
SET LOCAL statement_timeout = '60s';
DO $refund_guard$
DECLARE
  missing_functions text[];
  missing_tables text[];
  missing_columns text[];
BEGIN
  IF current_database() <> 'postgres' THEN
    RAISE EXCEPTION 'LOCAL REFUND RPC REPAIR BLOCKED: unexpected database name';
  END IF;
  SELECT array_agg(fn) INTO missing_functions
  FROM unnest(ARRAY[
    'public.bb_is_admin()',
    'public.bb_is_active_user()',
    'private.bb_is_current_permanent_salesman(text)'
  ]) fn WHERE to_regprocedure(fn) IS NULL;
  IF missing_functions IS NOT NULL THEN
    RAISE EXCEPTION 'LOCAL REFUND RPC REPAIR BLOCKED: missing prerequisite(s): %',array_to_string(missing_functions,', ');
  END IF;
  SELECT array_agg(t) INTO missing_tables
  FROM unnest(ARRAY[
    'public.app_users',
    'public.invoices',
    'public.daily_cash_closes',
    'public.bb_salesman_refund_deductions'
  ]) t WHERE to_regclass(t) IS NULL;
  IF missing_tables IS NOT NULL THEN
    RAISE EXCEPTION 'LOCAL REFUND RPC REPAIR BLOCKED: missing table(s): %',array_to_string(missing_tables,', ');
  END IF;
  WITH expected(tbl,col) AS (
    VALUES
    ('invoices','invoice_id'),('invoices','invoice_no'),('invoices','customer_id'),
    ('invoices','customer_name_snapshot'),
    ('daily_cash_closes','close_id'),('daily_cash_closes','status'),
    ('daily_cash_closes','gross_expected_usd'),('daily_cash_closes','salesman_refund_deduction_usd'),
    ('daily_cash_closes','expected_usd'),
    ('bb_salesman_refund_deductions','refund_id'),('bb_salesman_refund_deductions','invoice_id'),
    ('bb_salesman_refund_deductions','salesman_staff_id'),('bb_salesman_refund_deductions','location_code'),
    ('bb_salesman_refund_deductions','amount_usd'),('bb_salesman_refund_deductions','status'),
    ('bb_salesman_refund_deductions','close_id'),('bb_salesman_refund_deductions','created_at'),
    ('app_users','user_id'),('app_users','active'),('app_users','staff_id')
  )
  SELECT array_agg(tbl||'.'||col) INTO missing_columns
  FROM expected e
  WHERE NOT EXISTS(
    SELECT 1 FROM information_schema.columns c
    WHERE c.table_schema='public' AND c.table_name=e.tbl AND c.column_name=e.col
  );
  IF missing_columns IS NOT NULL THEN
    RAISE EXCEPTION 'LOCAL REFUND RPC REPAIR BLOCKED: missing columns: %',array_to_string(missing_columns,', ');
  END IF;
END $refund_guard$;

-- Exact Cloud SQL definition, restored only on LOCAL database: bb_admin_salesman_refund_overview_v1
CREATE OR REPLACE FUNCTION public.bb_admin_salesman_refund_overview_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 IF auth.uid() IS NULL OR NOT public.bb_is_admin() THEN RAISE EXCEPTION 'Admin only'; END IF;
 RETURN jsonb_build_object('success',true,'rows',coalesce((
 SELECT jsonb_agg(jsonb_build_object('refundId',d.refund_id,'invoiceNo',i.invoice_no,'customerId',i.customer_id,'salesmanStaffId',d.salesman_staff_id,'locationCode',d.location_code,'amountUSD',d.amount_usd,'status',d.status,'closeId',d.close_id,'closeStatus',c.status,'grossCollectionUSD',c.gross_expected_usd,'refundCollectionUSD',c.salesman_refund_deduction_usd,'netExpectedUSD',c.expected_usd,'createdAt',d.created_at) ORDER BY d.created_at DESC)
 FROM public.bb_salesman_refund_deductions d
 JOIN public.invoices i ON i.invoice_id=d.invoice_id
 LEFT JOIN public.daily_cash_closes c ON c.close_id=d.close_id
 ),'[]'::jsonb));
END;$function$;

-- Exact Cloud SQL definition, restored only on LOCAL database: bb_salesman_refund_available_v1
CREATE OR REPLACE FUNCTION public.bb_salesman_refund_available_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_staff text;
BEGIN
 IF auth.uid() IS NULL OR NOT public.bb_is_active_user() THEN RAISE EXCEPTION 'Access denied'; END IF;
 SELECT staff_id INTO v_staff FROM public.app_users WHERE user_id=auth.uid() AND active=true;
 RETURN jsonb_build_object('success',true,'refunds',
 coalesce((SELECT jsonb_agg(jsonb_build_object('refundId',r.refund_id,'invoiceNo',i.invoice_no,'customer',i.customer_name_snapshot,'amountUSD',r.amount_usd,'locationCode',r.location_code,'status',r.status) ORDER BY r.created_at)
 FROM public.bb_salesman_refund_deductions r JOIN public.invoices i ON i.invoice_id=r.invoice_id
 WHERE r.status='AVAILABLE' AND r.salesman_staff_id=v_staff AND private.bb_is_current_permanent_salesman(r.location_code)),'[]'::jsonb));
END;$function$;


REVOKE ALL ON FUNCTION public.bb_admin_salesman_refund_overview_v1() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bb_admin_salesman_refund_overview_v1() TO authenticated;
REVOKE ALL ON FUNCTION public.bb_salesman_refund_available_v1() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bb_salesman_refund_available_v1() TO authenticated;

DO $refund_verify$
BEGIN
  IF to_regprocedure('public.bb_admin_salesman_refund_overview_v1()') IS NULL
    OR to_regprocedure('public.bb_salesman_refund_available_v1()') IS NULL
  THEN RAISE EXCEPTION 'LOCAL REFUND RPC REPAIR BLOCKED: expected functions not installed'; END IF;
  IF (SELECT prosecdef FROM pg_proc WHERE oid='public.bb_admin_salesman_refund_overview_v1()'::regprocedure) IS DISTINCT FROM true
  THEN RAISE EXCEPTION 'LOCAL REFUND RPC REPAIR BLOCKED: admin authorization guard not deployed'; END IF;
END $refund_verify$;
NOTIFY pgrst, 'reload schema';
COMMIT;
-- Expected after schema cache reload:
-- Local Admin Daily Cash Collection -> "No salesman refund records yet" when Local table has zero records.
-- Your Collection -> empty salesman refund selector when no eligible Local refunds.
