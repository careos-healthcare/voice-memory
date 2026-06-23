# Manual walkthrough checklist — ArchiveMe

Use before App Store submission. Mark each path when verified on a release or TestFlight build.

**Purchases:** Restore and subscribe flows should show *unavailable* until RevenueCat/store setup is complete — that is expected.

---

## Fresh install

- [ ] App opens to Record tab after onboarding (or skip onboarding in screenshot mode).
- [ ] ArchiveMe branding visible; no legacy product naming in UI copy.
- [ ] Zero-entry Archive Home shows starter copy and Sample Archive hint.

## Microphone denied

- [ ] Deny microphone permission (or test on simulator without mic).
- [ ] **Type instead** is visible and reachable from Record and Archive Home.
- [ ] Typed save completes and appears in archive.

## Type instead path

- [ ] Open Type instead from Record.
- [ ] Enter a short moment and save.
- [ ] Post-save copy is cautious — no repeat/pattern claims at one entry.
- [ ] View archive navigates to Archive Home.

## First save path

- [ ] After first save, Archive Home shows one-piece evidence copy.
- [ ] Footnote: beliefs are not conclusions.
- [ ] Next step suggests a second moment (comparison framing).

## Second / third entry path

- [ ] Second save — Archive Home shows two-moment comparison copy (no certainty).
- [ ] Third save — cautious “forming belief” language with not-a-conclusion hedges.
- [ ] No streak, guilt, or pressure copy.

## Sample Archive path

- [ ] Open Sample Archive from Archive Home (empty state) or Settings / Help.
- [ ] Banner confirms example data only.
- [ ] Sample tour and Evidence Map work without writing to real journal.
- [ ] Leaving Sample Archive does not merge demo entries into user journal.

## Export / share-safe proof path

- [ ] Export or share-safe proof reachable from appropriate archive surface.
- [ ] Review-before-share messaging visible.
- [ ] Raw private entry text not included in share-safe output by default.

## Restore purchases path

- [ ] Restore purchases reachable from Settings or subscription surface.
- [ ] When RevenueCat is not configured: calm unavailable message (not a crash).
- [ ] Do **not** expect Pro unlock without live sandbox purchase.

## Pro Preview path

- [ ] Pro Preview reachable from Settings.
- [ ] Shows value preview copy only — no purchase CTAs.
- [ ] Dismiss works; no fake Pro lock on free archive core loop.

## Offline / backend unavailable path

- [ ] With network off or API unreachable: local save path behaves as designed.
- [ ] Degraded transcription message if voice save without connectivity.
- [ ] No false claims that cloud sync succeeded.

## Privacy / data controls path

- [ ] Settings → Privacy & data controls (or equivalent) opens.
- [ ] Copy explains local archive and explicit export/share.
- [ ] Support URL matches https://careosapp.co.uk/archiveme-support

---

## Sign-off

| Check | Date | Build |
|-------|------|-------|
| All paths above | | |
| Screenshot captions match `APP_STORE_SCREENSHOT_CAPTIONS.md` | | |
| Reviewer notes in `APP_STORE_SUBMISSION_PACK.md` copied to App Store Connect | | |

**Submission complete:** No — documentation and QA only until banking/RevenueCat and final assets are ready.
