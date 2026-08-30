# How ArchiveMe citations work

**Status: draft — ready, pending [#275](https://github.com/careos-healthcare/voice-memory/issues/275) or this coverage note. Do not publish as complete coverage while #275 is open.**

**As of:** 2026-08-30. Describes the shipped mobile citation path. Not a store listing. Not an audit report.

A skeptical reader should be able to check three things: what is stored, what a tap actually opens **on the surfaces listed below**, and what that does not prove.

---

## Current coverage

This document describes **only** the citation path used by:

**`ViewEvidenceInlineLink`**

- `archive_insight_feedback_controls.dart`
- `pattern_confidence_badge.dart`
- `pattern_confidence_card.dart`
- `pattern_lifecycle_badge.dart`

**`ViewSourceProofSection`** (verbatim tap-through)

- `belief_change_pattern_card.dart`
- `archive_verified_changes_section.dart`

Other widgets still show pattern, belief-change, or confidence claims without that tap-through. Examples (not a full inventory): `PatternMatchConfidenceBadge`, `PossibleBeliefChangeSection`, `InstantArchiveBeliefCard`, `EvidenceInsightCard`, weekly recaps, theory heroes, blind-spot sections, pressure pattern cards, prove_enough, share cards, and several Record payoff cards.

There is no automated gate. `AGENTS.md` names the three reference families and says new claim widgets should follow them. Completeness is [#275](https://github.com/careos-healthcare/voice-memory/issues/275).

Even on the listed surfaces, `ViewEvidenceInlineLink` can render from an `onViewEvidence` callback with an empty `entryIds` list. A visible “View evidence” control is not the same as a stored `source_entry_id`.

**Do not read this paper as: every pattern claim in ArchiveMe carries entry ids.**

---

## 1. What gets stored

There are **two** things named `fact_ledger`. They are not the same schema.

**What you tap on the surfaces above** uses the **local** SQLite table `fact_ledger` (`FactLedgerEntries` / `ArchiveFact`). That table holds user-saved details (“Save detail”) and system citations. They share columns; they are distinguished by `fact_type`.

| Column (SQLite) | Model field | What it is |
|---|---|---|
| `id` | `id` | Primary key. System citations use `cite_<entryId>_<id>` (`FactLedgerCitationService.citationIdFor`). The suffix is a short stable id derived from the trimmed quote — not a cryptographic hash and not a way to hide the quote. |
| `source_entry_id` | `sourceEntryId` | The journal entry this row points at. |
| `label` | `label` | For citations: **“Supporting words”** (`FactLedgerCopy.citationLabel`). |
| `value` | `value` | The stored quote string. |
| `note` | `note` | Provenance. Today: `entry_statement`, or `proof:<proofId>` when the quote came from a `VerifiedProof` receipt. |
| `fact_type` | `factType` | Citations are `evidence_citation`. Other values (`project_detail`, `contact`, …) are user-created details, not quotes. |
| `created_at` / `updated_at` | `createdAt` / `updatedAt` | Timestamps. |
| `archive_pack_id`, `archive_thread_id`, `collection_ids_json`, `is_pinned`, `preserve_original` | same | Pack/thread/pin metadata. Citations set `preserveOriginal: true`. |

A citation, structurally, is: **an id, a `source_entry_id`, a quote in `value`, a provenance in `note`, and `fact_type = evidence_citation`.**

Rows are written on journal save (`indexEntry` → `upsertSystemCitation`) into **prefs** (`FactLedgerStore`, key `archiveFacts`) and, when the database is up, the **SQLite mirror**. Renderers warm a session cache from SQLite (`loadEvidenceCitations` filters `fact_type = evidence_citation`) and fall back to prefs.

Prefs and archive metadata can be **plaintext JSON**. This paper does not claim citation rows are encrypted at rest. Encryption of the journal file and of `archiveme.db` is a separate stack.

**Server `fact_ledger`** (Postgres: `userId`, `entryId`, `rawText`, embeddings, …) is a different table used for retrieval. It is **not** what the citation card renders. This document does not describe ranking.

---

## 2. How a claim traces back to source text (on the listed surfaces)

Two layers. Only the second is what a tap can show as “your words.”

**Layer A — reference.** On the listed surfaces, a claim that is allowed to show evidence is wired with entry ids (`InsightEvidenceLine.entryId`, `ViewEvidenceInlineLink.entryIds`, or `VerifiedEvidenceSnapshot.sourceEntryId` on a proof receipt) and/or a handler that opens those entries (`openEvidenceTrailForSourceEntryIds`). If both the id list and the handler are empty, `ViewEvidenceInlineLink` does not render.

A proof receipt snapshot can also store `quote`, `startUtf16`, `endUtf16`, and related metadata. Those are pointers plus a stored excerpt. They are still checked again before a quote card is built.

**Layer B — display gate.** `EvidenceCitationCard` does not accept a raw string. It only accepts a `VerbatimEvidence`. In this codebase the only producer is `VerbatimEvidenceVerifier`. That is a **UI construction rule in this app**, not a security boundary. Another client could skip it.

The check, as mechanism:

1. Load the stored **capture transcript** for that `entryId` (`JournalEntry.transcript` via `JournalTranscriptEvidenceIndexer` → `TranscriptEvidenceIndex`).
2. Refuse a source unless `transcriptProvenance` is quotable. Quotable values are `speech_to_text` and `user_edited`. Missing or unknown stamps are `unknown_legacy` — treated as not the user’s words, because older rows may hold model back-fill and cannot be distinguished on disk.
3. Refuse empty text and draft/system placeholders (so a failed transcription does not become a quote).
4. Check that the candidate appears in that stored transcript. Spacing and capitalisation may differ for the *search*; the *shown* text is always a slice of the stored transcript (`sourceStart` … `sourceEnd`).
5. Candidates shorter than **8** characters after that fold are `tooShortToQuote`.
6. Missing transcript: `sourceUnavailable` → “Quote not loaded.”
7. Transcript present and candidate not in it: `notPresentInSource` → “No supporting quote found” / “This is not quoted, because nothing in your saved entries matches it word for word.”
8. Ungrounded claims render `UngroundedEvidenceNotice`. They do not get a placeholder quote.

Reflection fields can be **indexed** into the ledger for matching (`archiveStatementTexts`). They are **not** allowed into `TranscriptEvidenceIndex`. There is no factory that turns a reflection into a `SpokenTranscript`.

So, **on the listed surfaces:** a claim can point at an entry; the words under it are only shown as a quote card if they still exist in that entry’s stored transcript and the provenance stamp says those words may be treated as yours. You can open the named entry and read the stored transcript. That is an in-app check, not a third-party audit.

---

## 3. What this guarantees — and what it does not

**When a quote card is shown on a listed surface:**

- The visible quote is a contiguous run of characters from the stored capture transcript of a named `entryId`.
- That transcript was stamped `speech_to_text` or `user_edited` at write time (user edits go through a correction path that does not AI-rewrite).
- That widget was not handed a generated sentence to display as a quote.
- If the check fails, that widget says so instead of inventing words.
- You can open the entry those ids refer to.

**This does not guarantee:**

- That **every** pattern or confidence line in the app has ids or a tap-through. See Current coverage and #275.
- That the **claim** is true, complete, or the best reading of those words. A substring is not causation, diagnosis, or “the archive proved this.”
- That ledger `value` text is always user speech. `indexEntry` also stores statement-corpus lines (including reflection text) as `evidence_citation` for matching. **Display** on the quote card still has to pass the transcript check.
- That older entries can be quoted. `unknown_legacy` is fail-closed on purpose.
- Cryptographic proof, attestation, tamper-evidence, or that a remote model “cited sources” in the LLM sense. The implemented check is: does this candidate appear in the stored transcript string loaded for that id, with a quotable `transcriptProvenance` stamp.
- That citation rows in prefs are encrypted.
- That remote work only used those quotes. Sending a moment is a **separate** control. The app names it with these strings, unchanged here: **“What can leave this phone”** / **“You choose what leaves your phone”** / **“Nothing is sent unless you choose a feature that needs it.”** This document does not restate that control.
- Health, mood, or biometric inferences.

Product copy already hedges pattern language (“Your archive noticed…”, “This may be changing…”, “Based on these entries…”). The ledger does not upgrade that hedge into certainty.

---

## 4. How this differs from an “AI-generated” badge

An AI badge answers: *was this sentence produced by a model?* It does not, by itself, open the stored words or refuse a paraphrase.

On the listed surfaces, ArchiveMe’s quote card answers: *do the words under this claim exist in a saved entry I can open, as stored, not as rewritten?*

| | AI badge | Quote card on the listed surfaces |
|---|---|---|
| Question | Who wrote this sentence? | Which stored run of my words is being shown? |
| User action | None required | Tap through to `source_entry_id` / View Source Proof |
| Failure mode | Still shows the generated sentence | Shows “No supporting quote found” or “Quote not loaded” |
| Source of displayed text | Model output | Slice of stored transcript |

---

## 5. What this document omits

How the app *chooses* which pattern or change to propose is not described. Publishing the local citation schema and the tap-through check is enough to know what a citation is on the listed surfaces. It is not enough to reimplement ArchiveMe’s pattern engine.

---

## Publication hold

Publish only after **either**:

1. [#275](https://github.com/careos-healthcare/voice-memory/issues/275) is closed and this “Current coverage” section is updated to match, **or**
2. This draft is published **with** the Current coverage section still in place (honest caveat, not full-coverage marketing).

Do not publish a version that drops Current coverage while #275 is open.
