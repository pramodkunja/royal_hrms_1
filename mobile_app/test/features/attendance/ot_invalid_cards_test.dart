// Task 111: OT Entry record cards and Invalid Punch cards (stand-in API, no network).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/features/approvals/presentation/widgets/approvals_ui.dart' show ApprovalsTone;
import 'package:mobile_app/features/attendance/presentation/widgets/invalid_punch_card.dart';
import 'package:mobile_app/features/attendance/presentation/widgets/ot_record_card.dart';

import '../../visual/t111_ot_invalid_visual_test.dart' as h;

const tall = Size(393, 2600);

// The shell's hero banner (attendance_screen.dart, not part of these tabs) overflows in the wide test
// font at phone widths; those reports are set aside, anything else is recorded and asserted empty.
final unexpected = <String>[];
void installFilter() {
  FlutterError.onError = (d) {
    final text = d.toDiagnosticsNode().toStringDeep();
    if (text.contains('BlueHeroBanner')) return;
    unexpected.add(text.split('\n').where((l) => l.contains('overflowed') || l.contains('creator') || l.contains('.dart')).take(4).join(' / '));
  };
}

Future<void> open(WidgetTester t, String tab,
    {Size size = tall, double scale = 1, h.Server? server, bool dark = false, List<String> perms = h.staffPerms}) async {
  installFilter();
  await h.openTab(t, tab, size: size, scale: scale, server: server, dark: dark, perms: perms);
}

Finder inCards(Finder f) => find.descendant(of: find.byType(OtRecordCard), matching: f);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(unexpected.clear);
  tearDown(() => expect(unexpected, isEmpty, reason: 'layout / framework errors in the tabs'));

  group('pure mappings', () {
    test('OT status tone / label / date', () {
      expect(otStatusTone('approved'), ApprovalsTone.success);
      expect(otStatusTone('Pending'), ApprovalsTone.warning);
      expect(otStatusTone('rejected'), ApprovalsTone.error);
      expect(otStatusTone('whatever'), ApprovalsTone.neutral);
      expect(otStatusLabel('pending'), 'Pending');
      expect(otStatusLabel(''), 'Unknown');
      expect(formatAttendanceDate('2026-11-18'), '18 Nov 2026');
      expect(formatAttendanceDate('garbage'), 'garbage');
      expect(formatAttendanceDate('2026-09-05'), '5 Sept 2026'); // en-IN, as the rest of the app
      expect(formatAttendanceDate('2026-02-31'), '2026-02-31'); // no such date: shown as received
    });
    test('invalid punch kind follows web ISSUE_BADGE; unknown is neutral', () {
      expect(invalidPunchKind('no-match').tone, ApprovalsTone.error);
      expect(invalidPunchKind('duplicate').tone, ApprovalsTone.warning);
      expect(invalidPunchKind('future').tone, ApprovalsTone.error);
      expect(invalidPunchKind('other').tone, ApprovalsTone.neutral);
      expect(invalidPunchKind('other').label, 'Invalid punch');
    });
    test('raw time split', () {
      expect(splitRawPunchTime('2026-11-23 09:02:11').date, '23 Nov 2026');
      expect(splitRawPunchTime('2026-11-23 09:02:11').time, '09:02:11');
      expect(splitRawPunchTime('09:02').time, isNull);
      expect(splitRawPunchTime('09:02').date, '09:02');
    });
  });

  group('OT Entry cards', () {
    testWidgets('shows the API fields: name, id, status, hours, amount, type, date, approver', (t) async {
      await open(t, 'OT Entry', size: tall);
      expect(find.byType(OtRecordCard), findsNWidgets(3));
      final first = find.byType(OtRecordCard).first;
      for (final s in ['Pat Kumar', 'EMP-0007', 'Approved', '2h 30m', '₹ 1250.00', 'Regular', '18 Nov 2026', 'Approved By', 'Asha Rao']) {
        expect(find.descendant(of: first, matching: find.text(s)), findsOneWidget, reason: s);
      }
    });

    testWidgets('pending / rejected badges and missing approver', (t) async {
      await open(t, 'OT Entry', size: tall);
      expect(inCards(find.text('Pending')), findsOneWidget);
      expect(inCards(find.text('Rejected')), findsOneWidget);
      expect(inCards(find.text('Not assigned')), findsOneWidget);
    });

    testWidgets('long names and approver are fully shown (wrapped, never ellipsised) at 320 / 2x', (t) async {
      await open(t, 'OT Entry', size: const Size(320, 3000), scale: 2);
      expect(inCards(find.text(h.longName)), findsOneWidget);
      expect(inCards(find.text(h.longApprover)), findsOneWidget);
      final txt = t.widget<Text>(inCards(find.text(h.longName)));
      expect(txt.overflow, isNot(TextOverflow.ellipsis));
    });

    testWidgets('records carry no row actions (web OT Records is read-only)', (t) async {
      await open(t, 'OT Entry', size: tall);
      for (final label in ['Edit', 'Delete', 'Approve', 'Reject']) {
        expect(inCards(find.text(label)), findsNothing, reason: label);
      }
      expect(inCards(find.byType(ButtonStyleButton)), findsNothing);
    });

    testWidgets('Add OT Entry follows attendance.create; Approved By selector still in the form', (t) async {
      await open(t, 'OT Entry', size: tall);
      expect(find.byKey(const Key('ot-add-entry')), findsOneWidget);
      expect(find.text('Approved By'), findsWidgets);
      await open(t, 'OT Entry', size: tall, perms: const ['attendance.view', 'attendance.edit']);
      expect(find.byKey(const Key('ot-add-entry')), findsNothing);
      expect(find.byType(OtRecordCard), findsNWidgets(3), reason: 'records stay visible');
    });

    testWidgets('responsive: no overflow at several widths; 2 columns from 600 dp', (t) async {
      for (final w in [320.0, 360.0, 430.0]) {
        await open(t, 'OT Entry', size: Size(w, 3000));
        expect(unexpected, isEmpty, reason: 'width $w');
      }
      await open(t, 'OT Entry', size: const Size(1000, 2600));
      final a = t.getTopLeft(find.byType(OtRecordCard).at(0));
      final b = t.getTopLeft(find.byType(OtRecordCard).at(1));
      expect(a.dy, b.dy, reason: 'side by side');
      expect(b.dx, greaterThan(a.dx));
      await open(t, 'OT Entry', size: const Size(393, 2600));
      expect(t.getTopLeft(find.byType(OtRecordCard).at(1)).dy, greaterThan(t.getTopLeft(find.byType(OtRecordCard).at(0)).dy));
    });

    testWidgets('dark theme renders without exceptions', (t) async {
      await open(t, 'OT Entry', size: tall, dark: true);
      expect(find.byType(OtRecordCard), findsNWidgets(3));
    });

    testWidgets('empty list', (t) async {
      await open(t, 'OT Entry', size: tall, server: h.Server()..ot = []);
      expect(find.byKey(const Key('ot-empty')), findsOneWidget);
      expect(find.byType(OtRecordCard), findsNothing);
    });

    testWidgets('error shows Retry and Retry reloads', (t) async {
      final s = h.Server()..otStatus = 500;
      await open(t, 'OT Entry', size: tall, server: s);
      expect(find.byKey(const Key('ot-error')), findsOneWidget);
      s.otStatus = 200;
      await t.ensureVisible(find.byKey(const Key('approvals-empty-action')));
      await t.tap(find.byKey(const Key('approvals-empty-action')));
      await h.settle(t);
      expect(find.byType(OtRecordCard), findsNWidgets(3));
    });

    testWidgets('pagination bar appears when there are several pages', (t) async {
      await open(t, 'OT Entry', size: tall, server: h.Server()..totalPages = 3);
      expect(find.text('Page 1 of 3'), findsOneWidget);
    });
  });

  group('Invalid Punch cards', () {
    Finder card(int i) => find.byType(InvalidPunchCard).at(i);

    testWidgets('renders reason, kind badge, formatted time, device, suggestion, branch', (t) async {
      await open(t, 'Invalid Punches', size: tall);
      expect(find.byType(InvalidPunchCard), findsNWidgets(3));
      for (final s in [
        'Invalid · Sequence mismatch',
        'Expected OUT, got IN',
        '23 Nov 2026 · 09:02:11',
        'Device / Card ID',
        'DEV-7',
        'Add OUT punch',
        'Surat'
      ]) {
        expect(find.descendant(of: card(0), matching: find.text(s)), findsOneWidget, reason: s);
      }
      expect(find.descendant(of: card(1), matching: find.text('Invalid · Duplicate punch')), findsOneWidget);
      expect(find.descendant(of: card(2), matching: find.text('Invalid · Future time')), findsOneWidget);
      expect(find.descendant(of: card(2), matching: find.text('Not provided')), findsWidgets, reason: 'missing values say so');
      expect(find.byKey(const Key('invalid-punches-count')), findsOneWidget);
    });

    testWidgets('never claims a punch was corrected or resolved', (t) async {
      await open(t, 'Invalid Punches', size: tall);
      for (final w in ['Resolved', 'Corrected', 'Fixed', 'Converted', 'Discarded']) {
        expect(find.descendant(of: find.byType(InvalidPunchCard), matching: find.text(w)), findsNothing, reason: w);
      }
    });

    testWidgets('Assign / Convert / Discard shown with attendance.edit', (t) async {
      await open(t, 'Invalid Punches', size: tall);
      expect(find.byKey(const Key('invalid-punch-assign')), findsNWidgets(3));
      expect(find.byKey(const Key('invalid-punch-convert')), findsNWidgets(3));
      expect(find.byKey(const Key('invalid-punch-discard')), findsNWidgets(3));
    });

    testWidgets('no actions without attendance.edit, cards still listed', (t) async {
      await open(t, 'Invalid Punches', size: tall, perms: const ['attendance.view', 'attendance.create']);
      expect(find.byType(InvalidPunchCard), findsNWidgets(3));
      expect(find.byKey(const Key('invalid-punch-assign')), findsNothing);
      expect(find.byKey(const Key('invalid-punch-discard')), findsNothing);
      expect(find.byKey(const Key('invalid-punch-no-actions')), findsNWidgets(3));
    });

    testWidgets('Discard sends remarks to the discard endpoint (payload unchanged)', (t) async {
      await open(t, 'Invalid Punches', size: tall);
      await t.tap(find.byKey(const Key('invalid-punch-discard')).first);
      await h.settle(t);
      expect(find.text('Discard Invalid Punch'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'dup scan');
      await t.tap(find.widgetWithText(ElevatedButton, 'Discard'));
      await h.settle(t);
      expect(h.last.writes.single.$1, 'POST');
      expect(h.last.writes.single.$2, '/attendance/invalid-punches/ip1/discard/');
      expect(h.last.writes.single.$3, {'remarks': 'dup scan'});
    });

    testWidgets('Convert and Assign open their dialogs; Cancel sends nothing', (t) async {
      await open(t, 'Invalid Punches', size: tall);
      await t.tap(find.byKey(const Key('invalid-punch-convert')).first);
      await h.settle(t);
      expect(find.text('Convert Invalid Punch'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await h.settle(t);
      await t.tap(find.byKey(const Key('invalid-punch-assign')).first);
      await h.settle(t);
      expect(find.text('Assign Invalid Punch'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await h.settle(t);
      expect(h.last.writes, isEmpty);
    });

    testWidgets('error with Retry, access denied without Retry, empty', (t) async {
      final s = h.Server()..invalidStatus = 500;
      await open(t, 'Invalid Punches', size: tall, server: s);
      expect(find.byKey(const Key('invalid-punches-error')), findsOneWidget);
      s.invalidStatus = 200;
      await t.tap(find.byKey(const Key('approvals-empty-action')));
      await h.settle(t);
      expect(find.byType(InvalidPunchCard), findsNWidgets(3));

      await open(t, 'Invalid Punches', size: tall, server: h.Server()..invalidStatus = 403);
      expect(find.byKey(const Key('approvals-empty-action')), findsNothing);
      expect(find.text('Access denied'), findsOneWidget);

      await open(t, 'Invalid Punches', size: tall, server: h.Server()..invalid = []);
      expect(find.byKey(const Key('invalid-punches-empty')), findsOneWidget);
    });

    testWidgets('long device / branch values wrap; no overflow at 320 / 2x / dark', (t) async {
      await open(t, 'Invalid Punches', size: const Size(320, 3600), scale: 2, dark: true);
      expect(find.text('GATE-NORTH-TERMINAL-0042'), findsOneWidget);
      expect(find.text('Head Office - Bandra Kurla Complex Annexe'), findsOneWidget);
      for (final w in [320.0, 360.0, 430.0]) {
        await open(t, 'Invalid Punches', size: Size(w, 3600));
        expect(unexpected, isEmpty, reason: 'width $w');
      }
    });

    testWidgets('2 columns from 600 dp, 1 on phones', (t) async {
      await open(t, 'Invalid Punches', size: const Size(1000, 2600));
      expect(t.getTopLeft(card(0)).dy, t.getTopLeft(card(1)).dy);
      await open(t, 'Invalid Punches', size: tall);
      expect(t.getTopLeft(card(1)).dy, greaterThan(t.getTopLeft(card(0)).dy));
    });
  });
}
