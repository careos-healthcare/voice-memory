import 'package:flutter/material.dart';

import '../../../features/theme_system/theme_models.dart';
import '../../../features/theme_system/visual_theme_tokens.dart';
import '../glassmorphic_container.dart';

Future<T?> showCanvasFeaturePanel<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? routeName,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.black.withValues(alpha: .38),
  routeSettings: RouteSettings(name: routeName),
  builder: (context) {
    final tokens =
        Theme.of(context).extension<VisualThemeTokens>() ??
        VisualThemeTokens.resolve(
          ThemePreferences.defaultPreferences,
          Theme.of(context).brightness,
        );
    return FractionallySizedBox(
      heightFactor: .92,
      child: GlassmorphicContainer(
        radius: const BorderRadius.vertical(top: Radius.circular(28)),
        padding: EdgeInsets.zero,
        fillColor: tokens.glassFill,
        opacity: tokens.glassOpacity,
        blurSigma: tokens.blurSigma,
        refractionColors: [tokens.glassBorderStart, tokens.glassBorderEnd],
        renderQuality: _quality(tokens.glassEffects),
        child: Material(
          key: const Key('canvas_feature_panel'),
          color: Colors.transparent,
          child: builder(context),
        ),
      ),
    );
  },
);

GlassRenderQuality _quality(GlassEffectPreference preference) =>
    switch (preference) {
      GlassEffectPreference.automatic ||
      GlassEffectPreference.full => GlassRenderQuality.full,
      GlassEffectPreference.reduced => GlassRenderQuality.reduced,
      GlassEffectPreference.off => GlassRenderQuality.off,
    };
