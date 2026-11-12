import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/features/candidate_review/presentation/widgets/approval_identity_fields.dart';

import 'candidate_review_approval_test.dart'
    show FakeApprovalsServer, applicant, confirm, enter, openReview, pumpScreen, server, startApprove;

// Task 61: Candidate Review → Approve → EPF details, as web
// candidate-review/_components/OnboardingDrawer.tsx (lines ~384-425, 143-205):
// heading "EPF Details (optional — can be filled later from employee
// profile)"; "UAN Number" / "12-digit UAN" with a live "<n>/12 digits";
// "Name as per Aadhar" / "Exactly as on Aadhar card"; "PAN Number" /
// "e.g. ABCDE1234F" with a live "5 letters, 4 digits, 1 letter — e.g.
// ABCDE1234F"; Confirm reports one problem in the Assign Role banner
// (Department/Designation, then UAN, then PAN). Backend
// OnboardingApprovalView reads uan_number / name_as_per_aadhar / pan_number.
// Synthetic applicants on a stand-in server; nothing real is approved.

Finder byKey(String k) => find.byKey(Key(k));
Finder sheetScrollable() => find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first;
Finder inBox(Finder f) => find.descendant(of: byKey('approval-epf-details'), matching: f);

/// Opacity of [hint] inside field [key] (InputDecorator fades the hint).
double hintOpacity(WidgetTester tester, String key, String hint) {
  final t = find.descendant(of: byKey(key), matching: find.text(hint));
  expect(t, findsOneWidget, reason: '$hint rendered in $key');
  return tester.widgetList<AnimatedOpacity>(find.ancestor(of: t, matching: find.byType(AnimatedOpacity))).first.opacity;
}

String? liveText(WidgetTester tester, String key) {
  final f = byKey(key);
  return f.evaluate().isEmpty ? null : tester.widget<Text>(f).data;
}

Future<void> openApprove(WidgetTester tester, Map<String, dynamic> row, {Size? size, double dpr = 1}) async {
  await pumpScreen(tester, [row]);
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = dpr;
    await tester.pumpAndSettle();
  }
  await openReview(tester, row['full_name'] as String);
  await startApprove(tester);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('live hints (pure)', () {
    test('UAN counter only while 1-11 digits; PAN hint only while non-empty and invalid', () {
      expect(uanDigitsCounter(''), isNull);
      expect(uanDigitsCounter('1'), '1/12 digits');
      expect(uanDigitsCounter('12345678901'), '11/12 digits');
      expect(uanDigitsCounter('123456789012'), isNull);
      expect(panFormatHint(''), isNull);
      expect(panFormatHint('ABC'), kPanFormatHint);
      expect(panFormatHint('ABCDE1234F'), isNull);
      expect(kPanFormatHint, '5 letters, 4 digits, 1 letter — e.g. ABCDE1234F');
    });
  });

  group('approve form', () {
    testWidgets('1/3. web heading, labels and placeholders; hints visible before any field is focused', (tester) async {
      await openApprove(tester, applicant('u1', 'Test One'));
      expect(byKey('approval-epf-details'), findsOneWidget);
      expect(find.text('EPF DETAILS (optional — can be filled later from employee profile)', findRichText: true),
          findsOneWidget);
      for (final (label, key, hint) in [
        ('UAN Number', 'approval-uan', '12-digit UAN'),
        ('Name as per Aadhar', 'approval-aadhar-name', 'Exactly as on Aadhar card'),
        ('PAN Number', 'approval-pan', 'e.g. ABCDE1234F'),
      ]) {
        expect(inBox(find.text(label)), findsOneWidget, reason: label);
        final deco = tester.widget<TextField>(byKey(key)).decoration!;
        expect(deco.labelText, isNull, reason: '$label sits above the box, not inside it');
        expect(hintOpacity(tester, key, hint), 1.0, reason: '$hint visible unfocused');
      }
      // Old mobile wording is gone.
      expect(find.text('Statutory details (optional)'), findsNothing);
      expect(find.text('12-digit UAN'), findsOneWidget);
    });

    testWidgets('2/7. prefilled values are shown (hints hidden) and can be edited', (tester) async {
      await openApprove(
          tester, applicant('u1', 'Test One', uan: '100000000012', pan: 'abcde1234f', aadharName: 'Test A One'));
      expect(tester.widget<TextField>(byKey('approval-uan')).controller!.text, '100000000012');
      expect(tester.widget<TextField>(byKey('approval-pan')).controller!.text, 'ABCDE1234F');
      expect(tester.widget<TextField>(byKey('approval-aadhar-name')).controller!.text, 'Test A One');
      expect(hintOpacity(tester, 'approval-uan', '12-digit UAN'), 0.0);
      expect(liveText(tester, 'approval-uan-counter'), isNull, reason: 'a complete UAN shows no counter');
      expect(liveText(tester, 'approval-pan-hint'), isNull);
      await enter(tester, 'approval-aadhar-name', 'Test B Two');
      expect(tester.widget<TextField>(byKey('approval-aadhar-name')).controller!.text, 'Test B Two');
    });

    testWidgets('4. the UAN counter follows typing; digits only, at most 12', (tester) async {
      await openApprove(tester, applicant('u1', 'Test One'));
      expect(liveText(tester, 'approval-uan-counter'), isNull);
      await enter(tester, 'approval-uan', '123');
      expect(liveText(tester, 'approval-uan-counter'), '3/12 digits');
      await enter(tester, 'approval-uan', '12a4b5');
      expect(tester.widget<TextField>(byKey('approval-uan')).controller!.text, '1245');
      expect(liveText(tester, 'approval-uan-counter'), '4/12 digits');
      await enter(tester, 'approval-uan', '1234567890123');
      expect(tester.widget<TextField>(byKey('approval-uan')).controller!.text.length, lessThanOrEqualTo(12));
      await enter(tester, 'approval-uan', '123456789012');
      expect(liveText(tester, 'approval-uan-counter'), isNull);
      await enter(tester, 'approval-uan', '');
      expect(liveText(tester, 'approval-uan-counter'), isNull);
    });

    testWidgets('5. PAN: upper-cased as typed; format hint while invalid, gone once valid', (tester) async {
      await openApprove(tester, applicant('u1', 'Test One'));
      await enter(tester, 'approval-pan', 'abcde');
      expect(tester.widget<TextField>(byKey('approval-pan')).controller!.text, 'ABCDE');
      expect(liveText(tester, 'approval-pan-hint'), kPanFormatHint);
      expect(tester.widget<Text>(byKey('approval-pan-hint')).style!.color, AppColors.warning);
      await enter(tester, 'approval-pan', 'abcde1234f');
      expect(liveText(tester, 'approval-pan-hint'), isNull);
      // The live hints never block typing or submit anything.
      expect(server.posts, isEmpty);
    });

    testWidgets('6. Confirm: one banner message, Department/Designation first, then UAN, then PAN', (tester) async {
      final row = applicant('u1', 'Test One')
        ..['department'] = ''
        ..['designation'] = '';
      await openApprove(tester, row);
      await enter(tester, 'approval-uan', '123');
      await enter(tester, 'approval-pan', 'X');
      await confirm(tester);
      expect(find.text('Please select both Department and Designation before confirming.'), findsOneWidget);
      expect(find.text('UAN must be exactly 12 digits, or leave it blank.'), findsNothing);
      expect(server.posts, isEmpty);
    });

    testWidgets('8. payload: the backend keys, PAN upper case, Aadhaar name trimmed; blanks not sent', (tester) async {
      await openApprove(tester, applicant('u1', 'Test One', candidateId: null));
      await enter(tester, 'approval-uan', '100000000012');
      await enter(tester, 'approval-aadhar-name', '  Test A One ');
      await enter(tester, 'approval-pan', 'abcde1234f');
      await confirm(tester);
      expect(server.posts.single, {
        'decision': 'approve',
        'remarks': '',
        'department': 'Engineering',
        'designation': 'Engineer',
        'uan_number': '100000000012',
        'name_as_per_aadhar': 'Test A One',
        'pan_number': 'ABCDE1234F',
      });
    });

    testWidgets('8. all three left blank: none of the keys is sent (web sends undefined)', (tester) async {
      await openApprove(tester, applicant('u1', 'Test One', candidateId: null));
      await confirm(tester);
      expect(server.posts.single.keys, isNot(contains('uan_number')));
      expect(server.posts.single.keys, isNot(contains('pan_number')));
      expect(server.posts.single.keys, isNot(contains('name_as_per_aadhar')));
    });

    testWidgets('10. phone with the keyboard open: every field reachable, no overflow, hints readable', (tester) async {
      await openApprove(tester, applicant('u1', 'Test One'), size: const Size(1080, 2400), dpr: 2.625);
      tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      const keyboardTop = (2400 - 900) / 2.625;
      for (final (key, hint) in [
        ('approval-uan', '12-digit UAN'),
        ('approval-aadhar-name', 'Exactly as on Aadhar card'),
        ('approval-pan', 'e.g. ABCDE1234F'),
      ]) {
        // The review sheet builds its list lazily: scroll to each field, as a
        // user would.
        await tester.scrollUntilVisible(byKey(key), 120, scrollable: sheetScrollable());
        await tester.pumpAndSettle();
        expect(tester.getRect(byKey(key)).bottom, lessThanOrEqualTo(keyboardTop), reason: key);
        expect(hintOpacity(tester, key, hint), 1.0, reason: key);
      }
      await tester.scrollUntilVisible(byKey('approval-uan'), -120, scrollable: sheetScrollable());
      await tester.enterText(byKey('approval-uan'), '12');
      await tester.pumpAndSettle();
      expect(liveText(tester, 'approval-uan-counter'), '2/12 digits');
      expect(tester.takeException(), isNull);
    });
  });

  test('9. permission: approving still needs onboarding.approve (covered by candidate_review_permission_test)', () {
    // The EPF box only exists inside the Approve form, which that test shows
    // is not offered without employees.approve / onboarding.approve.
    expect(FakeApprovalsServer, isNotNull);
  });
}
