import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/settings/data/models/attendance_settings_model.dart';
import 'package:mobile_app/features/settings/presentation/attendance_rules/attendance_rules_screen.dart';

// Phase 11.3: Attendance Rules policy fields — missing_punch_action,
// early_leave_allowance_per_month, wfh_daily_report_required (punch_rules)
// and late_mark_mode (late_mark_rules) — against a stand-in for the
// production endpoint (GET/PATCH /attendance/settings/), which, like
// AttendanceSettingsService._apply_fields, changes only the fields sent.

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

Map<String, dynamic> settingsJson({Map<String, dynamic>? punch, Map<String, dynamic>? late}) => {
      'working_hours': {
        'shift_start': '09:00:00',
        'shift_end': '18:00:00',
        'grace_period_minutes': 15,
        'break_duration_minutes': 30,
      },
      'weekly_off': {
        'monday': false,
        'tuesday': false,
        'wednesday': false,
        'thursday': false,
        'friday': false,
        'saturday': true,
        'sunday': true,
      },
      'punch_rules': punch ??
          {
            'min_hours_full_day': '8.00',
            'min_hours_half_day': '4.00',
            'early_exit_grace_minutes': 30,
            'missing_punch_action': 'mark_half_day',
            'early_leave_allowance_per_month': 2,
            'wfh_daily_report_required': true,
          },
      'overtime_rules': {
        'ot_threshold_hours': '9.00',
        'ot_multiplier_regular': '1.50',
        'ot_multiplier_holiday': '2.00'
      },
      'late_mark_rules':
          late ?? {'late_marks_per_lop': 3, 'lop_deduction_unit': 'full_day', 'late_mark_mode': 'every_n'},
      'absence_alert': {'is_enabled': true, 'alert_after_days': 3, 'notify_whom': 'manager_and_hr'},
      'face_verification': {'is_mandatory': false},
    };

class FakeSettingsServer implements HttpClientAdapter {
  FakeSettingsServer(this.state);
  final Map<String, dynamic> state;
  final patches = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.path == '/attendance/settings/' && o.method == 'GET') {
      return _json(200, {'status': 'success', 'message': 'ok', 'data': state});
    }
    if (o.path == '/attendance/settings/' && o.method == 'PATCH') {
      final body = (o.data as Map).cast<String, dynamic>();
      patches.add(jsonDecode(jsonEncode(body)) as Map<String, dynamic>);
      body.forEach((section, fields) {
        final current = Map<String, dynamic>.from(state[section] as Map);
        current.addAll((fields as Map).cast<String, dynamic>()); // only the fields sent
        state[section] = current;
      });
      return _json(200, {'status': 'success', 'message': 'Attendance settings updated successfully.', 'data': state});
    }
    return _json(404, {'status': 'error', 'message': 'Not found', 'data': {}});
  }

  @override
  void close({bool force = false}) {}
}

class _Auth extends AuthNotifier {
  _Auth(this.perms);
  final List<String> perms;
  @override
  Future<AuthState> build() async => AuthState(
      user: UserEntity(
          id: 'u1',
          email: 'hr@example.test',
          fullName: 'HR Tester',
          role: 'hr',
          roleDisplay: 'HR',
          mustChangePassword: false,
          permissions: perms,
          onboardingStatus: 'complete',
          assessmentStatus: 'complete'));
}

late FakeSettingsServer server;

Future<void> pump(WidgetTester tester, Map<String, dynamic> state,
    {List<String> perms = const ['settings.view', 'settings.edit']}) async {
  tester.view.physicalSize = const Size(1080, 5200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = FakeSettingsServer(state);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      authStateProvider.overrideWith(() => _Auth(perms)),
    ],
    child: MaterialApp.router(
        routerConfig: GoRouter(
            initialLocation: '/settings/attendance-rules',
            routes: [GoRoute(path: '/settings/attendance-rules', builder: (_, __) => const AttendanceRulesScreen())])),
  ));
  await tester.pumpAndSettle();
}

/// The label of the item currently selected in a keyed dropdown.
String shown(WidgetTester tester, String key) {
  final dd = tester.widget<DropdownButton<Object?>>(
      find.descendant(of: find.byKey(Key(key)), matching: find.byWidgetPredicate((w) => w is DropdownButton)));
  final item = dd.items!.firstWhere((i) => i.value == dd.value);
  return (item.child as Text).data!;
}

Future<void> choose(WidgetTester tester, String key, String option) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> saveCard(WidgetTester tester, String title) async {
  final card = find.ancestor(of: find.text(title), matching: find.byType(Container)).first;
  final save = find.descendant(of: card, matching: find.widgetWithText(TextButton, 'Save'));
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('model', () {
    test('parses the four policy fields', () {
      final m = AttendanceSettingsModel.fromJson(settingsJson());
      expect(m.punchRules.missingPunchAction, 'mark_half_day');
      expect(m.punchRules.earlyLeaveAllowancePerMonth, 2);
      expect(m.punchRules.wfhDailyReportRequired, isTrue);
      expect(m.lateMarkRules.lateMarkMode, 'every_n');
    });

    test('absent fields stay unknown and are never sent', () {
      final m = AttendanceSettingsModel.fromJson(settingsJson(
        punch: {'min_hours_full_day': '8.00', 'min_hours_half_day': '4.00', 'early_exit_grace_minutes': 30},
        late: {'late_marks_per_lop': 3, 'lop_deduction_unit': 'full_day'},
      ));
      expect(m.punchRules.missingPunchAction, isNull);
      expect(m.punchRules.toJson().keys,
          unorderedEquals(['min_hours_full_day', 'min_hours_half_day', 'early_exit_grace_minutes']));
      expect(m.lateMarkRules.toJson().containsKey('late_mark_mode'), isFalse);
    });

    test('server values are sent back unchanged, including ones the app does not list', () {
      final m = AttendanceSettingsModel.fromJson(settingsJson(
        punch: {
          'min_hours_full_day': '6.00',
          'min_hours_half_day': '4.00',
          'early_exit_grace_minutes': 30,
          'missing_punch_action': 'auto_regularize',
          'early_leave_allowance_per_month': 5,
          'wfh_daily_report_required': false,
        },
      ));
      expect(m.punchRules.toJson(), {
        'min_hours_full_day': '6.00',
        'min_hours_half_day': '4.00',
        'early_exit_grace_minutes': 30,
        'missing_punch_action': 'auto_regularize',
        'early_leave_allowance_per_month': 5,
        'wfh_daily_report_required': false,
      });
    });

    test('backend defaults are the documented ones', () {
      expect(PunchRulesSectionModel.defaultMissingPunchAction, 'require_regularization');
      expect(PunchRulesSectionModel.defaultEarlyLeaveAllowance, 0);
      expect(PunchRulesSectionModel.defaultWfhDailyReportRequired, isFalse);
      expect(LateMarkRulesSectionModel.defaultLateMarkMode, 'every_n');
    });
  });

  group('screen', () {
    testWidgets('shows the server values with web labels and hints', (tester) async {
      await pump(tester, settingsJson());
      expect(shown(tester, 'punch-missing-clock-out'), 'Mark as Half Day');
      expect(shown(tester, 'punch-early-leaves'), '2 per month');
      expect(tester.widget<CheckboxListTile>(find.byKey(const Key('punch-wfh-report'))).value, isTrue);
      expect(shown(tester, 'late-mark-mode'), '1 LOP for every N late marks');
      expect(shown(tester, 'late-marks-n'), '3 late marks = 1 LOP');
      expect(find.text('Clock In without Clock Out after the shift ends. No punch at all is always Absent.'),
          findsOneWidget);
      expect(find.text('Leaving within the Early Exit Grace still counts as a full day, this many times a month.'),
          findsOneWidget);
    });

    testWidgets('unknown fields show the backend defaults', (tester) async {
      await pump(
          tester,
          settingsJson(
            punch: {'min_hours_full_day': '8.00', 'min_hours_half_day': '4.00', 'early_exit_grace_minutes': 30},
            late: {'late_marks_per_lop': 3, 'lop_deduction_unit': 'full_day'},
          ));
      expect(shown(tester, 'punch-missing-clock-out'), 'Incomplete — regularize');
      expect(shown(tester, 'punch-early-leaves'), 'Off');
      expect(tester.widget<CheckboxListTile>(find.byKey(const Key('punch-wfh-report'))).value, isFalse);
      expect(shown(tester, 'late-mark-mode'), '1 LOP for every N late marks');
    });

    testWidgets('values the app does not list are shown, not blanked', (tester) async {
      await pump(
          tester,
          settingsJson(
            punch: {
              'min_hours_full_day': '7.50',
              'min_hours_half_day': '4.00',
              'early_exit_grace_minutes': 30,
              'missing_punch_action': 'auto_regularize',
              'early_leave_allowance_per_month': 5,
              'wfh_daily_report_required': false,
            },
            late: {'late_marks_per_lop': 9, 'lop_deduction_unit': 'full_day', 'late_mark_mode': 'after_allowance'},
          ));
      expect(find.text('7.5 hours'), findsWidgets); // now a listed option, as on web
      expect(shown(tester, 'punch-missing-clock-out'), 'auto_regularize (current)');
      expect(shown(tester, 'punch-early-leaves'), '5 (current)');
      expect(shown(tester, 'late-marks-n'), '9 (current)');
      expect(tester.takeException(), isNull);
    });

    testWidgets('late-mark labels follow the rule; N offers 1–6 and 0', (tester) async {
      await pump(tester, settingsJson());
      await tester.tap(find.byKey(const Key('late-marks-n')));
      await tester.pumpAndSettle();
      for (final label in [
        '1 late mark = 1 LOP',
        '2 late marks = 1 LOP',
        '6 late marks = 1 LOP',
        'No LOP (tracking only)'
      ]) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      await tester.tap(find.text('3 late marks = 1 LOP').last);
      await tester.pumpAndSettle();
      await choose(tester, 'late-mark-mode', 'N late marks allowed, LOP for each after');
      expect(shown(tester, 'late-marks-n'), '3 allowed, then LOP each');
    });

    testWidgets('saving Punch Rules sends only that section, with the changed fields', (tester) async {
      await pump(tester, settingsJson());
      await choose(tester, 'punch-missing-clock-out', 'Mark as Absent');
      await choose(tester, 'punch-early-leaves', '1 per month');
      await tester.ensureVisible(find.byKey(const Key('punch-wfh-report')));
      await tester.tap(find.byKey(const Key('punch-wfh-report')));
      await tester.pumpAndSettle();
      await saveCard(tester, 'Punch Rules');
      expect(server.patches.single, {
        'punch_rules': {
          'min_hours_full_day': '8.00',
          'min_hours_half_day': '4.00',
          'early_exit_grace_minutes': 30,
          'missing_punch_action': 'mark_absent',
          'early_leave_allowance_per_month': 1,
          'wfh_daily_report_required': false,
        },
      });
      expect(server.state['late_mark_rules']['late_mark_mode'], 'every_n'); // untouched
    });

    testWidgets('saving Late Mark sends only that section, with the rule', (tester) async {
      await pump(tester, settingsJson());
      await choose(tester, 'late-mark-mode', 'N late marks allowed, LOP for each after');
      await choose(tester, 'late-marks-n', '5 allowed, then LOP each');
      await saveCard(tester, 'Late Mark & LOP Rule');
      expect(server.patches.single, {
        'late_mark_rules': {
          'late_marks_per_lop': 5,
          'lop_deduction_unit': 'full_day',
          'late_mark_mode': 'after_allowance'
        },
      });
      expect(server.state['punch_rules']['missing_punch_action'], 'mark_half_day'); // untouched
    });

    testWidgets('saving an older-format section never invents the new fields', (tester) async {
      await pump(
          tester,
          settingsJson(
            punch: {'min_hours_full_day': '8.00', 'min_hours_half_day': '4.00', 'early_exit_grace_minutes': 30},
          ));
      await choose(tester, 'punch-early-leaves', '3 per month'); // only this one changed
      await saveCard(tester, 'Punch Rules');
      final sent = server.patches.single['punch_rules'] as Map;
      expect(sent['early_leave_allowance_per_month'], 3);
      expect(sent.containsKey('missing_punch_action'), isFalse);
      expect(sent.containsKey('wfh_daily_report_required'), isFalse);
    });

    testWidgets('without settings.edit everything is read-only and there is no Save', (tester) async {
      await pump(tester, settingsJson(), perms: const ['settings.view']);
      expect(find.widgetWithText(TextButton, 'Save'), findsNothing);
      expect(tester.widget<CheckboxListTile>(find.byKey(const Key('punch-wfh-report'))).onChanged, isNull);
      final dropdown = tester.widget<DropdownButton<Object?>>(find.descendant(
          of: find.byKey(const Key('punch-missing-clock-out')),
          matching: find.byWidgetPredicate((w) => w is DropdownButton)));
      expect(dropdown.onChanged, isNull);
      expect(server.patches, isEmpty);
    });
  });
}
