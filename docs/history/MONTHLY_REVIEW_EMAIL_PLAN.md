# Monthly Review Email Plan (Growth Loop V1)

## Goal

Re-engage users inactive ~30 days with a **monthly archive review** email built only from cached GPT-5 synthesis output.

## Subject lines (priority order)

1. `The archive noticed something new` — when `biggestSurprise` is present
2. `A belief strengthened this month` — when `emergingTheories[0]` exists
3. `Your archive changed this month` — default

## Body sections

- Month key + eligible reflection count
- **Strongest theory** — `emergingTheories[0]` or `whatChanged[0]`
- **Biggest change** — `whatChanged[0]` or `fadingTheories[0]`
- **Surprise** — `biggestSurprise` or `surprises[0]`
- **Link back** — caller-supplied `archiveUrl`

## Implementation

- `lib/email/archive-monthly-review-email.ts` — Resend send (production only)
- `POST /api/internal/archive-monthly-review` — founder/debug auth (same as test push)
- Request body: `{ email, review: ArchiveMonthlyReview, archiveUrl, dryRun? }`

## Data rules

- **Do not** run a separate analysis job for email
- Review must come from `getCachedArchiveSynthesis` or mobile/client synthesis that already ran
- `dryRun: true` returns rendered text without send (QA)

## Cron / batch (operational)

1. For each signed-in user with email + synced archive:
2. Ensure monthly synthesis exists for prior `monthKey` (Pro + feature flag)
3. POST internal route with cached review + deep link (`/archive-belief` or web `/archive`)

## Limitations

- Local-only mobile users without sync will not receive email until account sync exists
- In-memory synthesis cache is per server instance — production should persist cache or pass review in cron payload

## Out of scope

- Marketing drip sequences
- Unsubscribe management beyond existing product email practices (add when broadcast scale requires)
