-- BIG BROTHER Cloud + Local V5/V6 notification-route parity, 29-Oct-2026.
-- New Batch Stock and Batch Transfer staff notifications must open
-- Sales Support > Your Stock, not the admin-oriented Batch Report.
-- Notification-only change: never alter stock, invoices, payments, or payroll.
-- No new events are created; historical assignment alerts are re-pointed.
-- Safe to re-run; fail closed if the notification capture function has drifted.

DO $bb_route_patch$
DECLARE
  v_definition text;
  v_old constant text := '''batch-report''';
  v_new constant text := '''sales-support-your-stock''';
  v_occurrences integer;
BEGIN
  IF to_regprocedure('public.bb_notification_v2_capture()') IS NULL
     OR to_regclass('public.bb_notification_events_v2') IS NULL THEN
    RAISE EXCEPTION 'BB_ROUTE_STOP: notification events/capture function missing';
  END IF;

  SELECT pg_get_functiondef('public.bb_notification_v2_capture()'::regprocedure)
    INTO v_definition;

  IF position('ASSIGN:' IN v_definition)=0
     OR position('BATCH_STOCK' IN v_definition)=0 THEN
    RAISE EXCEPTION 'BB_ROUTE_STOP: stock-assignment notification logic differs';
  END IF;

  v_occurrences := (length(v_definition)-length(replace(v_definition,v_old,''))) / length(v_old);
  IF v_occurrences = 1 THEN
    EXECUTE replace(v_definition,v_old,v_new);
  ELSIF v_occurrences = 0 AND position(v_new IN v_definition)>0 THEN
    -- Route already patched; no-op.
    NULL;
  ELSE
    RAISE EXCEPTION 'BB_ROUTE_STOP: expected exactly one old route; found %',v_occurrences;
  END IF;
END
$bb_route_patch$;

UPDATE public.bb_notification_events_v2
   SET route='sales-support-your-stock'
 WHERE category='Stock'
   AND audience='staff'
   AND event_key LIKE 'ASSIGN:%'
   AND route='batch-report';

DO $bb_route_verify$
DECLARE v_definition text;
BEGIN
  SELECT pg_get_functiondef('public.bb_notification_v2_capture()'::regprocedure)
    INTO v_definition;
  IF position('''sales-support-your-stock''' IN v_definition)=0
     OR position('''batch-report''' IN v_definition)>0
     OR EXISTS (
         SELECT 1 FROM public.bb_notification_events_v2
          WHERE category='Stock' AND audience='staff'
            AND event_key LIKE 'ASSIGN:%' AND route='batch-report'
       ) THEN
    RAISE EXCEPTION 'BB_ROUTE_STOP: route parity verification failed';
  END IF;
END
$bb_route_verify$;
