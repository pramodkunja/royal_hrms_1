import 'dart:async';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/employees/data/models/employee_model.dart';
import 'package:mobile_app/features/employees/presentation/providers/employee_providers.dart';
import 'package:mobile_app/features/employees/presentation/screens/employee_profile_screen.dart';

// HR Employee Detail: notice period (web employees/[id] Personal card,
// "Notice Period", formatNoticePeriod) and Reset Password (web
// ResetPasswordModal → POST /employees/<code>/reset-password/, employees.edit),
// against a stand-in for production EmployeeDetailView / _employee_dict and
// EmployeeResetPasswordView. Synthetic data only; no real reset is made.

const code = 'EMP-7';
const detailPath = '/employees/$code/';
const resetPath = '/employees/$code/reset-password/';

Map<String, dynamic> employee({Object? notice = 30, bool omitNotice = false}) => {
      'id': 'u7',
      'employee_id': code,
      'first_name': 'Pat',
      'last_name': 'Kumar',
      'full_name': 'Pat Kumar',
      'email': 'pat.kumar@example.test',
      'phone': '9000000000',
      'department': 'Engineering',
      'designation': 'Engineer',
      'branch': 'Surat',
      'role': 'employee',
      'role_display': 'Employee',
      'is_active': true,
      'status': 'active',
      'date_of_joining': '2026-01-05',
      'reporting_manager': {'id': 'EMP-2', 'name': 'Morgan Lee'},
      'hr': {'id': 'EMP-4', 'name': 'Hema Iyer'},
      if (!omitNotice) 'notice_period_days': notice,
      'documents': [],
      'profile': {'gender': 'male'},
    };

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

class FakeEmployeeServer implements HttpClientAdapter {
  FakeEmployeeServer(this.detail);
  Map<String, dynamic> detail;
  bool emailSent = true;
  ({int status, String message})? refuseNextReset;
  bool dropNextReset = false;
  Completer<void>? holdReset;
  final calls = <({String method, String path, Object? body})>[];

  int count(String method, String path) => calls.where((c) => c.method == method && c.path == path).length;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add((method: o.method, path: o.path, body: o.data));
    if (o.path == detailPath && o.method == 'GET') {
      return _json(200, {'status': 'success', 'message': 'Employee retrieved.', 'data': detail});
    }
    if (o.path == resetPath && o.method == 'POST') {
      final gate = holdReset;
      if (gate != null) await gate.future;
      if (dropNextReset) {
        dropNextReset = false;
        throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
      }
      final refusal = refuseNextReset;
      if (refusal != null) {
        refuseNextReset = null;
        return _json(refusal.status, {'status': 'error', 'message': refusal.message, 'data': {}});
      }
      return _json(200, {
        'status': 'success',
        'message': emailSent
            ? 'Password reset. New credentials sent to pat.kumar@example.test.'
            : 'Password reset, but the notification email could not be sent (SMTP down). Share the new password '
                'with Pat Kumar manually — check Settings → SMTP.',
        'data': {'email_sent': emailSent},
      });
    }
    return _json(404, {'status': 'error', 'message': 'Not found', 'data': {}});
  }

  @override
  void close({bool force = false}) {}
}

class _NullStorage extends SecureStorageService {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

class _Auth extends AuthNotifier {
  _Auth(this.u);
  final UserEntity u;
  @override
  Future<AuthState> build() async => AuthState(user: u);
}

UserEntity hrUser(List<String> perms) => UserEntity(
      id: 'hr1',
      email: 'hr@example.test',
      fullName: 'Hema Iyer',
      role: 'hr',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: perms,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final hrEditor = hrUser(['employees.view', 'employees.edit']);
final hrViewer = hrUser(['employees.view']);

late FakeEmployeeServer server;
late ProviderContainer container;

Future<void> pumpDetail(WidgetTester tester, {UserEntity? as, Map<String, dynamic>? detail}) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = FakeEmployeeServer(detail ?? employee());
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _Auth(as ?? hrEditor)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: const MaterialApp(home: EmployeeProfileScreen(employeeId: code)),
  ));
  await tester.pumpAndSettle();
  container = ProviderScope.containerOf(tester.element(find.byType(EmployeeProfileScreen)));
  await container.read(authStateProvider.future);
  await tester.pumpAndSettle();
}

String noticeShown(WidgetTester tester) {
  final field = find.byKey(const Key('employee-notice-period'));
  final texts = tester.widgetList<Text>(find.descendant(of: field, matching: find.byType(Text))).map((t) => t.data);
  expect(texts.first, 'Notice Period');
  return texts.last!;
}

final resetButton = find.byKey(const Key('employee-reset-password'));
final dialog = find.byKey(const Key('reset-password-dialog'));
final confirmButton = find.byKey(const Key('reset-password-confirm'));

Future<void> openDialog(WidgetTester tester) async {
  await tester.tap(resetButton);
  await tester.pumpAndSettle();
}

Future<void> confirm(WidgetTester tester) async {
  await tester.tap(confirmButton);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('notice period', () {
    test('the model reads notice_period_days; anything unusable is "not assigned"', () {
      int? days(Object? v, {bool omit = false}) =>
          EmployeeModel.fromJson(employee(notice: v, omitNotice: omit)).noticePeriodDays;
      expect(days(30), 30);
      expect(days(1), 1);
      expect(days(0), 0);
      expect(days('45'), 45);
      expect(days(null), isNull);
      expect(days(null, omit: true), isNull);
      for (final odd in ['soon', -5, 2.5, true, <String, dynamic>{}]) {
        expect(days(odd), isNull, reason: '$odd');
      }
      // Carried through a status copy.
      expect(EmployeeModel.fromJson(employee()).copyWith(isActive: false).noticePeriodDays, 30);
    });

    testWidgets('1. shown read-only beside the work details, as on web', (tester) async {
      await pumpDetail(tester);
      expect(noticeShown(tester), '30 days');
      await tester.pumpWidget(const SizedBox());
      await pumpDetail(tester, detail: employee(notice: 1));
      expect(noticeShown(tester), '1 day');
    });

    testWidgets('2. null or missing: "Not assigned"', (tester) async {
      await pumpDetail(tester, detail: employee(notice: null));
      expect(noticeShown(tester), 'Not assigned');
      await tester.pumpWidget(const SizedBox());
      await pumpDetail(tester, detail: employee(omitNotice: true));
      expect(noticeShown(tester), 'Not assigned');
    });

    testWidgets('3. zero is "0 days" (web formatNoticePeriod); an unusable value is "Not assigned"', (tester) async {
      await pumpDetail(tester, detail: employee(notice: 0));
      expect(noticeShown(tester), '0 days');
      await tester.pumpWidget(const SizedBox());
      await pumpDetail(tester, detail: employee(notice: 'abc'));
      expect(noticeShown(tester), 'Not assigned');
    });

    testWidgets('4. other details are unchanged', (tester) async {
      await pumpDetail(tester);
      for (final t in [
        'EMP-7',
        'Employee',
        'Engineering',
        'Engineer',
        'Morgan Lee',
        'Hema Iyer',
        'pat.kumar@example.test'
      ]) {
        expect(find.text(t), findsWidgets, reason: t);
      }
      expect(find.text('Reporting Manager'), findsWidgets);
      expect(find.text('HR Contact'), findsOneWidget);
    });
  });

  group('reset password', () {
    testWidgets('5 & 6. shown only with employees.edit', (tester) async {
      await pumpDetail(tester);
      expect(resetButton, findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await pumpDetail(tester, as: hrViewer);
      expect(resetButton, findsNothing);
    });

    testWidgets('7. asks first, with web\'s wording; Cancel sends nothing', (tester) async {
      await pumpDetail(tester);
      await openDialog(tester);
      expect(dialog, findsOneWidget);
      expect(find.text('Reset Password?'), findsOneWidget);
      expect(
          find.textContaining(
              'A new temporary password will be generated for Pat Kumar and emailed to them. '
              'Their current password will stop working immediately.',
              findRichText: true),
          findsOneWidget);
      await tester.tap(find.byKey(const Key('reset-password-cancel')));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
      expect(server.count('POST', resetPath), 0);
    });

    testWidgets('8 & 9. POST to /employees/<code>/reset-password/ with no body; success shows the server message',
        (tester) async {
      await pumpDetail(tester);
      await openDialog(tester);
      await confirm(tester);
      final call = server.calls.singleWhere((c) => c.method == 'POST');
      expect(call.path, resetPath);
      expect(call.body, isNull);
      expect(dialog, findsNothing);
      expect(find.text('Password reset. New credentials sent to pat.kumar@example.test.'), findsOneWidget);
      expect(tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor, AppColors.success);
      // No password anywhere on screen.
      expect(find.textContaining('Temporary Password'), findsNothing);
    });

    testWidgets('9b. password changed but email not sent: the server message, shown as a warning', (tester) async {
      await pumpDetail(tester);
      server.emailSent = false;
      await openDialog(tester);
      await confirm(tester);
      expect(find.textContaining('the notification email could not be sent'), findsOneWidget);
      // Web shows this toast as an error: the password changed, but the
      // employee could not be told.
      expect(tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor, AppColors.error);
      expect(dialog, findsNothing);
    });

    testWidgets('10. a refusal keeps the dialog open with the server message; never reported as done', (tester) async {
      await pumpDetail(tester);
      for (final (status, message) in [
        (403, 'You do not have permission to perform this action.'),
        (404, 'Employee not found.'),
        (400, 'Use Change Password from your own account instead.'),
      ]) {
        server.refuseNextReset = (status: status, message: message);
        await openDialog(tester);
        await confirm(tester);
        expect(dialog, findsOneWidget, reason: '$status');
        expect(find.byKey(const Key('reset-password-error')), findsOneWidget);
        expect(find.text(message), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
        await tester.tap(find.byKey(const Key('reset-password-cancel')));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('11. no connection: a clear message, and trying again works', (tester) async {
      await pumpDetail(tester);
      server.dropNextReset = true;
      await openDialog(tester);
      await confirm(tester);
      expect(dialog, findsOneWidget);
      final error = tester.widget<Text>(find.byKey(const Key('reset-password-error'))).data!;
      expect(error, isNot(contains('DioException')));
      expect(error.toLowerCase(), contains('internet'));
      await confirm(tester); // retry
      expect(dialog, findsNothing);
      expect(server.count('POST', resetPath), 2);
      expect(find.text('Password reset. New credentials sent to pat.kumar@example.test.'), findsOneWidget);
    });

    testWidgets('12. while resetting: "Resetting…", both buttons disabled, one request only', (tester) async {
      await pumpDetail(tester);
      final gate = server.holdReset = Completer<void>();
      await openDialog(tester);
      await tester.tap(confirmButton);
      await tester.pump();
      expect(find.text('Resetting…'), findsOneWidget);
      expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);
      expect(tester.widget<TextButton>(find.byKey(const Key('reset-password-cancel'))).onPressed, isNull);
      await tester.tap(confirmButton, warnIfMissed: false);
      await tester.pump();
      // A second call straight to the resetter is ignored too.
      expect(await container.read(employeePasswordResetterProvider).reset(code), isA<EmployeePasswordResetIgnored>());
      gate.complete();
      await tester.pumpAndSettle();
      expect(server.count('POST', resetPath), 1);
    });

    testWidgets('13. without employees.edit the action is refused below the UI; nothing is sent', (tester) async {
      await pumpDetail(tester, as: hrViewer);
      final outcome = await container.read(employeePasswordResetterProvider).reset(code);
      expect(outcome, isA<EmployeePasswordResetFailed>());
      expect((outcome as EmployeePasswordResetFailed).message, kResetPasswordNotPermitted);
      expect(server.count('POST', resetPath), 0);
    });
  });
}
