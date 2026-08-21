# Future private share report (planned — not live)

**Status:** Strategy and copy foundation only. **Not implemented in the app.**

## Concept

A **private share report** is a user-selected slice of archive evidence — pattern summaries and grounded phrases from saved moments — that the user may choose to show someone they trust.

It is **not**:

- A chat export
- A medical record
- A diagnosis or assessment
- An automatic share to a third party

## What it may include (future)

- Selected report sections the user already sees locally (e.g. what returned, what changed)
- Dates or relative dates already shown safely in private reports
- User-approved snippets only

## What it must exclude

- Hidden scores, internal labels, debug data
- Billing or account identifiers
- Audio files unless the user explicitly opts in
- Any section the user did not preview and confirm

## User flow (future sketch)

1. User opens a private report preview they already trust
2. User taps **Share** (future) and selects recipient channel or export handoff
3. User previews included sections and confirms
4. User sends via their chosen channel — ArchiveMe does not auto-deliver to contacts until an explicit invite flow exists

## Copy anchors (canonical)

Use strings from `SafeSharingCopy` in code:

- "Share only what you choose."
- "A private report may help you explain a pattern to someone you trust."
- "You stay in control of what is included."
- "Future sharing should be explicit, private, and reversible."

## Related live surfaces (today)

- Local private report preview (Pro-facing, on-device)
- Local backup export via Privacy & trust (user-controlled file)

Neither of these is **sharing to another person inside ArchiveMe**. Do not conflate them in copy.
