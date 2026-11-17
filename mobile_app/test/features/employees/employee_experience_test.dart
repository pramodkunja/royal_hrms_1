import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/features/employees/domain/experience.dart';

import 'employee_detail_notice_reset_test.dart' as harness;

// Phase C3 — HO-29: web ProfileHeader shows "Current Experience" =
// experienceFrom(date_of_joining) (frontend employees/_data.ts). Mobile ports
// that formula exactly. Live check, 17 Nov 2026: DOJ 28 Jan 2025 →
// web "1 year 9 months".
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('experienceFrom = web formula', () {
    final now = DateTime(2026, 11, 17);
    final cases = <String, String>{
      '2025-01-28': '1 year 9 months', // live web value for the same employee
      '2026-02-01': '9 months',
      '2025-11-17': '1 year',
      '2024-10-17': '2 years 1 month',
      '2026-11-17': '0 months',
      '2026-11-18': '0 months', // future joining date → floored at 0
      '2026-10-18': '0 months', // day not reached yet
      '2026-10-17': '1 month',
      '': '—',
      'garbage': '—',
    };
    cases.forEach((doj, expected) => test('$doj → $expected', () => expect(experienceFrom(doj, now: now), expected)));
    test('accepts a timestamp-suffixed date', () => expect(experienceFrom('2025-01-28T00:00:00Z', now: now), '1 year 9 months'));
  });

  testWidgets('profile header shows Current Experience from the date of joining', (tester) async {
    await harness.pumpDetail(tester);
    final cell = find.byKey(const Key('employee-current-experience'));
    expect(cell, findsOneWidget);
    expect(find.descendant(of: cell, matching: find.text('CURRENT EXPERIENCE')), findsOneWidget);
    expect(find.descendant(of: cell, matching: find.text(experienceFrom('2026-01-05'))), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
