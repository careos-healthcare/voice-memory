import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// The language the customer confirmed they speak into this app.
///
/// Three states, and the difference between the first two is the whole point:
///
/// * key absent — never asked, or asked and not yet answered. [read] returns
///   null and on-device recognition does not run. There is no platform default
///   and no device-locale fallback, because a wrong-language recogniser returns
///   confident text that is not what the person said, and this app quotes
///   transcripts back as verbatim evidence.
/// * an identifier no longer in [SpeechLocaleCatalog.offered] — also read as
///   null, so the customer is asked again rather than recognised in a language
///   this build cannot honestly offer.
/// * a catalogued identifier — the confirmed answer, kept until they change it.
///
/// Unreadable storage reads as null for the same reason
/// `LocalTranscriptionChoiceStore` reads as unset: a disk error is not an
/// answer, and inventing one here spends the customer's credibility on a guess.
class SpeechLocaleStore {
  SpeechLocaleStore(this._prefs);

  static const String prefsKey = 'speech_transcription_locale_v1';

  final MobilePrefsStore _prefs;

  Future<ConfirmedSpeechLocale?> read() async {
    try {
      final raw = await _prefs.readJsonMap(prefsKey);
      final stored = raw?['localeIdentifier'];
      if (stored is! String) return null;
      final entry = SpeechLocaleCatalog.entryFor(stored);
      if (entry == null) return null;
      return entry.locale;
    } on Object {
      // ignore: silent_catch_audit — an unreadable preference is not a
      // confirmed language, and guessing one fabricates quotations.
      return null;
    }
  }

  /// Whether the customer has answered, distinct from what they answered.
  Future<bool> hasConfirmed() async => (await read()) != null;

  Future<void> confirm(ConfirmedSpeechLocale locale) async {
    await _prefs.writeJsonMap(prefsKey, {
      'localeIdentifier': locale.identifier,
      'confirmedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Forgets the answer, so the customer is asked again.
  Future<void> clear() async {
    await _prefs.writeJsonMap(prefsKey, {});
  }

  /// A [SpeechLocaleReader] bound to this store.
  SpeechLocaleReader get reader => read;
}
