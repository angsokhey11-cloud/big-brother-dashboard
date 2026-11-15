-- SUPERSEDED (01-Nov-2026): DO NOT DEPLOY OR WIRE INTO CLOSE SELECTED.
-- Earlier forensic prototype intentionally retains reversed cash in the old
-- invoice-list SHAPE; that shape risks making approved cash selectable again.
-- The approved-only historical display design is now in
-- CI-DCC-APPROVED-CASH-HISTORY-STAGED.sql, tested against approved Close IDs.
-- Keep this older function only as a regression comparison for disappearing
-- cash receipts. It is not a valid production Daily Cash Collection endpoint.
-- BIG BROTHER V2: STAGED REPORTING-ONLY DCC PROTOTYPE; NONPRODUCTION.
-- Derived from CURRENT Cloud bb_dcc_invoice_list() 01-Nov-2026.
-- Does NOT post or infer any refund. Cash receipt remains gross.
-- Adds a provisional cashRefundReviewRequired flag for reconciliation only.
-- New function name prevents replacement of existing RPC. Do NOT deploy as-is.
-- Real close-selected UI must prohibit double-collection and the future refund
-- workflow must record actual cash/bank outflow before marking reconciled.

CREATE OR REPLACE FUNCTION public.bb_dcc_invoice_list_v2_staged()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_rows jsonb;
begin
  if not public.bb_has_module_access('daily_cash_collection','view') then
    raise exception 'Daily Cash Collection access denied';
  end if;

  with cash_payments as (
    select
      p.invoice_id,
      min(p.payment_date) as cash_date,
      upper(coalesce(max(nullif(trim(p.currency),'')),'USD')) as cash_currency,
      max(coalesce(p.exchange_rate,0)) as cash_exchange_rate,
      sum(coalesce(p.amount,0)) as cash_amount,
      jsonb_agg(p.payment_id order by p.payment_date,p.created_at,p.payment_id) as cash_payment_ids
    from public.payments p
    where lower(trim(coalesce(p.payment_method,'')))='cash'
      and lower(trim(coalesce(p.payment_source,'')))='invoice'
      and coalesce(p.amount,0)>0
      and upper(coalesce(p.currency,'USD')) in ('USD','KHR')
    group by p.invoice_id
  )
  select coalesce(jsonb_agg(row_json order by sort_date desc, invoice_no desc),'[]'::jsonb)
  into v_rows
  from (
    select
      coalesce(cp.cash_date,i.invoice_date) as sort_date,
      i.invoice_no,
      jsonb_build_object(
        'invoiceId',i.invoice_id,
        'invoiceNo',i.invoice_no,
        'invoiceDate',coalesce(cp.cash_date,i.invoice_date)::text,
        'customerId',coalesce(i.customer_id,''),
        'customer',coalesce(i.customer_name_snapshot,''),
        'phone',coalesce(c.phone,''),
        'address',coalesce(c.address,''),
        'locationCode',coalesce(i.location_code,c.location_code,''),
        'salespersonStaffId',coalesce(i.salesperson_staff_id,''),
        'salesperson',coalesce(i.salesperson_name_snapshot,''),
        'paymentMethod','Cash',
        'currency',cp.cash_currency,
        'exchangeRate',case when cp.cash_exchange_rate>0 then cp.cash_exchange_rate else coalesce(i.exchange_rate,1) end,
        'subtotal',coalesce(i.subtotal,0),
        'discount',coalesce(i.discount,0),
        'grandTotal',coalesce(i.grand_total,0),
        'amountPaid',coalesce(cp.cash_amount,0),
        'cashAmount',coalesce(cp.cash_amount,0),
        'cashPaymentIds',coalesce(cp.cash_payment_ids,'[]'::jsonb),
        'reportEventType','CASH_RECEIPT',
        'reversalAmount',coalesce(i.reversal_amount,0),
        'netInvoiceValue',greatest(coalesce(i.grand_total,0)-coalesce(i.reversal_amount,0),0),
        'cashRefundReviewRequired',coalesce(cp.cash_amount,0)>greatest(coalesce(i.grand_total,0)-coalesce(i.reversal_amount,0),0)+0.005,
        'outstanding',coalesce(i.outstanding,0),
        'status',coalesce(i.status,''),
        'invoiceType',case when coalesce(i.outstanding,0)>0 then 'Credit' else 'Paid' end,
        'dueDate',coalesce(i.due_date::text,''),
        'bankPayment','',
        'bankReference','',
        'batchNumber',coalesce(i.batch_number,''),
        'shippingTo',coalesce(i.shipping_to_legacy,''),
        'note',coalesce(i.note,'')
      ) row_json
    from cash_payments cp
    join public.invoices i on i.invoice_id=cp.invoice_id
    left join public.customers c on c.customer_id=i.customer_id
    where public.bb_has_location_access(coalesce(i.location_code,c.location_code,''))
      -- Keep received cash visible even when the invoice is reversed.
      -- Refund settlement is a separate, explicit, auditable transaction.
  ) q;

  return jsonb_build_object(
    'success',true,
    'revision',public.bb_dcc_revision(),
    'invoices',v_rows,
    'access',public.bb_dcc_access_profile()
  );
end;
$function$;

REVOKE ALL ON FUNCTION public.bb_dcc_invoice_list_v2_staged() FROM PUBLIC;
