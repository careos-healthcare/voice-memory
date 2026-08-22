import 'dart:async';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/widgets/paywall/pro_paywall_feature.dart';
import 'package:flutter/material.dart';

/// Pro benefits with staggered fade + slide reveal on first paint.
class StaggeredProFeatureList extends StatefulWidget {
  const StaggeredProFeatureList({
    required this.features,
    super.key,
    this.sectionTitle,
  });

  final List<ProPaywallFeatureItem> features;
  final String? sectionTitle;

  @override
  State<StaggeredProFeatureList> createState() =>
      _StaggeredProFeatureListState();
}

class _StaggeredProFeatureListState extends State<StaggeredProFeatureList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final count = widget.features.length.clamp(1, 12);
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 520 + count * 110),
    );
    unawaited(_controller.forward());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.sectionTitle != null) ...[
          Text(
            widget.sectionTitle!,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: 12),
        ],
        for (var i = 0; i < widget.features.length; i++)
          _StaggeredFeatureTile(
            feature: widget.features[i],
            index: i,
            total: widget.features.length,
            controller: _controller,
          ),
      ],
    );
  }
}

class _StaggeredFeatureTile extends StatelessWidget {
  const _StaggeredFeatureTile({
    required this.feature,
    required this.index,
    required this.total,
    required this.controller,
  });

  final ProPaywallFeatureItem feature;
  final int index;
  final int total;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final start = (index / total * 0.55).clamp(0.0, 0.85);
    final end = (start + 0.45).clamp(0.0, 1.0);
    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 18),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: VoiceMemoryColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: VoiceMemoryColors.border),
            boxShadow: [
              BoxShadow(
                color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  feature.icon,
                  size: 22,
                  color: VoiceMemoryColors.primaryIndigo,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feature.title,
                      style: ArchiveMobileTypography.listTitle(context),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      feature.subtitle,
                      style: ArchiveMobileTypography.responsiveHelper(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}