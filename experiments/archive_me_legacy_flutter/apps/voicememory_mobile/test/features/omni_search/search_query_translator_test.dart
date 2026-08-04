import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/omni_search/search_query_translator.dart';

void main() {
  final translator = LocalSearchQueryTranslator(
    clock: () => DateTime.utc(2026, 7, 27, 12),
  );

  test('resolves last summer to deterministic UTC boundaries', () async {
    final intent = await translator.translate(
      'Show project overwhelm from last summer',
    );

    expect(intent.timeframe!.start, DateTime.utc(2025, 6));
    expect(intent.timeframe!.end, DateTime.utc(2025, 9));
  });

  test('resolves two weeks ago and extracts local filters', () async {
    final intent = await translator.translate(
      'When did I feel stressed about "Project Atlas" two weeks ago?',
    );

    expect(intent.timeframe!.start, DateTime.utc(2026, 7, 13));
    expect(intent.timeframe!.end, DateTime.utc(2026, 7, 27));
    expect(intent.requiredEntities, ['Project Atlas']);
    expect(intent.nodeTypes.map((type) => type.name), contains('emotion'));
  });
}
