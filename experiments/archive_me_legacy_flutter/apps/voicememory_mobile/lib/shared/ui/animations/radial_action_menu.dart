import 'package:flutter/material.dart';

class RadialActionMenu extends StatelessWidget {
  const RadialActionMenu({
    super.key,
    required this.onVoiceCapture,
    required this.onTypeCapture,
    this.onGraphConversation,
    required this.onDismiss,
  });

  final VoidCallback onVoiceCapture;
  final VoidCallback onTypeCapture;
  final VoidCallback? onGraphConversation;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Stack(
    key: const Key('radial_action_menu'),
    children: [
      Positioned.fill(
        child: GestureDetector(
          key: const Key('canvas_capture_dimmer'),
          onTap: onDismiss,
          child: ColoredBox(color: Colors.black.withValues(alpha: .48)),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 8,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutBack,
          tween: Tween(begin: .2, end: 1),
          builder: (context, value, child) => Transform.scale(
            scale: value,
            alignment: Alignment.bottomCenter,
            child: child,
          ),
          child: Semantics(
            container: true,
            label: 'Capture actions expanded over Memory Graph',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  runAlignment: WrapAlignment.center,
                  spacing: 20,
                  runSpacing: 8,
                  children: [
                    _RadialAction(
                      key: const Key('radial_type_capture'),
                      icon: Icons.keyboard_alt_outlined,
                      label: 'Type',
                      onTap: onTypeCapture,
                    ),
                    _RadialAction(
                      key: const Key('radial_voice_capture'),
                      icon: Icons.mic,
                      label: 'Record',
                      onTap: onVoiceCapture,
                    ),
                    if (onGraphConversation != null)
                      _RadialAction(
                        key: const Key('radial_graph_conversation'),
                        icon: Icons.record_voice_over,
                        label: 'Talk to graph',
                        onTap: onGraphConversation!,
                      ),
                  ],
                ),
                Container(
                  key: const Key('recording_halo'),
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: .5),
                        Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.graphic_eq,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class _RadialAction extends StatelessWidget {
  const _RadialAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FilledButton.tonalIcon(
    onPressed: onTap,
    icon: Icon(icon),
    label: Text(label),
  );
}
