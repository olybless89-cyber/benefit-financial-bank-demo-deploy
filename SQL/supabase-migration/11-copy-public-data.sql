-- 11-copy-public-data.sql
-- Run in the NEW project's Dashboard SQL Editor(after 00-setup + 10-copy-auth.sql).
-- Copies all 8 public tables from OLD via dblink. FK-safe order(auth already copied);
-- hardcoded typed column lists matching the repo schema (002/011/014/015).
-- Idempotent: deletes ONLY rows in NEW it previously inserted. NEVER touches OLD.
--
-- >>> EDIT: set OLD_DB_URL below to the OLD project's postgres URI ## <<<

do $$
begin
  if exists (select 1 from dblink_get_connections() where t = 'old') then
    perform dblink_disconnect('old');
  end if;
  perform dblink_connect('old', 'postgresql://postgres.OLDREF:PASSWORD@aws-0-region.pooler.supabase.com:6543/postgres');
end
$$;

-- ---- payment_methods(15 cols)------------------------------------------------------------------------------------------------
delete from public.payment_methods;
insert into public.payment_methods (id,active,wallet_address,network,bank_name,account_name,account_number,swift_bic,iban,bank_address,currency,paypal_email,instructions,updated_by,updated_at)
select c1::text,c2::boolean,c3::text,c4::text,c5::text,c6::text,c7::text,c8::text,c9::text,c10::text,c11::text,c12::text,c13::text,c14::uuid,c15::timestamptz
from dblink('old', 'select id,active,wallet_address,network,bank_name,account_name,account_number,swift_bic,iban,bank_address,currency,paypal_email,instructions,updated_by,updated_at from public.payment_methods')
as t(c1 text,c2 text,c3 text,c4 text,c5 text,c6 text,c7 text,c8 text,c9 text,c10 text,c11 text,c12 text,c13 text,c14 text,c15 text);

-- ---- profiles(13 cols)----------------------------------------------------------------------------------------------------
delete from public.profiles;
insert into public.profiles (id,email,full_name,phone,role,status,kyc_status,balance,held_funds,account_number,transaction_limit,created_at,updated_at)
select c1::uuid,c2::text,c3::text,c4::text,c5::text,c6::text,c7::text,c8::numeric(14,2),c9::numeric(14,2),c10::text,c11::numeric(14,2),c12::timestamptz,c13::timestamptz
from dblink('old', 'select id,email,full_name,phone,role,status,kyc_status,balance,held_funds,account_number,transaction_limit,created_at,updated_at from public.profiles')
as t(c1 text,c2 text,c3 text,c4 text,c5 text,c6 text,c7 text,c8 text,c9 text,c10 text,c11 text,c12 text,c13 text);

-- ---- transactions(11 cols)------------------------------------------------------------------------------------------------
delete from public.transactions;
insert into public.transactions (id,user_id,type,amount,status,description,reference,recipient,held,created_at)
select c1::uuid,c2::uuid,c3::text,c4::numeric(14,2),c5::text,c6::text,c7::text,c8::text,c9::boolean,c10::timestamptz
from dblink('old', 'select id,user_id,type,amount,status,description,reference,recipient,held,created_at from public.transactions')
as t(c1 text,c2 text,c3 text,c4 text,c5 text,c6 text,c7 text,c8 text,c9 text,c10 text);

-- ---- deposit_requests(9 cols)--------------------------------------------------------------------------------------------
delete from public.deposit_requests;
insert into public.deposit_requests (id,user_id,amount,method,reference,status,note,created_at)
select c1::uuid,c2::uuid,c3::numeric(14,2),c4::text,c5::text,c6::text,c7::text,c8::timestamptz
from dblink('old', 'select id,user_id,amount,method,reference,status,note,created_at from public.deposit_requests')
as t(c1 text,c2 text,c3 text,c4 text,c5 text,c6 text,c7 text,c8 text);

-- ---- transfer_requests(10 cols)------------------------------------------------------------------------------------------
delete from public.transfer_requests;
insert into public.transfer_requests (id,user_id,amount,recipient_name,recipient_account,bank_name,reason,status,note,created_at)
select c1::uuid,c2::uuid,c3::numeric(14,2),c4::text,c5::text,c6::text,c7::text,c8::text,c9::text,c10::timestamptz
from dblink('old', 'select id,user_id,amount,recipient_name,recipient_account,bank_name,reason,status,note,created_at from public.transfer_requests')
as t(c1 text,c2 text,c3 text,c4 text,c5 text,c6 text,c7 text,c8 text,c9 text,c10 text);

-- ---- loan_applications(10 cols)------------------------------------------------------------------------------------------
delete from public.loan_applications;  
insert into public.loan_applications (id,user_id,amount,term_months,purpose,monthly_income,status,note,created_at)
select c1::uuid,c2::uuid,c3::numeric(14,2),c4::int,c5::text,c6::numeric(14,2),c7::text,c8::text,c9::timestamptz
from dblink('old', 'select id,user_id,amount,term_months,purpose,monthly_income,status,note,created_at from public.loan_applications')
as t(c1 text,c2 text,c3 text,c4 text,c5 text,c6 text,c7 text,c8 text,c9 text);

-- ---- support_tickets(9 cols)------------------------------------------------------------------------------------------------
delete from public.support_tickets;  
insert into public.support_tickets (id,user_id,category,subject,message,admin_reply,status,created_at,updated_at)
select c1::uuid,c2::uuid,c3::text,c4::text,c5::text,c6::text,c7::text,c8::timestamptz,c9::timestamptz
from dblink('old', 'select id,user_id,category,subject,message,admin_reply,status,created_at,updated_at from public.support_tickets')
as t(c1 text,c2 text,c3 text,c4 text,c5 text,c6 text,c7 text,c8 text,c9 text);

-- ---- cards(10 cols, incl pin from 015)----------------------------------------------------------------------------
delete from public.cards;  
insert into public.cards (id,user_id,card_number,expiry_month,expiry_year,cvv,status,created_at,updated_at,pin)
select c1::uuid,c2::uuid,c3::text,c4::int,c5::int,c6::text,c7::text,c8::timestamptz,c9::timestamptz,c10::text
from dblink('old', 'select id,user_id,card_number,expiry_month,expiry_year,cvv,status,created_at,updated_at,pin from public.cards')
as t(c1 text,c2 text,c3 text,c4 text,c5 text,c6 text,c7 text,c8 text,c9 text,c10 text);

do $$
begin
  perform dblink_disconnect('old');
end
$$;