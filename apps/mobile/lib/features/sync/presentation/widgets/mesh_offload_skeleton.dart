import 'dart:async';

import 'package:flutter/material.dart';

/// Short pulse that covers mesh settle. The bars run only while this widget
/// is mounted, so the feed can drop them as soon as the save settles.
class MeshOffloadSkeleton extends StatefulWidget {
  const MeshOffloadSkeleton({required this.entryId, super.key});

  final String entryId;

  @override
  State<MeshOffloadSkeleton> createState() => _MeshOffloadSkeletonState();
}

class _MeshOffloadSkeletonState extends State<MeshOffloadSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    unawaited(_pulse.repeat(reverse: true));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Semantics(
      label: 'Mesh sync settling',
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.45, end: 1).animate(_pulse),
        child: Column(
          key: Key('mesh_offload_skeleton_${widget.entryId}'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final width in const [220.0, 160.0, 96.0])
              Container(
                width: width,
                height: 10,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
