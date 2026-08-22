# archiveme.app — DNS, email, and Vercel cutover

Complete these steps once to provision **hello@archiveme.app** and make **https://archiveme.app** the canonical marketing site.

Code defaults and redirects are already in place:

- `packages/shared/lib/site/marketing-site.ts` — canonical URLs and contact addresses
- `apps/web/middleware.ts` — **308 redirect** from `voicememory.app` → `archiveme.app`
- Mobile app links — `https://archiveme.app/privacy` and `/contact`

## 1. Vercel — attach archiveme.app

1. Vercel project **voice-memory** (web) → **Settings → Domains**
2. Add **archiveme.app** and **www.archiveme.app**
3. At your DNS registrar, add the records Vercel shows (usually `A`/`CNAME` for apex + `www`)
4. Wait until Vercel shows **Valid Configuration**

Keep **voicememory.app** attached to the same project during transition — middleware redirects it to archiveme.app.

## 2. Vercel environment variables

Set in **Production**, **Preview**, and **Development**:

| Variable | Value |
|----------|--------|
| `NEXT_PUBLIC_SITE_URL` | `https://archiveme.app` |
| `NEXT_PUBLIC_APP_URL` | `https://archiveme.app` |
| `EMAIL_FROM` | `ArchiveMe <noreply@archiveme.app>` |

CLI example:

```bash
printf '%s' 'https://archiveme.app' | npx vercel env update NEXT_PUBLIC_SITE_URL production -y
printf '%s' 'https://archiveme.app' | npx vercel env update NEXT_PUBLIC_APP_URL production -y
printf '%s' 'ArchiveMe <noreply@archiveme.app>' | npx vercel env update EMAIL_FROM production -y
```

Redeploy after changing env vars.

## 3. Resend — verify archiveme.app (outbound)

1. https://resend.com/domains → **Add Domain** → `archiveme.app`
2. Add DNS records Resend provides (SPF TXT, DKIM CNAMEs, DMARC TXT recommended)
3. Wait for **Verified** status
4. Confirm production sender:

```bash
./scripts/verify-production-auth-email.sh you@your-inbox.com
```

Expected `emailFromDomain`: `archiveme.app`, `productionEmailReady`: `true`.

See also [RESEND_DOMAIN_AUTH.md](../RESEND_DOMAIN_AUTH.md).

## 4. Inbound — hello@ and support@

Resend sends mail; it does **not** host inboxes. Route inbound to the address you actually read.

**Recommended (Cloudflare Email Routing — free):**

1. Move DNS for `archiveme.app` to Cloudflare (or add Email Routing on an existing zone)
2. **Email → Routing** → create addresses:
   - `hello@archiveme.app` → your real inbox (e.g. Gmail)
   - `support@archiveme.app` → same inbox (billing alias)
3. Add the MX records Cloudflare provides

**Alternative:** Google Workspace, Fastmail, or ImprovMX with the same two addresses forwarding to one inbox.

Do **not** publish `hello@archiveme.app` in the app until a test message to that address reaches your inbox.

## 5. Verification checklist

Run from repo root:

```bash
./scripts/verify-archiveme-domain-setup.sh
node --import tsx scripts/validate-consumer-brand-audit.mjs
```

Manual checks:

- [ ] https://archiveme.app loads marketing homepage
- [ ] https://voicememory.app/privacy → redirects to https://archiveme.app/privacy
- [ ] https://archiveme.app/contact shows **hello@archiveme.app**
- [ ] Mail to hello@archiveme.app arrives in your inbox
- [ ] Auth sign-in code email sends from `noreply@archiveme.app`
- [ ] iOS Settings → Privacy opens https://archiveme.app/privacy
- [ ] App Store Connect support URL = https://archiveme.app/contact

## 6. Legacy retirement (after 30 days stable)

- Remove `voicememory.app` from Vercel when redirect traffic drops
- Retire `hello@voicememory.app` forward if no longer needed
- Update App Store listing if still showing old URLs
