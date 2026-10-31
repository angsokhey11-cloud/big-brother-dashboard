-- BIG BROTHER — STAGED, NOT DEPLOYED. Source-specific Batch Reversal.
-- Requires full coordination with 20261031_source_aware_batch_sale_and_back_sale_STAGED.sql
-- and compatible source selectors. No historic-data UPDATE statements.
-- Source validation is performed in BEFORE trigger and COGS from original sale.
CREATE OR REPLACE FUNCTION public.bb_batch_return_allocate_internal()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
 v_invoice public.invoices%rowtype;
 v_line public.invoice_lines%rowtype;
 v_batch public.stock_batches%rowtype;
 v_entry jsonb;
 v_input jsonb;
 v_result jsonb:='[]'::jsonb;
 v_code text;
 v_expected_code text;
 v_qty numeric;
 v_p numeric;
 v_z numeric;
 v_sold_p numeric;
 v_sold_z numeric;
 v_prior_p numeric;
 v_prior_z numeric;
 v_remaining_p numeric;
 v_remaining_z numeric;
 v_total numeric:=0;
 v_count int:=0;
 v_submitted boolean:=false;
BEGIN
 SELECT * INTO v_invoice FROM public.invoices WHERE invoice_id=new.invoice_id;
 IF NOT FOUND OR v_invoice.batch_id IS NULL THEN RETURN new; END IF;
 PERFORM pg_advisory_xact_lock(hashtext('BB_STOCK_WRITE'));
 SELECT * INTO v_batch FROM public.stock_batches WHERE batch_id=v_invoice.batch_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Original Batch does not exist'; END IF;
 IF upper(coalesce(v_batch.status,''))='CLOSED' AND NOT EXISTS (
   SELECT 1 FROM public.bb_postclose_reversal_routes r
   WHERE r.return_id=new.return_id AND r.invoice_id=new.invoice_id
     AND r.original_batch_id=v_batch.batch_id
 ) THEN
   RAISE EXCEPTION 'Batch % is CLOSED; choose a post-close return destination',v_batch.batch_id;
 END IF;
 IF upper(coalesce(v_batch.status,'')) IN ('CANCELLED','CANCELED') THEN
   RAISE EXCEPTION 'Batch % is cancelled',v_batch.batch_id;
 END IF;
 SELECT * INTO v_line FROM public.invoice_lines il WHERE il.invoice_id=new.invoice_id AND il.line_id=new.line_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Original invoice line not found for source validation'; END IF;
 IF new.qty IS NULL OR new.qty<=0 THEN RAISE EXCEPTION 'Reversal Qty must be greater than zero'; END IF;

 v_submitted:=jsonb_typeof(new.stock_allocation_json)='array'
               AND jsonb_array_length(new.stock_allocation_json)>0;
 IF v_submitted THEN
   v_input:=new.stock_allocation_json;
 ELSIF upper(coalesce(v_line.entry_type,'EXACT'))='EXACT' THEN
   -- Legacy client compatibility: exact single-source returns may auto-pick the
   -- only original sold source. Mixed-source returns must be explicitly selected.
   v_input:=jsonb_build_array(jsonb_build_object('productCode',v_line.product_code,'qty',new.qty));
 ELSE
   RAISE EXCEPTION 'Group reversal requires physical Product / Purchased / Zero-Cost source quantities';
 END IF;
 IF jsonb_typeof(v_input)<>'array' OR jsonb_array_length(v_input)=0 THEN
   RAISE EXCEPTION 'Reversal source allocation is required';
 END IF;

 FOR v_entry IN SELECT value FROM jsonb_array_elements(v_input) LOOP
   v_code:=nullif(trim(coalesce(v_entry->>'productCode','')),'');
   v_qty:=nullif(v_entry->>'qty','')::numeric;
   IF v_code IS NULL OR v_qty IS NULL OR v_qty<=0 THEN
     RAISE EXCEPTION 'Invalid Batch reversal product allocation';
   END IF;
   IF upper(coalesce(v_line.entry_type,'EXACT'))='EXACT' AND v_code IS DISTINCT FROM v_line.product_code THEN
     RAISE EXCEPTION 'Reversal source product % differs from original invoice product %',v_code,v_line.product_code;
   END IF;
   IF EXISTS (SELECT 1 FROM jsonb_array_elements(v_result) a WHERE a->>'productCode'=v_code) THEN
     RAISE EXCEPTION 'Duplicate Batch reversal product %',v_code;
   END IF;

   -- Require a real BATCH-INVOICE:<lineId>:<product>:<source> sale ledger entry:
   -- invoice numbers can be duplicated, so the line_id is the identity.
   SELECT
     coalesce(sum(sa.qty) FILTER(WHERE sa.from_bucket='BATCH_PENDING'),0),
     coalesce(sum(sa.qty) FILTER(WHERE sa.from_bucket='BATCH_ZERO_COST'),0)
   INTO v_sold_p,v_sold_z
   FROM public.stock_activity sa
   WHERE sa.movement_type='BATCH_SALE'
     AND sa.batch_id=v_invoice.batch_id
     AND sa.related_invoice_no=v_invoice.invoice_no
     AND sa.customer_id IS NOT DISTINCT FROM v_invoice.customer_id
     AND sa.product_code=v_code
     AND split_part(sa.client_request_id,':',1)='BATCH-INVOICE'
     AND split_part(sa.client_request_id,':',2)=v_line.line_id;
   IF v_sold_p+v_sold_z<=0.000001 THEN
     RAISE EXCEPTION 'Original Batch Invoice source is not traceable for %; manual audit required',v_code;
   END IF;

   SELECT
     coalesce(sum(sa.qty) FILTER(WHERE sa.to_bucket IN ('BATCH_PENDING','WAREHOUSE_GOOD')),0),
     coalesce(sum(sa.qty) FILTER(WHERE sa.to_bucket IN ('BATCH_ZERO_COST','WAREHOUSE_ZERO_COST')),0)
   INTO v_prior_p,v_prior_z
   FROM public.sales_returns sr
   JOIN public.stock_activity sa ON sa.reference_no=sr.return_id
   WHERE sr.invoice_id=v_invoice.invoice_id AND sr.line_id=v_line.line_id
     AND sr.return_id IS DISTINCT FROM new.return_id
     AND sa.product_code=v_code
     AND sa.movement_type IN ('BATCH_SALE_RETURN','POSTCLOSE_SALE_RETURN')
     AND sa.from_bucket='EXTERNAL';
   IF v_prior_p>v_sold_p+0.000001 OR v_prior_z>v_sold_z+0.000001 THEN
     RAISE EXCEPTION '% has historical reversal source imbalance: review required',v_code;
   END IF;
   v_remaining_p:=greatest(v_sold_p-v_prior_p,0);
   v_remaining_z:=greatest(v_sold_z-v_prior_z,0);
   IF v_submitted THEN
     IF jsonb_typeof(v_entry)<>'object' OR NOT(v_entry?'purchasedQty' AND v_entry?'zeroCostQty') THEN
       RAISE EXCEPTION 'Return % must specify Purchased Qty and Zero-Cost Qty',v_code;
     END IF;
     v_p:=nullif(v_entry->>'purchasedQty','')::numeric;
     v_z:=nullif(v_entry->>'zeroCostQty','')::numeric;
   ELSE
     IF v_remaining_p>0.000001 AND v_remaining_z>0.000001 THEN
       RAISE EXCEPTION '% had Mixed source sales; choose exact Purchased / Zero-Cost Return Qty',v_code;
     END IF;
     v_p:=CASE WHEN v_remaining_p>0.000001 THEN v_qty ELSE 0 END;
     v_z:=CASE WHEN v_remaining_p>0.000001 THEN 0 ELSE v_qty END;
   END IF;
   IF v_p IS NULL OR v_z IS NULL OR v_p<0 OR v_z<0
      OR abs(v_p+v_z-v_qty)>0.000001 THEN
      RAISE EXCEPTION '%: Returned Purchased + Zero-Cost must equal product return Qty %',v_code,v_qty;
   END IF;
   IF v_p>v_remaining_p+0.000001 OR v_z>v_remaining_z+0.000001 THEN
     RAISE EXCEPTION '%: return exceeds original eligible source balance (Purchased %, Zero-Cost %)',
        v_code,v_remaining_p,v_remaining_z;
   END IF;
   v_result:=v_result||jsonb_build_array(jsonb_build_object(
     'productCode',v_code,'qty',v_qty,'purchasedQty',v_p,'zeroCostQty',v_z
   ));
   v_count:=v_count+1;
   v_total:=v_total+v_qty;
 END LOOP;
 IF upper(coalesce(v_line.entry_type,'EXACT'))='EXACT' AND v_count<>1 THEN
   RAISE EXCEPTION 'Exact Invoice line requires precisely one return product';
 END IF;
 IF abs(v_total-new.qty)>0.000001 THEN
   RAISE EXCEPTION 'Physical Product source total % does not equal Reversal Qty %',v_total,new.qty;
 END IF;
 new.stock_allocation_json:=v_result;
 RETURN new;
END;
$function$;

CREATE OR REPLACE FUNCTION public.bb_invoice_reversal_save_v2(p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$


declare


  v_invoice
    public.invoices%rowtype;


  v_line
    public.invoice_lines%rowtype;


  v_source
    record;


  v_lines jsonb :=

    coalesce(
      p_payload->'lines',
      '[]'::jsonb
    );


  v_item jsonb;

  v_elem jsonb;


  v_invoice_no text :=

    trim(
      coalesce(
        p_payload->>'invoiceNo',
        ''
      )
    );


  v_return_date date;


  v_return_type text :=

    trim(
      coalesce(
        p_payload->>'returnType',
        'Partial Reversal'
      )
    );


  v_reason text :=

    trim(
      coalesce(
        p_payload->>'reason',
        ''
      )
    );


  v_note text :=

    nullif(

      trim(
        coalesce(
          p_payload->>'note',
          ''
        )
      ),

      ''

    );


  v_qty numeric;

  v_returned numeric;

  v_available numeric;

  v_requested numeric;


  v_line_id text;

  v_return_id text;


  v_exact_code text;

  v_group_code text;


  v_alloc_input jsonb;

  v_alloc_norm jsonb;

  v_saved_alloc jsonb;


  v_source_name text;

  v_source_qty numeric;


  v_requested_purchased numeric;

  v_requested_zero numeric;

  v_alloc_total numeric;


  v_total numeric :=
    0;


  v_rows jsonb :=
    '[]'::jsonb;


  v_actor text;

  v_audit_id text;


  v_line_count integer :=
    0;


  v_payload_count integer;


begin


  /* ==========================================================
     ACCESS
     ========================================================== */

  if not public.bb_has_module_access(
    'invoice_reversal',
    'create'
  )
  then

    raise exception
      'Invoice Reversal create access denied';

  end if;



  /* ==========================================================
     VALIDATION
     ========================================================== */

  if v_invoice_no = '' then

    raise exception
      'Invoice No. is required';

  end if;


  if v_reason = '' then

    raise exception
      'Reversal reason is required';

  end if;


  if v_return_type not in (
    'Partial Reversal',
    'Full Reversal'
  )
  then

    raise exception
      'Invalid Reversal Type';

  end if;



  begin


    v_return_date :=

      nullif(

        trim(
          coalesce(
            p_payload->>'returnDate',
            ''
          )
        ),

        ''

      )::date;


  exception
    when others then

      raise exception
        'Valid Reversal Date is required';

  end;



  if v_return_date is null then

    raise exception
      'Reversal Date is required';

  end if;



  if

    jsonb_typeof(
      v_lines
    )
    <>
    'array'

    or

    jsonb_array_length(
      v_lines
    )
    =
    0

  then

    raise exception
      'At least one reversed product line is required';

  end if;



  /* ==========================================================
     LOCK INVOICE
     ========================================================== */

  select *

  into
    v_invoice

  from public.invoices i

  where

    lower(
      i.invoice_no
    )
    =
    lower(
      v_invoice_no
    )

  for update;



  if not found then

    raise exception
      'Invoice was not found';

  end if;



  if not public.bb_has_location_access(
    v_invoice.location_code
  )
  then

    raise exception
      'You do not have access to this invoice location';

  end if;



  /* ==========================================================
     DUPLICATE PAYLOAD LINE CHECK
     ========================================================== */

  select
    count(*)

  into
    v_payload_count

  from jsonb_array_elements(
    v_lines
  );



  if

    v_payload_count

    <>

    (

      select

        count(
          distinct trim(
            x->>'lineId'
          )
        )

      from jsonb_array_elements(
        v_lines
      ) x

    )

  then

    raise exception
      'Duplicate invoice lines are not allowed in one reversal';

  end if;



  /* ==========================================================
     FULL REVERSAL CHECK
     ========================================================== */

  if v_return_type = 'Full Reversal' then


    for v_line in

      select *

      from public.invoice_lines il

      where il.invoice_id =
            v_invoice.invoice_id

      order by
        il.line_no

    loop


      select

        coalesce(
          sum(
            sr.qty
          ),
          0
        )

      into
        v_returned

      from public.sales_returns sr

      where sr.line_id =
            v_line.line_id;



      v_available :=

        greatest(

          coalesce(
            v_line.qty,
            0
          )

          -

          v_returned,

          0

        );



      if v_available > 0.000001 then


        select

          coalesce(

            sum(

              nullif(
                trim(
                  x->>'qty'
                ),
                ''
              )::numeric

            ),

            0

          )

        into
          v_requested

        from jsonb_array_elements(
          v_lines
        ) x

        where

          trim(
            coalesce(
              x->>'lineId',
              ''
            )
          )
          =
          v_line.line_id;



        if

          abs(
            v_requested
            -
            v_available
          )
          >
          0.000001

        then

          raise exception

            'Full Reversal must reverse all remaining quantity for line %',

            v_line.line_id;

        end if;


      end if;


    end loop;


  end if;



  /* ==========================================================
     SAVE EACH RETURN LINE
     ========================================================== */

  for v_item in

    select value

    from jsonb_array_elements(
      v_lines
    )

  loop


    v_line_id :=

      trim(
        coalesce(
          v_item->>'lineId',
          ''
        )
      );


    if v_line_id = '' then

      raise exception
        'Invoice Line ID is required';

    end if;



    begin


      v_qty :=

        nullif(

          trim(
            coalesce(
              v_item->>'qty',
              ''
            )
          ),

          ''

        )::numeric;


    exception
      when others then

        raise exception

          'Invalid reversed quantity for line %',

          v_line_id;

    end;



    if

      v_qty is null

      or

      v_qty <= 0

    then

      raise exception

        'Reversed quantity must be greater than zero for line %',

        v_line_id;

    end if;



    select *

    into
      v_line

    from public.invoice_lines il

    where

      il.line_id =
      v_line_id

      and

      il.invoice_id =
      v_invoice.invoice_id

    for update;



    if not found then

      raise exception

        'Invoice line not found: %',

        v_line_id;

    end if;



    select

      coalesce(
        sum(
          sr.qty
        ),
        0
      )

    into
      v_returned

    from public.sales_returns sr

    where sr.line_id =
          v_line.line_id;



    v_available :=

      greatest(

        coalesce(
          v_line.qty,
          0
        )

        -

        v_returned,

        0

      );



    if

      v_qty
      >
      v_available
      +
      0.000001

    then

      raise exception

        'Reversed quantity % exceeds available quantity % for %',

        v_qty,

        v_available,

        coalesce(
          v_line.product_name_snapshot,
          v_line.display_product_code,
          v_line.line_id
        );

    end if;



    /* ========================================================
       PRODUCT IDENTITY
       ======================================================== */

    if

      upper(
        coalesce(
          v_line.entry_type,
          'EXACT'
        )
      )
      =
      'GROUP'

    then


      v_exact_code :=
        null;


      v_group_code :=

        coalesce(

          nullif(
            v_line.product_group_code,
            ''
          ),

          nullif(
            v_line.display_product_code,
            ''
          )

        );


      if

        v_group_code is null

        or

        not exists(

          select 1

          from public.product_groups pg

          where pg.group_code =
                v_group_code

        )

      then

        raise exception

          'Invoice GROUP line % has no valid Product Group',

          v_line.line_id;

      end if;



    else


      v_exact_code :=
        v_line.product_code;


      v_group_code :=
        null;


      if

        v_exact_code is null

        or

        not exists(

          select 1

          from public.products p

          where p.product_code =
                v_exact_code

        )

      then

        raise exception

          'Invoice line % has no valid exact Product Code',

          v_line.line_id;

      end if;


    end if;



    v_alloc_norm:=null;
     -- Keep the accountant's exact physical-product source selection for Batch,
     -- so the BEFORE return trigger can validate it against the original sale.
     if v_invoice.batch_id is not null and jsonb_typeof(v_item->'stockAllocations')='array'
       and jsonb_array_length(v_item->'stockAllocations')>0 then
       v_alloc_norm:=v_item->'stockAllocations';
     end if;



    /* ========================================================
       DIRECT SALE SOURCE VALIDATION
       ======================================================== */

    if v_invoice.batch_id is null then


      if

        upper(
          coalesce(
            v_line.entry_type,
            'EXACT'
          )
        )
        <>
        'EXACT'

      then

        raise exception
          'Direct Sale Reversal supports exact products only';

      end if;



      select *

      into
        v_source

      from
        public.bb_invoice_reversal_direct_source_balance_v2_internal(
          v_line.line_id
        );



      if

        coalesce(
          v_source.ambiguous_previous_return_qty,
          0
        )
        >
        0.000001

      then

        raise exception

          '% has an older Mixed reversal without source data. Manual review is required.',

          coalesce(
            v_line.product_name_snapshot,
            v_line.product_code
          );

      end if;



      v_requested_purchased :=
        0;


      v_requested_zero :=
        0;


      v_alloc_total :=
        0;


      v_alloc_norm :=
        '[]'::jsonb;


      v_alloc_input :=
        v_item->'stockAllocations';



      /* ------------------------------------------------------
         Single-source Direct Sale can auto-select.

         Mixed Direct Sale must explicitly tell us the returned
         Purchased Qty and Zero-Cost Qty.
         ------------------------------------------------------ */

      if

        jsonb_typeof(
          v_alloc_input
        )
        <>
        'array'

        or

        jsonb_array_length(
          v_alloc_input
        )
        =
        0

      then


        if

          v_source.remaining_purchased_qty
          >
          0.000001

          and

          v_source.remaining_zero_cost_qty
          <=
          0.000001

        then


          v_alloc_input :=

            jsonb_build_array(

              jsonb_build_object(

                'source',
                  'PURCHASED',

                'qty',
                  v_qty

              )

            );



        elsif

          v_source.remaining_zero_cost_qty
          >
          0.000001

          and

          v_source.remaining_purchased_qty
          <=
          0.000001

        then


          v_alloc_input :=

            jsonb_build_array(

              jsonb_build_object(

                'source',
                  'ZERO_COST',

                'qty',
                  v_qty

              )

            );



        else


          raise exception

            '% is a Mixed Direct Sale. Purchased Return Qty and Zero-Cost Return Qty must be selected.',

            coalesce(
              v_line.product_name_snapshot,
              v_line.product_code
            );


        end if;


      end if;



      for v_elem in

        select value

        from jsonb_array_elements(
          v_alloc_input
        )

      loop


        v_source_name :=

          upper(

            replace(

              replace(

                trim(
                  coalesce(
                    v_elem->>'source',
                    ''
                  )
                ),

                '-',
                '_'

              ),

              ' ',
              '_'

            )

          );


        v_source_qty :=

          coalesce(

            nullif(
              v_elem->>'qty',
              ''
            )::numeric,

            0

          );



        if v_source_qty <= 0 then

          raise exception

            '% reversal source Qty must be greater than zero',

            coalesce(
              v_line.product_name_snapshot,
              v_line.product_code
            );

        end if;



        if v_source_name = 'PURCHASED' then


          v_requested_purchased :=

            v_requested_purchased
            +
            v_source_qty;



        elsif v_source_name = 'ZERO_COST' then


          v_requested_zero :=

            v_requested_zero
            +
            v_source_qty;



        else


          raise exception

            'Invalid Direct Sale reversal Stock Source: %',

            v_source_name;


        end if;



        v_alloc_total :=

          v_alloc_total
          +
          v_source_qty;


      end loop;



      if

        abs(
          v_alloc_total
          -
          v_qty
        )
        >
        0.000001

      then

        raise exception

          '% reversal source Qty % does not match Reversal Qty %',

          coalesce(
            v_line.product_name_snapshot,
            v_line.product_code
          ),

          v_alloc_total,

          v_qty;

      end if;



      if

        v_requested_purchased
        >
        v_source.remaining_purchased_qty
        +
        0.000001

      then

        raise exception

          '% Purchased Return Qty % exceeds remaining Purchased Sold Qty %',

          coalesce(
            v_line.product_name_snapshot,
            v_line.product_code
          ),

          v_requested_purchased,

          v_source.remaining_purchased_qty;

      end if;



      if

        v_requested_zero
        >
        v_source.remaining_zero_cost_qty
        +
        0.000001

      then

        raise exception

          '% Zero-Cost Return Qty % exceeds remaining Zero-Cost Sold Qty %',

          coalesce(
            v_line.product_name_snapshot,
            v_line.product_code
          ),

          v_requested_zero,

          v_source.remaining_zero_cost_qty;

      end if;



      v_alloc_norm :=
        '[]'::jsonb;



      if v_requested_purchased > 0 then


        v_alloc_norm :=

          v_alloc_norm

          ||

          jsonb_build_array(

            jsonb_build_object(

              'source',
                'PURCHASED',

              'qty',
                v_requested_purchased

            )

          );


      end if;



      if v_requested_zero > 0 then


        v_alloc_norm :=

          v_alloc_norm

          ||

          jsonb_build_array(

            jsonb_build_object(

              'source',
                'ZERO_COST',

              'qty',
                v_requested_zero

            )

          );


      end if;


    end if;



    /* ========================================================
       INSERT REVERSAL

       Existing Batch BEFORE trigger will create its own Batch
       stock allocation.

       Direct Sale keeps our source allocation.
       ======================================================== */

    v_return_id :=

      public.bb_next_prefixed_id(

        'public.sales_returns'::regclass,

        'return_id',

        'REV',

        4

      );



    insert into public.sales_returns(

      return_id,

      invoice_id,

      invoice_no_snapshot,

      return_date,

      customer_id,

      customer_name_snapshot,

      location_code,

      salesperson_staff_id,

      salesperson_name_snapshot,

      product_code,

      product_group_code,

      product_name_snapshot,

      qty,

      unit_price,

      return_amount,

      return_type,

      reason,

      note,

      source_created_at,

      line_id,

      stock_allocation_json

    )

    values(

      v_return_id,

      v_invoice.invoice_id,

      v_invoice.invoice_no,

      v_return_date,

      v_invoice.customer_id,

      v_invoice.customer_name_snapshot,

      v_invoice.location_code,

      v_invoice.salesperson_staff_id,

      v_invoice.salesperson_name_snapshot,

      v_exact_code,

      v_group_code,

      v_line.product_name_snapshot,

      v_qty,

      v_line.unit_price,

      v_qty
      *
      v_line.unit_price,

      v_return_type,

      v_reason,

      v_note,

      now(),

      v_line.line_id,

      v_alloc_norm

    )

    returning
      stock_allocation_json

    into
      v_saved_alloc;



    v_total :=

      v_total
      +
      (
        v_qty
        *
        v_line.unit_price
      );


    v_line_count :=
      v_line_count
      +
      1;



    v_rows :=

      v_rows

      ||

      jsonb_build_array(

        jsonb_build_object(

          'returnId',
            v_return_id,

          'lineId',
            v_line.line_id,

          'productCode',
            coalesce(
              v_exact_code,
              v_group_code,
              ''
            ),

          'productName',
            coalesce(
              v_line.product_name_snapshot,
              ''
            ),

          'qty',
            v_qty,

          'unitPrice',
            v_line.unit_price,

          'amount',
            v_qty
            *
            v_line.unit_price,

          'stockAllocations',
            v_saved_alloc

        )

      );


  end loop;



  /* ==========================================================
     AUDIT
     ========================================================== */

  select

    coalesce(
      s.staff_name,
      au.email
    )

  into
    v_actor


  from public.app_users au


  left join public.staff s

    on s.staff_id =
       au.staff_id


  where

    au.user_id =
    auth.uid()

    and

    au.active =
    true;



  v_audit_id :=

    public.bb_next_prefixed_id(

      'public.sales_database_edit_history'::regclass,

      'audit_id',

      'AUD',

      6

    );



  insert into public.sales_database_edit_history(

    audit_id,

    occurred_at,

    module,

    record_id,

    record_no,

    action,

    field_name,

    old_value,

    new_value,

    reason,

    admin_legacy_id,

    admin_name_snapshot

  )

  values(

    v_audit_id,

    now(),

    'Invoice Reversal V2',

    v_invoice.invoice_id,

    v_invoice.invoice_no,

    'CREATE',

    'Sales Return',

    null,

    jsonb_build_object(

      'returnType',
        v_return_type,

      'returnDate',
        v_return_date,

      'totalAmount',
        v_total,

      'lines',
        v_rows

    )::text,

    v_reason,

    null,

    coalesce(
      v_actor,
      'Supabase User'
    )

  );



  return

    jsonb_build_object(

      'success',
        true,

      'version',
        'INVOICE-REVERSAL-V2',

      'invoiceNo',
        v_invoice.invoice_no,

      'lineCount',
        v_line_count,

      'totalAmount',
        v_total,

      'returns',
        v_rows,

      'revision',
        public.bb_sales_history_revision()

    );


end;

$function$


CREATE OR REPLACE FUNCTION public.bb_invoice_reversal_save_by_id_v2(p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$


declare


  v_invoice
    public.invoices%rowtype;


  v_line
    public.invoice_lines%rowtype;


  v_source
    record;


  v_lines jsonb :=

    coalesce(
      p_payload->'lines',
      '[]'::jsonb
    );


  v_item jsonb;

  v_elem jsonb;


  v_invoice_no text :=

    trim(
      coalesce(
        p_payload->>'invoiceNo',
        ''
      )
    );


  v_invoice_id text :=
    trim(
      coalesce(
        p_payload->>'invoiceId',
        ''
      )
    );


  v_return_date date;


  v_return_type text :=

    trim(
      coalesce(
        p_payload->>'returnType',
        'Partial Reversal'
      )
    );


  v_reason text :=

    trim(
      coalesce(
        p_payload->>'reason',
        ''
      )
    );


  v_note text :=

    nullif(

      trim(
        coalesce(
          p_payload->>'note',
          ''
        )
      ),

      ''

    );


  v_qty numeric;

  v_returned numeric;

  v_available numeric;

  v_requested numeric;


  v_line_id text;

  v_return_id text;


  v_exact_code text;

  v_group_code text;


  v_alloc_input jsonb;

  v_alloc_norm jsonb;

  v_saved_alloc jsonb;


  v_source_name text;

  v_source_qty numeric;


  v_requested_purchased numeric;

  v_requested_zero numeric;

  v_alloc_total numeric;


  v_total numeric :=
    0;


  v_rows jsonb :=
    '[]'::jsonb;


  v_actor text;

  v_audit_id text;


  v_line_count integer :=
    0;


  v_payload_count integer;


begin


  /* ==========================================================
     ACCESS
     ========================================================== */

  if not public.bb_has_module_access(
    'invoice_reversal',
    'create'
  )
  then

    raise exception
      'Invoice Reversal create access denied';

  end if;



  /* ==========================================================
     VALIDATION
     ========================================================== */

  if v_invoice_id = '' then

    raise exception
      'Invoice ID is required';

  end if;


  if v_invoice_no = '' then

    raise exception
      'Invoice No. is required';

  end if;


  if v_reason = '' then

    raise exception
      'Reversal reason is required';

  end if;


  if v_return_type not in (
    'Partial Reversal',
    'Full Reversal'
  )
  then

    raise exception
      'Invalid Reversal Type';

  end if;



  begin


    v_return_date :=

      nullif(

        trim(
          coalesce(
            p_payload->>'returnDate',
            ''
          )
        ),

        ''

      )::date;


  exception
    when others then

      raise exception
        'Valid Reversal Date is required';

  end;



  if v_return_date is null then

    raise exception
      'Reversal Date is required';

  end if;



  if

    jsonb_typeof(
      v_lines
    )
    <>
    'array'

    or

    jsonb_array_length(
      v_lines
    )
    =
    0

  then

    raise exception
      'At least one reversed product line is required';

  end if;



  /* ==========================================================
     LOCK INVOICE
     ========================================================== */

  select *

  into
    v_invoice

  from public.invoices i

  where

    i.invoice_id = v_invoice_id

  for update;



  if not found then

    raise exception
      'Invoice was not found';

  end if;



  if not public.bb_has_location_access(
    v_invoice.location_code
  )
  then

    raise exception
      'You do not have access to this invoice location';

  end if;



  /* ==========================================================
     DUPLICATE PAYLOAD LINE CHECK
     ========================================================== */

  select
    count(*)

  into
    v_payload_count

  from jsonb_array_elements(
    v_lines
  );



  if

    v_payload_count

    <>

    (

      select

        count(
          distinct trim(
            x->>'lineId'
          )
        )

      from jsonb_array_elements(
        v_lines
      ) x

    )

  then

    raise exception
      'Duplicate invoice lines are not allowed in one reversal';

  end if;



  /* ==========================================================
     FULL REVERSAL CHECK
     ========================================================== */

  if v_return_type = 'Full Reversal' then


    for v_line in

      select *

      from public.invoice_lines il

      where il.invoice_id =
            v_invoice.invoice_id

      order by
        il.line_no

    loop


      select

        coalesce(
          sum(
            sr.qty
          ),
          0
        )

      into
        v_returned

      from public.sales_returns sr

      where sr.line_id =
            v_line.line_id;



      v_available :=

        greatest(

          coalesce(
            v_line.qty,
            0
          )

          -

          v_returned,

          0

        );



      if v_available > 0.000001 then


        select

          coalesce(

            sum(

              nullif(
                trim(
                  x->>'qty'
                ),
                ''
              )::numeric

            ),

            0

          )

        into
          v_requested

        from jsonb_array_elements(
          v_lines
        ) x

        where

          trim(
            coalesce(
              x->>'lineId',
              ''
            )
          )
          =
          v_line.line_id;



        if

          abs(
            v_requested
            -
            v_available
          )
          >
          0.000001

        then

          raise exception

            'Full Reversal must reverse all remaining quantity for line %',

            v_line.line_id;

        end if;


      end if;


    end loop;


  end if;



  /* ==========================================================
     SAVE EACH RETURN LINE
     ========================================================== */

  for v_item in

    select value

    from jsonb_array_elements(
      v_lines
    )

  loop


    v_line_id :=

      trim(
        coalesce(
          v_item->>'lineId',
          ''
        )
      );


    if v_line_id = '' then

      raise exception
        'Invoice Line ID is required';

    end if;



    begin


      v_qty :=

        nullif(

          trim(
            coalesce(
              v_item->>'qty',
              ''
            )
          ),

          ''

        )::numeric;


    exception
      when others then

        raise exception

          'Invalid reversed quantity for line %',

          v_line_id;

    end;



    if

      v_qty is null

      or

      v_qty <= 0

    then

      raise exception

        'Reversed quantity must be greater than zero for line %',

        v_line_id;

    end if;



    select *

    into
      v_line

    from public.invoice_lines il

    where

      il.line_id =
      v_line_id

      and

      il.invoice_id =
      v_invoice.invoice_id

    for update;



    if not found then

      raise exception

        'Invoice line not found: %',

        v_line_id;

    end if;



    select

      coalesce(
        sum(
          sr.qty
        ),
        0
      )

    into
      v_returned

    from public.sales_returns sr

    where sr.line_id =
          v_line.line_id;



    v_available :=

      greatest(

        coalesce(
          v_line.qty,
          0
        )

        -

        v_returned,

        0

      );



    if

      v_qty
      >
      v_available
      +
      0.000001

    then

      raise exception

        'Reversed quantity % exceeds available quantity % for %',

        v_qty,

        v_available,

        coalesce(
          v_line.product_name_snapshot,
          v_line.display_product_code,
          v_line.line_id
        );

    end if;



    /* ========================================================
       PRODUCT IDENTITY
       ======================================================== */

    if

      upper(
        coalesce(
          v_line.entry_type,
          'EXACT'
        )
      )
      =
      'GROUP'

    then


      v_exact_code :=
        null;


      v_group_code :=

        coalesce(

          nullif(
            v_line.product_group_code,
            ''
          ),

          nullif(
            v_line.display_product_code,
            ''
          )

        );


      if

        v_group_code is null

        or

        not exists(

          select 1

          from public.product_groups pg

          where pg.group_code =
                v_group_code

        )

      then

        raise exception

          'Invoice GROUP line % has no valid Product Group',

          v_line.line_id;

      end if;



    else


      v_exact_code :=
        v_line.product_code;


      v_group_code :=
        null;


      if

        v_exact_code is null

        or

        not exists(

          select 1

          from public.products p

          where p.product_code =
                v_exact_code

        )

      then

        raise exception

          'Invoice line % has no valid exact Product Code',

          v_line.line_id;

      end if;


    end if;



    v_alloc_norm:=null;
     -- Keep the accountant's exact physical-product source selection for Batch,
     -- so the BEFORE return trigger can validate it against the original sale.
     if v_invoice.batch_id is not null and jsonb_typeof(v_item->'stockAllocations')='array'
       and jsonb_array_length(v_item->'stockAllocations')>0 then
       v_alloc_norm:=v_item->'stockAllocations';
     end if;



    /* ========================================================
       DIRECT SALE SOURCE VALIDATION
       ======================================================== */

    if v_invoice.batch_id is null then


      if

        upper(
          coalesce(
            v_line.entry_type,
            'EXACT'
          )
        )
        <>
        'EXACT'

      then

        raise exception
          'Direct Sale Reversal supports exact products only';

      end if;



      select *

      into
        v_source

      from
        public.bb_invoice_reversal_direct_source_balance_v2_internal(
          v_line.line_id
        );



      if

        coalesce(
          v_source.ambiguous_previous_return_qty,
          0
        )
        >
        0.000001

      then

        raise exception

          '% has an older Mixed reversal without source data. Manual review is required.',

          coalesce(
            v_line.product_name_snapshot,
            v_line.product_code
          );

      end if;



      v_requested_purchased :=
        0;


      v_requested_zero :=
        0;


      v_alloc_total :=
        0;


      v_alloc_norm :=
        '[]'::jsonb;


      v_alloc_input :=
        v_item->'stockAllocations';



      /* ------------------------------------------------------
         Single-source Direct Sale can auto-select.

         Mixed Direct Sale must explicitly tell us the returned
         Purchased Qty and Zero-Cost Qty.
         ------------------------------------------------------ */

      if

        jsonb_typeof(
          v_alloc_input
        )
        <>
        'array'

        or

        jsonb_array_length(
          v_alloc_input
        )
        =
        0

      then


        if

          v_source.remaining_purchased_qty
          >
          0.000001

          and

          v_source.remaining_zero_cost_qty
          <=
          0.000001

        then


          v_alloc_input :=

            jsonb_build_array(

              jsonb_build_object(

                'source',
                  'PURCHASED',

                'qty',
                  v_qty

              )

            );



        elsif

          v_source.remaining_zero_cost_qty
          >
          0.000001

          and

          v_source.remaining_purchased_qty
          <=
          0.000001

        then


          v_alloc_input :=

            jsonb_build_array(

              jsonb_build_object(

                'source',
                  'ZERO_COST',

                'qty',
                  v_qty

              )

            );



        else


          raise exception

            '% is a Mixed Direct Sale. Purchased Return Qty and Zero-Cost Return Qty must be selected.',

            coalesce(
              v_line.product_name_snapshot,
              v_line.product_code
            );


        end if;


      end if;



      for v_elem in

        select value

        from jsonb_array_elements(
          v_alloc_input
        )

      loop


        v_source_name :=

          upper(

            replace(

              replace(

                trim(
                  coalesce(
                    v_elem->>'source',
                    ''
                  )
                ),

                '-',
                '_'

              ),

              ' ',
              '_'

            )

          );


        v_source_qty :=

          coalesce(

            nullif(
              v_elem->>'qty',
              ''
            )::numeric,

            0

          );



        if v_source_qty <= 0 then

          raise exception

            '% reversal source Qty must be greater than zero',

            coalesce(
              v_line.product_name_snapshot,
              v_line.product_code
            );

        end if;



        if v_source_name = 'PURCHASED' then


          v_requested_purchased :=

            v_requested_purchased
            +
            v_source_qty;



        elsif v_source_name = 'ZERO_COST' then


          v_requested_zero :=

            v_requested_zero
            +
            v_source_qty;



        else


          raise exception

            'Invalid Direct Sale reversal Stock Source: %',

            v_source_name;


        end if;



        v_alloc_total :=

          v_alloc_total
          +
          v_source_qty;


      end loop;



      if

        abs(
          v_alloc_total
          -
          v_qty
        )
        >
        0.000001

      then

        raise exception

          '% reversal source Qty % does not match Reversal Qty %',

          coalesce(
            v_line.product_name_snapshot,
            v_line.product_code
          ),

          v_alloc_total,

          v_qty;

      end if;



      if

        v_requested_purchased
        >
        v_source.remaining_purchased_qty
        +
        0.000001

      then

        raise exception

          '% Purchased Return Qty % exceeds remaining Purchased Sold Qty %',

          coalesce(
            v_line.product_name_snapshot,
            v_line.product_code
          ),

          v_requested_purchased,

          v_source.remaining_purchased_qty;

      end if;



      if

        v_requested_zero
        >
        v_source.remaining_zero_cost_qty
        +
        0.000001

      then

        raise exception

          '% Zero-Cost Return Qty % exceeds remaining Zero-Cost Sold Qty %',

          coalesce(
            v_line.product_name_snapshot,
            v_line.product_code
          ),

          v_requested_zero,

          v_source.remaining_zero_cost_qty;

      end if;



      v_alloc_norm :=
        '[]'::jsonb;



      if v_requested_purchased > 0 then


        v_alloc_norm :=

          v_alloc_norm

          ||

          jsonb_build_array(

            jsonb_build_object(

              'source',
                'PURCHASED',

              'qty',
                v_requested_purchased

            )

          );


      end if;



      if v_requested_zero > 0 then


        v_alloc_norm :=

          v_alloc_norm

          ||

          jsonb_build_array(

            jsonb_build_object(

              'source',
                'ZERO_COST',

              'qty',
                v_requested_zero

            )

          );


      end if;


    end if;



    /* ========================================================
       INSERT REVERSAL

       Existing Batch BEFORE trigger will create its own Batch
       stock allocation.

       Direct Sale keeps our source allocation.
       ======================================================== */

    v_return_id :=

      public.bb_next_prefixed_id(

        'public.sales_returns'::regclass,

        'return_id',

        'REV',

        4

      );



    insert into public.sales_returns(

      return_id,

      invoice_id,

      invoice_no_snapshot,

      return_date,

      customer_id,

      customer_name_snapshot,

      location_code,

      salesperson_staff_id,

      salesperson_name_snapshot,

      product_code,

      product_group_code,

      product_name_snapshot,

      qty,

      unit_price,

      return_amount,

      return_type,

      reason,

      note,

      source_created_at,

      line_id,

      stock_allocation_json

    )

    values(

      v_return_id,

      v_invoice.invoice_id,

      v_invoice.invoice_no,

      v_return_date,

      v_invoice.customer_id,

      v_invoice.customer_name_snapshot,

      v_invoice.location_code,

      v_invoice.salesperson_staff_id,

      v_invoice.salesperson_name_snapshot,

      v_exact_code,

      v_group_code,

      v_line.product_name_snapshot,

      v_qty,

      v_line.unit_price,

      v_qty
      *
      v_line.unit_price,

      v_return_type,

      v_reason,

      v_note,

      now(),

      v_line.line_id,

      v_alloc_norm

    )

    returning
      stock_allocation_json

    into
      v_saved_alloc;



    v_total :=

      v_total
      +
      (
        v_qty
        *
        v_line.unit_price
      );


    v_line_count :=
      v_line_count
      +
      1;



    v_rows :=

      v_rows

      ||

      jsonb_build_array(

        jsonb_build_object(

          'returnId',
            v_return_id,

          'lineId',
            v_line.line_id,

          'productCode',
            coalesce(
              v_exact_code,
              v_group_code,
              ''
            ),

          'productName',
            coalesce(
              v_line.product_name_snapshot,
              ''
            ),

          'qty',
            v_qty,

          'unitPrice',
            v_line.unit_price,

          'amount',
            v_qty
            *
            v_line.unit_price,

          'stockAllocations',
            v_saved_alloc

        )

      );


  end loop;



  /* ==========================================================
     AUDIT
     ========================================================== */

  select

    coalesce(
      s.staff_name,
      au.email
    )

  into
    v_actor


  from public.app_users au


  left join public.staff s

    on s.staff_id =
       au.staff_id


  where

    au.user_id =
    auth.uid()

    and

    au.active =
    true;



  v_audit_id :=

    public.bb_next_prefixed_id(

      'public.sales_database_edit_history'::regclass,

      'audit_id',

      'AUD',

      6

    );



  insert into public.sales_database_edit_history(

    audit_id,

    occurred_at,

    module,

    record_id,

    record_no,

    action,

    field_name,

    old_value,

    new_value,

    reason,

    admin_legacy_id,

    admin_name_snapshot

  )

  values(

    v_audit_id,

    now(),

    'Invoice Reversal V2',

    v_invoice.invoice_id,

    v_invoice.invoice_no,

    'CREATE',

    'Sales Return',

    null,

    jsonb_build_object(

      'returnType',
        v_return_type,

      'returnDate',
        v_return_date,

      'totalAmount',
        v_total,

      'lines',
        v_rows

    )::text,

    v_reason,

    null,

    coalesce(
      v_actor,
      'Supabase User'
    )

  );



  return

    jsonb_build_object(

      'success',
        true,

      'version',
        'INVOICE-REVERSAL-V2',

      'invoiceNo',
        v_invoice.invoice_no,

      'lineCount',
        v_line_count,

      'totalAmount',
        v_total,

      'returns',
        v_rows,

      'revision',
        public.bb_sales_history_revision()

    );


end;

$function$


CREATE OR REPLACE FUNCTION public.bb_invoice_reversal_postclose_save_v1(p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$


declare


  v_invoice
    public.invoices%rowtype;


  v_line
    public.invoice_lines%rowtype;


  v_source
    record;


  v_lines jsonb :=

    coalesce(
      p_payload->'lines',
      '[]'::jsonb
    );


  v_item jsonb;

  v_elem jsonb;


  v_invoice_no text :=

    trim(
      coalesce(
        p_payload->>'invoiceNo',
        ''
      )
    );


  v_invoice_id text :=
    trim(
      coalesce(
        p_payload->>'invoiceId',
        ''
      )
    );


  v_return_date date;


  v_return_type text :=

    trim(
      coalesce(
        p_payload->>'returnType',
        'Partial Reversal'
      )
    );


  v_reason text :=

    trim(
      coalesce(
        p_payload->>'reason',
        ''
      )
    );


  v_note text :=

    nullif(

      trim(
        coalesce(
          p_payload->>'note',
          ''
        )
      ),

      ''

    );


  v_qty numeric;

  v_returned numeric;

  v_available numeric;

  v_requested numeric;


  v_line_id text;

  v_return_id text;


  v_exact_code text;

  v_group_code text;


  v_alloc_input jsonb;

  v_alloc_norm jsonb;

  v_saved_alloc jsonb;


  v_source_name text;

  v_source_qty numeric;


  v_requested_purchased numeric;

  v_requested_zero numeric;

  v_alloc_total numeric;


  v_total numeric :=
    0;


  v_rows jsonb :=
    '[]'::jsonb;


  v_actor text;

  v_audit_id text;


  v_line_count integer :=
    0;


  v_destinations jsonb;
  v_dest jsonb;
  v_dest_code text;
  v_dest_type text;
  v_dest_batch text;
  v_dest_batch_row public.stock_batches%rowtype;
  v_payload_count integer;


begin


  /* ==========================================================
     ACCESS
     ========================================================== */

  if not public.bb_has_module_access(
    'invoice_reversal',
    'create'
  )
  then

    raise exception
      'Invoice Reversal create access denied';

  end if;



  /* ==========================================================
     VALIDATION
     ========================================================== */

  if v_invoice_id = '' then

    raise exception
      'Invoice ID is required';

  end if;


  if v_invoice_no = '' then

    raise exception
      'Invoice No. is required';

  end if;


  if v_reason = '' then

    raise exception
      'Reversal reason is required';

  end if;


  if v_return_type not in (
    'Partial Reversal',
    'Full Reversal'
  )
  then

    raise exception
      'Invalid Reversal Type';

  end if;



  begin


    v_return_date :=

      nullif(

        trim(
          coalesce(
            p_payload->>'returnDate',
            ''
          )
        ),

        ''

      )::date;


  exception
    when others then

      raise exception
        'Valid Reversal Date is required';

  end;



  if v_return_date is null then

    raise exception
      'Reversal Date is required';

  end if;



  if

    jsonb_typeof(
      v_lines
    )
    <>
    'array'

    or

    jsonb_array_length(
      v_lines
    )
    =
    0

  then

    raise exception
      'At least one reversed product line is required';

  end if;



  /* ==========================================================
     LOCK INVOICE
     ========================================================== */

  select *

  into
    v_invoice

  from public.invoices i

  where

    i.invoice_id = v_invoice_id

  for update;



  if not found then

    raise exception
      'Invoice was not found';

  end if;



  if not public.bb_has_location_access(
    v_invoice.location_code
  )
  then

    raise exception
      'You do not have access to this invoice location';

  end if;




  IF v_invoice.batch_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.stock_batches b WHERE b.batch_id=v_invoice.batch_id AND upper(b.status)='CLOSED') THEN RAISE EXCEPTION 'Post-close reversal requires an original Closed Batch'; END IF;
  IF v_invoice.invoice_no IS DISTINCT FROM v_invoice_no THEN RAISE EXCEPTION 'Invoice No / ID mismatch'; END IF;
  PERFORM pg_advisory_xact_lock(hashtext('BB_STOCK_WRITE'));
  /* ==========================================================
     DUPLICATE PAYLOAD LINE CHECK
     ========================================================== */

  select
    count(*)

  into
    v_payload_count

  from jsonb_array_elements(
    v_lines
  );



  if

    v_payload_count

    <>

    (

      select

        count(
          distinct trim(
            x->>'lineId'
          )
        )

      from jsonb_array_elements(
        v_lines
      ) x

    )

  then

    raise exception
      'Duplicate invoice lines are not allowed in one reversal';

  end if;



  /* ==========================================================
     FULL REVERSAL CHECK
     ========================================================== */

  if v_return_type = 'Full Reversal' then


    for v_line in

      select *

      from public.invoice_lines il

      where il.invoice_id =
            v_invoice.invoice_id

      order by
        il.line_no

    loop


      select

        coalesce(
          sum(
            sr.qty
          ),
          0
        )

      into
        v_returned

      from public.sales_returns sr

      where sr.line_id =
            v_line.line_id;



      v_available :=

        greatest(

          coalesce(
            v_line.qty,
            0
          )

          -

          v_returned,

          0

        );



      if v_available > 0.000001 then


        select

          coalesce(

            sum(

              nullif(
                trim(
                  x->>'qty'
                ),
                ''
              )::numeric

            ),

            0

          )

        into
          v_requested

        from jsonb_array_elements(
          v_lines
        ) x

        where

          trim(
            coalesce(
              x->>'lineId',
              ''
            )
          )
          =
          v_line.line_id;



        if

          abs(
            v_requested
            -
            v_available
          )
          >
          0.000001

        then

          raise exception

            'Full Reversal must reverse all remaining quantity for line %',

            v_line.line_id;

        end if;


      end if;


    end loop;


  end if;



  /* ==========================================================
     SAVE EACH RETURN LINE
     ========================================================== */

  for v_item in

    select value

    from jsonb_array_elements(
      v_lines
    )

  loop


    v_line_id :=

      trim(
        coalesce(
          v_item->>'lineId',
          ''
        )
      );


    if v_line_id = '' then

      raise exception
        'Invoice Line ID is required';

    end if;



    begin


      v_qty :=

        nullif(

          trim(
            coalesce(
              v_item->>'qty',
              ''
            )
          ),

          ''

        )::numeric;


    exception
      when others then

        raise exception

          'Invalid reversed quantity for line %',

          v_line_id;

    end;



    if

      v_qty is null

      or

      v_qty <= 0

    then

      raise exception

        'Reversed quantity must be greater than zero for line %',

        v_line_id;

    end if;



    select *

    into
      v_line

    from public.invoice_lines il

    where

      il.line_id =
      v_line_id

      and

      il.invoice_id =
      v_invoice.invoice_id

    for update;



    if not found then

      raise exception

        'Invoice line not found: %',

        v_line_id;

    end if;



    select

      coalesce(
        sum(
          sr.qty
        ),
        0
      )

    into
      v_returned

    from public.sales_returns sr

    where sr.line_id =
          v_line.line_id;



    v_available :=

      greatest(

        coalesce(
          v_line.qty,
          0
        )

        -

        v_returned,

        0

      );



    if

      v_qty
      >
      v_available
      +
      0.000001

    then

      raise exception

        'Reversed quantity % exceeds available quantity % for %',

        v_qty,

        v_available,

        coalesce(
          v_line.product_name_snapshot,
          v_line.display_product_code,
          v_line.line_id
        );

    end if;



    /* ========================================================
       PRODUCT IDENTITY
       ======================================================== */

    if

      upper(
        coalesce(
          v_line.entry_type,
          'EXACT'
        )
      )
      =
      'GROUP'

    then


      v_exact_code :=
        null;


      v_group_code :=

        coalesce(

          nullif(
            v_line.product_group_code,
            ''
          ),

          nullif(
            v_line.display_product_code,
            ''
          )

        );


      if

        v_group_code is null

        or

        not exists(

          select 1

          from public.product_groups pg

          where pg.group_code =
                v_group_code

        )

      then

        raise exception

          'Invoice GROUP line % has no valid Product Group',

          v_line.line_id;

      end if;



    else


      v_exact_code :=
        v_line.product_code;


      v_group_code :=
        null;


      if

        v_exact_code is null

        or

        not exists(

          select 1

          from public.products p

          where p.product_code =
                v_exact_code

        )

      then

        raise exception

          'Invoice line % has no valid exact Product Code',

          v_line.line_id;

      end if;


    end if;



    v_alloc_norm:=null;
     -- Keep the accountant's exact physical-product source selection for Batch,
     -- so the BEFORE return trigger can validate it against the original sale.
     if v_invoice.batch_id is not null and jsonb_typeof(v_item->'stockAllocations')='array'
       and jsonb_array_length(v_item->'stockAllocations')>0 then
       v_alloc_norm:=v_item->'stockAllocations';
     end if;



    /* ========================================================
       DIRECT SALE SOURCE VALIDATION
       ======================================================== */

    if v_invoice.batch_id is null then


      if

        upper(
          coalesce(
            v_line.entry_type,
            'EXACT'
          )
        )
        <>
        'EXACT'

      then

        raise exception
          'Direct Sale Reversal supports exact products only';

      end if;



      select *

      into
        v_source

      from
        public.bb_invoice_reversal_direct_source_balance_v2_internal(
          v_line.line_id
        );



      if

        coalesce(
          v_source.ambiguous_previous_return_qty,
          0
        )
        >
        0.000001

      then

        raise exception

          '% has an older Mixed reversal without source data. Manual review is required.',

          coalesce(
            v_line.product_name_snapshot,
            v_line.product_code
          );

      end if;



      v_requested_purchased :=
        0;


      v_requested_zero :=
        0;


      v_alloc_total :=
        0;


      v_alloc_norm :=
        '[]'::jsonb;


      v_alloc_input :=
        v_item->'stockAllocations';



      /* ------------------------------------------------------
         Single-source Direct Sale can auto-select.

         Mixed Direct Sale must explicitly tell us the returned
         Purchased Qty and Zero-Cost Qty.
         ------------------------------------------------------ */

      if

        jsonb_typeof(
          v_alloc_input
        )
        <>
        'array'

        or

        jsonb_array_length(
          v_alloc_input
        )
        =
        0

      then


        if

          v_source.remaining_purchased_qty
          >
          0.000001

          and

          v_source.remaining_zero_cost_qty
          <=
          0.000001

        then


          v_alloc_input :=

            jsonb_build_array(

              jsonb_build_object(

                'source',
                  'PURCHASED',

                'qty',
                  v_qty

              )

            );



        elsif

          v_source.remaining_zero_cost_qty
          >
          0.000001

          and

          v_source.remaining_purchased_qty
          <=
          0.000001

        then


          v_alloc_input :=

            jsonb_build_array(

              jsonb_build_object(

                'source',
                  'ZERO_COST',

                'qty',
                  v_qty

              )

            );



        else


          raise exception

            '% is a Mixed Direct Sale. Purchased Return Qty and Zero-Cost Return Qty must be selected.',

            coalesce(
              v_line.product_name_snapshot,
              v_line.product_code
            );


        end if;


      end if;



      for v_elem in

        select value

        from jsonb_array_elements(
          v_alloc_input
        )

      loop


        v_source_name :=

          upper(

            replace(

              replace(

                trim(
                  coalesce(
                    v_elem->>'source',
                    ''
                  )
                ),

                '-',
                '_'

              ),

              ' ',
              '_'

            )

          );


        v_source_qty :=

          coalesce(

            nullif(
              v_elem->>'qty',
              ''
            )::numeric,

            0

          );



        if v_source_qty <= 0 then

          raise exception

            '% reversal source Qty must be greater than zero',

            coalesce(
              v_line.product_name_snapshot,
              v_line.product_code
            );

        end if;



        if v_source_name = 'PURCHASED' then


          v_requested_purchased :=

            v_requested_purchased
            +
            v_source_qty;



        elsif v_source_name = 'ZERO_COST' then


          v_requested_zero :=

            v_requested_zero
            +
            v_source_qty;



        else


          raise exception

            'Invalid Direct Sale reversal Stock Source: %',

            v_source_name;


        end if;



        v_alloc_total :=

          v_alloc_total
          +
          v_source_qty;


      end loop;



      if

        abs(
          v_alloc_total
          -
          v_qty
        )
        >
        0.000001

      then

        raise exception

          '% reversal source Qty % does not match Reversal Qty %',

          coalesce(
            v_line.product_name_snapshot,
            v_line.product_code
          ),

          v_alloc_total,

          v_qty;

      end if;



      if

        v_requested_purchased
        >
        v_source.remaining_purchased_qty
        +
        0.000001

      then

        raise exception

          '% Purchased Return Qty % exceeds remaining Purchased Sold Qty %',

          coalesce(
            v_line.product_name_snapshot,
            v_line.product_code
          ),

          v_requested_purchased,

          v_source.remaining_purchased_qty;

      end if;



      if

        v_requested_zero
        >
        v_source.remaining_zero_cost_qty
        +
        0.000001

      then

        raise exception

          '% Zero-Cost Return Qty % exceeds remaining Zero-Cost Sold Qty %',

          coalesce(
            v_line.product_name_snapshot,
            v_line.product_code
          ),

          v_requested_zero,

          v_source.remaining_zero_cost_qty;

      end if;



      v_alloc_norm :=
        '[]'::jsonb;



      if v_requested_purchased > 0 then


        v_alloc_norm :=

          v_alloc_norm

          ||

          jsonb_build_array(

            jsonb_build_object(

              'source',
                'PURCHASED',

              'qty',
                v_requested_purchased

            )

          );


      end if;



      if v_requested_zero > 0 then


        v_alloc_norm :=

          v_alloc_norm

          ||

          jsonb_build_array(

            jsonb_build_object(

              'source',
                'ZERO_COST',

              'qty',
                v_requested_zero

            )

          );


      end if;


    end if;



    /* ========================================================
       INSERT REVERSAL

       Existing Batch BEFORE trigger will create its own Batch
       stock allocation.

       Direct Sale keeps our source allocation.
       ======================================================== */

    v_return_id :=

      public.bb_next_prefixed_id(

        'public.sales_returns'::regclass,

        'return_id',

        'REV',

        4

      );




    v_destinations:=v_item->'destinations';
    IF jsonb_typeof(v_destinations) IS DISTINCT FROM 'array' OR jsonb_array_length(v_destinations)=0 THEN RAISE EXCEPTION 'Select stock destination(s) for each returned product'; END IF;
    IF (SELECT count(*) FROM jsonb_array_elements(v_destinations)) <> (SELECT count(DISTINCT nullif(trim(value->>'productCode'),'')) FROM jsonb_array_elements(v_destinations)) THEN RAISE EXCEPTION 'Duplicate or missing product destination'; END IF;
    FOR v_dest IN SELECT value FROM jsonb_array_elements(v_destinations) LOOP
      v_dest_code:=nullif(trim(v_dest->>'productCode'),'');
      v_dest_type:=upper(trim(coalesce(v_dest->>'destinationType','')));
      v_dest_batch:=nullif(trim(coalesce(v_dest->>'batchId','')),'');
      IF v_dest_code IS NULL OR v_dest_type NOT IN ('WAREHOUSE','OPEN_BATCH') THEN RAISE EXCEPTION 'Invalid stock destination'; END IF;
      IF upper(coalesce(v_line.entry_type,'EXACT'))='EXACT' THEN
        IF v_dest_code IS DISTINCT FROM v_line.product_code THEN RAISE EXCEPTION 'Stock destination product does not match Invoice line'; END IF;
      ELSIF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(v_line.stock_allocation_json,'[]'::jsonb)) e WHERE e->>'productCode'=v_dest_code) THEN RAISE EXCEPTION 'Stock destination product is outside Invoice Group'; END IF;
      IF v_dest_type='OPEN_BATCH' THEN
        SELECT * INTO v_dest_batch_row FROM public.stock_batches b WHERE b.batch_id=v_dest_batch FOR UPDATE;
        IF NOT FOUND OR upper(coalesce(v_dest_batch_row.status,''))<>'OPEN' OR v_dest_batch_row.location_code IS DISTINCT FROM v_invoice.location_code OR v_dest_batch=v_invoice.batch_id THEN RAISE EXCEPTION 'Target Batch must be Open in the same location'; END IF;
        IF NOT EXISTS (SELECT 1 FROM public.stock_batch_items bi WHERE bi.batch_id=v_dest_batch AND bi.product_code=v_dest_code) THEN RAISE EXCEPTION 'Target Batch does not contain selected product'; END IF;
      ELSIF v_dest_batch IS NOT NULL THEN RAISE EXCEPTION 'Warehouse destination cannot have Batch ID'; END IF;
    END LOOP;
    INSERT INTO public.bb_postclose_reversal_routes(return_id,invoice_id,original_batch_id,destinations,created_by) VALUES(v_return_id,v_invoice.invoice_id,v_invoice.batch_id,v_destinations,auth.uid());

    insert into public.sales_returns(

      return_id,

      invoice_id,

      invoice_no_snapshot,

      return_date,

      customer_id,

      customer_name_snapshot,

      location_code,

      salesperson_staff_id,

      salesperson_name_snapshot,

      product_code,

      product_group_code,

      product_name_snapshot,

      qty,

      unit_price,

      return_amount,

      return_type,

      reason,

      note,

      source_created_at,

      line_id,

      stock_allocation_json

    )

    values(

      v_return_id,

      v_invoice.invoice_id,

      v_invoice.invoice_no,

      v_return_date,

      v_invoice.customer_id,

      v_invoice.customer_name_snapshot,

      v_invoice.location_code,

      v_invoice.salesperson_staff_id,

      v_invoice.salesperson_name_snapshot,

      v_exact_code,

      v_group_code,

      v_line.product_name_snapshot,

      v_qty,

      v_line.unit_price,

      v_qty
      *
      v_line.unit_price,

      v_return_type,

      v_reason,

      v_note,

      now(),

      v_line.line_id,

      v_alloc_norm

    )

    returning
      stock_allocation_json

    into
      v_saved_alloc;



    v_total :=

      v_total
      +
      (
        v_qty
        *
        v_line.unit_price
      );


    v_line_count :=
      v_line_count
      +
      1;



    v_rows :=

      v_rows

      ||

      jsonb_build_array(

        jsonb_build_object(

          'returnId',
            v_return_id,

          'lineId',
            v_line.line_id,

          'productCode',
            coalesce(
              v_exact_code,
              v_group_code,
              ''
            ),

          'productName',
            coalesce(
              v_line.product_name_snapshot,
              ''
            ),

          'qty',
            v_qty,

          'unitPrice',
            v_line.unit_price,

          'amount',
            v_qty
            *
            v_line.unit_price,

          'stockAllocations',
            v_saved_alloc,
          'destinations',
            v_destinations

        )

      );


  end loop;



  /* ==========================================================
     AUDIT
     ========================================================== */

  select

    coalesce(
      s.staff_name,
      au.email
    )

  into
    v_actor


  from public.app_users au


  left join public.staff s

    on s.staff_id =
       au.staff_id


  where

    au.user_id =
    auth.uid()

    and

    au.active =
    true;



  v_audit_id :=

    public.bb_next_prefixed_id(

      'public.sales_database_edit_history'::regclass,

      'audit_id',

      'AUD',

      6

    );



  insert into public.sales_database_edit_history(

    audit_id,

    occurred_at,

    module,

    record_id,

    record_no,

    action,

    field_name,

    old_value,

    new_value,

    reason,

    admin_legacy_id,

    admin_name_snapshot

  )

  values(

    v_audit_id,

    now(),

    'Post-Close Invoice Reversal V1',

    v_invoice.invoice_id,

    v_invoice.invoice_no,

    'CREATE',

    'Sales Return',

    null,

    jsonb_build_object(

      'returnType',
        v_return_type,

      'returnDate',
        v_return_date,

      'totalAmount',
        v_total,

      'lines',
        v_rows

    )::text,

    v_reason,

    null,

    coalesce(
      v_actor,
      'Supabase User'
    )

  );



  return

    jsonb_build_object(

      'success',
        true,

      'version',
        'INVOICE-REVERSAL-POSTCLOSE-V1',
      'destinationMode',
        'POST_CLOSE',

      'invoiceNo',
        v_invoice.invoice_no,

      'lineCount',
        v_line_count,

      'totalAmount',
        v_total,

      'returns',
        v_rows,

      'revision',
        public.bb_sales_history_revision()

    );


end;

$function$


CREATE OR REPLACE FUNCTION public.bb_batch_return_stock_internal()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$

declare


  v_invoice
    public.invoices%rowtype;


  v_batch
    public.stock_batches%rowtype;


  v_batch_item
    public.stock_batch_items%rowtype;


  v_elem jsonb;


  v_code text;

  v_qty numeric;


  v_purchase_restore numeric;

  v_zero_restore numeric;


  v_movement_id text;

  v_transaction_id text;


  v_name text;

  v_unit text;


  v_purchase_cost numeric;


begin


  select *

  into v_invoice

  from public.invoices

  where invoice_id =
        new.invoice_id;



  if not found

     or

     v_invoice.batch_id is null

  then

    return new;

  end if;



  perform pg_advisory_xact_lock(
    hashtext(
      'BB_STOCK_WRITE'
    )
  );



  select *

  into v_batch

  from public.stock_batches

  where batch_id =
        v_invoice.batch_id

  for update;



  if exists (select 1 from public.bb_postclose_reversal_routes r where r.return_id=new.return_id and r.invoice_id=new.invoice_id and r.original_batch_id=v_batch.batch_id) then return new; end if;

  if upper(
    coalesce(
      v_batch.status,
      ''
    )
  ) = 'CLOSED'
  then

    raise exception
      'Closed Batch % cannot be changed by Invoice Reversal',
      v_batch.batch_id;

  end if;



  v_movement_id :=

    public.bb_next_prefixed_id(

      'public.stock_activity'::regclass,

      'movement_id',

      'STK',

      6

    );



  for v_elem in

    select value

    from jsonb_array_elements(

      coalesce(
        new.stock_allocation_json,
        '[]'::jsonb
      )

    )

  loop


    v_code :=
      v_elem->>'productCode';


    v_qty :=
      coalesce(
        nullif(
          v_elem->>'qty',
          ''
        )::numeric,
        0
      );



    select *

    into v_batch_item

    from public.stock_batch_items

    where batch_id =
          v_batch.batch_id

      and product_code =
          v_code

    for update;



    if not found then

      raise exception
        'Return Product % is not in Batch %',
        v_code,
        v_batch.batch_id;

    end if;



    if v_qty >
       v_batch_item.sold_qty_snapshot
       +
       0.000001
    then

      raise exception
        'Return Qty % exceeds Batch sold Qty % for %',
        v_qty,
        v_batch_item.sold_qty_snapshot,
        v_code;

    end if;



    -- Return exactly the sources validated by BEFORE trigger.
    v_purchase_restore:=nullif(v_elem->>'purchasedQty','')::numeric;
    v_zero_restore:=nullif(v_elem->>'zeroCostQty','')::numeric;
    if v_purchase_restore is null or v_zero_restore is null or
       v_purchase_restore<0 or v_zero_restore<0 or
       abs(v_purchase_restore+v_zero_restore-v_qty)>0.000001 then
      raise exception '%: invalid Purchased / Zero-Cost Reversal source quantities',v_code;
    end if;
    if v_purchase_restore>v_batch_item.purchased_sold_qty_snapshot+0.000001 then
      raise exception '%: Purchased returned exceeds current Purchased sold balance',v_code;
    end if;
    if v_zero_restore >
       v_batch_item.zero_cost_sold_qty_snapshot
       +
       0.000001
    then

      raise exception
        '%: Batch sale source reversal mismatch',
        v_code;

    end if;



    update public.stock_batch_items

    set

      sold_qty_snapshot =
        greatest(
          sold_qty_snapshot
          -
          v_qty,
          0
        ),


      pending_qty_snapshot =
        pending_qty_snapshot
        +
        v_qty,


      purchased_sold_qty_snapshot =
        greatest(
          purchased_sold_qty_snapshot
          -
          v_purchase_restore,
          0
        ),


      purchased_pending_qty_snapshot =
        purchased_pending_qty_snapshot
        +
        v_purchase_restore,


      zero_cost_sold_qty_snapshot =
        greatest(
          zero_cost_sold_qty_snapshot
          -
          v_zero_restore,
          0
        ),


      zero_cost_pending_qty_snapshot =
        zero_cost_pending_qty_snapshot
        +
        v_zero_restore,


      source_updated_at =
        now(),


      updated_at =
        now()


    where batch_id =
          v_batch.batch_id

      and product_code =
          v_code;



    select

      coalesce(
        product_name,
        v_code
      ),

      coalesce(
        unit,
        ''
      )

    into
      v_name,
      v_unit

    from public.products

    where product_code =
          v_code;



    -- ========================================================
    -- PURCHASED RESTORE
    -- ========================================================

    if v_purchase_restore > 0 then


      -- Historical purchased sale value; do not revalue an old invoice return
      -- at today's moving average cost.
      select case when coalesce(sum(sa.qty),0)>0
             then coalesce(sum(sa.line_value),0)/sum(sa.qty) else null end
      into v_purchase_cost
      from public.stock_activity sa
      where sa.movement_type='BATCH_SALE'
        and sa.from_bucket='BATCH_PENDING'
        and sa.batch_id=v_invoice.batch_id
        and sa.related_invoice_no=v_invoice.invoice_no
        and sa.customer_id is not distinct from v_invoice.customer_id
        and sa.product_code=v_code
        and split_part(sa.client_request_id,':',1)='BATCH-INVOICE'
        and split_part(sa.client_request_id,':',2)=new.line_id;
      if v_purchase_cost is null then
        raise exception 'Historical Purchased COGS missing for %; audit review required',v_code;
      end if;



      v_transaction_id :=

        public.bb_next_prefixed_id(

          'public.stock_activity'::regclass,

          'transaction_id',

          'TRX',

          6

        );



      insert into public.stock_activity(

        transaction_id,

        batch_id,

        activity_date,
        activity_type,

        product_code,
        product_name_snapshot,

        qty,

        unit_snapshot,

        location_code,
        to_location_code,

        salesman_staff_id,
        salesman_name_snapshot,

        reference_no,
        related_invoice_no,

        note,

        source_created_at,

        movement_id,

        flow,
        movement_type,

        from_bucket,
        to_bucket,

        source_entity_type,

        source_id,
        source_name,

        customer_id,
        customer_name_snapshot,

        unit_cost,
        line_value,

        location_name_snapshot,

        client_request_id

      )
      values(

        v_transaction_id,

        v_batch.batch_id,

        new.return_date,
        'Stock In',

        v_code,
        v_name,

        v_purchase_restore,

        v_unit,

        v_batch.location_code,
        v_batch.location_code,

        v_batch.salesman_staff_id,
        v_batch.salesman_name_snapshot,

        new.return_id,
        v_invoice.invoice_no,

        'Invoice Reversal restored PURCHASED stock to live Batch',

        now(),

        v_movement_id,

        'INFLOW',
        'BATCH_SALE_RETURN',

        'EXTERNAL',
        'BATCH_PENDING',

        'CUSTOMER',

        v_invoice.customer_id,
        v_invoice.customer_name_snapshot,

        v_invoice.customer_id,
        v_invoice.customer_name_snapshot,

        v_purchase_cost,

        round(
          v_purchase_restore
          *
          v_purchase_cost,
          6
        ),

        coalesce(
          v_batch.location_name_snapshot,
          v_batch.location_code
        ),

        'BATCH-RETURN:'
        ||
        new.return_id
        ||
        ':'
        ||
        v_code
        ||
        ':PURCHASED'

      );


    end if;



    -- ========================================================
    -- ZERO-COST RESTORE
    -- ========================================================

    if v_zero_restore > 0 then


      v_transaction_id :=

        public.bb_next_prefixed_id(

          'public.stock_activity'::regclass,

          'transaction_id',

          'TRX',

          6

        );



      insert into public.stock_activity(

        transaction_id,

        batch_id,

        activity_date,
        activity_type,

        product_code,
        product_name_snapshot,

        qty,

        unit_snapshot,

        location_code,
        to_location_code,

        salesman_staff_id,
        salesman_name_snapshot,

        reference_no,
        related_invoice_no,

        note,

        source_created_at,

        movement_id,

        flow,
        movement_type,

        from_bucket,
        to_bucket,

        source_entity_type,

        source_id,
        source_name,

        customer_id,
        customer_name_snapshot,

        unit_cost,
        line_value,

        location_name_snapshot,

        client_request_id

      )
      values(

        v_transaction_id,

        v_batch.batch_id,

        new.return_date,
        'Stock In',

        v_code,
        v_name,

        v_zero_restore,

        v_unit,

        v_batch.location_code,
        v_batch.location_code,

        v_batch.salesman_staff_id,
        v_batch.salesman_name_snapshot,

        new.return_id,
        v_invoice.invoice_no,

        'Invoice Reversal restored ZERO-COST stock to live Batch',

        now(),

        v_movement_id,

        'INFLOW',
        'BATCH_SALE_RETURN',

        'EXTERNAL',
        'BATCH_ZERO_COST',

        'CUSTOMER',

        v_invoice.customer_id,
        v_invoice.customer_name_snapshot,

        v_invoice.customer_id,
        v_invoice.customer_name_snapshot,

        0,
        0,

        coalesce(
          v_batch.location_name_snapshot,
          v_batch.location_code
        ),

        'BATCH-RETURN:'
        ||
        new.return_id
        ||
        ':'
        ||
        v_code
        ||
        ':ZERO'

      );


    end if;


  end loop;



  update public.stock_batches

  set

    sold_qty =

      (

        select coalesce(
          sum(
            sold_qty_snapshot
          ),
          0
        )

        from public.stock_batch_items

        where batch_id =
              v_batch.batch_id

      ),


    updated_at =
      now(),


    source_updated_at =
      now()


  where batch_id =
        v_batch.batch_id;



  perform public.bb_stock_refresh_batch_status_internal(
    v_batch.batch_id
  );



  perform public.bb_stock_touch_revision_internal();


  return new;


end;

$function$


CREATE OR REPLACE FUNCTION public.bb_postclose_reversal_stock_v1()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_route public.bb_postclose_reversal_routes%rowtype;
        v_invoice public.invoices%rowtype;
        v_original public.stock_batch_items%rowtype;
        v_target public.stock_batches%rowtype;
        v_target_item public.stock_batch_items%rowtype;
        v_entry jsonb; v_dest jsonb; v_part jsonb;
        v_code text; v_type text; v_batch_id text; v_source text;
        v_qty numeric; v_purchased numeric; v_zero numeric; v_total numeric:=0;
        v_prior_p numeric; v_prior_z numeric; v_source_qty numeric;
        v_sale_p numeric; v_sale_z numeric; v_sale_p_value numeric;
        v_bucket text; v_location text; v_cost numeric;
        v_movement_id text; v_transaction_id text; v_product text; v_unit text;
        v_warehouse_location text; v_match_count integer;
BEGIN
 SELECT * INTO v_route FROM public.bb_postclose_reversal_routes r
 WHERE r.return_id=new.return_id AND r.invoice_id=new.invoice_id;
 IF NOT FOUND THEN RETURN new; END IF;
 SELECT * INTO v_invoice FROM public.invoices WHERE invoice_id=new.invoice_id;
 IF NOT FOUND OR v_invoice.batch_id IS DISTINCT FROM v_route.original_batch_id
 THEN RAISE EXCEPTION 'Post-close source invoice mismatch'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.stock_batches b
     WHERE b.batch_id=v_invoice.batch_id AND upper(b.status)='CLOSED')
 THEN RAISE EXCEPTION 'Original Batch is no longer Closed'; END IF;
 IF new.line_id IS NULL OR NOT EXISTS(SELECT 1 FROM public.invoice_lines il
   WHERE il.invoice_id=new.invoice_id AND il.line_id=new.line_id)
 THEN RAISE EXCEPTION 'Post-close invoice line mismatch'; END IF;
 IF jsonb_typeof(new.stock_allocation_json) IS DISTINCT FROM 'array'
 THEN RAISE EXCEPTION 'Post-close product allocation is missing'; END IF;

 SELECT s.default_warehouse_location_code INTO v_warehouse_location
 FROM public.stock_cutover_state s WHERE s.state_id='MAIN';
 IF v_warehouse_location IS NULL
 THEN RAISE EXCEPTION 'Warehouse location configuration missing'; END IF;
 v_movement_id := public.bb_next_prefixed_id(
    'public.stock_activity'::regclass,'movement_id','STK',6);

 FOR v_entry IN SELECT value FROM jsonb_array_elements(new.stock_allocation_json)
 LOOP
  v_code := nullif(trim(coalesce(v_entry->>'productCode','')),'');
  v_qty := coalesce(nullif(v_entry->>'qty','')::numeric,0);
  IF v_code IS NULL OR v_qty<=0
  THEN RAISE EXCEPTION 'Invalid post-close product allocation'; END IF;
  v_total:=v_total+v_qty;

  SELECT count(*),(jsonb_agg(value))->0 INTO v_match_count,v_dest
  FROM jsonb_array_elements(v_route.destinations)
  WHERE trim(coalesce(value->>'productCode',''))=v_code;
  IF v_match_count<>1 THEN
   RAISE EXCEPTION 'Choose exactly one stock destination for product %',v_code;
  END IF;
  v_type:=upper(trim(coalesce(v_dest->>'destinationType','')));
  v_batch_id:=nullif(trim(coalesce(v_dest->>'batchId','')),'');
  IF v_type NOT IN ('WAREHOUSE','OPEN_BATCH')
  THEN RAISE EXCEPTION 'Invalid destination for %',v_code; END IF;

  SELECT * INTO v_original FROM public.stock_batch_items
  WHERE batch_id=v_invoice.batch_id AND product_code=v_code;
  IF NOT FOUND THEN RAISE EXCEPTION 'Original Batch does not contain %',v_code; END IF;

  IF v_type='OPEN_BATCH' THEN
   IF v_batch_id IS NULL OR v_batch_id=v_invoice.batch_id
   THEN RAISE EXCEPTION 'Invalid target Batch for %',v_code; END IF;
   SELECT * INTO v_target FROM public.stock_batches
   WHERE batch_id=v_batch_id FOR UPDATE;
   IF NOT FOUND OR upper(coalesce(v_target.status,''))<>'OPEN'
    OR v_target.location_code IS DISTINCT FROM v_invoice.location_code
   THEN RAISE EXCEPTION 'Target Batch must be Open in the same location for %',v_code; END IF;
   SELECT * INTO v_target_item FROM public.stock_batch_items
   WHERE batch_id=v_batch_id AND product_code=v_code FOR UPDATE;
   IF NOT FOUND THEN RAISE EXCEPTION 'Product % is missing from target Batch %',v_code,v_batch_id; END IF;
   v_location:=v_target.location_code;
  ELSE
   IF v_batch_id IS NOT NULL THEN RAISE EXCEPTION 'Warehouse destination cannot have Batch ID'; END IF;
   v_location:=v_warehouse_location;
  END IF;

  -- Restore precisely the products and cost source sold by THIS original line.
  -- Original BATCH_SALE activity contains a unique BATCH-INVOICE:<lineId>:... key.
  -- Using that key prevents invoice-number reuse from mixing customers or invoices.
  SELECT
    coalesce(sum(sa.qty) FILTER (WHERE sa.from_bucket='BATCH_PENDING'),0),
    coalesce(sum(sa.qty) FILTER (WHERE sa.from_bucket='BATCH_ZERO_COST'),0),
    coalesce(sum(sa.line_value) FILTER (WHERE sa.from_bucket='BATCH_PENDING'),0)
  INTO v_sale_p,v_sale_z,v_sale_p_value
  FROM public.stock_activity sa
  WHERE sa.movement_type='BATCH_SALE'
    AND sa.batch_id=v_invoice.batch_id
    AND sa.related_invoice_no=v_invoice.invoice_no
    AND sa.customer_id IS NOT DISTINCT FROM v_invoice.customer_id
    AND sa.product_code=v_code
    AND split_part(sa.client_request_id,':',1)='BATCH-INVOICE'
    AND split_part(sa.client_request_id,':',2)=new.line_id
    AND sa.qty>0;

  -- Include any earlier normal (pre-close) or post-close returns of this line.
  SELECT
    coalesce(sum(sa.qty) FILTER (
      WHERE sa.to_bucket IN ('BATCH_PENDING','WAREHOUSE_GOOD')),0),
    coalesce(sum(sa.qty) FILTER (
      WHERE sa.to_bucket IN ('BATCH_ZERO_COST','WAREHOUSE_ZERO_COST')),0)
  INTO v_prior_p,v_prior_z
  FROM public.stock_activity sa
  JOIN public.sales_returns sr ON sr.return_id=sa.reference_no
  WHERE sr.invoice_id=new.invoice_id
    AND sr.line_id=new.line_id
    AND sr.return_id IS DISTINCT FROM new.return_id
    AND sa.product_code=v_code
    AND sa.movement_type IN ('BATCH_SALE_RETURN','POSTCLOSE_SALE_RETURN')
    AND sa.from_bucket='EXTERNAL';

  IF v_sale_p+v_sale_z<=0.000001 THEN
    RAISE EXCEPTION 'Original invoice line stock provenance missing for %; no estimated COGS permitted',v_code;
  END IF;
  -- Validate exact original-line source selected in the BEFORE trigger.
   v_purchased:=nullif(v_entry->>'purchasedQty','')::numeric;
   v_zero:=nullif(v_entry->>'zeroCostQty','')::numeric;
   IF v_purchased IS NULL OR v_zero IS NULL OR v_purchased<0 OR v_zero<0
       OR abs(v_purchased+v_zero-v_qty)>0.000001 THEN
     RAISE EXCEPTION '%: invalid post-close Purchased/Zero-Cost source allocation',v_code;
   END IF;
   IF v_purchased>greatest(v_sale_p-v_prior_p,0)+0.000001 THEN
     RAISE EXCEPTION '%: returned Purchased exceeds original eligible source balance',v_code;
   END IF;
   IF v_zero>greatest(v_sale_z-v_prior_z,0)+0.000001 THEN
    RAISE EXCEPTION 'Return qty exceeds original sold stock source for %',v_code;
  END IF;
  -- Financial COGS must reverse the historical sale cost, not today's moving
  -- warehouse average (which may differ months after the original sale).
  IF v_purchased>0 AND (v_sale_p<=0 OR v_sale_p_value<=0) THEN
    RAISE EXCEPTION 'Original purchased sale cost missing for %; audit review needed',v_code;
  END IF;
  v_cost:=CASE WHEN v_sale_p>0 THEN v_sale_p_value/v_sale_p ELSE 0 END;
  SELECT p.product_name,p.unit INTO v_product,v_unit FROM public.products p
  WHERE p.product_code=v_code;

  FOR v_part IN SELECT value FROM jsonb_array_elements(jsonb_build_array(
    jsonb_build_object('source','PURCHASED','qty',v_purchased),
    jsonb_build_object('source','ZERO_COST','qty',v_zero)
  ))
  LOOP
   v_source:=v_part->>'source';v_source_qty:=(v_part->>'qty')::numeric;
   IF v_source_qty<=0.000001 THEN CONTINUE; END IF;
   v_bucket:=CASE
    WHEN v_type='WAREHOUSE' AND v_source='PURCHASED' THEN 'WAREHOUSE_GOOD'
    WHEN v_type='WAREHOUSE' THEN 'WAREHOUSE_ZERO_COST'
    WHEN v_source='PURCHASED' THEN 'BATCH_PENDING'
    ELSE 'BATCH_ZERO_COST' END;

   v_transaction_id:=public.bb_next_prefixed_id(
     'public.stock_activity'::regclass,'transaction_id','TRX',6);
   INSERT INTO public.stock_activity(
     transaction_id,batch_id,activity_date,activity_type,
     product_code,product_name_snapshot,qty,unit_snapshot,
     location_code,to_location_code,salesman_staff_id,salesman_name_snapshot,
     reference_no,related_invoice_no,note,source_created_at,
     movement_id,flow,movement_type,from_bucket,to_bucket,
     source_entity_type,source_id,source_name,customer_id,customer_name_snapshot,
     unit_cost,line_value,location_name_snapshot,client_request_id
   ) VALUES (
     v_transaction_id,CASE WHEN v_type='OPEN_BATCH' THEN v_batch_id ELSE NULL END,
     new.return_date,'Stock In',v_code,coalesce(v_product,v_code),v_source_qty,
     coalesce(v_unit,''),v_invoice.location_code,v_location,v_invoice.salesperson_staff_id,
     v_invoice.salesperson_name_snapshot,new.return_id,v_invoice.invoice_no,
     'Post-close reversal: original closed Batch '||v_invoice.batch_id||
     ' -> '||v_type||coalesce(' '||v_batch_id,'')||' ('||v_source||')',
     now(),v_movement_id,'INFLOW','POSTCLOSE_SALE_RETURN',
     'EXTERNAL',v_bucket,'CUSTOMER',v_invoice.customer_id,
     v_invoice.customer_name_snapshot,v_invoice.customer_id,
     v_invoice.customer_name_snapshot,
     CASE WHEN v_source='PURCHASED' THEN v_cost ELSE 0 END,
     round(v_source_qty*CASE WHEN v_source='PURCHASED' THEN v_cost ELSE 0 END,6),
     coalesce((select l.location_name from public.locations l
               where l.location_code=v_invoice.location_code),v_invoice.location_code),
     'POSTCLOSE-RETURN:'||new.return_id||':'||v_code||':'||v_source
   );
   INSERT INTO public.bb_postclose_reversal_allocations(
     return_id,invoice_id,original_batch_id,product_code,stock_source,qty,
     destination_type,destination_batch_id,destination_location,stock_transaction_id
   ) VALUES(new.return_id,new.invoice_id,v_invoice.batch_id,
     v_code,v_source,v_source_qty,v_type,v_batch_id,v_location,v_transaction_id);

   IF v_type='OPEN_BATCH' THEN
    UPDATE public.stock_batch_items bi
    SET issued_qty=issued_qty+v_source_qty,
        pending_qty_snapshot=pending_qty_snapshot+v_source_qty,
        purchased_issued_qty=coalesce(purchased_issued_qty,0)+
           CASE WHEN v_source='PURCHASED' THEN v_source_qty ELSE 0 END,
        zero_cost_issued_qty=coalesce(zero_cost_issued_qty,0)+
           CASE WHEN v_source='ZERO_COST' THEN v_source_qty ELSE 0 END,
        purchased_pending_qty_snapshot=coalesce(purchased_pending_qty_snapshot,0)+
           CASE WHEN v_source='PURCHASED' THEN v_source_qty ELSE 0 END,
        zero_cost_pending_qty_snapshot=coalesce(zero_cost_pending_qty_snapshot,0)+
           CASE WHEN v_source='ZERO_COST' THEN v_source_qty ELSE 0 END,
        updated_at=now(),source_updated_at=now()
    WHERE bi.batch_id=v_batch_id AND bi.product_code=v_code;
    UPDATE public.stock_batches b SET issued_qty=issued_qty+v_source_qty,
      updated_at=now(),source_updated_at=now()
    WHERE b.batch_id=v_batch_id;
   END IF;
  END LOOP;
  IF v_type='OPEN_BATCH' THEN
   PERFORM public.bb_stock_refresh_batch_status_internal(v_batch_id);
  END IF;
 END LOOP;
 IF abs(v_total-new.qty)>0.000001
 THEN RAISE EXCEPTION 'Post-close physical product Qty does not match invoice line Qty'; END IF;
 PERFORM public.bb_stock_touch_revision_internal();
 RETURN new;
END;
$function$

