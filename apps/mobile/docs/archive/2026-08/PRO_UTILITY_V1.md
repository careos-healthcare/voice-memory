# Pro utility V1

Narrow, gated Pro utility expansion when users care about proof and ask for history, export, or report.

## Trigger

Users care about proof (`proofFeltMeaningful`) and ask for history, export, or report (`askedForHistory`, `askedForExport`, `askedForReport`) — only when the beta expansion gate passes.

## Core product sentence

Record one real moment. Return when it happens again. ArchiveMe shows what repeated, changed, faded, or corrected. **Pro keeps the longer trail.**

## What is allowed now

- **Older proof history** — copy and gated preview after meaningful proof
- **Export / ownership** — live link to `/export` when `ExportScreen` is available and branch gate passes (Account surface)
- **Private report preview** — preview/planned copy only; monthly private report is not marketed as live

## What remains blocked

- Ask Archive
- Chat
- Loop packs
- B2B
- Annual plan
- New top-level tabs or bottom nav
- RevenueCat config, product IDs, entitlement IDs, pricing, or entitlement logic changes
- Cloud backup or cross-device sync claims unless proven live
- Full monthly report claims unless implemented and tested
- Therapy, diagnosis, treatment, trauma, healing, mental-health, coach, chatbot, more AI, better answers, unlimited coaching, or breakthrough language
- Fake locked content or dark-pattern paywalls

## Free vs Pro value

| Free | Pro |
|------|-----|
| First useful repeat | Longer trail |
| First proof | Older evidence kept |
| Basic archive start | History, export, and summaries around proof |

Free must remain useful. Pro utility does not make free feel worthless.

## Key copy

| Surface | Copy |
|---------|------|
| Headline | Keep more of the trail. |
| Subheadline | When the first proof matters, Pro helps you keep the older evidence, history, and summaries around it. |
| History | Older proof history — see how a repeat changed across more saved moments. |
| Export | Export your archive — keep a copy of your saved moments and proof trail. |
| Private report | Private report preview — see what returned, what changed, what softened, and what to watch next. |
| Proof bridge | You asked for more history. That is what Pro is for. |
| Not more AI | Not more AI — more of your own evidence kept over time. |

## Gating rules

Pro utility appears only when:

1. `BetaImprovementBranch.proUtility` is active (beta decision or `--dart-define=ARCHIVEME_BETA_IMPROVEMENT_BRANCH=proUtility`), **and**
2. User has meaningful proof **or** explicit utility ask from beta outcomes, **and**
3. Expansion gate passes (`expansionAllowed` from `BetaDecisionEngine`), **and**
4. Not empty first-run (`entryCount > 0`)

Never show more than one Pro utility card/section on the same surface.

## Export link rule

- **Live link:** `/export` (`ExportScreen`) — gated CTA from Account when branch active and export config allows
- **Preview only:** "Export is planned for Pro utility." when export surface is not detected/allowed

## Private report rule

- Monthly private report engine exists as **preview** — show planned suffix, no live report CTA
- Do not say "monthly report" is live

## Surfaces

- Post-proof Pro bridge (`FirstProofPayoffCard`, `ProBridgeVisibilityEngine`)
- Account (`ProUtilityExpansionSection`)
- Testing ArchiveMe active-branch card (internal preview)

## Module map

- Copy: `lib/features/beta_improvement/pro_utility_copy_fix.dart`
- Engine: `lib/features/beta_improvement/pro_utility_branch_engine.dart`
- Model: `lib/features/beta_improvement/pro_utility_boundary_model.dart`
- UI: `lib/widgets/account/pro_utility_expansion_section.dart`
- Orchestrator: `lib/features/beta_improvement/beta_improvement_pack_engine.dart`

See also `docs/BETA_IMPROVEMENT_PACK.md` and `test/pro_utility_branch_test.dart`.
