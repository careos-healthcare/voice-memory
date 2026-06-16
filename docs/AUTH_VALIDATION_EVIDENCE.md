# Auth validation — evidence collection

**Status:** Implementation is complete enough for validation. **Do not expand auth scope** until evidence is in.

Frozen until known: Firebase, passwords, social login, account settings expansion, enterprise permissions.

**Validation first. Expansion later.**

---

## What matters now

| Priority | What to collect |
| --- | --- |
| **1** | Exact quotes when users see “Protect this archive” (scenario #2, 5–10 people) |
| **2** | Paywall → verify → checkout → entitlement (scenario #3, end-to-end) |
| **3** | Two real devices, same email (scenario #4) |
| **4** | TestFlight + Android **release** installs (scenario #5, not simulators) |
| **5** | Interview: *“If your archive disappeared tomorrow, would you care?”* |

**Ignore** device-local conversion rates until **≥10 real users** have completed guest → belief → protect paths. One founder browser = noise.

**Most important metric (after 10+ users):** Protect Archive conversion rate **after first working belief**  
(`auth_verified` with `reason=protect_archive` ÷ `protect_archive_clicked`).

**Most important interview question:**  
*“If your archive disappeared tomorrow, would you care?”*

| Answer | Action |
| --- | --- |
| Weak / shrug | **Do not touch auth.** Improve archive value and belief pull. |
| Strong / distress | Auth is positioned correctly. **Keep auth frozen.** |

---

## Action 1 — Scenario #2 interviews (5–10 people)

**Setup**

1. Fresh guest session (incognito / cleared data / fresh install).
2. Record until **5 reflections** exist.
3. Open Archive belief (`/archive-belief` on web; belief screen on mobile).
4. User sees **Protect this archive** (banner and/or one-time prompt).
5. **Do not coach.** Ask what they think it means.

**Success signal (paraphrase OK):** “I should save this.”  
**Failure signal:** “Why do you need my email?” / “Why are you asking for my email?”

### Quote log (copy per participant)

```text
Participant: P__
Date:
Platform: web | iOS TestFlight | Android release
Reflection count at prompt: __
Saw: banner only | banner + modal | other: __

Exact words (verbatim):
"

Tone (your read): save value | suspicious | confused | ignored

Follow-up — archive disappearance:
"If your archive disappeared tomorrow, would you care?"
Answer (verbatim):
"

Outcome: pass | fail | inconclusive
```

After 5–10 rows, tag each quote **pass** / **fail** / **inconclusive**. If majority fail → archive value work, not auth.

---

## Action 2 — Scenario #3 paywall (end-to-end)

**Path:** Value-moment paywall → Upgrade → email code → verify → **checkout** → return → **entitlement active**.

**Surfaces that trigger paywall:** Discover or blind-spot value moment (`ValueMomentPaywall`, reason `pro_paywall`).

### Checklist

| Step | Pass criterion | Notes |
| --- | --- | --- |
| 1. Hit paywall | Paywall appears at a real value moment | Record surface name |
| 2. Tap upgrade | Single auth prompt (`pro_paywall`) | |
| 3. Enter email + verify | One modal flow; no second email ask | |
| 4. Checkout | Stripe (or pricing fallback) opens **without** signing in again | |
| 5. Return URL | Lands back in app with context preserved | |
| 6. Entitlement | Pro/unlock reflects on account used for checkout | Refresh billing state |

**Fail if any:** dead end, 401 on checkout after verify, modal loop, lost surface/context, duplicate `auth_prompt_shown` for same action.

### Evidence block

```text
Date:
Surface: discover | blind_spot | __
Signed in before paywall: yes | no
Duplicate email prompt: yes | no
Checkout completed: yes | no
Entitlement correct after return: yes | no
Notes:
```

---

## Action 3 — Scenario #4 (two real devices)

**Device A:** sign in with test email, let sync/backup run if offered.  
**Device B:** same email, sign in again.

### Verify

| Check | Pass |
| --- | --- |
| Device / session limits enforced predictably | No surprise total lockout |
| Copy explains **protection** (not punishment) | User can say what happened |
| Guest data on B before sign-in still usable | No accidental wipe |
| After sign-in, archive continuity message makes sense | e.g. backup / sync lines on Account |

**Fail:** “broken,” unexplained lockout, or copy that sounds like arbitrary blocking.

Record **exact UI strings** shown on limit or error (screenshot + verbatim).

```text
Device A: __  OS: __
Device B: __  OS: __
Limit hit: yes | no
Copy shown (verbatim):
User reaction (verbatim):
Pass | fail
```

---

## Action 4 — Scenario #5 mobile (release builds only)

**Not simulators.** TestFlight (iOS) and internal/release track (Android).

| Step | Pass |
| --- | --- |
| Fresh install, no login | |
| Record immediately (guest) | No email wall |
| Reach first belief | |
| Protect archive from banner | |
| Restore account on second device | Archive feels primary; account is means |

Link to mobile paths: Record screen + `ProtectArchiveBanner` → account sign-in flow.

**Fail:** login required before first recording.

---

## Action 5 — Analytics (deferred)

Until **10 real users**:

- Do **not** treat `/internal/auth-value-validation` percentages as decisions.
- You may still spot-check that events fire during a session; that is plumbing, not product proof.

After 10+ users with belief + protect exposure, read **Protect Archive conversion** on the internal page and combine with quote log.

---

## Decision after evidence

```text
Quotes majority "save this" + strong disappearance answers
  → Keep auth frozen; optional paywall/device polish only

Quotes majority "why email" OR weak disappearance answers
  → Improve archive value (belief, permanence, loss framing)
  → Do NOT add Firebase / passwords / social / account settings

Paywall E2E fails
  → Fix checkout resume only (no new auth methods)

Device test fails on copy
  → Fix messaging only (no new auth methods)
```

---

## Related

- Manual scenario reference: [AUTH_VALUE_VALIDATION.md](./AUTH_VALUE_VALIDATION.md)
- Internal funnel (post-10 users): `/internal/auth-value-validation`
- Automated plumbing: `npm run validate:auth-value-validation`, `npm run validate:guest-first-auth`
