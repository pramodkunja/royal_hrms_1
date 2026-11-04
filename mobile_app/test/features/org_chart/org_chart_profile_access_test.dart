import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/org_chart/domain/entities/org_chart_entity.dart';
import 'package:mobile_app/features/org_chart/domain/repositories/org_chart_repository.dart';
import 'package:mobile_app/features/org_chart/presentation/providers/org_chart_providers.dart';
import 'package:mobile_app/features/org_chart/presentation/screens/org_chart_screen.dart';

// Every role can open the Org Chart (org_chart.view), but employee profiles
// need employees.view. Found in live emulator testing: an employee tapping a
// person was bounced to the dashboard by the route guard. The tap now
// explains instead of navigating.

UserEntity _user(List<String> permissions) => UserEntity(
      id: 'u-1',
      email: 'temp@example.com',
      fullName: 'Temp User',
      role: 'employee',
      roleDisplay: 'Employee',
      mustChangePassword: false,
      permissions: permissions,
      onboardingStatus: 'complete',
      companyCode: 'ROYAL01',
    );

const _person = OrgPersonEntity(id: 'p-1', employeeId: 'emp-42', name: 'Pat Person', designation: 'Engineer');

class _FakeRepo implements OrgChartRepository {
  @override
  Future<OrgChartEntity> getOrgChart({String? branch}) async => const OrgChartEntity(
        scope: OrgChartScope.branch,
        groups: [
          OrgChartGroupEntity(branch: 'HQ', departments: [
            OrgDepartmentEntity(id: 1, label: 'ENGINEERING', members: [_person]),
          ]),
        ],
      );

  @override
  Future<List<String>> getBranchNames() async => const [];
}

class _FixedAuthNotifier extends AuthNotifier {
  _FixedAuthNotifier(this._user);
  final UserEntity _user;
  @override
  Future<AuthState> build() async => AuthState(user: _user);
}

Future<void> _tapPerson(WidgetTester tester, UserEntity user) async {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const OrgChartScreen()),
    GoRoute(path: '/dashboard/employees/:id', builder: (_, s) => Text('PROFILE ${s.pathParameters['id']}')),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _FixedAuthNotifier(user)),
      orgChartRepositoryProvider.overrideWithValue(_FakeRepo()),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
  if (find.text('Pat Person').evaluate().isEmpty) {
    await tester.tap(find.text('ENGINEERING'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Pat Person'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('without employees.view: no navigation, an explanation instead', (tester) async {
    await _tapPerson(tester, _user(const ['org_chart.view']));
    expect(find.text('PROFILE emp-42'), findsNothing);
    expect(find.text("You don't have access to employee profiles."), findsOneWidget);
  });

  testWidgets('with employees.view: the profile opens', (tester) async {
    await _tapPerson(tester, _user(const ['org_chart.view', 'employees.view']));
    expect(find.text('PROFILE emp-42'), findsOneWidget);
  });
}
