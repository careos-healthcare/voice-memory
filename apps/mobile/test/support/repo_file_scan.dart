import 'dart:io';

/// Resolves monorepo-relative scan paths from the mobile package root.
///
/// Tests often reference `packages/...` paths as if they lived under
/// `apps/mobile/`, but workspace packages live at the repo root.
File resolveRepoScanFile(String relativePath) {
  final candidates = [
    File(relativePath),
    if (relativePath.startsWith('lib/')) File('apps/mobile/$relativePath'),
    if (relativePath.startsWith('packages/')) File('../../$relativePath'),
    if (relativePath.startsWith('apps/')) File('../../$relativePath'),
  ];
  for (final file in candidates) {
    if (file.existsSync()) return file;
  }
  return File(relativePath);
}

String resolveRepoScanPath(String relativePath) =>
    resolveRepoScanFile(relativePath).path;

Iterable<String> existingRepoScanPaths(Iterable<String> paths) sync* {
  for (final path in paths) {
    if (resolveRepoScanFile(path).existsSync()) yield path;
  }
}