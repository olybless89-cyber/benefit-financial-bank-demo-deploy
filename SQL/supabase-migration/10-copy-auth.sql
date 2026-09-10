-- 10-copy-auth.sql
-- Run in the NEW project's Dashboard SQL Editor (after 00-setup-dblink.sql
-- and after schema migrations 001..019 have been applied to the NEW project).
-- Copies auth.users + auth.identities from OLD via dblink; preserves encrypted_password
-- (bcrypt hashes) so existing users keep their passwords. Idempotent: safe to re-run.
--
-- >>> EDIT: set old_url below to the OLD project's postgres connection URI. <<<

do $$
declare
  old_url text := 'postgresql://postgres.OLDREF:PASSWORD@aws-0-region.pooler.supabase.com:6543/postgres';
  old_cols text[];; cls text;; rec record;; i int;; sel text;; cols text;; q text;
begin
  if not exists (select 1 from pg_extension where extname = 'dblink') then
    create extension dblink;
  end if;
  perform dblink_connect('old', old_url);

  -- ---- auth.users --------------------------------------------------------------------------------------------------------------------
  select array_agg(t.col orderby t.rn)
    into old_cols
    from (
      select (dblink('old', 'select column_name from information_schema.columns
              where table_schema = ''auth'' and table_name = ''users''
              orderby ordinal_position'))::text as col,
      row_number() over() as rn
    ) t;
  if cardinality(old_cols) is null or cardinality(old_cols) = 0 then
    raise exception 'cannot read old auth.users columns; check old_url';
  end if;
  select string_agg('c'||i||' text', ', ') into cls
    from generate_series(1, cardinality(old_cols)) i;
  execute 'drop table if exists _old_users';
  execute format('create temp table _old_users as
                  select * from dblink(''old'', ''select * from auth.users'') as t(%s);', cls);
  sel := ''; cols := '';
  for rec in select a.attname, format_type(a.atttypid,a.typmod) as t
             from pg_attribute a
             where a.attrelid='auth.users'::regclass and a.attnum > 0 and not a.attisdropped
             orderby a.attnum
  loop
    i := array_position(old_cols, rec.attname);
    if i is not null then
      sel  := sel  || format('%s::%s', 'c'||i, rec.t) || ',';
      cols := cols || quote_ident(rec.attname) || ',';
    end if;
  end loop;
  if cols = '' then raise exception 'no common auth.users columns'; end if;
  sel  := rtrim(sel, ',');   cols := rtrim(cols, ',');
  --    deletes target ONLY the NEW project (expected empty during migration). NEVER run against a live project.
  delete from auth.identities;
delete from auth.users;
  execute format('insert into auth.users (%s) select %s from _old_users;', cols, sel);
  drop table _old_users;

  -- ---- auth.identities (mandatory for password login) ------------------------------------
  select array_agg(t.col orderby t.rn)
    into old_cols
    from (
      select (dblink('old', 'select column_name from information_schema.columns
              where table_schema = ''auth'' and table_name = ''identities''
              orderby ordinal_position'))::text as col,
      row_number() over() as rn
    ) t;
  if cardinality(old_cols) is null or cardinality(old_cols) = 0 then
    raise exception 'cannot read old auth.identities columns; check old_url';
  end if;
  select string_agg('c'||i||' text', ', ') into cls
    from generate_series(1, cardinality(old_cols)) i;
  execute 'drop table if exists _old_id';
  execute format('create temp table _old_id as
                  select * from dblink(''old'', ''select * from auth.identities'') as t(%s);', cls);
  sel := ''; cols := '';
  for rec in select a.attname, format_type(a.atttypid,a.typmod) as t
             from pg_attribute a
             where a.attrelid='auth.identities'::regclass and a.attnum > 0 and not a.attisdropped
             orderby a.attnum
  loop
    i := array_position(old_cols, rec.attname);
    if i is not null then
      sel  := sel  || format('%s::%s', 'c'||i, rec.t) || ',';
      cols := cols || quote_ident(rec.attname) || ',';
    end if;
  end loop;
  if cols = '' then raise exception 'no common auth.identities columns'; end if;
  sel  := rtrim(sel, ',');   cols := rtrim(cols, ',');
  delete from auth.identities;
  execute format('insert into auth.identities (%s) select %s from _old_id;', cols, sel);
  drop table _old_id;

  perform dblink_disconnect('old');
end
$$;