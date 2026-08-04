import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/comparison_engine/domain/models/archive_moment_record.dart';
import 'package:voicememory_mobile/features/comparison_engine/domain/services/comparison_output_parser.dart';
import 'package:voicememory_mobile/features/comparison_engine/domain/services/local_text_comparison_engine.dart';
import 'package:voicememory_mobile/features/comparison_engine/domain/services/pattern_comparison_executor.dart';
import 'package:voicememory_mobile/features/comparison_engine/presentation/controllers/post_save_comparison_controller.dart';
import 'package:voicememory_mobile/features/pro_conversion_audit/pro_conversion_audit_copy.dart';

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

String _modelOutput({
  required String connection,
  required String presentQuote,
}) =>
    '''
Label: Clear repeat
Connection: $connection
Evidence:
- Past: "past words"
- Present: "$presentQuote"
What Changed: The wording changed.
''';

class _FakeModelApiClient implements ModelApiClient {
  _FakeModelApiClient({
    this.response = _sampleModelOutput,
    this.error,
    this.handler,
  });

  final String response;
  final Object? error;
  final Future<String> Function()? handler;
  String? lastSystemPrompt;
  String? lastUserPrompt;
  int callCount = 0;

  @override
  Future<String> evaluatePrompts({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    callCount += 1;
    lastSystemPrompt = systemPrompt;
    lastUserPrompt = userPrompt;
    if (error != null) throw error!;
    if (handler != null) return handler!();
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

class _ThrowingParser extends ComparisonOutputParser {
  const _ThrowingParser();

  @override
  ParsedComparisonOutput parse(String rawOutput) {
    throw const FormatException('parser failed');
  }
}

class _RecordingComparisonLogger implements ComparisonExecutionLogger {
  final List<ComparisonExecutionEvent> events = [];
  final List<Object> errors = [];

  @override
  void log(ComparisonExecutionEvent event, {Object? error}) {
    events.add(event);
    if (error != null) errors.add(error);
  }
}

void main() {
  group('PostSaveComparisonController', () {
    test(
      'processMomentComparison runs model pipeline into success state',
      () async {
        final api = _FakeModelApiClient();
        final prefs = _FakePreferenceStore();
        final logger = _RecordingComparisonLogger();
        final controller = PostSaveComparisonController(
          apiClient: api,
          prefs: prefs,
          logger: logger,
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
        expect(api.callCount, 1);
        expect(logger.events, [
          ComparisonExecutionEvent.parserSuccess,
          ComparisonExecutionEvent.validationSuccess,
          ComparisonExecutionEvent.remoteSuccess,
        ]);
      },
    );

    test(
      'processMomentComparison falls back to local engine when remote fails',
      () async {
        final api = _FakeModelApiClient(error: Exception('network down'));
        final logger = _RecordingComparisonLogger();
        final controller = PostSaveComparisonController(
          apiClient: api,
          prefs: _FakePreferenceStore(),
          logger: logger,
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
        expect(api.callCount, 1);
        expect(logger.events, [
          ComparisonExecutionEvent.remoteFailure,
          ComparisonExecutionEvent.fallbackInvoked,
          ComparisonExecutionEvent.fallbackValidationSuccess,
          ComparisonExecutionEvent.fallbackSuccess,
        ]);
      },
    );

    test('processMomentComparison falls back after remote timeout', () async {
      final api = _FakeModelApiClient(
        handler: () => Completer<String>().future,
      );
      final logger = _RecordingComparisonLogger();
      final controller = PostSaveComparisonController(
        apiClient: api,
        prefs: _FakePreferenceStore(),
        logger: logger,
        remoteTimeout: const Duration(milliseconds: 1),
      );

      await controller.processMomentComparison(
        currentMoment: _moment(
          'current',
          'I said yes again before checking whether I had enough capacity.',
        ),
        historicalMoments: [
          _moment(
            'past',
            'I agreed to help again even though I was already tired.',
          ),
        ],
        isProUser: false,
      );

      expect(controller.uiState, isA<ComparisonSuccess>());
      expect(api.callCount, 1);
      expect(logger.events, [
        ComparisonExecutionEvent.remoteFailure,
        ComparisonExecutionEvent.fallbackInvoked,
        ComparisonExecutionEvent.fallbackValidationSuccess,
        ComparisonExecutionEvent.fallbackSuccess,
      ]);
      expect(logger.errors.single, isA<TimeoutException>());
    });

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

    test('processMomentComparison falls back when parser throws', () async {
      final logger = _RecordingComparisonLogger();
      final controller = PostSaveComparisonController(
        apiClient: _FakeModelApiClient(),
        prefs: _FakePreferenceStore(),
        executor: const PatternComparisonExecutor(parser: _ThrowingParser()),
        logger: logger,
      );

      await controller.processMomentComparison(
        currentMoment: _moment(
          'current',
          'I said yes again before checking whether I had enough capacity.',
        ),
        historicalMoments: [
          _moment(
            'past',
            'I agreed to help again even though I was already tired.',
          ),
        ],
        isProUser: false,
      );

      expect(controller.uiState, isA<ComparisonSuccess>());
      expect(logger.events, [
        ComparisonExecutionEvent.remoteFailure,
        ComparisonExecutionEvent.fallbackInvoked,
        ComparisonExecutionEvent.fallbackValidationSuccess,
        ComparisonExecutionEvent.fallbackSuccess,
      ]);
      expect(logger.errors.single, isA<FormatException>());
    });

    test(
      'processMomentComparison surfaces failure when remote and local fail',
      () async {
        final logger = _RecordingComparisonLogger();
        final controller = PostSaveComparisonController(
          apiClient: _FakeModelApiClient(error: Exception('network down')),
          prefs: _FakePreferenceStore(),
          localEngine: _ThrowingLocalEngine(),
          logger: logger,
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
        expect(logger.events, [
          ComparisonExecutionEvent.remoteFailure,
          ComparisonExecutionEvent.fallbackInvoked,
          ComparisonExecutionEvent.fallbackFailure,
        ]);
        expect(logger.errors, hasLength(2));
      },
    );

    test(
      'newer operation prevents stale remote result from updating UI',
      () async {
        final responses = <Completer<String>>[
          Completer<String>(),
          Completer<String>(),
        ];
        var responseIndex = 0;
        final api = _FakeModelApiClient(
          handler: () => responses[responseIndex++].future,
        );
        final controller = PostSaveComparisonController(
          apiClient: api,
          prefs: _FakePreferenceStore(),
        );
        var listenerCalls = 0;
        controller.addListener(() => listenerCalls += 1);

        final olderOperation = controller.processMomentComparison(
          currentMoment: _moment('older-current', 'older current words'),
          historicalMoments: [_moment('past', 'past words')],
          isProUser: false,
        );
        final newerOperation = controller.processMomentComparison(
          currentMoment: _moment('newer-current', 'newer current words'),
          historicalMoments: [_moment('past', 'past words')],
          isProUser: false,
        );

        responses[1].complete(
          _modelOutput(
            connection: 'The newer operation completed.',
            presentQuote: 'newer current words',
          ),
        );
        await newerOperation;

        responses[0].complete(
          _modelOutput(
            connection: 'The stale operation completed.',
            presentQuote: 'older current words',
          ),
        );
        await olderOperation;

        final success = controller.uiState as ComparisonSuccess;
        expect(
          success.viewState.connectionText,
          'The newer operation completed.',
        );
        expect(api.callCount, 2);
        expect(listenerCalls, 1);
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
