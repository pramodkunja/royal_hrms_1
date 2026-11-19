import 'dart:async';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';

// Shared harness for the Task 101 secondary-tab tests (attendance approval,
// face registration, leave cancellations, delegations): a stand-in HTTP server
// behind a fake Dio adapter (nothing ever leaves the test), plus a pump helper
// with a configurable viewport and text scale. Synthetic people only.

ResponseBody jsonBody(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

ResponseBody ok(Object? data, [String message = 'ok']) =>
    jsonBody(200, {'status': 'success', 'message': message, 'data': data});

ResponseBody refuse(int status, [String? message]) =>
    jsonBody(status, {'status': 'error', if (message != null) 'message': message, 'data': {}});

typedef Handler = FutureOr<ResponseBody> Function(RequestOptions o);

class FakeServer implements HttpClientAdapter {
  /// "GET /path/" -> handler. Unknown routes answer 404.
  final routes = <String, Handler>{};
  final calls = <RequestOptions>[];

  /// Routes listed here wait for [release] before answering.
  final holdKeys = <String>{};
  final Completer<void> _gate = Completer<void>();

  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }

  void on(String key, Handler h) => routes[key] = h;

  int count(String key) => calls.where((c) => '${c.method} ${c.path}' == key).length;

  List<Object?> bodies(String key) => [
        for (final c in calls)
          if ('${c.method} ${c.path}' == key) c.data
      ];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? body, Future<void>? cancel) async {
    calls.add(o);
    final key = '${o.method} ${o.path}';
    if (holdKeys.contains(key)) await _gate.future;
    final h = routes[key];
    if (h == null) return refuse(404, 'No route $key');
    return h(o);
  }

  @override
  void close({bool force = false}) {}
}

class NullStorage extends SecureStorageService {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

Finder byKey(String k) => find.byKey(Key(k));

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> pumpTab(
  WidgetTester tester,
  Widget child,
  FakeServer server, {
  Size size = const Size(420, 1800),
  double textScale = 1.0,
  List<Override> overrides = const [],
  bool settleAfter = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(NullStorage()),
      ...overrides,
    ],
    child: MaterialApp(
      builder: (context, c) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)), child: c!),
      home: Scaffold(body: child),
    ),
  ));
  if (settleAfter) await settle(tester);
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(byKey(key));
  await tester.pump();
  await tester.tap(byKey(key));
  await settle(tester);
}

/// The three viewports every tab must survive.
const responsiveCases = <(String, Size, double)>[
  ('320x568', Size(320, 568), 1.0),
  ('320x568 at 2.0x text', Size(320, 568), 2.0),
  ('tablet 1000x800', Size(1000, 800), 1.0),
];
