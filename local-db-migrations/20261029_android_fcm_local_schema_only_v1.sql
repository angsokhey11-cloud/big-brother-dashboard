-- BIG BROTHER Local Brain V5/V6 — Code Sync schema-only 29-Oct-2026.
-- Cloud Firebase/FCM device registration and delivery are infrastructure,
-- NEVER Cloud -> Local business data. No rows, secrets, tokens or expenses.
-- Stop on schema drift. Preserve all existing Local business and salary records.
DO $bb_fcm_preflight$
DECLARE t text;
BEGIN
 IF to_regclass('public.bb_notification_events_v2') IS NULL
    OR to_regprocedure('private.bb_local_reject_infrastructure_replay_v1()') IS NULL
    OR to_regclass('auth.users') IS NULL THEN
   RAISE EXCEPTION 'CODE_SYNC_STOP: run 20261025_staff_relation_sync_schema_v1 first; notification guard and auth foundation required';
 END IF;
 -- Existing unrelated local tables must never be silently converted.
 FOREACH t IN ARRAY ARRAY[
   'bb_fcm_config_v1','bb_fcm_devices_v1','bb_fcm_deliveries_v1'
 ] LOOP
   IF to_regclass(format('public.%I',t)) IS NOT NULL AND NOT EXISTS (
     SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
     WHERE n.nspname='public' AND c.relname=t AND c.relkind='r'
   ) THEN
     RAISE EXCEPTION 'CODE_SYNC_STOP: unexpected existing relation public.%',t;
   END IF;
 END LOOP;
END $bb_fcm_preflight$;

CREATE TABLE IF NOT EXISTS public.bb_fcm_config_v1 (
 id smallint PRIMARY KEY DEFAULT 1 CHECK (id=1),
 enabled boolean NOT NULL DEFAULT false,
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.bb_fcm_devices_v1 (
 token text PRIMARY KEY
   CONSTRAINT bb_fcm_token_length CHECK (char_length(token)>=20 AND char_length(token)<=4096),
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 application_id text NOT NULL DEFAULT 'com.bigbrother.online.stable'
   CHECK (application_id='com.bigbrother.online.stable'),
 enabled boolean NOT NULL DEFAULT true,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 last_registered_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS bb_fcm_devices_v1_user_idx
 ON public.bb_fcm_devices_v1(user_id) WHERE enabled;
CREATE TABLE IF NOT EXISTS public.bb_fcm_deliveries_v1 (
 event_key text NOT NULL REFERENCES public.bb_notification_events_v2(event_key) ON DELETE CASCADE,
 token text NOT NULL REFERENCES public.bb_fcm_devices_v1(token) ON DELETE CASCADE,
 status text NOT NULL DEFAULT 'claimed'
   CHECK (status IN ('claimed','sent','failed','invalid')),
 last_status_code integer,
 attempted_at timestamptz NOT NULL DEFAULT now(),
 finished_at timestamptz,
 PRIMARY KEY(event_key,token)
);

ALTER TABLE public.bb_fcm_config_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bb_fcm_devices_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bb_fcm_deliveries_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.bb_fcm_config_v1 FROM PUBLIC,anon,authenticated;
REVOKE ALL ON public.bb_fcm_devices_v1 FROM PUBLIC,anon,authenticated;
REVOKE ALL ON public.bb_fcm_deliveries_v1 FROM PUBLIC,anon,authenticated;

-- Verify cloud parity, credentials are absent, no user-facing policies and
-- no unexpected data are inserted by Code Sync.
DO $bb_fcm_verify$
DECLARE t text; spec jsonb; x record; actual_type text; actual_nullable text;
DECLARE kcount integer; existing_count bigint;
BEGIN
 FOR t,spec IN SELECT * FROM (VALUES
  ('bb_fcm_config_v1','{"id":"smallint:NO","enabled":"boolean:NO","updated_at":"timestamp with time zone:NO"}'::jsonb),
  ('bb_fcm_devices_v1','{"token":"text:NO","user_id":"uuid:NO","application_id":"text:NO","enabled":"boolean:NO","created_at":"timestamp with time zone:NO","updated_at":"timestamp with time zone:NO","last_registered_at":"timestamp with time zone:NO"}'::jsonb),
  ('bb_fcm_deliveries_v1','{"event_key":"text:NO","token":"text:NO","status":"text:NO","last_status_code":"integer:YES","attempted_at":"timestamp with time zone:NO","finished_at":"timestamp with time zone:YES"}'::jsonb)
 ) AS specs(name,columns) LOOP
   IF NOT EXISTS(SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                 WHERE n.nspname='public' AND c.relname=t AND c.relkind='r' AND c.relrowsecurity)
     THEN RAISE EXCEPTION 'CODE_SYNC_STOP: public.% table missing or RLS disabled',t;
   END IF;
   SELECT count(*) INTO kcount FROM information_schema.columns
   WHERE table_schema='public' AND table_name=t;
   IF kcount<>(SELECT count(*) FROM jsonb_object_keys(spec)) THEN
     RAISE EXCEPTION 'CODE_SYNC_STOP: public.% has unexpected extra/missing columns',t;
   END IF;
   FOR x IN SELECT key,value FROM jsonb_each_text(spec) LOOP
     SELECT data_type,is_nullable INTO actual_type,actual_nullable
       FROM information_schema.columns
       WHERE table_schema='public' AND table_name=t AND column_name=x.key;
     IF NOT FOUND OR (actual_type||':'||actual_nullable) IS DISTINCT FROM x.value THEN
       RAISE EXCEPTION 'CODE_SYNC_STOP: public.%.% differs from Cloud',t,x.key;
     END IF;
   END LOOP;
   IF EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename=t) THEN
     RAISE EXCEPTION 'CODE_SYNC_STOP: unexpected FCM local access policy public.%',t;
   END IF;
 END LOOP;
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.bb_fcm_config_v1'::regclass AND contype='p')
    OR NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.bb_fcm_devices_v1'::regclass AND contype='p')
    OR NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.bb_fcm_deliveries_v1'::regclass AND contype='p')
    OR NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.bb_fcm_deliveries_v1'::regclass AND contype='f' AND confrelid='public.bb_fcm_devices_v1'::regclass)
    OR NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.bb_fcm_deliveries_v1'::regclass AND contype='f' AND confrelid='public.bb_notification_events_v2'::regclass)
    OR NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.bb_fcm_devices_v1'::regclass AND contype='f' AND confrelid='auth.users'::regclass)
 THEN RAISE EXCEPTION 'CODE_SYNC_STOP: FCM primary/foreign key parity mismatch'; END IF;
END $bb_fcm_verify$;

-- Staging replay is blocked even under 08C session_replication_role=replica.
-- Keep all three local infrastructure tables empty unless explicitly used by
-- a local service outside Cloud -> Local sync.
DO $bb_fcm_guard$
DECLARE t text; installed oid;
BEGIN
 FOREACH t IN ARRAY ARRAY[
   'bb_fcm_config_v1','bb_fcm_devices_v1','bb_fcm_deliveries_v1'
 ] LOOP
   SELECT tgfoid INTO installed FROM pg_trigger
    WHERE tgrelid=format('public.%I',t)::regclass
      AND tgname='bb_local_business_only_replay_guard_v1' AND NOT tgisinternal;
   IF installed IS NOT NULL AND installed<>'private.bb_local_reject_infrastructure_replay_v1()'::regprocedure::oid THEN
     RAISE EXCEPTION 'CODE_SYNC_STOP: unapproved infrastructure replay trigger public.%',t;
   END IF;
   IF installed IS NULL THEN
     EXECUTE format(
       'CREATE TRIGGER bb_local_business_only_replay_guard_v1 BEFORE INSERT OR UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION private.bb_local_reject_infrastructure_replay_v1()',t);
   END IF;
   EXECUTE format('ALTER TABLE public.%I ENABLE ALWAYS TRIGGER bb_local_business_only_replay_guard_v1',t);
   IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE
      tgrelid=format('public.%I',t)::regclass
      AND tgname='bb_local_business_only_replay_guard_v1' AND tgenabled='A') THEN
     RAISE EXCEPTION 'CODE_SYNC_STOP: FCM ALWAYS replay guard missing on %',t;
   END IF;
 END LOOP;
END $bb_fcm_guard$;
