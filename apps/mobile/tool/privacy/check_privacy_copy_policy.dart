// Scans every user-facing privacy/trust copy source for unsafe promises.
//
// Discovery, not a hand-maintained list: this walks `lib/` and asks
// `PrivacyCopyPolicy.isConsumerPrivacySource` about each Dart file, so a new
// copy file is covered the moment it lands. `test/privacy_copy_policy_test.dart`
// imports the same functions, so the gate and the test can never disagree.
//
// Usage (from apps/mobile):
//   dart run tool/privacy/check_privacy_copy_policy.dart              # gate
//   dart run tool/privacy/check_privacy_copy_policy.dart --report
//   dart run tool/privacy/check_privacy_copy_policy.dart --write-baseline
//
// Exit codes: 0 clean, 1 new violation or stale baseline entry, 2 bad usage.
//
// The baseline exists only because widening the scan surfaced pre-existing
// violations. Anything in it is debt, not permission, and the gate fails if a
// baselined line stops being produced, so the file cannot rot.
import 'dart:io';

import 'package:archiveme_mobile/security/privacy_copy_policy.dart';

const String libRoot = 'lib';
const String privacyCopyBaselinePath =
    'tool/privacy/privacy_copy_policy_baseline.txt';

/// Depth cap so a pathological symlink graph cannot hang the walk.
const int _maxDepth = 24;

const String _liveSectionHeader = '# --- live lib/ sources ---';
const String _retiredSectionHeader =
    '# --- reached through lib/features/* symlinks into retired_sprawl/ ---';

void main(List<String> args) {
  final report = args.contains('--report');
  final writeBaseline = args.contains('--write-baseline');
  final unknown = args.where(
    (a) => a != '--report' && a != '--write-baseline',
  );
  if (unknown.isNotEmpty) {
    stderr.writeln('unknown arguments: ${unknown.join(' ')}');
    exit(2);
  }

  if (!Directory(libRoot).existsSync()) {
    stderr.writeln('run this from apps/mobile — no $libRoot directory here');
    exit(2);
  }

  final sources = discoverPrivacyCopySources();
  final violations = PrivacyCopyPolicy.scanSources(sources)..sort();

  if (writeBaseline) {
    File(
      privacyCopyBaselinePath,
    ).writeAsStringSync(_renderBaseline(violations));
    stdout.writeln(
      'wrote ${violations.length} baselined violations to '
      '$privacyCopyBaselinePath',
    );
    return;
  }

  final baseline = readPrivacyCopyBaseline();
  final unbaselined = newPrivacyCopyViolations(violations, baseline);
  final stale = stalePrivacyCopyBaselineEntries(violations, baseline);
  final uncovered = uncoveredRequiredSources();

  final retired = violations.where(isRetiredSprawlPath).length;
  stdout.writeln(
    'scanned ${sources.length} discovered privacy/trust sources — '
    '${violations.length} violations '
    '(${violations.length - retired} in live lib/, $retired in retired_sprawl) '
    '— ${unbaselined.length} new',
  );

  if (report) _printGrouped(violations, baseline);

  if (unbaselined.isNotEmpty) {
    stderr.writeln('\nNEW privacy copy violations (fix these):');
    for (final violation in unbaselined) {
      stderr.writeln('  $violation');
    }
  }
  if (stale.isNotEmpty) {
    stderr.writeln(
      '\nStale baseline entries — these were fixed, so delete them from '
      '$privacyCopyBaselinePath:',
    );
    for (final violation in stale) {
      stderr.writeln('  $violation');
    }
  }
  if (uncovered.isNotEmpty) {
    stderr.writeln('\nRequired sources missing or no longer discovered:');
    for (final path in uncovered) {
      stderr.writeln('  $path');
    }
  }

  if (unbaselined.isNotEmpty || stale.isNotEmpty || uncovered.isNotEmpty) {
    exit(1);
  }
  stdout.writeln('OK — no new privacy copy violations');
}

/// Every discovered source, keyed by its path relative to `apps/mobile`.
///
/// Symlinked feature directories are followed because they hold copy that is
/// still rendered (for example `lib/features/privacy/`), so retiring a
/// directory does not quietly remove it from the scan.
Map<String, String> discoverPrivacyCopySources() {
  final sources = <String, String>{};
  final visitedDirectories = <String>{};
  var frontier = <Directory>[Directory(libRoot)];

  for (var depth = 0; depth < _maxDepth && frontier.isNotEmpty; depth++) {
    final next = <Directory>[];
    for (final directory in frontier) {
      final resolved = _resolveDirectory(directory.path);
      if (resolved == null || !visitedDirectories.add(resolved)) continue;

      for (final entry in _listSorted(directory)) {
        if (entry is Directory) {
          next.add(entry);
          continue;
        }
        if (entry is! File) continue;
        if (!PrivacyCopyPolicy.isConsumerPrivacySource(entry.path)) continue;
        try {
          sources[entry.path] = entry.readAsStringSync();
        } on FileSystemException {
          // A dangling symlink is not copy; the analyzer reports it instead.
        }
      }
    }
    frontier = next;
  }

  return sources;
}

Set<String> readPrivacyCopyBaseline() {
  final file = File(privacyCopyBaselinePath);
  if (!file.existsSync()) return const {};
  return file
      .readAsLinesSync()
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && !line.startsWith('#'))
      .toSet();
}

/// Violations that are not accounted for by [baseline] — the failure set.
List<String> newPrivacyCopyViolations(
  List<String> violations,
  Set<String> baseline,
) => violations.where((v) => !baseline.contains(v)).toList()..sort();

/// Baseline entries whose file still exists but no longer offends, so the
/// baseline must shrink. This is what forces the burn-down.
List<String> stalePrivacyCopyBaselineEntries(
  List<String> violations,
  Set<String> baseline,
) {
  final produced = violations.toSet();
  return baseline
      .where((v) => !produced.contains(v) && File(pathOf(v)).existsSync())
      .toList()
    ..sort();
}

/// Explicitly listed sources that are missing or fell out of discovery.
List<String> uncoveredRequiredSources() => PrivacyCopyPolicy
    .consumerPrivacySources
    .where(
      (path) =>
          !PrivacyCopyPolicy.isConsumerPrivacySource(path) ||
          !File(path).existsSync(),
    )
    .toList();

/// The file path prefix of a `path: reason in "literal"` violation line.
String pathOf(String violation) => violation.split(':').first;

/// Whether a violation line points at code reached through a `lib/features/*`
/// symlink into `retired_sprawl/`, which the analyzer also excludes.
bool isRetiredSprawlPath(String violation) {
  try {
    return File(
      pathOf(violation),
    ).resolveSymbolicLinksSync().contains('/retired_sprawl/');
  } on FileSystemException {
    return false;
  }
}

String? _resolveDirectory(String path) {
  try {
    return Directory(path).resolveSymbolicLinksSync();
  } on FileSystemException {
    return null;
  }
}

List<FileSystemEntity> _listSorted(Directory directory) {
  try {
    return directory.listSync()..sort((a, b) => a.path.compareTo(b.path));
  } on FileSystemException {
    return const [];
  }
}

String _renderBaseline(List<String> violations) {
  final live = violations.where((v) => !isRetiredSprawlPath(v)).toList();
  final retired = violations.where(isRetiredSprawlPath).toList();

  final buffer = StringBuffer()
    ..writeln('# Pre-existing privacy copy violations, surfaced when the scan')
    ..writeln('# widened from a hand-maintained list to discovery over lib/.')
    ..writeln('#')
    ..writeln('# This is debt, not permission. Fix a line, delete it here —')
    ..writeln('# the gate fails on a stale entry as well as on a new one.')
    ..writeln('#')
    ..writeln('# Regenerate with:')
    ..writeln(
      '#   dart run tool/privacy/check_privacy_copy_policy.dart '
      '--write-baseline',
    )
    ..writeln('#')
    ..writeln(_liveSectionHeader);
  live.forEach(buffer.writeln);
  buffer
    ..writeln()
    ..writeln(_retiredSectionHeader);
  retired.forEach(buffer.writeln);
  return buffer.toString();
}

void _printGrouped(List<String> violations, Set<String> baseline) {
  final byFile = <String, List<String>>{};
  for (final violation in violations) {
    byFile.putIfAbsent(pathOf(violation), () => []).add(violation);
  }
  final paths = byFile.keys.toList()..sort();
  for (final path in paths) {
    final entries = byFile[path]!;
    final flags = [
      if (entries.any((e) => !baseline.contains(e))) 'NEW',
      if (isRetiredSprawlPath(entries.first)) 'retired',
    ];
    final prefix = flags.isEmpty ? '' : '[${flags.join(' ')}] ';
    stdout.writeln('\n$prefix$path (${entries.length})');
    for (final entry in entries) {
      stdout.writeln('  - ${entry.substring(path.length + 2)}');
    }
  }
}
