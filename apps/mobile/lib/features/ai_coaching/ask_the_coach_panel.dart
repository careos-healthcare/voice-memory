import 'package:archiveme_mobile/features/ai_coaching/ask_the_coach_service.dart';
import 'package:archiveme_mobile/features/monetization/revenuecat_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Chat box for asking the local coach about past notes.
class AskTheCoachPanel extends ConsumerStatefulWidget {
  const AskTheCoachPanel({required this.service, super.key});

  final AskTheCoachService service;

  @override
  ConsumerState<AskTheCoachPanel> createState() => _AskTheCoachPanelState();
}

class _AskTheCoachPanelState extends ConsumerState<AskTheCoachPanel> {
  final _question = TextEditingController();
  final _turns = <_CoachTurn>[];
  var _busy = false;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ask the coach', key: Key('ask_the_coach_title')),
        const SizedBox(height: 8),
        for (final turn in _turns)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(turn.text, key: Key(turn.keyName)),
          ),
        TextField(
          key: const Key('ask_the_coach_input'),
          controller: _question,
          decoration: const InputDecoration(hintText: 'Ask about a past note'),
          onSubmitted: (_) => _send(),
        ),
        TextButton(
          key: const Key('ask_the_coach_send'),
          onPressed: _busy ? null : _send,
          child: const Text('Ask'),
        ),
      ],
    );
  }

  Future<void> _send() async {
    final question = _question.text.trim();
    if (question.isEmpty || _busy) return;
    final entitlement = ref.read(premiumEntitlementProvider);
    if (!FreeTierGate.allowsDeeperCoaching(entitlement, offline: false)) {
      setState(() {
        _turns.add(
          const _CoachTurn(
            'coach_locked',
            'Deeper coaching is part of Premium. Your notes stay on this device.',
          ),
        );
      });
      return;
    }
    setState(() {
      _busy = true;
      _turns.add(_CoachTurn('you:${_turns.length}', question));
    });
    final reply = await widget.service.ask(question);
    if (!mounted) return;
    setState(() {
      _question.clear();
      _busy = false;
      _turns.add(_CoachTurn('coach_reply', reply.answer));
    });
  }
}

class _CoachTurn {
  const _CoachTurn(this.keyName, this.text);

  final String keyName;
  final String text;
}
