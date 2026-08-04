# Manual protocols — physical device

Part of [`MANUAL_TEST_PROTOCOLS.md`](MANUAL_TEST_PROTOCOLS.md). Not executed.

Covers protocols 2, 3, 6, 7 and 8. **No physical iPhone or Android handset was
connected while these were written. Nothing here has been run, and a simulator
or emulator does not satisfy any of them.**

Build the artefact once as described in the
[index](MANUAL_TEST_PROTOCOLS.md#build-the-artefact-once-then-run-every-protocol-against-it)
and use the same binary for all five.

---

## 2. Physical iOS capture

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

### Purpose

Confirm that recording, saving, playback, and the encrypted vault work on real
Apple hardware with a real microphone.

### Preconditions

A signed release build on a physical iPhone, microphone permission in its
first-run state, and a quiet room.

```bash
cd apps/voicememory_mobile
xcrun devicectl list devices                                   # copy the device id
xcrun devicectl device uninstall app --device <IOS_DEVICE_ID> com.voicememory.mobile
idevicesyslog | rg -i 'Runner|micro|record|vault'              # keep this open
```

### Steps

1. Install and launch. Confirm the app reaches its first screen without a crash
   and without a blank frame lasting more than two seconds.
2. Tap Record. Confirm the system microphone prompt appears, showing the
   `NSMicrophoneUsageDescription` string from `ios/Runner/Info.plist`.
3. Deny. Confirm the screen explains what is blocked and offers a route into
   Settings. Confirm no recording starts.
4. Grant the microphone in Settings, return, and record 20 seconds of ordinary
   speech at conversational volume.
5. Stop. Confirm the moment saves and the transcript appears before any
   interpretation of it.
6. Play the saved audio back. Confirm it is audible, complete, and matches what
   was spoken.
7. Record a 5-second moment and a 3-minute moment. Confirm both save, and that
   neither truncates.
8. Record with the device on battery, screen at minimum brightness, and Low
   Power Mode on. Confirm capture still completes.
9. Airplane mode on, record and save. Confirm the moment is saved locally and
   is marked as not yet uploaded rather than lost or silently dropped.
10. Airplane mode off. Confirm the pending moment uploads without a manual
    retry.
11. Force-quit from the app switcher, relaunch, and confirm every moment from
    steps 4–10 is still present and still plays.

### Pass criteria

Steps 1–11 all behave as described; audio in step 6 is intelligible; no crash;
no moment lost at any point; the airplane-mode moment survives step 11.

### Fail criteria

Any crash, any lost or truncated recording, any silent failure with no visible
state, any recording that starts before permission is granted, or any plaintext
audio file left behind after a successful save.

---

## 3. Physical Android capture

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

### Purpose

The same guarantee as protocol 2, on hardware with a different audio stack,
different permission model, and a much wider device range.

### Preconditions

Two handsets, one on the oldest supported Android release and one on the newest.
Run every step on both and record two results.

```bash
adb devices -l
adb -s <ANDROID_DEVICE_ID> shell pm clear com.voicememory.mobile
adb -s <ANDROID_DEVICE_ID> shell pm revoke com.voicememory.mobile android.permission.RECORD_AUDIO
adb -s <ANDROID_DEVICE_ID> logcat -c
adb -s <ANDROID_DEVICE_ID> logcat | rg -i 'flutter|record|audio|vault'
```

### Steps

1. Install and launch. Confirm no crash and no ANR.
2. Tap Record, confirm the `android.permission.RECORD_AUDIO` prompt, and deny.
   Confirm the screen explains what is blocked rather than leaving a dead
   button.
3. Deny a second time to reach permanent denial. Confirm the app routes to
   system settings instead of re-prompting in a loop.
4. Grant the permission and record 20 seconds of speech.
5. Stop, confirm the save, and play the audio back.
6. Record a 5-second moment and a 3-minute moment; confirm neither truncates.
7. Rotate the device mid-recording. Confirm capture continues and the saved
   audio is complete.
8. Enable battery saver and repeat step 4.
9. Airplane mode on: record, save, confirm local save and pending-upload state.
   Airplane mode off: confirm the upload completes without manual retry.
10. Confirm no plaintext capture survives a successful save:
    ```bash
    adb -s <ANDROID_DEVICE_ID> shell run-as com.voicememory.mobile ls -la files cache
    adb -s <ANDROID_DEVICE_ID> shell run-as com.voicememory.mobile \
      find . -name '*.m4a' -o -name '*.wav' -o -name 'vm_rec_*'
    ```
11. Force-stop and relaunch; confirm every moment is still present.

### Pass criteria

Steps 1–11 behave as described on **both** handsets, step 10 finds no plaintext
audio, and no recording is lost or truncated.

### Fail criteria

Any crash or ANR, any truncated recording, a permission loop, plaintext audio
left on disk after a successful save, or a result that differs between the two
handsets without an explanation recorded.

---

## 6. Background interruption

```text
Result:        NOT EXECUTED
Run by:        NOT EXECUTED
Date:          NOT EXECUTED
Build SHA:     NOT EXECUTED
Device:        NOT EXECUTED
OS version:    NOT EXECUTED
Evidence:      NOT EXECUTED
Per-step:      NOT EXECUTED
```

### Purpose

**This protocol does not check that recording continues in the background,
because the app has no background-audio capability.** `ios/Runner/Info.plist`
declares no `UIBackgroundModes`, and the Android manifest removes
`FOREGROUND_SERVICE` and every `FOREGROUND_SERVICE_*` permission with
`tools:node="remove"`. The correct expectation is a clean stop and an honest
recovery, and any claim that background capture is a feature is wrong.

Run every step on both platforms.

### Steps

1. Start a recording, press Home, wait 60 seconds, reopen. Confirm capture
   stopped at backgrounding and the partial audio is either offered for recovery
   or discarded — never silently lost while still on disk.
2. Start a recording and take an incoming phone call. End the call and reopen.
   Same expectation.
3. Start a recording and lock the screen for two minutes. Unlock and reopen.
   Same expectation.
4. Start a recording and trigger an alarm or timer. Confirm the interruption is
   handled without a crash.
5. Start a recording, then let the OS terminate the process:
   ```bash
   adb -s <ANDROID_DEVICE_ID> shell am kill com.voicememory.mobile
   adb -s <ANDROID_DEVICE_ID> shell am force-stop com.voicememory.mobile
   ```
   Relaunch. Confirm recovery offers the partial file exactly once, not on every
   launch thereafter.
6. Repeat step 1 on iOS with a Bluetooth headset connected, then disconnect the
   headset mid-recording. Confirm capture stops cleanly rather than continuing
   to a dead input.
7. After a successful save following any interruption, confirm no plaintext
   audio remains:
   ```bash
   adb -s <ANDROID_DEVICE_ID> shell run-as com.voicememory.mobile ls -la files cache
   ```

### Pass criteria

Every interruption produces either a saved moment or a single, dismissible
recovery offer; no crash; no duplicate recovery prompt; no plaintext audio left
after a save.

### Fail criteria

A crash on any interruption, audio lost with no recovery offer and no message, a
recovery prompt that reappears after being dismissed, or the app appearing to
record while backgrounded.

---

## 7. Reinstall

```text
Result:        NOT EXECUTED
Run by:        NOT EXECUTED
Date:          NOT EXECUTED
Build SHA:     NOT EXECUTED
Device:        NOT EXECUTED
OS version:    NOT EXECUTED
Evidence:      NOT EXECUTED
Per-step:      NOT EXECUTED
```

### Purpose

Confirm that deleting the app really deletes local content, and that signing
back in restores what the account owns and nothing else.

### Steps

1. Sign in as account A. Save three moments. Note their dates.
2. Join the study as `P-01` and record activity, so there is study state to
   check as well.
3. Confirm the three moments and the study state are present.
4. Delete the app.
   ```bash
   xcrun devicectl device uninstall app --device <IOS_DEVICE_ID> com.voicememory.mobile
   adb -s <ANDROID_DEVICE_ID> uninstall com.voicememory.mobile
   ```
5. Reinstall the same build. Launch without signing in. Confirm no moment, no
   transcript, and no study state from step 1–2 is visible to a signed-out user.
6. Sign in as account A. Confirm the three moments return, with their original
   dates, from the account's own storage.
7. Confirm study state: on iOS the Keychain can survive an uninstall, so record
   what you actually observe. If the previous agreement is still present, it
   must still name account A's archive and must still be revocable. If it is
   gone, the participant must be asked to consent again before anything is
   collected. Either is acceptable; silently resuming collection without a
   visible agreement is not.
8. Reinstall a second time and sign in as account B. Confirm none of account A's
   moments are visible.

### Pass criteria

Step 5 shows nothing; step 6 restores exactly the three moments; step 7 leaves
consent either explicitly present or explicitly re-requested; step 8 shows no
cross-account content.

### Fail criteria

Any of account A's content visible while signed out or signed in as B; a moment
lost that the account owned; collection resuming after reinstall without a
visible, revocable agreement.

---

## 8. Account switching

```text
Result:        NOT EXECUTED
Run by:        NOT EXECUTED
Date:          NOT EXECUTED
Build SHA:     NOT EXECUTED
Device:        NOT EXECUTED
OS version:    NOT EXECUTED
Evidence:      NOT EXECUTED
Per-step:      NOT EXECUTED
```

### Purpose

The device-level counterpart to the automated isolation suites in
`apps/voicememory_mobile/test/archive_account_isolation_test.dart` and
`apps/voicememory_mobile/test/study_mode_test.dart`. Those prove the storage and
study layers keep two archives apart in process; this proves it on a real device
with real sign-in.

### Steps

1. Sign in as account A. Save two moments containing a distinctive, memorable
   phrase you can search for later. Join the study as `A-01` and record activity.
2. Sign out. Confirm nothing from account A is readable while signed out.
3. Sign in as account B on the same device. Confirm the moment list is empty and
   the distinctive phrase from step 1 is not findable by search.
4. Confirm account B is not enrolled in the study and shows no counts, no
   feedback, and no notes from account A.
5. Join the study as account B with code `B-01`, record activity, and export.
   Confirm the export's `participant.code` is `B-01`, that it does not contain
   `A-01`, and that the signal counts are B's own and do not include A's.
6. Capture a moment as B. Sign out, sign back in as A. Confirm A sees its two
   original moments and not B's.
7. Confirm A is still enrolled as `A-01` with its own counts intact.
8. Leave the study as B. Confirm A remains enrolled and A's counts are unchanged.
9. Delete account B from the account screen. Confirm A's moments and study state
   survive untouched.
10. Sign in as a third, brand-new account C. Confirm it starts empty and is not
    offered either A's or B's content.

### Pass criteria

At no point does either account see the other's moments, counts, feedback,
notes, or participant code. Steps 8 and 9 leave A entirely unaffected.

### Fail criteria

Any content, count, or code crossing between accounts; a search finding the
step-1 phrase under B; a study export under one code containing another's data;
an account deletion removing another account's content.
