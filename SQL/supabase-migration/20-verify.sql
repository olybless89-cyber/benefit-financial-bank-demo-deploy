-- 20-verify.sql
-- Row-count sanity: OLD (via dblink) vs NEW (local. Run in NEW's SQL editor AFTER 10/11.
-- Every table's old_count should equal new_count. auth.users.encrypted_password counts confirm password hashes were carried over.

do $$
begin
  if exists (select 1 from dblink_get_connections() where t = 'old') then
    perform dblink_disconnect('old');
  end if;
  perform dblink_connect('old', 'postgresql://postgres.OLDREF:PASSWORD@aws-0-region.pooler.supabase.com:6543/postgres');
end
$$;

select 'auth.users' as table_name,
  (select count(*) from dblink('old', 'select 1 from auth.users')) as old_count,
  (select count(*) from auth.users) as new_count;

select 'auth.identities' as table_name,
  (select count(*) from dblink('old', 'select 1 from auth.identities')) as old_count,
  (select count(*) from auth.identities) as new_count;

select 'public.profiles' as table_name,
  (select count(*) from dblink('old', 'select 1 from public.profiles')) as old_count,
  (select count(*) from public.profiles) as new_count;

select 'public.transactions' as table_name,
  (select count(*) from dblink('old', 'select 1 from public.transactions')) as old_count,
  (select count(*) from public.transactions) as new_count;

select 'public.deposit_requests' as table_name,
  (select count(*) from dblink('old', 'select 1 from public.deposit_requests')) as old_count,
  (select count(*) from public.deposit_requests) as new_count;

select 'public.transfer_requests' as table_name,
  (select count(*) from dblink('old', 'select 1 from public.transfer_requests')) as old_count,
  (select count(*) from public.transfer_requests) as new_count;

select 'public.loan_applications' as table_name,
  (select count(*) from dblink('old', 'select 1 from public.loan_applications')) as old_count,
  (select count(*) from public.loan_applications) as new_count;

select 'public.support_tickets' as table_name,
  (select count(*) from dblink('old', 'select 1 from public.support_tickets')) as old_count,
  (select count(*) from public.support_tickets) as new_count;

select 'public.payment_methods' as table_name,
  (select count(*) from dblink('old', 'select 1 from public.payment_methods')) as old_count,
  (select count(*) from public.payment_methods) as new_count;

select 'public.cards' as table_name,
  (select count(*) from dblink('old', 'select 1 from public.cards')) as old_count,
  (select count(*) from public.cards) as new_count;

-- Password-hash sanity: count of users with a bcrypt hash (old vs new).
select 'auth.users.encrypted_password' as check_name,
  (select count(*) from dblink('old', 'select 1 from auth.users where encrypted_password is not null')) as old_count,
  (select count(*) from auth.users where encrypted_password is not null) as new_count;

do $$
begin
  perform dblink_disconnect('old');
end
$$;