# ArchiveMe V1 product contract

Machine-readable authority: `config/product/archive_me_v1_contract.json` and
`config/product/archive_me_v1_release_contract.json`. Where this prose and those
files disagree, the JSON wins.

The shipping client is the Flutter application in `apps/voicememory_mobile`.
The Next.js application at the repository root is an API-only backend artifact.

## Category and promise

The category is **auditable personal change**.

The promise is **See what repeated. See what changed. Verify it in your own
words.**

In full: **a private change ledger that shows exactly what repeated, what
changed, the words proving it, and lets you correct the record.**

`apps/voicememory_mobile/lib/product/auditable_change_positioning.dart` is the
only place those three strings are authored. Onboarding, the empty Record state,
Changes, the paywall, the marketing source, and both store listings all resolve
to it, and
`apps/voicememory_mobile/test/product_positioning_copy_test.dart` fails if any of
them drifts or leads with a forbidden headline.

AI is a processing detail, never the positioning. Transcription may use the
on-device Whisper engine or, after a separate online choice and disclosure, a
remote model. Each drafted observation uses separately authorized remote
interpretation; no observation reaches the reader without the exact saved words
and dates behind it.

One moment gives ArchiveMe an observation. Returning gives it something real
to compare.

## Onboarding

Onboarding is a single promise screen, not a multi-step tour and not a paged
carousel. `apps/voicememory_mobile/lib/onboarding/onboarding_pages.dart:5`
declares `pageCount = 1`. The screen shows the promise headline, the positioning
sentence as its one supporting paragraph, and two buttons: "Record a moment"
(`primaryAction`) and "Type instead" (`secondaryAction`). Completing either
button persists onboarding completion and routes to `/record` or
`/quick-capture`.

Any documentation describing belief-forming onboarding screens, a five-screen
flow, or a `PageView` onboarding is describing a surface that no longer exists.

## Authoritative loop

1. The user sees the single onboarding promise screen and chooses Record or
   Type.
2. ArchiveMe saves typed words or encrypted audio before optional AI.
   Transcription consent never implies interpretation consent; declining either
   choice still archives the original.
3. The post-save screen shows, in order: Saved, the original words (or an
   honest audio-only state), **at most one** validated interpretation, inline
   exact evidence with source and date, why ArchiveMe noticed it, what the
   evidence does not establish, correction controls, then one grounded next
   action. No paywall, reminder, streak, or second interpretation participates
   in this render decision.
   `apps/voicememory_mobile/lib/widgets/record/focused_auditable_post_save_section.dart:25`
   holds a single nullable `conclusion`; when it is absent the screen renders the
   `focused_auditable_no_conclusion` card instead.
4. One saved moment can produce only a cautious observation.
5. Two related, distinct moments can produce a possible repeat or possible
   change. Unrelated moments produce no comparison.
6. Changes is the repeat-use surface. It presents validated history
   chronologically with Then/Now evidence and source navigation. Its only
   primary customer statuses are **First noticed**, **Showing up again**, and
   **Changed**. Stronger, weaker, mixed, and uncertain are secondary
   explanations; **Corrected by you** is a separate user-authored marker.
   A restrained weekly review lives inside Changes and may contain at most one
   Showing up again item, one Changed item, and one unresolved tension.
7. Every interpretation can be marked Accurate, Wrong angle, Too generic, or
   Hide. Correction text remains private and is never analytics data.
8. Account provides readable and full archive export, privacy, subscription
   management, restore, optional sync-key recovery, and idempotent account
   deletion. Readable export excludes audio bytes. Full export is a single
   archive containing readable content, machine-readable JSON, available
   original audio, and a checksummed manifest. Recovery is opt-in, requires
   the signed-in account plus the complete user-held code, and never sends or
   stores that code. Deletion clears remote account data and local journal,
   audio, derived interpretations, corrections, recovery envelope,
   credentials, and queued work before returning to the promise screen.

## Confidence is a band, never a number

A conclusion's confidence is derived, never authored, and is shown to the reader
only as a band label. `EvidenceConfidenceBand`
(`apps/voicememory_mobile/lib/features/explainable_conclusion/explainable_conclusion.dart:14`)
has exactly four values, rendered as:

- Early observation
- Some supporting evidence
- Repeated across moments
- Strongly supported

`ConclusionConfidenceSignals.value`
(`apps/voicememory_mobile/lib/features/explainable_conclusion/conclusion_confidence_model.dart:60`)
computes an internal 0..100 score from inspectable signals, and
`ConclusionConfidenceSignals.band:83` maps it to one of those four bands. The
numeric score is an internal input. No consumer surface presents a confidence
percentage, and none may be added.

## Evidence contract

Every visible interpretation is an `ExplainableConclusion` accepted by
`ExplainableConclusionValidator`. Evidence must identify an exact transcript
range, source moment, full source date, source type, and chronological role.
Change evidence uses distinct entry IDs and different exact quotes in Then/Now
order. Unsupported, generic, diagnostic, zero-confidence, stale-offset, and
legacy fallback claims render as no conclusion.

## Surface contract

The four primary destinations declared by
`apps/voicememory_mobile/lib/router/route_catalog.dart:11` are `/record`
(Record), `/archive-belief` (Archive), `/belief-changes` (Changes), and
`/account` (Account). The `belief` fragments in those two paths are historical
route names retained so existing deep links keep working; there is no belief
system behind them.

Source navigation opens the exact saved moment. Record and Changes offer no
route into removed surfaces.

## Surfaces that are not in this product

`config/product/archive_me_v1_contract.json` lists these as prohibited, and
`config/release/archive_me_v1_backend_allowlist.json` records the matching
backend routes as removed. None of them exists in the shipping client, and no
document may describe them as available:

- life simulation and horizon simulation
- life-story replay
- a generic analyst or action-plan generator
- broad archive synthesis and dashboard synthesis
- document ingestion and vision extraction
- memory graph, graph sync, and relationship synthesis
- live AI audio conversation and voice sessions
- the consumer web client and the Capacitor shell
- personality, trait, diagnosis, blind-spot and belief systems
- a fifth primary tab, or any second journal alongside the canonical one
- Places or location journaling, and any location permission
- streak pressure, and entry-count value promises such as 50, 100, or 200 entries
- rich-media parity: camera, photo library, video, OCR, and document ingestion
- an AI companion persona, a generic chat surface, or a generic memory assistant
- therapy and diagnosis claims of any kind
- a Memory Graph, an analyst dashboard, a Life OS, or future simulation
- HealthKit and Health Connect, BLE, and WebRTC
- social or community surfaces, and broad guide libraries
- a mood-tracker identity
- a lifetime subscription package

`prohibitedProductDirections` in `config/product/archive_me_v1_contract.json`
records that list with the mechanism enforcing each entry.
`scripts/validate-archive-me-v1-anti-features.mjs` and
`apps/voicememory_mobile/test/anti_feature_guard_test.dart` fail the release if
any of them returns. Both work from explicit route and production-path
allowlists, so an ordinary class or directory whose name merely contains a
common word is never flagged.

## Account isolation

Each local archive is a physically separate directory.
`ArchiveScopePaths.scopeDirectory`
(`apps/voicememory_mobile/lib/features/archive_ownership/archive_scope_paths.dart:13`)
derives `<base>/archives/<sanitized archive id>` per identity, and
`JournalStore` requires a non-empty `ownerArchiveId`
(`apps/voicememory_mobile/lib/storage/journal_store.dart:38`) and refuses to
write an entry whose owner does not match
(`apps/voicememory_mobile/lib/storage/journal_store.dart:179`). Two archives
never share a journal file.

Guest and legacy content is never claimed automatically. A legacy unclaimed
archive keeps its pre-partition path
(`archive_scope_paths.dart:26`) until the user makes an explicit decision
through `ArchiveOwnershipDecisionService`; the decision sheet has no default
action and no dismiss-to-claim path
(`apps/voicememory_mobile/lib/features/archive_ownership/archive_ownership_decision_sheet.dart:10`).

## Commercial contract

Originals, transcripts, evidence sources, corrections, deletion, export, and
previously generated results remain readable. The first valid observation and
first valid comparison are free proof. Pro governs new ongoing comparison and
deeper-generation work. No paywall appears before free proof.

The machine-readable authority remains
`config/monetization/archive_me_entitlement_matrix.json`. See
`MONETIZATION_CONTRACT.md`.

## Privacy and analytics

Audio is encrypted in the local vault. Transcription can run with local Whisper;
online transcription and interpretation are distinct remote calls with
purpose-specific choices and disclosures. Preferences are archive-scoped in
platform secure storage, revocable, and never plaintext preferences. See
`DATA_FLOW_AND_PRIVACY.md` for the full flow and encryption limits.

Product analytics accepts only allowlisted metadata such as conclusion kind,
count bands, confidence bands, source type, surface, and feedback choice. It
must never receive transcripts, quotes, conclusions, correction text, entry
IDs, dates, filenames, or audio.

Operational visibility uses the same typed catalog and two-stage validation.
It may record only bounded lifecycle, timing, attempt, source, count, format,
and failure bands for save, transcription, interpretation, retry, vault, sync,
recovery, commerce, deletion, and export. Raw provider errors and identifiers
are prohibited. Crash reporting has a privacy-reviewed bounded adapter but no
configured production provider; it therefore reports `disabled` and fails
closed rather than forwarding an exception or breadcrumb.
