// DEBUG-ONLY demo of Settings → SMTP (Task 47 provider picker) on the real
// screen, without signing in or calling a server:
//
//   flutter run -d <emulator> -t lib/debug/smtp_provider_demo_main.dart
//
// Every request is answered in-process by [_DemoServer] in the production
// response shapes (SMTPSettingsSerializer). No SMTP connection is ever made and
// no email is sent. Each write is logged on screen and as "FAKE_SERVER ..."
// lines with the password REDACTED (only its presence and length are shown).
// Chips make the next saves succeed, refuse a duplicate name (400), or refuse
// permission (403). Not imported by lib/main.dart, so not part of the release
// app; refuses to run outside debug builds.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/network/api_client.dart';
import '../features/settings/presentation/smtp/smtp_screen.dart';

enum SaveMode { ok, duplicate, forbidden }

Map<String, dynamic> _row(int id, String name, String provider, String type, String host, {bool active = false}) => {
      'id': id,
      'name': name,
      'smtp_type': type,
      'smtp_type_display': type == 'local' ? 'Gmail / Custom SMTP' : 'Dedicated Mail Server',
      'provider': provider,
      'provider_display': provider,
      'host': host,
      'port': type == 'local' ? 587 : 25,
      'username': type == 'local' ? 'mailer$id@example.test' : 'noreply$id@example.test',
      'password_display': '••••••••',
      'use_tls': type == 'local',
      'sender_name': 'Demo HR',
      'from_email': 'noreply$id@example.test',
      'bcc_email': '',
      'priority': 'normal',
      'receiver_email_type': 'email_id',
      'is_active': active,
      'updated_at': '2026-11-01T10:00:00Z',
    };

final _log = ValueNotifier<List<String>>([]);
void _record(String line) {
  debugPrint('FAKE_SERVER $line');
  _log.value = [..._log.value, line];
}

/// The body as logged: the password replaced by its length only.
String _redacted(Map<String, dynamic> body) {
  final b = Map<String, dynamic>.from(body);
  if (b.containsKey('password')) b['password'] = '«redacted ${(b['password'] as String).length} chars»';
  return jsonEncode(b);
}

class _DemoServer implements HttpClientAdapter {
  SaveMode mode = SaveMode.ok;
  int _nextId = 10;
  final rows = [
    _row(1, 'Zoho Mail (India)', 'zoho_mail', 'local', 'smtp.zoho.in', active: true),
    _row(2, 'Legacy Relay', 'sendgrid', 'local', 'smtp.sendgrid.net'), // unknown to the app
    _row(3, 'Office Mail Server', 'dedicated_server', 'server', 'mail.internal.test'),
  ];

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (o.method == 'GET' && o.path == '/settings/smtp/') {
      return _json(200, {
        'status': 'success',
        'data': {'count': rows.length, 'results': rows}
      });
    }
    if (o.method == 'POST' || o.method == 'PUT') {
      final body = Map<String, dynamic>.from(o.data as Map);
      if (mode == SaveMode.duplicate) {
        _record('${o.method} ${o.path} ${_redacted(body)} → 400 duplicate name');
        return _json(
            400, {'status': 'error', 'message': 'An SMTP config named "${body['name']}" already exists.', 'data': {}});
      }
      if (mode == SaveMode.forbidden) {
        _record('${o.method} ${o.path} ${_redacted(body)} → 403');
        return _json(403, {'status': 'error', 'message': 'You do not have permission to manage settings.', 'data': {}});
      }
      _record('${o.method} ${o.path} ${_redacted(body)} → ${o.method == 'POST' ? 201 : 200}');
      body.remove('password');
      if (o.method == 'POST') {
        final created = {..._row(_nextId++, '', '', 'local', ''), ...body};
        rows.add(created);
        return _json(201, {'status': 'success', 'data': created});
      }
      final id = int.parse(o.path.split('/')[3]);
      final i = rows.indexWhere((r) => r['id'] == id);
      rows[i] = {...rows[i], ...body};
      return _json(200, {'status': 'success', 'data': rows[i]});
    }
    return _json(200, {'status': 'success', 'data': <String, dynamic>{}});
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
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://demo.invalid/api'))..httpClientAdapter = server),
    ],
    child: _DemoApp(server: server),
  ));
}

class _DemoApp extends StatefulWidget {
  const _DemoApp({required this.server});
  final _DemoServer server;
  @override
  State<_DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<_DemoApp> {
  late final _router = GoRouter(routes: [GoRoute(path: '/', builder: (_, __) => const SmtpScreen())]);

  @override
  Widget build(BuildContext context) {
    final s = widget.server;
    Widget chip(String label, SaveMode m) => ChoiceChip(
          label: Text(label, style: const TextStyle(fontSize: 11)),
          selected: s.mode == m,
          visualDensity: VisualDensity.compact,
          onSelected: (_) => setState(() => s.mode = m),
        );
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      builder: (context, child) => Column(children: [
        Material(
          child: SafeArea(
            bottom: false,
            child: Wrap(spacing: 6, children: [
              chip('Save OK', SaveMode.ok),
              chip('Duplicate', SaveMode.duplicate),
              chip('403', SaveMode.forbidden),
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
                lines.isEmpty ? 'Fake server log: (no writes yet)' : lines.last,
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
