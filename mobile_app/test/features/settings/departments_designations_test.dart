// Task 107: Departments & Designations — Add/Edit Designation department selector,
// parity with web (departments/page.tsx), and layout at every size. Stand-in API only.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/features/settings/data/models/departments_model.dart';
import 'package:mobile_app/features/settings/presentation/providers/settings_providers.dart';

import '../../visual/departments_visual_test.dart' as v;

Finder _k(String k) => find.byKey(Key(k));

v.DeptServer get _s => v.lastServer;

int _count(String key) => _s.log.where((l) => l == key).length;

Future<void> _fill(WidgetTester t, String name) async {
  await t.enterText(_k('desig-name'), name);
  await t.pump();
}

Future<void> _pick(WidgetTester t, int id) async {
  await v.tapKey(t, 'desig-dept-field');
  await v.tapKey(t, 'dept-option-$id');
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('Add Designation — department field', () {
    testWidgets('opened from a department it is preselected and shows the full long name', (t) async {
      await v.openDepartments(t, shots: false);
      await v.openAddDesignation(t, dept: v.longDeptName);
      expect(t.takeException(), isNull);
      expect(t.widget<Text>(_k('desig-dept-value')).data, v.longDeptName);
      expect(find.text('Add Designation'), findsWidgets);
    });

    testWidgets('the selector sheet lists every department, wraps long names, marks the current one', (t) async {
      await v.openDepartments(t, shots: false);
      await v.openAddDesignation(t, dept: v.longDeptName);
      await v.tapKey(t, 'desig-dept-field');
      expect(find.text('Select Department'), findsOneWidget);
      expect(find.descendant(of: _k('dept-option-2'), matching: find.text(v.longDeptName)), findsOneWidget);
      expect(find.descendant(of: _k('dept-option-2'), matching: find.byIcon(Icons.check_circle)), findsOneWidget);
      expect(find.descendant(of: _k('dept-option-3'), matching: find.text('Inactive')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('choosing a department shows it and sends that department’s id', (t) async {
      await v.openDepartments(t, shots: false);
      await v.openAddDesignation(t, dept: v.longDeptName);
      await _pick(t, 1);
      expect(t.widget<Text>(_k('desig-dept-value')).data, 'Engineering');
      await _fill(t, 'Platform Engineer');
      await v.tapKey(t, 'desig-submit');
      expect(
          _s.bodies['POST /designations/']!.single, {'name': 'Platform Engineer', 'department': 1, 'is_active': true});
    });

    testWidgets('search narrows the list, says when nothing matches, and clearing restores it', (t) async {
      await v.openDepartments(t, shots: false);
      await v.openAddDesignation(t);
      await v.tapKey(t, 'desig-dept-field');
      await t.enterText(_k('dept-select-search'), 'resourc');
      await t.pump();
      expect(_k('dept-option-3'), findsOneWidget);
      expect(_k('dept-option-1'), findsNothing);
      await t.enterText(_k('dept-select-search'), 'zzz');
      await t.pump();
      expect(_k('dept-select-no-match'), findsOneWidget);
      await t.enterText(_k('dept-select-search'), '');
      await t.pump();
      expect(_k('dept-option-1'), findsOneWidget);
    });

    testWidgets('many departments: the list scrolls and a department far down can be chosen', (t) async {
      await v.openDepartments(t, size: const Size(360, 640), shots: false, server: v.DeptServer()..manyDepts = 60);
      await v.openAddDesignation(t);
      await v.tapKey(t, 'desig-dept-field');
      final last = find.text('Department 60 of the Operations Group');
      expect(last, findsNothing); // not built yet: it is far below
      await t.scrollUntilVisible(last, 300,
          scrollable: find.descendant(of: _k('dept-select-list'), matching: find.byType(Scrollable)));
      await t.tap(last);
      await v.settle(t);
      expect(t.widget<Text>(_k('desig-dept-value')).data, 'Department 60 of the Operations Group');
      expect(t.takeException(), isNull);
    });

    testWidgets('closing the sheet without choosing keeps the current department', (t) async {
      await v.openDepartments(t, shots: false);
      await v.openAddDesignation(t);
      await v.tapKey(t, 'desig-dept-field');
      await t.tap(find.byTooltip('Close').last);
      await v.settle(t);
      expect(t.widget<Text>(_k('desig-dept-value')).data, 'Engineering');
    });
  });

  group('Add Designation — states of the departments request', () {
    // The dialog is opened over a screen whose departments loaded; the request is then
    // refreshed so the field itself goes through loading / empty / error.
    Future<void> openThenRefresh(WidgetTester t, v.DeptServer s, void Function() change) async {
      await v.openDepartments(t, shots: false, server: s);
      await v.openAddDesignation(t);
      change();
      final ctx = t.element(_k('desig-name'));
      final container = ProviderScope.containerOf(ctx);
      container.invalidate(departmentsProvider);
      await t.pump();
      await t.pump();
    }

    testWidgets('failed request: error with Retry, which reloads and restores the field', (t) async {
      final s = v.DeptServer();
      await openThenRefresh(t, s, () => s.deptStatus = 500);
      await v.settle(t);
      expect(_k('desig-dept-error'), findsOneWidget);
      expect(find.text('Could not load departments.'), findsOneWidget);
      s.deptStatus = 200;
      await v.tapKey(t, 'desig-dept-retry');
      expect(_k('desig-dept-field'), findsOneWidget);
    });

    testWidgets('loading: a progress notice instead of a field', (t) async {
      final s = v.DeptServer();
      final gate = Completer<void>();
      await openThenRefresh(t, s, () => s.deptHold = gate);
      expect(_k('desig-dept-loading'), findsOneWidget);
      gate.complete();
      await v.settle(t);
      expect(_k('desig-dept-field'), findsOneWidget);
    });

    testWidgets('no departments: says so and does not offer a selector', (t) async {
      final s = v.DeptServer();
      await openThenRefresh(t, s, () => s.noDepts = true);
      await v.settle(t);
      expect(_k('desig-dept-empty'), findsOneWidget);
      expect(_k('desig-dept-field'), findsNothing);
    });
  });

  group('Edit Designation', () {
    testWidgets('the designation’s department is preselected; saving sends the same id with the edit', (t) async {
      await v.openDepartments(t, shots: false);
      await v.tapText(t, 'Engineering');
      await v.tapKey(t, 'desig-edit-100');
      expect(find.text('Edit Designation'), findsOneWidget);
      expect(t.widget<Text>(_k('desig-dept-value')).data, 'Engineering');
      expect(t.widget<TextFormField>(_k('desig-name')).controller!.text, 'Senior Software Engineer');
      await _fill(t, 'Principal Engineer');
      await v.tapKey(t, 'desig-submit');
      expect(_s.bodies['PUT /designations/100/']!.single,
          {'name': 'Principal Engineer', 'department': 1, 'is_active': true});
      expect(find.text('Principal Engineer'), findsOneWidget); // list updated from the server reply
    });

    testWidgets('a designation under a long-named department keeps that department', (t) async {
      await v.openDepartments(t, shots: false);
      await v.tapText(t, v.longDeptName);
      await v.tapKey(t, 'desig-edit-102');
      expect(t.widget<Text>(_k('desig-dept-value')).data, v.longDeptName);
      expect(t.takeException(), isNull);
    });
  });

  group('validation and server errors', () {
    testWidgets('empty name: web’s required rule, the chosen department is kept, nothing is sent', (t) async {
      await v.openDepartments(t, shots: false);
      await v.openAddDesignation(t);
      await _pick(t, 2);
      await v.tapKey(t, 'desig-submit');
      expect(find.text('Designation name is required'), findsOneWidget);
      expect(t.widget<Text>(_k('desig-dept-value')).data, v.longDeptName);
      expect(_s.bodies['POST /designations/'], isNull);
    });

    testWidgets('typing clears the name error', (t) async {
      await v.openDepartments(t, shots: false);
      await v.openAddDesignation(t);
      await v.tapKey(t, 'desig-submit');
      await _fill(t, 'A');
      expect(find.text('Designation name is required'), findsNothing);
    });

    testWidgets('the department is required by the form data (no department → error)', (t) async {
      final errors = DesignationFormData(name: 'X').validate();
      expect(errors['departmentId'], 'Department is required');
      expect(DesignationFormData(name: 'X', departmentId: 1).validate(), isEmpty);
    });

    testWidgets('duplicate name / server refusal: shown inside the dialog, input and department kept', (t) async {
      final s = v.DeptServer()..saveStatus = 400;
      await v.openDepartments(t, shots: false, server: s);
      await v.openAddDesignation(t);
      await _pick(t, 2);
      await _fill(t, 'QA Lead');
      await v.tapKey(t, 'desig-submit');
      expect(_k('desig-save-error'), findsOneWidget);
      expect(find.text('A designation with this name already exists in this department.'), findsOneWidget);
      expect(t.widget<TextFormField>(_k('desig-name')).controller!.text, 'QA Lead');
      expect(t.widget<Text>(_k('desig-dept-value')).data, v.longDeptName);
      // fixing the input clears the banner
      await _fill(t, 'QA Lead 2');
      expect(_k('desig-save-error'), findsNothing);
    });

    testWidgets('a long validation / server message wraps and does not overflow at 320dp@2×', (t) async {
      final s = v.DeptServer()
        ..saveStatus = 400
        ..saveMessage = 'A designation named "${'Extraordinarily Long Designation ' * 3}" already exists in the '
            'selected department; choose another name or another department.';
      await v.openDepartments(t, size: const Size(320, 568), scale: 2, shots: false, server: s);
      await v.openAddDesignation(t);
      await _fill(t, 'X');
      await v.tapKey(t, 'desig-submit');
      expect(_k('desig-save-error'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('create success closes the dialog and the new designation appears', (t) async {
      await v.openDepartments(t, shots: false);
      await v.openAddDesignation(t);
      await _fill(t, 'Brand New Role');
      await v.tapKey(t, 'desig-submit');
      expect(find.text('Add Designation'), findsNothing);
      expect(find.text('Brand New Role'), findsOneWidget);
    });
  });

  group('Departments screen', () {
    testWidgets('list, expand, delete designation confirmation → DELETE', (t) async {
      await v.openDepartments(t, shots: false);
      expect(find.text('Engineering'), findsWidgets);
      await v.tapText(t, 'Engineering');
      await v.tapKey(t, 'desig-delete-101');
      expect(find.text('Confirm Delete'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await v.settle(t);
      expect(_count('DELETE /designations/101/'), 0);
      await v.tapKey(t, 'desig-delete-101');
      await t.tap(find.text('Delete').last);
      await v.settle(t);
      expect(_count('DELETE /designations/101/'), 1);
    });

    testWidgets('department edit/delete are 44dp targets; edit form shows a server refusal inline', (t) async {
      final s = v.DeptServer()
        ..saveStatus = 400
        ..saveMessage = 'A department with this name already exists.';
      await v.openDepartments(t, shots: false, server: s);
      expect(t.getSize(_k('dept-edit-1')).height, greaterThanOrEqualTo(44));
      expect(t.getSize(_k('dept-delete-1')).width, greaterThanOrEqualTo(44));
      await v.tapKey(t, 'dept-edit-1');
      await v.tapKey(t, 'dept-submit');
      expect(_k('dept-save-error'), findsOneWidget);
      expect(find.text('A department with this name already exists.'), findsOneWidget);
    });

    testWidgets('search narrows the departments and says when none match', (t) async {
      await v.openDepartments(t, shots: false);
      await t.enterText(find.byType(TextField).first, 'human');
      await v.settle(t);
      expect(find.text('Human Resources'), findsOneWidget);
      expect(find.text('Engineering'), findsNothing);
      await t.enterText(find.byType(TextField).first, 'qqq');
      await v.settle(t);
      expect(find.text('No departments yet'), findsOneWidget);
    });

    testWidgets('failed load: an error; no departments: the empty state with Add', (t) async {
      await v.openDepartments(t, shots: false, server: v.DeptServer()..deptStatus = 500);
      expect(find.text('Could not load'), findsOneWidget);
      await v.openDepartments(t, shots: false, server: v.DeptServer()..noDepts = true);
      expect(find.text('No departments yet'), findsOneWidget);
    });
  });

  group('permissions (web: settings.edit)', () {
    testWidgets('without settings.edit there is no Add Department, Add designation, Edit or Delete', (t) async {
      await v.openDepartments(t, shots: false, as: v.deptUser(['settings.view']));
      expect(_k('dept-add'), findsNothing);
      expect(_k('dept-edit-1'), findsNothing);
      await v.tapText(t, 'Engineering');
      expect(_k('desig-add'), findsNothing);
      expect(_k('desig-edit-100'), findsNothing);
      expect(find.text('Senior Software Engineer'), findsOneWidget); // still browsable
    });

    testWidgets('with settings.edit all of them are there', (t) async {
      await v.openDepartments(t, shots: false);
      expect(_k('dept-add'), findsOneWidget);
      await v.tapText(t, 'Engineering');
      expect(_k('desig-add'), findsOneWidget);
      expect(_k('desig-edit-100'), findsOneWidget);
    });
  });

  group('keyboard', () {
    testWidgets('keyboard open at 320×568: the name field and Add button stay reachable', (t) async {
      await v.openDepartments(t, size: const Size(320, 568), keyboard: 280, shots: false);
      await v.openAddDesignation(t);
      await t.enterText(_k('desig-name'), 'Role');
      await t.pump();
      expect(t.takeException(), isNull);
      await t.ensureVisible(_k('desig-submit'));
      await t.pump();
      expect(t.getRect(_k('desig-submit')).bottom, lessThanOrEqualTo(568 - 280 + 1));
    });

    testWidgets('keyboard open with the selector: the sheet stays above the keyboard and the search works', (t) async {
      await v.openDepartments(t, size: const Size(320, 568), keyboard: 280, shots: false);
      await v.openAddDesignation(t);
      await v.tapKey(t, 'desig-dept-field');
      expect(t.takeException(), isNull);
      expect(t.getRect(_k('dept-select-search')).bottom, lessThanOrEqualTo(568 - 280));
      await t.enterText(_k('dept-select-search'), 'eng');
      await t.pump();
      expect(t.getRect(_k('dept-option-1')).bottom, lessThanOrEqualTo(568 - 280));
    });
  });

  group('responsive', () {
    for (final (w, h, sc) in [
      (320.0, 568.0, 1.0),
      (360.0, 800.0, 1.0),
      (393.0, 852.0, 1.0),
      (430.0, 932.0, 1.0),
      (600.0, 900.0, 1.0),
      (800.0, 1000.0, 1.0),
      (1000.0, 800.0, 1.0),
      (320.0, 568.0, 2.0),
      (360.0, 800.0, 1.5),
      (360.0, 800.0, 2.0),
    ]) {
      testWidgets('${w.toInt()}×${h.toInt()} @ $sc×: list, add dialog, selector, edit dialog, no overflow', (t) async {
        await v.openDepartments(t, size: Size(w, h), scale: sc, shots: false);
        expect(t.takeException(), isNull);
        await v.openAddDesignation(t, dept: v.longDeptName);
        expect(t.takeException(), isNull);
        expect(t.getRect(_k('desig-dept-field')).right, lessThanOrEqualTo(w));
        await v.tapKey(t, 'desig-dept-field');
        expect(t.takeException(), isNull);
        expect(t.getRect(_k('dept-select-list')).right, lessThanOrEqualTo(w));
        expect(t.getRect(_k('dept-select-list')).bottom, lessThanOrEqualTo(h));
        await v.tapKey(t, 'dept-option-1');
        // every action of the form can be scrolled to and is inside the width
        await t.ensureVisible(_k('desig-submit'));
        await t.pump();
        expect(t.getRect(_k('desig-submit')).right, lessThanOrEqualTo(w));
        expect(t.getSize(_k('desig-submit')).height, greaterThanOrEqualTo(44));
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('dark theme: the form and selector draw without overflow', (t) async {
      await v.openDepartments(t, dark: true, shots: false);
      await v.openAddDesignation(t, dept: v.longDeptName);
      await v.tapKey(t, 'desig-dept-field');
      expect(t.takeException(), isNull);
    });
  });
}
