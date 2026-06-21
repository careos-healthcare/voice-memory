import 'archive_copy_normalizer.dart';

/// Shared ArchiveMe log hygiene rules for CI tools and tests.
abstract class ArchiveLogHygiene {
  ArchiveLogHygiene._();

  static const archiveMePrefix = 'ARCHIVEME_';

  /// Forbidden glued tokens in any ARCHIVEME line (not only approved display copy).
  static const strictForbiddenSubstrings = [
    'alternativeconnector',
    'reliefconnector',
    'separateuseful',
    'usefulcheck',
    'reliefattempt',
    'aneed',
    'checkwas',
    'needstowork',
    'needs towork',
    'towork',
    'archivemesaved',
    'onemore',
    'to=alternativeconnector',
    'to=reliefconnector',
  ];

  /// Glued tokens that are only malformed inside user-facing quoted copy fields.
  static const displayCopyFieldMalformedTokens = [
    'mapready',
  ];

  static final strictMalformedTokens = [
    ...ArchiveCopyNormalizer.residualMalformedTokens
        .where((token) => !displayCopyFieldMalformedTokens.contains(token)),
    ...strictForbiddenSubstrings,
  ];

  /// Quoted display-copy payloads such as `phrase="..."`.
  static final displayCopyQuotedFieldPattern = RegExp(
    r'\b(?:phrase|title|subtitle|body|text|label)="([^"]*)"',
    caseSensitive: false,
  );

  /// Glued log keys such as `to=reliefconnector=because`.
  static final gluedLogKeyPattern = RegExp(
    r'to=\w+connector=',
    caseSensitive: false,
  );

  /// Node name glued to `connector=` without a space, e.g. `reliefconnector=because`.
  static final gluedConnectorKeyPattern = RegExp(
    r'\b(?:relief|alternative|behaviour|behavior|cost|trigger|thought)connector=',
    caseSensitive: false,
  );

  static bool isRelevantArchiveMeLog(String line) =>
      line.contains(archiveMePrefix);

  static List<String> scanLines(Iterable<String> lines) {
    final violations = <String>[];
    for (final line in lines) {
      if (!isRelevantArchiveMeLog(line)) continue;
      violations.addAll(scanLine(line));
    }
    return violations;
  }

  static List<String> scanLine(String line) {
    final violations = <String>[];
    final lower = line.toLowerCase();

    for (final token in strictMalformedTokens) {
      if (lower.contains(token)) {
        violations.add('token=$token line=$line');
      }
    }

    if (gluedLogKeyPattern.hasMatch(line)) {
      violations.add('pattern=to=<node>connector= line=$line');
    }

    if (gluedConnectorKeyPattern.hasMatch(line)) {
      violations.add('pattern=<node>connector= line=$line');
    }

    violations.addAll(_scanDisplayCopyQuotedFields(line));

    return violations;
  }

  static List<String> _scanDisplayCopyQuotedFields(String line) {
    final violations = <String>[];
    for (final match in displayCopyQuotedFieldPattern.allMatches(line)) {
      final value = match.group(1)?.toLowerCase() ?? '';
      for (final token in displayCopyFieldMalformedTokens) {
        if (value.contains(token)) {
          violations.add('token=$token field=display_copy line=$line');
        }
      }
    }
    return violations;
  }

  /// Canonical thought-map link display log line.
  static String thoughtMapLinkDisplayedLine({
    required String from,
    required String to,
    required String connector,
  }) {
    final safeFrom = from.trim();
    final safeTo = to.trim();
    final safeConnector = normalizedLogPhrase(connector);
    return 'ARCHIVEME_THOUGHT_MAP_LINK_DISPLAYED '
        'from=$safeFrom to=$safeTo connector=$safeConnector';
  }

  /// Normalize phrase text before it appears in archive logs.
  static String normalizedLogPhrase(String text) {
    return ArchiveCopyNormalizer.normalize(text.trim());
  }
}
