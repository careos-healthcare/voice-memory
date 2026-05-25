# Resend verified domain — production auth email

Use this after [Resend](https://resend.com/domains) shows **Verified** for a domain you control.

## 1. Add and verify domain (Resend dashboard)

1. Open https://resend.com/domains
2. **Add Domain** — e.g. `voicememory.app` (must be a domain you control)
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
VoiceMemory <noreply@YOUR_VERIFIED_DOMAIN>
```

Example:

```text
VoiceMemory <noreply@voicememory.app>
```

Rules:

- Use an address on the **verified** domain (`noreply@`, `auth@`, etc.)
- Do **not** use `onboarding@resend.dev` in production (sandbox: only the Resend account owner inbox)
- Display name + angle brackets are supported by the app validator

CLI (no stray quotes):

```bash
printf '%s' 'VoiceMemory <noreply@voicememory.app>' | npx vercel env update EMAIL_FROM production -y
printf '%s' 'VoiceMemory <noreply@voicememory.app>' | npx vercel env update EMAIL_FROM preview -y
printf '%s' 'VoiceMemory <noreply@voicememory.app>' | npx vercel env update EMAIL_FROM development -y
```

Replace the domain with yours. Wait 1–2 minutes (redeploy only if sends still use the old sender).

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
  "emailFromDomain": "voicememory.app",
  "appUrlConfigured": true,
  "productionEmailReady": true
}
```

If `emailFromUsesResendSandbox` is **true**, Production still has `onboarding@resend.dev` — update `EMAIL_FROM` after Resend shows **Verified**.

```bash
chmod +x scripts/verify-production-auth-email.sh
./scripts/verify-production-auth-email.sh
./scripts/verify-production-auth-email.sh you@yourdomain.com
```

## 4. Send-code test (any user email)

`POST /api/auth/send-code` with a **real** inbox you can open (not required to be the Resend owner).

Expected:

- HTTP **200**
- `{ "ok": true, "message": "Code sent. Check your email." }`
- No `AUTH_RESEND_REJECTED`

Then: `/account` → sign in → **Back up now** → confirm sync (see [POST_DEPLOY_QA.md](./POST_DEPLOY_QA.md)).

## 5. Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| `AUTH_RESEND_REJECTED` + sender message | `EMAIL_FROM` not on verified domain, or domain not verified |
| `AUTH_RESEND_REJECTED` + “only send testing emails to your own…” | Still on `onboarding@resend.dev` |
| `AUTH_RESEND_NOT_CONFIGURED` | Missing `RESEND_API_KEY` or `EMAIL_FROM` in Production |
| Env probe all `true` but send fails | Wrong `EMAIL_FROM` value or literal quotes in Vercel value — re-set via CLI above |

Vercel logs: filter `[VoiceMemory auth]` for `resendResponseId`, `resendErrorMessage`, `errorCode`.

## 6. Resend API key note

Production uses a **Sending** API key. Domain management requires a key with broader permissions in the Resend dashboard; verification is done in the UI, not via the restricted send-only key.
