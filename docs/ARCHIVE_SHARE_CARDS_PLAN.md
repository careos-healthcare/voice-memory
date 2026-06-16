# Archive Share Cards Plan (Growth Loop V1)

## Goal

Let users export **shareable discoveries** as PNG with ArchiveMe branding, using existing archive outputs only.

## Route

- Mobile: `/archive-share` (`ArchiveShareDiscoveriesScreen`)

## Supported discovery types

| Type | Source |
|------|--------|
| Belief changed | `changeFeed.beliefsWeakened`, `thenNow` evolution |
| Contradiction discovered | `ArchiveV1.contradictions` |
| Pattern detected | Recurring theme counts ≥3 |
| Surprise detected | `ArchiveSurprisesEngine` observations |
| Milestone reached | Recording count 50 / 100 / 200 |

## Card layout

- Headline: “The archive noticed”
- Body: discovery-specific line (no full transcript)
- Footer: `ArchiveMe`

Example (then/now):

```
The archive noticed

I stopped saying
"I'm not ready"
after March.

ArchiveMe
```

## Export

- `RepaintBoundary` + `toImage` → PNG temp file
- `share_plus` `Share.shareXFiles` (same pattern as export screen)
- Max 5 discoveries per session

## Web parity (reference)

- `lib/distribution/archive-share-cards.ts` + `ArchiveShareCard.tsx` remain the web implementation
- Mobile uses `ArchiveShareDiscoveryEngine` — same product intent, on-device engines

## Safety

- Clip long statements; no private transcript dumps
- Screenshot-safe wording only

## Out of scope

- New social graph or in-app feed
- AI-generated share copy (GPT-5 synthesis not required for cards)
