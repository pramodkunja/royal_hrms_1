import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/features/approvals/presentation/widgets/approvals_ui.dart';
import 'package:mobile_app/features/attendance/data/models/attendance_models.dart';
import 'package:mobile_app/features/attendance/domain/entities/attendance_entity.dart';
import 'package:mobile_app/features/attendance/presentation/widgets/late_justification_card.dart';

import '../../visual/late_justification_visual_test.dart' show row, longReason, open, Server, allStatuses;

// Task 111 — Late Justifications card: details, status/approval rendering, long reasons,
// permission-aware action, responsive. Synthetic data only. Workflow (approve / reject / resubmit
// payloads, remarks required) stays covered by late_justification_review_test.dart.

HrCorrectionRowEntity entity(Map<String, dynamic> j) => HrCorrectionRowModel.fromJson(j);

Future<void> pumpCard(WidgetTester t, Map<String, dynamic> j,
    {double width = 393, double scale = 1, VoidCallback? onOpen, bool dark = false}) async {
  t.view.physicalSize = Size(width, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  AppColors.applyMode(dark);
  addTearDown(() => AppColors.applyMode(false));
  await t.pumpWidget(MaterialApp(
    builder: (c, child) =>
        MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
    home: Scaffold(
        body: SingleChildScrollView(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: LateJustificationCard(row: entity(j), onOpen: onOpen ?? () {})))),
  ));
}

void main() {
  group('lateApprovalSteps', () {
    test('pending: manager awaiting, HR not reached (not collapsed into one status)', () {
      final s = lateApprovalSteps(entity(row('1')));
      expect(s.map((e) => e.level), ['Manager (L1)', 'HR (L2)']);
      expect(s[0].label, 'Awaiting decision');
      expect(s[1].label, 'Not reached');
    });
    test('l2_pending: L1 approved, HR awaiting', () {
      final s = lateApprovalSteps(entity(row('1', status: 'l2_pending', l1Status: 'approved')));
      expect([s[0].label, s[1].label], ['Approved', 'Awaiting decision']);
    });
    test('rejected at L2 keeps remarks; resubmit at L1', () {
      final r = lateApprovalSteps(
          entity(row('1', status: 'rejected', l1Status: 'approved', l2Status: 'rejected', l2Remarks: 'No proof')));
      expect(r[1].label, 'Rejected');
      expect(r[1].remarks, 'No proof');
      final s = lateApprovalSteps(entity(row('2', status: 'resubmit', l1Status: 'resubmit', l1Remarks: 'Redo')));
      expect(s[0].label, 'Asked to resubmit');
    });
    test('no HR approver and no decision: only the manager level is shown', () {
      final j = row('1')..['l2_approver_name'] = null;
      expect(lateApprovalSteps(entity(j)).map((e) => e.level), ['Manager (L1)']);
    });
    test('tones and submitted label', () {
      expect(lateStatusTone('pending'), ApprovalsTone.warning);
      expect(lateStatusTone('l2_pending'), ApprovalsTone.warning);
      expect(lateStatusTone('approved'), ApprovalsTone.success);
      expect(lateStatusTone('rejected'), ApprovalsTone.error);
      expect(lateStatusTone('resubmit'), ApprovalsTone.info);
      expect(lateSubmittedLabel('2026-11-10 11:00'), '10 Nov 2026, 11:00');
      expect(lateSubmittedLabel(''), '');
    });
  });

  group('LateJustificationCard', () {
    testWidgets('shows identity, day, clock-in, reason, status, approvals, proof and Review for an actionable row',
        (t) async {
      var opened = 0;
      await pumpCard(t, row('1'), onOpen: () => opened++);
      expect(find.text('Asha Test'), findsOneWidget);
      expect(find.text('EMP-01 · North Wing'), findsOneWidget);
      expect(find.text('Tue, 10 Nov 2026'), findsOneWidget);
      expect(find.text('Clock-in 10:05'), findsOneWidget);
      expect(find.text('Transport'), findsOneWidget);
      expect(find.text('Bus broke down on the way'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Manager (L1) · Kiran Manager'), findsOneWidget);
      expect(find.text('HR (L2) · Hema HR'), findsOneWidget);
      expect(find.text('Submitted 10 Nov 2026, 11:00'), findsOneWidget);
      expect(find.text('Proof: None'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('late-review-open-1')), matching: find.text('Review')),
          findsOneWidget);
      await t.tap(find.byKey(const Key('late-review-open-1')));
      await t.tap(find.byKey(const Key('late-review-row-1')));
      expect(opened, 2);
    });

    testWidgets('read-only row (no can_action) offers View, not Review', (t) async {
      await pumpCard(t, row('2', status: 'l2_pending', canAction: false, l1Status: 'approved'));
      expect(find.text('Pending (HR)'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('late-review-open-2')), matching: find.text('View')),
          findsOneWidget);
      expect(find.text('Review'), findsNothing);
    });

    for (final (status, label) in [
      ('pending', 'Pending'),
      ('l2_pending', 'Pending (HR)'),
      ('approved', 'Approved'),
      ('rejected', 'Rejected'),
      ('resubmit', 'Resubmission Required'),
    ]) {
      testWidgets('status $status reads "$label"', (t) async {
        await pumpCard(t, row('3', status: status, canAction: false));
        expect(find.descendant(of: find.byKey(const Key('late-card-status-3')), matching: find.text(label)),
            findsOneWidget);
      });
    }

    testWidgets('long justification and long remarks wrap in full (no ellipsis), no overflow at 320dp / 2x', (t) async {
      await pumpCard(
          t,
          row('4',
              explanation: longReason,
              name: 'Alexandria Montgomery-Featherstonehaugh Test',
              status: 'rejected',
              canAction: false,
              l1Status: 'rejected',
              l1Remarks: longReason),
          width: 320,
          scale: 2);
      expect(t.takeException(), isNull);
      final text = t.widget<Text>(
          find.descendant(of: find.byKey(const Key('late-card-explanation-4')), matching: find.byType(Text)));
      expect(text.data, longReason);
      expect(text.maxLines, isNull);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      expect(find.text('“$longReason”'), findsOneWidget);
    });

    testWidgets('proof states: attached, locked, missing (required), none', (t) async {
      await pumpCard(t, row('5', hasDocument: true, canViewDocument: true));
      expect(find.text('Proof: Attached'), findsOneWidget);
      await pumpCard(t, row('5', hasDocument: true));
      expect(find.text('Proof: Attached (locked)'), findsOneWidget);
      await pumpCard(t, row('5', reason: 'medical'));
      expect(find.text('Proof: Missing'), findsOneWidget);
      await pumpCard(t, row('5'));
      expect(find.text('Proof: None'), findsOneWidget);
    });

    testWidgets('resubmission count shown only when > 0; missing clock-in is a dash', (t) async {
      await pumpCard(t, row('6', resubmissions: 2, status: 'resubmit', canAction: false));
      expect(find.text('Resubmitted ×2'), findsOneWidget);
      await pumpCard(t, row('6')..['original_in'] = null);
      expect(find.text('Resubmitted ×2'), findsNothing);
      expect(find.text('Clock-in —'), findsOneWidget);
    });

    for (final w in [320.0, 360.0, 393.0, 600.0, 1000.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets('no overflow at ${w.toInt()}dp x$scale (light) and dark', (t) async {
          final j = row('7',
              explanation: longReason,
              status: 'rejected',
              canAction: false,
              l1Status: 'approved',
              l2Status: 'rejected',
              l2Remarks: 'Not convincing',
              hasDocument: true,
              resubmissions: 1);
          await pumpCard(t, j, width: w, scale: scale);
          expect(t.takeException(), isNull);
          await pumpCard(t, j, width: w, scale: scale, dark: true);
          expect(t.takeException(), isNull);
        });
      }
    }
  });

  group('tab states', () {
    testWidgets('empty (All) vs filtered no-match with Show all', (t) async {
      await open(t, server: Server([]), filter: 'all');
      expect(find.text('No late-arrival justifications have been submitted yet.'), findsOneWidget);
      expect(find.byKey(const Key('approvals-empty-action')), findsNothing);
      await open(t, server: Server([]), filter: 'rejected');
      expect(find.text('Nothing matches this filter.'), findsOneWidget);
      await t.tap(find.byKey(const Key('approvals-empty-action')));
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 80));
      }
      expect(find.text('No late-arrival justifications have been submitted yet.'), findsOneWidget);
    });

    testWidgets('load error offers Retry; access denied does not', (t) async {
      await open(t, server: Server([])..status = 500, filter: 'all');
      expect(find.byKey(const Key('late-review-retry')), findsOneWidget);
      await open(t, server: Server([])..status = 403, filter: 'all');
      expect(find.byKey(const Key('late-review-load-error')), findsOneWidget);
      expect(find.byKey(const Key('late-review-retry')), findsNothing);
    });

    testWidgets('one column on a phone, two from 600dp; count line', (t) async {
      await open(t, size: const Size(393, 3000));
      expect(find.text('6 requests'), findsOneWidget);
      final a = t.getTopLeft(find.byKey(const Key('late-review-row-1'))).dx;
      final b = t.getTopLeft(find.byKey(const Key('late-review-row-2'))).dx;
      expect(a, b);
      await open(t, size: const Size(800, 3000));
      expect(t.getTopLeft(find.byKey(const Key('late-review-row-2'))).dx,
          greaterThan(t.getTopLeft(find.byKey(const Key('late-review-row-1'))).dx));
      expect(allStatuses(), isNotEmpty);
    });
  });
}
