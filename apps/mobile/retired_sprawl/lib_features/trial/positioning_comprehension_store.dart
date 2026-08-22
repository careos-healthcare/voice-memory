import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/features/trial/positioning_comprehension_model.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

class PositioningComprehensionStore {
  PositioningComprehensionStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _responsesKey = 'positioning_comprehension_responses';
  static const _askedKey = 'positioning_comprehension_asked';

  static PositioningComprehensionStore instance() =>
      PositioningComprehensionStore(AppServices.instance.prefs);

  Future<bool> hasAnswered() async {
    final all = await loadAll();
    return all.isNotEmpty;
  }

  Future<bool> wasAskedThisSession() async {
    return await _prefs.readBool(_askedKey) == true;
  }

  Future<void> markAsked() async {
    await _prefs.writeBool(_askedKey, true);
    ActivationTracker.trackPositioningComprehensionAsked();
  }

  Future<void> recordAnswer(
    PositioningComprehensionAnswer answer, {
    String? followUp,
  }) async {
    final all = await loadAll();
    final next = [
      PositioningComprehensionResponse(
        answer: answer,
        recordedAt: DateTime.now(),
        followUp: followUp,
      ),
      ...all,
    ].take(20).toList();
    await _prefs.writeMap(_responsesKey, {
      'items': next.map((e) => e.toJson()).toList(),
    });
    ActivationTracker.trackPositioningComprehensionAnswered(answer);
  }

  Future<List<PositioningComprehensionResponse>> loadAll() async {
    final raw = await _prefs.readMap(_responsesKey);
    if (raw == null || raw.isEmpty) return const [];
    final list = raw['items'];
    if (list is! List) return const [];
    return list
        .map(
          (e) => PositioningComprehensionResponse.fromJson(
            e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map),
          ),
        )
        .whereType<PositioningComprehensionResponse>()
        .toList();
  }

  Future<void> clear() async {
    await _prefs.writeMap(_responsesKey, {'items': []});
    await _prefs.writeBool(_askedKey, false);
  }

  Future<PositioningComprehensionSummary> summary({
    required int askedCount,
    required int answeredCount,
    required int archiveMemoryCount,
    required int journalCount,
    required int chatCount,
    required int notSureCount,
  }) async {
    return PositioningComprehensionSummary(
      askedCount: askedCount,
      answeredCount: answeredCount,
      archiveMemoryCount: archiveMemoryCount,
      journalCount: journalCount,
      chatCount: chatCount,
      notSureCount: notSureCount,
    );
  }
}