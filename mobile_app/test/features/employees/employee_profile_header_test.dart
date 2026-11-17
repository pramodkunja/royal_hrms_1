import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/dashboard_shell.dart';

import 'employee_detail_notice_reset_test.dart' as harness;

// Task C1 — device audit HO-05 / HO-06 (17 Nov 2026, moto g06, 411 dp wide):
//  • HO-05: the dashboard shell drew its own top bar above the profile's
//    AppBar (two headers, two bells, title squeezed to "Em…"). The shell now
//    leaves its bar off on detail routes; the profile's actions are icon
//    buttons with tooltips so the title fits.
//  • HO-06: a Cancel / Save bar was pinned under a profile opened for
//    viewing. Web's ProfileForm hides that footer in read-only mode and shows
//    it only after "Edit"; here the Personal section's Edit opens the edit
//    form (its own Cancel / Save). Editing stays available to editors.
// Synthetic employee; stand-in server; nothing is saved.

Future<void> pumpPhone(WidgetTester tester, {bool editor = true}) async {
  await harness.pumpDetail(tester, as: editor ? harness.hrEditor : harness.hrViewer);
  // Re-run at the audited phone size (720 × 1640 px @ 1.75).
  tester.view.physicalSize = const Size(720, 1640);
  tester.view.devicePixelRatio = 1.75;
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('shell header rule', () {
    test('detail routes with their own AppBar', () {
      for (final p in ['/dashboard/employees/EMP-7', '/dashboard/employees/EMP-7/id-card', '/dashboard/separation/42']) {
        expect(shellDetailRouteHasOwnAppBar(p), isTrue, reason: p);
      }
      for (final p in ['/dashboard', '/dashboard/employees', '/dashboard/separation', '/dashboard/leave', '/dashboard/employees/x/y']) {
        expect(shellDetailRouteHasOwnAppBar(p), isFalse, reason: p);
      }
    });
  });

  group('employee profile header (HO-05)', () {
    testWidgets('one AppBar; title not truncated; ID Card / Reset Password as labelled icon buttons', (tester) async {
      await pumpPhone(tester);
      expect(find.byType(AppBar), findsOneWidget);
      final title = tester.renderObject<RenderParagraph>(find.text('Employee Profile'));
      expect(title.size.width, greaterThanOrEqualTo(title.getMaxIntrinsicWidth(double.infinity) - 0.5),
          reason: 'title painted in full, not ellipsised');
      expect(find.byTooltip('ID Card'), findsOneWidget);
      expect(find.byTooltip('Reset Password'), findsOneWidget);
      expect(find.byKey(const Key('employee-id-card')), findsOneWidget);
      expect(find.byKey(const Key('employee-reset-password')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('view vs edit (HO-06)', () {
    testWidgets('editor: no pinned Cancel / Save while viewing; Edit opens the edit form', (tester) async {
      await pumpPhone(tester);
      expect(find.widgetWithText(OutlinedButton, 'Cancel'), findsNothing);
      expect(find.text('Save'), findsNothing);
      final edit = find.text('Edit').first;
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      // The edit form (its own Cancel / Save) — not submitted.
      expect(find.textContaining('Edit Employee').evaluate().isNotEmpty || find.text('Save Changes').evaluate().isNotEmpty || find.text('Update Employee').evaluate().isNotEmpty, isTrue);
      expect(harness.server.calls.where((c) => c.method != 'GET'), isEmpty);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('viewer (no employees.edit): no Save bar, no Edit, no Reset Password', (tester) async {
      await pumpPhone(tester, editor: false);
      expect(find.text('Save'), findsNothing);
      expect(find.text('Edit'), findsNothing);
      expect(find.byKey(const Key('employee-reset-password')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
