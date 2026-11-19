import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../features/approvals/team_approvals_redesign_test.dart' as t;
import 'shot_harness.dart';

// Task 101.1 — render evidence for the Team Approvals tab (see shot_harness.dart;
// runs only with T1011_SHOTS=1).

t.Server crowd() => t.Server(
      leaves: [
        t.leave('1042', 'Anika Sharma', reason: 'Family function out of town, travelling the night before'),
        t.leave('1088', 'Rohan Mehta',
            status: 'l2_pending',
            lop: 1,
            start: '2026-11-24',
            end: '2026-11-26',
            reason: 'Fever; doctor advised two days of rest'),
      ],
      expenses: [t.expense(7, 'Kavya Iyer')],
      corrections: [t.correction('1120', 'Imran Qureshi')],
      wfhs: [t.wfh('1131', 'Sneha Patel')],
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('team approvals — top of the inbox', (tester) async {
    await t.pump(tester, t.approver, crowd(), size: const Size(390, 1500));
    await shoot(tester, '01_team_approvals');
  }, skip: !shotsEnabled);

  testWidgets('team approvals — request detail sheet', (tester) async {
    await t.pump(tester, t.approver, crowd(), size: const Size(390, 1500));
    await t.tap(tester, find.byKey(const Key('approval-details-1042')));
    await shoot(tester, '03_detail_sheet');
  }, skip: !shotsEnabled);

  testWidgets('team approvals — reject confirmation dialog', (tester) async {
    await t.pump(tester, t.approver, crowd(), size: const Size(390, 844));
    await t.scrollTo(tester, find.byKey(const Key('approval-reject-1042')));
    await t.tap(tester, find.byKey(const Key('approval-reject-1042')));
    await shoot(tester, '04_reject_dialog');
  }, skip: !shotsEnabled);

  testWidgets('team approvals — selection mode with the bulk bar', (tester) async {
    await t.pump(tester, t.approver, crowd(), size: const Size(390, 844));
    await t.enterSelectMode(tester);
    await t.tapPinned(tester, find.byKey(const Key('approvals-select-page')));
    await shoot(tester, '02_team_selection_mode');
  }, skip: !shotsEnabled);

  testWidgets('team approvals — bulk reject dialog', (tester) async {
    await t.pump(tester, t.approver, crowd(), size: const Size(390, 844));
    await t.enterSelectMode(tester);
    await t.tapPinned(tester, find.byKey(const Key('approvals-select-page')));
    await t.tapPinned(tester, find.byKey(const Key('approvals-bulk-reject')));
    await shoot(tester, '05_bulk_reject_dialog');
  }, skip: !shotsEnabled);

  testWidgets('team approvals — 320 dp wide at 2.0x text', (tester) async {
    await t.pump(tester, t.approver, crowd(), size: const Size(320, 1700), textScale: 2);
    await shoot(tester, '06_team_320dp_2x_text');
  }, skip: !shotsEnabled);

  // ── States (Task 101.3) ──────────────────────────────────────────────────
  testWidgets('team approvals — empty: nothing is waiting', (tester) async {
    await t.pump(tester, t.approver, t.Server(), size: const Size(390, 844));
    await shoot(tester, '01e_team_empty');
  }, skip: !shotsEnabled);

  testWidgets('team approvals — no results for the filters', (tester) async {
    await t.pump(tester, t.approver, crowd(), size: const Size(390, 844));
    await tester.enterText(find.byKey(const Key('approvals-search')), 'zzzz');
    await t.settle(tester);
    await shoot(tester, '01f_team_no_match');
  }, skip: !shotsEnabled);

  testWidgets('team approvals — the load failed (not a success look)', (tester) async {
    final s = crowd()..listStatus = 500;
    await t.pump(tester, t.approver, s, size: const Size(390, 844));
    await shoot(tester, '01g_team_error');
  }, skip: !shotsEnabled);

  testWidgets('team approvals — no approval permission', (tester) async {
    await t.pump(tester, t.user(['leave.view']), crowd(), size: const Size(390, 844));
    await shoot(tester, '01h_team_denied');
  }, skip: !shotsEnabled);

  testWidgets('team approvals — filter sheet', (tester) async {
    await t.pump(tester, t.approver, crowd(), size: const Size(390, 844));
    await t.tap(tester, find.byKey(const Key('approvals-filters')));
    await shoot(tester, '01i_filter_sheet');
  }, skip: !shotsEnabled);

  testWidgets('team approvals — active filters shown as chips', (tester) async {
    await t.pump(tester, t.approver, crowd(), size: const Size(390, 844));
    await t.tap(tester, find.byKey(const Key('approvals-filters')));
    await t.tap(tester, find.byKey(const Key('approvals-status-all')));
    await t.tap(tester, find.byKey(const Key('approvals-sort-employee')));
    await t.tap(tester, find.byKey(const Key('approvals-sheet-done')));
    await shoot(tester, '01j_team_filtered');
  }, skip: !shotsEnabled);
}
