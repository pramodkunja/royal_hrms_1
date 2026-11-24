import 'dart:async';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/router/access_control.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/employees/data/datasources/employee_assets_datasource.dart';
import 'package:mobile_app/features/settings/data/models/asset_catalogue.dart';
import 'package:mobile_app/features/settings/presentation/assets/assets_settings_screen.dart';
import 'package:mobile_app/features/settings/presentation/settings_hub/settings_screen.dart';

// Task 69: Settings → Assets (asset catalogue) — web settings/assets/page.tsx,
// AssignmentDetails.tsx, types/assets.ts, lib/assetHolder.ts over backend
// apps/assets. The stand-in server applies the backend's rules: assets.view
// to list (non-admins: own branch only), assets.create / edit / delete,
// unique tag / serial, category & type from the master lists or "Other" with a
// name, no deleting an assigned asset, maintenance only for damaged /
// under-repair assets. Synthetic assets; nothing real is created or changed.

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
ResponseBody _ok(Object data, [String message = 'ok', int status = 200]) =>
    _json(status, {'status': 'success', 'message': message, 'data': data});
ResponseBody _err(int status, String message, [Map<String, dynamic>? data]) =>
    _json(status, {'status': 'error', 'message': message, 'data': data ?? {}});

const statusLabel = {
  'available': 'Available',
  'assigned': 'Assigned',
  'under_repair': 'Under Repair',
  'damaged': 'Damaged',
  'retired': 'Retired',
};

Map<String, dynamic> asset(String id, String tag, String name,
        {String status = 'available',
        String category = 'IT Equipment',
        String categoryOther = '',
        String type = 'Laptop',
        String branch = '1',
        String branchName = 'North Wing',
        String condition = 'good',
        Map<String, dynamic>? maintenance,
        Map<String, dynamic>? assignment}) =>
    {
      'id': id,
      'asset_tag': tag,
      'asset_name': name,
      'category': category,
      'category_other': categoryOther,
      'asset_type': type,
      'asset_type_other': '',
      'brand': 'Dell',
      'model': 'L5420',
      'serial_number': 'SN-$tag',
      'purchase_date': null,
      'purchase_price': null,
      'vendor': '',
      'warranty_start_date': null,
      'warranty_end_date': null,
      'branch': branch,
      'branch_name': branchName,
      'status': status,
      'status_display': statusLabel[status] ?? status,
      'condition': condition,
      'condition_display': '${condition[0].toUpperCase()}${condition.substring(1)}',
      'description': '',
      'active_maintenance': maintenance,
      'active_assignment': assignment,
    };

class Backend implements HttpClientAdapter {
  Backend(this.perms);
  final Set<String> perms;
  late List<Map<String, dynamic>> assets = [
    asset('a1', 'LAP-001', 'Dell Latitude', status: 'assigned', assignment: {
      'id': 'as1',
      'status': 'assigned',
      'status_display': 'Assigned',
      'assigned_date': '2026-11-01',
      'expected_return_date': null,
      'employee_hidden': false,
      'employee_name': 'Asha Test',
      'employee_code': 'EMP-2',
    }),
    asset('a2', 'PHN-001', 'Pixel', category: 'Other', categoryOther: 'Mobiles', type: 'Phone', status: 'damaged'),
    asset('a3', 'MON-001', 'Monitor 24',
        type: 'Monitor',
        status: 'under_repair',
        maintenance: {'id': 'm1', 'issue': 'Flickering screen', 'maintenance_start_date': '2026-11-02'}),
    asset('a4', 'LAP-002', 'Spare Laptop', branch: '2', branchName: 'South Wing'),
  ];
  final calls = <(String, String, Object?, Map<String, dynamic>)>[];
  int listStatus = 200;
  int detailStatus = 200;

  /// Holds the next create/update answer until completed (to see the saving state).
  Completer<void>? holdWrite;

  /// Failure / emptiness of the form's pick lists.
  int categoriesStatus = 200;
  bool noBranches = false;
  ({int status, String message, Map<String, dynamic>? data})? refuseNext;
  List<Map<String, dynamic>> categories = [
    {'id': 1, 'name': 'IT Equipment'},
    {'id': 2, 'name': 'Furniture'},
    {'id': 3, 'name': 'Other'},
  ];
  List<Map<String, dynamic>> types = [
    {'id': 10, 'name': 'Laptop', 'category': 1},
    {'id': 11, 'name': 'Monitor', 'category': 1},
    {'id': 12, 'name': 'Chair', 'category': 2},
  ];

  bool can(String p) => perms.contains(p);
  List<Object?> bodies(String method, String path) => [
        for (final c in calls)
          if (c.$1 == method && c.$2 == path) c.$3
      ];
  List<Map<String, dynamic>> lists() => [
        for (final c in calls)
          if (c.$1 == 'GET' && c.$2 == '/assets/') c.$4
      ];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add((o.method, o.path, o.data, Map.of(o.queryParameters)));
    final p = o.path;
    if (holdWrite != null && (o.method == 'POST' || o.method == 'PUT') && p.startsWith('/assets/')) {
      await holdWrite!.future;
    }
    final r = refuseNext;
    if (r != null && o.method != 'GET') {
      refuseNext = null;
      return _err(r.status, r.message, r.data);
    }
    if (p == '/branch/branches/') {
      if (noBranches) return _ok({'results': []});
      return _ok({
        'results': [
          {'id': 1, 'branch_name': 'North Wing'},
          {'id': 2, 'branch_name': 'South Wing'},
        ]
      });
    }
    if (p == '/assets/categories/' && o.method == 'GET') {
      return categoriesStatus == 200 ? _ok(categories) : _err(categoriesStatus, 'Server error.');
    }
    if (p == '/assets/categories/' && o.method == 'POST') {
      if (!can('assets.create')) return _err(403, 'You do not have permission to create asset categories.');
      final name = '${(o.data as Map)['name']}';
      categories = [
        ...categories,
        {'id': 4, 'name': name}
      ];
      return _ok({'id': 4, 'name': name}, 'Asset category created.', 201);
    }
    if (p == '/assets/types/' && o.method == 'GET') {
      final c = o.queryParameters['category'];
      return _ok([
        for (final t in types)
          if (c == null || '${t['category']}' == '$c') t
      ]);
    }
    if (p == '/assets/types/' && o.method == 'POST') {
      final b = Map<String, dynamic>.from(o.data as Map);
      types = [
        ...types,
        {'id': 13, 'name': b['name'], 'category': b['category']}
      ];
      return _ok({'id': 13, 'name': b['name']}, 'Asset type created.', 201);
    }
    if (p == '/assets/' && o.method == 'GET') {
      if (listStatus != 200) return _err(listStatus, 'You do not have permission to view assets.');
      if (!can('assets.view')) return _err(403, 'You do not have permission to view assets.');
      final q = o.queryParameters;
      var rows = assets.where((a) {
        final s = '${q['search'] ?? ''}'.toLowerCase();
        if (s.isNotEmpty && !'${a['asset_tag']} ${a['asset_name']} ${a['serial_number']}'.toLowerCase().contains(s)) {
          return false;
        }
        if ((q['status'] ?? '') != '' && a['status'] != q['status']) return false;
        if ((q['branch'] ?? '') != '' && a['branch'] != '${q['branch']}') return false;
        if ((q['category'] ?? '') != '' && '${a['category']}'.toLowerCase() != '${q['category']}'.toLowerCase()) {
          return false;
        }
        if ((q['asset_type'] ?? '') != '' && '${a['asset_type']}'.toLowerCase() != '${q['asset_type']}'.toLowerCase()) {
          return false;
        }
        return true;
      }).toList();
      final size = int.tryParse('${q['page_size'] ?? 20}') ?? 20;
      final page = int.tryParse('${q['page'] ?? 1}') ?? 1;
      final total = rows.isEmpty ? 1 : ((rows.length + size - 1) ~/ size);
      rows = rows.skip((page - 1) * size).take(size).toList();
      return _ok({'count': rows.length, 'page': page, 'page_size': size, 'total_pages': total, 'results': rows});
    }
    if (p == '/assets/' && o.method == 'POST') {
      if (!can('assets.create')) return _err(403, 'You do not have permission to create assets.');
      final b = Map<String, dynamic>.from(o.data as Map);
      if (assets.any((a) => '${a['asset_tag']}'.toLowerCase() == '${b['asset_tag']}'.toLowerCase())) {
        return _err(400, 'Asset Tag "${b['asset_tag']}" already exists.', {
          'asset_tag': ['Asset Tag "${b['asset_tag']}" already exists.']
        });
      }
      assets = [asset('new', '${b['asset_tag']}', '${b['asset_name']}'), ...assets];
      return _ok(assets.first, 'Asset created successfully.', 201);
    }
    final detail = RegExp(r'^/assets/([^/]+)/$').firstMatch(p);
    if (detail != null) {
      final row = assets.where((a) => a['id'] == detail.group(1)).firstOrNull;
      if (row == null) return _err(404, 'Asset not found.');
      if (o.method == 'GET') {
        if (detailStatus != 200) return _err(detailStatus, 'Server error.');
        return _ok(row);
      }
      if (o.method == 'PUT') {
        if (!can('assets.edit')) return _err(403, 'You do not have permission to edit assets.');
        row.addAll(Map<String, dynamic>.from(o.data as Map));
        return _ok(row, 'Asset updated successfully.');
      }
      if (o.method == 'DELETE') {
        if (!can('assets.delete')) return _err(403, 'You do not have permission to delete assets.');
        if (row['status'] == 'assigned') {
          return _err(
              409, 'Cannot delete "${row['asset_tag']}" — it is currently assigned to an employee. Return it first.');
        }
        assets = assets.where((a) => a != row).toList();
        return _ok({}, 'Asset deleted successfully.');
      }
    }
    final send = RegExp(r'^/assets/([^/]+)/send-to-maintenance/$').firstMatch(p);
    if (send != null) {
      final row = assets.firstWhere((a) => a['id'] == send.group(1));
      row['status'] = 'under_repair';
      row['status_display'] = 'Under Repair';
      return _ok({}, 'Asset sent to maintenance.', 201);
    }
    final complete = RegExp(r'^/assets/maintenance/([^/]+)/complete/$').firstMatch(p);
    if (complete != null) return _ok({}, 'Maintenance completed.');
    return _err(404, 'Not found: ${o.method} $p');
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

UserEntity user(List<String> perms, {bool superuser = false, List<String>? modules}) => UserEntity(
      id: 'u1',
      email: 'hr@example.test',
      fullName: 'Test HR',
      role: 'hr',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: superuser,
      enabledModules: modules,
      branch: 'North Wing',
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

const allAssetPerms = ['settings.view', 'assets.view', 'assets.create', 'assets.edit', 'assets.delete'];
final admin = user(allAssetPerms);
final viewer = user(['settings.view', 'assets.view']);

late Backend server;
Finder byKey(String k) => find.byKey(Key(k));
String? statusOf(WidgetTester t, String id) =>
    t.widget<Text>(find.descendant(of: byKey('asset-status-$id'), matching: find.byType(Text))).data;

Future<void> pump(WidgetTester tester, {UserEntity? as, void Function(Backend)? setup, Widget? child}) async {
  tester.view.physicalSize = const Size(1080, 4200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final u = as ?? admin;
  server = Backend({...u.permissions});
  setup?.call(server);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      assetDatePickerProvider.overrideWithValue((context, initial) async => DateTime(2026, 11, 13)),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(initialLocation: '/s', routes: [
        GoRoute(
          path: '/s',
          builder: (_, __) => Consumer(
            builder: (context, ref, _) => ref.watch(authStateProvider).valueOrNull?.user == null
                ? const SizedBox()
                : (child ?? const AssetsSettingsScreen()),
          ),
        ),
      ]),
    ),
  ));
  await settle(tester);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(byKey(key));
  await tester.tap(byKey(key));
  await settle(tester);
  // The form is a full-screen route: let a page transition (push or pop) finish.
  await settle(tester);
}

Future<void> choose(WidgetTester tester, String key, String option) async {
  await tester.ensureVisible(byKey(key));
  await tester.tap(byKey(key));
  await settle(tester);
  await tester.tap(find.text(option).last);
  await settle(tester);
}

Future<void> type(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(byKey(key));
  await tester.enterText(byKey(key), text);
  await settle(tester);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('rules', () {
    test('payload as web save(): blank dates, price and serial sent as null', () {
      final f = blankAssetForm()
        ..['asset_tag'] = 'LAP-9'
        ..['asset_name'] = 'Test'
        ..['branch'] = '1';
      final p = assetPayload(f);
      expect(p['purchase_price'], isNull);
      expect(p['purchase_date'], isNull);
      expect(p['warranty_start_date'], isNull);
      expect(p['warranty_end_date'], isNull);
      expect(p['serial_number'], isNull);
      expect(p['condition'], 'new');
      expect(p['vendor'], '');
      expect(p.keys.toSet(), kAssetFormFields.toSet());
    });

    test('holder view as web lib/assetHolder.ts', () {
      CatalogueAsset a(Map<String, dynamic>? assignment, {String status = 'assigned'}) =>
          CatalogueAsset(asset('x', 'T', 'N', status: status, assignment: assignment));
      final shown = holderView(a({
        'status_display': 'Assigned',
        'assigned_date': '2026-11-01',
        'employee_hidden': false,
        'employee_name': 'Asha',
        'employee_code': 'EMP-2',
      })) as HolderAssigned;
      expect((shown.employee, shown.code, shown.hidden), ('Asha', 'EMP-2', false));
      final hidden = holderView(a({
        'status_display': 'Assigned',
        'assigned_date': '2026-11-01',
        'employee_hidden': true,
        'employee_name': null,
        'employee_code': null,
      })) as HolderAssigned;
      expect((hidden.employee, hidden.code), ('Not visible to you', null));
      expect(
          (holderView(a(null)) as HolderNone).message, 'Marked Assigned, but no active assignment record was found.');
      expect((holderView(a(null, status: 'available')) as HolderNone).message, 'Not currently assigned.');
    });

    test('module gate: Settings → Assets needs the assets module (unknown list → shown)', () {
      expect(moduleForPath('/settings/assets'), 'assets');
      expect(canAccessPath(user(['settings.view'], modules: const ['leave']), '/settings/assets'), isFalse);
      expect(canAccessPath(user(['settings.view'], modules: const ['assets']), '/settings/assets'), isTrue);
      expect(canAccessPath(user(['settings.view']), '/settings/assets'), isTrue);
      expect(canAccessPath(user(const [], modules: const ['assets']), '/settings/assets'), isFalse); // settings.view
    });
  });

  group('list', () {
    testWidgets('rows as web: tag, name, category / type ("Other (…)"), branch, status, condition', (tester) async {
      await pump(tester);
      expect(find.text('LAP-001'), findsOneWidget);
      expect(find.text('Dell Latitude'), findsOneWidget);
      expect(find.text('Other (Mobiles)'), findsOneWidget); // category chip
      expect(find.text('Phone'), findsOneWidget); // type chip
      expect(find.text('North Wing'), findsWidgets); // branch chip
      expect(find.text('Condition: Good'), findsWidgets);
      expect(statusOf(tester, 'a3'), 'Under Repair');
      expect(server.lists().first, {'page': 1, 'page_size': 20});
      // Actions by status: maintenance only for damaged, complete only under repair.
      expect(byKey('asset-maintenance-a2'), findsOneWidget);
      expect(byKey('asset-maintenance-a1'), findsNothing);
      expect(byKey('asset-complete-a3'), findsOneWidget);
      expect(byKey('asset-complete-a2'), findsNothing);
      expect(byKey('asset-edit-a1'), findsOneWidget);
      expect(byKey('asset-delete-a1'), findsOneWidget);
      expect(byKey('asset-add'), findsOneWidget);
    });

    testWidgets('filters send web\'s query and go back to page 1', (tester) async {
      await pump(tester);
      await type(tester, 'asset-search', 'lap');
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);
      expect(server.lists().last, {'search': 'lap', 'page': 1, 'page_size': 20});
      expect(find.text('Pixel'), findsNothing);
      await tapKey(tester, 'asset-pill-available'); // web's Status select, as one-tap pills
      expect(server.lists().last['status'], 'available');
      expect(find.text('Dell Latitude'), findsNothing);
      await tapKey(tester, 'asset-pill-all');
      await type(tester, 'asset-search', '');
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);
      await tapKey(tester, 'asset-filters'); // category / type / branch live in the filter sheet
      await type(tester, 'asset-filter-category', 'it equipment');
      await type(tester, 'asset-filter-type', 'monitor');
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);
      expect(server.lists().last, {'category': 'it equipment', 'asset_type': 'monitor', 'page': 1, 'page_size': 20});
      await tapKey(tester, 'asset-sheet-done');
      expect(find.text('Monitor 24'), findsOneWidget);
      expect(find.text('Dell Latitude'), findsNothing);
    });

    testWidgets('branch filter (branches from the server)', (tester) async {
      await pump(tester);
      await tapKey(tester, 'asset-filters');
      await tapKey(tester, 'asset-filter-branch');
      // the menu item (not the "South Wing" chip on a card behind the sheet)
      await tester
          .tap(find.descendant(of: find.byType(DropdownMenuItem<String>), matching: find.text('South Wing')).last);
      await settle(tester);
      expect(server.lists().last['branch'], '2');
      await tapKey(tester, 'asset-sheet-done');
      expect(find.text('Spare Laptop'), findsOneWidget);
      expect(find.text('Dell Latitude'), findsNothing);
    });

    testWidgets('pagination: Prev / Next and "Page x of y"', (tester) async {
      await pump(tester, setup: (s) {
        s.assets = [for (var i = 0; i < 25; i++) asset('p$i', 'TAG-${i.toString().padLeft(2, '0')}', 'Item $i')];
      });
      expect(find.text('Page 1 of 2'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(byKey('asset-prev')).onPressed, isNull);
      await tapKey(tester, 'asset-next');
      expect(server.lists().last['page'], 2);
      expect(find.text('Page 2 of 2'), findsOneWidget);
      expect(find.text('Item 24'), findsOneWidget);
      await tapKey(tester, 'asset-prev');
      expect(server.lists().last['page'], 1);
    });

    testWidgets('empty, and failure with Retry', (tester) async {
      await pump(tester, setup: (s) => s.assets = []);
      expect(find.text('No assets found.'), findsOneWidget);
      expect(byKey('asset-page'), findsNothing);
      server.listStatus = 500;
      await tester.pumpWidget(const SizedBox());
      await pump(tester, setup: (s) => s.listStatus = 500);
      expect(byKey('asset-load-error'), findsOneWidget);
      server.listStatus = 200;
      await tapKey(tester, 'approvals-empty-action'); // Retry
      expect(find.text('Dell Latitude'), findsOneWidget);
    });

    testWidgets('view only (assets.view): no Add, no row actions', (tester) async {
      await pump(tester, as: viewer);
      expect(find.text('Dell Latitude'), findsOneWidget);
      for (final k in ['asset-add', 'asset-edit-a1', 'asset-delete-a1', 'asset-maintenance-a2', 'asset-complete-a3']) {
        expect(byKey(k), findsNothing, reason: k);
      }
    });

    testWidgets('each button follows its own permission (edit without create / delete)', (tester) async {
      await pump(tester, as: user(['settings.view', 'assets.view', 'assets.edit']));
      expect(byKey('asset-edit-a1'), findsOneWidget);
      expect(byKey('asset-maintenance-a2'), findsOneWidget);
      expect(byKey('asset-delete-a1'), findsNothing);
      expect(byKey('asset-add'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await pump(tester, as: user(['settings.view', 'assets.view', 'assets.delete']));
      expect(byKey('asset-delete-a1'), findsOneWidget);
      expect(byKey('asset-edit-a1'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await pump(tester, as: user(['settings.view', 'assets.view'], superuser: true));
      expect(byKey('asset-add'), findsOneWidget); // superuser flag, as web usePermission
    });

    testWidgets('no assets.view: the server refusal is shown, nothing listed', (tester) async {
      await pump(tester, as: user(['settings.view']));
      expect(find.text('You do not have permission to view assets.'), findsOneWidget);
      expect(byKey('asset-add'), findsNothing);
    });

    testWidgets('settings.edit alone grants no asset buttons (the server decides via is_superuser)', (tester) async {
      await pump(tester, as: user(['settings.view', 'settings.edit', 'assets.view']));
      expect(byKey('asset-add'), findsNothing);
      expect(byKey('asset-edit-a1'), findsNothing);
    });
  });

  group('add / edit', () {
    testWidgets('create: types follow the category; web payload; list reloaded', (tester) async {
      await pump(tester);
      await tapKey(tester, 'asset-add');
      expect(find.text('Add Asset'), findsWidgets);
      await type(tester, 'asset-field-asset_tag', 'LAP-100');
      await type(tester, 'asset-field-asset_name', 'ThinkPad');
      await choose(tester, 'asset-field-category', 'Furniture');
      expect(server.calls.where((c) => c.$2 == '/assets/types/').last.$4, {'category': '2'});
      await choose(tester, 'asset-field-asset_type', 'Chair');
      await choose(tester, 'asset-field-branch', 'North Wing');
      await type(tester, 'asset-field-purchase_price', '45000');
      await tapKey(tester, 'asset-field-purchase_date');
      final listsBefore = server.lists().length;
      await tapKey(tester, 'asset-save');
      final body = server.bodies('POST', '/assets/').single as Map;
      expect(body, {
        'asset_tag': 'LAP-100',
        'asset_name': 'ThinkPad',
        'category': 'Furniture',
        'category_other': '',
        'asset_type': 'Chair',
        'asset_type_other': '',
        'brand': '',
        'model': '',
        'serial_number': null,
        'purchase_date': '2026-11-13',
        'purchase_price': '45000',
        'vendor': '',
        'warranty_start_date': null,
        'warranty_end_date': null,
        'branch': '1',
        'condition': 'new',
        'description': '',
      });
      expect(find.text('Add Asset'), findsOneWidget); // the sheet closed; only the button remains
      expect(byKey('asset-save'), findsNothing);
      expect(server.lists().length, greaterThan(listsBefore));
      expect(find.text('ThinkPad'), findsOneWidget);
    });

    testWidgets('server refusal: message and the field error under the field; form kept', (tester) async {
      await pump(tester);
      await tapKey(tester, 'asset-add');
      await type(tester, 'asset-field-asset_tag', 'lap-001');
      await type(tester, 'asset-field-asset_name', 'Dup');
      await tapKey(tester, 'asset-save');
      expect(find.text('Asset Tag "lap-001" already exists.'), findsNWidgets(2)); // banner + field
      expect(byKey('asset-save-error'), findsOneWidget);
      await type(tester, 'asset-field-asset_tag', 'LAP-777');
      expect(find.text('Asset Tag "lap-001" already exists.'), findsOneWidget); // field error cleared on edit
    });

    testWidgets('"Other" category needs its own name field; category change clears the type', (tester) async {
      await pump(tester);
      await tapKey(tester, 'asset-add');
      await choose(tester, 'asset-field-category', 'IT Equipment');
      await choose(tester, 'asset-field-asset_type', 'Monitor');
      await choose(tester, 'asset-field-category', 'Other');
      expect(byKey('asset-field-category_other'), findsOneWidget);
      await type(tester, 'asset-field-category_other', 'Mobiles');
      await type(tester, 'asset-field-asset_tag', 'PHN-9');
      await type(tester, 'asset-field-asset_name', 'Phone');
      server.refuseNext = (
        status: 400,
        message: 'Asset Type is required.',
        data: {
          'asset_type': ['Asset Type is required.']
        }
      );
      await tapKey(tester, 'asset-save');
      final body = server.bodies('POST', '/assets/').single as Map;
      expect(body['category'], 'Other');
      expect(body['category_other'], 'Mobiles');
      expect(body['asset_type'], ''); // cleared by the category change
    });

    testWidgets('quick-add category: required name; POST; then selected', (tester) async {
      await pump(tester);
      await tapKey(tester, 'asset-add');
      await tapKey(tester, 'asset-add-category');
      await tapKey(tester, 'asset-quick-add-submit');
      expect(find.text('Category name is required.'), findsOneWidget);
      await type(tester, 'asset-quick-add-name', 'Vehicles');
      await tapKey(tester, 'asset-quick-add-submit');
      expect(server.bodies('POST', '/assets/categories/').single, {'name': 'Vehicles'});
      expect(find.descendant(of: byKey('asset-field-category'), matching: find.text('Vehicles')), findsOneWidget);
    });

    testWidgets('edit: prefilled, current holder from a fresh read, PUT to the asset', (tester) async {
      await pump(tester);
      await tapKey(tester, 'asset-edit-a1');
      expect(find.text('Edit: LAP-001'), findsOneWidget);
      expect(find.text('Asha Test'), findsOneWidget);
      expect(find.text('EMP-2'), findsOneWidget);
      expect(find.text('Not set'), findsOneWidget); // expected return
      expect(server.calls.where((c) => c.$1 == 'GET' && c.$2 == '/assets/a1/'), hasLength(1));
      await type(tester, 'asset-field-asset_name', 'Dell Latitude 5420');
      await tapKey(tester, 'asset-save');
      final body = server.bodies('PUT', '/assets/a1/').single as Map;
      expect(body['asset_name'], 'Dell Latitude 5420');
      expect(body['asset_tag'], 'LAP-001');
      expect(body['branch'], '1');
      expect(body['serial_number'], 'SN-LAP-001');
      expect(find.text('Dell Latitude 5420'), findsOneWidget);
    });

    testWidgets('edit: a failed holder refresh shows the row\'s data with a note; hidden employee', (tester) async {
      await pump(tester, setup: (s) {
        s.detailStatus = 500;
        s.assets.first['active_assignment'] = {
          'status_display': 'Assigned',
          'assigned_date': '2026-11-01',
          'employee_hidden': true,
          'employee_name': null,
          'employee_code': null,
        };
      });
      await tapKey(tester, 'asset-edit-a1');
      expect(byKey('asset-holder-stale'), findsOneWidget);
      expect(find.text('Not visible to you'), findsOneWidget);
    });
  });

  group('delete and maintenance', () {
    testWidgets('delete: confirm; an assigned asset is refused with the server message; else removed', (tester) async {
      await pump(tester);
      await tapKey(tester, 'asset-delete-a1');
      expect(find.textContaining('LAP-001 — Dell Latitude'), findsOneWidget);
      await tapKey(tester, 'asset-delete-confirm');
      expect(find.text('Cannot delete "LAP-001" — it is currently assigned to an employee. Return it first.'),
          findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      await tapKey(tester, 'asset-delete-a4');
      await tapKey(tester, 'asset-delete-confirm');
      expect(server.calls.where((c) => c.$1 == 'DELETE').map((c) => c.$2), ['/assets/a1/', '/assets/a4/']);
      expect(find.text('Spare Laptop'), findsNothing);
    });

    testWidgets('send to maintenance: issue required; web payload', (tester) async {
      await pump(tester);
      await tapKey(tester, 'asset-maintenance-a2');
      await tapKey(tester, 'maint-submit');
      expect(find.text('Issue / Reason is required.'), findsOneWidget);
      await type(tester, 'maint-issue', 'Cracked screen');
      await type(tester, 'maint-vendor', 'FixIt');
      await tapKey(tester, 'maint-submit');
      final body = server.bodies('POST', '/assets/a2/send-to-maintenance/').single as Map;
      expect(body['issue'], 'Cracked screen');
      expect(body['vendor'], 'FixIt');
      expect(body['expected_completion_date'], isNull);
      expect(body['estimated_cost'], isNull);
      expect(body['notes'], '');
      expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch('${body['maintenance_start_date']}'), isTrue);
      expect(statusOf(tester, 'a2'), 'Under Repair');
    });

    testWidgets('complete maintenance: notes required; not repairable sends no resulting condition', (tester) async {
      await pump(tester);
      await tapKey(tester, 'asset-complete-a3');
      expect(find.textContaining('Flickering screen', findRichText: true), findsOneWidget);
      await tapKey(tester, 'maint-submit');
      expect(find.text('Repair/Maintenance notes are required.'), findsOneWidget);
      await choose(tester, 'complete-outcome', 'Not Repairable');
      expect(byKey('complete-condition'), findsNothing);
      await type(tester, 'complete-notes', 'Panel dead');
      await tapKey(tester, 'maint-submit');
      final body = server.bodies('POST', '/assets/maintenance/m1/complete/').single as Map;
      expect(body.containsKey('resulting_condition'), isFalse);
      expect(body['outcome'], 'not_repairable');
      expect(body['maintenance_notes'], 'Panel dead');
      expect(body['actual_cost'], isNull);
    });

    testWidgets('complete maintenance (repaired): resulting condition sent, Damaged not offered', (tester) async {
      await pump(tester);
      await tapKey(tester, 'asset-complete-a3');
      await tester.tap(byKey('complete-condition'));
      await settle(tester);
      // "Damaged" is not an option for the resulting condition (it is a status elsewhere on the page)
      expect(find.descendant(of: find.byType(DropdownMenuItem<String>), matching: find.text('Damaged')), findsNothing);
      await tester.tap(find.text('Fair').last);
      await settle(tester);
      await type(tester, 'complete-notes', 'Replaced cable');
      await tapKey(tester, 'maint-submit');
      final body = server.bodies('POST', '/assets/maintenance/m1/complete/').single as Map;
      expect(body['outcome'], 'repaired');
      expect(body['resulting_condition'], 'fair');
    });
  });

  group('integration', () {
    testWidgets('Settings hub: Assets shown with the module, hidden without', (tester) async {
      await pump(tester, as: user(['settings.view'], modules: const ['assets']), child: const SettingsScreen());
      expect(find.text('Assets'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await pump(tester, as: user(['settings.view'], modules: const ['leave']), child: const SettingsScreen());
      expect(find.text('Assets'), findsNothing);
      expect(server.lists(), isEmpty); // no asset data requested
    });

    test('a new asset is offered by the employee Assign picker (it reads the list each time)', () async {
      server = Backend({...allAssetPerms});
      final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server;
      final picker = EmployeeAssetsDataSource(dio);
      final before = await picker.fetchAvailable();
      expect(before.map((a) => a.assetTag), isNot(contains('NEW-1')));
      await AssetCatalogueApi(dio).create(assetPayload(blankAssetForm()
        ..['asset_tag'] = 'NEW-1'
        ..['asset_name'] = 'Fresh Laptop'
        ..['branch'] = '1'));
      final after = await picker.fetchAvailable();
      expect(after.map((a) => a.label), contains('NEW-1 — Fresh Laptop'));
    });
  });
}
