import 'package:archiveme_mobile/core/di/network_providers.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/insights_conversation_api_client.dart';
import 'package:archiveme_mobile/features/insights/pattern_exploration_conversation_notifier.dart';
import 'package:archiveme_mobile/features/insights/pattern_exploration_conversation_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordedConversationCall {
  const _RecordedConversationCall({
    required this.conversationHistory,
    required this.message,
  });

  final List<InsightsConversationTurn> conversationHistory;
  final String message;
}

class _FakeInsightsConversationApiClient
    implements InsightsConversationApiClient {
  final List<_RecordedConversationCall> calls = [];

  @override
  Future<ApiResult<InsightsConversationReply>> sendConversationMessage({
    required List<InsightsConversationTurn> conversationHistory,
    required String message,
    NetworkCancelToken? cancelToken,
  }) {
    calls.add(
      _RecordedConversationCall(
        conversationHistory: List<InsightsConversationTurn>.of(
          conversationHistory,
        ),
        message: message,
      ),
    );
    return Future.value(
      const ApiSuccess(
        InsightsConversationReply(
          reply: 'assistant reply',
          citedEntryIds: [],
          groundedness: 'grounded',
        ),
      ),
    );
  }
}

void main() {
  late _FakeInsightsConversationApiClient fakeApi;
  late ProviderContainer container;
  late PatternExplorationConversationNotifier notifier;

  setUp(() {
    fakeApi = _FakeInsightsConversationApiClient();
    container = ProviderContainer(
      overrides: [
        insightsConversationApiClientProvider.overrideWithValue(fakeApi),
      ],
    );
    notifier = container.read(patternExplorationConversationProvider.notifier);
  });

  tearDown(() {
    container.dispose();
  });

  test('reset() clears messages, isSending, and error after a prior turn',
      () async {
    await notifier.sendMessage('first');

    final beforeReset = container.read(patternExplorationConversationProvider);
    expect(beforeReset.messages, hasLength(2));
    expect(beforeReset.messages.first.content, 'first');
    expect(beforeReset.messages.last.content, 'assistant reply');
    expect(beforeReset.isSending, isFalse);

    notifier.reset();

    final afterReset = container.read(patternExplorationConversationProvider);
    expect(afterReset.messages, isEmpty);
    expect(afterReset.isSending, isFalse);
    expect(afterReset.errorMessage, isNull);
  });

  test(
    'reset() then sendMessage sends empty conversationHistory',
    () async {
      await notifier.sendMessage('first');
      expect(fakeApi.calls, hasLength(1));
      expect(fakeApi.calls.single.conversationHistory, isEmpty);
      expect(fakeApi.calls.single.message, 'first');

      notifier.reset();
      await notifier.sendMessage('hello');

      expect(fakeApi.calls, hasLength(2));
      final last = fakeApi.calls.last;
      expect(last.message, 'hello');
      expect(last.conversationHistory, isEmpty);
      expect(
        last.conversationHistory.map((turn) => turn.content),
        isNot(contains('first')),
      );
    },
  );
}
