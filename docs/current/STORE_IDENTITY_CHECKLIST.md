# ArchiveMe store identity checklist

**Release identity gate: `BLOCKED_EXTERNAL`.**

Nothing in this repository can verify the release identity. The canonical values
below are what the *source* declares. Whether they match the *published*
applications can only be confirmed by a human signing in to App Store Connect,
Google Play Console, Firebase and RevenueCat. No external system was contacted
to produce this document, and no external verification is claimed anywhere in
it.

Machine-readable source of truth:
[`config/release/archive_me_identity.json`](../../config/release/archive_me_identity.json).
Automated source-side guard: `npm run check:identity`.

---

## A bundle ID is not a store product ID

These are two unrelated namespaces. Conflating them is the specific mistake this
checklist exists to prevent.

| | Bundle ID / application ID | Store product ID |
| --- | --- | --- |
| **What it identifies** | The application binary itself | One purchasable SKU sold *inside* that binary |
| **How many** | Exactly one per app per platform | As many as you sell |
| **Where it is declared** | `project.pbxproj` (`PRODUCT_BUNDLE_IDENTIFIER`), `build.gradle.kts` (`applicationId`) | App Store Connect and Play Console product catalogues, mirrored into RevenueCat |
| **Mutable after publish?** | **No.** Changing it creates a different app and orphans every existing install, review and subscription | Effectively no. Changing it orphans existing subscribers |
| **This project's values** | `com.voicememory.mobile` (both platforms) | `com.voicememory.app.pro.monthly`, `com.voicememory.app.pro.annual` |

Read that last row carefully. The store product IDs begin with
`com.voicememory.app.` — which is also this project's **legacy** bundle ID. The
shared prefix is a historical accident, not a relationship. `com.voicememory.app`
is **not** the bundle ID of the shipping app, and the product IDs are **not**
derived from the bundle ID.

Concretely, the two mistakes to never make:

- Do **not** "fix" the product IDs to `com.voicememory.mobile.pro.monthly` to
  match the bundle ID. That orphans every existing subscriber.
- Do **not** "fix" the bundle ID to `com.voicememory.app` to match the product ID
  prefix. That orphans the published application.

A third identifier, the **RevenueCat entitlement ID** (`archive_loop_pro`), is a
third namespace again: it is a label you choose inside RevenueCat that one or
more store products grant. It is not visible to Apple or Google.

---

## The known drift

`RELEASE_CHECKLIST.md:21-22` currently instructs the reader to:

> Verify `com.voicememory.app` in App Store Connect and `com.voicememory.mobile`
> in Play Console without renaming either application.

That claims iOS and Android ship under **different** identifiers. The shipping
iOS project disagrees: `apps/voicememory_mobile/ios/Runner.xcodeproj/project.pbxproj:925`
sets `PRODUCT_BUNDLE_IDENTIFIER = com.voicememory.mobile;` in the Runner target's
**Release** build configuration.

Exactly one of those is correct and **only App Store Connect can settle it**.
This is the reason the gate is `BLOCKED_EXTERNAL` rather than merely unverified.
Resolve step 1 below before any release decision that depends on iOS identity.

---

## 1. App Store Connect — `BLOCKED_EXTERNAL`

1. Sign in to [App Store Connect](https://appstoreconnect.apple.com) → **Apps**.
2. Open the ArchiveMe app record → **App Information**.
3. Record the **Bundle ID** exactly as shown. Then resolve the drift:
   - **If it reads `com.voicememory.mobile`** — source is correct. Update
     `RELEASE_CHECKLIST.md:21` to say `com.voicememory.mobile`. Change nothing
     else. Done.
   - **If it reads `com.voicememory.app`** — **stop and escalate.** Do not edit
     the pbxproj to match. A published bundle ID cannot be renamed, and the
     shipping project would then be building an app that cannot be uploaded to
     that record. The decision (new app record vs. correcting the project before
     first publish) is a release-owner decision, not a code change.
   - **If there is no ArchiveMe record at all** — nothing is published on iOS, so
     `com.voicememory.mobile` is free to adopt as canonical. Update
     `RELEASE_CHECKLIST.md` and note in
     `config/release/archive_me_identity.json` that iOS is unpublished.
4. Go to **Certificates, Identifiers & Profiles** → **Identifiers** in the
   [Apple Developer portal](https://developer.apple.com/account/resources/identifiers/list).
   Confirm an App ID exists for `com.voicememory.mobile` and that these
   capabilities are enabled, because the shipping entitlements require them:
   - [ ] **App Groups**, containing `group.com.voicememory.mobile`
   - [ ] **iCloud** with container `iCloud.com.voicememory.mobile`
   - [ ] **Keychain Sharing** for `com.voicememory.mobile.shared`
   - [ ] **Push Notifications** — see the Firebase section; no `aps-environment`
         entitlement is declared in source, so this is unverified in both
         directions
5. Confirm App IDs also exist for the two extension targets:
   - [ ] `com.voicememory.mobile.ShareExtension`
   - [ ] `com.voicememory.mobile.ArchiveMeWidgets`
6. Under **In-App Purchases / Subscriptions**, confirm each product exists and
   record its status. These are **product IDs, not bundle IDs**:
   - [ ] `com.voicememory.app.pro.monthly` — status must be *Ready to Submit* or
         *Approved*
   - [ ] `com.voicememory.app.pro.annual` — status must be *Ready to Submit* or
         *Approved*
7. Confirm the provisioning profile named in
   `.github/workflows/build_and_deploy.yml:276` is mapped to
   `com.voicememory.mobile` and is not expired.

## 2. Google Play Console — `BLOCKED_EXTERNAL`

1. Sign in to [Play Console](https://play.google.com/console) → select the
   ArchiveMe app.
2. Under **Dashboard** / **App integrity**, record the **package name**.
   - [ ] It must read `com.voicememory.mobile`, matching
         `apps/voicememory_mobile/android/app/build.gradle.kts:70`.
   - A Play package name is **immutable after first publish**. If it differs,
     **stop and escalate**; do not edit the gradle file to match a published
     package you did not intend to ship under.
3. Under **Monetise → Subscriptions**, confirm each product exists and is
   **Active**. Again, product IDs, not package names:
   - [ ] `com.voicememory.app.pro.monthly`
   - [ ] `com.voicememory.app.pro.annual`
4. Confirm the base plans and offers attached to each subscription are active in
   every target country.
5. Under **Setup → App signing**, confirm Play App Signing is enrolled and
   record the upload key certificate fingerprint. It must match the key used by
   the release job in `.github/workflows/build_and_deploy.yml`.
6. Confirm the app is not in a state that blocks release: no unresolved policy
   declarations, data safety form submitted, content rating completed.

## 3. Firebase — `BLOCKED_EXTERNAL`

No `GoogleService-Info.plist` and no `google-services.json` exist in this
repository. All Firebase configuration is injected at build time via
`dart-define`, read by `apps/voicememory_mobile/lib/push/firebase_options.dart`.

1. Open the [Firebase console](https://console.firebase.google.com) → the
   ArchiveMe project → **Project settings → General**.
2. Record the **Project ID** and **Project number** (the project number is the
   FCM sender ID).
3. Under **Your apps**, confirm **two separate apps** are registered and record
   **both** app IDs. Firebase issues a distinct app ID per platform:
   - [ ] iOS app, bundle ID `com.voicememory.mobile` → app ID of the form
         `1:<project-number>:ios:<hash>`
   - [ ] Android app, package name `com.voicememory.mobile` → app ID of the form
         `1:<project-number>:android:<hash>`
4. **Known defect to resolve here.** `firebase_options.dart` threads a single
   `FIREBASE_APP_ID` value to both the iOS and Android options. That cannot be
   correct for a real Firebase project, because the two platforms have different
   app IDs. Once you have both values from step 3, the build must supply them as
   two distinct defines. Record both in
   `config/release/archive_me_identity.json` under `firebase.iosAppId` and
   `firebase.androidAppId`.
5. Under **Cloud Messaging**, confirm an **APNs authentication key** (or
   certificate) is uploaded for `com.voicememory.mobile`. Without it iOS push
   silently fails. Cross-check against step 1.4 — no `aps-environment`
   entitlement is declared in source, so Push Notifications capability must be
   confirmed in the Apple Developer portal too.
6. Confirm the CI secrets `FIREBASE_API_KEY`, `FIREBASE_APP_ID`,
   `FIREBASE_PROJECT_ID` and `FIREBASE_MESSAGING_SENDER_ID` are populated for
   both the `build_android` and `build_ios` jobs. If any is empty the client
   treats push as unconfigured and continues silently.

## 4. RevenueCat — `BLOCKED_EXTERNAL`

No RevenueCat app ID or project reference is committed anywhere in this
repository, so both must be read from the dashboard.

1. Sign in to [RevenueCat](https://app.revenuecat.com) → the ArchiveMe project.
2. Record the **Project ID / reference** from the project settings URL and store
   it in `config/release/archive_me_identity.json` under
   `revenueCat.projectReference`.
3. Under **Apps**, confirm **two** app configurations exist and record each
   RevenueCat **App ID** into `revenueCat.appId`:
   - [ ] App Store app, bundle ID `com.voicememory.mobile`, with a valid
         **App Store Connect shared secret** or in-app purchase key
   - [ ] Play Store app, package `com.voicememory.mobile`, with valid
         **Play service account credentials**
4. Under **Entitlements**, confirm an entitlement with the identifier
   **`archive_loop_pro`** exists. This exact string is asserted by
   `config/monetization/archive_me_entitlement_matrix.json:5` and by
   `.github/workflows/build_and_deploy.yml:99,207`.
   - [ ] `archive_loop_pro` exists
   - [ ] The legacy alias `pro` is still present, or is still returned for
         existing subscribers. The client honours it via
         `MonetizationPolicy.acceptedLegacyEntitlementAliases`, so removing it
         in RevenueCat would silently downgrade grandfathered subscribers.
5. Confirm both store products are **attached** to `archive_loop_pro` in both
   apps. An entitlement with no attached product returns `false` for every
   customer:
   - [ ] `com.voicememory.app.pro.monthly`
   - [ ] `com.voicememory.app.pro.annual`
6. Under **Integrations → Webhooks**, confirm the webhook points at the
   production `POST /api/billing/revenuecat/webhook` and that its
   `Authorization` header equals the deployed `REVENUECAT_WEBHOOK_AUTH_TOKEN`.
7. Confirm the CI secrets `REVENUECAT_IOS_API_KEY` and
   `REVENUECAT_ANDROID_API_KEY` are populated, and that the server has
   `REVENUECAT_SECRET_API_KEY` set.
8. Perform one sandbox purchase and one restore on each platform, and confirm
   `GET /api/billing/entitlements` and `GET /api/user/subscription-status` both
   report Pro.

---

## Neutralised second identity — do not revive

The repository root contains a residual Capacitor Android project at
`android/`, whose `android/app/src/main/assets/capacitor.config.json` declares a
**second production identity**:

```json
{ "appId": "com.voicememory.app", "appName": "ArchiveMe", "ios": { "scheme": "voicememory" } }
```

This is **not** the shipping client and was deliberately **not** renamed, because
renaming the shipping `com.voicememory.mobile` identity is the dangerous
operation. It is neutralised by exclusion instead:

- `.vercelignore` and `.dockerignore` exclude `android/` and `capacitor.config.*`
- The root Capacitor Gradle project is not buildable — `android/app/build.gradle`,
  `android/build.gradle`, `android/settings.gradle` and the Gradle wrapper are
  all deleted, so no artifact bearing `com.voicememory.app` can be produced
- `config/release/archive_me_identity.json` records it under
  `experimentalIdentifiers`, never as canonical
- `npm run check:identity` fails if `com.voicememory.app` ever appears in the
  shipping iOS pbxproj, Info.plist, entitlements, Android gradle, Android
  manifest or `release_identity.dart`

Its URL scheme `voicememory` is likewise obsolete; the shipping scheme is
`archiveme`.

---

## Sign-off

The gate stays `BLOCKED_EXTERNAL` until every checkbox above is ticked by a named
human against the live dashboards. Record the outcome here — including the App
Store Connect bundle ID from step 1.3, which is the blocking unknown.

| Item | Verified by | Date | Value recorded |
| --- | --- | --- | --- |
| App Store Connect bundle ID | | | |
| App Store Connect IAP products | | | |
| Play Console package name | | | |
| Play Console subscriptions | | | |
| Firebase iOS app ID | | | |
| Firebase Android app ID | | | |
| Firebase APNs key uploaded | | | |
| RevenueCat app IDs | | | |
| RevenueCat project reference | | | |
| RevenueCat `archive_loop_pro` entitlement | | | |
| Sandbox purchase + restore, both platforms | | | |
