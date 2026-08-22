import 'package:flutter/foundation.dart';

/// The language a recording is expected to be in, as the customer stated it.
///
/// This type exists so that "which language?" cannot be answered by accident.
/// A speech recogniser pointed at the wrong language does not fail — it returns
/// fluent text in the language it was asked for, and this app quotes transcripts
/// back to people as their own verbatim words in support of claims about their
/// beliefs. A guessed language therefore produces a fabricated quotation
/// attributed to the person who never said it, which is worse than no
/// transcript at all.
///
/// The constructor is private and the only public way in is
/// [ConfirmedSpeechLocale.confirmed], which takes an identifier the customer
/// picked from [SpeechLocaleCatalog.offered]. There is deliberately no
/// `fromDeviceLocale`, no `Locale.current`, and no default: a device setting is
/// evidence about a phone, not about the language someone speaks into it.
/// `speech_locale_contract_test.dart` scans this library for those and fails if
/// one appears.
@immutable
final class ConfirmedSpeechLocale {
  const ConfirmedSpeechLocale._(this.identifier);

  /// Builds a locale from an identifier the customer affirmatively chose.
  ///
  /// Returns null for anything that is not a well-formed BCP-47-ish identifier,
  /// which is the same answer as "not chosen": callers must not transcribe.
  static ConfirmedSpeechLocale? confirmed(String? identifier) {
    final raw = identifier?.trim();
    if (raw == null || raw.isEmpty) return null;
    final normalized = raw.replaceAll('_', '-');
    if (!_identifierPattern.hasMatch(normalized)) return null;
    return ConfirmedSpeechLocale._(normalized);
  }

  static final RegExp _identifierPattern = RegExp(
    r'^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})*$',
  );

  /// The identifier handed to `SFSpeechRecognizer(locale:)`.
  final String identifier;

  /// The primary language subtag, lowercased — `en` for `en-GB`.
  ///
  /// Matches `IosNativeSpeechTranscription.primaryLanguageSubtag`, which is
  /// what the Swift side compares to decide whether the recogniser it got back
  /// speaks the language that was asked for.
  String get primaryLanguageSubtag =>
      identifier.split('-').first.toLowerCase();

  @override
  bool operator ==(Object other) =>
      other is ConfirmedSpeechLocale && other.identifier == identifier;

  @override
  int get hashCode => identifier.hashCode;

  @override
  String toString() => 'ConfirmedSpeechLocale($identifier)';
}

/// One language the customer can be offered for speech recognition.
class OfferedSpeechLocale {
  const OfferedSpeechLocale({
    required this.identifier,
    required this.displayName,
    required this.endonym,
  });

  final String identifier;

  /// Name in English, for the surrounding UI.
  final String displayName;

  /// Name in the language itself, so someone who does not read the app's
  /// current language can still find their own.
  final String endonym;

  ConfirmedSpeechLocale get locale =>
      ConfirmedSpeechLocale.confirmed(identifier)!;
}

/// The languages this build offers for on-device speech recognition.
///
/// [offered] is the hand-maintained fallback, used when the device cannot be
/// asked. It is conservative and it is also wrong in one direction: it lists
/// `gu-IN`, which `SFSpeechRecognizer.supportedLocales()` does not report, so
/// a Gujarati speaker who picks it gets `locale_unsupported` and no transcript.
/// Picking an unsupported language fails safe rather than transcribing in
/// another one, but it still fails.
///
/// [offeredForDevice] is the real authority and should be preferred wherever
/// the channel can be reached: the device reports 63 locales against these 13,
/// and the 50 it adds — Arabic, Korean, Russian, Turkish, Vietnamese, Thai,
/// Polish, Dutch, Cantonese and the rest — are languages in which this build
/// otherwise offers no private transcription at all.
abstract final class SpeechLocaleCatalog {
  SpeechLocaleCatalog._();

  static const List<OfferedSpeechLocale> offered = [
    OfferedSpeechLocale(
      identifier: 'en-US',
      displayName: 'English (United States)',
      endonym: 'English (United States)',
    ),
    OfferedSpeechLocale(
      identifier: 'en-GB',
      displayName: 'English (United Kingdom)',
      endonym: 'English (United Kingdom)',
    ),
    OfferedSpeechLocale(
      identifier: 'en-IN',
      displayName: 'English (India)',
      endonym: 'English (India)',
    ),
    OfferedSpeechLocale(
      identifier: 'es-ES',
      displayName: 'Spanish (Spain)',
      endonym: 'Español (España)',
    ),
    OfferedSpeechLocale(
      identifier: 'es-MX',
      displayName: 'Spanish (Mexico)',
      endonym: 'Español (México)',
    ),
    OfferedSpeechLocale(
      identifier: 'fr-FR',
      displayName: 'French',
      endonym: 'Français',
    ),
    OfferedSpeechLocale(
      identifier: 'de-DE',
      displayName: 'German',
      endonym: 'Deutsch',
    ),
    OfferedSpeechLocale(
      identifier: 'it-IT',
      displayName: 'Italian',
      endonym: 'Italiano',
    ),
    OfferedSpeechLocale(
      identifier: 'pt-BR',
      displayName: 'Portuguese (Brazil)',
      endonym: 'Português (Brasil)',
    ),
    OfferedSpeechLocale(
      identifier: 'hi-IN',
      displayName: 'Hindi',
      endonym: 'हिन्दी',
    ),
    OfferedSpeechLocale(
      identifier: 'gu-IN',
      displayName: 'Gujarati',
      endonym: 'ગુજરાતી',
    ),
    OfferedSpeechLocale(
      identifier: 'ja-JP',
      displayName: 'Japanese',
      endonym: '日本語',
    ),
    OfferedSpeechLocale(
      identifier: 'zh-CN',
      displayName: 'Chinese (Mandarin, Simplified)',
      endonym: '中文（简体）',
    ),
  ];

  /// The offered entry for [identifier], or null when it is not on the list.
  ///
  /// Used to validate a stored preference on read. An identifier that has been
  /// dropped from the catalogue reads as "not chosen", so the customer is asked
  /// again rather than transcribed in a language this build no longer offers.
  static OfferedSpeechLocale? entryFor(String? identifier) {
    if (identifier == null) return null;
    final normalized = identifier.trim().replaceAll('_', '-').toLowerCase();
    for (final entry in offered) {
      if (entry.identifier.toLowerCase() == normalized) return entry;
    }
    return null;
  }

  /// The choices to show, given the identifiers the device reports.
  ///
  /// This widens what is *offered*. It is not a way to skip the question: the
  /// result is a list of choices, every element still has to be tapped, and
  /// [ConfirmedSpeechLocale] is still the only thing that opens the channel.
  /// A device knowing 63 languages is evidence about a recogniser, not about
  /// the person holding the phone, so nothing here selects an entry.
  ///
  /// Curated metadata wins where it exists, so the entries in [offered] keep
  /// their endonyms. A language the device reports and this file has no name
  /// for is offered under its identifier — worse to read than `Français`, and
  /// far better than being unable to choose the language at all.
  ///
  /// Identifiers [ConfirmedSpeechLocale.confirmed] cannot parse are dropped,
  /// since they could never become a choice. An empty result falls back to
  /// [offered] rather than to an empty picker.
  static List<OfferedSpeechLocale> offeredForDevice(
    Iterable<String> deviceIdentifiers,
  ) {
    final resolved = <String, OfferedSpeechLocale>{};
    for (final raw in deviceIdentifiers) {
      final locale = ConfirmedSpeechLocale.confirmed(raw);
      if (locale == null) continue;
      final curated = entryFor(locale.identifier);
      if (curated != null) {
        resolved[locale.identifier.toLowerCase()] = curated;
        continue;
      }
      resolved[locale.identifier.toLowerCase()] = OfferedSpeechLocale(
        identifier: locale.identifier,
        displayName: locale.identifier,
        endonym: locale.identifier,
      );
    }
    if (resolved.isEmpty) return offered;
    // Case-insensitive, or every uncurated entry sorts below every curated one
    // purely because `ar-SA` is lowercase and `Arabic` would not have been.
    final entries = resolved.values.toList()
      ..sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
    return List.unmodifiable(entries);
  }
}

/// Reads the customer's confirmed speech language, or null when unanswered.
///
/// Null is a real, expected value and must never be replaced by a device
/// locale further down the call chain.
typedef SpeechLocaleReader = Future<ConfirmedSpeechLocale?> Function();
