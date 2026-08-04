import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/memory_graph/rendering/memory_graph_visual_style.dart';
import '../../../shared/ui/animations/canvas_feature_panel.dart';
import '../../../shared/ui/glassmorphic_container.dart';
import '../memory_typography.dart';
import '../theme_engine.dart';
import '../theme_models.dart';
import '../visual_theme_tokens.dart';

Future<void> showThemeStudioSheet(BuildContext context) =>
    showCanvasFeaturePanel<void>(
      context: context,
      routeName: 'theme-studio',
      builder: (_) => const ThemeStudioSheet(),
    );

class ThemeStudioSheet extends ConsumerWidget {
  const ThemeStudioSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(themeEngineProvider);
    final engine = ref.read(themeEngineProvider.notifier);
    final tokens =
        Theme.of(context).extension<VisualThemeTokens>() ??
        visualTokensFor(preferences, Theme.of(context).brightness);
    final hsv = HSVColor.fromColor(preferences.customAccent ?? tokens.accent);
    final typography = MemoryTypography.of(context);

    void preview(ThemePreferences next) => engine.preview(next);
    Future<void> persistCurrent() =>
        engine.replace(ref.read(themeEngineProvider));

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        key: const Key('theme_studio_sheet'),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: tokens.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text('Theme Studio', style: typography.display),
                ),
                IconButton(
                  tooltip: 'Close Theme Studio',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(
              'Shape the atmosphere of your private memory space.',
              style: typography.body.copyWith(color: tokens.onSurfaceMuted),
            ),
            const SizedBox(height: 20),
            _ThemePreview(
              tokens: tokens,
              quality: _quality(preferences.glassEffects),
            ),
            const SizedBox(height: 24),
            Text('Visual archetype', style: typography.sectionTitle),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final archetype in ThemeArchetype.values)
                  _PresetCard(
                    archetype: archetype,
                    selected: preferences.archetype == archetype,
                    onTap: () => engine.selectArchetype(archetype),
                  ),
              ],
            ),
            const SizedBox(height: 26),
            Text('Accent color', style: typography.sectionTitle),
            const SizedBox(height: 8),
            _ColorPreview(color: hsv.toColor()),
            _StudioSlider(
              key: const Key('theme_accent_hue_slider'),
              label: 'Hue',
              value: hsv.hue,
              max: 360,
              valueLabel: '${hsv.hue.round()} degrees',
              onChanged: (value) => preview(
                preferences.copyWith(
                  customAccentValue: hsv.withHue(value).toColor().toARGB32(),
                ),
              ),
              onChangeEnd: (_) => persistCurrent(),
            ),
            _StudioSlider(
              key: const Key('theme_accent_saturation_slider'),
              label: 'Saturation',
              value: hsv.saturation,
              max: 1,
              valueLabel: '${(hsv.saturation * 100).round()} percent',
              onChanged: (value) => preview(
                preferences.copyWith(
                  customAccentValue: hsv
                      .withSaturation(value)
                      .toColor()
                      .toARGB32(),
                ),
              ),
              onChangeEnd: (_) => persistCurrent(),
            ),
            _StudioSlider(
              key: const Key('theme_accent_value_slider'),
              label: 'Brightness',
              value: hsv.value,
              max: 1,
              valueLabel: '${(hsv.value * 100).round()} percent',
              onChanged: (value) => preview(
                preferences.copyWith(
                  customAccentValue: hsv.withValue(value).toColor().toARGB32(),
                ),
              ),
              onChangeEnd: (_) => persistCurrent(),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('theme_clear_accent'),
                onPressed: preferences.customAccentValue == null
                    ? null
                    : engine.clearCustomAccent,
                icon: const Icon(Icons.colorize_outlined),
                label: const Text('Use preset accent'),
              ),
            ),
            const SizedBox(height: 18),
            Text('Glass and glow', style: typography.sectionTitle),
            const SizedBox(height: 8),
            _StudioSlider(
              key: const Key('theme_blur_slider'),
              label: 'Blur intensity',
              value: preferences.glassBlur,
              max: 30,
              valueLabel: preferences.glassBlur.toStringAsFixed(0),
              onChanged: (value) =>
                  preview(preferences.copyWith(glassBlur: value)),
              onChangeEnd: (_) => persistCurrent(),
            ),
            _StudioSlider(
              key: const Key('theme_opacity_slider'),
              label: 'Glass opacity',
              value: preferences.glassOpacity,
              min: .45,
              max: 1,
              valueLabel: '${(preferences.glassOpacity * 100).round()} percent',
              onChanged: (value) =>
                  preview(preferences.copyWith(glassOpacity: value)),
              onChangeEnd: (_) => persistCurrent(),
            ),
            _StudioSlider(
              key: const Key('theme_glow_slider'),
              label: 'Node glow diffusion',
              value: preferences.nodeGlowDiffusion,
              max: 1.5,
              valueLabel: preferences.nodeGlowDiffusion.toStringAsFixed(2),
              onChanged: (value) =>
                  preview(preferences.copyWith(nodeGlowDiffusion: value)),
              onChangeEnd: (_) => persistCurrent(),
            ),
            DropdownButtonFormField<GlassEffectPreference>(
              key: const Key('theme_effects_control'),
              isExpanded: true,
              initialValue: preferences.glassEffects,
              decoration: const InputDecoration(
                labelText: 'Glass rendering',
                helperText:
                    'Automatic reduces effects for accessibility settings.',
              ),
              items: [
                for (final value in GlassEffectPreference.values)
                  DropdownMenuItem(value: value, child: Text(value.label)),
              ],
              onChanged: (value) {
                if (value != null) engine.setGlassEffects(value);
              },
            ),
            const SizedBox(height: 26),
            OutlinedButton.icon(
              key: const Key('theme_reset_button'),
              onPressed: engine.reset,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset visual theme'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.archetype,
    required this.selected,
    required this.onTap,
  });

  final ThemeArchetype archetype;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sample = VisualThemeTokens.resolve(
      ThemePreferences(archetype: archetype),
      Theme.of(context).brightness,
    );
    return Semantics(
      button: true,
      selected: selected,
      label: '${archetype.label} theme',
      child: InkWell(
        key: Key('theme_preset_${archetype.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 148,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: sample.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? sample.accent : sample.outline,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Dot(sample.accent),
                  _Dot(sample.secondaryAccent),
                  _Dot(sample.nodePalette[2]),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                archetype.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: sample.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                archetype.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: sample.onSurfaceMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.tokens, required this.quality});

  final VisualThemeTokens tokens;
  final GlassRenderQuality quality;

  @override
  Widget build(BuildContext context) {
    final style = MemoryGraphVisualStyle.fromTokens(tokens);
    return Semantics(
      label: 'Interactive theme preview with synthetic memory nodes',
      child: SizedBox(
        height: 250,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: InteractiveViewer(
            key: const Key('theme_live_preview'),
            minScale: .8,
            maxScale: 2,
            boundaryMargin: const EdgeInsets.all(48),
            child: SizedBox(
              width: 520,
              height: 280,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _ThemePreviewPainter(
                          style,
                          MediaQuery.textScalerOf(context),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 18,
                    bottom: 18,
                    child: SizedBox(
                      width: 180,
                      child: GlassmorphicContainer(
                        padding: const EdgeInsets.all(12),
                        fillColor: tokens.glassFill,
                        opacity: tokens.glassOpacity,
                        blurSigma: tokens.blurSigma,
                        refractionColors: [
                          tokens.glassBorderStart,
                          tokens.glassBorderEnd,
                        ],
                        renderQuality: quality,
                        child: Text(
                          'A calm pattern is emerging.',
                          style: TextStyle(
                            color: tokens.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemePreviewPainter extends CustomPainter {
  const _ThemePreviewPainter(this.style, this.textScaler);

  final MemoryGraphVisualStyle style;
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = style.background);
    final points = [
      const Offset(95, 90),
      const Offset(250, 52),
      const Offset(390, 112),
      const Offset(220, 190),
    ];
    final edgePaint = Paint()
      ..color = style.edge.withValues(alpha: .6)
      ..strokeWidth = 2;
    for (final pair in const [
      [0, 1],
      [1, 2],
      [1, 3],
      [0, 3],
    ]) {
      canvas.drawLine(points[pair[0]], points[pair[1]], edgePaint);
    }
    for (var index = 0; index < points.length; index++) {
      final color = style.nodePalette[index % style.nodePalette.length];
      canvas.drawCircle(
        points[index],
        24 + style.glowDiffusion * 8,
        Paint()..color = color.withValues(alpha: .12),
      );
      canvas.drawCircle(points[index], 12, Paint()..color = color);
    }
    final label = TextPainter(
      text: TextSpan(
        text: 'Future self',
        style: TextStyle(
          color: style.labelText,
          backgroundColor: style.labelSurface,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout(maxWidth: 100);
    label.paint(canvas, points[2] + const Offset(-28, 18));
  }

  @override
  bool shouldRepaint(covariant _ThemePreviewPainter oldDelegate) =>
      oldDelegate.style != style || oldDelegate.textScaler != textScaler;
}

class _StudioSlider extends StatelessWidget {
  const _StudioSlider({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.valueLabel,
    required this.onChanged,
    required this.onChangeEnd,
    this.min = 0,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String valueLabel;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    value: valueLabel,
    slider: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(valueLabel, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ],
    ),
  );
}

class _ColorPreview extends StatelessWidget {
  const _ColorPreview({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      key: const Key('theme_accent_preview'),
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
    ),
  );
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 16,
    height: 16,
    margin: const EdgeInsets.only(right: 5),
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

GlassRenderQuality _quality(GlassEffectPreference preference) =>
    switch (preference) {
      GlassEffectPreference.automatic ||
      GlassEffectPreference.full => GlassRenderQuality.full,
      GlassEffectPreference.reduced => GlassRenderQuality.reduced,
      GlassEffectPreference.off => GlassRenderQuality.off,
    };

extension on ThemeArchetype {
  String get label => switch (this) {
    ThemeArchetype.obsidian => 'Obsidian OLED',
    ThemeArchetype.parchment => 'Parchment',
    ThemeArchetype.cyberMatrix => 'Cyber-Matrix',
    ThemeArchetype.dynamicSystem => 'Dynamic System',
  };

  String get subtitle => switch (this) {
    ThemeArchetype.obsidian => 'Pitch black · cyan violet',
    ThemeArchetype.parchment => 'Warm paper · quiet sepia',
    ThemeArchetype.cyberMatrix => 'Amber · emerald signal',
    ThemeArchetype.dynamicSystem => 'Follows your device',
  };
}

extension on GlassEffectPreference {
  String get label => switch (this) {
    GlassEffectPreference.automatic => 'Automatic',
    GlassEffectPreference.full => 'Full effects',
    GlassEffectPreference.reduced => 'Reduced effects',
    GlassEffectPreference.off => 'Effects off',
  };
}
