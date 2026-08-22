import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Directories whose Dart sources render consumer-visible text.
const _consumerScanRoots = [
  'lib/widgets',
  'lib/screens',
  'lib/onboarding',
  'lib/product',
  'lib/billing',
  'lib/services/capture_save_messages.dart',
  'lib/services/capture_pipeline_service.dart',
  'lib/features/insights',
  'lib/design/empty_archive_experience.dart',
  'lib/design/warm_archive_copy.dart',
];

/// Technical identifiers — class names, bundle IDs, API hosts, dart-defines.
const _allowlistedPaths = {
  'lib/theme/voicememory_typography.dart',
  'lib/theme/voicememory_colors.dart',
  'lib/theme/voicememory_cards.dart',
  'lib/config/app_config.dart',
  'lib/features/search/voice_memory_search.dart',
  'lib/dev/screenshot_registry.dart',
  'lib/product/consumer_copy_guard.dart',
};

const _legacyBrandPatterns = <String, String>{
  'VoiceMemory': 'VoiceMemory brand text',
  'Voice Memory': 'Voice Memory phrase',
  'voice memory': 'voice memory phrase',
};

const _staleFakePatterns = <String>[
  'I want freedom, but I keep choosing more responsibility.',
  'I talk about achievement more than satisfaction.',
  'A pattern that used to drive me is starting to fade.',
];

const _grepForbiddenPatterns = <String>[
  'VoiceMemory notices',
  'VoiceMemory connects',
  'Today VoiceMemory',
  'VoiceMemory Pro',
  'Cloud processing pending',
  'Cloud sync is unavailable',
  'I want freedom, but I keep choosing more responsibility.',
  'I talk about achievement more than satisfaction.',
  'A pattern that used to drive me is starting to fade.',
  'Record short moments. VoiceMemory notices',
  'VoiceMemory connects what you mention often',
];

const _grepAllowlistedLibPaths = {'lib/product/consumer_copy_guard.dart'};

const _cloudCopyPatterns = <String>[
  'Cloud processing pending',
  'Cloud sync unavailable',
  'Cloud sync is unavailable',
  'Cloud analysis pending',
  'Never synced',
];

List<String> _consumerDartFiles() {
  final files = <String>[];
  for (final root in _consumerScanRoots) {
    final entity = FileSystemEntity.typeSync(root);
    if (entity == FileSystemEntityType.file) {
      files.add(root);
      continue;
    }
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    for (final f in dir.listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final relative = f.path.replaceFirst('${Directory.current.path}/', '');
      if (_allowlistedPaths.contains(relative)) continue;
      files.add(relative);
    }
  }
  return files.toSet().toList()..sort();
}

List<String> _violationsInStringLiterals(String source, String path) {
  final violations = <String>[];
  final literalPattern = RegExp("'([^']*)'");

  for (final line in source.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.startsWith('import ')) continue;
    if (trimmed.startsWith('//')) continue;

    for (final match in literalPattern.allMatches(line)) {
      final literal = match.group(1)!;
      for (final entry in _legacyBrandPatterns.entries) {
        if (RegExp(entry.key).hasMatch(literal)) {
          violations.add("${entry.value} in $path: '$literal'");
        }
      }
    }
  }
  return violations;
}

void main() {
  final consumerFiles = _consumerDartFiles();

  for (final path in consumerFiles) {
    test('$path has no VoiceMemory brand text in string literals', () {
      final source = File(path).readAsStringSync();
      final violations = _violationsInStringLiterals(source, path);
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  }

  test(
    'allowlisted technical paths may keep internal voicememory identifiers',
    () {
      for (final path in _allowlistedPaths) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    },
  );

  test('patterns empty view source has no stale fake statements', () {
    final source = File(
      'lib/widgets/patterns/patterns_empty_view.dart',
    ).readAsStringSync();
    for (final stale in _staleFakePatterns) {
      expect(source, isNot(contains(stale)));
    }
  });

  test('consumer copy has no stale fake pattern examples', () {
    final source = File('lib/product/consumer_ui_copy.dart').readAsStringSync();
    for (final stale in _staleFakePatterns) {
      expect(source, isNot(contains(stale)));
    }
  });

  test('capture messages avoid confusing cloud copy', () {
    final source = File(
      'lib/services/capture_save_messages.dart',
    ).readAsStringSync();
    for (final cloud in _cloudCopyPatterns) {
      expect(source, isNot(contains(cloud)));
    }
    expect(source, contains('ConsumerUiCopy.savedPrivatelyOnDevice'));
  });

  test('lib/ has no forbidden consumer leak strings from QA grep', () {
    final violations = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceFirst('${Directory.current.path}/', '');
      if (_grepAllowlistedLibPaths.contains(path)) continue;

      final source = entity.readAsStringSync();
      for (final pattern in _grepForbiddenPatterns) {
        if (source.contains(pattern)) {
          violations.add('"$pattern" in $path');
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}