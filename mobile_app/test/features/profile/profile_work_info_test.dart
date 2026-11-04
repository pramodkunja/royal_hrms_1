import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/features/profile/data/models/my_profile_model.dart';
import 'package:mobile_app/features/profile/domain/entities/my_profile_entity.dart';
import 'package:mobile_app/features/profile/presentation/widgets/profile_sections.dart';

// Phase 8: My Profile → Work Information (audit row 53). GET /employees/me/
// (MyProfileSerializer) returns reporting_manager, reporting_approver and hr
// as {id: <employee code>, name: <full name>} or null, plus
// notice_period_days. Web (ProfileClient.tsx + lib/assignedPerson.ts) shows
// the name only, "Not assigned" when there is none, read-only.

Map<String, dynamic> me({Object? manager, Object? approver, Object? hr, Object? notice = 30, bool omit = false}) => {
      'id': 'u1',
      'full_name': 'Pat Kumar',
      'email': 'pat@example.com',
      'phone': '9000000000',
      'employee_id': 'EMP-7',
      'department': 'Engineering',
      'designation': 'Engineer',
      'branch': 'Surat',
      'role_name': 'employee',
      'role_display': 'Employee',
      'date_of_joining': '2026-01-05',
      'date_joined': '2026-01-01T00:00:00Z',
      'onboarding_status': 'complete',
      'assessment_status': 'complete',
      if (!omit) ...{
        'notice_period_days': notice,
        'reporting_manager': manager,
        'reporting_approver': approver,
        'hr': hr,
      },
      'profile': <String, dynamic>{},
      'profile_photo_url': null,
    };

const _mgr = {'id': 'EMP-2', 'name': 'Morgan Lee'};
const _appr = {'id': 'EMP-3', 'name': 'Asha Rao'};
const _hr = {'id': 'EMP-4', 'name': 'Hema Iyer'};

Future<void> pumpSection(WidgetTester tester, MyProfileModel profile) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final phone = TextEditingController(text: profile.phone);
  addTearDown(phone.dispose);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    child: MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: ProfilePersonalSection(profile: profile, phoneCtrl: phone))),
    ),
  ));
  await tester.pumpAndSettle();
}

/// The value shown beside [label] (the display field's text below it).
Finder valueFor(String label, String value) => find.descendant(
    of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first, matching: find.text(value));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('mapping from /employees/me/', () {
    test('each assigned person keeps the server id and name', () {
      final p = MyProfileModel.fromJson(me(manager: _mgr, approver: _appr, hr: _hr));
      expect((p.reportingManager?.id, p.reportingManager?.name), ('EMP-2', 'Morgan Lee'));
      expect((p.reportingApprover?.id, p.reportingApprover?.name), ('EMP-3', 'Asha Rao'));
      expect((p.hr?.id, p.hr?.name), ('EMP-4', 'Hema Iyer'));
      expect(p.noticePeriodDays, 30);
    });

    test('null or absent → nothing assigned', () {
      final nulls = MyProfileModel.fromJson(me());
      expect([nulls.reportingManager, nulls.reportingApprover, nulls.hr], [null, null, null]);
      final absent = MyProfileModel.fromJson(me(omit: true));
      expect([absent.reportingManager, absent.reportingApprover, absent.hr, absent.noticePeriodDays],
          [null, null, null, null]);
    });

    test('display text: the name only, or "Not assigned" (web assignedName)', () {
      expect(assignedName(const AssignedPersonEntity(id: 'EMP-2', name: '  Morgan Lee ')), 'Morgan Lee');
      expect(assignedName(const AssignedPersonEntity(id: 'EMP-2', name: '')), 'Not assigned');
      expect(assignedName(const AssignedPersonEntity(id: 'EMP-2')), 'Not assigned'); // never the raw id
      expect(assignedName(null), 'Not assigned');
      expect(AssignedPersonEntity.fromJson('EMP-2'), isNull); // not the documented shape
    });

    test('local profile updates keep them', () {
      final p = MyProfileModel.fromJson(me(manager: _mgr, approver: _appr, hr: _hr));
      final photo = p.copyWithPhotoUrl('https://files.invalid/me.jpg');
      expect((photo.reportingManager?.name, photo.reportingApprover?.name, photo.hr?.name),
          ('Morgan Lee', 'Asha Rao', 'Hema Iyer'));
      final updated = p.applyUpdate(MyProfileUpdateData(phone: '9111111111'));
      expect(
          (updated.reportingManager?.name, updated.hr?.name, updated.phone), ('Morgan Lee', 'Hema Iyer', '9111111111'));
    });
  });

  group('Work Information on My Profile', () {
    testWidgets('shows the assigned people and notice period next to the existing fields', (tester) async {
      await pumpSection(tester, MyProfileModel.fromJson(me(manager: _mgr, approver: _appr, hr: _hr)));
      expect(valueFor('Reporting Manager', 'Morgan Lee'), findsOneWidget);
      expect(valueFor('Reporting Approver', 'Asha Rao'), findsOneWidget);
      expect(valueFor('HR', 'Hema Iyer'), findsOneWidget);
      expect(valueFor('Notice Period', '30 days'), findsOneWidget);
      expect(find.text('EMP-2'), findsNothing); // ids are not shown
      // Existing fields unchanged.
      for (final (label, value) in [
        ('Employee ID', 'EMP-7'),
        ('Department', 'Engineering'),
        ('Designation', 'Engineer'),
        ('Branch', 'Surat'),
      ]) {
        expect(valueFor(label, value), findsOneWidget, reason: label);
      }
    });

    testWidgets('missing people read "Not assigned"; no notice period reads "Not assigned"', (tester) async {
      await pumpSection(tester, MyProfileModel.fromJson(me(manager: _mgr, notice: null)));
      expect(valueFor('Reporting Manager', 'Morgan Lee'), findsOneWidget);
      expect(valueFor('Reporting Approver', 'Not assigned'), findsOneWidget);
      expect(valueFor('HR', 'Not assigned'), findsOneWidget);
      expect(valueFor('Notice Period', 'Not assigned'), findsOneWidget);
    });

    testWidgets('read-only: still only the phone is editable in this section', (tester) async {
      await pumpSection(tester, MyProfileModel.fromJson(me(manager: _mgr, approver: _appr, hr: _hr)));
      expect(find.byType(TextField), findsOneWidget); // Phone, as before
      expect(find.text('1 day'), findsNothing);
      await pumpSection(tester, MyProfileModel.fromJson(me(notice: 1)));
      expect(valueFor('Notice Period', '1 day'), findsOneWidget);
    });
  });
}
