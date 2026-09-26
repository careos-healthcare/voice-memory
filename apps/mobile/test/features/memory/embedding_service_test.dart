import 'package:archiveme_mobile/features/memory/services/embedding_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const vocab = '[PAD]\n'
      '[UNK]\n'
      '[CLS]\n'
      '[SEP]\n'
      'the\n'
      'river\n'
      'un\n'
      '##want\n'
      '##ed\n'
      ',\n';

  test('wordpiece wraps a sentence with cls and sep', () {
    final tokenizer = WordPieceTokenizer.fromVocabText(vocab);
    final encoded = tokenizer.encode('The river, unwanted');

    expect(encoded.inputIds.first, 2);
    expect(encoded.inputIds.last, 3);
    expect(encoded.inputIds, containsAll([4, 5, 6, 7, 8]));
    expect(encoded.attentionMask, everyElement(1));
    expect(encoded.tokenTypeIds, everyElement(0));
    expect(encoded.inputIds.length, encoded.attentionMask.length);
  });

  test('mean pooling uses the attention mask and then unit length', () {
    final pooled = EmbeddingService.meanPool(
      hidden: const [3, 0, 9, 12],
      attentionMask: const [1, 0],
      dimensions: 2,
    );
    expect(pooled, [3, 0]);
    final unit = EmbeddingService.l2Normalize(const [3, 4]);
    expect(unit[0], closeTo(0.6, 1e-9));
    expect(unit[1], closeTo(0.8, 1e-9));
  });
}
