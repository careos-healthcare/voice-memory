import '../../services/app_services.dart';
import '../activation/activation_tracker.dart';

/// User rating of first-insight sharpness — trial/debug only.
enum FirstInsightSpecificityRating {
  yesSpecific,
  tooGeneric,
  wrongAngle,
}

extension FirstInsightSpecificityRatingIds on FirstInsightSpecificityRating {
  String get id => name;
}

/// Persists first-use sharpness check responses.
abstract final class FirstInsightSpecificityStore {
  FirstInsightSpecificityStore._();

  static const _key = 'firstInsightSpecificity';

  static Future<void> save(FirstInsightSpecificityRating rating) async {
    if (!AppServices.isInitialized) return;
    final prefs = AppServices.instance.prefs;
    final raw = await prefs.readMap(_key);
    final list = raw?['ratings'];
    final items =
        list is List ? List<Map<String, dynamic>>.from(list) : <Map<String, dynamic>>[];
    items.add({
      'rating': rating.id,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    await prefs.writeMap(_key, {'ratings': items});
    ActivationTracker.trackFirstInsightSpecificityRating(rating);
  }

  static Future<FirstInsightSpecificityRating?> latest() async {
    if (!AppServices.isInitialized) return null;
    final raw = await AppServices.instance.prefs.readMap(_key);
    final list = raw?['ratings'];
    if (list is! List || list.isEmpty) return null;
    final last = list.last;
    if (last is! Map) return null;
    final id = last['rating'] as String?;
    if (id == null) return null;
    return FirstInsightSpecificityRating.values.firstWhere(
      (e) => e.id == id,
      orElse: () => FirstInsightSpecificityRating.tooGeneric,
    );
  }

  static Future<bool> wedgeInterpretationMatched() async {
    final rating = await latest();
    return rating == FirstInsightSpecificityRating.yesSpecific;
  }

  static Future<bool> firstPromptUsed() async {
    if (!AppServices.isInitialized) return false;
    final raw = await AppServices.instance.prefs.readMap('firstPromptUsed');
    return raw?['used'] == true;
  }

  static Future<void> markFirstPromptUsed() async {
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeMap('firstPromptUsed', {
      'used': true,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    ActivationTracker.trackFirstPromptUsed();
  }
}
