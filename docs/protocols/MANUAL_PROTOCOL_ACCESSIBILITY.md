# Manual protocols — screen readers

Part of [`MANUAL_TEST_PROTOCOLS.md`](MANUAL_TEST_PROTOCOLS.md). Not executed.

Covers protocols 4 and 5. **Neither has been run.** No screen reader has been
driven against this app on a physical device by anyone, and no automated test in
this repository can substitute for one.

These two protocols overlap with gates 1 and 2 of
[`ACCESSIBILITY_DEVICE_VERIFICATION.md`](ACCESSIBILITY_DEVICE_VERIFICATION.md),
which are marked `BLOCKED_EXTERNAL` there. That document carries the full
screen-by-screen traversal; these add the study-mode consent and export surfaces
and state their pass criteria as pass/fail. Running one satisfies the other only
when both record the same build SHA.

The four primary destinations referred to below are `/record`,
`/archive-belief`, `/belief-changes` and `/account`.

---

## 4. VoiceOver

```text
Result:        NOT EXECUTED
Run by:        NOT EXECUTED
Date:          NOT EXECUTED
Build SHA:     NOT EXECUTED
Device:        NOT EXECUTED
iOS version:   NOT EXECUTED
Evidence:      NOT EXECUTED
Per-step:      NOT EXECUTED
```

### Preconditions

A physical iPhone running the release build. Swipe right to advance, swipe left
to go back, double-tap to activate.

```bash
# On the iPhone: Settings > Accessibility > VoiceOver > On
# Bind the shortcut so you can toggle mid-run:
#   Settings > Accessibility > Accessibility Shortcut > VoiceOver
idevicesyslog | rg -i 'Runner|accessib'
```

### Steps

1. Launch. Confirm focus lands on the first meaningful element, not on a blank
   container, and that the reading order matches the visual order top to bottom.
2. Traverse the whole first screen with swipe-right only. Confirm every control
   is reachable, every icon-only control announces a label that says what it
   does, and no element is announced twice.
3. Double-tap Record. Confirm the microphone prompt is announced. Deny, and
   confirm the resulting explanation is announced and the route into Settings is
   announced as a button.
4. Grant the microphone, record roughly 20 seconds, and stop using VoiceOver
   only. Confirm the recording state change is announced as it happens — a
   silent transition from "recording" to "stopped" is a failure.
5. Confirm the save is announced, and that the transcript is announced before
   any interpretation of it.
6. Confirm any confidence value is announced as a band label, not a percentage.
7. Traverse the four primary destinations using VoiceOver only. Confirm each
   destination announces its own name and that the selected destination is
   announced as selected.
8. Open the study consent screen. Confirm all five statements are announced in
   order, that the join control is announced as a button, and that the leave
   control is announced with wording that makes clear it deletes the collected
   counts and notes.
9. Join the study using VoiceOver only, then leave using VoiceOver only. Confirm
   both state changes are announced.
10. Open the account screen, reach the delete-account confirmation, and cancel
    it. Confirm cancelling is announced and focus returns to the control that
    opened it.
11. Confirm focus is never trapped inside a dialog and never lands on an
    offscreen or hidden element.

### Pass criteria

Every step above behaves as described, with no unlabelled control, no silent
state change, no reading order that contradicts the visual order, and no focus
trap. Every one of the four primary destinations is reachable by screen reader
alone.

### Fail criteria

Any control announced only as "button" with no name; any state change that is
visible but not announced; a confidence percentage announced instead of a band
label; a focus trap; the study consent screen reachable but not fully readable;
the leave control unreachable by screen reader.

---

## 5. TalkBack

```text
Result:          NOT EXECUTED
Run by:          NOT EXECUTED
Date:            NOT EXECUTED
Build SHA:       NOT EXECUTED
Device:          NOT EXECUTED
Android version: NOT EXECUTED
Evidence:        NOT EXECUTED
Per-step:        NOT EXECUTED
```

### Preconditions

A physical Android handset running the release build.

```bash
adb -s <ANDROID_DEVICE_ID> shell settings put secure enabled_accessibility_services \
  com.google.android.marvin.talkback/com.google.android.marvin.talkback.TalkBackService
adb -s <ANDROID_DEVICE_ID> shell settings put secure accessibility_enabled 1
adb -s <ANDROID_DEVICE_ID> logcat -c
adb -s <ANDROID_DEVICE_ID> logcat | rg -i 'TalkBack|Accessibility|flutter'

# Restore afterwards:
adb -s <ANDROID_DEVICE_ID> shell settings put secure accessibility_enabled 0
adb -s <ANDROID_DEVICE_ID> shell settings delete secure enabled_accessibility_services
```

### Steps

1. Run VoiceOver steps 1 to 11 above, unchanged, with TalkBack gestures: swipe
   right and left to move linear focus, double-tap to activate.
2. Confirm the microphone rationale matches `android.permission.RECORD_AUDIO`
   and that a second denial leaves a readable explanation, not a dead Record
   button.
3. Confirm every focusable target is at least 48dp:
   ```bash
   adb -s <ANDROID_DEVICE_ID> shell uiautomator dump /sdcard/ui.xml
   adb -s <ANDROID_DEVICE_ID> pull /sdcard/ui.xml ./talkback-ui.xml
   rg -o 'bounds="[^"]+"' ./talkback-ui.xml
   adb -s <ANDROID_DEVICE_ID> shell dumpsys window displays | rg -i density
   ```
   Convert each bounds rectangle to dp using the reported density and record any
   target below 48dp.
4. Confirm the system Back gesture never leaves the post-save screen in a state
   where the saved moment is unreachable.
5. Confirm the system Back gesture from the study consent screen leaves the
   participant not enrolled, rather than half-enrolled. Re-open the screen and
   confirm it still asks from the beginning.
6. Confirm TalkBack's local context menu can read the screen by headings, and
   that headings exist on every screen with more than one section.

### Pass criteria

All of protocol 4's pass criteria, plus: no focusable target below 48dp, Back
never strands the user, and Back from consent leaves the participant unenrolled.

### Fail criteria

All of protocol 4's fail criteria, plus: any target below 48dp, a Back gesture
that loses a saved moment, or a Back gesture from consent that leaves collection
running.
