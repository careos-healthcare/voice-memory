import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import '../cognitive_council/council_persona.dart';
import '../semantic_clusters/semantic_cluster.dart';
import '../../core/graph/personal_knowledge_graph.dart';

enum MeshExchangePolicy { reusable, readOnce, selfDestruct }

final class MeshExchangeInvitation {
  MeshExchangeInvitation({
    required this.id,
    required Uint8List receiverEphemeralPublicKey,
    required Uint8List nonce,
    required DateTime expiresAt,
  }) : receiverEphemeralPublicKey = Uint8List.fromList(
         receiverEphemeralPublicKey,
       ),
       nonce = Uint8List.fromList(nonce),
       expiresAt = expiresAt.toUtc();

  final String id;
  final Uint8List receiverEphemeralPublicKey;
  final Uint8List nonce;
  final DateTime expiresAt;

  String encode() =>
      'vm-mesh-exchange://invite/${base64UrlEncode(utf8.encode(jsonEncode({'version': 1, 'id': id, 'receiverKey': base64Encode(receiverEphemeralPublicKey), 'nonce': base64Encode(nonce), 'expiresAt': expiresAt.toIso8601String()})))}';

  factory MeshExchangeInvitation.decode(String value, {DateTime? now}) {
    const prefix = 'vm-mesh-exchange://invite/';
    if (!value.startsWith(prefix)) {
      throw const FormatException('Invalid Mesh Exchange invitation.');
    }
    final json = jsonDecode(
      utf8.decode(base64Url.decode(value.substring(prefix.length))),
    );
    if (json is! Map || json['version'] != 1) {
      throw const FormatException('Invalid Mesh Exchange invitation.');
    }
    final invitation = MeshExchangeInvitation(
      id: json['id'] as String,
      receiverEphemeralPublicKey: base64Decode(json['receiverKey'] as String),
      nonce: base64Decode(json['nonce'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
    if (invitation.receiverEphemeralPublicKey.length != 32 ||
        invitation.nonce.length != 32 ||
        !invitation.expiresAt.isAfter((now ?? DateTime.now()).toUtc())) {
      throw const FormatException('Mesh Exchange invitation expired.');
    }
    return invitation;
  }
}

final class MeshJournalFragment {
  MeshJournalFragment({
    required this.id,
    required String text,
    required DateTime createdAt,
  }) : text = text.trim(),
       createdAt = createdAt.toUtc() {
    if (id.trim().isEmpty || this.text.isEmpty || this.text.length > 100000) {
      throw ArgumentError('Invalid journal fragment.');
    }
  }

  final String id;
  final String text;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
  };

  factory MeshJournalFragment.fromJson(Map<String, dynamic> json) =>
      MeshJournalFragment(
        id: json['id'] as String,
        text: json['text'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

final class MeshExchangeContent {
  MeshExchangeContent({
    required this.id,
    required this.senderName,
    required this.graph,
    Iterable<SemanticCluster> clusters = const [],
    Iterable<CouncilPersona> personas = const [],
    Iterable<MeshJournalFragment> journalFragments = const [],
    required this.policy,
    required DateTime createdAt,
    DateTime? destructAt,
  }) : clusters = UnmodifiableListView(clusters),
       personas = UnmodifiableListView(personas),
       journalFragments = UnmodifiableListView(journalFragments),
       createdAt = createdAt.toUtc(),
       destructAt = destructAt?.toUtc() {
    if (id.trim().isEmpty ||
        senderName.trim().isEmpty ||
        policy == MeshExchangePolicy.selfDestruct && this.destructAt == null) {
      throw ArgumentError('Invalid Mesh Exchange content.');
    }
  }

  final String id;
  final String senderName;
  final PersonalKnowledgeGraph graph;
  final List<SemanticCluster> clusters;
  final List<CouncilPersona> personas;
  final List<MeshJournalFragment> journalFragments;
  final MeshExchangePolicy policy;
  final DateTime createdAt;
  final DateTime? destructAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderName': senderName,
    'graph': graph.toJson(),
    'clusters': clusters.map((item) => item.toJson()).toList(),
    'personas': personas.map((item) => item.toJson()).toList(),
    'journalFragments': journalFragments.map((item) => item.toJson()).toList(),
    'policy': policy.name,
    'createdAt': createdAt.toIso8601String(),
    'destructAt': destructAt?.toIso8601String(),
  };

  factory MeshExchangeContent.fromJson(Map<String, dynamic> json) =>
      MeshExchangeContent(
        id: json['id'] as String,
        senderName: json['senderName'] as String,
        graph: PersonalKnowledgeGraph.fromJson(
          Map<String, dynamic>.from(json['graph'] as Map),
        ),
        clusters: (json['clusters'] as List).whereType<Map>().map(
          (item) => SemanticCluster.fromJson(Map<String, dynamic>.from(item)),
        ),
        personas: (json['personas'] as List).whereType<Map>().map(
          (item) => CouncilPersona.fromJson(Map<String, dynamic>.from(item)),
        ),
        journalFragments: (json['journalFragments'] as List)
            .whereType<Map>()
            .map(
              (item) =>
                  MeshJournalFragment.fromJson(Map<String, dynamic>.from(item)),
            ),
        policy: MeshExchangePolicy.values.byName(json['policy'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        destructAt: json['destructAt'] == null
            ? null
            : DateTime.parse(json['destructAt'] as String),
      );
}

final class MeshQrFrame {
  const MeshQrFrame({
    required this.exchangeId,
    required this.index,
    required this.total,
    required this.digest,
    required this.payload,
  });

  final String exchangeId;
  final int index;
  final int total;
  final String digest;
  final String payload;

  String encode() =>
      'vm-mesh-exchange://frame/${base64UrlEncode(utf8.encode(jsonEncode({'v': 1, 'id': exchangeId, 'i': index, 'n': total, 'sha256': digest, 'data': payload})))}';

  factory MeshQrFrame.decode(String value) {
    const prefix = 'vm-mesh-exchange://frame/';
    if (!value.startsWith(prefix)) {
      throw const FormatException('Invalid frame.');
    }
    final json = jsonDecode(
      utf8.decode(base64Url.decode(value.substring(prefix.length))),
    );
    if (json is! Map || json['v'] != 1) {
      throw const FormatException('Invalid frame.');
    }
    return MeshQrFrame(
      exchangeId: json['id'] as String,
      index: (json['i'] as num).toInt(),
      total: (json['n'] as num).toInt(),
      digest: json['sha256'] as String,
      payload: json['data'] as String,
    );
  }
}
