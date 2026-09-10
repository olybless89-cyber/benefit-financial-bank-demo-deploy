# Auto-Deploy Active
Every push to `main` automatically:
1. Runs SQL migrations in `SQL/supabase/` against the Supabase project named by
   the `SUPABASE_PROJECT_REF` secret. The site embeds project
   `<PROJECT_REF>` (from the committed `<SUPA...>` placeholders), so the secret must
   point at that project.
2. Frontend is deployed by Vercel's own Git integration (the CI `vercel deploy`
   job was removed — it duplicated the integration and failed on every run).

## Railway runtime (2026-09-06)
- Railway start command: `node serve.js` (Node 22 via Nixpacks; PHP/php81
  removed — the `php -S` build crashed before Railway could register the app,
  leaving the site on railway `x-railway-fallback`{Application not found}).
- `serve.js` serves `public/` with the clean-URL rewrites, vendors the Supabase
  SDK, and rewrites/serves the hosted Supabase URL/anon key at serve time.

## Go-live DNS / SSL checklist (2026-09-09)
The live `benefitfinbnk.com` A record currently points at **Railway** (`69.46.46.98`)
which returns `{"status":"error","code":404,"message":"Application not found"}` and serves
Railway's wildcard cert (`*.up.railway.app`) — hence the browser shows the invalid-cert
warning (ERR_CERT_COMMON_NAME_INVALID). The frontend is supposed to be served by **Vercel**
(see README Deployment; DEPLOY_STATUS above), so the DNS must point at Vercel instead:

1. **Vercel**: add the domain `benefitfinbnk.com` (and `www`) to the project's
   Domains settings. The project's domain card shows the exact record values to use.
2. **Name.com DNS** (nameservers are `ns1kpv.name.com` etc.):
   - A record `@` → `76.76.21.21`  (or the value shown on the Vercel domain card)
   - CNAME `www` → `cname.vercel-dns.com`  (or the value shown on the Vercel domain card)
   - Delete the old Railway A record (69.46.46.98) to avoid split traffic.

3. Vercel auto-provisions SSL once DNS propagates (typically minutes–hours)..
4. Then push this repo's `main` to trigger the Vercel Git-integration deploy +
   CI Supabase migrations. Note: the committed git remote token and `$GITHUB_TOKEN`
   were both rejected (`Invalid username or token` / `Bad credentials`) on 2026-09-09,
   so a **fresh fine-grained PAT** with `repo` scope is needed to push (or update
   the `origin` remote URL + repo secret)．

Last updated: 2026-09-09

