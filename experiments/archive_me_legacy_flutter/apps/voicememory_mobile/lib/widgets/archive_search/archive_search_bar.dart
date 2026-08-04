import 'package:flutter/material.dart';

import '../../features/archive_search/archive_search_filters.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';

/// Archive search input. Local only: the typed text goes to [onChanged]
/// and nowhere else — it is never logged, stored, or sent to analytics.
/// Only a fixed "search opened" event fires, once per session.
class ArchiveSearchBar extends StatelessWidget {
  const ArchiveSearchBar({
    super.key,
    required this.onChanged,
    this.source = 'journal',
    this.focusNode,
    this.controller,
  });

  final ValueChanged<String> onChanged;

  /// Stable analytics source id only.
  final String source;

  /// Lets callers (e.g. the first-archive helper) focus the field.
  final FocusNode? focusNode;

  /// Optional controller so parent state stays in sync with the field.
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('archive_search_bar'),
      controller: controller,
      focusNode: focusNode,
      onTap: () => ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.archiveSearchOpened,
        source: source,
        oncePerSession: true,
      ),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: ArchiveSearchCopy.searchPlaceholder,
        prefixIcon: const Icon(Icons.search, size: 20),
        isDense: true,
        constraints: const BoxConstraints(minHeight: 48),
        filled: true,
        fillColor: AppColors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      textInputAction: TextInputAction.search,
    );
  }
}
