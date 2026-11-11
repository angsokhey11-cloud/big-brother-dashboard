-- A/R Sync Bank: permit authorized Accounts Receivable readers to use the same
-- read-only bulk bank balance sync as Invoice Generator. Keep existing location
-- access checks, original rows/amounts, and per-account cache schema unchanged.
-- No financial records are changed by this function.
CREATE OR REPLACE FUNCTION public.bb_invoice_bank_bulk_sync()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_data jsonb;
begin
 if auth.uid() is null or not (
  public.bb_has_module_access('invoice_generator','create')
  or public.bb_has_module_access('accounts_receivable','view')
  or public.bb_is_admin()
 ) then
  raise exception 'Invoice Generator or Accounts Receivable access required';
 end if;
 select coalesce(jsonb_agg(jsonb_build_object(
 'customer_id',b.customer_id,'transaction_id',b.transaction_id,
 'original_amount',b.original_amount,'used_amount',b.used_amount,'remaining_amount',b.remaining_amount,
 'amount',b.remaining_amount,'currency',b.currency,'invoice_currency',coalesce(b.invoice_currency,b.currency),
 'approved_exchange_rate',b.approved_exchange_rate,'received_date',b.received_date,
 'equivalent_remaining',case when b.currency=coalesce(b.invoice_currency,b.currency) then b.remaining_amount when b.currency='KHR' then b.remaining_amount/nullif(b.approved_exchange_rate,0) else b.remaining_amount*b.approved_exchange_rate end,
 'equivalent_amount',case when b.currency=coalesce(b.invoice_currency,b.currency) then b.remaining_amount when b.currency='KHR' then b.remaining_amount/nullif(b.approved_exchange_rate,0) else b.remaining_amount*b.approved_exchange_rate end,
 'bank_name',coalesce(t.bank_name,'')
 )), '[]'::jsonb) into v_data
 from public.bb_bank_balance_snapshot b
 join public.customers c on c.customer_id=b.customer_id and coalesce(c.active,true)=true
 left join public.bb_verified_bank_transactions t on t.transaction_id=b.transaction_id
 where b.status='AVAILABLE' and b.remaining_amount>0
 and (public.bb_is_admin() or public.bb_has_location_access(coalesce(c.location_code,'')));
 return v_data;
end $function$;
