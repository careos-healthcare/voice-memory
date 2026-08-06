# Archive Screen — Authoritative Spec (V1 launch)

Status: **authoritative**. Supersedes every prior "intelligence-heavy" archive
design (belief cards, theory rankings, thought maps, timeline spines, evidence
maturity engines, etc.). Those modules are quarantined — see
`docs/LAUNCH_ROUTE_INVENTORY.md`. The Changes tab (`BeliefChangesScreen`,
`/belief-changes`) is a separate, already-correct surface for the
four-state belief-comparison experience; this spec does not change it.

Route: `RouteCatalog.archiveHome` = `/archive-belief`, implemented by
`lib/screens/archive_belief_screen.dart`.

## Product promise this screen must honor

> "Record a real moment, preserve the evidence, and safely see what changed
> over time."

Archive is where the user goes to *find what they said* and, when it exists,
*see the one thing the archive can currently prove changed*. It is not a
dashboard, not an insights feed, and not a place for competing theories.

## Section order and priority (top to bottom)

1. **Original saved moments** — the primary record. Every entry the user
   recorded or typed, newest first. This must always be reachable and must
   never be pushed below other content.
2. **Search / filter** — a single text field that filters the moments list by
   transcript content. Launch scope is intentionally plain: substring match,
   case-insensitive, debounced. No semantic search, no saved filters, no
   faceted browsing. This is deliberately "not exotic" per the V1 launch
   surface decision.
3. **Verified changes** — a restrained section, shown **only** when at least
   one canonical, currently-admitted verified proof exists for this account.
   "Currently admitted" means it passed `ProofDisplayGate` at render time,
   not merely that it was admitted once in the past (see Hard rule 1 below).
   When no verified proof is admitted, this section renders nothing — not a
   placeholder, not an empty-state card, nothing. Its absence is the
   correct signal that no change has cleared the evidence bar yet.
4. **Proof detail** — tapping a verified-change entry opens the existing
   `ProofDetailSheet`, unmodified, showing exact evidence quotes and
   "why this appeared" framing already implemented in
   `VerifiedProofViewModel`.
5. **Correction controls** — the existing `VerifiedProofCorrectionControls`
   widget, reused as-is from the post-save surface. Archive does not
   reimplement corrections.
6. **States** — loading, empty (zero entries), error, and offline must each
   be distinguishable to the user and to automated tests. See below.

## Hard rules

1. **Never bypass the proof pipeline.** Every verified-change card is built
   from `ProofDisplayGate.viewFor`/`latestVerified`, never from raw
   `JournalEntry.reflection` fields, `qualityReceipt` internals, or any
   experimental interpretation engine (belief/theory/pattern-map/comparison-
   engine outputs). If the gate returns null for an entry's proof, that
   entry shows only as a plain original moment.
2. **No raw provider/model output.** Original moments show the user's own
   transcript text (their own words) — never a summarized/interpreted
   rewrite of it, never a raw API response, never a confidence score as a
   number. Verified-change cards only ever render the plain-language lines
   `VerifiedProofViewModel` already produces.
3. **One proof surface per event.** A given saved moment may appear at most
   once in "original moments" and, if and only if it carries an
   admitted proof, once (not twice) in "verified changes." Archive Home must
   never show multiple competing interpretation cards (pattern/theory/
   watchlist/timeline-spine style) for the same underlying evidence.
4. **No card wall.** The verified-changes section is capped and restrained,
   not an infinite feed of "insights." If the list is empty, the section is
   absent, not collapsed-but-present.

## States

| State    | Trigger                                          | UI |
|----------|---------------------------------------------------|----|
| Loading  | Initial load / pull-to-refresh in flight           | Centered progress indicator, existing list preserved during refresh |
| Empty    | Zero saved entries                                 | `_EmptyArchive` card with a single "Go to Record" CTA |
| Error    | `journalStore.loadAll()` throws a non-network error | Inline, live-region error text; last-known list (if any) stays visible |
| Offline  | Load fails with `SocketException`/`NetworkOfflineException`/`TimeoutException` | Distinct offline banner explaining the archive is local-first and will keep working; does not claim data was lost |

## Out of scope for this spec (deferred, tracked separately)

- Full-text/semantic search, saved searches, tagging.
- Any multi-card "insight" surfaces (belief, theory, pattern-map, timeline
  spine, watchlist, milestones) — quarantined per
  `docs/LAUNCH_ROUTE_INVENTORY.md`.
- Bulk actions, packs/collections browsing.

## Testing contract

Behavioral tests (not implementation-placement tests) must assert:

- The verified-changes section is absent when no entry has an admitted
  proof.
- The verified-changes section appears, gated through `ProofDisplayGate`,
  when an entry does have one, and disappears again if the gate would
  reject it (e.g. transcript edited after admission).
- Raw `qualityReceipt`/reflection fields are never rendered directly —
  only plain-language `VerifiedProofViewModel` lines appear.
- The search field filters the visible original-moments list by transcript
  substring.
- Tapping a verified-change card opens `ProofDetailSheet` with correction
  controls; tapping an original moment opens `/entry/:id`.
- Loading, empty, error, and offline states are each independently
  reachable and visually distinct.
