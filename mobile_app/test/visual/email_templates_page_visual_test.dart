import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_theme.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/settings/presentation/email_templates/email_templates_screen.dart';

import 'shot_harness.dart';

// Task 105 — render evidence for the Email Templates PAGE, through the app's
// own route (a top-level Settings route, so under the real blue AppTopBar once
// redesigned). Runs only with T1011_SHOTS=1 (T1011_OUT, T1011_PREFIX:
// `before_t105_` for the old page, `t105_` for the redesign). Real widgets,
// real Poppins.

/// A stand-in API: grouped templates, company, birthday settings, categories.
class EtBackend implements HttpClientAdapter {
  EtBackend({List<Map<String, dynamic>>? templates}) : templates = templates ?? richTemplates();
  List<Map<String, dynamic>> templates;
  int listStatus = 200;
  int companyStatus = 200;
  String listMessage = 'Server error. Please try again later.';
  final calls = <String>[];
  final bodies = <String, Object?>{};

  ResponseBody _json(Object b, [int status = 200]) => ResponseBody.fromString(jsonEncode(b), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add('${o.method} ${o.path}');
    if (o.method != 'GET') {
      bodies['${o.method} ${o.path}'] = o.data;
    }
    final p = o.path;
    if (p == '/settings/email-templates/' && o.method == 'GET') {
      if (listStatus != 200) return _json({'status': 'error', 'message': listMessage, 'data': {}}, listStatus);
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final t in templates) {
        grouped.putIfAbsent(t['template_type'] as String, () => []).add(t);
      }
      return _json({
        'status': 'success',
        'message': 'ok',
        'data': {'count': templates.length, 'page': 1, 'page_size': 100, 'total_pages': 1, 'results': grouped},
      });
    }
    if (p == '/settings/email-template-categories/') {
      return _json({
        'status': 'success',
        'data': [
          for (final t in ['document', 'notification', 'reminder', 'wish'])
            {'id': t.length, 'name': t, 'display_name': '${t[0].toUpperCase()}${t.substring(1)} Templates'},
        ],
      });
    }
    if (p == '/settings/company/') {
      if (companyStatus != 200) {
        return _json({'status': 'error', 'message': 'Server error.', 'data': {}}, companyStatus);
      }
      return _json({
        'status': 'success',
        'data': {
          'id': 1,
          'company_name': 'Sria Infotech Pvt Ltd',
          'logo_url': null,
          'website': 'www.sriainfotech.example',
          'address': 'Plot 12, Tech Park',
          'city': 'Surat',
          'state': 'Gujarat',
          'official_phone': '+91 261 000 0000',
        },
      });
    }
    if (p == '/birthdays/settings/') {
      return _json({
        'status': 'success',
        'data': {
          'is_enabled': true,
          'banner_message_template': 'Wishing you a wonderful year ahead!',
          'employee_notification_template': 'Happy Birthday!',
          'team_notification_template': "It's {employee_name}'s birthday.",
          'manager_notification_template': "It's {employee_name}'s birthday.",
        },
      });
    }
    // Updating a template answers with the template, as the real API does.
    final one = RegExp(r'^/settings/email-templates/(\d+)/$').firstMatch(p);
    if (one != null && (o.method == 'PATCH' || o.method == 'PUT')) {
      final id = int.parse(one.group(1)!);
      final current = templates.firstWhere((t) => t['id'] == id, orElse: () => {'id': id});
      final merged = {...current, if (o.data is Map) ...(o.data as Map).cast<String, dynamic>()};
      return _json({'status': 'success', 'message': 'Email template updated', 'data': merged});
    }
    return _json({'status': 'success', 'data': <String, dynamic>{}});
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> tpl(int id, String type, String name,
        {String? description,
        String subject = 'A subject line',
        bool active = true,
        bool builtin = true,
        String body = '<p>Hello {FNAME},</p><p>This is the body.</p>',
        List<String> vars = const []}) =>
    {
      'id': id,
      'name': 'tpl_$id',
      'display_name': name,
      'description': description ?? 'When $name is sent to an employee.',
      'subject': subject,
      'body': body,
      'template_type': type,
      'template_type_display': '${type[0].toUpperCase()}${type.substring(1)}',
      'is_active': active,
      'is_builtin': builtin,
      'available_variables': vars,
      'attachments': <Object>[],
    };

List<Map<String, dynamic>> richTemplates() => [
      tpl(1, 'document', 'Pay Slip', subject: 'Your pay slip for {MONTH} {YEAR}', vars: ['FNAME', 'MONTH', 'YEAR']),
      tpl(2, 'document', 'Offer Letter', subject: 'Offer of employment — {POSITION}', vars: ['FNAME', 'POSITION']),
      tpl(3, 'document', 'Experience Certificate', active: false),
      tpl(4, 'notification', 'Leave Approved', subject: 'Your leave request has been approved'),
      tpl(5, 'notification', 'Welcome Email', subject: 'Welcome to {COMPANY}, {FNAME}!', builtin: false),
      tpl(6, 'reminder', 'Document Submission Reminder',
          subject: 'Reminder: please submit your pending onboarding documents before the deadline of {DEADLINE_DATE}',
          description:
              'Sent every morning to candidates who still have mandatory onboarding documents outstanding after their joining date.'),
      tpl(7, 'wish', 'Birthday Wish', subject: 'Happy Birthday, {FNAME}! 🎂', builtin: false),
      tpl(8, 'wish', 'Work Anniversary', subject: 'Congratulations on {YEARS} years with us'),
    ];

class _Storage extends SecureStorageService {
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

UserEntity etUser([List<String> perms = const ['settings.view', 'settings.edit', 'employees.view']]) => UserEntity(
      id: 'u1',
      email: 'admin@example.test',
      fullName: 'Admin',
      role: 'admin',
      roleDisplay: 'Admin',
      mustChangePassword: false,
      permissions: perms,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 80));
  }
}

Future<void> _open(WidgetTester t,
    {Size size = const Size(393, 3000),
    double scale = 1,
    EtBackend? backend,
    bool dark = false,
    double keyboard = 0}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  if (keyboard > 0) t.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(t.view.reset);
  // Dark mode is the app's static colour switch (ThemeModeNotifier → AppColors.applyMode).
  AppColors.applyMode(dark);
  addTearDown(() => AppColors.applyMode(false));
  await t.runAsync(loadShotFonts);
  final b = backend ?? EtBackend();
  await t.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith(() => _Auth(etUser())),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = b),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_Storage()),
    ],
    child: shotFrame(MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(dark),
      builder: (c, child) =>
          MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
      routerConfig: GoRouter(initialLocation: '/s', routes: [
        GoRoute(path: '/s', builder: (_, __) => const EmailTemplatesScreen()),
      ]),
    )),
  ));
  await _settle(t);
}

void shot(String name, Future<void> Function(WidgetTester t) body) {
  testWidgets('shot $name', (t) async {
    await body(t);
    await shoot(t, name);
  }, skip: !shotsEnabled);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  shot('01_page_populated', (t) => _open(t, size: const Size(393, 4200)));
  shot('02_page_top_viewport', (t) => _open(t, size: const Size(393, 852)));
  shot('03_search_match', (t) async {
    await _open(t, size: const Size(393, 1800));
    await t.enterText(find.byType(TextField).first, 'remind');
    await _settle(t);
  });
  shot('04_search_no_match', (t) async {
    await _open(t, size: const Size(393, 1200));
    await t.enterText(find.byType(TextField).first, 'zzzzzz');
    await _settle(t);
  });
  shot('05_empty', (t) => _open(t, size: const Size(393, 1200), backend: EtBackend(templates: [])));
  shot('06_error', (t) => _open(t, size: const Size(393, 1200), backend: EtBackend()..listStatus = 500));
  shot('07_denied', (t) async {
    final b = EtBackend()
      ..listStatus = 403
      ..listMessage = 'You do not have permission to perform this action.';
    await _open(t, size: const Size(393, 1200), backend: b);
  });
  shot('08_320dp_2x', (t) => _open(t, size: const Size(320, 7000), scale: 2));
  shot('09_tablet_1000', (t) => _open(t, size: const Size(1000, 2400)));
  shot('09b_foldable_700', (t) => _open(t, size: const Size(700, 3000)));
  shot('10_dark', (t) => _open(t, size: const Size(393, 3200), dark: true));
}
