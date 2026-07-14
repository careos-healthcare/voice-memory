# Pro packaging V1

Display-only packaging rules for ArchiveMe Pro. No billing, RevenueCat, or entitlement changes.

## Core paid reason

**Pro keeps the longer trail.**

Paying is not for more AI. It is for keeping the longer proof trail.

## Free value

- First useful repeat
- First proof
- Basic archive start

Free copy must remain useful. Do not imply free is worthless.

## Pro value

- Longer trail
- Older evidence
- Change over time
- Longer comparison history

## Key copy

| Surface | Copy |
|---------|------|
| Headline | Keep the longer trail. |
| Subheadline | Free helps you see the first useful repeat. Pro keeps the older evidence and change over time. |
| Proof bridge | This is the kind of trail Pro keeps building. |
| Why pay | Paying is not for more AI. It is for keeping the longer proof trail. |

## Banned claims

Do not use in Pro packaging surfaces:

- therapy, diagnosis, treatment, trauma, healing, mental health
- AI coach, chatbot, breakthrough, unlimited coaching
- more AI, better answers, coaching
- cloud backup, cross-device sync (unless proven live)
- monthly reports as live (preview/planned only)
- fake scarcity, urgency, locked-content dark patterns

## Paywall truth rules

- If offerings are unavailable, stay honest: existing unavailable copy remains
- Restore purchases stays visible where already supported
- Do not make unavailable purchases look live
- No RevenueCat configuration changes in packaging passes

## When Pro bridge may appear

Pro packaging bridge copy applies only when:

1. `BetaImprovementBranch.proPackaging` is active (beta decision or dart-define), **and**
2. User has meaningful proof (`hasMeaningfulProof` / timeline proof visible), **and**
3. Existing `ProBridgeVisibilityEngine` timing gates pass

Never on empty first-run state. Never stacked with multiple Pro cards — respect surface priority rules.

## Module map

- Copy: `lib/features/beta_improvement/pro_packaging_copy_fix.dart`
- Gating: `lib/features/beta_improvement/pro_packaging_branch_engine.dart`
- Bridge: `lib/features/pro_bridge_visibility/pro_bridge_visibility_engine.dart`
- Paywall display: `lib/features/pro_packaging/pro_value_engine.dart`
