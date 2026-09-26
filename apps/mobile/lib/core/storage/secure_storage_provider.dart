import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Account-key storage. The wrapped key stays on this device.
///
/// iOS uses `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
/// `synchronizable: false` keeps the item out of iCloud Keychain.
/// Android uses encrypted shared preferences.
const AndroidOptions accountKeyAndroidOptions = AndroidOptions(
  encryptedSharedPreferences: true,
);

const IOSOptions accountKeyIosOptions = IOSOptions(
  accessibility: KeychainAccessibility.first_unlock_this_device,
  synchronizable: false,
);

const FlutterSecureStorage accountKeySecureStorage = FlutterSecureStorage(
  aOptions: accountKeyAndroidOptions,
  iOptions: accountKeyIosOptions,
);
