import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/features/employees/data/models/employee_model.dart';
import 'package:mobile_app/features/settings/data/models/roles_model.dart';

import 'employee_edit_contact_approver_test.dart' as base;

// Task 36 (C-E13 follow-up): Employee Edit — Reporting Manager for
// manager-type roles, as web employees/[id]/page.tsx: the picker lists
// /employees/managers/?manager_approvers=1&branch=&designation= (lib/
// reportingManager.ts), leaves the employee out, offers "None — no reporting
// manager", and the save sends reporting_manager_id (user UUID or null).
// Becoming a Manager clears a reporting manager who isn't eligible
// (shouldClearReportingManager over the always-loaded managerEligibleList).
// Reuses the Task 34 stand-in server; synthetic data, nothing real changed.

const mgrUuid = base.mgrUuid; // stored reporting manager (code EMP-M1)

Finder byKey(String k) => find.byKey(Key(k));
Finder managerField() =>
    find.descendant(of: byKey('edit-employee-manager'), matching: find.byType(DropdownButtonFormField<String>));
String? managerValue(WidgetTester tester) => tester.state<FormFieldState<String>>(managerField()).value;

Future<void> pickManager(WidgetTester tester, String option) async {
  await tester.ensureVisible(managerField());
  await tester.tap(managerField());
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> chooseRole(WidgetTester tester, String role) async {
  final field = find.byType(DropdownButtonFormField<RoleModel>);
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(role).last);
  await tester.pumpAndSettle();
}

List<Map<String, dynamic>> managerListRequests() => base.server
    .of('GET', ApiConstants.employeesManagerList)
    .map((r) => Map<String, dynamic>.from(r.queryParameters))
    .toList();

Map<String, dynamic> managerEmployee({Map<String, dynamic>? manager}) => {
      ...base.employeeJson(role: 'manager'),
      if (manager != null) 'reporting_manager': manager,
    };

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('payload sends reporting_manager_id (user UUID) for managers too; null clears', () {
    final f = EmployeeUpdateFormData.fromModel(EmployeeModel.fromJson(managerEmployee()))..canManageTeam = true;
    expect(f.toJson()['reporting_manager_id'], mgrUuid, reason: 'UUID, not the code EMP-M1');
    f.reportingManagerId = null;
    expect(f.toJson().containsKey('reporting_manager_id'), isTrue);
    expect(f.toJson()['reporting_manager_id'], isNull);
  });

  group('manager-type role', () {
    testWidgets('picker shown with web\'s eligible list, note, self left out, None offered', (tester) async {
      await base.pumpEdit(tester, employee: managerEmployee());
      expect(byKey('edit-employee-manager'), findsOneWidget);
      expect(find.text('Reporting Manager', findRichText: true), findsOneWidget);
      expect(byKey('edit-employee-manager-note'), findsOneWidget);
      expect(managerListRequests(),
          anyElement(equals({'manager_approvers': '1', 'branch': 'Pune', 'designation': 'QA Analyst'})));
      expect(managerListRequests().any((q) => q['manager_approvers'] == null), isFalse,
          reason: 'no plain branch list for a Manager');
      await tester.ensureVisible(managerField());
      await tester.tap(managerField());
      await tester.pumpAndSettle();
      expect(find.text('None — no reporting manager'), findsWidgets);
      expect(find.text('Chitra COO (EMP-COO · COO)'), findsWidgets);
      expect(find.text('Nia Test (EMP-7 · Manager)'), findsNothing, reason: 'the employee themself');
    });

    testWidgets('current reporting manager shown even when not in the list, and sent back unchanged (UUID)',
        (tester) async {
      await base.pumpEdit(tester, employee: managerEmployee());
      expect(managerValue(tester), mgrUuid);
      expect(find.text('Kiran Manager'), findsWidgets);
      await base.save(tester);
      final body = base.lastPut();
      expect(body['reporting_manager_id'], mgrUuid);
      expect(body['reporting_manager_id'], isNot('EMP-M1'));
    });

    testWidgets('choosing an eligible manager sends that user\'s UUID', (tester) async {
      await base.pumpEdit(tester, employee: managerEmployee());
      await pickManager(tester, 'Chitra COO (EMP-COO · COO)');
      await base.save(tester);
      expect(base.lastPut()['reporting_manager_id'], 'u-coo');
    });

    testWidgets('None clears it (null); the approver and other fields are untouched', (tester) async {
      await base.pumpEdit(tester, employee: managerEmployee());
      await pickManager(tester, 'None — no reporting manager');
      expect(managerValue(tester), isNull);
      await base.save(tester);
      final body = base.lastPut();
      expect(body.containsKey('reporting_manager_id'), isTrue);
      expect(body['reporting_manager_id'], isNull);
      expect(body['reporting_approver_id'], base.apprUuid);
      expect(body['hr_id'], base.hrUuid);
      expect([body['email'], body['phone'], body['branch'], body['designation']],
          ['nia.test@example.test', '9000000007', 'Pune', 'QA Analyst']);
    });

    testWidgets('a refused choice: the server message is shown and the sheet stays open', (tester) async {
      final s = base.Server()
        ..putStatus = 400
        ..putMessage = 'A Manager can only report to the COO / CMD, Admin Head, or HR of their branch.';
      await base.pumpEdit(tester, with_: s, employee: managerEmployee());
      await pickManager(tester, 'Chitra COO (EMP-COO · COO)');
      await base.save(tester);
      expect(
          find.text('A Manager can only report to the COO / CMD, Admin Head, or HR of their branch.'), findsOneWidget);
      expect(base.sheetResult, isNull);
      s.putStatus = 200;
      await base.save(tester);
      expect(base.sheetResult, isTrue);
      expect(base.lastPut()['reporting_manager_id'], 'u-coo');
    });
  });

  group('non-manager role (unchanged)', () {
    testWidgets('branch list picker as before; eligible list still loaded in the background (web)', (tester) async {
      await base.pumpEdit(tester);
      expect(byKey('edit-employee-manager'), findsNothing, reason: 'the existing non-manager picker is used');
      expect(byKey('edit-employee-manager-note'), findsNothing);
      expect(managerListRequests(), anyElement(equals({'branch': 'Pune'})));
      expect(managerListRequests(),
          anyElement(equals({'manager_approvers': '1', 'branch': 'Pune', 'designation': 'QA Analyst'})));
      await base.save(tester);
      expect(base.lastPut()['reporting_manager_id'], mgrUuid);
    });
  });

  group('role changes', () {
    testWidgets('becoming a Manager clears an ineligible reporting manager (nothing else)', (tester) async {
      await base.pumpEdit(tester); // employee role, reporting manager Kiran (not eligible for a Manager)
      await chooseRole(tester, 'Manager');
      expect(byKey('edit-employee-manager'), findsOneWidget);
      expect(managerValue(tester), isNull);
      await base.save(tester);
      final body = base.lastPut();
      expect(body['role'], 'manager');
      expect(body.containsKey('reporting_manager_id'), isTrue);
      expect(body['reporting_manager_id'], isNull);
      expect(body['reporting_approver_id'], base.apprUuid, reason: 'web clears only the manager');
      expect(body['hr_id'], base.hrUuid);
      expect(body['email'], 'nia.test@example.test');
    });

    testWidgets('becoming a Manager keeps an eligible reporting manager', (tester) async {
      final s = base.Server()
        ..managerApprovers = [
          {
            'id': mgrUuid,
            'employee_id': 'EMP-M1',
            'full_name': 'Kiran Manager',
            'department': 'Ops',
            'branch': 'Pune',
            'role': 'HR Admin'
          },
        ];
      await base.pumpEdit(tester, with_: s);
      await chooseRole(tester, 'Manager');
      expect(managerValue(tester), mgrUuid);
      await base.save(tester);
      expect(base.lastPut()['reporting_manager_id'], mgrUuid);
    });

    testWidgets('eligible list unavailable → becoming a Manager clears it (web treats it as empty)', (tester) async {
      final s = base.Server()..approverStatus = 500;
      await base.pumpEdit(tester, with_: s);
      await chooseRole(tester, 'Manager');
      await base.save(tester);
      expect(base.lastPut()['reporting_manager_id'], isNull);
    });

    testWidgets('Manager → non-manager keeps the reporting manager and returns to the branch picker', (tester) async {
      await base.pumpEdit(tester, employee: managerEmployee());
      await chooseRole(tester, 'Employee');
      expect(byKey('edit-employee-manager'), findsNothing);
      await base.save(tester);
      final body = base.lastPut();
      expect(body['role'], 'employee');
      expect(body['reporting_manager_id'], mgrUuid);
    });
  });
}
