# ArchiveMe — Pricing hypotheses

Exploratory price points for interviews and store tests. **These are
hypotheses, not measured results or final pricing.** The app must display only
the localized prices returned by the current RevenueCat offering.

Do not change RevenueCat product IDs or entitlement logic from this doc.

---

## Candidate price points

| Plan | Price | Role |
| --- | --- | --- |
| **Monthly A** | £4.99 / month | Low-friction entry; “less than one coffee” |
| **Monthly B** | £7.99 / month | Anchor for serious personal tool |
| **Annual A** | £39.99 / year | ~£3.33/mo — default annual push |
| **Annual B** | £59.99 / year | Premium anchor if export + timeline feel strong |

Monthly and annual are the only new-purchase package types. Historical,
verified non-expiring purchases remain grandfathered; no lifetime offer is
available for a new purchase.

---

## What each price must justify

| Price | User must believe |
| --- | --- |
| £4.99/mo | “Worth it to not lose my patterns.” |
| £7.99/mo | “This replaces messy notes + ChatGPT threads for *my* repeats.” |
| £39.99/yr | “I’ll use this for months — full memory is the product.” |
| £59.99/yr | “Export + timeline + report = personal record I’d pay for.” |

---

## Willingness-to-pay questions

Use in TestFlight interviews ([TESTFLIGHT_REVENUE_SCRIPT.md](./TESTFLIGHT_REVENUE_SCRIPT.md)).

### After first proof

- **Does first proof create enough desire?**  
  Metric: % who say “fit” or “partly fit” AND would return tomorrow.  
- **Would they pay after 3 days?**  
  Metric: stated WTP after day-3 script without showing price first.  

### After memory ceiling

- **Do users understand longer memory?**  
  Metric: can they explain difference between “last 7 key moments” and “full history” unprompted?  
- **Would longer memory matter?**  
  Metric: rank vs export vs private report.  

### After export / report

- **Would they pay after first private report?**  
  Metric: interview + optional waitlist tap (Experiment D).  
- **Would they pay for exportable evidence?**  
  Metric: “I’d pay to keep a PDF of my pattern memory” yes/no/range.  

### Price fairness

- **What price feels fair?**
  Discuss monthly and annual hypotheses without presenting them as live store
  prices. Record the store locale with any observed response.

---

## Success thresholds (unmeasured hypotheses)

Before turning on live billing at scale:

| Signal | Minimum bar |
| --- | --- |
| First proof “fit” rate | ≥ 40% of users with 3 related entries |
| Different from ChatGPT | ≥ 60% say “yes, clearly different” |
| Return intent | ≥ 50% would come back tomorrow unprompted |
| Stated WTP ≥ £39/yr | ≥ 25% of engaged testers (3+ entries) |
| Paywall comprehension | ≥ 70% understand “full memory” vs free |

---

## Anti-patterns

- Discounting before proof (paywall on day 0)  
- New lifetime offers (not supported by the canonical monetization policy)
- Multiple concurrent SKUs on first launch  
- Competing on “cheaper than ChatGPT Plus”  

---

## Related

- [REVENUE_EXPERIMENTS.md](./REVENUE_EXPERIMENTS.md)  
- [PRO_VALUE_LADDER.md](./PRO_VALUE_LADDER.md)  
- [NEXT_PRODUCT_BETS.md](./NEXT_PRODUCT_BETS.md)
