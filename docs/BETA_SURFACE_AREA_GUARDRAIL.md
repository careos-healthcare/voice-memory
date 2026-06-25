# Beta surface-area guardrail

**Branch context:** TestFlight beta (`testflight-full-suite-stabilisation`)  
**Purpose:** Keep first-run simple. Do not add product surface to fix comprehension or activation.

## Canonical beta path

Save one yes moment → save two more → review what repeated.

## Rules

1. **Under 3 moments, show one primary path only.** Archive Home and Record must not become a card wall before the user has three saved moments.
2. **Historical surfaces may stay reachable** (detail, overflow, advanced, “more tools”) but **must not compete on first run** with the canonical path above.
3. **Paid cues stay suppressed until eligibility.** Purchase return cues, Pro previews, and paywall nudges must not appear before paid-intent proof exists. RevenueCat readiness is a separate branch after 2–3 clear paid-intent users.
4. **Advanced archive surfaces stay secondary.** Theory, depth, watchlists, and similar tools belong behind “more” / detail — not the default first-run stack.
5. **Do not add new dashboards** to solve comprehension.
6. **Do not add a second guided path** before beta validates the first path.
7. **Do not enable payments or RevenueCat** on this branch.

## If beta feedback is weak

| Signal | Fix in this branch | Defer to post-beta branch |
|--------|-------------------|---------------------------|
| Users do not understand | Onboarding copy only | New cards, dashboards |
| Users do not reach 3 moments | Activation flow only | Extra first-run cards |
| Users forget to return | Local review ritual (later branch) | More first-run retention cards |

## Copy guardrails (consumer-visible)

- **Allowed:** “Private by default”; “Your journal file on this device is encrypted”; honest cloud/transcription lines when features are used.
- **Forbidden:** therapy / diagnosis / medical / treatment language; score language; “ArchiveMe knows”; “everything stays on device”; “fully encrypted archive” (unless every storage path supports it).
- **Do not expose private transcript text** in prefs, analytics, feedback, paid-intent stores, or share-safe surfaces.

## Related docs

- [POST_BETA_RESPONSE_ROADMAP.md](./POST_BETA_RESPONSE_ROADMAP.md)
- [TESTFLIGHT_FULL_SUITE_STABILISATION.md](./TESTFLIGHT_FULL_SUITE_STABILISATION.md)
- [DEPENDENCY_MAINTENANCE_PLAN.md](../apps/voicememory_mobile/docs/DEPENDENCY_MAINTENANCE_PLAN.md)
