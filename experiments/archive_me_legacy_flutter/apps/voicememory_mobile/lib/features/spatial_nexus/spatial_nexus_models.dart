import 'dart:math' as math;

enum SpatialEnvironmentPreset { neuralVoid, cyberneticGrid, organicSanctuary }

enum SpatialNativeCapability { metal, vulkan, hrtf, visionOs, openXr }

final class SpatialCapability {
  const SpatialCapability({
    required this.kind,
    required this.available,
    required this.contractVersion,
    required this.reason,
  });

  const SpatialCapability.unavailable(this.kind, this.reason)
    : available = false,
      contractVersion = 1;

  final SpatialNativeCapability kind;
  final bool available;
  final int contractVersion;
  final String reason;
}

final class SpatialVector3 {
  const SpatialVector3(this.x, this.y, this.z);
  const SpatialVector3.zero() : this(0, 0, 0);

  final double x;
  final double y;
  final double z;

  double get length => math.sqrt(lengthSquared);
  double get lengthSquared => x * x + y * y + z * z;

  SpatialVector3 operator +(SpatialVector3 other) =>
      SpatialVector3(x + other.x, y + other.y, z + other.z);
  SpatialVector3 operator -(SpatialVector3 other) =>
      SpatialVector3(x - other.x, y - other.y, z - other.z);
  SpatialVector3 operator *(double scale) =>
      SpatialVector3(x * scale, y * scale, z * scale);
  SpatialVector3 operator /(double scale) =>
      scale == 0 ? const SpatialVector3.zero() : this * (1 / scale);

  SpatialVector3 normalized() =>
      length <= 1e-9 ? const SpatialVector3.zero() : this / length;

  double dot(SpatialVector3 other) => x * other.x + y * other.y + z * other.z;

  Map<String, double> toJson() => {'x': x, 'y': y, 'z': z};
}

final class SpatialCamera {
  const SpatialCamera({
    this.position = const SpatialVector3(0, 0, 8),
    this.near = .1,
    this.far = 80,
    this.fieldOfViewRadians = math.pi / 3,
  });

  final SpatialVector3 position;
  final double near;
  final double far;
  final double fieldOfViewRadians;

  SpatialCamera copyWith({SpatialVector3? position}) => SpatialCamera(
    position: position ?? this.position,
    near: near,
    far: far,
    fieldOfViewRadians: fieldOfViewRadians,
  );
}

final class SpatialNode {
  const SpatialNode({
    required this.id,
    required this.label,
    required this.type,
    required this.position,
    required this.velocity,
    required this.radius,
    required this.valence,
    required this.clusterId,
    required this.isHorizonProjection,
  });

  final String id;
  final String label;
  final String type;
  final SpatialVector3 position;
  final SpatialVector3 velocity;
  final double radius;
  final double valence;
  final String? clusterId;
  final bool isHorizonProjection;

  SpatialNode copyWith({SpatialVector3? position, SpatialVector3? velocity}) =>
      SpatialNode(
        id: id,
        label: label,
        type: type,
        position: position ?? this.position,
        velocity: velocity ?? this.velocity,
        radius: radius,
        valence: valence,
        clusterId: clusterId,
        isHorizonProjection: isHorizonProjection,
      );
}

final class SpatialEdge {
  const SpatialEdge({
    required this.sourceId,
    required this.targetId,
    required this.weight,
  });

  final String sourceId;
  final String targetId;
  final double weight;
}

final class SpatialScene {
  const SpatialScene({
    required this.nodes,
    required this.edges,
    required this.preset,
  });

  final List<SpatialNode> nodes;
  final List<SpatialEdge> edges;
  final SpatialEnvironmentPreset preset;

  SpatialScene copyWith({
    List<SpatialNode>? nodes,
    SpatialEnvironmentPreset? preset,
  }) => SpatialScene(
    nodes: nodes ?? this.nodes,
    edges: edges,
    preset: preset ?? this.preset,
  );
}

final class SpatialProjectedNode {
  const SpatialProjectedNode({
    required this.node,
    required this.screenX,
    required this.screenY,
    required this.depth,
    required this.scale,
    required this.blurSigma,
  });

  final SpatialNode node;
  final double screenX;
  final double screenY;
  final double depth;
  final double scale;
  final double blurSigma;
}
