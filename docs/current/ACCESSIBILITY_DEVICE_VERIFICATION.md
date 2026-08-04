# ArchiveMe device verification scripts

Every gate in this document is `BLOCKED_EXTERNAL`. No physical device was
connected while it was written, so nothing here has been executed.

**A written script is not device proof.** Reading this file, reviewing it, or
citing it in a release note does not satisfy any gate. A gate moves out of
`BLOCKED_EXTERNAL` only when a named person records device model, OS version,
app build number, date, and the observed result for every numbered step, and
attaches that record to the release. Until then, treat every gate as failing.

## Gate index

| Gate | Status | Section |
| --- | --- | --- |
| VoiceOver (iOS) | `BLOCKED_EXTERNAL` | [1](#1-voiceover-ios) |
| TalkBack (Android) | `BLOCKED_EXTERNAL` | [2](#2-talkback-android) |
| Physical microphone permission | `BLOCKED_EXTERNAL` | [3](#3-physical-microphone-permission) |
| Backgrounding during recording | `BLOCKED_EXTERNAL` | [4](#4-backgrounding-during-recording) |
| Keyboard navigation | `BLOCKED_EXTERNAL` | [5](#5-keyboard-navigation) |
| Maximum Dynamic Type / font scaling | `BLOCKED_EXTERNAL` | [6](#6-maximum-dynamic-type--font-scaling) |
| Reduced motion | `BLOCKED_EXTERNAL` | [7](#7-reduced-motion) |

## Build once, then run every gate against that build

The Flutter version is pinned by `.fvmrc` to `3.44.6`.

```bash
cd apps/voicememory_mobile
fvm flutter --version                 # expect 3.44.6
fvm flutter pub get
fvm flutter devices                   # copy the device id you will use
```

Install a release-mode build on the physical device. Substitute your own device
id and API base URL; do not commit real keys.

```bash
# iOS, signed, on a connected iPhone
cd apps/voicememory_mobile
fvm flutter run --release -d <IOS_DEVICE_ID> \
  --dart-define=VOICE_MEMORY_API_BASE_URL="$VOICE_MEMORY_API_BASE_URL"

# Android, on a connected handset
cd apps/voicememory_mobile
fvm flutter run --release -d <ANDROID_DEVICE_ID> \
  --dart-define=VOICE_MEMORY_API_BASE_URL="$VOICE_MEMORY_API_BASE_URL"
```

Record the build you tested:

```bash
cd apps/voicememory_mobile
git rev-parse --short HEAD
rg -n '^version:' pubspec.yaml
```

---

## 1. VoiceOver (iOS)

Status: `BLOCKED_EXTERNAL`.

Enable and drive VoiceOver from the device, and keep a log stream open on the
host:

```bash
# On the iPhone: Settings > Accessibility > VoiceOver > On
# Then bind the Accessibility Shortcut to VoiceOver:
#   Settings > Accessibility > Accessibility Shortcut > VoiceOver
# Triple-click the side button to toggle it during the run.

# On the host, stream device logs while you drive VoiceOver:
xcrun devicectl device info details --device <IOS_DEVICE_ID>
xcrun simctl spawn booted log stream --predicate 'process == "Runner"'   # simulator only
idevicesyslog | rg -i 'Runner|accessib'                                  # physical device
```

Steps. Swipe right to move forward, swipe left to move back, double-tap to
activate.

1. Launch to the onboarding promise screen. Confirm the reading order is:
   "ArchiveMe" wordmark, "See what changed." headline, the supporting paragraph,
   then "Record a moment", then "Type instead". There is exactly one onboarding
   screen; if VoiceOver announces a page indicator or a second page, that is a
   failure.
2. Double-tap "Record a moment". Confirm the microphone permission prompt is
   announced with the `NSMicrophoneUsageDescription` string from
   `apps/voicememory_mobile/ios/Runner/Info.plist`, and that Deny returns focus
   to a readable explanation with a route into Settings.
3. Grant the microphone, record roughly twenty seconds of speech, and stop.
   Confirm "Saved." is announced first, the editable transcript is announced
   before any interpretation, and "Edit transcript" and "Open saved moment"
   are announced as buttons.
4. Confirm the post-save screen announces **at most one** interpretation. Confirm
   its confidence is announced as one of the four band labels — "Early
   observation", "Some supporting evidence", "Repeated across moments",
   "Strongly supported". A spoken percentage is a failure.
5. Move into the evidence receipt. Confirm each citation announces the quote, the
   full source date, and a distinct "open source" action.
6. Save a second, related moment. Confirm Then and Now are announced with their
   own dates and quotes, in chronological order, and that the uncertainty note is
   announced.
7. Traverse Changes, Archive, `/account`, privacy, subscription and delete-account.
   Confirm every icon-only control has a label and no legal text is clipped.
8. Back out of the delete-account confirmation. Confirm cancelling is announced
   and nothing is deleted.

Record: device, iOS version, build, date, per-step result.

---

## 2. TalkBack (Android)

Status: `BLOCKED_EXTERNAL`.

```bash
# Enable TalkBack without touching the UI:
adb -s <ANDROID_DEVICE_ID> shell settings put secure enabled_accessibility_services \
  com.google.android.marvin.talkback/com.google.android.marvin.talkback.TalkBackService
adb -s <ANDROID_DEVICE_ID> shell settings put secure accessibility_enabled 1

# Watch what TalkBack and the app emit:
adb -s <ANDROID_DEVICE_ID> logcat -c
adb -s <ANDROID_DEVICE_ID> logcat | rg -i 'TalkBack|Accessibility|flutter'

# When finished, turn it back off:
adb -s <ANDROID_DEVICE_ID> shell settings put secure accessibility_enabled 0
adb -s <ANDROID_DEVICE_ID> shell settings delete secure enabled_accessibility_services
```

Steps: run all eight VoiceOver steps above, with these Android-specific checks.

1. Swipe right/left to move linear focus; double-tap to activate.
2. Confirm the microphone rationale matches
   `android.permission.RECORD_AUDIO` and that "Don't allow" leaves a readable
   explanation rather than a dead Record button.
3. Confirm every focusable target is at least 48dp:
   ```bash
   adb -s <ANDROID_DEVICE_ID> shell dumpsys window displays | rg -i density
   adb -s <ANDROID_DEVICE_ID> shell uiautomator dump /sdcard/ui.xml
   adb -s <ANDROID_DEVICE_ID> pull /sdcard/ui.xml ./talkback-ui.xml
   rg -o 'bounds="[^"]+"' ./talkback-ui.xml
   ```
4. Confirm the system Back gesture never leaves the post-save screen in a state
   where the saved moment is unreachable.

Record: device, Android version, build, date, per-step result.

---

## 3. Physical microphone permission

Status: `BLOCKED_EXTERNAL`. A simulator or emulator does not satisfy this gate.

The client asks for the permission through `permission_handler`
(`apps/voicememory_mobile/lib/features/recording/domain/application/recording_permission_coordinator.dart`).
Declared strings are `NSMicrophoneUsageDescription`
(`apps/voicememory_mobile/ios/Runner/Info.plist`) and
`android.permission.RECORD_AUDIO`
(`apps/voicememory_mobile/android/app/src/main/AndroidManifest.xml`).

Run each case from a clean permission state.

```bash
# Android: reset to first-run permission state
adb -s <ANDROID_DEVICE_ID> shell pm revoke com.voicememory.mobile android.permission.RECORD_AUDIO
adb -s <ANDROID_DEVICE_ID> shell pm clear com.voicememory.mobile     # also clears app data
adb -s <ANDROID_DEVICE_ID> shell dumpsys package com.voicememory.mobile | rg -A2 RECORD_AUDIO

# iOS: delete and reinstall the app to reset the prompt
xcrun devicectl device uninstall app --device <IOS_DEVICE_ID> com.voicememory.mobile
```

1. **Grant.** Tap Record, allow, speak for twenty seconds, stop. A moment saves
   and audio plays back from the encrypted vault.
2. **Deny once.** Revoke, tap Record, deny. The screen explains what is blocked
   and offers a route to system settings. It must not crash, must not loop the
   prompt, and must not silently record.
3. **Deny permanently.** Deny twice on Android, or set Microphone to Off in iOS
   Settings. Confirm the app detects the permanent denial and sends the user to
   settings rather than re-prompting.
4. **Revoke while recording.** Start recording, then turn Microphone off in
   Settings. Confirm the in-progress recording is stopped and either recovered or
   discarded without leaving a plaintext file behind:
   ```bash
   adb -s <ANDROID_DEVICE_ID> shell run-as com.voicememory.mobile \
     find . -name 'vm_rec_*' -o -name '*.m4a' -o -name '*.wav'
   ```
5. **Re-grant.** Re-enable the microphone and confirm recording works without a
   restart.

Record: device, OS version, build, date, per-step result.

---

## 4. Backgrounding during recording

Status: `BLOCKED_EXTERNAL`.

**This gate does not verify that background recording works, because the app has
no background-audio capability.** The evidence:

- `apps/voicememory_mobile/ios/Runner/Info.plist` declares no `UIBackgroundModes`
  key, so iOS suspends capture when the app leaves the foreground.
- `apps/voicememory_mobile/android/app/src/main/AndroidManifest.xml:36-43`
  explicitly removes `FOREGROUND_SERVICE` and every
  `FOREGROUND_SERVICE_*` permission with `tools:node="remove"`.
- `config/product/archive_me_v1_release_contract.json` lists
  `allowedBackgroundServices` as empty and permits only `INTERNET`,
  `RECORD_AUDIO`, `USE_BIOMETRIC` and `com.android.vending.BILLING`.

So the correct expectation is graceful interruption and recovery, not continued
capture. Any document claiming background recording is a feature is wrong.

Steps.

1. Start a recording. Press Home. Wait sixty seconds. Reopen the app.
   Expected: capture stopped at backgrounding, and the partial audio is either
   recovered through `/recording-recovery` or discarded — never silently lost
   while still on disk as plaintext.
2. Start a recording, then take an incoming phone call. End the call and reopen.
   Same expectation.
3. Start a recording and lock the screen for two minutes. Unlock and reopen.
   Same expectation.
4. Start a recording and let the OS terminate the app:
   ```bash
   adb -s <ANDROID_DEVICE_ID> shell am kill com.voicememory.mobile
   # or force-stop, which is harsher than a normal background transition:
   adb -s <ANDROID_DEVICE_ID> shell am force-stop com.voicememory.mobile
   ```
   Relaunch and confirm the 24-hour temporary-audio bound is enforced at startup
   and that recovery offers the file exactly once.
5. Confirm no plaintext audio survives past 24 hours:
   ```bash
   adb -s <ANDROID_DEVICE_ID> shell run-as com.voicememory.mobile ls -la files
   adb -s <ANDROID_DEVICE_ID> shell run-as com.voicememory.mobile ls -la cache
   ```
6. Repeat steps 1-3 on iOS, and confirm the app-private no-backup directory
   contains no leftover plaintext capture after a successful save.

Record: device, OS version, build, date, per-step result.

---

## 5. Keyboard navigation

Status: `BLOCKED_EXTERNAL`. Requires a physical or Bluetooth keyboard paired to
the device.

```bash
# Android: confirm the hardware keyboard is seen by the device
adb -s <ANDROID_DEVICE_ID> shell dumpsys input | rg -i 'Keyboard|KeyboardType'

# Android: drive focus from the host to check traversal order deterministically
adb -s <ANDROID_DEVICE_ID> shell input keyevent KEYCODE_TAB
adb -s <ANDROID_DEVICE_ID> shell input keyevent KEYCODE_ENTER
adb -s <ANDROID_DEVICE_ID> shell input keyevent KEYCODE_ESCAPE
```

Steps.

1. On the onboarding screen, press Tab. Focus must land on "Record a moment",
   then "Type instead", and must not leave the screen. Shift+Tab reverses that
   order. Every focused control shows a visible focus indicator.
2. Activate with both Enter and Space.
3. In `/quick-capture`, type an entry with the keyboard only, and save with the
   keyboard only. Escape must dismiss the keyboard without discarding text.
4. On the post-save screen, Tab through: transcript, "Edit transcript", "Open
   saved moment", the interpretation, each evidence citation, each correction
   control, then "Record another moment". No control may be reachable only by
   touch.
5. Move between the four primary destinations (`/record`, `/archive-belief`,
   `/belief-changes`, `/account`) using the keyboard only.
6. Open the delete-account confirmation with the keyboard, then dismiss it with
   Escape. Focus must return to the control that opened it.
7. Confirm focus is never trapped in a dialog and never lands on a hidden or
   offscreen widget.

Record: device, OS version, keyboard model, build, date, per-step result.

---

## 6. Maximum Dynamic Type / font scaling

Status: `BLOCKED_EXTERNAL`.

`apps/voicememory_mobile/lib/onboarding/onboarding_visuals.dart:28` is the only
place in `lib` that reads `MediaQuery.textScalerOf`, so almost all layout relies
on default Flutter scaling. Large-text regressions are therefore likely and must
be checked visually.

```bash
# Android: step through scales, including the largest
adb -s <ANDROID_DEVICE_ID> shell settings put system font_scale 1.0
adb -s <ANDROID_DEVICE_ID> shell settings put system font_scale 1.3
adb -s <ANDROID_DEVICE_ID> shell settings put system font_scale 2.0
# Also enable display size (density) scaling:
adb -s <ANDROID_DEVICE_ID> shell wm density 420    # reset later with: wm density reset
adb -s <ANDROID_DEVICE_ID> shell settings get system font_scale
# Restore when finished:
adb -s <ANDROID_DEVICE_ID> shell settings put system font_scale 1.0
adb -s <ANDROID_DEVICE_ID> shell wm density reset

# iOS: Settings > Accessibility > Display & Text Size > Larger Text
#      enable "Larger Accessibility Sizes" and drag to the maximum
```

Steps, at Android `font_scale 2.0` and iOS maximum accessibility size, in both
light and dark appearance.

1. Onboarding: the headline, paragraph, and both buttons remain fully readable.
   No clipped glyph, no overlapping text, no button label truncated to an
   ellipsis.
2. Post-save: "Saved.", the transcript, the single interpretation, the confidence
   band label, and every evidence quote and date remain readable. The band label
   must not truncate — a truncated band label is indistinguishable from a
   different band.
3. Changes: Then/Now rows stay legible and vertically scrollable.
4. Paywall and subscription: localized store price, terms, and restore control
   stay fully visible.
5. Delete-account: the destructive warning is fully readable before the
   confirm control.
6. Capture a screenshot of each screen at maximum scale and attach it:
   ```bash
   adb -s <ANDROID_DEVICE_ID> exec-out screencap -p > a11y-max-text-<screen>.png
   xcrun devicectl device screenshot --device <IOS_DEVICE_ID> a11y-max-text-<screen>.png
   ```

Record: device, OS version, scale used, build, date, per-step result, screenshots.

---

## 7. Reduced motion

Status: `BLOCKED_EXTERNAL`.

A search of `apps/voicememory_mobile/lib` found no reference to
`MediaQuery.disableAnimations`, `accessibleNavigation`, or any reduce-motion
flag, so the app does not branch on the OS setting. This gate therefore checks
that honouring the OS setting does not break anything, and it does not claim a
bespoke reduced-motion mode exists.

```bash
# Android: remove animation entirely
adb -s <ANDROID_DEVICE_ID> shell settings put global window_animation_scale 0
adb -s <ANDROID_DEVICE_ID> shell settings put global transition_animation_scale 0
adb -s <ANDROID_DEVICE_ID> shell settings put global animator_duration_scale 0
adb -s <ANDROID_DEVICE_ID> shell settings get global animator_duration_scale
# Restore:
adb -s <ANDROID_DEVICE_ID> shell settings put global window_animation_scale 1
adb -s <ANDROID_DEVICE_ID> shell settings put global transition_animation_scale 1
adb -s <ANDROID_DEVICE_ID> shell settings put global animator_duration_scale 1

# iOS: Settings > Accessibility > Motion > Reduce Motion > On
#      also enable "Prefer Cross-Fade Transitions"
```

Steps.

1. With motion reduced, complete onboarding. The ambient glow behind the promise
   screen must not flash, strobe, or block interaction.
2. Record and save a moment. The post-save screen must render its content in the
   contracted order with no animation required to reveal the interpretation, the
   evidence, or the correction controls.
3. Navigate between all four primary destinations. No transition may leave a
   blank frame or a stuck overlay.
4. Open and dismiss the evidence receipt, the paywall, and the delete-account
   confirmation. Each must be fully visible and dismissible without animation.
5. Re-run step 1 of the VoiceOver script with reduce motion on, confirming
   announcement order is unchanged.

Record: device, OS version, build, date, per-step result.

---

## Reporting template

Copy this per gate. An entry without all five fields is not evidence.

```text
Gate:          <gate name>
Status:        BLOCKED_EXTERNAL | PASS | FAIL
Device:        <model>
OS version:    <version>
App build:     <git short sha> / <pubspec version+build>
Date:          <YYYY-MM-DD>
Run by:        <name>
Per-step:      1 pass | 2 pass | 3 fail: <what happened>
```
