import 'dart:convert';
import 'package:archiveme_mobile/core/utils/app_logger.dart';

/// Persona link between a client archive owner and a professional/caregiver.
enum RelationshipType {
  professional,
  caregiver,
}

extension RelationshipTypeWire on RelationshipType {
  String get wireValue => switch (this) {
        RelationshipType.professional => 'professional',
        RelationshipType.caregiver => 'caregiver',
      };

  static RelationshipType? fromWire(String? raw) => switch (raw) {
        'professional' => RelationshipType.professional,
        'caregiver' => RelationshipType.caregiver,
        _ => null,
      };
}

enum ConsentStatus {
  pending,
  active,
  revoked,
}

extension ConsentStatusWire on ConsentStatus {
  String get wireValue => switch (this) {
        ConsentStatus.pending => 'pending',
        ConsentStatus.active => 'active',
        ConsentStatus.revoked => 'revoked',
      };

  static ConsentStatus? fromWire(String? raw) => switch (raw) {
        'pending' => ConsentStatus.pending,
        'active' => ConsentStatus.active,
        'revoked' => ConsentStatus.revoked,
        _ => null,
      };
}

class UserRelationship {
  const UserRelationship({
    required this.id,
    required this.clientId,
    required this.professionalId,
    required this.relationshipType,
    required this.consentStatus,
    required this.agreedScope,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserRelationship.fromJson(Map<String, dynamic> json) {
    return UserRelationship(
      id: json['id']?.toString() ?? '',
      clientId: json['clientId']?.toString() ?? '',
      professionalId: json['professionalId']?.toString() ?? '',
      relationshipType: RelationshipTypeWire.fromWire(
            json['relationshipType']?.toString(),
          ) ??
          RelationshipType.professional,
      consentStatus: ConsentStatusWire.fromWire(
            json['consentStatus']?.toString(),
          ) ??
          ConsentStatus.pending,
      agreedScope: _parseScope(json['agreedScope']),
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now().toUtc(),
      updatedAt: _parseDate(json['updatedAt']) ?? DateTime.now().toUtc(),
    );
  }

  factory UserRelationship.fromMap(Map<String, Object?> map) {
    return UserRelationship(
      id: map['id']?.toString() ?? '',
      clientId: map['client_id']?.toString() ?? '',
      professionalId: map['professional_id']?.toString() ?? '',
      relationshipType: RelationshipTypeWire.fromWire(
            map['relationship_type']?.toString(),
          ) ??
          RelationshipType.professional,
      consentStatus: ConsentStatusWire.fromWire(
            map['consent_status']?.toString(),
          ) ??
          ConsentStatus.pending,
      agreedScope: _parseScope(map['agreed_scope']),
      createdAt: _parseEpoch(map['created_at']) ?? DateTime.now().toUtc(),
      updatedAt: _parseEpoch(map['updated_at']) ?? DateTime.now().toUtc(),
    );
  }

  final String id;
  final String clientId;
  final String professionalId;
  final RelationshipType relationshipType;
  final ConsentStatus consentStatus;
  final Map<String, dynamic> agreedScope;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive => consentStatus == ConsentStatus.active;

  UserRelationship copyWith({
    String? id,
    String? clientId,
    String? professionalId,
    RelationshipType? relationshipType,
    ConsentStatus? consentStatus,
    Map<String, dynamic>? agreedScope,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserRelationship(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      professionalId: professionalId ?? this.professionalId,
      relationshipType: relationshipType ?? this.relationshipType,
      consentStatus: consentStatus ?? this.consentStatus,
      agreedScope: agreedScope ?? this.agreedScope,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'clientId': clientId,
        'professionalId': professionalId,
        'relationshipType': relationshipType.wireValue,
        'consentStatus': consentStatus.wireValue,
        'agreedScope': agreedScope,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  Map<String, Object?> toMap() => {
        'id': id,
        'client_id': clientId,
        'professional_id': professionalId,
        'relationship_type': relationshipType.wireValue,
        'consent_status': consentStatus.wireValue,
        'agreed_scope': jsonEncode(agreedScope),
        'created_at': createdAt.toUtc().millisecondsSinceEpoch,
        'updated_at': updatedAt.toUtc().millisecondsSinceEpoch,
      };
}

Map<String, dynamic> _parseScope(Object? raw) {
  if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
  if (raw is Map) {
    return raw.map((key, value) => MapEntry('$key', value));
  }
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', value));
      }
    } catch (e, stackTrace) {
      AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
      }
  }
  return const {};
}

DateTime? _parseDate(Object? raw) {
  if (raw is String) return DateTime.tryParse(raw)?.toUtc();
  return null;
}

DateTime? _parseEpoch(Object? raw) {
  if (raw is int) {
    return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
  }
  if (raw is num) {
    return DateTime.fromMillisecondsSinceEpoch(raw.toInt(), isUtc: true);
  }
  return null;
}