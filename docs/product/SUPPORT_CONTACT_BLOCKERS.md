# Support contact — status

## Published (code + docs aligned)

| Item | Value | Where |
|------|--------|--------|
| Primary contact | **hello@archiveme.app** | Web `/contact`, app help, TestFlight/beta feedback |
| Billing alias | **support@archiveme.app** | Subscription/billing copy — forward to same inbox |
| Outbound auth mail | **noreply@archiveme.app** | Resend `EMAIL_FROM` for sign-in codes |
| Marketing site | **https://archiveme.app** | Sitemap, robots, mobile legal links, store docs |
| Privacy URL | **https://archiveme.app/privacy** | App Settings, App Store |
| Support URL | **https://archiveme.app/contact** | App Store, Support & feedback screen |

## External setup (operator checklist)

Complete [ARCHIVEME_APP_DNS.md](./ARCHIVEME_APP_DNS.md), then run:

```bash
./scripts/verify-archiveme-domain-setup.sh
```

| Step | Action |
|------|--------|
| Vercel domains | Attach `archiveme.app` + `www.archiveme.app` |
| Vercel env | `NEXT_PUBLIC_SITE_URL`, `NEXT_PUBLIC_APP_URL`, `EMAIL_FROM` |
| Resend | Verify `archiveme.app` domain; DKIM/SPF green |
| Inbound MX | Cloudflare Email Routing (or equivalent) for `hello@` + `support@` |
| App Store Connect | Support URL → https://archiveme.app/contact |
| Smoke test | Email hello@, receive auth code from noreply@ |

## Legacy (do not publish in new copy)

| Item | Status |
|------|--------|
| `hello@voicememory.app` | Retire when forward no longer needed |
| `voicememory.app` | Redirects to archiveme.app via middleware — remove from Vercel after transition |
| `careosapp.co.uk/archiveme-*` | Retired — app no longer links here |
