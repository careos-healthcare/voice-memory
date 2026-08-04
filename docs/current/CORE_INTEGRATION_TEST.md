# Core V1 integration test

`apps/voicememory_mobile/integration_test/core_v1_integration_test.dart`
exercises the shipping `ArchiveMeApp` router and the existing typed V1
composition. It does not create a second application graph.

## Deterministic boundaries

Every scenario gets a new temporary journal, preferences file, encrypted audio
vault, transcription ledger, and Changes store. The bootstrap injects:

- a test-mode recorder;
- deterministic on-device transcription;
- a `VoiceCaptureApiClient` test provider;
- an HTTP transport that returns a local failure if accidentally reached;
- in-memory secure storage; and
- the existing RevenueCat initialization bypass;
- an app-private export directory and handoff recorder that never opens the OS
  share UI; and
- an in-memory recovery API plus separate secure stores for the original and
  simulated fresh devices.

Interpretation uses a deterministic `InterpretationAnalysisRunner`. No OpenAI,
RevenueCat, transcription, recorder plugin, Firebase, or backend production
call is permitted. Every scenario also asserts that the blocked transport
received zero requests.

## Scenarios

1. Typed first proof: starts on first-run onboarding, taps **Type instead**,
   types and saves, reviews the transcript, chooses **Generate possible read**,
   accepts the interpretation disclosure, and verifies the rendered exact
   evidence plus durable typed storage.
2. Voice first proof: taps **Start recording** and **Stop and save**, chooses
   on-device transcription, reviews the transcript, chooses interpretation,
   accepts disclosure, and verifies rendered proof, encrypted audio, voice
   provenance, and the evidence audio reference.
3. Decline: types and saves through Record, reviews, taps
   **Save without interpretation**, opens the saved moment, and verifies the
   later **Generate a possible read** CTA while the free proof remains unused.
4. Type instead: records and stops, selects online transcription, taps
   **Type instead** in the production disclosure, types into the existing
   entry, continues through post-save, and verifies no upload or duplicate.
5. Later analysis: reopens a saved moment through Entry Detail, taps
   **Generate a possible read**, chooses generation, accepts disclosure, and
   verifies the same stored entry receives the proof.
6. Corrections: opens real Entry Detail cards and taps **Accurate**,
   **Wrong angle** (including correction entry), **Too generic**, and **Hide**.
   All four persist locally while transcript, conclusion, and correction text
   remain absent from analytics.
7. Related return: completes two genuinely related typed Record flows. The
   second post-save screen renders one comparison; **Check all evidence**
   exposes ordered Then/Now chronology and both exact quotes.
8. Changes: completes the related pair through UI, opens the real Changes tab
   and thread, verifies Then/Now quotes, renames the thread through its
   correction menu, opens an exact source moment, then records an unrelated
   third moment and verifies no additional comparison is rendered or stored.
9. Weekly review: stores a deterministic review against the production Changes
   projection, opens the single **Your week** entry card inside Changes, and
   verifies the bounded section count, exact evidence, and thread/source
   affordances without introducing another primary destination.
10. Export: opens the production Export screen, chooses both **Readable
    archive** and **Full archive**, confirms audio inclusion, generates the
    deterministic files, and records their handoff while the files still exist.
    No OS share UI is invoked; cleanup remains production cleanup.
11. Recovery: uses the production recovery screen and service to set up
    recovery, rejects an inexact re-entry, accepts the complete code, then
    mounts a second service with empty secure storage as a fresh device and
    recovers the original 32-byte sync key. The API and transport are local
    fakes and the blocked network counter remains zero.
12. Operational observability: constructs and dispatches save, transcription,
    interpretation, retry, vault, recovery, export, commerce, and deletion
    events through the production typed analytics boundary. The provider
    payload is checked against fixture transcript, evidence, conclusion,
    correction, recovery code, identifiers, and paths.

Fixtures are reset before each test. Assertion reasons use only redacted,
content-free diagnostics.

## Local command

Boot a supported iOS simulator or Android emulator, then run:

```sh
cd apps/voicememory_mobile && bash tool/run_core_integration_tests.sh
```

Pass `--device <id>` or set `ARCHIVEME_INTEGRATION_DEVICE` when more than one
mobile device is available.

## CI and diff mapping

Flutter CI boots an available iOS simulator on `macos-15` and runs all twelve
scenarios through the same script. The release-critical unit group also covers
the affected accessibility surfaces and the synthetic archive scale benchmark.

The authoritative release workflow supplies distinct
`FIREBASE_IOS_APP_ID` and `FIREBASE_ANDROID_APP_ID` secrets to both platform
builds, rejects equal or missing values, and never uses `FIREBASE_APP_ID`.

`tool/run_fast_v1_checks.sh` maps changed paths into focused groups:

- named Record/entry handoff and interpretation paths;
- explainable evidence and auditable post-save paths;
- Changes repository, projection, and screen paths; and
- recording and queue recovery paths;
- weekly review, readable/full export, sync recovery, and typed analytics
  paths; and
- affected accessibility and archive-scale performance paths.

The mapper reports when the device-backed core integration command is required;
it does not silently run the full retained Flutter suite.
