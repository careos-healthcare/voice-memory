import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_analyst/archive_belief_visibility.dart';
import 'package:voicememory_mobile/features/archive_theory/archive_theory_models.dart';

void main() {
  test('rejects trait templates and thin evidence', () {
    expect(
      ArchiveBeliefVisibility.isVisibleBelief(
        statement: 'You focus on career',
        confidencePercent: 72,
        evidenceCount: 10,
      ),
      isFalse,
    );
    expect(
      ArchiveBeliefVisibility.isVisibleBelief(
        statement: 'I avoid difficult conversations at work',
        confidencePercent: 0,
        evidenceCount: 5,
      ),
      isFalse,
    );
    expect(
      ArchiveBeliefVisibility.isVisibleBelief(
        statement: 'I avoid difficult conversations at work',
        confidencePercent: 40,
        evidenceCount: 2,
      ),
      isFalse,
    );
    expect(
      ArchiveBeliefVisibility.isVisibleBelief(
        statement: 'I avoid difficult conversations at work',
        confidencePercent: 40,
        evidenceCount: 5,
      ),
      isTrue,
    );
  });

  test('isVisibleTheory mirrors belief rules', () {
    expect(
      ArchiveBeliefVisibility.isVisibleTheory(
        const ArchiveCurrentTheory(
          statement: 'Work delivery pressure dominates my week.',
          confidencePercent: 0,
          evidenceCount: 0,
          counterEvidenceCount: 0,
          lastUpdated: null,
          isConfident: false,
          missingEvidenceMessage: '',
          strengthenEvidenceLines: [],
        ),
      ),
      isFalse,
    );
  });
}
