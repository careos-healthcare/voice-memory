import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'onboarding_pages.dart';

/// Onboarding layout and type scale — compact on phone, readable on tablet.
abstract class OnboardingLayout {
  OnboardingLayout._();

  static const double maxContentWidth = 560;
  static const double mobileTitleSize = 28;
  static const double compactTitleSize = 24;
  static const double tabletTitleSize = 32;
  static const double mobileBodySize = 16;
  static const double compactBodySize = 15;
  static const double tabletBodySize = 17;
  static const double sectionGap = 12;
  static const double compactSectionGap = 10;
  static const double cardPadding = 14;
  static const double compactCardPadding = 12;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 600;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).height < 700 ||
      MediaQuery.textScalerOf(context).scale(16) > 18;
}

/// Onboarding-specific type scale.
abstract class OnboardingTypography {
  OnboardingTypography._();

  static double titleSize(BuildContext context) {
    if (OnboardingLayout.isWide(context)) {
      return OnboardingLayout.tabletTitleSize;
    }
    if (OnboardingLayout.isCompact(context)) {
      return OnboardingLayout.compactTitleSize;
    }
    return OnboardingLayout.mobileTitleSize;
  }

  static double bodySize(BuildContext context) {
    if (OnboardingLayout.isWide(context)) {
      return OnboardingLayout.tabletBodySize;
    }
    if (OnboardingLayout.isCompact(context)) {
      return OnboardingLayout.compactBodySize;
    }
    return OnboardingLayout.mobileBodySize;
  }

  static double sectionGap(BuildContext context) =>
      OnboardingLayout.isCompact(context)
      ? OnboardingLayout.compactSectionGap
      : OnboardingLayout.sectionGap;

  static const double chipSize = 14;
  static const double labelSize = 13;

  static TextStyle title(BuildContext context, {Color? color}) => TextStyle(
    fontSize: titleSize(context),
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.4,
    color: color ?? AppColors.textPrimary,
  );

  static TextStyle body(BuildContext context, {Color? color}) => TextStyle(
    fontSize: bodySize(context),
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: color ?? AppColors.textSecondary,
  );

  static TextStyle chip({Color? color}) => TextStyle(
    fontSize: chipSize,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: color ?? AppColors.textPrimary,
  );

  static TextStyle label({Color? color}) => TextStyle(
    fontSize: labelSize,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: color ?? AppColors.textSecondary,
  );
}

class OnboardingPageVisual extends StatelessWidget {
  const OnboardingPageVisual({super.key, required this.page});

  final OnboardingPageData page;

  @override
  Widget build(BuildContext context) {
    return switch (page.visual) {
      OnboardingVisualKind.patternNetwork => const _PatternNetworkVisual(),
      OnboardingVisualKind.evidenceChips => _EvidenceChipsVisual(
        examples: page.evidenceExamples,
      ),
      OnboardingVisualKind.confidenceGrowth => _ConfidenceGrowthVisual(
        steps: page.confidenceSteps,
      ),
      OnboardingVisualKind.beliefShift => _BeliefShiftVisual(
        oldBelief: page.oldBelief ?? '',
        newBelief: page.newBelief ?? '',
      ),
      OnboardingVisualKind.insightPreview => _InsightPreviewVisual(
        bullets: page.insightBullets,
      ),
      OnboardingVisualKind.checkPreview => _InsightPreviewVisual(
        bullets: page.insightBullets,
      ),
      OnboardingVisualKind.stepBadge => _StepBadgeVisual(
        stepNumber: page.stepNumber ?? 1,
      ),
    };
  }
}

class _PatternNetworkVisual extends StatelessWidget {
  const _PatternNetworkVisual();

  @override
  Widget build(BuildContext context) {
    final height = OnboardingLayout.isWide(context) ? 160.0 : 132.0;
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.borderSubtle),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowColor,
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const CustomPaint(painter: _PatternNetworkPainter()),
      ),
    );
  }
}

class _PatternNetworkPainter extends CustomPainter {
  const _PatternNetworkPainter();

  static const _phrases = [
    'too late',
    'not ready',
    'prove myself',
    'what if',
    'again',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 8 || size.height <= 8) return;
    final nodes = <Offset>[
      Offset(size.width * 0.22, size.height * 0.28),
      Offset(size.width * 0.78, size.height * 0.22),
      Offset(size.width * 0.5, size.height * 0.48),
      Offset(size.width * 0.18, size.height * 0.72),
      Offset(size.width * 0.82, size.height * 0.68),
      Offset(size.width * 0.52, size.height * 0.82),
    ];

    final linePaint = Paint()
      ..color = AppColors.accentPrimary.withValues(alpha: 0.22)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < nodes.length; i++) {
      for (var j = i + 1; j < nodes.length; j++) {
        if ((i + j) % 3 == 0) {
          canvas.drawLine(nodes[i], nodes[j], linePaint);
        }
      }
    }

    final nodePaint = Paint()..color = AppColors.accentPrimary;
    final ringPaint = Paint()
      ..color = AppColors.accentLight
      ..style = PaintingStyle.fill;

    for (var i = 0; i < nodes.length; i++) {
      canvas.drawCircle(nodes[i], 14, ringPaint);
      canvas.drawCircle(nodes[i], 5, nodePaint);
    }

    final textStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary.withValues(alpha: 0.9),
    );
    for (var i = 0; i < nodes.length; i++) {
      final phrase = _phrases[i % _phrases.length];
      final tp = TextPainter(
        text: TextSpan(text: phrase, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = nodes[i].dx - tp.width / 2;
      final dy = nodes[i].dy + 18;
      final maxDx = size.width - tp.width - 4;
      tp.paint(canvas, Offset(dx.clamp(4.0, maxDx > 4 ? maxDx : 4.0), dy));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EvidenceChipsVisual extends StatelessWidget {
  const _EvidenceChipsVisual({required this.examples});

  final List<String> examples;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Examples from real reflections',
          style: OnboardingTypography.label(),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final quote in examples) ...[
          _EvidenceChip(text: quote),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _EvidenceChip extends StatelessWidget {
  const _EvidenceChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accentPrimary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.format_quote_rounded,
            size: 20,
            color: AppColors.accentPrimary.withValues(alpha: 0.75),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: OnboardingTypography.chip())),
        ],
      ),
    );
  }
}

class _ConfidenceGrowthVisual extends StatelessWidget {
  const _ConfidenceGrowthVisual({required this.steps});

  final List<int> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Pattern clarity', style: OnboardingTypography.label()),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < steps.length; i++) ...[
          _ConfidenceRow(percent: steps[i], index: i),
          if (i < steps.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _ConfidenceRow extends StatelessWidget {
  const _ConfidenceRow({required this.percent, required this.index});

  final int percent;
  final int index;

  @override
  Widget build(BuildContext context) {
    final fraction = percent / 100.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _beliefLabel(index),
                style: OnboardingTypography.chip(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Text(
              '$percent%',
              style: OnboardingTypography.label(color: AppColors.accentPrimary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 10,
            backgroundColor: AppColors.borderSubtle,
            color: AppColors.accentPrimary.withValues(
              alpha: 0.55 + (index * 0.15).clamp(0.0, 0.4),
            ),
          ),
        ),
      ],
    );
  }

  String _beliefLabel(int index) => switch (index) {
    0 => 'Early observation',
    1 => 'Growing pattern',
    _ => 'Clear pattern',
  };
}

class _BeliefShiftVisual extends StatelessWidget {
  const _BeliefShiftVisual({required this.oldBelief, required this.newBelief});

  final String oldBelief;
  final String newBelief;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BeliefCard(label: 'Earlier', belief: oldBelief, faded: true),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.arrow_downward_rounded,
                size: 22,
                color: AppColors.accentPrimary.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
        _BeliefCard(label: 'Now', belief: newBelief, faded: false),
      ],
    );
  }
}

class _BeliefCard extends StatelessWidget {
  const _BeliefCard({
    required this.label,
    required this.belief,
    required this.faded,
  });

  final String label;
  final String belief;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: faded ? AppColors.backgroundPrimary : AppColors.accentLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: faded
              ? AppColors.borderSubtle
              : AppColors.accentPrimary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: OnboardingTypography.label()),
          const SizedBox(height: 8),
          Text(
            belief,
            style:
                OnboardingTypography.chip(
                  color: faded
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ).copyWith(
                  decoration: faded ? TextDecoration.lineThrough : null,
                  decorationColor: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _StepBadgeVisual extends StatelessWidget {
  const _StepBadgeVisual({required this.stepNumber});

  final int stepNumber;

  @override
  Widget build(BuildContext context) {
    final size = OnboardingLayout.isWide(context) ? 88.0 : 72.0;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.accentLight,
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.accentPrimary.withValues(alpha: 0.25),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '$stepNumber',
          style: OnboardingTypography.title(context).copyWith(
            fontSize: OnboardingLayout.isWide(context) ? 34 : 28,
            color: AppColors.accentPrimary,
          ),
        ),
      ),
    );
  }
}

class _InsightPreviewVisual extends StatelessWidget {
  const _InsightPreviewVisual({required this.bullets});

  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    final compact = OnboardingLayout.isCompact(context);
    final cardPadding = compact
        ? OnboardingLayout.compactCardPadding
        : OnboardingLayout.cardPadding;

    return Container(
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in bullets)
            Padding(
              padding: EdgeInsets.only(bottom: compact ? 6 : 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: EdgeInsets.only(top: compact ? 6 : 7),
                    decoration: const BoxDecoration(
                      color: AppColors.accentPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item,
                      style: OnboardingTypography.chip(),
                      softWrap: true,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Decorative arc used behind page content (optional polish).
class OnboardingAmbientGlow extends StatelessWidget {
  const OnboardingAmbientGlow({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(size: Size.infinite, painter: _AmbientGlowPainter()),
    );
  }
}

class _AmbientGlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.85, size.height * 0.12);
    final gradient = RadialGradient(
      colors: [
        AppColors.accentPrimary.withValues(alpha: 0.08),
        AppColors.transparent,
      ],
    );
    final rect = Rect.fromCircle(center: center, radius: size.width * 0.45);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = gradient.createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
