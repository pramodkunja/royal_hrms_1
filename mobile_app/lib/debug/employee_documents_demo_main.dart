// DEBUG-ONLY demo of HR Employee Profile → Documents → View (Task 54) on the
// real screen, without signing in or calling a server:
//
//   flutter run -d <emulator> -t lib/debug/employee_documents_demo_main.dart
//
// GET /employees/<code>/ is answered in-process by [_DemoApi] in the
// production shape (documents[].file = a signed file-host link, re-signed on
// every load). The "file host" is [_DemoFileHost], also in-process: it serves
// a synthetic PNG ("Aadhaar") and a synthetic PDF ("PAN"), both generated
// here. Nothing leaves the device. Chips make the file host refuse the first
// signature (expired link), go offline, or lose the PAN file. Not imported by
// lib/main.dart, so not part of the release app; refuses to run outside debug
// builds.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/widgets.dart' as pw;

import '../core/network/api_client.dart';
import '../features/auth/domain/entities/user_entity.dart';
import '../features/auth/presentation/controllers/auth_notifier.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/auth/presentation/states/auth_state.dart';
import '../features/employees/presentation/providers/employee_providers.dart';
import '../features/employees/presentation/screens/employee_profile_screen.dart';

const _code = 'DEMO-54';
const _host = 'files.demo.invalid';

class _DemoAuth extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState(
        user: UserEntity(
          id: 'demo',
          email: 'demo@example.test',
          fullName: 'Demo HR',
          role: 'hr',
          roleDisplay: 'HR',
          mustChangePassword: false,
          permissions: ['employees.view', 'employees.edit'],
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

ResponseBody _bytes(int status, List<int> body, String ct) => ResponseBody.fromBytes(body, status, headers: {
      Headers.contentTypeHeader: [ct]
    });

class _DemoApi implements HttpClientAdapter {
  int sig = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (o.uri.path.endsWith('/employees/$_code/') && o.method == 'GET') {
      sig++;
      _record('GET employee detail (links signed s$sig)');
      String link(String id) => 'https://$_host/raw/download?public_id=$id&signature=s$sig';
      Map<String, dynamic> d(int id, String type, String label, String name, String file) => {
            'id': id,
            'document_type': type,
            'document_type_display': label,
            'file': file,
            'file_name': name,
            'file_size': 2048,
            'uploaded_at': '2026-03-01T10:00:00Z',
          };
      return _bytes(
          200,
          utf8.encode(jsonEncode({
            'status': 'success',
            'data': {
              'id': 'u54',
              'uuid': 'uuid-54',
              'employee_id': _code,
              'first_name': 'Demo',
              'last_name': 'Employee',
              'full_name': 'Demo Employee',
              'email': 'demo.employee@example.test',
              'department': 'QA',
              'designation': 'Analyst',
              'branch': 'North Wing',
              'role': 'employee',
              'is_active': true,
              'status': 'active',
              'onboarding_status': 'complete',
              'documents': [
                d(1, 'aadhaar_card', 'Aadhaar Card', 'aadhaar.png', link('aadhaar')),
                d(2, 'pan_card', 'PAN Card', 'pan.pdf', link('pan')),
              ],
              'profile': {'custom_field_values': <String, dynamic>{}},
            },
          })),
          Headers.jsonContentType);
    }
    return _bytes(200, utf8.encode(jsonEncode({'status': 'success', 'data': <Object>[]})), Headers.jsonContentType);
  }

  @override
  void close({bool force = false}) {}
}

class _DemoFileHost implements HttpClientAdapter {
  _DemoFileHost(this.png, this.pdf);
  final Uint8List png;
  final Uint8List pdf;
  bool expireFirstSignature = false;
  bool offline = false;
  bool panMissing = false;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final id = o.uri.queryParameters['public_id'];
    final s = o.uri.queryParameters['signature'];
    final auth = o.headers.keys.any((k) => k.toLowerCase() == 'authorization' || k.toLowerCase() == 'cookie');
    if (offline) {
      _record('FILE $id ($s) → offline');
      throw DioException.connectionError(requestOptions: o, reason: 'offline');
    }
    if (expireFirstSignature && s == 's1') {
      _record('FILE $id ($s) → 401 expired · login sent: $auth');
      return _bytes(401, utf8.encode('{"error":"expired"}'), 'application/json');
    }
    if (id == 'pan' && panMissing) {
      _record('FILE $id ($s) → 404 · login sent: $auth');
      return _bytes(404, utf8.encode('not found'), 'text/plain');
    }
    _record('FILE $id ($s) → 200 · login sent: $auth');
    return id == 'aadhaar' ? _bytes(200, png, 'image/png') : _bytes(200, pdf, 'application/octet-stream');
  }

  @override
  void close({bool force = false}) {}
}

Uint8List _syntheticPng() {
  final im = img.Image(width: 480, height: 300);
  img.fill(im, color: img.ColorRgb8(232, 240, 254));
  img.fillRect(im, x1: 0, y1: 0, x2: 479, y2: 50, color: img.ColorRgb8(30, 80, 160));
  img.drawString(im, 'SYNTHETIC AADHAAR - TEST ONLY', font: img.arial24, x: 20, y: 12, color: img.ColorRgb8(255, 255, 255));
  img.drawString(im, 'Name: Demo Employee', font: img.arial24, x: 20, y: 110, color: img.ColorRgb8(20, 20, 20));
  img.drawString(im, 'No: XXXX XXXX 0000', font: img.arial24, x: 20, y: 160, color: img.ColorRgb8(20, 20, 20));
  return Uint8List.fromList(img.encodePng(im));
}

Future<Uint8List> _syntheticPdf() async {
  final doc = pw.Document();
  doc.addPage(pw.Page(
    build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text('SYNTHETIC PAN CARD - TEST ONLY', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 16),
      pw.Text('Name: Demo Employee'),
      pw.Text('PAN: XXXXX0000X'),
    ]),
  ));
  return doc.save();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode) {
    runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('Debug builds only.')))));
    return;
  }
  final files = _DemoFileHost(_syntheticPng(), await _syntheticPdf());
  runApp(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(_DemoAuth.new),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://demo.invalid/api'))
        ..httpClientAdapter = _DemoApi()
        ..interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
          o.headers['Authorization'] = 'Bearer demo-token';
          h.next(o);
        }))),
      employeeDocumentExternalDioProvider.overrideWithValue(Dio()..httpClientAdapter = files),
    ],
    child: _DemoApp(files: files),
  ));
}

class _DemoApp extends StatefulWidget {
  const _DemoApp({required this.files});
  final _DemoFileHost files;
  @override
  State<_DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<_DemoApp> {
  @override
  Widget build(BuildContext context) {
    final f = widget.files;
    Widget chip(String label, bool on, VoidCallback t) => ChoiceChip(
          label: Text(label, style: const TextStyle(fontSize: 10.5)),
          selected: on,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onSelected: (_) => setState(t),
        );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) => Column(children: [
        Material(
          child: SafeArea(
            bottom: false,
            child: Wrap(spacing: 4, children: [
              chip('Expire s1 links', f.expireFirstSignature, () => f.expireFirstSignature = !f.expireFirstSignature),
              chip('File host offline', f.offline, () => f.offline = !f.offline),
              chip('PAN file missing', f.panMissing, () => f.panMissing = !f.panMissing),
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
                lines.isEmpty ? 'Fake server log: (nothing yet)' : lines.reversed.take(3).join('\n'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace'),
              ),
            ),
          ),
        ),
      ]),
      home: const EmployeeProfileScreen(employeeId: _code),
    );
  }
}
