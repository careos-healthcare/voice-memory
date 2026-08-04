# iOS OS integration

The share extension and widgets use:

- App Group: `group.com.voicememory.mobile`
- Shared Keychain access group: `$(AppIdentifierPrefix)com.voicememory.mobile.shared`
- Keychain service/account: `com.voicememory.mobile.os-integration` /
  `app-group-handoff-aes-gcm-v1`

The existing Flutter vault key is intentionally not copied into an extension.
`SecureAppGroupStore` creates a dedicated random 256-bit key in the shared
Keychain group and stores only AES-GCM envelopes in the App Group. Access is
serialized across processes with `flock`.

## Flutter bridge

`archive_me/os_level_integration` implements the contract in
`SharedVaultPlatformBridge`:

- `sharedContainerPath`
- `drainShareInbox`
- `drainWidgetActions`
- `extensionStatus`
- `publishWidgetSnapshot`
- `reloadWidgets`

Share items are individually encrypted and flattened to the Dart
`SharedVaultPayload` schema. Native iOS validates each decrypted record and
deletes it only after conversion succeeds. Images and files are capped at
20 MiB each, 40 MiB per extension invocation, and 12 items.

On iOS 17 and later the habit widget writes a `completeHabit` action with its
step ID and local calendar day. Older systems open the configured deep link.

If Flutter ever reads the App Group files directly, it must use the exact
Keychain service, account, access group, and AES-GCM envelope format above.
Never place the key, share payload, widget title, or widget summary in shared
`UserDefaults`.

The App ID and both extension App IDs must have the App Groups and Keychain
Sharing capabilities enabled in the Apple Developer portal before device or
archive signing can succeed.
