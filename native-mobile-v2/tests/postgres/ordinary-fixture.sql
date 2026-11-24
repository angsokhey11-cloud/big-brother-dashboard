-- Extend the synthetic fixture, not production. Stock trigger below is a test double.
alter table public.invoices
 add column subtotal numeric(18,2), add column discount numeric(18,2),
 add column change_amount numeric, add column outstanding numeric(18,2), add column status text,
 add column note text, add column due_date date, add column bank_payment text, add column bank_reference text,
 add column credit_amount numeric, add column batch_number text, add column shipping_to_legacy text;
alter table public.invoices alter column grand_total type numeric(18,2), alter column amount_paid type numeric(18,2);
create unique index uq_invoices_invoice_no_customer_id on public.invoices(lower(trim(invoice_no)),customer_id);
alter table public.payments alter column amount type numeric(18,2);
create table public.locations(location_code text primary key,active boolean);
create table public.staff(staff_id text primary key,staff_name text,status text);
create table public.products(product_code text primary key,product_name text,barcode text,unit text,active boolean);
create table public.product_groups(group_code text primary key,group_name text,active boolean);
create table public.stock_batches(batch_id text primary key,location_code text,status text);
create table public.product_group_mapping(product_code text,group_code text,use_group boolean,status text);
create table public.invoice_lines(line_id text primary key,invoice_id text references public.invoices(invoice_id),invoice_no_snapshot text,line_no int,entry_type text,product_code text,product_group_code text,display_product_code text,product_name_snapshot text,product_barcode_snapshot text,product_note text,qty numeric(18,4),unit_snapshot text,unit_price numeric(18,4),line_total numeric,stock_allocation_json jsonb);
create table public.fixture_stock(scope text,product_code text,source text,qty numeric,primary key(scope,product_code,source));
create view public.v_batch_reconciliation as select scope as batch_id,product_code,sum(qty) as difference_qty from public.fixture_stock where scope<>'WH' group by scope,product_code;
create or replace function public.bb_has_module_access(text,text) returns boolean language sql as $$select coalesce(current_setting('bb_test.write',true),'on')<>'off'$$;
create or replace function public.bb_has_sales_write() returns boolean language sql as $$select coalesce(current_setting('bb_test.write',true),'on')<>'off'$$;
create or replace function public.bb_has_location_access(text) returns boolean language sql as $$select $1='L1'$$;
create function public.bb_is_active_user() returns boolean language sql as $$select true$$;
insert into public.locations values('L1',true),('L2',true);
insert into public.staff values('S1','Test staff','active');
insert into public.customers values('C2',true);
alter table public.customers add column customer_name text, add column location_code text;
update public.customers set customer_name='Synthetic '||customer_id,location_code='L1';
insert into public.products values('P1','Test milk','B1','bt',true),('P2','Test group member','B2','bt',true),('SVC','Test service','','unit',true);
insert into public.stock_batches values('B1','L1','OPEN');
insert into public.product_groups values('G1','Test group',true);
insert into public.product_group_mapping values('P2','G1',true,'active');
insert into public.fixture_stock values('WH','P1','PURCHASED',200),('WH','P1','ZERO_COST',100),('B1','P1','PURCHASED',60),('B1','P1','ZERO_COST',20),('B1','P2','PURCHASED',30);
insert into public.bb_verified_bank_transactions(transaction_id,customer_id,bank_name,currency,status,amount,approved_exchange_rate) values
 ('FX-KHR','C1','ABA','KHR','AVAILABLE',410000,4100),('FX-USD','C1','ABA','USD','AVAILABLE',100,4100);
create function public.fixture_stock_guard() returns trigger language plpgsql as $$
declare a jsonb;scope_key text;product_key text;source_key text;used numeric:=0;amount numeric;
begin
 if new.product_code='SVC' then return new;end if;
 select coalesce(batch_number,'WH') into scope_key from public.invoices where invoice_id=new.invoice_id;
 if jsonb_typeof(new.stock_allocation_json) is distinct from 'array' then raise exception 'Fixture requires stock allocation';end if;
 for a in select value from jsonb_array_elements(new.stock_allocation_json) loop
   product_key:=coalesce(a->>'productCode',new.product_code);
   source_key:=coalesce(a->>'source','PURCHASED');
   amount:=(a->>'qty')::numeric;
   update public.fixture_stock set qty=qty-amount where scope=scope_key and product_code=product_key and source=source_key and qty>=amount and amount>0;
   if not found then raise exception 'Fixture stock insufficient';end if;
   used:=used+amount;
 end loop;
 if used<>new.qty then raise exception 'Fixture allocation mismatch';end if;
 return new;
end $$;
create trigger fixture_stock_guard before insert on public.invoice_lines for each row execute function public.fixture_stock_guard();
