import 'package:archiveme_mobile/features/comparison_engine/domain/models/archive_moment_record.dart';
import 'package:archiveme_mobile/features/comparison_engine/domain/models/pattern_evidence_view_state.dart';
import 'package:archiveme_mobile/features/comparison_engine/presentation/controllers/post_save_comparison_controller.dart';
import 'package:archiveme_mobile/features/comparison_engine/presentation/widgets/pattern_evidence_card.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// Whether the comparison pipeline surfaced enough aligned text to show UI.
bool postSaveComparisonHasVisibleEvidence(PatternEvidenceViewState viewState) {
  if (viewState.state == PatternState.notEnoughEvidence) {
    return false;
  }

  return viewState.pastQuote.trim().isNotEmpty &&
      viewState.currentQuote.trim().isNotEmpty;
}

class PostSaveComparisonSection extends StatelessWidget {
  const PostSaveComparisonSection({
    required this.controller, super.key,
    this.onProUpgradeTapped,
  });

  final PostSaveComparisonController controller;
  final VoidCallback? onProUpgradeTapped;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.uiState;

        return AnimatedSize(
          duration: const Duration(milliseconds: 350),
          curve: Curves.fastOutSlowIn,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              // Combined fade + slide for fluid arrival.
              final offsetAnimation = Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(animation);

              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offsetAnimation, child: child),
              );
            },
            child: _buildContent(state),
          ),
        );
      },
    );
  }

  Widget _buildContent(PostSaveComparisonUiState state) {
    switch (state) {
      case ComparisonLoading():
        return const _PulsingLoadingShell(key: ValueKey('comparison_loading'));

      case ComparisonSuccess(:final viewState):
        if (viewState.state == PatternState.notEnoughEvidence ||
            viewState.pastQuote.isEmpty ||
            viewState.currentQuote.isEmpty) {
          return const SizedBox(key: ValueKey('comparison_empty'));
        }

        return _ComparisonEvidenceShell(
          key: const ValueKey('comparison_card'),
          viewState: viewState,
          onDismissProPrompt: controller.dismissProPrompt,
          onProUpgradeTapped: onProUpgradeTapped,
        );

      case ComparisonFailure():
        return const SizedBox(key: ValueKey('comparison_failure'));
    }
  }
}

/// Pulsing text placeholder shaped like the incoming [PatternEvidenceCard].
class _PulsingLoadingShell extends StatefulWidget {
  const _PulsingLoadingShell({super.key});

  @override
  State<_PulsingLoadingShell> createState() => _PulsingLoadingShellState();
}

class _PulsingLoadingShellState extends State<_PulsingLoadingShell>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _opacityAnimation = Tween<double>(
      begin: 0.4,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
          borderRadius: BorderRadius.circular(8),
        ),
        color: Colors.grey.withValues(alpha: 0.02),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _TextPlaceholder(width: 100, height: 12),
                  _TextPlaceholder(width: 70, height: 16),
                ],
              ),
              SizedBox(height: 20),
              _TextPlaceholder(width: double.infinity, height: 14),
              SizedBox(height: 8),
              _TextPlaceholder(width: 180, height: 14),
              SizedBox(height: 24),
              Divider(height: 1, color: Colors.transparent),
              _TextPlaceholder(width: 120, height: 10),
              SizedBox(height: 12),
              _TextPlaceholder(width: double.infinity, height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextPlaceholder extends StatelessWidget {
  const _TextPlaceholder({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _ComparisonEvidenceShell extends StatelessWidget {
  const _ComparisonEvidenceShell({
    required this.viewState, required this.onDismissProPrompt, super.key,
    this.onProUpgradeTapped,
  });

  final PatternEvidenceViewState viewState;
  final Future<void> Function() onDismissProPrompt;
  final VoidCallback? onProUpgradeTapped;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PatternEvidenceCard(
          viewState: viewState,
          onProUpgradeTapped: onProUpgradeTapped,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 350),
          curve: Curves.fastOutSlowIn,
          child: viewState.showProTrailPrompt
              ? Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextButton(
                      key: const Key('pattern_evidence_dismiss_pro_prompt'),
                      onPressed: onDismissProPrompt,
                      child: const Text('Not now'),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Backward-compatible alias for existing call sites.
typedef PostSavePatternComparisonSection = PostSaveComparisonSection;