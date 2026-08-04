import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

final class CouncilPersona {
  CouncilPersona({
    required String id,
    required String name,
    required String archetypeTitle,
    required String systemPrompt,
    Map<String, String> localizedSystemPrompts = const {},
    required num temperature,
    required Iterable<String> restrictedClusterIds,
    String avatarAsset = 'psychology',
    Uint8List? avatarImage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = _text(id, 'id', 128),
       name = _text(name, 'name', 80),
       avatarAsset = _text(avatarAsset, 'avatarAsset', 128),
       avatarImage = avatarImage == null
           ? null
           : Uint8List.fromList(avatarImage),
       archetypeTitle = _text(archetypeTitle, 'archetypeTitle', 120),
       systemPrompt = _text(systemPrompt, 'systemPrompt', 12000),
       localizedSystemPrompts = UnmodifiableMapView({
         for (final entry in localizedSystemPrompts.entries)
           _text(entry.key, 'locale', 32).replaceAll('_', '-').toLowerCase():
               _text(entry.value, 'localizedSystemPrompt', 12000),
       }),
       temperature = _temperature(temperature),
       restrictedClusterIds = UnmodifiableSetView(_ids(restrictedClusterIds)),
       createdAt = (createdAt ?? DateTime.now()).toUtc(),
       updatedAt = (updatedAt ?? DateTime.now()).toUtc();

  final String id;
  final String name;
  final String avatarAsset;
  final Uint8List? avatarImage;
  final String archetypeTitle;
  final String systemPrompt;
  final Map<String, String> localizedSystemPrompts;
  final double temperature;
  final Set<String> restrictedClusterIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  CouncilPersona copyWith({
    String? name,
    String? avatarAsset,
    Uint8List? avatarImage,
    bool clearAvatarImage = false,
    String? archetypeTitle,
    String? systemPrompt,
    Map<String, String>? localizedSystemPrompts,
    num? temperature,
    Iterable<String>? restrictedClusterIds,
    DateTime? updatedAt,
  }) => CouncilPersona(
    id: id,
    name: name ?? this.name,
    avatarAsset: avatarAsset ?? this.avatarAsset,
    avatarImage: clearAvatarImage ? null : (avatarImage ?? this.avatarImage),
    archetypeTitle: archetypeTitle ?? this.archetypeTitle,
    systemPrompt: systemPrompt ?? this.systemPrompt,
    localizedSystemPrompts:
        localizedSystemPrompts ?? this.localizedSystemPrompts,
    temperature: temperature ?? this.temperature,
    restrictedClusterIds: restrictedClusterIds ?? this.restrictedClusterIds,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'avatarAsset': avatarAsset,
    'avatarImage': avatarImage == null ? null : base64Encode(avatarImage!),
    'archetypeTitle': archetypeTitle,
    'systemPrompt': systemPrompt,
    'localizedSystemPrompts': localizedSystemPrompts,
    'temperature': temperature,
    'restrictedClusterIds': restrictedClusterIds.toList()..sort(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory CouncilPersona.fromJson(Map<String, dynamic> json) {
    final rawIds = json['restrictedClusterIds'];
    if (rawIds is! List) {
      throw const FormatException('Persona cluster permissions are invalid.');
    }
    final encodedAvatar = json['avatarImage'];
    return CouncilPersona(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatarAsset: json['avatarAsset'] as String? ?? 'psychology',
      avatarImage: encodedAvatar is String && encodedAvatar.isNotEmpty
          ? base64Decode(encodedAvatar)
          : null,
      archetypeTitle: json['archetypeTitle'] as String? ?? '',
      systemPrompt: json['systemPrompt'] as String? ?? '',
      localizedSystemPrompts: Map<String, String>.from(
        json['localizedSystemPrompts'] as Map? ?? const {},
      ),
      temperature: json['temperature'] as num? ?? .5,
      restrictedClusterIds: rawIds.whereType<String>(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }

  String promptForLocale(String localeTag) {
    final normalized = localeTag.replaceAll('_', '-').toLowerCase();
    return localizedSystemPrompts[normalized] ??
        localizedSystemPrompts[normalized.split('-').first] ??
        systemPrompt;
  }

  static String _text(String value, String field, int maxLength) {
    final result = value.trim();
    if (result.isEmpty || result.length > maxLength) {
      throw ArgumentError.value(
        value,
        field,
        'must be 1-$maxLength characters',
      );
    }
    return result;
  }

  static double _temperature(num value) {
    final result = value.toDouble();
    if (!result.isFinite || result < 0 || result > 1) {
      throw ArgumentError.value(
        value,
        'temperature',
        'must be between 0 and 1',
      );
    }
    return result;
  }

  static Set<String> _ids(Iterable<String> values) {
    final result = <String>{};
    for (final value in values) {
      result.add(_text(value, 'restrictedClusterIds', 256));
    }
    return result;
  }
}
