import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/comparison_engine/domain/mappers/archive_moment_record_mapper.dart';
import 'package:voicememory_mobile/features/comparison_engine/infrastructure/journal_comparison_model_api_client.dart';
import 'package:voicememory_mobile/features/comparison_engine/presentation/controllers/post_save_comparison_controller.dart';
import 'package:voicememory_mobile/features/retention/second_session_signal_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';

JournalEntry _voiceEntry({
  required String id,
  required String transcript,
  required DateTime createdAt,
}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt,
      transcript: transcript,
      durationSeconds: 24,
      reflection: const Reflection(
        mood: 'thoughtful',
        emotionalIntensity: 2,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
      syncStatus: SyncStatus.localOnly,
    );

class _FakePreferenceStore implements PreferenceStore {
  @override
  bool getHasDismissedProPrompt() => false;

  @override
  Future<void> setHasDismissedProPrompt(bool value) async {}
}

void main() {
  group('JournalComparisonModelApiClient', () {
    test('evaluatePrompts returns manifest block for grounded repeat entries', () async {
      final entries = [
        _voiceEntry(
          id: 'e1',
          transcript:
              'I said yes again even though I was already tired from work today.',
          createdAt: DateTime(2026, 6, 11, 12),
        ),
        _voiceEntry(
          id: 'e2',
          transcript:
              'I took responsibility again before asking anyone for help today.',
          createdAt: DateTime(2026, 6, 12, 12),
        ),
      ];
      expect(
        const SecondSessionSignalEngine().hasGroundedRepeatMatch(entries),
        isTrue,
      );

      final raw = await JournalComparisonModelApiClient(entries: entries)
          .evaluatePrompts(systemPrompt: 'system', userPrompt: 'user');

      expect(raw, contains('Label:'));
      expect(raw, contains('Evidence:'));
      expect(raw, contains('What Changed:'));
    });

    test('controller end-to-end with local journal client reaches success', () async {
      final entries = [
        _voiceEntry(
          id: 'e1',
          transcript:
              'I said yes again even though I was already tired from work today.',
          createdAt: DateTime(2026, 6, 11, 12),
        ),
        _voiceEntry(
          id: 'e2',
          transcript:
              'I took responsibility again before asking anyone for help today.',
          createdAt: DateTime(2026, 6, 12, 12),
        ),
      ];
      final moments = ArchiveMomentRecordMapper.fromJournalEntries(entries);
      final controller = PostSaveComparisonController(
        apiClient: JournalComparisonModelApiClient(entries: entries),
        prefs: _FakePreferenceStore(),
      );

      await controller.processMomentComparison(
        currentMoment: moments.last,
        historicalMoments: moments.sublist(0, moments.length - 1),
        isProUser: false,
      );

      expect(controller.uiState, isA<ComparisonSuccess>());
      final success = controller.uiState as ComparisonSuccess;
      expect(success.viewState.pastQuote, isNotEmpty);
      expect(success.viewState.currentQuote, isNotEmpty);
    });
  });
}
