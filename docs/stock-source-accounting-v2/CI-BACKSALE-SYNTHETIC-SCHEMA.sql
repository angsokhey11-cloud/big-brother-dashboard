-- BIG BROTHER Stock Source V2: SYNTHETIC Back Sale integration fixture.
-- Strictly no actual business data, no network and no cloud/local access.
-- NOTE: selective tables follow real field names/types used by this code path.
-- Non-stock concerns (auth/ID/cutover) use sandbox helpers explicitly; this is
-- not a full schema-equivalence, permissions, or production integration test.
\set ON_ERROR_STOP on
CREATE SCHEMA IF NOT EXISTS auth;
CREATE TABLE public.app_users (
  user_id uuid PRIMARY KEY, email text NOT NULL, role text NOT NULL,
  active boolean NOT NULL DEFAULT true, staff_id text);
CREATE TABLE public.app_user_location_access (
  user_id uuid NOT NULL, location_code text NOT NULL,
  PRIMARY KEY(user_id,location_code));
CREATE TABLE public.locations(
  location_code text PRIMARY KEY, location_name text NOT NULL,
  active boolean NOT NULL DEFAULT true);
CREATE TABLE public.staff(staff_id text PRIMARY KEY,staff_name text NOT NULL,status text DEFAULT 'active');
CREATE TABLE public.products(
  product_code text PRIMARY KEY,product_name text NOT NULL,unit text,
  active boolean NOT NULL DEFAULT true,track_stock boolean NOT NULL DEFAULT true);
CREATE TABLE public.stock_batches(
  batch_id text PRIMARY KEY,batch_date date NOT NULL,
  salesman_staff_id text,salesman_name_snapshot text,
  driver_staff_id text,driver_name_snapshot text,
  driver2_staff_id text,driver2_name_snapshot text,
  location_code text NOT NULL,location_name_snapshot text,
  status text NOT NULL DEFAULT 'Open',
  issued_qty numeric(18,4) DEFAULT 0 NOT NULL,
  sold_qty numeric(18,4) DEFAULT 0 NOT NULL,
  back_sale_qty numeric(18,4) DEFAULT 0 NOT NULL,
  damaged_qty numeric(18,4) DEFAULT 0 NOT NULL,
  returned_qty numeric(18,4) DEFAULT 0 NOT NULL,
  lost_qty numeric(18,4) DEFAULT 0 NOT NULL,
  source_updated_at timestamptz,updated_at timestamptz DEFAULT now() NOT NULL);
CREATE TABLE public.stock_batch_items(
  batch_id text NOT NULL,product_code text NOT NULL,
  product_name_snapshot text,unit_snapshot text,
  issued_qty numeric(18,4) DEFAULT 0 NOT NULL,
  sold_qty_snapshot numeric(18,4) DEFAULT 0 NOT NULL,
  back_sale_qty numeric(18,4) DEFAULT 0 NOT NULL,
  damaged_qty numeric(18,4) DEFAULT 0 NOT NULL,
  other_out_qty numeric(18,4) DEFAULT 0 NOT NULL,
  pending_qty_snapshot numeric(18,4) DEFAULT 0 NOT NULL,
  purchased_issued_qty numeric DEFAULT 0 NOT NULL,
  zero_cost_issued_qty numeric DEFAULT 0 NOT NULL,
  purchased_pending_qty_snapshot numeric DEFAULT 0 NOT NULL,
  zero_cost_pending_qty_snapshot numeric DEFAULT 0 NOT NULL,
  purchased_back_sale_qty numeric DEFAULT 0 NOT NULL,
  zero_cost_back_sale_qty numeric DEFAULT 0 NOT NULL,
  source_updated_at timestamptz,updated_at timestamptz DEFAULT now() NOT NULL,
  PRIMARY KEY(batch_id,product_code));
CREATE TABLE public.stock_activity(
  transaction_id text PRIMARY KEY,
  batch_id text,activity_date date NOT NULL,activity_type text,
  product_code text NOT NULL,product_name_snapshot text,
  qty numeric(18,4) NOT NULL,unit_snapshot text,
  location_code text,from_location_code text,to_location_code text,
  inventory_controller_staff_id text,inventory_controller_name_snapshot text,
  salesman_staff_id text,salesman_name_snapshot text,
  driver_staff_id text,driver_name_snapshot text,
  driver2_staff_id text,driver2_name_snapshot text,
  reference_no text,note text,source_created_at timestamptz,
  created_at timestamptz DEFAULT now() NOT NULL,
  movement_id text,flow text,movement_type text,
  from_bucket text,to_bucket text,
  source_entity_type text,source_id text,source_name text,
  unit_cost numeric(18,4),line_value numeric(18,2),
  location_name_snapshot text,client_request_id text);
CREATE TABLE public.stock_movement_requests(
  request_id text PRIMARY KEY,movement_id text NOT NULL,
  response_payload jsonb NOT NULL,created_by uuid,
  created_at timestamptz DEFAULT now() NOT NULL);
-- No production functions replaced. The following limited helpers exist
-- ONLY in disposable CI database to exercise the real staged Back Sale function.
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
CREATE FUNCTION public.bb_stock_default_warehouse_internal() RETURNS text
LANGUAGE sql STABLE AS $$ SELECT 'BB-WH-TEST'::text $$;
CREATE FUNCTION public.bb_has_location_access(p_location_code text) RETURNS boolean
LANGUAGE sql STABLE AS $$
SELECT EXISTS(
  SELECT 1 FROM public.app_users u
  JOIN public.app_user_location_access a ON a.user_id=u.user_id
  WHERE u.user_id=auth.uid() AND u.active
    AND lower(a.location_code)=lower(p_location_code)
)
$$;
CREATE SEQUENCE public.bb_ci_id;
CREATE FUNCTION public.bb_next_prefixed_id(p_table regclass,p_col text,p_prefix text,p_pad integer)
RETURNS text LANGUAGE sql VOLATILE AS $$
SELECT p_prefix||'-'||lpad(nextval('public.bb_ci_id')::text,p_pad,'0')
$$;
-- This helper has the exact business average-cost calculation from Cloud,
-- reading real-style (but strictly synthetic) stock_activity rows.
CREATE FUNCTION public.bb_stock_average_cost_internal(p_product_code text)
 RETURNS numeric LANGUAGE plpgsql STABLE AS $body$
DECLARE
  r record;
  v_good_qty numeric:=0;v_good_cost numeric:=0;v_avg numeric:=0;
  v_from_good boolean;v_to_good boolean;v_cost numeric;
BEGIN
  FOR r IN SELECT qty,unit_cost,
        upper(coalesce(from_bucket,'')) AS from_bucket,
        upper(coalesce(to_bucket,'')) AS to_bucket
      FROM public.stock_activity
      WHERE product_code=p_product_code AND qty>0
      ORDER BY coalesce(source_created_at,created_at),created_at,transaction_id
  LOOP
    v_from_good:=r.from_bucket IN ('WAREHOUSE_GOOD','BATCH_PENDING');
    v_to_good:=r.to_bucket IN ('WAREHOUSE_GOOD','BATCH_PENDING');
    v_avg:=CASE WHEN v_good_qty>0 THEN v_good_cost/v_good_qty ELSE 0 END;
    IF v_from_good AND v_to_good THEN CONTINUE;
    ELSIF NOT v_from_good AND v_to_good THEN
      v_cost:=CASE WHEN coalesce(r.unit_cost,0)>0 THEN r.unit_cost ELSE v_avg END;
      v_good_cost:=v_good_cost+(r.qty*v_cost);v_good_qty:=v_good_qty+r.qty;
    ELSIF v_from_good AND NOT v_to_good THEN
      v_good_cost:=greatest(v_good_cost-(r.qty*v_avg),0);
      v_good_qty:=greatest(v_good_qty-r.qty,0);
    END IF;
  END LOOP;
  RETURN round(CASE WHEN v_good_qty>0 THEN v_good_cost/v_good_qty ELSE 0 END,6);
END;
$body$;
-- Non-transactional test support; the true production implementations of
-- these helpers still need full-schema integration coverage.
CREATE FUNCTION public.bb_stock_refresh_batch_status_internal(p_batch_id text)
RETURNS void LANGUAGE plpgsql AS $body$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.stock_batches WHERE batch_id=p_batch_id) THEN
    RAISE EXCEPTION 'test Batch ID missing';
  END IF;
END;
$body$;
CREATE FUNCTION public.bb_stock_touch_revision_internal() RETURNS text
LANGUAGE sql AS $$SELECT 'CI-SYNTHETIC-REVISION'::text$$;

INSERT INTO public.locations(location_code,location_name) VALUES
 ('BB-WH-TEST','Synthetic Warehouse'),('BB-SALES-TEST','Synthetic Sales Route');
INSERT INTO public.app_users(user_id,email,role,active) VALUES
 ('00000000-0000-4000-8000-000000000001','ci-test@example.invalid','admin',true);
INSERT INTO public.app_user_location_access(user_id,location_code) VALUES
 ('00000000-0000-4000-8000-000000000001','BB-WH-TEST'),
 ('00000000-0000-4000-8000-000000000001','BB-SALES-TEST');
INSERT INTO public.products(product_code,product_name,unit) VALUES
 ('BB-CI-PRODUCT','Synthetic 2L Milk','bottle');
INSERT INTO public.stock_batches(
  batch_id,batch_date,location_code,location_name_snapshot,status,
  issued_qty,back_sale_qty,returned_qty
) VALUES ('BB-CI-BATCH',CURRENT_DATE,'BB-SALES-TEST','Synthetic Sales Route','Open',40,0,0);
INSERT INTO public.stock_batch_items(
 batch_id,product_code,product_name_snapshot,unit_snapshot,
 issued_qty,pending_qty_snapshot,
 purchased_issued_qty,zero_cost_issued_qty,
 purchased_pending_qty_snapshot,zero_cost_pending_qty_snapshot
) VALUES ('BB-CI-BATCH','BB-CI-PRODUCT','Synthetic 2L Milk','bottle',
 40,40,20,20,20,20);
-- Purchase-cost origin: synthetic receipt only, not real customer/order data.
INSERT INTO public.stock_activity(
 transaction_id,activity_date,activity_type,product_code,qty,unit_cost,line_value,
 from_bucket,to_bucket,movement_type
) VALUES('BB-CI-RECEIPT',CURRENT_DATE,'Purchase','BB-CI-PRODUCT',
  100,3.2825,328.25,'EXTERNAL','WAREHOUSE_GOOD','PURCHASE_RECEIPT');
\echo 'SYNTHETIC Back Sale stock/permissions/average-cost fixture ready'
