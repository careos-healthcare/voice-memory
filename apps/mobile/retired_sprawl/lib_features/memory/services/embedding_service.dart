import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

/// Token ids for one MiniLM forward pass.
class MiniLmEncoding {
  const MiniLmEncoding({
    required this.inputIds,
    required this.attentionMask,
    required this.tokenTypeIds,
  });

  factory MiniLmEncoding.fromMap(Map<String, Object?> map) {
    return MiniLmEncoding(
      inputIds: _ints(map['inputIds']),
      attentionMask: _ints(map['attentionMask']),
      tokenTypeIds: _ints(map['tokenTypeIds']),
    );
  }

  static List<int> _ints(Object? value) {
    if (value is! List) return const [];
    return [for (final item in value) (item as num).toInt()];
  }

  final List<int> inputIds;
  final List<int> attentionMask;
  final List<int> tokenTypeIds;

  Map<String, List<int>> toMap() => {
    'inputIds': inputIds,
    'attentionMask': attentionMask,
    'tokenTypeIds': tokenTypeIds,
  };
}

/// BERT WordPiece used by all-MiniLM-L6-v2.
class WordPieceTokenizer {
  WordPieceTokenizer._(this._vocab);

  final Map<String, int> _vocab;

  static const maxSequenceLength = 128;
  static const maxWordChars = 100;
  static const clsToken = '[CLS]';
  static const sepToken = '[SEP]';
  static const unkToken = '[UNK]';

  static final _punctuation = RegExp(
    r'''[!"#$%&'()*+,\-./:;<=>?@\[\\\]^_`{|}~]''',
  );

  factory WordPieceTokenizer.fromVocabText(String vocab) {
    final lines = vocab.split('\n');
    if (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    final tokens = <String, int>{};
    for (var i = 0; i < lines.length; i++) {
      final token = lines[i].replaceAll('\r', '');
      if (token.isEmpty) continue;
      tokens[token] = i;
    }
    return WordPieceTokenizer._(tokens);
  }

  static Future<WordPieceTokenizer> loadAsset({
    String assetPath = EmbeddingService.vocabAsset,
  }) async {
    final vocab = await rootBundle.loadString(assetPath);
    return WordPieceTokenizer.fromVocabText(vocab);
  }

  /// Encodes [texts] with [vocab]. Safe to run inside an isolate.
  static List<Map<String, List<int>>> encodeAll(
    String vocab,
    List<String> texts,
  ) {
    final tokenizer = WordPieceTokenizer.fromVocabText(vocab);
    return [for (final text in texts) tokenizer.encode(text).toMap()];
  }

  MiniLmEncoding encode(String text) {
    final ids = <int>[_id(clsToken)];
    for (final word in _basicTokens(text)) {
      if (ids.length >= maxSequenceLength - 1) break;
      for (final piece in _wordPiece(word)) {
        if (ids.length >= maxSequenceLength - 1) break;
        ids.add(piece);
      }
    }
    ids.add(_id(sepToken));
    return MiniLmEncoding(
      inputIds: ids,
      attentionMask: List<int>.filled(ids.length, 1),
      tokenTypeIds: List<int>.filled(ids.length, 0),
    );
  }

  List<String> _basicTokens(String text) {
    final tokens = <String>[];
    final word = StringBuffer();
    void flush() {
      if (word.isEmpty) return;
      tokens.add(word.toString());
      word.clear();
    }

    for (final rune in text.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      if (RegExp(r'\s').hasMatch(char)) {
        flush();
      } else if (_punctuation.hasMatch(char)) {
        flush();
        tokens.add(char);
      } else {
        word.write(char);
      }
    }
    flush();
    return tokens;
  }

  List<int> _wordPiece(String word) {
    if (word.length > maxWordChars) return [_id(unkToken)];
    final pieces = <int>[];
    var start = 0;
    while (start < word.length) {
      var end = word.length;
      int? piece;
      while (start < end) {
        var slice = word.substring(start, end);
        if (start > 0) slice = '##$slice';
        final id = _vocab[slice];
        if (id != null) {
          piece = id;
          break;
        }
        end -= 1;
      }
      if (piece == null) return [_id(unkToken)];
      pieces.add(piece);
      start = end;
    }
    return pieces;
  }

  int _id(String token) => _vocab[token] ?? 0;
}

/// Runs the bundled all-MiniLM-L6-v2 graph and returns a 384-d unit vector.
class EmbeddingService {
  EmbeddingService._(this._session, this._tokenizer, this._outputName);

  final OrtSession _session;
  final WordPieceTokenizer _tokenizer;
  final String _outputName;

  static const modelAsset = 'assets/models/all-MiniLM-L6-v2.onnx';
  static const vocabAsset = 'assets/models/vocab.txt';
  static const dimensions = 384;
  static const outputName = 'last_hidden_state';

  static Future<String> loadVocabText() {
    return rootBundle.loadString(vocabAsset);
  }

  static EmbeddingService? _instance;
  static Future<EmbeddingService>? _opening;

  static Future<EmbeddingService> open() {
    final existing = _instance;
    if (existing != null) return Future<EmbeddingService>.value(existing);
    return _opening ??= _load();
  }

  static Future<EmbeddingService> _load() async {
    final tokenizer = await WordPieceTokenizer.loadAsset();
    final runtime = OnnxRuntime();
    final session = await runtime.createSessionFromAsset(modelAsset);
    final output = session.outputNames.contains(outputName)
        ? outputName
        : session.outputNames.first;
    final service = EmbeddingService._(session, tokenizer, output);
    _instance = service;
    return service;
  }

  Future<List<double>> embed(String text) {
    return embedEncoding(_tokenizer.encode(text));
  }

  Future<List<double>> embedEncoding(MiniLmEncoding encoding) async {
    final seq = encoding.inputIds.length;
    final ids = await OrtValue.fromList(
      Int64List.fromList(encoding.inputIds),
      [1, seq],
    );
    final mask = await OrtValue.fromList(
      Int64List.fromList(encoding.attentionMask),
      [1, seq],
    );
    final types = await OrtValue.fromList(
      Int64List.fromList(encoding.tokenTypeIds),
      [1, seq],
    );
    try {
      final outputs = await _session.run({
        'input_ids': ids,
        'attention_mask': mask,
        'token_type_ids': types,
      });
      final output = outputs[_outputName];
      if (output == null) {
        throw StateError('ONNX output "$_outputName" was missing');
      }
      try {
        final raw = await output.asFlattenedList();
        final hidden = [
          for (final value in raw) (value as num).toDouble(),
        ];
        return l2Normalize(
          meanPool(
            hidden: hidden,
            attentionMask: encoding.attentionMask,
            dimensions: dimensions,
          ),
        );
      } finally {
        await output.dispose();
      }
    } finally {
      await ids.dispose();
      await mask.dispose();
      await types.dispose();
    }
  }

  /// Mean of token states, weighted by [attentionMask].
  static List<double> meanPool({
    required List<double> hidden,
    required List<int> attentionMask,
    required int dimensions,
  }) {
    final seq = attentionMask.length;
    if (hidden.length < seq * dimensions) {
      throw StateError(
        'hidden width ${hidden.length} is shorter than $seq x $dimensions',
      );
    }
    final sum = List<double>.filled(dimensions, 0);
    var counted = 0;
    for (var token = 0; token < seq; token++) {
      if (attentionMask[token] == 0) continue;
      counted += 1;
      final offset = token * dimensions;
      for (var dim = 0; dim < dimensions; dim++) {
        sum[dim] += hidden[offset + dim];
      }
    }
    if (counted == 0) return sum;
    for (var dim = 0; dim < dimensions; dim++) {
      sum[dim] /= counted;
    }
    return sum;
  }

  static List<double> l2Normalize(List<double> vector) {
    var norm = 0.0;
    for (final value in vector) {
      norm += value * value;
    }
    norm = math.sqrt(norm);
    if (norm == 0) return vector;
    return [for (final value in vector) value / norm];
  }
}
