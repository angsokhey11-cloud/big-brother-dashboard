-- BIG BROTHER Local Brain — schema ONLY, delivered through Code Sync.
-- Business records are NEVER inserted by Code Sync. No cloud push data copied.
-- Compatible with request-origin columns and four Cloud notification/push structures.
-- Old 08C (unfiltered) is FAIL-CLOSED by ENABLE ALWAYS triggers below.
DO $bb_origin$
DECLARE t text; d text; n record;
BEGIN
 FOREACH t IN ARRAY ARRAY['staff_payment_requests','staff_leave_requests','staff_salary_advance_requests'] LOOP
  IF to_regclass(format('public.%I',t)) IS NULL THEN
   RAISE EXCEPTION 'CODE_SYNC_STOP: public.% request table missing',t;
  END IF;
  IF EXISTS(SELECT 1 FROM pg_attribute a WHERE a.attrelid=format('public.%I',t)::regclass
    AND a.attnum>0 AND NOT a.attisdropped AND
    ((a.attname='submitted_by_user_id' AND (a.atttypid<>'uuid'::regtype OR a.attnotnull))
      OR (a.attname='submission_channel' AND a.atttypid<>'text'::regtype))) THEN
   RAISE EXCEPTION 'CODE_SYNC_STOP: incompatible request origin column in public.%',t;
  END IF;
  EXECUTE format('ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS submitted_by_user_id uuid',t);
  EXECUTE format('ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS submission_channel text NOT NULL DEFAULT %L',t,'STAFF');
  SELECT a.attnotnull,pg_get_expr(d.adbin,d.adrelid) expression INTO n
  FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum
  WHERE a.attrelid=format('public.%I',t)::regclass AND a.attname='submission_channel'
    AND a.attnum>0 AND NOT a.attisdropped;
  IF NOT FOUND OR n.attnotnull IS DISTINCT FROM true OR n.expression IS NULL
    OR replace(replace(n.expression,'::text',''),'::pg_catalog.text','') NOT IN ('''STAFF''','(''STAFF'')') THEN
    RAISE EXCEPTION 'CODE_SYNC_STOP: public.%.submission_channel default/not-null differs',t;
  END IF;
  SELECT pg_get_constraintdef(c.oid) INTO d FROM pg_constraint c
  WHERE c.conrelid=format('public.%I',t)::regclass AND c.conname=t||'_submission_channel_check' AND c.contype='c';
  IF d IS NULL THEN
   EXECUTE format('ALTER TABLE public.%I ADD CONSTRAINT %I CHECK (submission_channel IN (%L,%L))',
    t,t||'_submission_channel_check','STAFF','ADMIN_ON_BEHALF');
  ELSIF d NOT LIKE '%''STAFF''%' OR d NOT LIKE '%''ADMIN_ON_BEHALF''%' THEN
   RAISE EXCEPTION 'CODE_SYNC_STOP: public.% unexpected submission_channel CHECK',t;
  END IF;
 END LOOP;
END $bb_origin$;

-- Structure-only infrastructure parity for existing Cloud Schema Guard.
CREATE TABLE IF NOT EXISTS public.bb_notification_events_v2(
 event_key text PRIMARY KEY,
 category text NOT NULL CHECK (category IN ('Stock','Approvals','Cash & Bank','Requests','Payments','Receivable','Schedule')),
 audience text NOT NULL CHECK (audience IN ('admin','staff')),
 recipient_staff_id text, title text NOT NULL, route text NOT NULL,
 entity_id text,location_code text,
 event_at timestamptz NOT NULL DEFAULT now(),
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS bb_notification_events_v2_recipient_idx
 ON public.bb_notification_events_v2(audience,recipient_staff_id,event_at DESC);
ALTER TABLE public.bb_notification_events_v2 ENABLE ROW LEVEL SECURITY;
CREATE TABLE IF NOT EXISTS public.bb_push_config_v1(
 id smallint PRIMARY KEY DEFAULT 1 CHECK(id=1),
 vapid_public_key text NOT NULL,enabled boolean NOT NULL DEFAULT false,
 updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.bb_push_config_v1 ENABLE ROW LEVEL SECURITY;
CREATE TABLE IF NOT EXISTS public.bb_push_subscriptions_v1(
 subscription_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 endpoint text NOT NULL UNIQUE CHECK (length(endpoint)>=40 AND length(endpoint)<=2048),
 p256dh text NOT NULL CHECK (length(p256dh)>=32 AND length(p256dh)<=500),
 auth_secret text NOT NULL CHECK(length(auth_secret)>=16 AND length(auth_secret)<=500),
 device_label text NOT NULL DEFAULT 'BIG BROTHER device',
 enabled boolean NOT NULL DEFAULT true,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 last_delivered_at timestamptz
);
CREATE INDEX IF NOT EXISTS bb_push_subscriptions_v1_user_idx
 ON public.bb_push_subscriptions_v1(user_id) WHERE enabled;
ALTER TABLE public.bb_push_subscriptions_v1 ENABLE ROW LEVEL SECURITY;
CREATE TABLE IF NOT EXISTS public.bb_push_deliveries_v1(
 event_key text NOT NULL REFERENCES public.bb_notification_events_v2(event_key) ON DELETE CASCADE,
 subscription_id uuid NOT NULL REFERENCES public.bb_push_subscriptions_v1(subscription_id) ON DELETE CASCADE,
 status text NOT NULL DEFAULT 'processing'
  CHECK(status IN ('processing','delivered','failed','expired')),
 last_status_code integer, attempted_at timestamptz NOT NULL DEFAULT now(),
 finished_at timestamptz, PRIMARY KEY(event_key,subscription_id)
);
ALTER TABLE public.bb_push_deliveries_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.bb_notification_events_v2 FROM PUBLIC,anon,authenticated;
REVOKE ALL ON public.bb_push_config_v1 FROM PUBLIC,anon,authenticated;
REVOKE ALL ON public.bb_push_subscriptions_v1 FROM PUBLIC,anon,authenticated;
REVOKE ALL ON public.bb_push_deliveries_v1 FROM PUBLIC,anon,authenticated;

-- Verify schema parity before allowing the legacy Schema Guard to continue.
DO $bb_verify$
DECLARE tab text; spec jsonb; x record; typ text; nullable text;
BEGIN
 FOR tab,spec IN SELECT * FROM (VALUES
 ('bb_notification_events_v2','{"event_key":"text:NO","category":"text:NO","audience":"text:NO","recipient_staff_id":"text:YES","title":"text:NO","route":"text:NO","entity_id":"text:YES","location_code":"text:YES","event_at":"timestamp with time zone:NO","created_at":"timestamp with time zone:NO"}'::jsonb),
 ('bb_push_config_v1','{"id":"smallint:NO","vapid_public_key":"text:NO","enabled":"boolean:NO","updated_at":"timestamp with time zone:NO"}'::jsonb),
 ('bb_push_subscriptions_v1','{"subscription_id":"uuid:NO","user_id":"uuid:NO","endpoint":"text:NO","p256dh":"text:NO","auth_secret":"text:NO","device_label":"text:NO","enabled":"boolean:NO","created_at":"timestamp with time zone:NO","updated_at":"timestamp with time zone:NO","last_delivered_at":"timestamp with time zone:YES"}'::jsonb),
 ('bb_push_deliveries_v1','{"event_key":"text:NO","subscription_id":"uuid:NO","status":"text:NO","last_status_code":"integer:YES","attempted_at":"timestamp with time zone:NO","finished_at":"timestamp with time zone:YES"}'::jsonb)
 ) z(tbl,columns) LOOP
  IF NOT EXISTS(SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relname=tab AND c.relkind='r' AND c.relrowsecurity) THEN
   RAISE EXCEPTION 'CODE_SYNC_STOP: public.% missing or RLS disabled',tab;
  END IF;
  FOR x IN SELECT key,value FROM jsonb_each_text(spec) LOOP
   SELECT c.data_type,c.is_nullable INTO typ,nullable FROM information_schema.columns c
    WHERE c.table_schema='public' AND c.table_name=tab AND c.column_name=x.key;
   IF NOT FOUND OR (typ||':'||nullable) IS DISTINCT FROM x.value THEN
    RAISE EXCEPTION 'CODE_SYNC_STOP: public.%.% column mismatch',tab,x.key;
   END IF;
  END LOOP;
  IF EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename=tab) THEN
   RAISE EXCEPTION 'CODE_SYNC_STOP: unexpected Local push infrastructure policy %',tab;
  END IF;
 END LOOP;
END $bb_verify$;

-- Fail closed if OLD Cloud -> Local controller is run before the updated
-- business-only staging script reaches the actual Local Windows controller.
-- 08C uses session_replication_role=replica; ENABLE ALWAYS triggers still fire.
DO $bb_schema_private$
BEGIN
 IF to_regnamespace('private') IS NULL THEN
  RAISE EXCEPTION 'CODE_SYNC_STOP: private schema missing for staging replay guard';
 END IF;
END $bb_schema_private$;
CREATE OR REPLACE FUNCTION private.bb_local_reject_infrastructure_replay_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $bb_reject$
BEGIN
 IF current_setting('session_replication_role',true)='replica' THEN
  RAISE EXCEPTION 'BUSINESS_SCOPE_BLOCKED: legacy Cloud -> Local tried to merge %. Code Sync controller staging update required.',TG_TABLE_NAME;
 END IF;
 RETURN NEW;
END $bb_reject$;
REVOKE ALL ON FUNCTION private.bb_local_reject_infrastructure_replay_v1() FROM PUBLIC,anon,authenticated;
DO $bb_guard$
DECLARE t text; p oid;
BEGIN
 FOREACH t IN ARRAY ARRAY['bb_notification_events_v2','bb_push_config_v1','bb_push_subscriptions_v1','bb_push_deliveries_v1'] LOOP
  SELECT tgfoid INTO p FROM pg_trigger
  WHERE tgrelid=format('public.%I',t)::regclass
    AND tgname='bb_local_business_only_replay_guard_v1' AND NOT tgisinternal;
  IF p IS NOT NULL AND p<>'private.bb_local_reject_infrastructure_replay_v1()'::regprocedure::oid THEN
   RAISE EXCEPTION 'CODE_SYNC_STOP: incompatible replay guard on public.%',t;
  END IF;
  IF p IS NULL THEN
   EXECUTE format('CREATE TRIGGER bb_local_business_only_replay_guard_v1 BEFORE INSERT OR UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION private.bb_local_reject_infrastructure_replay_v1()',t);
  END IF;
  EXECUTE format('ALTER TABLE public.%I ENABLE ALWAYS TRIGGER bb_local_business_only_replay_guard_v1',t);
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid=format('public.%I',t)::regclass
    AND tgname='bb_local_business_only_replay_guard_v1' AND tgenabled='A') THEN
   RAISE EXCEPTION 'CODE_SYNC_STOP: ALWAYS replay guard missing on public.%',t;
  END IF;
 END LOOP;
END $bb_guard$;
