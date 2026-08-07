import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../domain/models/live_voice_error_state.dart';
import '../live_voice_session_copy.dart';

class LiveVoiceErrorBoundaryOverlay extends ConsumerWidget {
  const LiveVoiceErrorBoundaryOverlay({
    super.key,
    required this.errorState,
    required this.onRetry,
    required this.onCancel,
    this.busy = false,
  });

  final LiveVoiceErrorState errorState;
  final VoidCallback onRetry;
  final VoidCallback onCancel;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (errorState == LiveVoiceErrorState.none) {
      return const SizedBox.shrink(key: ValueKey('live_voice_error_none'));
    }

    return Positioned.fill(
      key: ValueKey(errorState),
      child: _FadeInWidget(
        child: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: AppColors.textPrimary.withValues(alpha: 0.4),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Card(
                  elevation: 8,
                  color: AppColors.backgroundSecondary,
                  shadowColor: AppColors.shadowColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _iconForError(errorState),
                            color: AppColors.error,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _titleForError(errorState),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _messageForError(errorState),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                key: const Key('live_voice_error_exit_button'),
                                onPressed: busy ? null : onCancel,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  LiveVoiceSessionCopy.exitSession,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: FilledButton(
                                key: const Key('live_voice_error_retry_button'),
                                onPressed: busy ? null : onRetry,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.accentPrimary,
                                  foregroundColor: AppColors.onAccent,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  busy
                                      ? LiveVoiceSessionCopy.reconnecting
                                      : LiveVoiceSessionCopy.tryAgain,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconForError(LiveVoiceErrorState state) {
    return switch (state) {
      LiveVoiceErrorState.networkTimeout => Icons.wifi_off_rounded,
      LiveVoiceErrorState.tokenExpired => Icons.lock_clock_rounded,
      LiveVoiceErrorState.hardwareFailure => Icons.mic_off_rounded,
      LiveVoiceErrorState.unknown => Icons.error_outline_rounded,
      LiveVoiceErrorState.none => Icons.error_outline_rounded,
    };
  }

  static String _titleForError(LiveVoiceErrorState state) {
    return switch (state) {
      LiveVoiceErrorState.networkTimeout => 'Connection Interrupted',
      LiveVoiceErrorState.tokenExpired => 'Session Expired',
      LiveVoiceErrorState.hardwareFailure => 'Microphone Unavailable',
      LiveVoiceErrorState.unknown => 'Something Went Wrong',
      LiveVoiceErrorState.none => '',
    };
  }

  static String _messageForError(LiveVoiceErrorState state) {
    return switch (state) {
      LiveVoiceErrorState.networkTimeout =>
        'Your connection to the live voice server dropped. Check your signal and we\'ll pick up right where we left off.',
      LiveVoiceErrorState.tokenExpired =>
        'Your secure session token has expired. Let\'s quickly refresh your connection details.',
      LiveVoiceErrorState.hardwareFailure =>
        'We lost access to your device\'s microphone. Please check system permissions.',
      LiveVoiceErrorState.unknown =>
        'An unexpected failure occurred while streaming. Let\'s try to reset the pipeline.',
      LiveVoiceErrorState.none => '',
    };
  }
}

class _FadeInWidget extends StatelessWidget {
  const _FadeInWidget({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: child,
    );
  }
}
