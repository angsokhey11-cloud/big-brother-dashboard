-- BIG BROTHER Local Brain V5/V6
-- Fix only the ambiguous/missing alias in salary-save salary-advance lookup.
-- No salary, staff, expense, or payment data changes.
DO $bb_salary_advance_alias_v2$
DECLARE
  v_def text;
  v_before text;
  v_old_month text := 'date_trunc(''month'',salary_month)::date AS month';
  v_new_month text := 'date_trunc(''month'',a.salary_month)::date AS month';
  v_old_from text := 'FROM public.staff_salary_advance_requests' || chr(10) || '    WHERE staff_id=st.staff_id AND status IN';
  v_new_from text := 'FROM public.staff_salary_advance_requests a' || chr(10) || '    WHERE a.staff_id=st.staff_id AND a.status IN';
BEGIN
  SELECT pg_get_functiondef('public.bb_staff_relation_admin_save_salary(text,numeric,date,numeric,numeric,numeric,text,text)'::regprocedure) INTO v_def;
  v_before := v_def;
  v_def := replace(v_def, v_old_month, v_new_month);
  v_def := replace(v_def, v_old_from, v_new_from);
  IF position(v_new_month IN v_def) = 0 OR position(v_new_from IN v_def) = 0 THEN
    RAISE EXCEPTION 'SALARY_ALIAS_V2: unexpected salary-save function; no changes applied';
  END IF;
  IF v_def IS DISTINCT FROM v_before THEN
    EXECUTE v_def;
    RAISE NOTICE 'SALARY_ALIAS_V2: qualified salary_month and salary-advance table alias';
  ELSE
    RAISE NOTICE 'SALARY_ALIAS_V2: already fixed';
  END IF;
END
$bb_salary_advance_alias_v2$;
