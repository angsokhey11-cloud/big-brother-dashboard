-- Calls actual snapshot save functions with synthetic fixtures. No production connection.
create function public.fixture_invoice(id text,no text,cid text,method text,cur text default 'USD',paid numeric default 0,batch text default '',bank text default '',tx text default '',quantity numeric default 12,price numeric default 2.5) returns jsonb language sql as $$
select jsonb_build_object('invoiceId',id,'invoiceNo',no,'invoiceDate','2026-11-24','dueDate','2026-11-28','locationCode','L1','customerId',cid,'customer','Synthetic '||cid,'salespersonStaffId','S1','salesperson','Test staff','paymentMethod',method,'currency',cur,'exchangeRate',4100,'discount',0,'amountPaid',paid,'batchNumber',batch,'paymentBank',bank,'transactionId',tx,
 'items',jsonb_build_array(jsonb_build_object('productCode','P1','productName','Test milk','unit','bt','entryType','EXACT','qty',quantity,'unitPrice',price,'stockAllocations',jsonb_build_array(jsonb_build_object('source','PURCHASED','qty',quantity)))))
$$;
do $test$
declare r jsonb; p jsonb; before_stock numeric; before_bank numeric; error_text text;
begin
 p:=public.fixture_invoice('TEST-CASH','INV-1','C1','Cash','USD',30);
 r:=public.bb_sales_save_invoice_bundle(p,jsonb_build_object('amount',30));
 if r->>'status'<>'Paid' or (select grand_total from public.invoices where invoice_id='TEST-CASH')<>30 or (select sum(amount) from public.payments where invoice_id='TEST-CASH')<>30 then raise exception 'Cash totals mismatch';end if;
 if (select qty from public.fixture_stock where scope='WH' and product_code='P1' and source='PURCHASED')<>188 then raise exception 'Warehouse deduction mismatch';end if;
 if (select qty from public.fixture_stock where scope='B1' and product_code='P1' and source='PURCHASED')<>60 then raise exception 'Warehouse changed batch';end if;
 raise notice 'PASS cash, base-unit arithmetic and warehouse isolation';
 r:=public.bb_sales_save_invoice_bundle(public.fixture_invoice('TEST-CREDIT','INV-1','C2','Credit'),null);
 if (r->>'outstanding')::numeric<>30 or exists(select 1 from public.payments where invoice_id='TEST-CREDIT') then raise exception 'Credit mismatch';end if;
 if not (public.bb_sales_check_invoice_customer('INV-1','C1')->>'exists')::boolean then raise exception 'Duplicate precheck wrong';end if;
 before_stock:=(select qty from public.fixture_stock where scope='WH' and product_code='P1' and source='PURCHASED');
 begin
   perform public.bb_sales_save_invoice_bundle(public.fixture_invoice('TEST-DUP','INV-1','C1','Cash'),jsonb_build_object('amount',30));
   raise exception 'Unexpected duplicate success';
 exception when others then get stacked diagnostics error_text=message_text;if error_text not like '%already exists for this Customer%' then raise;end if;end;
 if exists(select 1 from public.invoices where invoice_id='TEST-DUP') or (select qty from public.fixture_stock where scope='WH' and product_code='P1' and source='PURCHASED')<>before_stock then raise exception 'Duplicate changed records';end if;
 raise notice 'PASS credit, duplicate pair and number reuse across customers';
 r:=public.bb_sales_save_invoice_bundle(public.fixture_invoice('TEST-PART','INV-2','C1','Partially Paid in Cash','USD',10,'B1'),jsonb_build_object('amount',10));
 if (r->>'outstanding')::numeric<>20 or (select qty from public.fixture_stock where scope='B1' and product_code='P1' and source='PURCHASED')<>48 then raise exception 'Partial cash/batch mismatch';end if;
 raise notice 'PASS partial cash and batch deduction';
 r:=public.bb_sales_save_invoice_bundle(public.fixture_invoice('TEST-FX1','INV-3','C1','Bank','USD',30,'','ABA','FX-KHR'),jsonb_build_object('amount',30));
 if (select actual_bank_amount from public.payments where invoice_id='TEST-FX1')<>123000 then raise exception 'USD invoice/KHR debit mismatch';end if;
 r:=public.bb_sales_save_invoice_bundle(public.fixture_invoice('TEST-FX2','INV-4','C1','Bank','KHR',41000,'','ABA','FX-USD',1,41000),jsonb_build_object('amount',41000));
 if (select actual_bank_amount from public.payments where invoice_id='TEST-FX2')<>10 then raise exception 'KHR invoice/USD debit mismatch';end if;
 raise notice 'PASS both FX directions using historical bank trigger';
 p:=public.fixture_invoice('TEST-SPLIT','INV-5','C1','Cash + Bank','USD',30,'','ABA','TX-A');
 r:=public.bb_sales_save_invoice_split_payment(p,jsonb_build_object('amount',30,'cashAmount',10,'bankAmount',20));
 if (select count(*) from public.payments where invoice_id='TEST-SPLIT')<>2 or (select sum(amount) from public.payments where invoice_id='TEST-SPLIT')<>30 then raise exception 'Split payment mismatch';end if;
 before_stock:=(select qty from public.fixture_stock where scope='WH' and product_code='P1' and source='PURCHASED');
 before_bank:=(select remaining_amount from public.bb_bank_balance_snapshot where transaction_id='TX-A');
 begin
   perform public.bb_sales_save_invoice_split_payment(public.fixture_invoice('TEST-ROLLBACK','INV-6','C1','Cash + Bank','USD',30,'','ABA','TX-A'),jsonb_build_object('amount',30,'cashAmount',10,'bankAmount',19));
   raise exception 'Unexpected split success';
 exception when others then get stacked diagnostics error_text=message_text;if error_text not like '%must equal Grand Total%' then raise;end if;end;
 if exists(select 1 from public.invoices where invoice_id='TEST-ROLLBACK') or exists(select 1 from public.payments where invoice_id='TEST-ROLLBACK') or (select qty from public.fixture_stock where scope='WH' and product_code='P1' and source='PURCHASED')<>before_stock or (select remaining_amount from public.bb_bank_balance_snapshot where transaction_id='TX-A')<>before_bank then raise exception 'Rollback incomplete';end if;
 raise notice 'PASS split cash/bank and atomic rollback';
 p:=public.fixture_invoice('TEST-GROUP','INV-7','C1','Credit','USD',0,'B1');
 p:=jsonb_set(p,'{items}',jsonb_build_array(jsonb_build_object('entryType','GROUP','productCode','G1','productGroupCode','G1','qty',5,'unitPrice',2,'unit','bt')));
 r:=public.bb_sales_save_invoice_bundle(p,null);
 if (select qty from public.fixture_stock where scope='B1' and product_code='P2' and source='PURCHASED')<>25 then raise exception 'Group allocation mismatch';end if;
 raise notice 'PASS group member allocation';
 if not (public.bb_sales_verify_invoice_save('TEST-CASH')->>'found')::boolean or (public.bb_sales_verify_invoice_save('TEST-ROLLBACK')->>'found')::boolean then raise exception 'Recovery verification mismatch';end if;
 perform set_config('bb_test.write','off',true);
 begin
   perform public.bb_sales_save_invoice_bundle(public.fixture_invoice('TEST-DENIED','INV-8','C1','Cash'),jsonb_build_object('amount',30));
   raise exception 'Unexpected permission success';
 exception when others then get stacked diagnostics error_text=message_text;if error_text not like '%create access denied%' then raise;end if;end;
 if exists(select 1 from public.invoices where invoice_id='TEST-DENIED') then raise exception 'Denied invoice saved';end if;
 raise notice 'PASS recovery verification and permission rejection';
end $test$;
