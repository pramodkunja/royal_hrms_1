// Task 111 Part A harness: the Org Chart screen with a stand-in repository (nothing leaves the test)
// and render-evidence shots (T1011_SHOTS=1).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_theme.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/org_chart/domain/entities/org_chart_entity.dart';
import 'package:mobile_app/features/org_chart/domain/repositories/org_chart_repository.dart';
import 'package:mobile_app/features/org_chart/presentation/providers/org_chart_providers.dart';
import 'package:mobile_app/features/org_chart/presentation/screens/org_chart_screen.dart';

import 'shot_harness.dart';

OrgPersonEntity person(String name, {String designation = '', String code = 'EMP-1'}) =>
    OrgPersonEntity(id: 'p-$name', employeeId: code, name: name, designation: designation);

/// A chart with every kind of value: real, hyphenated, numeric-looking, blank, missing.
OrgChartEntity sampleChart({bool rootMissing = true}) => OrgChartEntity(
      scope: OrgChartScope.company,
      groups: [
        OrgChartGroupEntity(
          branch: 'Hyderabad HQ',
          root: rootMissing ? null : person('Asha Verma', designation: 'Managing Director'),
          departments: [
            OrgDepartmentEntity(
                id: 1,
                label: 'ENGINEERING',
                head: person('Priya Nair', designation: 'VP Engineering'),
                members: [
                  person('Ravi Kumar', designation: 'Engineer'),
                  person('', designation: 'Intern'),
                  person("Anne-Marie O'Neil-Smith", designation: '0')
                ]),
            const OrgDepartmentEntity(id: 2, label: 'FINANCE', members: [
              OrgPersonEntity(id: 'p-f1', employeeId: 'EMP-9', name: 'Meera Joshi', designation: 'Accountant'),
            ]),
            OrgDepartmentEntity(
                id: 3, label: 'OPERATIONS', head: person('   ', designation: 'Head of Operations'), members: const []),
            OrgDepartmentEntity(id: 4, label: 'LEGAL', head: person('J.-P. Fournier-Lefèvre'), members: const []),
            const OrgDepartmentEntity(
                id: 5, label: 'INTERNATIONAL REGULATORY COMPLIANCE AND CORPORATE AFFAIRS DIVISION', members: []),
          ],
        ),
      ],
    );

class FakeOrgRepo implements OrgChartRepository {
  FakeOrgRepo(this.chart);
  final OrgChartEntity chart;
  @override
  Future<OrgChartEntity> getOrgChart({String? branch}) async => chart;
  @override
  Future<List<String>> getBranchNames() async => const ['Hyderabad HQ'];
}

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState(
      user: UserEntity(
          id: 'u1',
          email: 'a@example.test',
          fullName: 'Test User',
          role: 'employee',
          roleDisplay: 'Employee',
          mustChangePassword: false,
          permissions: ['org_chart.view', 'employees.view'],
          onboardingStatus: 'complete',
          assessmentStatus: 'complete'));
}

Future<void> openOrgChart(WidgetTester t,
    {OrgChartEntity? chart,
    Size size = const Size(393, 1400),
    double scale = 1,
    bool dark = false,
    bool shots = true}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  AppColors.applyMode(dark);
  addTearDown(() => AppColors.applyMode(false));
  if (shots && shotsEnabled) await t.runAsync(loadShotFonts);
  await t.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith(_Auth.new),
      orgChartRepositoryProvider.overrideWithValue(FakeOrgRepo(chart ?? sampleChart())),
    ],
    child: shotFrame(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(dark),
      builder: (c, child) =>
          MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
      home: const OrgChartScreen(),
    )),
  ));
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 80));
  }
}

void shot(String name, Future<void> Function(WidgetTester t) body) {
  testWidgets('shot $name', (t) async {
    await body(t);
    await shoot(t, name);
  }, skip: !shotsEnabled);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  shot('o_01_chart', (t) => openOrgChart(t));
  shot('o_02_320_2x', (t) => openOrgChart(t, size: const Size(320, 2400), scale: 2));
  shot('o_03_tablet_1000', (t) => openOrgChart(t, size: const Size(1000, 1000)));
  shot('o_04_dark', (t) => openOrgChart(t, dark: true));
  shot('o_05_root_present', (t) => openOrgChart(t, chart: sampleChart(rootMissing: false)));
}
