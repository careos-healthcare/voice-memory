# ArchiveMe — Loop map beta validation plan

Five real-user beta sessions focused on whether the **loop map** feels personal, useful, and worth returning to.

## Scope

- Product surface: Map tab → loop map onboarding → Record → first completed map view → validation probe
- Not in scope: new features, paywall pricing experiments, or backend model changes during beta

## Facilitator setup

1. Install TestFlight build with release configuration (no debug tools).
2. Confirm microphone permission string on first record: *"ArchiveMe uses the microphone so you can record short private reflections."*
3. Do not enable `VM_DEBUG_TOOLS` or scripted debug saves during sessions.
4. After the user completes their **first** loop map view, the in-app probe should appear automatically (not during automated E2E runs).

## What the validation probe captures

After first completed map view, the probe stores:

| Field | Values |
| --- | --- |
| Map match | matched / partly / missed |
| Most useful node | trigger, thought, behaviour, relief, cost, alternative, next test |
| Confusing part | optional free text |
| Return intent | would come back tomorrow — yes / no |
| Pay intent | would pay to keep tracking — yes / no / not yet |

Logs: `ARCHIVEME_LOOP_MAP_VALIDATION_*` (shown, answered, node selected, return intent, pay intent).

## Success threshold (5 users)

| Signal | Threshold |
| --- | --- |
| Complete 3 recordings | **4 / 5** |
| Map matched or partly matched | **3 / 5** |
| Identified a useful node | **3 / 5** |
| Would return tomorrow | **2 / 5** |
| Would pay or strongly considers paying | **1 / 5** |

## Failure signals

Stop and revise copy/flow before wider release if:

- Users do not understand **loop map** (ask what it is; blank stares)
- Users do not complete **3 recordings** (drop-off before map)
- Users say the map feels **generic** (missed / no useful node)
- Users cannot tell **what to do next** after map view

## Session script (15–20 min)

1. Open app → Map tab → read primary surface card aloud.
2. Start loop map → record 3 short real moments (no scripted debug).
3. Review completed map together.
4. Complete validation probe when it appears.
5. Ask aloud: *"What would you do tomorrow?"* — compare to return-intent answer.

## Automated pre-flight (run before each beta build)

```bash
flutter test \
  test/loop_map_validation_probe_test.dart \
  test/loop_map_primary_surface_test.dart \
  test/archive_loop_paywall_test.dart \
  test/archive_loop_onboarding_test.dart \
  test/archive_copy_pipeline_log_hygiene_test.dart \
  test/archive_beta_debug_release_gate_test.dart \
  > /tmp/archive_beta_safety_test.log

dart run tool/check_archive_copy_logs.dart /tmp/archive_beta_safety_test.log
bash tool/run_archive_loop_release_smoke_ipad.sh
```

## Release smoke acceptance (device `00008112-000145A81E07401E`)

- App launches on Map tab
- New user sees **"Map the loop behind your thoughts"**
- Microphone permission flow works
- One real recording saves successfully
- No debug buttons visible
- No crash
- No malformed `ARCHIVEME_` logs

## Privacy / App Store safety

- Microphone: user-friendly, no overclaim — see `ios/Runner/Info.plist`
- Store copy (`docs/APP_STORE_COPY.md`): reflection and pattern language only — no diagnosis, therapy, medical treatment, or guaranteed mental health outcomes
