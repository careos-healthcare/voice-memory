import 'package:archiveme_mobile/features/post_save_insight/selected_signal_model.dart';
import 'package:archiveme_mobile/features/post_save_insight/selected_signal_store.dart';
import 'package:archiveme_mobile/services/app_services.dart';

abstract class SelectedSignalCoordinator {
  SelectedSignalCoordinator._();

  static SelectedSignalStore _store() => SelectedSignalStore.instance();

  static Future<void> save({
    required String title,
    required String categoryId,
    required String strengthLabel,
    required String nextPrompt,
    String? entryId,
    String? whySuggested,
    List<String> evidenceChips = const [],
    String? mightMean,
    String? wouldConfirm,
    String? wouldContradict,
    String? evidenceUsed,
    String? readId,
  }) async {
    if (!AppServices.isInitialized) return;
    await _store().save(
      SelectedSignalRecord(
        id: '${DateTime.now().millisecondsSinceEpoch}_$categoryId',
        title: title,
        categoryId: categoryId,
        strengthLabel: strengthLabel,
        nextPrompt: nextPrompt,
        savedAt: DateTime.now(),
        entryId: entryId,
        whySuggested: whySuggested,
        evidenceChips: evidenceChips,
        mightMean: mightMean,
        wouldConfirm: wouldConfirm,
        wouldContradict: wouldContradict,
        evidenceUsed: evidenceUsed,
        readId: readId,
      ),
    );
  }

  static Future<SelectedSignalRecord?> loadCurrent() async {
    if (!AppServices.isInitialized) return null;
    return _store().loadCurrent();
  }

  static Future<List<SelectedSignalRecord>> loadHistory() async {
    if (!AppServices.isInitialized) return const [];
    return _store().loadHistory();
  }
}