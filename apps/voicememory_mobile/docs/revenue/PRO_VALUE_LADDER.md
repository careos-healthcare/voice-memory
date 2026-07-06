# ArchiveMe — Pro value ladder

Free vs Pro framing for messaging, pricing tests, and store copy. Aligns with `ArchiveProFeatureMap` in code — **this doc does not change entitlements**.

**Monetization principle:** charge for **longer memory and preserved evidence**, not for AI chat or generic coaching.

---

## Free — start the loop

What users should get without paying:

| Capability | Status | Notes |
| --- | --- | --- |
| **Save real moments** (voice or typed) | Live | Core loop entry |
| **First repeat proof** | Live | Typically after ~3 related entries; gated by evidence |
| **Basic pattern detection** | Live | Early signal → confirmed repeat; cautious copy |
| **Basic correction** | Live | Pattern correction options when gates pass |
| **Short local history** | Live | Free tier keeps **last 7 key moments** (product map) |
| **Tomorrow check / return comparison** | Live | Return loop, watch targets |
| **Beta feedback** | Live | Settings → Testing ArchiveMe? → Send feedback |

Free must feel **complete enough** to prove value in 3 days — not a crippled demo.

---

## Pro — preserve and revisit

What Pro should mean in market copy (check **Live** vs **Partial** vs **Future** before promising in App Store):

| Capability | Status | Notes |
| --- | --- | --- |
| **Longer memory / full pattern history** | Live (positioning) | `fullHistory` in feature map; soft paywall surfaces |
| **What ArchiveMe remembers** (cross-week view) | Live (positioning) | Beyond last-7 key moments |
| **Pattern map** | Live (positioning) | Gated on pattern map route when loop closed |
| **Change timeline** | Live (positioning) | Archive timeline — day-by-day pattern change |
| **Key moments search** | Live (positioning) | Search full archive |
| **Monthly review** | Live (positioning) | Monthly archive review surface |
| **Private report / recap export** | Partial | Export/recap exists in map; TestFlight billing may be inert |
| **Review history** | Partial | Review inbox + weekly/monthly surfaces evolving |
| **More archive beliefs** | Partial | Belief/archive surfaces exist; Pro packaging still clarifying |
| **Advanced pattern correction** | Partial | Correction flows live; “advanced” tier not fully separated |
| **Exportable evidence (PDF/share)** | Partial | Export screen exists; Pro enforcement not uniform everywhere |
| **Backup / multi-device sync** | **Future** | Not live — do not sell until shipped |
| **GPT-5 archive synthesis** | **Future / flag** | Behind `enableGpt5ArchiveSynthesis` + Pro; not default beta story |

> **Honesty rule:** If billing is paused on TestFlight, Pro is **preview/teaser** copy — say “coming soon” or “preview” where purchases are unavailable.

---

## Value ladder narrative

**Free:** *“Prove the loop works for you.”*  
Record → return → first proof → basic correction → last 7 key moments.

**Pro:** *“Keep the full memory growing.”*  
Full history → timeline → map → search → monthly review → private export.

Upgrade moment should follow **value felt**, not day zero:

1. After **first proof** (“keep this memory”)  
2. After **private report preview** (“keep a copy”)  
3. When user hits **7 key moments** ceiling (“see older moments”)  

See [REVENUE_EXPERIMENTS.md](./REVENUE_EXPERIMENTS.md).

---

## What Pro is NOT

- Unlimited ChatGPT-style Q&A  
- Therapy or clinical assessment  
- Social sharing or groups  
- Streak gamification  
- “Unlock AI wisdom”  

---

## Copy snippets (paywall-safe)

**Headline direction:** “Keep your pattern memory growing.”  

**Subhead direction:** “Free keeps your last 7 key moments. Pro keeps your full archive — timeline, map, and private export.”  

**Do not use** while purchases unavailable: “Subscribe now” without TestFlight disclaimer.

---

## Related

- [PRICING_HYPOTHESES.md](./PRICING_HYPOTHESES.md)  
- [REVENUE_EXPERIMENTS.md](./REVENUE_EXPERIMENTS.md)  
- `docs/ACCESS_PROTECTION_AUDIT.md` — billing honesty audit  
- `docs/ARCHIVE_INTELLIGENCE_PROOF_SECTION.md` — proof above paywall
