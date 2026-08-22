# ArchiveMe Mobile (Flutter)

**This is the canonical ArchiveMe consumer product.** Native iOS/Android app —
**record → transcribe → analyze → local journal → Archive Home**.

> **Record a real moment, preserve the evidence, and safely see what changed
> over time.**

The Next.js project at the repo root is *not* a second consumer app — it's the
backend (authenticated API endpoints this app calls, e.g. transcribe/analyze/
account/sync/export/delete) plus privacy/terms/support/marketing web pages.
Every consumer-facing surface — recording, Archive, proof/evidence, corrections,
subscription — lives here.

## Core loop (implemented)

1. Onboarding → Record
2. Microphone permission + AAC recording
3. API attest / transcribe / analyze (when connected)
4. Save `JournalEntry` locally
5. Archive Home, evidence tools, export/share

## Billing (not launch-ready)

RevenueCat + native IAP code exists, but **purchases are unavailable** until store/RevenueCat setup completes (see `REVENUECAT_LAUNCH_BLOCKERS.md`). No Stripe checkout in the mobile app.

## Run

```bash
cd apps/mobile
flutter pub get
npm run dev   # from repo root — backend on :3000

flutter run --dart-define=VOICE_MEMORY_API_BASE_URL=http://127.0.0.1:3000
```

## Validate (launch-focused)

See [LAUNCH_VALIDATION.md](./LAUNCH_VALIDATION.md) — not the full historical test suite.

```bash
flutter test test/launch_hardening_test.dart
flutter build ios --release --no-codesign
```

From repo root:

```bash
./scripts/validate-mobile-clean-working-tree.sh
```

## Identifiers (brand vs store vs package)

**Public app name:** ArchiveMe  
**Store IDs (iOS + Android):** `com.voicememory.mobile`  
**Dart package:** `archiveme_mobile` (`pubspec.yaml`)

These three layers **intentionally differ**. The Dart package name and repo path
(`apps/mobile/`) do not affect device or store identity. Store/platform IDs are
frozen for continuity — see **[IDENTIFIERS.md](./IDENTIFIERS.md)** for the full
policy, canonical values, and migration rules.

Open **`ios/Runner.xcworkspace`** for iOS builds (not `Runner.xcodeproj`).

## TestFlight / App Store submission

See [APP_STORE_SUBMISSION_PACK.md](./APP_STORE_SUBMISSION_PACK.md) for the consolidated reviewer path, internal TestFlight checklist, and validation commands.

**Physical-device QA:** [docs/TESTFLIGHT_MANUAL_QA.md](./docs/TESTFLIGHT_MANUAL_QA.md)

**Access protection:** [docs/ACCESS_PROTECTION_AUDIT.md](./docs/ACCESS_PROTECTION_AUDIT.md)

**Wedge / retention / acquisition:** [docs/WEDGE_RETENTION_ACQUISITION_PLAN.md](./docs/WEDGE_RETENTION_ACQUISITION_PLAN.md)

**Capacity yes £100k wedge:** [docs/CAPACITY_YES_100K_WEDGE_PLAN.md](./docs/CAPACITY_YES_100K_WEDGE_PLAN.md)

**Capacity yes positioning:** [docs/CAPACITY_YES_POSITIONING_ONE_PAGER.md](./docs/CAPACITY_YES_POSITIONING_ONE_PAGER.md)
