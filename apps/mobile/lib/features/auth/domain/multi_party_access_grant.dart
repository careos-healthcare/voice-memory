/// Role of a third party granted read access to archive evidence.
enum MultiPartyAccessRole {
  caregiver,
  observer,
  coach;

  String get label => switch (this) {
        MultiPartyAccessRole.caregiver => 'Caregiver',
        MultiPartyAccessRole.observer => 'Observer',
        MultiPartyAccessRole.coach => 'Coach',
      };

  static MultiPartyAccessRole? fromWire(String? raw) => switch (raw) {
        'caregiver' || 'caregiver_monitoring' => MultiPartyAccessRole.caregiver,
        'observer' => MultiPartyAccessRole.observer,
        'coach' || 'coach_client' => MultiPartyAccessRole.coach,
        _ => null,
      };

  String get wireValue => switch (this) {
        MultiPartyAccessRole.caregiver => 'caregiver',
        MultiPartyAccessRole.observer => 'observer',
        MultiPartyAccessRole.coach => 'coach',
      };
}

/// Active HMAC-signed consent grant for multi-party archive access.
class MultiPartyAccessGrant {
  const MultiPartyAccessGrant({
    required this.grantId,
    required this.partyId,
    required this.role,
    required this.grantedAt,
    this.expiresAt,
    this.isCurrentSession = false,
  });

  final String grantId;
  final String partyId;
  final MultiPartyAccessRole role;
  final DateTime grantedAt;
  final DateTime? expiresAt;
  final bool isCurrentSession;

  String get displayLabel => partyId.trim().isEmpty ? role.label : partyId;

  bool isExpiredAt(DateTime clock) =>
      expiresAt != null && !clock.isBefore(expiresAt!);
}
