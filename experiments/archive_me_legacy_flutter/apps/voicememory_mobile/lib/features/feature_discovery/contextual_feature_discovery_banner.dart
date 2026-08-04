import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/feature_discovery/feature_discovery_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

class ContextualFeatureDiscoveryBanner extends StatefulWidget {
  const ContextualFeatureDiscoveryBanner({
    super.key,
    required this.service,
    required this.discoveryContext,
    this.onOpen,
  });

  final FeatureDiscoveryService service;
  final FeatureDiscoveryContext discoveryContext;
  final ValueChanged<FeatureDiscoverySuggestion>? onOpen;

  @override
  State<ContextualFeatureDiscoveryBanner> createState() =>
      _ContextualFeatureDiscoveryBannerState();
}

class _ContextualFeatureDiscoveryBannerState
    extends State<ContextualFeatureDiscoveryBanner> {
  FeatureDiscoverySuggestion? _suggestion;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final suggestion = await widget.service.nextSuggestion(
      widget.discoveryContext,
    );
    if (suggestion == null) return;
    await widget.service.markExposed(suggestion.feature);
    if (mounted) setState(() => _suggestion = suggestion);
  }

  Future<void> _dismiss() async {
    final suggestion = _suggestion;
    if (suggestion == null) return;
    setState(() => _suggestion = null);
    await widget.service.dismiss(suggestion.feature);
  }

  Future<void> _open() async {
    final suggestion = _suggestion;
    if (suggestion == null) return;
    await widget.service.complete(suggestion.feature);
    if (!mounted) return;
    final callback = widget.onOpen;
    if (callback != null) {
      callback(suggestion);
    } else {
      context.push(suggestion.route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestion = _suggestion;
    if (suggestion == null) return const SizedBox.shrink();
    return Semantics(
      container: true,
      label: '${suggestion.title}. ${suggestion.message}',
      child: Card(
        key: Key('feature_discovery_${suggestion.feature.storageId}'),
        color: AppColors.backgroundSecondary,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ExcludeSemantics(
                    child: Icon(
                      Icons.auto_awesome_outlined,
                      color: AppColors.accentSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      suggestion.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    key: Key(
                      'feature_discovery_dismiss_${suggestion.feature.storageId}',
                    ),
                    tooltip: 'Dismiss suggestion',
                    onPressed: () => unawaited(_dismiss()),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                suggestion.message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: Key(
                    'feature_discovery_open_${suggestion.feature.storageId}',
                  ),
                  onPressed: () => unawaited(_open()),
                  child: Text(suggestion.actionLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
