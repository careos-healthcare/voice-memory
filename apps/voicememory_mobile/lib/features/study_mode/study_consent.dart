/// Where a participant stands with respect to the product test.
enum StudyConsentState {
  /// Never asked, or asked and declined. Nothing is collected.
  never,

  /// Actively taking part under the current policy.
  granted,

  /// Took part and left. Collection has stopped and the collected data is gone.
  revoked,

  /// Agreed to an older policy. Treated as not taking part until re-asked.
  lapsed,
}

/// The exact wording a participant agrees to, and the version it belongs to.
///
/// The version is part of the stored record. When the policy text changes the
/// version changes with it, every existing agreement becomes
/// [StudyConsentState.lapsed], and collection stops until the participant is
/// asked again under the new wording.
abstract final class StudyConsentPolicy {
  static const version = 'study_consent_v1_2026_08_01';

  static const title = 'Join the product test';

  /// Every statement must be shown, in this order, before consent is taken.
  static const statements = <String>[
    'This is the normal app. Nothing about how it works changes if you take '
        'part.',
    'We collect counts only: how many times you open the app, start a '
        'recording, finish one, and look at a result.',
    'We never collect your recordings, the words you saved, or anything you '
        'wrote. None of it leaves this device as part of this test.',
    'What you send us is tied to this account on this device only. It can '
        'never contain anyone else.',
    'You can leave at any time. Leaving stops collection and deletes the '
        'counts and notes collected on this device.',
  ];

  /// Shown on the control that ends participation.
  static const leaveStatement =
      'Leave the product test. Collection stops now and the counts and notes '
      'collected on this device are deleted.';

  /// A short run identifier handed out by whoever is running the test.
  ///
  /// Deliberately not a name, email, or anything a participant would type in
  /// prose: it must be a short upper-case token so it cannot carry free text.
  static final participantCodeShape = RegExp(r'^[A-Z0-9][A-Z0-9-]{1,11}$');

  static bool isValidParticipantCode(String code) =>
      participantCodeShape.hasMatch(code);
}

/// A participant's standing agreement, scoped to exactly one archive.
final class StudyConsentRecord {
  const StudyConsentRecord({
    required this.archiveId,
    required this.policyVersion,
    required this.participantCode,
    required this.grantedAt,
    required this.acknowledgedStatementCount,
    this.revokedAt,
    this.schemaVersion = currentSchemaVersion,
  });

  static const currentSchemaVersion = 1;

  final String archiveId;
  final String policyVersion;
  final String participantCode;
  final DateTime grantedAt;
  final DateTime? revokedAt;
  final int acknowledgedStatementCount;
  final int schemaVersion;

  StudyConsentState get state {
    if (revokedAt != null) return StudyConsentState.revoked;
    if (policyVersion != StudyConsentPolicy.version) {
      return StudyConsentState.lapsed;
    }
    if (acknowledgedStatementCount < StudyConsentPolicy.statements.length) {
      return StudyConsentState.never;
    }
    return StudyConsentState.granted;
  }

  bool get isActive => state == StudyConsentState.granted;

  StudyConsentRecord revoked(DateTime at) => StudyConsentRecord(
    archiveId: archiveId,
    policyVersion: policyVersion,
    participantCode: participantCode,
    grantedAt: grantedAt,
    acknowledgedStatementCount: acknowledgedStatementCount,
    revokedAt: at.toUtc(),
    schemaVersion: schemaVersion,
  );

  Map<String, Object?> toJson() => {
    'archiveId': archiveId,
    'policyVersion': policyVersion,
    'participantCode': participantCode,
    'grantedAt': grantedAt.toUtc().toIso8601String(),
    'revokedAt': revokedAt?.toUtc().toIso8601String(),
    'acknowledgedStatementCount': acknowledgedStatementCount,
    'schemaVersion': schemaVersion,
  };

  static StudyConsentRecord? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final archiveId = json['archiveId']?.toString().trim() ?? '';
    final policyVersion = json['policyVersion']?.toString().trim() ?? '';
    final participantCode = json['participantCode']?.toString().trim() ?? '';
    final grantedAt = DateTime.tryParse(json['grantedAt']?.toString() ?? '');
    final revokedRaw = json['revokedAt']?.toString();
    final revokedAt = revokedRaw == null ? null : DateTime.tryParse(revokedRaw);
    final acknowledged = (json['acknowledgedStatementCount'] as num?)?.toInt();
    final schemaVersion = (json['schemaVersion'] as num?)?.toInt();

    if (archiveId.isEmpty ||
        policyVersion.isEmpty ||
        grantedAt == null ||
        acknowledged == null ||
        schemaVersion != currentSchemaVersion ||
        !StudyConsentPolicy.isValidParticipantCode(participantCode) ||
        (revokedRaw != null && revokedAt == null)) {
      return null;
    }

    return StudyConsentRecord(
      archiveId: archiveId,
      policyVersion: policyVersion,
      participantCode: participantCode,
      grantedAt: grantedAt.toUtc(),
      revokedAt: revokedAt?.toUtc(),
      acknowledgedStatementCount: acknowledged,
      schemaVersion: schemaVersion!,
    );
  }
}
