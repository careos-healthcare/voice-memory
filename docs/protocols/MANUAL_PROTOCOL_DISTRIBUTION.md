# Manual protocols — store distribution

Part of [`MANUAL_TEST_PROTOCOLS.md`](MANUAL_TEST_PROTOCOLS.md). Not executed.

Covers protocols 14 and 15. **No build has been uploaded to App Store Connect or
to the Google Play Console from this repository, no tester has been invited, and
no review has been requested. There is no TestFlight build number and no Play
internal release to cite.**

Both protocols gate the 25-user test
([protocol 1](MANUAL_PROTOCOL_USER_STUDY.md#1-25-user-test)), which cannot begin
until participants can actually install the app.

---

## 14. TestFlight

```text
Result:          NOT EXECUTED
Run by:          NOT EXECUTED
Date:            NOT EXECUTED
Build SHA:       NOT EXECUTED
App version:     NOT EXECUTED
TestFlight build: NOT EXECUTED
Evidence:        NOT EXECUTED
Per-step:        NOT EXECUTED
```

### Purpose

Get a study build onto real iPhones belonging to people who are not the author,
and confirm it survives Apple's beta review.

### Preconditions

An Apple Developer Program membership, an App Store Connect record for
`com.voicememory.mobile`, a distribution certificate and provisioning profile,
and the export compliance answer prepared.

### Steps

1. Confirm the version and build number are ahead of anything already uploaded:
   ```bash
   rg -n '^version:' apps/voicememory_mobile/pubspec.yaml
   ```
   A duplicate build number is rejected at upload.
2. Build the archive with the study defines set, exactly as in the
   [index](MANUAL_TEST_PROTOCOLS.md#build-the-artefact-once-then-run-every-protocol-against-it).
   Record the SHA compiled into `STUDY_BUILD_SHA`.
3. Upload the `.ipa` to App Store Connect. Record the upload timestamp and the
   build number Apple assigns.
4. Confirm processing completes without an email listing missing entries — in
   particular the microphone usage description and the encryption/export
   compliance declaration.
5. Answer export compliance. Record the answer given.
6. Confirm the build appears under TestFlight and can be assigned to an internal
   group.
7. Install on an internal device from TestFlight. Confirm it launches, and
   confirm the study export from this build reports `"identified": 1` and the
   SHA from step 2. A study build that reports `unknown` here means the defines
   did not reach the artefact, and step 2 must be redone.
8. Submit for external beta review with the beta description and the test
   instructions. Record the submission date.
9. Record the review outcome verbatim. If Apple rejects it, record the rejection
   reason as given; a rejection is a `FAIL` for this protocol, not a blocker to
   be worked around silently.
10. On approval, invite the external testers for protocol 1 and confirm at least
    one non-author tester installs successfully and reaches the first screen.

### Pass criteria

A build is live on TestFlight, external review is approved, step 7 confirms the
build SHA is embedded, and at least one non-author tester has installed and
launched it.

### Fail criteria

Rejected beta review; a build that will not process; a build whose study export
reports an unidentified build; no tester outside the author able to install.

### What this protocol does not prove

That anyone used the app, that anyone liked it, or that anything about the
product is validated. It proves only that the artefact is installable by other
people. Every claim beyond that belongs to protocol 1, which is also
`NOT EXECUTED`.

---

## 15. Play Internal testing

```text
Result:          NOT EXECUTED
Run by:          NOT EXECUTED
Date:            NOT EXECUTED
Build SHA:       NOT EXECUTED
App version:     NOT EXECUTED
Play version code: NOT EXECUTED
Evidence:        NOT EXECUTED
Per-step:        NOT EXECUTED
```

### Purpose

The Android counterpart of protocol 14, plus the Play-specific declarations that
block a release outright if they are wrong.

### Preconditions

A Google Play Console account, an app record for `com.voicememory.mobile`, an
upload key with Play App Signing configured, and the Data safety form prepared.

### Steps

1. Confirm the version code is ahead of anything already uploaded. A duplicate
   version code is rejected.
2. Build the signed `.aab` with the study defines set. Record the SHA compiled
   into `STUDY_BUILD_SHA`.
3. Upload to the internal testing track. Record the version code Play assigns.
4. Confirm no blocking pre-launch issue is reported. Record every warning
   verbatim, including any raised against a device model not otherwise tested.
5. Complete the Data safety form. It must state that audio recordings and
   transcripts are collected, how they are used, and that they can be deleted.
   Confirm what it says matches
   [`DATA_FLOW_AND_PRIVACY.md`](DATA_FLOW_AND_PRIVACY.md); a Data safety form
   that contradicts the app's actual behaviour is a policy violation, and a
   mismatch is a `FAIL` for this protocol.
6. Confirm the declared permissions match the manifest and that no
   foreground-service permission has reappeared:
   ```bash
   rg -n 'uses-permission' \
     apps/voicememory_mobile/android/app/src/main/AndroidManifest.xml
   ```
7. Complete the sensitive-permissions declaration if Play asks for one, and
   record the justification given.
8. Add internal testers and confirm the opt-in link works from an account that
   is not the developer account.
9. Install from Play on a physical handset. Confirm it launches, and confirm the
   study export reports `"identified": 1` and the SHA from step 2.
10. Confirm the Play-installed build can complete protocol 3 step 4 — a real
    recording, saved — since a Play-signed build differs from a locally
    installed one.
11. Record the review outcome for the internal track verbatim.

### Pass criteria

A build is live on the internal track, the Data safety form matches actual
behaviour, no blocking pre-launch issue, and a non-developer account has
installed the build and completed a recording.

### Fail criteria

Rejected release; a Data safety declaration that does not match
[`DATA_FLOW_AND_PRIVACY.md`](DATA_FLOW_AND_PRIVACY.md); a permission in the
manifest that is not declared; a study export from the Play build reporting an
unidentified build; a non-developer tester unable to install.

### What this protocol does not prove

The same limit as protocol 14: installability, and nothing about whether the
product works for anyone.
