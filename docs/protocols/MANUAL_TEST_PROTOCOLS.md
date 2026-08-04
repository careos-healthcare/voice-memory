# Manual test protocols — index and result ledger

Fifteen protocols that cannot be run by any automated check in this repository,
because each one needs a physical device, a store account, a real payment
instrument, or a real person.

**Nothing in this set has been executed.** Every `Result` field in every linked
document reads `NOT EXECUTED`, and that is the correct state of this file today.
Writing a protocol is not running it. Reading one, reviewing it, or citing it in
a release note is not evidence of anything.

## Ledger

| # | Protocol | Result | Document |
| --- | --- | --- | --- |
| 1 | 25-user test | `NOT EXECUTED` | [User study](MANUAL_PROTOCOL_USER_STUDY.md#1-25-user-test) |
| 2 | Physical iOS capture | `NOT EXECUTED` | [Device](MANUAL_PROTOCOL_DEVICE.md#2-physical-ios-capture) |
| 3 | Physical Android capture | `NOT EXECUTED` | [Device](MANUAL_PROTOCOL_DEVICE.md#3-physical-android-capture) |
| 4 | VoiceOver | `NOT EXECUTED` | [Accessibility](MANUAL_PROTOCOL_ACCESSIBILITY.md#4-voiceover) |
| 5 | TalkBack | `NOT EXECUTED` | [Accessibility](MANUAL_PROTOCOL_ACCESSIBILITY.md#5-talkback) |
| 6 | Background interruption | `NOT EXECUTED` | [Device](MANUAL_PROTOCOL_DEVICE.md#6-background-interruption) |
| 7 | Reinstall | `NOT EXECUTED` | [Device](MANUAL_PROTOCOL_DEVICE.md#7-reinstall) |
| 8 | Account switching | `NOT EXECUTED` | [Device](MANUAL_PROTOCOL_DEVICE.md#8-account-switching) |
| 9 | RevenueCat monthly | `NOT EXECUTED` | [Billing](MANUAL_PROTOCOL_BILLING.md#9-revenuecat-monthly) |
| 10 | RevenueCat annual | `NOT EXECUTED` | [Billing](MANUAL_PROTOCOL_BILLING.md#10-revenuecat-annual) |
| 11 | Restore | `NOT EXECUTED` | [Billing](MANUAL_PROTOCOL_BILLING.md#11-restore) |
| 12 | Expiry | `NOT EXECUTED` | [Billing](MANUAL_PROTOCOL_BILLING.md#12-expiry) |
| 13 | Refund / revocation | `NOT EXECUTED` | [Billing](MANUAL_PROTOCOL_BILLING.md#13-refund--revocation) |
| 14 | TestFlight | `NOT EXECUTED` | [Distribution](MANUAL_PROTOCOL_DISTRIBUTION.md#14-testflight) |
| 15 | Play Internal | `NOT EXECUTED` | [Distribution](MANUAL_PROTOCOL_DISTRIBUTION.md#15-play-internal-testing) |

## What counts as a result

A protocol leaves `NOT EXECUTED` only when a named person fills in every field
of the header block on that protocol and attaches the evidence it names. A
partially completed run stays `NOT EXECUTED`; there is no partial credit and no
inferred pass.

Permitted values for `Result`:

- `NOT EXECUTED` — nobody has run it.
- `PASS` — every numbered step met its pass criterion on the recorded build.
- `FAIL: <step number> <what happened>` — at least one step met a fail
  criterion.
- `BLOCKED: <what was missing>` — the run started and could not finish. This is
  not a pass.

## Build the artefact once, then run every protocol against it

The Flutter version is pinned by `.fvmrc` to `3.44.6`. The application id is
`com.voicememory.mobile` on both platforms.

```bash
cd apps/voicememory_mobile
fvm flutter --version          # expect 3.44.6
fvm flutter pub get
fvm flutter devices            # copy the device id you will use
```

Record the exact revision under test before building. Every protocol header
asks for this value, and a run whose SHA is unknown cannot be attributed to a
build:

```bash
git rev-parse HEAD             # full SHA, used below
git rev-parse --short HEAD
rg -n '^version:' apps/voicememory_mobile/pubspec.yaml
```

Build a release-mode binary. Study builds additionally pass the three
`STUDY_*` defines, which is what makes the in-app study export name a commit
instead of reporting `unknown`
(`apps/voicememory_mobile/lib/features/study_mode/study_build_identity.dart`):

```bash
cd apps/voicememory_mobile
SHA="$(git rev-parse HEAD)"
VERSION="$(rg -o '^version: ([0-9.]+)' -r '$1' pubspec.yaml)"
BUILD="$(rg -o '^version: [0-9.]+\+([0-9]+)' -r '$1' pubspec.yaml)"

fvm flutter build ipa --release \
  --dart-define=VOICE_MEMORY_API_BASE_URL="$VOICE_MEMORY_API_BASE_URL" \
  --dart-define=STUDY_BUILD_SHA="$SHA" \
  --dart-define=STUDY_APP_VERSION="$VERSION" \
  --dart-define=STUDY_BUILD_NUMBER="$BUILD"

fvm flutter build appbundle --release \
  --dart-define=VOICE_MEMORY_API_BASE_URL="$VOICE_MEMORY_API_BASE_URL" \
  --dart-define=STUDY_BUILD_SHA="$SHA" \
  --dart-define=STUDY_APP_VERSION="$VERSION" \
  --dart-define=STUDY_BUILD_NUMBER="$BUILD"
```

Billing protocols need the RevenueCat defines as well; see
[Billing](MANUAL_PROTOCOL_BILLING.md#preconditions-for-every-billing-protocol).

## Header block to copy into each run

```text
Result:        NOT EXECUTED | PASS | FAIL: <step> <what happened> | BLOCKED: <reason>
Run by:        <name>
Date:          <YYYY-MM-DD>
Build SHA:     <full git sha compiled into STUDY_BUILD_SHA>
App version:   <pubspec version+build>
Device:        <model> / <OS version>
Store account: <sandbox or internal-tester account, never a real customer>
Evidence:      <paths to screenshots, logs, exports>
Per-step:      1 pass | 2 pass | 3 fail: <what happened>
```

## Related documents

- [`ACCESSIBILITY_DEVICE_VERIFICATION.md`](ACCESSIBILITY_DEVICE_VERIFICATION.md)
  holds the wider accessibility gate set — microphone permission, keyboard
  navigation, Dynamic Type, reduced motion — all marked `BLOCKED_EXTERNAL`. The
  VoiceOver and TalkBack protocols here are narrower and are written to be run
  as part of this set; where they overlap, running one satisfies the other only
  if the recorded build SHA is identical.
- [`RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md) and
  [`STORE_IDENTITY_CHECKLIST.md`](STORE_IDENTITY_CHECKLIST.md) cover submission
  metadata, which these protocols do not.
