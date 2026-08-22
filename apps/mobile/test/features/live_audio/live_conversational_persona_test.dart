import 'package:archiveme_mobile/core/user/life_stage_lens.dart';
import 'package:archiveme_mobile/features/live_audio/domain/live_conversational_persona.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiveConversationalPersona', () {
    test('builds baseline instruction without ledger context or lens', () {
      final instruction = LiveConversationalPersona.buildSystemInstruction();

      expect(instruction, isNotEmpty);
      expect(instruction, contains('THE EVIDENCE METHOD'));
      expect(instruction, contains('open-ended follow-up question'));
      expect(instruction, contains('Never use clinical, diagnostic, therapeutic'));
      expect(instruction, contains('Never use CBT, IFS, DBT'));
      expect(instruction, contains('CBT'));
      expect(instruction, contains('diagnosis'));
      expect(instruction, isNot(contains('KNOWN USER EVIDENCE (cite only these')));
      expect(instruction, isNot(contains('ACTIVE LIFE STAGE LENS')));
    });

    test('includes citable fact ledger context when provided', () {
      final instruction = LiveConversationalPersona.buildSystemInstruction(
        recentEvidence: const [
          FactLedgerEntry(
            id: 'fact-1',
            label: 'Core belief',
            value: 'I am not good enough at work',
            factType: 'belief',
          ),
          FactLedgerEntry(
            id: 'fact-2',
            label: 'Contradiction',
            value: 'Said I was done with overtime, then stayed late Friday',
            factType: 'contradiction',
          ),
        ],
      );

      expect(instruction, contains('KNOWN USER EVIDENCE'));
      expect(instruction, contains('[belief] Core belief: I am not good enough at work'));
      expect(instruction, contains('[contradiction] Contradiction:'));
      expect(instruction, contains('do not invent archive history'));
    });

    test('appends lens-specific listening instructions when lens is active', () {
      final instruction = LiveConversationalPersona.buildSystemInstruction(
        activeLens: LifeStageLens.recovery,
      );

      expect(instruction, contains('ACTIVE LIFE STAGE LENS'));
      expect(instruction, contains('RECOVERY / SOBRIETY LENS'));
      expect(instruction, contains('setback-and-return cycles'));
    });

    test('forbids medical and clinical terminology in hard constraints', () {
      final instruction = LiveConversationalPersona.buildSystemInstruction(
        activeLens: LifeStageLens.griefLoss,
      );

      for (final term in [
        'clinical',
        'diagnosis',
        'therapy',
        'CBT',
        'IFS',
        'trauma',
        'medication',
      ]) {
        expect(
          instruction.toLowerCase(),
          contains(term.toLowerCase()),
          reason: 'Expected hard-constraint blocklist to mention $term',
        );
      }
    });
  });
}