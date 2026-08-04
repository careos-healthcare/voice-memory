import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const kRecordScreenSourcePath = 'lib/screens/record_screen.dart';

const _recordScreenPartPaths = [
  'lib/features/recording/recording_state_controller.dart',
  'lib/features/recording/recording_audio_visualizer.dart',
  'lib/features/recording/recording_transcription_view.dart',
  'lib/features/recording/recording_metadata_sheet.dart',
];

String readRecordScreenSource([String path = kRecordScreenSourcePath]) {
  final source = StringBuffer(File(path).readAsStringSync());
  if (path == kRecordScreenSourcePath) {
    for (final partPath in _recordScreenPartPaths) {
      source
        ..writeln()
        ..write(File(partPath).readAsStringSync());
    }
  }
  return source.toString();
}

int recordScreenExactMarker(String source, String needle, {String? reason}) {
  final index = source.indexOf(needle);
  expect(index, greaterThan(-1), reason: reason ?? 'marker not found: $needle');
  return index;
}

/// Resolves the first `if (` for a show-flag, even when the condition spans lines
/// or the flag is not the first predicate in the condition.
int recordScreenShowCondition(
  String source,
  String conditionVariable, {
  String? reason,
}) {
  final escaped = RegExp.escape(conditionVariable);
  final patterns = [
    RegExp(r'if\s*\(\s*' + escaped + r'\b'),
    RegExp(r'if\s*\((?:[^)]|\n)*?\b' + escaped + r'\b'),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(source);
    if (match != null) {
      return match.start;
    }
  }
  expect(
    null,
    isNotNull,
    reason: reason ?? 'show condition not found: $conditionVariable',
  );
  return -1;
}

int resolveRecordScreenLayoutMarker(String source, String marker) {
  if (marker.startsWith('show')) {
    return recordScreenShowCondition(source, marker);
  }
  return recordScreenExactMarker(source, marker);
}

void expectRecordScreenLayoutBefore({
  required String earlier,
  required String later,
  String sourcePath = kRecordScreenSourcePath,
}) {
  final source = readRecordScreenSource(sourcePath);
  final earlierIndex = resolveRecordScreenLayoutMarker(source, earlier);
  final laterIndex = resolveRecordScreenLayoutMarker(source, later);
  expect(
    earlierIndex,
    lessThan(laterIndex),
    reason: 'expected $earlier before $later',
  );
}

void expectRecordScreenLayoutOrder(
  List<String> markers, {
  String sourcePath = kRecordScreenSourcePath,
}) {
  final source = readRecordScreenSource(sourcePath);
  final indices = markers
      .map((marker) => resolveRecordScreenLayoutMarker(source, marker))
      .toList();
  for (var i = 0; i < indices.length - 1; i++) {
    expect(
      indices[i],
      lessThan(indices[i + 1]),
      reason: 'expected layout order $markers',
    );
  }
}
