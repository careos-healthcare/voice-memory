# ArchiveMe V1 release checklist

Repository checks are evidence only for the command actually run. Store
dashboards, signing, purchases, restore, refund, accessibility devices, and
physical-device recording require dated external evidence. Nothing in this
repository has been confirmed against a store or a physical device.

## Automated gates

Run from the repository root unless noted.

- `npm run check:identity` — shipping iOS pbxproj, Info.plist, entitlements and
  Android `build.gradle.kts` agree with `config/release/archive_me_identity.json`
  and no neutralised experimental identifier has leaked in.
- `npm run check:backend-allowlist` — every route under `app/api` appears in
  `config/release/archive_me_v1_backend_allowlist.json`.
- `npm run test:v1-product-contract` — the four primary destinations and the
  prohibited capability groups.
- `npm run test:docs-drift` — `docs/current/` matches how the app actually
  behaves.
- `npm run validate:backend-release` — migrations, billing, account deletion,
  transcribe route, sync parsing, metered usage, monetization contract drift and
  the monetization documentation verifier.
- `npm run monetization:verify` — as above plus deployment-owned production
  usage allowances. Requires the configured release environment.
- Flutter: dependencies resolve, `flutter analyze` is clean, and the retained V1
  test suite passes.
- iOS: Pods resolve; plugin registrant, Info.plist, entitlements, privacy
  manifest, and a no-codesign build are inspected.
- Android: dependency graph and merged release manifest contain only the
  permissions, services and providers listed in
  `config/product/archive_me_v1_release_contract.json`; debug APK and release
  AAB build.
- Backend: locked install, type-check, lint, tests, migrations, API-only release
  graph, and production build pass.

## Release identity — BLOCKED_EXTERNAL

`config/release/archive_me_identity.json` is the only authority for identifiers.

- The shipping iOS Release build configuration at
  `apps/voicememory_mobile/ios/Runner.xcodeproj/project.pbxproj:925` sets
  `PRODUCT_BUNDLE_IDENTIFIER = com.voicememory.mobile`, and
  `apps/voicememory_mobile/android/app/build.gradle.kts:70` sets the same
  `applicationId`. `com.voicememory.mobile` is canonical because that is what the
  shipping project declares, not because it was externally confirmed.
- Earlier revisions of this checklist instructed the reader to expect
  `com.voicememory.app` in App Store Connect. That instruction was wrong as a
  statement about the shipping binary and has been removed.
  `com.voicememory.app` is a legacy identifier that must never be reintroduced
  as a bundle identifier or application id.
- Only App Store Connect and the Play Console can confirm which package the
  published or in-review application actually uses. Do not rename either
  application. Record the answer in
  [`STORE_IDENTITY_CHECKLIST.md`](STORE_IDENTITY_CHECKLIST.md).
- `com.voicememory.app.pro.monthly` and `com.voicememory.app.pro.annual` are
  store *product* identifiers, not bundle identifiers. Their legacy prefix must
  not be changed to match a bundle identifier.

## Manual release blockers

Every item below is `BLOCKED_EXTERNAL`. None has been performed.

- [ ] Confirm the published iOS bundle identifier in App Store Connect.
- [ ] Confirm the published Android package name in the Play Console.
- [ ] Confirm the RevenueCat app id, project reference and that entitlement
      `archive_loop_pro` is attached to both store products.
- [ ] Confirm the per-platform Firebase app ids and that an APNs key is uploaded.
      `config/release/archive_me_identity.json` notes that a single
      `FIREBASE_APP_ID` is threaded to both platforms, which cannot be correct
      for a real Firebase project.
- [ ] Confirm the `aps-environment` entitlement is injected at signing and that
      the App ID has the Push Notifications capability.
- [ ] Confirm monthly and annual localized storefront products exist and are
      approved, then exercise sandbox purchase, restore, expiry and refund.
- [ ] Decide the `/api/billing/restore` gap recorded in
      `config/release/archive_me_v1_backend_allowlist.json`: implement the route
      or remove the client call.
- [ ] Run every real-device script in `ACCESSIBILITY_DEVICE_VERIFICATION.md`
      (VoiceOver, TalkBack, microphone permission, background recording,
      keyboard navigation, maximum Dynamic Type, reduced motion).
- [ ] Verify recording interruption, 24-hour temporary-audio recovery,
      remote-transcription disclosure, export, and account deletion on supported
      physical devices.
- [ ] Detach or accept the two residual WebSocket upgrades recorded as
      `STILL_REACHABLE_ON_CUSTOM_SERVER` in
      `config/release/archive_me_v1_backend_allowlist.json` when serving via
      `server.entry.ts`.

An unchecked item is a blocker. Do not report an unchecked item as passed, and
do not treat a written script as device evidence.
