# ArchiveMe capture performance report

Five capture latency spans, measured. One environment was measured: the host
Dart VM under `flutter test`. **No simulator run, no release/profile run and no
physical-device run was performed**, and every row for those environments says so
instead of carrying a number. Nothing in this document is estimated,
extrapolated or scaled from another environment.

## What was measured, and where

| Environment | Status |
| --- | --- |
| Host Dart VM, `flutter test`, debug semantics | Measured, three runs, numbers below |
| iOS simulator, debug build | `NOT_MEASURED` — see [Gaps](#gaps) |
| Release / profile build (any target) | `NOT_MEASURED` — see [Gaps](#gaps) |
| Physical device | `BLOCKED_EXTERNAL` — no physical-device measurement was taken |

### Host environment for every number below

| Item | Value |
| --- | --- |
| Machine | Apple M2 Pro, arm64 |
| OS | macOS 26.1 (25B78) |
| Flutter | 3.44.6, stable, revision `ee80f08bbf` |
| Dart | 3.12.2 |
| Build mode | `flutter test` on the host VM — debug semantics, asserts enabled, no AOT |
| Command | `flutter test test/capture_performance_test.dart` from `apps/voicememory_mobile` |
| Runs | 4 runs, 5 samples per span per run (run 4 alongside five other test files) |
| Date | 2026-08-02 |

## How the spans are measured

`lib/features/performance/capture_performance_tracker.dart` starts and stops a
`Stopwatch` at the product moments below. The same marks that produce these
numbers run in production; only the report is local.

| Span | Starts at | Ends at |
| --- | --- | --- |
| 1. app launch → Record interactive | first line of `main()` | first post-frame callback of the Record surface, whose painted frame already carries a live Record action |
| 2. Record tap → recording | `_onRecordPressed`, re-armed after a permission prompt so the system sheet is not counted | `_startCapture` commits `RecordUiState.recording` |
| 3. Stop tap → encrypted local persistence | `_stopAndPersist` | audio sealed in the encrypted vault and the entry committed to the journal |
| 4. save → transcript visible | the committed save | the frame that carries the transcript |
| 5. save → first valid observation visible | the committed save | the frame that carries a conclusion that passed the trust policy |

Span 1 excludes native pre-`main` time: Dart cannot observe it, so it is not in
the number.

### Harness effect, stated plainly

A widget test runs on a fake clock that also queues microtasks, so an app future
waiting on real file, preference or vault I/O advances by one hop per pumped
frame. The harness therefore yields to the real event loop and pumps in a tight
loop, which adds a small per-hop cost to spans 3, 4 and 5. These numbers are
upper bounds for this environment, not lower bounds, and they are not device
numbers.

## Measured spans

p50 / p95 / max in milliseconds, n = 5 per run.

| Span | Run 1 | Run 2 | Run 3 | Run 4 |
| --- | --- | --- | --- | --- |
| 1. app launch → Record interactive | 15 / 205 / 205 | 10 / 200 / 200 | 10 / 201 / 201 | 15 / 255 / 255 |
| 2. Record tap → recording | 0 / 3 / 3 | 0 / 2 / 2 | 0 / 2 / 2 | 0 / 2 / 2 |
| 3. Stop tap → encrypted local persistence | 34 / 116 / 116 | 39 / 121 / 121 | 33 / 180 / 180 | 29 / 148 / 148 |
| 4. save → transcript visible | 21 / 37 / 37 | 20 / 37 / 37 | 18 / 35 / 35 | 20 / 29 / 29 |
| 5. save → first valid observation visible | 21 / 37 / 37 | 20 / 37 / 37 | 18 / 35 / 35 | 20 / 29 / 29 |

Runs 1 to 3 are this file on its own. Run 4 is the same file inside the
six-file verification run, which is why its span 1 p95 is the highest number
here: more suites share the machine.

Raw samples, in capture order, from run 3:

```
app_launch_to_record_interactive   [201, 22, 9, 10, 8]
record_tap_to_recording            [2, 0, 0, 0, 0]
stop_tap_to_encrypted_persistence  [180, 64, 33, 28, 25]
save_to_transcript_visible         [35, 22, 18, 18, 18]
save_to_first_valid_observation    [35, 22, 18, 18, 18]
```

In every run the largest sample of each span is the first one. That is one-time
JIT and cache warm-up inside the process, not a capture that behaved
differently; the four samples after it are three to twenty times cheaper.

Spans 4 and 5 are identical because the observation is already attached to the
saved entry: the transcript and the conclusion reach the screen in the same
frame. A saved moment with no conclusion that passes the trust policy records a
sample for span 4 only, by design.

## Budgets, and the measurement each comes from

A budget is the catalogued band boundary at or immediately above the worst
measured p95, so a regression trips before it could move the band a session
reports. Budgets live in
`lib/features/performance/capture_performance_budgets.dart` and are asserted by
the measurement tests, which fail if a measured p50 exceeds them.

| Span | Measured (host) | Budget | Why this number |
| --- | --- | --- | --- |
| 1. app launch → Record interactive | p50 10–15 ms, p95 200–255 ms | 500 ms | Worst p95 is 255 ms, all of it first-mount warm-up; the next boundary above it is 500 ms |
| 2. Record tap → recording | p50 0 ms, p95 2–3 ms | 200 ms | Worst p95 is 3 ms; the first catalogued boundary already holds it with room for a real recorder |
| 3. Stop tap → encrypted local persistence | p50 29–39 ms, p95 116–180 ms | 200 ms | Worst p95 is 180 ms, so 200 ms is the boundary that holds it |
| 4. save → transcript visible | p50 18–21 ms, p95 29–37 ms | 200 ms | Worst p95 is 37 ms; 200 ms is the first boundary and leaves headroom for a slower disk |
| 5. save → first valid observation visible | p50 18–21 ms, p95 29–37 ms | 200 ms | Same samples as span 4 |

No budget is set for a simulator, a release build or a device, because no
measurement exists for them.

## Cold start service graph

`test/capture_performance_test.dart` also times building the service graph with
and without the deferred modules, five samples each, same environment:

| Cold start | p50 | Samples |
| --- | --- | --- |
| Capture-only graph (what a launch now pays before the first frame) | 3 ms | 3, 3, 3, 4, 4 |
| Same graph plus every deferred step | 3–5 ms | 3, 3, 3, 4, 6 |

This measurement understates the saving: the billing SDK is stubbed in tests
(`skipRevenueCat`), so monetization activation costs almost nothing here, and the
analytics provider is not a real Firebase provider. The gating proof, not this
timing, is what shows the deferral is real: see
`test/cold_start_service_gating_test.dart`, which asserts that the Record surface
is interactive while the billing SDK, the analytics provider, the sync service
and the semantic index have all not been initialised, and that all four do
initialise after activation.

## What leaves the device

Only a coarse band. `AnalyticsCatalog.durationBand` maps a duration to one of
`under_200ms`, `under_500ms`, `under_1s`, `under_2s`, `under_5s`, `over_5s`, and
that string is the single property (`performance_duration_band`) attached to an
already registered V1 event. Raw milliseconds exist only in memory, only for
this report, and the sink that reaches analytics accepts a band string rather
than a `Duration`, so there is no code path a timing could travel down. No
transcript, entry id, mood, theme or observation text is ever attached to a
performance event.

## Reproducing this report

```bash
cd apps/voicememory_mobile
flutter test test/capture_performance_test.dart
```

Each measured span prints a `MEASURED <span> n=… p50=… p95=… max=… raw=[…]`
line. Numbers will differ on other hardware; state your own environment if you
record them.

## Gaps

- **Physical device: `BLOCKED_EXTERNAL`.** No physical-device measurement was
  taken. No device number appears anywhere in this document, and none may be
  inferred from the host numbers: a phone's storage, encryption throughput, CPU
  scheduling and thermal state are all different, and span 1 additionally
  depends on native pre-`main` time that this environment cannot observe at all.
- **iOS simulator, debug: `NOT_MEASURED`.** Simulators are installed on this
  machine, but capturing these spans on one requires driving the real UI
  (microphone permission, a real recording, a real tap on the post-capture
  sheet) from an `integration_test` harness. That harness does not exist in the
  repository and creating it was outside the file scope of this task.
- **Release / profile build: `NOT_MEASURED`.** `flutter test` runs debug
  semantics on the host VM; there is no release or profile equivalent of it. A
  release number requires the same UI-driving harness above, run on a simulator
  or a device.
- The next honest step for all three is one `integration_test` driver that marks
  the same five spans and prints `CapturePerformanceTracker.instance
  .localReport()`, run in `--profile` on a named device, with the machine, OS,
  build mode and device model recorded next to the numbers.
