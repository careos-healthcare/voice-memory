# Beta Four Failure Response Rules

Focused fallback rules for the four remaining beta failure modes after the Beta Readiness Simplification Pack.

## Failure mode → allowed scope

| If testers report… | Change only… |
| --- | --- |
| Users do not understand the app | Onboarding / start copy |
| Users save once but do not reach 3 moments | Activation flow (1/3, 2/3 states, return trigger, activation card copy/priority) |
| Daily change feels obvious | Daily change copy and engine rules |
| Alternatives feel weak | Fixed alternative mapping |

## Do not change without repeated evidence

- Do not change multiple unrelated systems for one failure report.
- Do not add dashboards, payments, backend work, or broad feature expansion to address these four problems.
- Do not add new dashboards for these four problems.
- Do not add new beta metrics unless they are fixed local counters already available.

## Commercial guardrails

- Do not enable RevenueCat unless **2–3 clear paid-intent users** exist.
- Do not enable paid launch from a single maybe-paid user.

## Copy guardrails (all four packs)

- No therapy / diagnosis / medical / treatment language.
- No mental health score, wellbeing score, clinical score, or life score.
- No “ArchiveMe knows.”
- No fake stats or testimonials.
- Do not claim everything stays on device.
- Do not overclaim encryption.
- Do not expose private transcript text in user-visible copy.

## Related docs

- [POST_BETA_RESPONSE_ROADMAP.md](./POST_BETA_RESPONSE_ROADMAP.md) — evidence-based branches 1–10 after TestFlight; branches 1–4 covered below in beta

## Current fallback pack

This document tracks the **Beta Four Failure Response Pack** fallbacks:

1. **Onboarding** — simpler title “Map the moments that keep repeating.” with lighter first-path and timing micro-copy.
2. **Activation** — 1/3 and 2/3 cards lead with “Done for now”; secondary offers save when a real moment happens.
3. **Daily change** — six sharper response categories (new outcome, same outcome, later cost, partly fit, quick capture still work, boundary selected).
4. **Alternatives** — fixed pull-specific labels and usable text; selected boundary response always wins.
