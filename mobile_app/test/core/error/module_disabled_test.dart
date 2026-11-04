import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/error/exceptions.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/features/attendance/domain/entities/attendance_entity.dart';
import 'package:mobile_app/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:mobile_app/features/expenses/data/models/expense_model.dart';
import 'package:mobile_app/features/expenses/presentation/providers/expense_providers.dart';
import 'package:mobile_app/features/leave/domain/entities/leave_entity.dart';
import 'package:mobile_app/features/leave/presentation/providers/leave_providers.dart';
import 'package:mobile_app/features/my_requests/presentation/providers/my_requests_providers.dart';
import 'package:mobile_app/features/wfh/domain/entities/wfh_entity.dart';
import 'package:mobile_app/features/wfh/presentation/providers/wfh_providers.dart';
import 'package:mobile_app/shared/widgets/app_error_state.dart';

// Phase 5 (B): a module the company has switched off. The backend's tenant
// middleware answers with 403 and "<Module> is not enabled for your
// company. Contact your administrator to enable it." — kept and shown as
// such, and kept apart from missing permission, connection and server
// failures, and from an empty result.

const disabledMsg = 'Expenses is not enabled for your company. Contact your administrator to enable it.';

DioException http(int status, Object? body, {String path = '/expenses/'}) {
  final o = RequestOptions(path: path);
  return DioException(
    requestOptions: o,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: o, statusCode: status, data: body),
  );
}

Map<String, dynamic> envelope(String message) => {'status': 'error', 'message': message, 'data': {}};

class _Leave extends LeaveRequestsNotifier {
  @override
  Future<List<LeaveRequestEntity>> build() async => const [];
}

class _Wfh extends WfhMyRequestsNotifier {
  @override
  Future<List<WfhRequestEntity>> build() async => const [];
}

class _Expenses extends ExpenseListNotifier {
  _Expenses(this.error);
  final Object? error;
  @override
  Future<List<ExpenseModel>> build() async {
    if (error != null) throw error!;
    return const [];
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('classification', () {
    test('a disabled module keeps the server message and is its own kind', () {
      final e = parseDioException(http(403, envelope(disabledMsg)));
      expect(e, isA<ModuleDisabledException>());
      expect(e, isA<ForbiddenException>()); // existing 403 handling still applies
      expect(e.message, disabledMsg);
      expect(appErrorKind(http(403, envelope(disabledMsg))), AppErrorKind.moduleDisabled);
      expect(userFriendlyMessage(http(403, envelope(disabledMsg))), disabledMsg);
    });

    test('a permission refusal is not a disabled module', () {
      final err = http(403, envelope('You do not have permission to manage contacts.'));
      expect(parseDioException(err), isNot(isA<ModuleDisabledException>()));
      expect(appErrorKind(err), AppErrorKind.forbidden);
      expect(userFriendlyMessage(err), 'You do not have permission to manage contacts.');
    });

    test('a 403 without the backend wording is never guessed to be a disabled module', () {
      expect(appErrorKind(http(403, null)), AppErrorKind.forbidden);
      expect(appErrorKind(http(403, envelope(''))), AppErrorKind.forbidden);
    });

    test('connection and server failures stay distinct', () {
      final o = RequestOptions(path: '/expenses/');
      expect(
          appErrorKind(DioException(requestOptions: o, type: DioExceptionType.connectionError)), AppErrorKind.network);
      expect(appErrorKind(http(500, envelope('Server error.'))), AppErrorKind.server);
      expect(appErrorKind(http(404, envelope('Not found.'))), AppErrorKind.unknown);
    });

    test('the login lockout 403 is unaffected', () {
      final o = RequestOptions(path: '/login/');
      final e = parseDioException(DioException(
          requestOptions: o,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: o, statusCode: 403, data: envelope('Account locked.'))));
      expect(e, isA<AccountLockedException>());
    });

    test('an empty disabled-module message falls back to a clear explanation', () {
      expect(userFriendlyMessage(const ModuleDisabledException('')), kModuleDisabledFallback);
      expect(userFriendlyMessage(const ModuleDisabledException()), kModuleDisabledFallback);
    });

    test('the server message re-thrown as a plain Exception is still recognised', () {
      expect(moduleDisabledMessage(Exception(disabledMsg)), disabledMsg);
      expect(moduleDisabledMessage(Exception('Something else')), isNull);
    });
  });

  group('rendering', () {
    Future<void> show(WidgetTester tester, Object error, {VoidCallback? onRetry}) async {
      await tester
          .pumpWidget(MaterialApp(home: Scaffold(body: AppErrorState.forError(error, onRetry: onRetry ?? () {}))));
    }

    testWidgets('disabled module: its own title and the backend text, no Retry', (tester) async {
      await show(tester, http(403, envelope(disabledMsg)));
      expect(find.text('Not enabled for your company'), findsOneWidget);
      expect(find.text(disabledMsg), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('missing message: the fallback explanation', (tester) async {
      await show(tester, const ModuleDisabledException(''));
      expect(find.text(kModuleDisabledFallback), findsOneWidget);
    });

    testWidgets('permission refusal: Access denied with the server text, no Retry', (tester) async {
      await show(tester, http(403, envelope('You do not have permission to view this.')));
      expect(find.text('Access denied'), findsOneWidget);
      expect(find.text('You do not have permission to view this.'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('connection failure: No connection, with Retry', (tester) async {
      var retried = 0;
      await show(tester, DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionError),
          onRetry: () => retried++);
      expect(find.text('No connection'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, 1);
    });

    testWidgets('server error: the server message with Retry', (tester) async {
      await show(tester, http(500, envelope('Server error.')));
      expect(find.text('Server error.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('My Requests with a switched-off module', () {
    ProviderContainer container(Object? expensesError) {
      final c = ProviderContainer(overrides: [
        leaveRequestsProvider.overrideWith(_Leave.new),
        wfhMyRequestsProvider.overrideWith(_Wfh.new),
        expenseListProvider.overrideWith(() => _Expenses(expensesError)),
        myCorrectionsProvider.overrideWith((ref) async => const <MyCorrectionEntity>[]),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('the rest still loads; the server reason is kept as a notice', () async {
      final c = container(const ModuleDisabledException(disabledMsg));
      final sub = c.listen(myRequestsModuleNoticesProvider, (_, __) {});
      expect(await c.read(myRequestsProvider.future), isEmpty);
      expect(sub.read(), [disabledMsg]);
    });

    test('all modules enabled with no records: empty, no notice', () async {
      final c = container(null);
      final sub = c.listen(myRequestsModuleNoticesProvider, (_, __) {});
      expect(await c.read(myRequestsProvider.future), isEmpty);
      expect(sub.read(), isEmpty);
    });

    test('any other failure still fails the list (not shown as empty)', () async {
      final c = container(http(500, envelope('Server error.')));
      final sub = c.listen(myRequestsProvider, (_, __) {});
      await expectLater(c.read(myRequestsProvider.future), throwsA(isA<DioException>()));
      expect(sub.read().hasError, isTrue);
    });
  });
}
