import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// Flags the public beta profile is allowed to name.
///
/// Sourced from `bool.fromEnvironment` in `*feature_flags*.dart`,
/// [V1CapabilityRegistry], and the dark-mode gate. A string define such as
/// the clinical sandbox token is not a launch flag.
void main() {
  final packageRoot = Directory.current;
  final repoRoot = packageRoot.parent.parent;
  final profileFile = File(
    '${repoRoot.path}/config/launch_profiles/beta_1.json',
  );

  test('beta_1.json matches the compile-time flags and leaves them off', () {
    expect(profileFile.existsSync(), isTrue, reason: profileFile.path);

    final decoded = jsonDecode(profileFile.readAsStringSync());
    expect(decoded, isA<Map<String, dynamic>>());
    final profile = Map<String, dynamic>.from(decoded as Map);

    final referenced = _boolDefinesIn(_flagSources(packageRoot));

    final missing = referenced.difference(profile.keys.toSet());
    final unknown = profile.keys.toSet().difference(referenced);
    expect(missing, isEmpty, reason: 'referenced in code but missing from beta_1.json');
    expect(unknown, isEmpty, reason: 'present in beta_1.json but not a known flag');

    for (final entry in profile.entries) {
      expect(entry.value, isFalse, reason: '${entry.key} must stay false');
    }
  });
}

Set<String> _boolDefinesIn(Iterable<File> files) {
  final pattern = RegExp(
    r"""bool\.fromEnvironment\(\s*'([^']+)'""",
  );
  final names = <String>{};
  for (final file in files) {
    names.addAll(pattern.allMatches(file.readAsStringSync()).map((m) => m.group(1)!));
  }
  return names;
}

List<File> _flagSources(Directory packageRoot) {
  final lib = Directory('${packageRoot.path}/lib');
  final files = lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) {
        final path = file.path.replaceAll('\\', '/');
        if (!path.endsWith('.dart')) return false;
        if (path.contains('/retired_sprawl/')) return false;
        return path.contains('feature_flag') ||
            path.endsWith('/v1_capability_registry.dart') ||
            path.endsWith('/app_palette.dart') ||
            path.endsWith('/post_save_stability_gate.dart');
      })
      .toList();
  expect(files, isNotEmpty);
  return files;
}
