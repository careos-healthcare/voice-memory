# Memory surfacing — internal guide

How VoiceMemory decides what to show, and what we deliberately avoid building.

## How memory surfacing works

### Candidate generation

Pattern engines produce **memory note candidates** from the local journal archive:

- Continuity moments (`lib/patterns/continuity-moments.ts`)
- Change detection (`lib/patterns/changes.ts`)
- Resurfacing, familiarity, milestones, etc. under `lib/memory/`

Each candidate is a `MemoryNote` with `id`, `text`, `category`, `confidence`, optional quote pairs.

### Ranking and suppression

Candidates pass through a shared refinement stack:

| Stage | Module | Purpose |
|-------|--------|---------|
| Suppression patterns | `lib/refinement/callback-suppression.ts` | Drop generic / low-contrast IDs and copy |
| Wording tune | `lib/refinement/callback-wording.ts` | Rewrite weak lines toward temporal, personal copy |
| Hierarchy score | `lib/refinement/memory-hierarchy.ts` | Emotional weight + contrast evidence gate |
| Revisit worth | `lib/refinement/revisit-worth.ts` | Entry-level worth for resurfacing priority |
| Silence calibration | `lib/refinement/silence-calibration.ts` | Session caps, cooldowns, timing — not quality scoring |
| Score thresholds | `lib/refinement/score-thresholds.ts` | Named numeric gates shared across modules |

Debug-only multi-axis tuning lives in `lib/refinement/callback-tuning.ts` — do not wire directly to user UI without hierarchy + silence gates.

### Surfaces

| Surface | Entry point |
|---------|-------------|
| Entry page | `entryMemoryNotes`, `buildRevisitExperience` |
| Memory / timeline | `buildMemoryNotesReport` |
| Homepage cards | Contextual reminders + top hierarchy notes |
| Revisit reward | `lib/refinement/revisit-experience.ts` |

### Revisit loop

1. User opens an old entry (bookmark, memory note link, timeline)
2. `detectRevisitContext` marks revisit sources
3. Contrast notes filtered by shared suppression + hierarchy min
4. `calibrateRevisitExperience` applies silence/session rules
5. Local events recorded (`revisit_opened`, etc.)

---

## What not to build

These conflict with product restraint and emotional safety:

- **Streaks, badges, or daily pressure** — no guilt loops; reminders off by default
- **Dashboards / KPI walls** — no chart grids, performance scores, or “insights engine” framing on user pages
- **AI coach / therapy bot copy** — mirror language only; see `lib/trust-copy.ts`
- **Cloud journal database** — entries stay local unless user opts into encrypted backup
- **Server-side plaintext storage** — sync stores ciphertext only
- **Automatic merge without local preservation** — conflicts must not silently drop device data
- **More ranking layers** — extend `callback-suppression` / `score-thresholds` instead of adding parallel regex lists
- **Push notifications that shame inactivity** — in-app suggestions only, gentle copy

---

## Restraint rules (CI)

Run before merge:

```bash
npm run validate
```

### `validate:quiet-copy`

Bans therapy/AI/dashboard wording in user-facing `app/` and `components/`. Many internal lib paths are excluded — still avoid introducing banned terms in new user-visible strings.

### `validate:restraint`

- Max **4 `<Card>`** sections per user page
- SiteHeader must include essential nav routes
- Product pages may only link to allowed routes (`/privacy`, `/safety`, etc.)
- Banned product phrases: dashboard, coach, gamification, streak badge, insight engine, …

When adding routes, update `scripts/validate-product-restraint.mjs` deliberately.

---

## Cross-device continuity

Sync-ready model: `types/sync-continuity.ts`

| Domain | Merge strategy |
|--------|----------------|
| Entries | Append-only union by id; newer `updatedAt` wins; local wins on tie |
| Bookmarks / reviews | Union by key; newest wins; local wins on tie |
| Settings | Newest snapshot wins; local wins on tie |
| Local events | Append-only by event key (max 500) |
| Audio metadata | Union by entryId; newest wins |

Implementation: `lib/sync/merge-strategy.ts`, wired in `lib/sync/client.ts`.

---

## Safe extension checklist

- [ ] New note type? Add to pattern engine, not directly to UI
- [ ] New suppression rule? Add to `callback-suppression.ts` once
- [ ] New score gate? Add constant to `score-thresholds.ts`
- [ ] New synced field? Extend `SyncContinuityModel` + merge function + schema version
- [ ] User-visible copy? Run `npm run validate`
