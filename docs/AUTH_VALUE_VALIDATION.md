# Auth value validation

**Objective:** Sign-in should feel like protecting value already created — not permission to start.

**Status:** Implementation is complete enough for validation. **Priority is evidence, not scope.**

**Active work:** [AUTH_VALIDATION_EVIDENCE.md](./AUTH_VALIDATION_EVIDENCE.md) — quote log (scenario #2), paywall E2E (#3), two devices (#4), TestFlight/Android (#5). Ignore conversion rates until **10+ real users**.

**Do not build** until conversion and interviews are known: social login, Firebase, password auth, account settings expansion, enterprise permissions.

## Device analytics (this browser)

Open `/internal/auth-value-validation` **after 10+ real users**. Until then, treat local-storage rates as noise; use interview quotes from the evidence doc.

| Event | Meaning |
| --- | --- |
| `guest_mode_started` | Guest mode active (no session on launch) |
| `protect_archive_banner_seen` | Soft banner shown |
| `protect_archive_clicked` | User chose Protect archive |
| `auth_prompt_shown` | Email modal opened (`reason` in meta) |
| `auth_verified` | Email code verified (`reason` in meta) |

**Protect Archive conversion rate** = `auth_verified` where `reason=protect_archive` ÷ `protect_archive_clicked`.

If conversion is low, the archive may not feel valuable enough yet — not a signal to add auth features.

## Manual scenarios

### 1. Brand new user

1. Open app signed out (incognito or cleared site data).
2. Record reflection 1 and 2 via device guest path (mic works without email).
3. Confirm no email modal and no blocked recorder.

**Pass:** Reaches reflection 2 without thinking about accounts.  
**Fail:** Email wall or modal before reflection 2.

### 2. First working belief

1. Reach 5 reflections.
2. Open `/archive-belief`.
3. Note Protect Archive banner and/or one-time protect prompt (not before reflection 5).

**Pass:** “I should save this.”  
**Fail:** “Why are you asking for my email?”

### 3. Paywall flow

1. Trigger value-moment paywall (Discover or blind spot surface).
2. Tap upgrade → email modal (`pro_paywall`).
3. Verify code → should resume checkout without a second email prompt.

**Pass:** No dead ends, no repeated prompts, no lost context.  
**Fail:** Modal loops or checkout still 401.

### 4. Device protection

1. Sign in on Device A; sync if available.
2. Sign in same email on Device B.
3. Confirm rate limits / session behavior is explained (account protection, not arbitrary lockout).

**Pass:** Feels like protection.  
**Fail:** Feels broken.

### 5. Mobile

1. Fresh install → Record without login.
2. Reach belief; use Protect archive banner → Account sign-in.
3. Restore on second device after sync.

**Pass:** Archive more important than account.  
**Fail:** Login required before record.

### 6. Analytics

After **10+ real users**, confirm events and Protect Archive conversion on internal dashboard. Before that, only verify plumbing if needed.

**Key interview (all scenarios):** *“If your archive disappeared tomorrow, would you care?”* — weak answer → improve archive value, not auth.

## Automated checks

```bash
npm run validate:auth-value-validation
npm run validate:guest-first-auth
```

Playwright (when dev server available):

```bash
npx playwright test e2e/guest-first-auth-validation.spec.ts
```
