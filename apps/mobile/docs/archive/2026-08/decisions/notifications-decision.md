# Notifications — product decision (deferred)

**Status:** Not implementing yet.  
**Decision:** Notifications should wait until retention is proven.

## Why defer

ArchiveMe is still validating whether users return on their own after seeing value in-app. Push adds permission friction, platform setup, and trust risk before we know return loops work. Prove retention with in-product cues first; add notifications only when users ask for them.

## Rules

1. **No push notifications before beta feedback.** Do not ship reminder pushes, check-in nudges, or re-engagement campaigns until beta interviews and retention metrics show a clear gap that in-app loops cannot close.
2. **Use in-app return loops first.** Prefer return-tomorrow cues, weekly review ritual, yesterday-watch, and other on-device surfaces that do not require OS permission.
3. **Only consider notification permission after users say they want reminders.** Permission prompts are a response to explicit interest (e.g. “remind me,” “I forget to check in”), not a default onboarding step.
4. **Notifications must be optional and user-controlled.** If added later: off by default or opt-in only, clear Settings control, easy disable, no dark patterns.

## Out of scope for now

- Requesting notification permissions in the app
- FCM / APNs registration or delivery logic
- Scheduled local/push reminder flows tied to retention experiments

## Revisit when

- Beta feedback or retention data shows users want reminders and in-app loops are insufficient
- Day-2 / Day-7 return intent is understood and a specific reminder use case is defined
- Product is ready to own permission copy, settings UX, and opt-out guarantees

## TODO

- [ ] Re-evaluate after beta retention review — do not implement notifications until then.
