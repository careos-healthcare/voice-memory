# Memory pipeline

End-to-end flow from voice capture to revisit tracking. All persistence is local-first unless encrypted account sync is enabled.

## Pipeline stages

```
Record → Transcribe → Save → Reflect → Memory notes → Revisit tracking
```

### 1. Record

- **Component:** `components/Recorder.tsx`
- Captures up to 60s via `MediaRecorder`
- Listening mode skips immediate reflection (`lib/pending-reflection.ts`)
- Unexpected stop / partial failure → draft recovery (`lib/reliability/draft-recovery.ts`)

### 2. Transcribe

- **API:** `app/api/transcribe/route.ts` (OpenAI Whisper)
- Audio sent transiently; not kept as a cloud journal
- Returns transcript text to the client

### 3. Save

- **Audio:** `lib/reliability/safe-audio.ts` → IndexedDB (`lib/audio-storage.ts`)
- **Entry:** `lib/storage.ts` → `voicememory_entries` (localStorage)
- Side effects on save: habit day, analytics milestones, emotional timing, moat metrics, encrypted sync schedule

### 4. Reflect

- **API:** `app/api/analyze/route.ts` (structured reflection fields)
- Normalized via `lib/reflection.ts`
- Listening mode: reflection deferred until user taps “Reflect on this entry”

### 5. Memory notes

- **Builder:** `lib/patterns/memory-notes.ts`
- Sources: continuity moments, change detection, landmarks
- Ranking stack:
  1. Wording tune + suppression (`lib/refinement/callback-wording.ts`, `callback-suppression.ts`)
  2. Hierarchy gate (`lib/refinement/memory-hierarchy.ts`)
  3. Revisit worth (`lib/refinement/revisit-worth.ts`)
  4. Silence calibration caps (`lib/refinement/silence-calibration.ts`)

### 6. Revisit tracking

- **Detection:** `lib/refinement/revisit-experience.ts` (nav hint, bookmark, prior views)
- **Presentation:** reward line, then-vs-now, living resurfacing, voice identity, emotional chapter
- **Signals:** `lib/callback-interaction-signals.ts`, `lib/retention/retention-loops.ts`
- **Analytics:** `lib/local-analytics.ts` (local events, optional sync)

## Cross-device sync (optional)

When signed in, `lib/sync/client.ts`:

1. Builds local `SyncContinuityModel` (`lib/sync/sync-model.ts`)
2. Pulls remote encrypted core blob
3. Merges with conflict rules (`lib/sync/merge-strategy.ts`)
4. Applies merged model locally
5. Pushes encrypted payload + audio blobs

See `types/sync-continuity.ts` for the sync-ready schema.

## Key localStorage keys

| Key | Domain |
|-----|--------|
| `voicememory_entries` | Journal entries |
| `voicememory_reflection_bookmarks` | Bookmarks |
| `voicememory_reminder_preferences` | Settings |
| `voicememory_callback_reviews` | Review labels |
| `voicememory_local_events` | Local events (opt-in sync) |
| `voicememory_sync_device_id` | Sync device identity |

Audio recordings live in IndexedDB (`voicememory_audio`), not localStorage.
