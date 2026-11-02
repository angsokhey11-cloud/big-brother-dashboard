-- BIG BROTHER Local Brain V5/V6 — minimal salary-save ambiguity fix.
-- Only adjusts the SQL name qualification in the existing routine.
-- Leaves salary, advances, payments, expenses, and authorizations unchanged.
DO $bb_salary_ambiguity_fix$
DECLARE
  v_definition text;
  v_old_month constant text := 'date_trunc(''month'',salary_month)::date AS month';
  v_new_month constant text := 'date_trunc(''month'',a.salary_month)::date AS month';
  v_old_from constant text := E'FROM public.staff_salary_advance_requests\n    WHERE staff_id=st.staff_id AND status IN';
  v_new_from constant text := E'FROM public.staff_salary_advance_requests a\n    WHERE a.staff_id=st.staff_id AND a.status IN';
BEGIN
  SELECT pg_get_functiondef('public.bb_staff_relation_admin_save_salary(text,numeric,date,numeric,numeric,numeric,text,text)'::regprocedure)
    INTO v_definition;

  IF position(v_new_month IN v_definition) > 0 AND position(v_new_from IN v_definition) > 0 THEN
    RAISE NOTICE 'BB_SALARY_MONTH_AMBIGUITY: already fixed';
    RETURN;
  END IF;

  IF position(v_old_month IN v_definition) = 0 OR position(v_old_from IN v_definition) = 0 THEN
    RAISE EXCEPTION 'BB_SALARY_MONTH_AMBIGUITY: unexpected Local salary function; no change applied';
  END IF;

  v_definition := replace(v_definition, v_old_month, v_new_month);
  v_definition := replace(v_definition, v_old_from, v_new_from);
  EXECUTE v_definition;
  RAISE NOTICE 'BB_SALARY_MONTH_AMBIGUITY: salary-advance month column qualified';
END;
$bb_salary_ambiguity_fix$;
