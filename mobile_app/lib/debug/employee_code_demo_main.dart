// DEBUG-ONLY demo of Settings → Employee ID Format (Task 48) on the real
// screen, without signing in or calling a server:
//
//   flutter run -d <emulator> -t lib/debug/employee_code_demo_main.dart
//
// GET/PUT /settings/employee-code/ are answered in-process by [_DemoServer]
// in the production shapes (EmployeeCodeSettingsView / Serializer). Values
// are fictitious; nothing leaves the device. Each request is logged on screen
// and as "FAKE_SERVER ..." lines. Chips pick the stored data, make the next
// GET fail, pick the PUT answer, and switch between a user with and without
// settings.edit. Not imported by lib/main.dart, so not part of the release
// app; refuses to run outside debug builds.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/network/api_client.dart';
import '../features/auth/domain/entities/user_entity.dart';
import '../features/auth/presentation/controllers/auth_notifier.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/auth/presentation/states/auth_state.dart';
import '../features/settings/presentation/employee_code/employee_code_screen.dart';

enum Stored { normal, legacy, missing }

enum PutMode { ok, prefixError, hiddenErrors }

bool _canEdit = true;

class _DemoAuth extends AuthNotifier {
  @override
  Future<AuthState> build() async => AuthState(
        user: UserEntity(
          id: 'demo',
          email: 'demo@example.test',
          fullName: 'Demo Admin',
          role: 'demo',
          roleDisplay: 'Demo',
          mustChangePassword: false,
          permissions: ['settings.view', if (_canEdit) 'settings.edit'],
          onboardingStatus: 'complete',
          assessmentStatus: 'complete',
        ),
      );
}

final _log = ValueNotifier<List<String>>([]);
void _record(String line) {
  debugPrint('FAKE_SERVER $line');
  _log.value = [..._log.value, line];
}

class _DemoServer implements HttpClientAdapter {
  Stored stored = Stored.normal;
  Map<String, dynamic> data = _initial(Stored.normal);
  bool failNextGet = false;
  PutMode put = PutMode.ok;

  static Map<String, dynamic> _initial(Stored s) => switch (s) {
        Stored.normal => {
            'prefix': 'RSS',
            'padding': 5,
            'next_sequence': 1,
            'format_description': 'RSS00001  (prefix + 5-digit sequence, next = 1)',
          },
        Stored.legacy => {'prefix': 'R-S', 'padding': 5, 'next_sequence': 1},
        Stored.missing => {'prefix': 'OLD'},
      };

  void reset(Stored s) {
    stored = s;
    data = _initial(s);
  }

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (o.path == '/settings/employee-code/' && o.method == 'GET') {
      if (failNextGet) {
        failNextGet = false;
        _record('GET /settings/employee-code/ → 500');
        return _json(500, {'status': 'error', 'message': 'Server error. Please try again later.', 'data': {}});
      }
      _record('GET /settings/employee-code/ → 200 ${jsonEncode(data)}');
      return _json(200, {'status': 'success', 'message': 'Employee code settings retrieved.', 'data': data});
    }
    if (o.path == '/settings/employee-code/' && o.method == 'PUT') {
      final body = Map<String, dynamic>.from(o.data as Map);
      switch (put) {
        case PutMode.prefixError:
          _record('PUT /settings/employee-code/ ${jsonEncode(body)} → 400 prefix');
          return _json(400, {
            'status': 'error',
            'message': 'Please fix the errors below.',
            'data': {
              'prefix': ['Ensure this field has no more than 10 characters.']
            }
          });
        case PutMode.hiddenErrors:
          _record('PUT /settings/employee-code/ ${jsonEncode(body)} → 400 padding/next_sequence');
          return _json(400, {
            'status': 'error',
            'message': 'Please fix the errors below.',
            'data': {
              'padding': ['Padding must be between 3 and 8.'],
              'next_sequence': ['Starting number must be at least 1.'],
            }
          });
        case PutMode.ok:
          data = {...data, ...body, 'prefix': '${body['prefix']}'.toUpperCase()};
          _record('PUT /settings/employee-code/ ${jsonEncode(body)} → 200 ${jsonEncode(data)}');
          return _json(200, {'status': 'success', 'message': 'Employee code settings updated.', 'data': data});
      }
    }
    return _json(404, {'status': 'error', 'message': 'Not found', 'data': {}});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode) {
    runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('Debug builds only.')))));
    return;
  }
  final server = _DemoServer();
  runApp(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(_DemoAuth.new),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://demo.invalid/api'))..httpClientAdapter = server),
    ],
    child: _DemoApp(server: server),
  ));
}

class _DemoApp extends ConsumerStatefulWidget {
  const _DemoApp({required this.server});
  final _DemoServer server;
  @override
  ConsumerState<_DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends ConsumerState<_DemoApp> {
  late final _router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Settings (demo)')),
        body: Center(
          child: FilledButton(
            key: const Key('open-employee-code'),
            onPressed: () => context.push('/code'),
            child: const Text('Open Employee ID Format'),
          ),
        ),
      ),
    ),
    GoRoute(path: '/code', builder: (_, __) => const EmployeeCodeScreen()),
  ]);

  @override
  Widget build(BuildContext context) {
    final s = widget.server;
    Widget chip(String label, bool on, VoidCallback f) => ChoiceChip(
          label: Text(label, style: const TextStyle(fontSize: 10.5)),
          selected: on,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onSelected: (_) => setState(f),
        );
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      builder: (context, child) => Column(children: [
        Material(
          child: SafeArea(
            bottom: false,
            child: Wrap(spacing: 4, runSpacing: 0, children: [
              chip('Data RSS', s.stored == Stored.normal, () => s.reset(Stored.normal)),
              chip('Data R-S', s.stored == Stored.legacy, () => s.reset(Stored.legacy)),
              chip('Data no pad/seq', s.stored == Stored.missing, () => s.reset(Stored.missing)),
              chip('Fail next GET', s.failNextGet, () => s.failNextGet = !s.failNextGet),
              chip('PUT ok', s.put == PutMode.ok, () => s.put = PutMode.ok),
              chip('PUT prefix err', s.put == PutMode.prefixError, () => s.put = PutMode.prefixError),
              chip('PUT hidden errs', s.put == PutMode.hiddenErrors, () => s.put = PutMode.hiddenErrors),
              chip(_canEdit ? 'User: settings.edit' : 'User: no settings.edit', _canEdit, () {
                _canEdit = !_canEdit;
                // Reload the signed-in user now (as a fresh sign-in would),
                // not lazily on the next screen's first read.
                ref.invalidate(authStateProvider);
                ref.read(authStateProvider.future);
              }),
            ]),
          ),
        ),
        Expanded(child: child!),
        Material(
          color: const Color(0xFF102A43),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(6),
            child: ValueListenableBuilder<List<String>>(
              valueListenable: _log,
              builder: (_, lines, __) => Text(
                lines.isEmpty ? 'Fake server log: (nothing yet)' : lines.reversed.take(2).join('\n'),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace'),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
