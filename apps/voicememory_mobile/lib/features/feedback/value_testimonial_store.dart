import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';

/// One short, voluntary quote about what felt useful — product feedback only.
///
/// Privacy by construction: the record holds the user-typed quote (sanitized,
/// capped), a stable card-type id, and a timestamp. Evidence snippets, belief
/// phrases, thread terms, and transcripts are never attached, the quote never
/// enters analytics payloads, and nothing is shared publicly — share cards
/// keep building from counts only.
class ValueTestimonial {
  const ValueTestimonial({
    required this.quote,
    required this.cardType,
    required this.createdAt,
  });

  final String quote;

  /// Stable id of the card the user rated useful (e.g. `belief_distance`).
  final String cardType;

  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'quote': quote,
    'cardType': cardType,
    'createdAt': createdAt.toIso8601String(),
  };

  static ValueTestimonial? fromJson(Map<String, dynamic> json) {
    final quote = json['quote'];
    final cardType = json['cardType'];
    final createdAt = DateTime.tryParse('${json['createdAt']}');
    if (quote is! String || cardType is! String || createdAt == null) {
      return null;
    }
    return ValueTestimonial(
      quote: quote,
      cardType: cardType,
      createdAt: createdAt,
    );
  }
}

/// Local-only testimonial log in the on-device prefs file. No backend, no
/// analytics free text, no automatic public exposure.
class ValueTestimonialStore {
  ValueTestimonialStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const String storageKey = 'valueTestimonials';

  /// Quotes are capped so the file stays small and entries stay quotable.
  static const int maxQuoteLength = 180;

  /// Oldest entries are dropped beyond this cap.
  static const int maxStored = 50;

  /// Resolves against app services when available; null in bare test setups.
  static ValueTestimonialStore? instanceOrNull() => AppServices.isInitialized
      ? ValueTestimonialStore(AppServices.instance.prefs)
      : null;

  /// Newlines become spaces, whitespace collapses, and the result is capped
  /// at [maxQuoteLength]. Returns an empty string for blank input.
  static String sanitizeQuote(String raw) {
    final flattened = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (flattened.length <= maxQuoteLength) return flattened;
    return flattened.substring(0, maxQuoteLength).trim();
  }

  Future<void> add({
    required String quote,
    required String cardType,
    DateTime? now,
  }) async {
    final sanitized = sanitizeQuote(quote);
    if (sanitized.isEmpty) return;
    final entry = ValueTestimonial(
      quote: sanitized,
      cardType: cardType,
      createdAt: now ?? DateTime.now(),
    );
    await _prefs.updateMap(storageKey, (current) {
      final items = (current?['items'] is List)
          ? List<dynamic>.of(current!['items'] as List)
          : <dynamic>[];
      items.add(entry.toJson());
      while (items.length > maxStored) {
        items.removeAt(0);
      }
      return {'items': items};
    });
  }

  Future<List<ValueTestimonial>> all() async {
    final raw = await _prefs.readMap(storageKey);
    final items = raw?['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => ValueTestimonial.fromJson(Map<String, dynamic>.from(e)))
        .whereType<ValueTestimonial>()
        .toList();
  }
}
