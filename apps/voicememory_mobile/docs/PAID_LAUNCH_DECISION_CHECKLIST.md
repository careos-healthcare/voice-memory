# ArchiveMe — Paid Launch Decision Checklist

Paid launch is **not ready** until store billing, RevenueCat, physical QA, and beta evidence gates pass. This checklist is go / caution / no-go — not a feature spec.

## Prerequisites (all required)

- [ ] RevenueCat + App Store Connect banking and products configured
- [ ] TestFlight physical QA complete ([TESTFLIGHT_MANUAL_QA.md](./TESTFLIGHT_MANUAL_QA.md))
- [ ] [ACCESS_PROTECTION_AUDIT.md](./ACCESS_PROTECTION_AUDIT.md) gates understood
- [ ] Support URL works: https://careosapp.co.uk/archiveme-support
- [ ] No placeholder app icon / launch image warnings in release build
- [ ] Crash-free fresh install on **2 physical devices**

## Beta evidence gates (20-user plan)

- [ ] 20 beta users invited
- [ ] ≥10 users save **first moment**
- [ ] ≥5 users save **3+ moments**
- [ ] ≥3 users **day-2 return**
- [ ] ≥3 users complete or view **weekly review** or **Then vs Now**
- [ ] ≥3 users say archive showed something **useful**
- [ ] ≥2 users express **willingness to pay** (yes / maybe with reason)
- [ ] No privacy blockers (share/calendar/milestone surfaces)
- [ ] Sandbox **purchase + restore** verified after RevenueCat configured

## Product gates

- [ ] Sticky loop calm on Archive Home (not a card wall)
- [ ] No forced login before recording
- [ ] Pro Preview honest — purchases not available until configured
- [ ] Restore Purchases reachable with honest copy
- [ ] No purchase CTAs claiming checkout works today

## Greenlight (paid launch candidate)

All prerequisites pass **and** all beta evidence gates pass **and** sandbox purchase + restore verified **and** wedge feedback positive in user words (capacity or prove-enough, not founder assumption).

## Caution (delay 2–4 weeks)

- Beta gates met but WTP weak (0–1 would pay)
- Day-2 return below 3 users
- Insight rejection high without second saves
- One device crash on fresh install
- RevenueCat configured but restore flaky in sandbox

## No-go (do not launch paid)

- RevenueCat / store setup incomplete
- Privacy issue in share, calendar, or milestone surfaces
- Crash on fresh install reproducible
- Forced login or purchase wall blocks free archive
- Dishonest Pro or purchase copy
- Fewer than 5 users complete 3-moment task
- Clinical framing or score language in consumer copy

## Post-launch monitoring (first 30 days)

- Sandbox → production purchase success rate
- Restore success rate
- Day-7 retention (external analytics)
- Support tickets: privacy, “don't know what to say,” crash
- Refund / chargeback signals

## Related docs

- [WEDGE_RETENTION_ACQUISITION_PLAN.md](./WEDGE_RETENTION_ACQUISITION_PLAN.md)
- [CAPACITY_YES_100K_WEDGE_PLAN.md](./CAPACITY_YES_100K_WEDGE_PLAN.md)
- [RETENTION_METRIC_DEFINITIONS.md](./RETENTION_METRIC_DEFINITIONS.md)
- [APP_STORE_SUBMISSION_PACK.md](../APP_STORE_SUBMISSION_PACK.md)
