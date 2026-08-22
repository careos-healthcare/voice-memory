# Manual evidence checklist — focused beta (Section E)

Bind every manual gate to the **exact build** under test. Evidence must be JSON (or Markdown + JSON index) with all required fields; the release verifier rejects missing, false, stale, or mismatched records.

## Required signed evidence fields

| Field | Example |
| --- | --- |
| `success` | `true` |
| `build_number` | `48` (matches `pubspec.yaml` + manifest) |
| `commit_sha` | full git SHA of the built artifact |
| `tester` | legal name or team role |
| `device` | `iPhone16,2` / `Pixel 8 Pro` |
| `os` | `iOS 18.1` / `Android 14` |
| `timestamp` | ISO-8601 UTC when test completed |
| `attachment_path` | repo-relative path to notes/screenshots/log |

Optional booleans per checklist (e.g. `voiceover_completed`, `offline_capture_ok`) go alongside these fields in the same JSON file referenced by `evidencePath` on the gate row.

## Checklist items (one session per build)

### Install and upgrade
- [ ] Fresh install from TestFlight / Play internal
- [ ] Upgrade from previous internal build (data retained)

### Resilience
- [ ] Interrupted recording (incoming call / audio focus loss)
- [ ] Microphone permission denied → honest recovery
- [ ] Offline capture → local save succeeds
- [ ] Slow network → no data loss; sanitized errors
- [ ] Low storage warning path
- [ ] Background / process kill during capture → recovery on relaunch

### Accessibility
- [ ] VoiceOver critical path: Record → save → Archive → entry detail
- [ ] TalkBack critical path (Android when available)
- [ ] 200% text size — no clipped primary actions
- [ ] Reduce Motion — no required motion-only affordances

### Archive scale and export
- [ ] Large archive scroll/search remains usable
- [ ] Export/share sheet cancel leaves archive intact

### Deletion verification
- [ ] Local wipe removes journal from device
- [ ] Cloud/account deletion when backend configured

### Store install
- [ ] TestFlight or Play internal build matches manifest `buildNumber` and `commitSha`

## Recording evidence

1. Complete the checklist on the **same binary** uploaded to TestFlight/Play.
2. Save JSON under `release/evidence/` (e.g. `manual_resilience_build48.json`).
3. Update the matching gate row in `release/focused_beta_status.json` (`status: pass`, `evidencePath`, aligned `commitSha` / `buildNumber`).
4. Run `npm run release:verify-focused-beta` — waivers are **not** accepted for privacy, export, deletion, or consent gates.
