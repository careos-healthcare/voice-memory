> Historical, non-authoritative. Superseded and retained for context only. Do not use for release decisions.

# ArchiveMe Paywall Redesign

**Goal:** The paywall feels like *your archive discovered something important* — not a generic subscription upsell.

**Scope:** Copy, hierarchy, and presentation only. RevenueCat entitlement flow (`pro`) unchanged.

---

## Positioning

| Avoid | Use |
|-------|-----|
| Upgrade to premium | Your archive is starting to understand you |
| Unlock AI | Unlock Archive Intelligence |
| Subscribe now | Continue with Free Archive |
| AI journal / voice journal | Archive, recordings, patterns, beliefs |
| Smarter journaling | What changed, what strengthened, what contradicted |
| Powered by GPT-5 | Evidence-backed narrative reviews |

Tone: **evidence-based, historical, longitudinal, personal** — personal archive report, not Netflix.

---

## A/B/C headline variants

| Variant | ID | Headline | Best for |
|---------|-----|----------|----------|
| **B** | `B` (**production default**) | What changed in your life? | Evidence of change over time |
| **A** | `A` (flag) | Your archive is starting to understand you. | Intelligence / synthesis unlock |
| **C** | `C` (flag) | Your archive is just getting started. | Early archive momentum |

**Runtime:** `--dart-define=PAYWALL_VARIANT=A|B|C` (default **`B`**).

See [PAYWALL_VARIANT_B_IMPLEMENTATION.md](./PAYWALL_VARIANT_B_IMPLEMENTATION.md).

**Alternates for future tests (Variant A family):**
- The most valuable insights appear over time.
- Your archive has started finding patterns.

---

## Page structure (top → bottom)

1. **Headline** — variant-specific
2. **Subheadline** — dynamic: `X recordings` · `Y days` · `Z recurring themes` + fixed second paragraph
3. **Archive Theory preview** — current belief, confidence %, evidence count (real data)
4. **Blurred synthesis band** — visual lock; no fake claims
5. **Locked cards** (4) — Monthly Review, Historian, Milestone Reviews, Archive Intelligence narratives
6. **Social proof** — archive-specific return reasons (not testimonials)
7. **Pre-CTA line** — real counts or fallback
8. **Primary CTA** — Unlock Archive Intelligence → purchase (yearly preferred, else monthly)
9. **Plan rows** — monthly / yearly prices (existing RevenueCat packages)
10. **Secondary CTA** — Continue with Free Archive → `pop` (no trap)
11. **Restore purchases** — existing flow

---

## Dynamic copy rules

### Subheadline

```
Generated from {count} recordings across {spanLabel}.

The archive has begun identifying patterns, contradictions, and changes over time.
```

- `count` = eligible reflection count
- `spanLabel` = `N days` | `N months` | `N years` from first→last eligible entry
- If `count < 5`: shorter fallback subhead

### Pre-CTA (above primary button)

**With data:**
> The archive has analyzed {count} recordings and identified {themeCount} recurring patterns.

**Fallback:**
> The archive becomes more valuable as it gathers evidence.

---

## Locked cards

| Icon | Title | Subtitle |
|------|-------|----------|
| 🔒 | Monthly Review | What changed in your life this month? |
| 🔒 | Archive Historian | How your beliefs evolved over time. |
| 🔒 | Milestone Reviews | What your first 50, 100, and 200 recordings reveal. |
| 🔒 | Archive Intelligence | Evidence-backed narrative reviews. |

(No GPT-5 branding in UI.)

---

## Implementation map

| File | Role |
|------|------|
| `lib/billing/archive_paywall_copy.dart` | Variants A/B/C + static strings |
| `lib/billing/archive_paywall_stats.dart` | Stats from journal + V1 theory |
| `lib/widgets/archive_paywall/archive_paywall_body.dart` | Layout |
| `lib/screens/mobile_subscription_screen.dart` | Loads data; wires RC purchase |
| `GPT5_PRO_GATING_AUDIT.md` | Unchanged billing |

---

## Success criteria

- Free users see archive value (theory preview) before pay ask
- Pro users see active state, not upsell
- Secondary exit always available
- No modification to `BillingService` / RevenueCat IDs

