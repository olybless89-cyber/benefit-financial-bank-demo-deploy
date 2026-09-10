-- 00-setup-dblink.sql
-- Run this FIRST in the NEW project's Dashboard SQL Editor.
-- It enables the dblink extension and verifies connectivity to the OLD project.

-- >>> EDIT THIS: paste the OLD project's postgres connection URI <<<
select dblink_connect('old', 'postgresql://postgres.OLDREF:PASSWORD@aws-0-region.pooler.supabase.com:6543/postgres');

-- If the line above returns OK, keep the connection open for the next scripts
-- (or just re-open in each script; 10/20 open their own connection if needed).

-- If you get "conn: connection error" double-check the URI(project   Connect   Connection string   URI).