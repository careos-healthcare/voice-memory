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

  test('mobile and beta profiles are the same active set', () {
    final mobile = File('${packageRoot.path}/config/launch_profile.json');
    expect(mobile.existsSync(), isTrue, reason: mobile.path);
    expect(profileFile.existsSync(), isTrue, reason: profileFile.path);
    final mobileProfile = Map<String, dynamic>.from(
      jsonDecode(mobile.readAsStringSync()) as Map,
    );
    final betaProfile = Map<String, dynamic>.from(
      jsonDecode(profileFile.readAsStringSync()) as Map,
    );
    expect(mobileProfile, betaProfile);
    expect(mobileProfile['THOUGHTPRINT_DARK_MODE_READY'], isFalse);
  });

  test(
    'beta profile matches compile-time flags and enables the reviewed set',
    () {
      final decoded = jsonDecode(profileFile.readAsStringSync());
      expect(decoded, isA<Map<String, dynamic>>());
      final profile = Map<String, dynamic>.from(decoded as Map);

      final referenced = _boolDefinesIn(_flagSources(packageRoot));

      final missing = referenced.difference(profile.keys.toSet());
      final unknown = profile.keys.toSet().difference(referenced);
      expect(
        missing,
        isEmpty,
        reason: 'referenced in code but missing from beta_1.json',
      );
      expect(
        unknown,
        isEmpty,
        reason: 'present in beta_1.json but not a known flag',
      );

      for (final entry in profile.entries) {
        if (_enabledBetaFlags.contains(entry.key)) {
          expect(
            entry.value,
            isTrue,
            reason: '${entry.key} is on for this beta',
          );
        } else {
          expect(entry.value, isFalse, reason: '${entry.key} stays off');
        }
      }
    },
  );
}

const _enabledBetaFlags = {
  'VOICEMEMORY_ENABLE_ENCRYPTED_BACKUP',
  'VOICEMEMORY_ENABLE_FIRST_SAVE_QUOTE_BACK',
  'VOICEMEMORY_ENABLE_ONBOARDING_IMPORT_FIRST',
  'VOICEMEMORY_ENABLE_GENTLE_REMINDERS',
  'VOICEMEMORY_ENABLE_E2EE_SYNC',
  'VOICEMEMORY_ENABLE_NATIVE_QUICK_CAPTURE',
  'VOICEMEMORY_ENABLE_LIVE_DRAFT_TRANSCRIPT',
  'VOICEMEMORY_ENABLE_LOCATION',
  'VOICEMEMORY_ENABLE_TREND_PATTERN_SUMMARY',
  'VOICEMEMORY_ENABLE_HISTORY_VIEWS',
  'VOICEMEMORY_ENABLE_PATTERN_EXPLORATION',
  'VOICEMEMORY_ENABLE_PHOTO_ATTACHMENTS',
  'VOICEMEMORY_ENABLE_VOICE_MEMOS_IMPORT',
  'POST_SAVE_FOLLOW_UP',
  'WEEKLY_RECAP_BANNER',
};

Set<String> _boolDefinesIn(Iterable<File> files) {
  final pattern = RegExp(
    r"""bool\.fromEnvironment\(\s*'([^']+)'""",
  );
  final names = <String>{};
  for (final file in files) {
    names.addAll(
      pattern.allMatches(file.readAsStringSync()).map((m) => m.group(1)!),
    );
  }
  return names;
}

List<File> _flagSources(Directory packageRoot) {
  final lib = Directory('${packageRoot.path}/lib');
  final files = lib.listSync(recursive: true).whereType<File>().where((file) {
    final path = file.path.replaceAll('\\', '/');
    if (!path.endsWith('.dart')) return false;
    if (path.contains('/retired_sprawl/')) return false;
    return path.contains('feature_flag') ||
        path.endsWith('/v1_capability_registry.dart') ||
        path.endsWith('/app_palette.dart') ||
        path.endsWith('/post_save_stability_gate.dart');
  }).toList();
  expect(files, isNotEmpty);
  return files;
}
