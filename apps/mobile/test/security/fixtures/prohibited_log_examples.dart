/// Deliberately prohibited log examples for validator tests only.
/// Marker: PRIVACY_LOG_VALIDATOR_FIXTURE — excluded from production scans.
abstract final class ProhibitedLogFixtureExamples {
  ProhibitedLogFixtureExamples._();

  static const examples = [
    // PRIVACY_LOG_VALIDATOR_FIXTURE
    "debugPrint('audioPath=/secret/path.m4a');",
    "debugPrint('entry_id=secret-entry');",
    // PRIVACY_LOG_VALIDATOR_FIXTURE
  ];
}
