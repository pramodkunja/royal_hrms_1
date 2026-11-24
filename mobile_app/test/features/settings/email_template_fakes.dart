// Shared stand-in server + app wiring for the Task 105 email template editor /
// preview tests and evidence renders. Synthetic data only; nothing real is sent.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/core/theme/app_theme.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/settings/data/datasources/settings_remote_datasource.dart';
import 'package:mobile_app/features/settings/data/models/email_template_model.dart';
import 'package:mobile_app/features/settings/presentation/providers/settings_providers.dart';

const etAdmin = UserEntity(
  id: 'a1',
  email: 'admin@example.test',
  fullName: 'Test Admin',
  role: 'system_admin',
  roleDisplay: 'Admin',
  mustChangePassword: false,
  permissions: ['settings.view', 'settings.edit'],
  onboardingStatus: 'complete',
  assessmentStatus: 'complete',
);

class _Auth extends AuthNotifier {
  _Auth(this.u);
  final UserEntity u;
  @override
  Future<AuthState> build() async => AuthState(user: u);
}

class _NullStorage extends SecureStorageService {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

Map<String, dynamic> etJson({
  int id = 7,
  String name = 'pay_slip',
  String displayName = 'Pay Slip',
  String subject = 'Your payslip for {MONTH}',
  String body = '<p>Hello {EMPLOYEE_NAME},</p><p>Your payslip is ready.</p>',
  String type = 'document',
  String typeDisplay = 'Document Templates',
  bool active = true,
  bool builtin = false,
  List<String> vars = const ['EMPLOYEE_NAME', 'MONTH'],
  List<Map<String, dynamic>> attachments = const [],
}) =>
    {
      'id': id,
      'name': name,
      'display_name': displayName,
      'description': '',
      'subject': subject,
      'body': body,
      'template_type': type,
      'template_type_display': typeDisplay,
      'is_active': active,
      'is_builtin': builtin,
      'available_variables': vars,
      'attachments': attachments,
    };

EmailTemplateModel etModel({
  int id = 7,
  String name = 'pay_slip',
  String displayName = 'Pay Slip',
  String subject = 'Your payslip for {MONTH}',
  String body = '<p>Hello {EMPLOYEE_NAME},</p><p>Your payslip is ready.</p>',
  bool active = true,
  bool builtin = false,
  List<String> vars = const ['EMPLOYEE_NAME', 'MONTH'],
  List<Map<String, dynamic>> attachments = const [],
}) =>
    EmailTemplateModel.fromJson(etJson(
        id: id,
        name: name,
        displayName: displayName,
        subject: subject,
        body: body,
        active: active,
        builtin: builtin,
        vars: vars,
        attachments: attachments));

class EtRequest {
  EtRequest(this.method, this.path, this.data, this.query);
  final String method;
  final String path;
  final dynamic data;
  final Map<String, dynamic> query;
  @override
  String toString() => '$method $path $data';
}

class EtBackend implements HttpClientAdapter {
  final requests = <EtRequest>[];
  List<Map<String, dynamic>> categories = [
    {'id': 1, 'name': 'document', 'display_name': 'Document Templates'},
    {'id': 2, 'name': 'notification', 'display_name': 'Notification Templates'},
    {'id': 3, 'name': 'reminder', 'display_name': 'Reminder Templates'},
    {'id': 4, 'name': 'wish', 'display_name': 'Wish Templates'},
  ];
  Map<String, dynamic>? company = {
    'company_name': 'Acme Test Pvt Ltd',
    'website': 'https://acme.example.test',
    'address': '1 Test Street',
    'city': 'Pune',
    'state': 'MH',
    'logo_url': null,
  };
  int companyStatus = 200;
  int? createStatus;
  int? patchStatus;
  int? categoryStatus;
  String errorMessage = 'Email template with this name already exists.';
  Completer<void>? hold; // holds create + patch responses until completed
  List<Map<String, dynamic>> templates = [];

  Iterable<EtRequest> where(String method, String path) => requests.where((r) => r.method == method && r.path == path);

  ResponseBody _json(Object b, [int status = 200]) => ResponseBody.fromString(jsonEncode(b), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  ResponseBody _err(int status) => _json({'status': 'error', 'message': errorMessage, 'data': {}}, status);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    dynamic data = o.data;
    if (data is FormData) data = {for (final f in data.fields) f.key: f.value, 'files': data.files.length};
    requests.add(EtRequest(o.method, o.path, data, Map<String, dynamic>.from(o.queryParameters)));
    final p = o.path;
    if (p == ApiConstants.settingsEmailTemplateCategories) {
      if (o.method == 'GET') return _json({'status': 'success', 'data': categories});
      if (categoryStatus != null) return _err(categoryStatus!);
      final body = o.data as Map;
      final c = {'id': 99, 'name': body['name'], 'display_name': body['display_name']};
      categories = [...categories, c];
      return _json({'status': 'success', 'data': c}, 201);
    }
    if (p == ApiConstants.settingsCompany) {
      if (companyStatus != 200) return _err(companyStatus);
      return _json({'status': 'success', 'data': company});
    }
    if (p == ApiConstants.settingsEmailTemplates) {
      if (o.method == 'GET') {
        return _json({
          'status': 'success',
          'data': {
            'count': templates.length,
            'page': 1,
            'page_size': 100,
            'total_pages': 1,
            'results': {'document': templates}
          }
        });
      }
      if (hold != null) await hold!.future;
      if (createStatus != null) return _err(createStatus!);
      final b = Map<String, dynamic>.from(o.data as Map);
      return _json({
        'status': 'success',
        'data': etJson(
          id: 50,
          name: b['name'] as String,
          displayName: b['display_name'] as String,
          subject: b['subject'] as String,
          body: b['body'] as String,
          type: b['template_type'] as String,
          vars: List<String>.from(b['available_variables'] as List),
        ),
      }, 201);
    }
    final detail = RegExp(r'^/settings/email-templates/(\d+)/$').firstMatch(p);
    if (detail != null) {
      final id = int.parse(detail.group(1)!);
      if (o.method == 'PATCH') {
        if (hold != null) await hold!.future;
        if (patchStatus != null) return _err(patchStatus!);
        final b = Map<String, dynamic>.from(o.data as Map);
        return _json({
          'status': 'success',
          'data': etJson(
            id: id,
            subject: b['subject'] as String,
            body: b['body'] as String,
            vars: List<String>.from(b['available_variables'] as List),
          ),
        });
      }
      if (o.method == 'POST') {
        return _json({
          'status': 'success',
          'data': {
            'id': 31,
            'filename': 'a.pdf',
            'mime_type': 'application/pdf',
            'size': 2048,
            'url': 'https://files.example.test/a.pdf',
          }
        }, 201);
      }
      if (o.method == 'DELETE') return _json({'status': 'success', 'data': {}});
    }
    return _json({'status': 'success', 'data': <String, dynamic>{}});
  }

  @override
  void close({bool force = false}) {}
}

/// Attachment uploads read the picked file from disk, which a widget test
/// cannot await; the upload is recorded on the stand-in server instead.
class EtDataSource extends SettingsRemoteDataSource {
  EtDataSource(super.dio, this.backend);
  final EtBackend backend;
  @override
  Future<EmailTemplateAttachmentModel> uploadTemplateAttachment(int templateId, File file, String mimeType) async {
    backend.requests.add(EtRequest('POST', ApiConstants.settingsEmailTemplateDetail(templateId),
        {'file': file.path.split('/').last, 'mime': mimeType, 'files': 1}, const {}));
    return EmailTemplateAttachmentModel.fromJson({
      'id': 31,
      'filename': file.path.split('/').last,
      'mime_type': mimeType,
      'size': 4,
      'url': 'https://files.example.test/${file.path.split('/').last}',
    });
  }
}

List<Override> etOverrides(EtBackend s) => [
      settingsDataSourceProvider.overrideWith((ref) => EtDataSource(ref.watch(dioProvider), s)),
      authStateProvider.overrideWith(() => _Auth(etAdmin)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = s),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ];

/// A host page with an "open" button that pushes [builder]'s route the way the
/// Email Templates screen does, and records what the route popped.
class EtHost extends StatefulWidget {
  const EtHost({super.key, required this.builder});
  final WidgetBuilder builder;
  @override
  State<EtHost> createState() => EtHostState();
}

class EtHostState extends State<EtHost> {
  Object? result = 'unset';
  @override
  Widget build(BuildContext context) => Scaffold(
        // Watched like the Email Templates page does, so the list stays alive under the pushed route.
        body: Consumer(builder: (context, ref, _) {
          ref.watch(emailTemplatesProvider);
          return Center(
            child: ElevatedButton(
              key: const Key('host-open'),
              onPressed: () async {
                final r = await Navigator.of(context).push<Object>(MaterialPageRoute(builder: widget.builder));
                setState(() => result = r);
              },
              child: Text('open (result: $result)'),
            ),
          );
        }),
      );
}

Widget etApp(EtBackend s, WidgetBuilder builder, {double scale = 1, List<Override> extra = const []}) => ProviderScope(
      key: UniqueKey(),
      overrides: [...etOverrides(s), ...extra],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.themeFor(false),
        builder: (c, child) =>
            MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
        home: EtHost(builder: builder),
      ),
    );
