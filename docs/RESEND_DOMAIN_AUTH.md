# Resend verified domain — production auth email

Use this after [Resend](https://resend.com/domains) shows **Verified** for **archiveme.app**.

Full cutover checklist: [docs/product/ARCHIVEME_APP_DNS.md](./product/ARCHIVEME_APP_DNS.md)

## 1. Add and verify domain (Resend dashboard)

1. Open https://resend.com/domains
2. **Add Domain** — `archiveme.app`
3. Add DNS records at your registrar (Resend shows exact host/names):

| Type | Purpose |
| --- | --- |
| TXT | SPF |
| CNAME | DKIM (usually 2–3 records) |
| TXT | DMARC (recommended) |

4. Wait until status is **Verified** (often 5–60 minutes after DNS propagates)

## 2. Update Vercel `EMAIL_FROM`

Project: **voice-memory** → Settings → Environment Variables

Set **EMAIL_FROM** (Production, Preview, Development):

```text
ArchiveMe <noreply@archiveme.app>
```

Rules:

- Use an address on the **verified** domain (`noreply@`, `auth@`, etc.)
- Do **not** use `onboarding@resend.dev` in production (sandbox: only the Resend account owner inbox)
- Display name + angle brackets are supported by the app validator

CLI (no stray quotes):

```bash
printf '%s' 'ArchiveMe <noreply@archiveme.app>' | npx vercel env update EMAIL_FROM production -y
printf '%s' 'ArchiveMe <noreply@archiveme.app>' | npx vercel env update EMAIL_FROM preview -y
printf '%s' 'ArchiveMe <noreply@archiveme.app>' | npx vercel env update EMAIL_FROM development -y
```

Also set:

```bash
printf '%s' 'https://archiveme.app' | npx vercel env update NEXT_PUBLIC_SITE_URL production -y
printf '%s' 'https://archiveme.app' | npx vercel env update NEXT_PUBLIC_APP_URL production -y
```

Wait 1–2 minutes (redeploy only if sends still use the old sender).

## 3. Verify production

```bash
curl -sS https://voice-memory-iota.vercel.app/api/debug/auth-env
```

Expected:

```json
{
  "resendConfigured": true,
  "emailFromConfigured": true,
  "emailFromUsesResendSandbox": false,
  "emailFromDomain": "archiveme.app",
  "appUrlConfigured": true,
  "productionEmailReady": true
}
```

If `emailFromUsesResendSandbox` is **true**, Production still has `onboarding@resend.dev` — update `EMAIL_FROM` after Resend shows **Verified**.

```bash
chmod +x scripts/verify-production-auth-email.sh
./scripts/verify-production-auth-email.sh
./scripts/verify-production-auth-email.sh you@yourdomain.com
./scripts/verify-archiveme-domain-setup.sh
```

## 4. Inbound contact addresses

Customer-facing contact: **hello@archiveme.app** (web, app help, TestFlight feedback).

Billing alias: **support@archiveme.app** — forward to the same inbox via Cloudflare Email Routing or your mail host.

Resend does not receive inbound mail; configure MX/forwarding separately (see ARCHIVEME_APP_DNS.md).

## 5. Send-code test (any user email)

`POST /api/auth/send-code` with a **real** inbox you can open (not required to be the Resend owner).

Expected:

- HTTP **200**
- `{ "ok": true, "message": "Code sent. Check your email." }`
- No `AUTH_RESEND_REJECTED`

## 6. Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| `AUTH_RESEND_REJECTED` + sender message | `EMAIL_FROM` not on verified domain, or domain not verified |
| `AUTH_RESEND_REJECTED` + “only send testing emails to your own…” | Still on `onboarding@resend.dev` |
| `AUTH_RESEND_NOT_CONFIGURED` | Missing `RESEND_API_KEY` or `EMAIL_FROM` in Production |
| Env probe all `true` but send fails | Wrong `EMAIL_FROM` value or literal quotes in Vercel value — re-set via CLI above |
| hello@ bounces | Inbound MX/forwarding not configured — see ARCHIVEME_APP_DNS.md |

Vercel logs: filter `[ArchiveMe auth]` for `resendResponseId`, `resendErrorMessage`, `errorCode`.

## Legacy

`voicememory.app` remains a redirect host until DNS is retired. Do not use `hello@voicememory.app` in new copy.
