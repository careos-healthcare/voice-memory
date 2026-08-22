import 'package:archiveme_mobile/features/comparison_engine/domain/models/archive_moment_record.dart';
import 'package:archiveme_mobile/features/comparison_engine/domain/services/local_text_comparison_engine.dart';
import 'package:archiveme_mobile/features/comparison_engine/presentation/controllers/post_save_comparison_controller.dart';
import 'package:archiveme_mobile/features/pro_conversion_audit/pro_conversion_audit_copy.dart';
import 'package:flutter_test/flutter_test.dart';

const _sampleModelOutput = '''
---
Label: Clear repeat
Connection: This may connect to saying yes before checking capacity.
Evidence:
- Past: "I said yes again before I checked my calendar."
- Present: "I said yes at work without thinking."
What Changed: The repeat showed up around work again with similar wording.
---
''';

class _FakeModelApiClient implements ModelApiClient {
  _FakeModelApiClient({this.response = _sampleModelOutput, this.error});

  final String response;
  final Object? error;
  String? lastSystemPrompt;
  String? lastUserPrompt;

  @override
  Future<String> evaluatePrompts({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    lastSystemPrompt = systemPrompt;
    lastUserPrompt = userPrompt;
    if (error != null) throw error!;
    return response;
  }
}

class _FakePreferenceStore implements PreferenceStore {
  bool dismissed = false;

  @override
  bool getHasDismissedProPrompt() => dismissed;

  @override
  Future<void> setHasDismissedProPrompt(bool value) async {
    dismissed = value;
  }
}

ArchiveMomentRecord _moment(String id, String words) => ArchiveMomentRecord(
  id: id,
  createdAt: DateTime.utc(2026, 6, 10),
  savedWords: words,
);

class _ThrowingLocalEngine extends LocalTextComparisonEngine {
  const _ThrowingLocalEngine();

  @override
  LocalTextComparisonResult buildFromRawTextHistory({
    required ArchiveMomentRecord current,
    required List<ArchiveMomentRecord> history,
  }) {
    throw StateError('local comparison failed');
  }
}

void main() {
  group('PostSaveComparisonController', () {
    test(
      'processMomentComparison runs model pipeline into success state',
      () async {
        final api = _FakeModelApiClient();
        final prefs = _FakePreferenceStore();
        final controller = PostSaveComparisonController(
          apiClient: api,
          prefs: prefs,
        );

        await controller.processMomentComparison(
          currentMoment: _moment('current', 'said yes at work'),
          historicalMoments: [_moment('1', 'first yes')],
          isProUser: false,
        );

        expect(controller.uiState, isA<ComparisonSuccess>());
        final success = controller.uiState as ComparisonSuccess;
        expect(success.viewState.state, PatternState.clearRepeat);
        expect(success.viewState.showProTrailPrompt, isTrue);
        expect(
          success.viewState.conversionHeadline,
          ProConversionAuditCopy.proTrailCanonical,
        );
        expect(api.lastSystemPrompt, isNotEmpty);
        expect(api.lastUserPrompt, contains('said yes at work'));
      },
    );

    test(
      'processMomentComparison falls back to local engine when remote fails',
      () async {
        final controller = PostSaveComparisonController(
          apiClient: _FakeModelApiClient(error: Exception('network down')),
          prefs: _FakePreferenceStore(),
        );

        await controller.processMomentComparison(
          currentMoment: ArchiveMomentRecord(
            id: 'e2',
            createdAt: DateTime.utc(2026, 6, 12, 12),
            savedWords:
                'I took responsibility again before asking anyone for help today.',
          ),
          historicalMoments: [
            ArchiveMomentRecord(
              id: 'e1',
              createdAt: DateTime.utc(2026, 6, 11, 12),
              savedWords:
                  'I said yes again even though I was already tired from work today.',
            ),
          ],
          isProUser: false,
        );

        expect(controller.uiState, isA<ComparisonSuccess>());
        final success = controller.uiState as ComparisonSuccess;
        expect(success.viewState.pastQuote, isNotEmpty);
        expect(success.viewState.currentQuote, isNotEmpty);
        expect(
          success.viewState.whatChangedText,
          startsWith('Evaluated locally.'),
        );
      },
    );

    test(
      'processMomentComparison falls back when remote returns empty payload',
      () async {
        final controller = PostSaveComparisonController(
          apiClient: _FakeModelApiClient(response: '   '),
          prefs: _FakePreferenceStore(),
        );

        await controller.processMomentComparison(
          currentMoment: ArchiveMomentRecord(
            id: 'e2',
            createdAt: DateTime.utc(2026, 6, 12, 12),
            savedWords:
                'I took responsibility again before asking anyone for help today.',
          ),
          historicalMoments: [
            ArchiveMomentRecord(
              id: 'e1',
              createdAt: DateTime.utc(2026, 6, 11, 12),
              savedWords:
                  'I said yes again even though I was already tired from work today.',
            ),
          ],
          isProUser: false,
        );

        expect(controller.uiState, isA<ComparisonSuccess>());
        expect(
          (controller.uiState as ComparisonSuccess).viewState.whatChangedText,
          startsWith('Evaluated locally.'),
        );
      },
    );

    test(
      'processMomentComparison falls back when remote response is unparseable',
      () async {
        final controller = PostSaveComparisonController(
          apiClient: _FakeModelApiClient(
            response: 'Label: Clear repeat\nConnection: Something repeated.',
          ),
          prefs: _FakePreferenceStore(),
        );

        await controller.processMomentComparison(
          currentMoment: ArchiveMomentRecord(
            id: 'e2',
            createdAt: DateTime.utc(2026, 6, 12, 12),
            savedWords:
                'I took responsibility again before asking anyone for help today.',
          ),
          historicalMoments: [
            ArchiveMomentRecord(
              id: 'e1',
              createdAt: DateTime.utc(2026, 6, 11, 12),
              savedWords:
                  'I said yes again even though I was already tired from work today.',
            ),
          ],
          isProUser: false,
        );

        expect(controller.uiState, isA<ComparisonSuccess>());
        final success = controller.uiState as ComparisonSuccess;
        expect(success.viewState.pastQuote, isNotEmpty);
        expect(success.viewState.currentQuote, isNotEmpty);
        expect(
          success.viewState.whatChangedText,
          startsWith('Evaluated locally.'),
        );
      },
    );

    test(
      'processMomentComparison surfaces failure when remote and local fail',
      () async {
        final controller = PostSaveComparisonController(
          apiClient: _FakeModelApiClient(error: Exception('network down')),
          prefs: _FakePreferenceStore(),
          localEngine: const _ThrowingLocalEngine(),
        );

        await controller.processMomentComparison(
          currentMoment: _moment('current', 'said yes at work'),
          historicalMoments: [_moment('1', 'first yes')],
          isProUser: false,
        );

        expect(controller.uiState, isA<ComparisonFailure>());
        expect(
          (controller.uiState as ComparisonFailure).errorMessage,
          'Unable to compute connection analysis.',
        );
      },
    );

    test('dismissProPrompt persists dismissal and hides pro banner', () async {
      final prefs = _FakePreferenceStore();
      final controller = PostSaveComparisonController(
        apiClient: _FakeModelApiClient(),
        prefs: prefs,
      );

      await controller.processMomentComparison(
        currentMoment: _moment('current', 'said yes at work'),
        historicalMoments: [_moment('1', 'first yes')],
        isProUser: false,
      );

      await controller.dismissProPrompt();

      expect(prefs.dismissed, isTrue);
      final success = controller.uiState as ComparisonSuccess;
      expect(success.viewState.showProTrailPrompt, isFalse);
      expect(success.viewState.conversionHeadline, isNull);
    });
  });
}