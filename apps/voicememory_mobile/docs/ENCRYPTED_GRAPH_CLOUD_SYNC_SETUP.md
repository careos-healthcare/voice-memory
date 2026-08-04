# Encrypted graph cloud sync setup

Cloud transports store only the AES-256-GCM encrypted graph envelope. The
portable passphrase is never sent to Apple or Google.

## iOS: iCloud Drive

1. In Apple Developer, enable **iCloud Documents** for
   `com.voicememory.mobile`.
2. Create or attach the container `iCloud.com.voicememory.mobile`.
3. Regenerate the Runner provisioning profiles after enabling the capability.
4. Keep the checked-in `Runner.entitlements` values aligned with that
   container.

The app resolves the ubiquity container with
`FileManager.url(forUbiquityContainerIdentifier:)` and coordinates access with
`NSFileCoordinator`. `path_provider` only supplies sandbox directories and
cannot resolve an iCloud ubiquity container.

Encrypted payloads are written under:

```text
Documents/ArchiveMe_Sync/
```

Validate iCloud upload/download on a physical iOS device signed into iCloud
Drive with a provisioning profile that includes the container. Simulator and
no-codesign builds can verify compilation, but not production container access.

## Android: Google Drive appDataFolder

1. Enable the Google Drive API in Google Cloud.
2. Configure the OAuth consent screen.
3. Register an Android OAuth client for `com.voicememory.mobile` with every
   signing certificate used in development, CI, release, and Play App Signing.
4. Register a Web OAuth client for Google Sign-In's `serverClientId`.
5. Supply that Web client ID through the external build configuration:

```shell
flutter build appbundle \
  --dart-define=GOOGLE_DRIVE_SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID
```

`GOOGLE_DRIVE_SERVER_CLIENT_ID` must be the Web OAuth client ID, not the
Android client ID. This transport does not use Firebase configuration and does
not require or read `google-services.json`; OAuth clients, consent-screen
publishing/test users, API enablement, package name, and signing certificate
fingerprints are configured in Google Cloud Console.

The app requests only:

```text
https://www.googleapis.com/auth/drive.appdata
```

Google Sign-In owns platform credentials. ArchiveMe does not persist OAuth
access or refresh tokens itself.

## Retry behavior

Pending uploads are stored in an encrypted local queue. The queue drains at app
startup, after network reconnection, and after bounded in-process backoff.
Authorization and missing-configuration states remain queued without a retry
storm.

This implementation does not claim killed-app background scheduling. Adding
that behavior requires a separately reviewed WorkManager/BGTask policy.
