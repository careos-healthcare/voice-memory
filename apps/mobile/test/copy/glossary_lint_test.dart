import 'dart:io';

import 'package:archiveme_mobile/core/copy/glossary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/repo_file_scan.dart';

final _literal = RegExp(r"'([^'\\]*)'");
final _interpolation = RegExp(r'\$[A-Za-z_]\w*');

bool _skipLine(String line, {required bool inBanCatalogue}) {
  if (inBanCatalogue) return true;
  final trimmed = line.trim();
  if (trimmed.startsWith('//')) return true;
  if (trimmed.startsWith('import ')) return true;
  if (line.contains('bannedSynonyms')) return true;
  if (line.contains('synonymOf')) return true;
  if (line.contains('inventoryBeforeRewrite')) return true;
  return false;
}

void main() {
  test('record CTA is the single word Record', () {
    expect(Glossary.recordCta, 'Record');
  });

  test('V1-visible strings do not use banned synonyms', () {
    final violations = <String>[];
    for (final relative in Glossary.v1VisibleCopyFiles) {
      final source = resolveRepoScanFile(relative).readAsStringSync();
      var inBanCatalogue = false;
      for (final line in source.split('\n')) {
        if (line.contains('bannedPrimaryUiTerms')) inBanCatalogue = true;
        if (inBanCatalogue && line.contains('];')) {
          inBanCatalogue = false;
          continue;
        }
        if (_skipLine(line, inBanCatalogue: inBanCatalogue)) continue;
        for (final match in _literal.allMatches(line)) {
          final visible = match.group(1)!.replaceAll(_interpolation, '');
          final lower = visible.toLowerCase();
          for (final banned in Glossary.bannedSynonyms) {
            final pattern = RegExp('\\b${RegExp.escape(banned)}s?\\b');
            if (pattern.hasMatch(lower)) {
              violations.add('$relative: "$banned" in "$visible"');
            }
          }
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('glossary files exist on disk', () {
    for (final relative in Glossary.v1VisibleCopyFiles) {
      expect(resolveRepoScanFile(relative).existsSync(), isTrue, reason: relative);
    }
  });
}
