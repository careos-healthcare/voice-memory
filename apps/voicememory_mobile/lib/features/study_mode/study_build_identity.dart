/// Which binary a participant is actually running.
///
/// Values arrive from the build command as `--dart-define`, so a study report
/// can be tied to one commit without the app shipping any build tooling. Each
/// value is validated against a strict shape before it is used, so a mistyped
/// or hostile define degrades to [unknown] instead of becoming free text in a
/// study export.
final class StudyBuildIdentity {
  const StudyBuildIdentity({
    required this.declaredBuildSha,
    required this.declaredAppVersion,
    required this.declaredBuildNumber,
  });

  /// Reported whenever a value is missing or does not match its expected shape.
  static const unknown = 'unknown';

  /// Supplied by the release command, for example:
  ///
  /// ```
  /// flutter build ipa \
  ///   --dart-define=STUDY_BUILD_SHA=$(git rev-parse HEAD) \
  ///   --dart-define=STUDY_APP_VERSION=1.4.0 \
  ///   --dart-define=STUDY_BUILD_NUMBER=41
  /// ```
  static const fromBuildEnvironment = StudyBuildIdentity(
    declaredBuildSha: String.fromEnvironment(
      'STUDY_BUILD_SHA',
      defaultValue: unknown,
    ),
    declaredAppVersion: String.fromEnvironment(
      'STUDY_APP_VERSION',
      defaultValue: unknown,
    ),
    declaredBuildNumber: String.fromEnvironment(
      'STUDY_BUILD_NUMBER',
      defaultValue: unknown,
    ),
  );

  static final _shaShape = RegExp(r'^[0-9a-f]{7,40}$');
  static final _versionShape = RegExp(r'^[0-9]{1,4}(\.[0-9]{1,4}){1,3}$');
  static final _buildNumberShape = RegExp(r'^[0-9]{1,10}$');

  /// What the build command supplied, before any check.
  final String declaredBuildSha;
  final String declaredAppVersion;
  final String declaredBuildNumber;

  String get buildSha => _valid(declaredBuildSha, _shaShape);

  String get appVersion => _valid(declaredAppVersion, _versionShape);

  String get buildNumber => _valid(declaredBuildNumber, _buildNumberShape);

  /// First twelve characters of the commit, or [unknown].
  String get shortSha {
    final sha = buildSha;
    return sha == unknown ? unknown : sha.substring(0, 12);
  }

  /// True only when the running binary can be traced back to one commit.
  ///
  /// A study result from an unidentified build cannot be attributed to a
  /// revision, so the export records the flag rather than implying provenance
  /// it does not have.
  bool get isIdentified => buildSha != unknown;

  Map<String, Object?> toJson() => {
    'sha': buildSha,
    'short_sha': shortSha,
    'app_version': appVersion,
    'build_number': buildNumber,
    'identified': isIdentified ? 1 : 0,
  };

  static String _valid(String value, RegExp shape) {
    final trimmed = value.trim().toLowerCase();
    return shape.hasMatch(trimmed) ? trimmed : unknown;
  }
}
