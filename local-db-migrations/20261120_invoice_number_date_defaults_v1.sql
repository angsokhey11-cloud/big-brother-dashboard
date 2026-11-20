CREATE OR REPLACE FUNCTION public.bb_sales_batch_next_invoice_no(p_batch_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ declare v_no text; v_date date; begin if not public.bb_is_active_user() or not public.bb_has_module_access('invoice_generator','create') then raise exception 'Access denied'; end if; if not exists(select 1 from jsonb_array_elements(coalesce(public.bb_sales_open_batches()->'batches','[]'::jsonb)) x where x->>'batchId'=p_batch_id) then raise exception 'Batch access denied'; end if; select invoice_no,invoice_date into v_no,v_date from public.invoices where batch_number=p_batch_id order by created_at desc nulls last,invoice_no desc limit 1; return jsonb_build_object('success',true,'invoiceDate',coalesce(v_date,(select selling_date_from from public.stock_batches where batch_id=p_batch_id)),'invoiceNo',case when v_no ~ '^INV-[0-9]+$' then 'INV-'||lpad((substring(v_no from '[0-9]+$')::bigint+1)::text,greatest(length(v_no)-4,length((substring(v_no from '[0-9]+$')::bigint+1)::text)),'0') else 'INV-' end); end; $function$;

CREATE OR REPLACE FUNCTION public.bb_sales_next_invoice_no_core_access_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ declare v_next bigint; begin if not public.bb_is_active_user() then raise exception 'BIG BROTHER access denied'; end if; select greatest(12304,coalesce(max(substring(invoice_no from '[0-9]+$')::bigint),0))+1 into v_next from public.invoices where nullif(trim(coalesce(batch_number,'')),'') is null and invoice_no ~ '^INV-[0-9]+$'; return jsonb_build_object('success',true,'invoiceNo','INV-'||v_next::text); end; $function$;
REVOKE ALL ON FUNCTION public.bb_sales_batch_next_invoice_no(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.bb_sales_batch_next_invoice_no(text) TO authenticated;
NOTIFY pgrst, 'reload schema';
