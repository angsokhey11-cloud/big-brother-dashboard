-- BIG BROTHER LOCAL BRAIN — Staff PC Overview stock snapshot alignment (2026-10-17)
-- Source: successful read-only Local stock inspection dated 2026-10-17 18:06 +07.
-- SR-01 stock_batch_items is 1 + 247 + 477 = 725; no negative item rows.
-- Preserve all existing permissions, months, sales, A/R, batch count and function attributes.
-- Change ONLY physical/purchased/zero-cost stock calculation inside bb_mobile_overview_filtered.
-- No stock movement, invoice, customer, COGS, or other business-data writes.
DO $bb_stock_overview$
DECLARE
  v_fn regprocedure := to_regprocedure('public.bb_mobile_overview_filtered(integer,integer,text)');
  v_definition text;
  v_start integer;
  v_stop integer;
  v_old text;
  v_new text := $bb_reconciled$
  -- Reconciled stock_batch_items snapshots reflect batch transfers and corrections.
  with assigned_batches as (
    select b.batch_id
    from public.stock_batches b
    where upper(coalesce(b.status,'OPEN')) not in ('CLOSED','CANCELLED','CANCELED')
      and exists (
        select 1
        from public.app_user_location_access ula
        where ula.user_id=v_user.user_id
          and lower(ula.location_code)=lower(b.location_code)
      )
  )
  select
    coalesce(sum(coalesce(bi.purchased_pending_qty_snapshot,0)
      * public.bb_stock_average_cost_internal(bi.product_code)),0),
    coalesce(sum(bi.purchased_pending_qty_snapshot),0),
    coalesce(sum(bi.zero_cost_pending_qty_snapshot),0),
    coalesce(sum(bi.pending_qty_snapshot),0)
  into
    v_stock_value_usd,
    v_stock_purchased_qty,
    v_stock_zero_cost_qty,
    v_stock_physical_qty
  from assigned_batches ab
  join public.stock_batch_items bi
    on bi.batch_id=ab.batch_id;

$bb_reconciled$;
BEGIN
  IF v_fn IS NULL THEN
    RAISE EXCEPTION 'STOCK OVERVIEW SAFE STOP: bb_mobile_overview_filtered(integer,integer,text) missing';
  END IF;
  IF to_regclass('public.stock_batches') IS NULL
     OR to_regclass('public.stock_batch_items') IS NULL
     OR to_regclass('public.app_user_location_access') IS NULL THEN
    RAISE EXCEPTION 'STOCK OVERVIEW SAFE STOP: required reconciled stock tables missing';
  END IF;

  SELECT pg_get_functiondef(v_fn) INTO v_definition;
  IF position('join public.stock_batch_items bi' IN v_definition)>0
     AND position('left join public.stock_activity sa' IN v_definition)=0 THEN
    RAISE NOTICE 'STOCK OVERVIEW ALREADY RECONCILED: no change';
  ELSE
    v_start := position('  with assigned_batches as (' IN v_definition);
    v_stop := position('  if lower(coalesce(v_user.role,''))=''admin'' then' IN v_definition);

    IF v_start=0 OR v_stop<=v_start THEN
      RAISE EXCEPTION 'STOCK OVERVIEW SAFE STOP: source markers not found in inspected order';
    END IF;

    v_old := substring(v_definition from v_start for v_stop-v_start);
    IF position('batch_product as (' IN v_old)=0
       OR position('left join public.stock_activity sa' IN v_old)=0
       OR position('group by ab.batch_id,sa.product_code' IN v_old)=0
       OR position('bp.purchased_pending+bp.zero_cost_pending' IN v_old)=0
       OR position('v_stock_physical_qty' IN v_old)=0
       OR position('join public.stock_batch_items' IN v_old)>0
       OR position('public.app_user_location_access' IN v_definition)=0 THEN
      RAISE EXCEPTION 'STOCK OVERVIEW SAFE STOP: Local movement-based calculation differs from inspected version';
    END IF;

    v_definition := substring(v_definition from 1 for v_start-1)
                 || v_new || substring(v_definition from v_stop);
    EXECUTE v_definition;

    IF position('join public.stock_batch_items bi' IN
       pg_get_functiondef('public.bb_mobile_overview_filtered(integer,integer,text)'::regprocedure))=0 THEN
      RAISE EXCEPTION 'STOCK OVERVIEW SAFE STOP: reconciled function verification failed';
    END IF;
    RAISE NOTICE 'STOCK OVERVIEW REPAIRED: uses reconciled stock_batch_items; no stock data changed';
  END IF;
END
$bb_stock_overview$;
