import 'dart:async';

import 'package:archiveme_mobile/core/theme/serene_theme.dart';
import 'package:archiveme_mobile/features/onboarding/providers/onboarding_provider.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/widgets/archive/view_evidence_inline_link.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// First-launch voice conversation. Speech, the orb, or typing can finish it.
class ConversationalOnboardingScreen extends StatefulWidget {
  const ConversationalOnboardingScreen({
    super.key,
    this.session,
    this.onFinished,
    this.pace = const Duration(seconds: 8),
  });

  final OnboardingSession? session;
  final ValueChanged<OnboardingBaseline>? onFinished;
  final Duration? pace;

  @override
  State<ConversationalOnboardingScreen> createState() =>
      _ConversationalOnboardingScreenState();
}

class _ConversationalOnboardingScreenState
    extends State<ConversationalOnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final OnboardingSession _session;
  late final bool _ownsSession;
  late final AnimationController _pulse;
  late final TextEditingController _typed;
  var _reported = false;

  @override
  void initState() {
    super.initState();
    _ownsSession = widget.session == null;
    _session =
        widget.session ??
        OnboardingSession(
          pace: widget.pace,
          store: AppServices.isInitialized
              ? PrefsOnboardingCompletionStore(AppServices.instance.prefs)
              : MemoryOnboardingCompletionStore(),
        );
    _typed = TextEditingController();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    unawaited(_pulse.repeat(reverse: true));
    _session.addListener(_onSession);
    unawaited(_session.start());
  }

  @override
  void dispose() {
    _session.removeListener(_onSession);
    _pulse.dispose();
    _typed.dispose();
    if (_ownsSession) {
      _session.dispose();
    }
    super.dispose();
  }

  void _onSession() {
    if (!mounted) return;
    setState(() {});
    if (_session.phase != OnboardingPhase.done || _reported) return;
    if (_session.baseline == null) return;
    _reported = true;
    final baseline = _session.baseline!;
    final finished = widget.onFinished;
    if (finished != null) {
      finished(baseline);
      return;
    }
    if (GoRouter.maybeOf(context) != null) {
      context.go(RouteCatalog.recordHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseline = _session.baseline;
    if (_session.phase == OnboardingPhase.done && baseline != null) {
      return OnboardingBaselineHome(baseline: baseline);
    }
    final scale = 1 + (0.06 * _pulse.value) + (0.14 * _session.level);
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: SereneTheme.canvas),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
            child: Column(
              children: [
                Text(
                  _session.prompt,
                  key: const Key('onboarding_prompt'),
                  textAlign: TextAlign.center,
                  style: SereneTheme.textTheme(SereneTheme.ink).headlineSmall,
                ),
                const Spacer(),
                GestureDetector(
                  key: const Key('onboarding_orb'),
                  onTap: _session.tapOrb,
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 168,
                      height: 168,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [SereneTheme.foam, SereneTheme.blush],
                        ),
                        boxShadow: SereneTheme.softShadow,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  _session.transcript,
                  key: const Key('onboarding_transcript'),
                  textAlign: TextAlign.center,
                  style: SereneTheme.textTheme(SereneTheme.ink).bodyLarge,
                ),
                const Spacer(),
                if (_session.typing) ...[
                  TextField(
                    key: const Key('onboarding_type_field'),
                    controller: _typed,
                    decoration: const InputDecoration(
                      hintText: 'Type your answer',
                    ),
                  ),
                  TextButton(
                    key: const Key('onboarding_type_submit'),
                    onPressed: () {
                      _session.submitTyped(_typed.text);
                      _typed.clear();
                    },
                    child: const Text('Continue'),
                  ),
                ],
                TextButton(
                  key: const Key('onboarding_skip_type'),
                  onPressed: () {
                    if (!_session.typing) {
                      _session.beginTyping();
                      return;
                    }
                    if (_typed.text.trim().isEmpty) {
                      _session.skip();
                      return;
                    }
                    _session.submitTyped(_typed.text);
                    _typed.clear();
                  },
                  child: Text(
                    'Skip / Type instead',
                    style: SereneTheme.textTheme(SereneTheme.ink).labelLarge,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Home surface for the baseline created during onboarding.
class OnboardingBaselineHome extends StatelessWidget {
  const OnboardingBaselineHome({
    required this.baseline,
    super.key,
    this.onViewEvidence,
  });

  final OnboardingBaseline baseline;
  final VoidCallback? onViewEvidence;

  @override
  Widget build(BuildContext context) {
    final text = SereneTheme.textTheme(SereneTheme.ink);
    return DecoratedBox(
      key: const Key('onboarding_home'),
      decoration: const BoxDecoration(gradient: SereneTheme.canvas),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Core Memory', style: text.titleMedium),
              const SizedBox(height: 8),
              Text(
                baseline.coreMemory,
                key: const Key('onboarding_core_memory'),
                style: text.bodyLarge,
              ),
              const SizedBox(height: 24),
              Text('Life Patterns', style: text.titleMedium),
              const SizedBox(height: 8),
              for (final pattern in baseline.lifePatterns)
                Padding(
                  key: Key('onboarding_life_patterns_$pattern'),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(pattern, style: text.bodyLarge),
                ),
              ViewEvidenceInlineLink(
                entryIds: <String>[baseline.coreMemoryId],
                surface: 'onboarding_baseline',
                claimContext: 'Life Patterns',
                onViewEvidence: onViewEvidence ?? () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}
