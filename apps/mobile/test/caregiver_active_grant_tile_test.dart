import 'package:archiveme_mobile/features/caregiver/caregiver_access_service.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_copy.dart';
import 'package:archiveme_mobile/features/caregiver/views/caregiver_active_grant_tile.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CaregiverActiveGrant _sampleGrant({bool isCurrentSession = true}) {
  return CaregiverActiveGrant(
    tokenId: 'token-tile-1',
    caregiverId: 'caregiver-ada',
    subjectAccountId: 'subject-1',
    grantedAt: DateTime.utc(2026, 2, 1, 14, 30),
    expiresAt: DateTime.utc(2026, 12, 31, 23, 59),
    isCurrentSession: isCurrentSession,
  );
}

void main() {
  testWidgets('shows caregiver id, session badge, and revoke action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CaregiverActiveGrantTile(
            grant: _sampleGrant(),
            onRevoke: () {},
          ),
        ),
      ),
    );

    expect(find.text('caregiver-ada'), findsOneWidget);
    expect(find.text(CaregiverCopy.currentSessionBadge), findsOneWidget);
    expect(find.text(CaregiverCopy.revokeAccessCta), findsOneWidget);
    expect(find.textContaining(CaregiverCopy.grantedAtLabel), findsOneWidget);
    expect(find.textContaining(CaregiverCopy.expiresAtLabel), findsOneWidget);
  });

  testWidgets('invokes onRevoke when revoke is tapped', (tester) async {
    var revokeCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CaregiverActiveGrantTile(
            grant: _sampleGrant(),
            onRevoke: () => revokeCount++,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('caregiver_revoke_access_token-tile-1')));
    await tester.pump();

    expect(revokeCount, 1);
  });

  testWidgets('disables revoke while revoking', (tester) async {
    var revokeCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CaregiverActiveGrantTile(
            grant: _sampleGrant(),
            isRevoking: true,
            onRevoke: () => revokeCount++,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(CaregiverCopy.revokeAccessCta), findsNothing);

    final button = tester.widget<OutlinedButton>(
      find.byKey(const Key('caregiver_revoke_access_token-tile-1')),
    );
    expect(button.onPressed, isNull);
    expect(revokeCount, 0);
  });

  testWidgets('hides current session badge when not active session', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CaregiverActiveGrantTile(
            grant: _sampleGrant(isCurrentSession: false),
            onRevoke: () {},
          ),
        ),
      ),
    );

    expect(find.text('caregiver-ada'), findsOneWidget);
    expect(find.text(CaregiverCopy.currentSessionBadge), findsNothing);
  });
}
