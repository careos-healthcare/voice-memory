# Empty State Fixes — ArchiveMe Flutter

**Date:** 2026-05-25  
**Based on:** `EMPTY_STATE_AUDIT.md`  
**Scope:** First-user copy and layout only — no business logic, Firebase, RevenueCat, or auth changes.

---

## Summary

Introduced a shared **`EmptyArchivePanel`** + **`EmptyArchiveCopy`** (`lib/design/empty_archive_experience.dart`) so empty surfaces use:

- **Headline**
- **One-sentence explanation**
- **Single CTA** (where appropriate)

No seeded data, analytics percentages, or “patterns detected” language on zero-recording paths.

---

## Files changed

| File | Change |
|------|--------|
| `apps/voicememory_mobile/lib/design/empty_archive_experience.dart` | **New** — canonical copy + `EmptyArchivePanel` widget |
| `apps/voicememory_mobile/lib/screens/search_screen.dart` | Empty index vs idle search vs no-match states |
| `apps/voicememory_mobile/lib/screens/discover_yourself_screen.dart` | Zero-recording empty panel; neutral lead when entries exist |
| `apps/voicememory_mobile/lib/widgets/archive_progress_identity_card.dart` | Zero recordings → onboarding card (no metrics / View Growth) |
| `apps/voicememory_mobile/lib/features/archive_state_object/archive_state_object.dart` | Below evidence: `changeSummary` uses need-more-evidence body |
| `apps/voicememory_mobile/lib/screens/archive_belief_screen.dart` | Need-more-evidence panel; hide stale change line below threshold |
| `apps/voicememory_mobile/lib/screens/discover_screen.dart` | Need-more-evidence panel when below threshold |
| `apps/voicememory_mobile/lib/features/discover/discover_models.dart` | Removed pattern/insight empty banner copy (handled by panel) |
| `apps/voicememory_mobile/lib/widgets/first_reflection_archive_section.dart` | Archive tab zero state → shared panel |
| `apps/voicememory_mobile/lib/screens/timeline_screen.dart` | Timeline zero state → shared panel |
| `apps/voicememory_mobile/lib/screens/journal_screen.dart` | Journal zero state → shared panel |

---

## Before / after copy

### 1. Search (no recordings, empty query)

| | Copy |
|---|------|
| **Before (title)** | *(none — single paragraph)* |
| **Before (body)** | “Nothing found yet. Search transcripts, beliefs, discoveries, and themes.” |
| **Before (CTA)** | — |
| **After (title)** | “No recordings yet” |
| **After (body)** | “Record your first thought to begin building your archive.” |
| **After (CTA)** | “Create First Recording” |

**With recordings, empty query:** title “Search your archive”, body explains search is available after reflections (no “nothing found”).

**Active query, no matches:** “No matches found” + filter hint (unchanged intent).

---

### 2. Discover Yourself (`recording count == 0`)

| | Copy |
|---|------|
| **Before (lead)** | “Your archive is beginning to notice patterns.” |
| **Before (banner)** | “Record a few thoughts and your archive will begin noticing patterns.” |
| **After (title)** | “Your archive is empty” |
| **After (body)** | “Record your first thought to begin building your archive.” |
| **After (CTA)** | “Create First Recording” |

**With recordings:** lead → “Belief changes, themes, and chapters from your recordings.” Early-mode banner no longer uses “noticing patterns” / “insights become stronger”.

---

### 3. Archive progress card (`recordings == 0`)

| | Copy |
|---|------|
| **Before** | “Your Archive”, 0 recordings / themes / belief changes / chapters, archive age, streak, **View Growth** |
| **After (title)** | “Your archive starts with one recording” |
| **After (body)** | “Every recording becomes evidence. Over time your archive will reveal patterns, beliefs, and changes.” |
| **After (CTA)** | “Create First Recording” |
| **Hidden** | All metrics, streak, View Growth |

---

### 4. Belief / archive state (below evidence threshold)

| | Copy |
|---|------|
| **Before (`changeSummary`)** | “Nothing notable has shifted since your last visit.” |
| **Before (archive screen)** | Count-based “X of Y reflections…” block |
| **After (title)** | “We need more evidence” |
| **After (body)** | “Keep recording thoughts and experiences. Your archive will begin identifying recurring beliefs as more evidence appears.” |
| **After (UI)** | `changeSummary` line hidden until minimum evidence; panel on Archive + What Changed |

**At or above evidence threshold, no delta:** still “Nothing notable has shifted since your last visit.”

---

### 5. Other aligned screens

| Screen | Before | After |
|--------|--------|-------|
| **Archive** (0 reflections) | “Your archive is waiting for its first memory…” | Shared first-recording panel |
| **Timeline** | “Your story begins with your first recording…” | Shared first-recording panel |
| **Journal** | “No reflections yet.” | Shared first-recording panel |

---

## Screenshots recommended for QA

Capture on a **fresh install** (or cleared journal) after onboarding:

| # | Route / tab | State | What to verify |
|---|-------------|-------|----------------|
| 1 | `/search` | 0 recordings, no query | Title, body, CTA; no “nothing found” |
| 2 | `/search` | ≥1 recording, no query | “Search your archive” idle state |
| 3 | `/search` | Query with no hits | “No matches found” only |
| 4 | `/discover-yourself` | 0 recordings | Empty panel; no progress metrics; no pattern lead |
| 5 | `/discover-yourself` | 0 recordings | Progress card shows starts-with-one-recording copy |
| 6 | `/archive-belief` | 0 recordings | First-recording panel |
| 7 | `/timeline` | 0 recordings | First-recording panel |
| 8 | `/journal` | 0 recordings (via drawer/tool) | First-recording panel |
| 9 | `/archive-belief` | 5+ short/low-evidence reflections | “We need more evidence” panel; no “nothing notable” |
| 10 | `/discover-yourself` | 1–4 reflections | No duplicate empty banner; early copy without “insights forming” |

Optional: 11 — `/archive-belief` with full evidence — change summary and metrics behave as before.

---

## Not changed (per scope)

- Updates auto-notification seed (`updates_screen.dart`) — out of scope for this pass
- Engine thresholds, Firebase, RevenueCat, authentication
- Tool/test fixture seeding (`tool/`, `test/`)

---

*End of report.*
