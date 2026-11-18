import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/features/employees/data/models/employee_model.dart';
import 'package:mobile_app/features/employees/presentation/widgets/employee_card.dart';

import '../../shared/text_scale_layout_c2_test.dart' as h;

// Task 87 — HO-30: web's employee list shows department and branch per row;
// the mobile card now shows "Department · Branch" from the same list
// response (no new request), wrapping to two lines at large text, skipping a
// blank part, and omitted when both are blank. View / Edit unchanged.
EmployeeModel withOrg(String dept, String branch) => EmployeeModel.fromJson({
      'id': 'x',
      'employee_id': 'EMP9',
      'full_name': 'Test Person',
      'designation': 'Engineer',
      'department': dept,
      'branch': branch,
      'status': 'active',
      'is_active': true,
    });

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('employeeOrgLine', () {
    test('both', () => expect(employeeOrgLine(withOrg('Engineering', 'Main')), 'Engineering · Main'));
    test('department only', () => expect(employeeOrgLine(withOrg('Engineering', '')), 'Engineering'));
    test('branch only', () => expect(employeeOrgLine(withOrg('', 'Main')), 'Main'));
    test('neither', () => expect(employeeOrgLine(withOrg(' ', '')), ''));
  });

  testWidgets('card shows the line; omitted when blank; View / Edit still work', (tester) async {
    var viewed = 0, edited = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Row(children: [
          Expanded(child: EmployeeCard(employee: withOrg('Engineering', 'Main'), onView: () => viewed++, onEdit: () => edited++)),
          Expanded(child: EmployeeCard(employee: withOrg('', ''), onView: () {})),
        ]),
      ),
    ));
    expect(find.byKey(const Key('employee-card-org')), findsOneWidget);
    expect(find.text('Engineering · Main'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.remove_red_eye_outlined).first);
    await tester.tap(find.byKey(const Key('employee-card-edit')));
    expect((viewed, edited), (1, 1));
  });

  for (final s in [1.0, 1.3, 1.5, 2.0]) {
    testWidgets('Employees screen at $s: org line on every card, not clipped, no overflow', (tester) async {
      await h.pumpEmployees(tester, s);
      expect(tester.takeException(), isNull);
      final lines = find.byKey(const Key('employee-card-org'));
      expect(lines, findsNWidgets(4));
      for (final e in lines.evaluate()) {
        final p = e.findRenderObject()! as RenderParagraph;
        // 'Engineering · Main' fits within the card's three lines at any of these scales.
        expect(p.didExceedMaxLines, isFalse, reason: 'clipped at $s');
      }
      // Each card still fully laid out (no clipped content) — rows grow with text.
      for (final card in tester.widgetList(find.byType(EmployeeCard))) {
        final box = tester.renderObject<RenderBox>(find.byWidget(card));
        expect(box.size.height, greaterThanOrEqualTo(box.getMinIntrinsicHeight(box.size.width) - 0.5));
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
