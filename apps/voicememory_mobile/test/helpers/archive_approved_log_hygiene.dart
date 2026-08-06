import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_reactivity/archive_log_hygiene.dart';

import 'package:voicememory_mobile/features/archive_reactivity/archive_copy_normalizer.dart';

/// Hard audit for approved archive display-copy logs.
void assertNoMalformedApprovedArchiveLogs(List<String> logs) {
  final tokens = ArchiveCopyNormalizer.residualMalformedTokens;

  final approvedLines = logs.where((line) {
    final isDisplayCopyApproved =
        line.contains('ARCHIVEME_PATTERN_DISPLAY_COPY_CHECK') &&
        line.contains('decision=approved');
    final isMinimumBarApproved =
        line.contains('ARCHIVEME_COPY_MINIMUM_BAR') &&
        line.contains('approved=true');
    return isDisplayCopyApproved || isMinimumBarApproved;
  });

  for (final line in approvedLines) {
    final lower = line.toLowerCase();
    for (final token in tokens) {
      expect(
        lower,
        isNot(contains(token)),
        reason: 'malformed token "$token" in approved archive log: $line',
      );
    }
  }
}

/// Hard audit for all relevant ArchiveMe logs.
void assertNoMalformedArchiveMeLogs(List<String> logs) {
  final violations = ArchiveLogHygiene.scanLines(logs);
  expect(
    violations,
    isEmpty,
    reason: 'malformed ArchiveMe logs:\n${violations.join('\n')}',
  );
}

List<String> approvedArchiveDisplayCopyLogs(List<String> logs) => logs
    .where(
      (line) =>
          line.contains('ARCHIVEME_PATTERN_DISPLAY_COPY_CHECK') &&
          line.contains('decision=approved'),
    )
    .toList();

List<String> approvedArchiveMinimumBarLogs(List<String> logs) => logs
    .where(
      (line) =>
          line.contains('ARCHIVEME_COPY_MINIMUM_BAR') &&
          line.contains('approved=true'),
    )
    .toList();
