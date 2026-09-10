#!/usr/bin/env bash
set -euo pipefail

# Migrate auth + data from OLD Supabase to NEW Supabase (same logins).
# Prereq: OLD_DB_URL, NEW_DB_URL exported; pg_dump + psql installed.



: "${OLD_DB_URL:?set OLD_DB_URL}"; : "${NEW_DB_URL:?set NEW_DB_URL}"

AUTH_TABLES=(auth.users auth.identities)
PUBLIC_TABLES=(public.payment_methods public.profiles public.transactions public.deposit_requests public.transfer_requests public.loan_applications public.support_tickets public.cards)

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "-> Copying auth (preserves bcrypt password hashes; no sessions/refresh_tokens)..."
pg_dump --data-only --no-owner --no-privileges --dbname="$OLD_DB_URL" \
        --table=auth.users --table=auth.identities > "$tmp/auth.sql"
psql -v ON_ERROR_STOP=1 --dbname="$NEW_DB_URL" -f "$tmp/auth.sql"

echo "-> Copying public data (FK-safe order)..."
for t in "${PUBLIC_TABLES[@]}"; do
    echo "   $t"
    pg_dump --data-only --no-owner --no-privileges --dbname="$OLD_DB_URL" \
            --table="$t" > "$tmp/${t//\//_}.sql"
    psql -v ON_ERROR_STOP=1 --dbname="$NEW_DB_URL" -f "$tmp/${t//\//_}.sql"
done

echo; echo "Row counts  old vs new:"; echo "   table                          old       new"
check() {
    local t="$1" o n
    o=$(psql -At --dbname="$OLD_DB_URL" -c "select count(*) from $t;")
    n=$(psql -At --dbname="$NEW_DB_URL" -c "select count(*) from $t;")
    printf "   %-28s %-9s %s\n" "$t" "$o" "$n"
}
for t in "${AUTH_TABLES[@]}" "${PUBLIC_TABLES[@]}"; do check "$t"; done

echo; echo "Done. Now: switch runtime files + CI secrets + re-point edge function (see README."