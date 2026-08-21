# ArchiveMe — Revenue experiments

Structured tests for monetization learning. **Documentation only** — do not implement billing changes until TestFlight feedback is triaged.

For each experiment: hypothesis → copy → success metric → build status.

---

## Experiment A — Founder beta offer

| Field | Detail |
| --- | --- |
| **Hypothesis** | Early believers will pay £49–£99 lifetime if framed as “founding archive” before public launch. |
| **Copy** | “Founding member: keep full pattern memory forever. Limited to first 100 testers. Purchases may be unavailable on TestFlight — join waitlist.” |
| **Success metric** | Waitlist signups ≥ 20; ≥ 10 complete interview; ≥ 5 state WTP ≥ £49 if billing worked. |
| **Build status** | **Do not build yet** — waitlist email capture only (safe). Live IAP lifetime SKU later. |

---

## Experiment B — Pro waitlist before billing

| Field | Detail |
| --- | --- |
| **Hypothesis** | Users will join a Pro waitlist when purchases are inert if value is already felt. |
| **Copy** | “Pro keeps your full archive. Purchases aren’t live on this build — tap to get notified when Pro opens.” |
| **Success metric** | Waitlist CTR from paywall teaser; correlation with first-proof “fit” rate. |
| **Build status** | **Safe to build later** — simple email/deep link; no RevenueCat change required for waitlist-only. |

---

## Experiment C — First proof upgrade prompt

| Field | Detail |
| --- | --- |
| **Hypothesis** | Showing Pro teaser immediately after first proof maximizes conversion without harming trust. |
| **Copy** | “This fit? Free keeps your last 7 key moments. Pro keeps the full memory — timeline, map, export.” CTA: “See Pro” / “Not now”. |
| **Success metric** | Teaser view → waitlist or “would pay” survey; no drop in truth-answer completion rate. |
| **Build status** | **Safe to build later** — copy + existing paywall route only; do not change proof gates. |

---

## Experiment D — Private report upgrade prompt

| Field | Detail |
| --- | --- |
| **Hypothesis** | Private report preview is a stronger upgrade moment than first proof for export-minded users. |
| **Copy** | “Keep a private copy of your pattern memory. Pro unlocks exportable recap.” |
| **Success metric** | Rank vs Experiment C in interview; export WTP question score. |
| **Build status** | **Safe to build later** — after private report preview is stable in beta. |

---

## Experiment E — Longer memory upgrade prompt

| Field | Detail |
| --- | --- |
| **Hypothesis** | Hitting the 7 key-moments ceiling creates natural upgrade desire. |
| **Copy** | “You’ve saved more than 7 key moments. Pro keeps your full archive searchable.” |
| **Success metric** | Gate impression count; stated WTP; return rate after gate. |
| **Build status** | **Safe to build later** — aligns with existing `freeKeyMomentsLimit`; do not change limit in experiment doc. |

---

## Experiment F — Export report upgrade prompt

| Field | Detail |
| --- | --- |
| **Hypothesis** | Users will pay specifically for exportable evidence (PDF/share), not generic “Pro”. |
| **Copy** | “Export your pattern memory — private recap for you or your therapist *on your terms*.” (Not medical advice.) |
| **Success metric** | Export WTP ≥ £39/yr; interview quotes mentioning “record” or “evidence”. |
| **Build status** | **Do not build yet** — validate demand in interviews first; export Pro enforcement uneven today. |

---

## Experiment G — Therapy / session companion positioning test

| Field | Detail |
| --- | --- |
| **Hypothesis** | “Bring evidence to therapy” positioning increases WTP without clinical claims. |
| **Copy** | “A private record of what kept repeating — export what *you* choose to share.” |
| **Success metric** | Message resonance in interviews; **no** increase in “medical app” confusion. |
| **Build status** | **Do not build yet** — landing/copy test only; no clinician dashboard. |

---

## Experiment H — “Not ChatGPT” landing page test

| Field | Detail |
| --- | --- |
| **Hypothesis** | Explicit ChatGPT contrast improves qualified signups vs generic “AI journal” hero. |
| **Copy** | Hero: “Stop losing the patterns you keep noticing.” Sub: “ArchiveMe is not trying to answer better than ChatGPT. It remembers what keeps returning.” |
| **Success metric** | Landing → TestFlight install → day-3 retention vs control hero. |
| **Build status** | **Safe to build later** — web/marketing only; see [LANDING_PAGE_COPY.md](./LANDING_PAGE_COPY.md). |

---

## Experiment sequencing

| Phase | Run |
| --- | --- |
| **Now (TestFlight)** | Interviews only — [TESTFLIGHT_REVENUE_SCRIPT.md](./TESTFLIGHT_REVENUE_SCRIPT.md) |
| **After 10 interviews** | B (waitlist) + H (landing A/B) |
| **After proof metrics** | C vs D vs E — pick one upgrade moment |
| **Before live SKUs** | A (founder) with hard cap |
| **Defer** | F, G until export and positioning validated |

---

## Related

- [PRICING_HYPOTHESES.md](./PRICING_HYPOTHESES.md)  
- [DO_NOT_BUILD_YET.md](./DO_NOT_BUILD_YET.md)  
- [NEXT_PRODUCT_BETS.md](./NEXT_PRODUCT_BETS.md)
