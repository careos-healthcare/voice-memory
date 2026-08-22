import 'dart:convert';

import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/personal_content_encrypted_storage.dart';
import 'package:archiveme_mobile/storage/sensitive_prefs_encrypted_blob.dart';
import 'package:flutter/foundation.dart';

/// A caregiver's name and email as typed by the subject.
///
/// This is personal data about a third party who has not agreed to anything in
/// this app, so it is held to the same bar as the subject's own free text.
@immutable
class CaregiverGrantContact {
  const CaregiverGrantContact({required this.name, required this.email});

  factory CaregiverGrantContact.fromJson(Map<String, Object?> json) {
    return CaregiverGrantContact(
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
    );
  }

  final String name;
  final String email;

  Map<String, Object?> toJson() => {'name': name, 'email': email};

  @override
  bool operator ==(Object other) =>
      other is CaregiverGrantContact &&
      other.name == name &&
      other.email == email;

  @override
  int get hashCode => Object.hash(name, email);
}

/// AES-256-GCM storage for caregiver contact details, keyed by caregiver id.
///
/// `MobilePrefsStore` is plain JSON on disk and says so in its own doc comment
/// — "Personal free text ... must use `PersonalContentEncryptedStorage`". A
/// third party's name and email are exactly that, so this goes through
/// [SensitivePrefsEncryptedBlob], which seals the payload with the same
/// per-namespace key the journal uses and stores only the ciphertext envelope
/// under [securePrefsKey].
///
/// None of it is sent to a server. The grant path transmits
/// `CaregiverGrantRequest.caregiverId`, an opaque local id, so the third
/// party's details stay on this device.
class CaregiverGrantContactStore {
  const CaregiverGrantContactStore({required this.blob});

  static const String securePrefsKey = 'secure_caregiver_grant_contacts_v1';
  static const String payloadRootKey = 'contacts';
  static const String keyAlias = 'caregiver_grant_contacts_key_v1';

  final SensitivePrefsEncryptedBlob blob;

  /// Builds a store backed by the app's secure storage and prefs file.
  static Future<CaregiverGrantContactStore> open() async {
    final services = AppServices.instance;
    final encryptedStorage = await PersonalContentEncryptedStorage.forNamespace(
      secureStorage: services.secureStorage,
      keyAlias: keyAlias,
    );
    return CaregiverGrantContactStore(
      blob: SensitivePrefsEncryptedBlob(
        prefs: services.prefs,
        encryptedStorage: encryptedStorage,
        securePrefsKey: securePrefsKey,
        payloadRootKey: payloadRootKey,
      ),
    );
  }

  Future<void> save({
    required String caregiverId,
    required CaregiverGrantContact contact,
  }) async {
    final current = await blob.readStringMap();
    await blob.writeStringMap({
      ...current,
      caregiverId: jsonEncode(contact.toJson()),
    });
  }

  Future<CaregiverGrantContact?> read(String caregiverId) async {
    final raw = (await blob.readStringMap())[caregiverId];
    if (raw == null || raw.trim().isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return CaregiverGrantContact.fromJson(
      Map<String, Object?>.from(decoded.cast<String, Object?>()),
    );
  }

  Future<void> remove(String caregiverId) async {
    final current = Map<String, String>.from(await blob.readStringMap())
      ..remove(caregiverId);
    await blob.writeStringMap(current);
  }
}
