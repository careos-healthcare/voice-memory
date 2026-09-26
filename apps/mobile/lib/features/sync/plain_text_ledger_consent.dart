import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// A signature for sending journal text to the server for AI processing.
///
/// This is separate from encrypted sync and from other remote-processing
/// grants. Nothing is signed until [sign] runs.
class PlainTextLedgerConsent {
  const PlainTextLedgerConsent._();

  static const preferenceKey = 'plain_text_ai_processing_consent_v1';
  static const purpose = 'plain_text_ai_processing';

  static Future<bool> isSigned(MobilePrefsStore prefs) async {
    final raw = await prefs.readJsonMap(preferenceKey);
    return raw?['signed'] == true && raw?['purpose'] == purpose;
  }

  static Future<void> sign(MobilePrefsStore prefs, {DateTime? signedAt}) async {
    await prefs.writeJsonMap(preferenceKey, {
      'signed': true,
      'purpose': purpose,
      'signedAt': (signedAt ?? DateTime.now()).toUtc().toIso8601String(),
    });
  }

  static Future<void> withdraw(MobilePrefsStore prefs) async {
    await prefs.remove(preferenceKey);
  }
}
