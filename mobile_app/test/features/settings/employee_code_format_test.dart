import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/settings/data/models/employee_code_model.dart';

import 'employee_code_settings_test.dart'
    show Server, byKey, enabled, previewCodes, prefixText, pump, save, server, typePrefix;

// Task 63: Settings → Employee ID Format's Format choice, as web
// settings/employee-code/page.tsx (FORMAT_OPTIONS, buildPreview, onSave) over
// backend EmployeeCodeSettings.id_format (accounts migration 0103;
// build_base_id): date_initials = prefix + DDMM + both initials (RSS0308TG),
// first_date_last = prefix + first initial + DDMM + last initial (RIST0308G);
// default date_initials; a save without id_format would leave it unchanged,
// web always sends it. A stand-in server; fictitious values.

const dateInitials = 'Prefix + DDMM + initials';
const firstDateLast = 'Prefix + first initial + DDMM + last initial';

String formatValue(WidgetTester tester) =>
    tester.widget<DropdownButton<String>>(find.byType(DropdownButton<String>)).value!;

String description(WidgetTester tester) => tester.widget<Text>(byKey('employee-code-format-description')).data!;

Future<void> pickFormat(WidgetTester tester, String label) async {
  await tester.tap(find.byType(DropdownButton<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Server withFormat(String? format) {
  final s = Server();
  if (format != null) s.stored = {...s.stored, 'id_format': format};
  return s;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('rules (pure)', () {
    test('1. both formats build the backend\'s codes for web\'s three examples', () {
      expect(employeeCodePreview('rss', 'date_initials').map((r) => r.code), ['RSS0308TG', 'RSS1509RK', 'RSS1509RK2']);
      expect(
          employeeCodePreview(' ris ', 'first_date_last').map((r) => r.code), ['RIST0308G', 'RISR1509K', 'RISR1509K2']);
      // Empty prefix → EMP; an unknown format falls back to date_initials (web).
      expect(employeeCodePreview('', 'first_date_last').first.code, 'EMPT0308G');
      expect(employeeCodePreview('A', 'future_format').first.code, 'A0308TG');
      expect(employeeCodePreview('A').first.code, 'A0308TG', reason: 'default format');
    });

    test('2/4. parsing: id_format kept; missing or blank → date_initials (web toSettings)', () {
      expect(EmployeeCodeSettings.fromJson(const {'prefix': 'R', 'id_format': 'first_date_last'}).idFormat,
          'first_date_last');
      expect(EmployeeCodeSettings.fromJson(const {'prefix': 'R'}).idFormat, 'date_initials');
      expect(EmployeeCodeSettings.fromJson(const {'prefix': 'R', 'id_format': ''}).idFormat, 'date_initials');
      expect(EmployeeCodeSettings.fromJson(const {'prefix': 'R', 'id_format': 'other'}).idFormat, 'other');
    });

    test('labels and descriptions are web\'s', () {
      expect(kEmployeeIdFormats.map((f) => f.$2), [dateInitials, firstDateLast]);
      expect(employeeIdFormatDescription('date_initials'),
          'prefix + date of joining (DDMM) + first and last name initials');
      expect(employeeIdFormatDescription('first_date_last'),
          'prefix + first name initial + date of joining (DDMM) + last name initial');
      expect(employeeIdFormatDescription('unknown'), employeeIdFormatDescription('date_initials'));
    });
  });

  group('screen', () {
    testWidgets('2/4. a server without id_format: date_initials selected, its preview, nothing to save',
        (tester) async {
      await pump(tester); // the Task 48 stand-in sends no id_format
      expect(formatValue(tester), 'date_initials');
      expect(find.text(dateInitials), findsOneWidget);
      expect(find.text('Applies to employees created from now on. Existing employee IDs are not changed.'),
          findsOneWidget);
      expect(previewCodes(tester), ['RSS0308TG', 'RSS1509RK', 'RSS1509RK2']);
      expect(enabled(tester, 'employee-code-save'), isFalse);
    });

    testWidgets('3. stored first_date_last: shown selected with its preview and description', (tester) async {
      await pump(tester, with_: withFormat('first_date_last'));
      expect(formatValue(tester), 'first_date_last');
      expect(previewCodes(tester), ['RSST0308G', 'RSSR1509K', 'RSSR1509K2']);
      expect(description(tester),
          'Format: prefix + first name initial + date of joining (DDMM) + last name initial. Example IDs:');
    });

    testWidgets('5/7/8. switching format updates the preview live; Save sends web\'s payload; form = server value',
        (tester) async {
      await pump(tester, with_: withFormat('date_initials'));
      await pickFormat(tester, firstDateLast);
      expect(previewCodes(tester), ['RSST0308G', 'RSSR1509K', 'RSSR1509K2']);
      expect(enabled(tester, 'employee-code-save'), isTrue, reason: 'a format change alone is a change');
      await typePrefix(tester, 'ris');
      expect(previewCodes(tester).first, 'RIST0308G');
      await save(tester);
      expect(server.puts.single, {'prefix': 'RIS', 'id_format': 'first_date_last', 'padding': 5, 'next_sequence': 1});
      expect(find.text('Employee ID format saved successfully.'), findsOneWidget);
      expect((prefixText(tester), formatValue(tester)), ('RIS', 'first_date_last'));
      expect(enabled(tester, 'employee-code-save'), isFalse);
    });

    testWidgets('8. Cancel restores both the prefix and the format; nothing is sent', (tester) async {
      await pump(tester, with_: withFormat('date_initials'));
      await pickFormat(tester, firstDateLast);
      await typePrefix(tester, 'XYZ');
      await tester.tap(byKey('employee-code-cancel'));
      await tester.pumpAndSettle();
      expect((prefixText(tester), formatValue(tester)), ('RSS', 'date_initials'));
      expect(previewCodes(tester).first, 'RSS0308TG');
      expect(server.puts, isEmpty);
      expect(enabled(tester, 'employee-code-cancel'), isFalse);
    });

    testWidgets('6. prefix validation still blocks the save, whatever the format', (tester) async {
      await pump(tester, with_: withFormat('date_initials'));
      await pickFormat(tester, firstDateLast);
      await typePrefix(tester, 'R1');
      await save(tester);
      expect(find.text('Prefix must contain letters only.'), findsOneWidget);
      await typePrefix(tester, '  ');
      await save(tester);
      expect(find.text('Prefix is required.'), findsOneWidget);
      expect(server.puts, isEmpty);
    });

    testWidgets('10. a refused save: the server\'s format error in the banner; the choice is kept for a retry',
        (tester) async {
      final s = withFormat('date_initials')
        ..refuse = (
          status: 400,
          body: {
            'status': 'error',
            'message': 'Please fix the errors below.',
            'data': {
              'id_format': ['"bogus" is not a valid choice.']
            },
          }
        );
      await pump(tester, with_: s);
      await pickFormat(tester, firstDateLast);
      await save(tester);
      expect(find.text('Format: "bogus" is not a valid choice.'), findsOneWidget);
      expect(formatValue(tester), 'first_date_last');
      s.refuse = null;
      await save(tester);
      expect(s.puts.last['id_format'], 'first_date_last');
      expect(find.text('Employee ID format saved successfully.'), findsOneWidget);
    });

    testWidgets('a stored format this app doesn\'t know: kept, offered, sent back unchanged', (tester) async {
      await pump(tester, with_: withFormat('future_format'));
      expect(formatValue(tester), 'future_format');
      await typePrefix(tester, 'ABC');
      await save(tester);
      expect(server.puts.single['id_format'], 'future_format');
    });

    testWidgets('9. without settings.edit: nothing requested, no format control', (tester) async {
      await pump(tester,
          as: const UserEntity(
            id: 'v',
            email: 'v@example.test',
            fullName: 'Viewer',
            role: 'hr',
            roleDisplay: 'HR',
            mustChangePassword: false,
            permissions: ['settings.view'],
            onboardingStatus: 'complete',
            assessmentStatus: 'complete',
          ));
      expect(byKey('employee-code-denied'), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsNothing);
      expect(server.gets, 0);
    });

    testWidgets('prefix placeholder visible before focus (web shows it in an empty field)', (tester) async {
      await pump(tester);
      await typePrefix(tester, '');
      final dec = tester.widget<TextField>(byKey('employee-code-prefix')).decoration!;
      expect(dec.floatingLabelBehavior, FloatingLabelBehavior.always);
      expect(dec.hintText, 'e.g. RSS');
    });
  });
}
