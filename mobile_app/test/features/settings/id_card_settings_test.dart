import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/router/access_control.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/profile/data/services/profile_document_viewer.dart';
import 'package:mobile_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:mobile_app/features/profile/presentation/screens/profile_document_viewer_screen.dart';
import 'package:mobile_app/features/settings/data/models/company_model.dart';
import 'package:mobile_app/features/settings/data/models/id_card_settings_model.dart';
import 'package:mobile_app/features/settings/presentation/id_card/id_card_settings_providers.dart';
import 'package:mobile_app/features/settings/presentation/id_card/id_card_settings_screen.dart';
import 'package:mobile_app/features/settings/presentation/settings_hub/settings_screen.dart';

// Task 32: Settings → ID Card, as web app/dashboard/settings/id-card/page.tsx
// over GET/PUT /settings/id-card/ (+ GET /settings/id-card/reference-pdf/)
// — backend apps/accounts/views_id_card.py IdCardSettingsView
// (HasSettingsPermission: GET settings.view, PUT settings.edit; multipart).
// Synthetic data on a stand-in server; nothing real is read or changed.

const defaultTerms =
    'This ID card is the property of {company}.\nThis ID card is non-transferable.\nIf found, please return to the above address.';

Map<String, dynamic> settingsJson({
  String label = 'Authorised Signatory',
  String terms = '',
  bool dob = true,
  bool res = true,
  bool contact = true,
  bool pdf = false,
  bool signature = false,
}) =>
    {
      'signatory_label': label,
      'terms': terms,
      'default_terms': defaultTerms,
      'show_date_of_birth': dob,
      'show_residential_address': res,
      'show_contact_details': contact,
      'reference_pdf_name': pdf ? 'id-card-design.pdf' : '',
      'reference_pdf_size': pdf ? 245760 : null,
      'reference_pdf_url': pdf ? '/api/settings/id-card/reference-pdf/' : null,
      'signature_url': signature ? 'https://media.example.test/sign.png' : null,
      'updated_at': '2026-11-01T10:00:00Z',
      'updated_by_name': 'Test Admin',
    };

Map<String, dynamic> companyJson({String website = 'https://testco.example/'}) => {
      'company_name': 'Test Company Pvt Ltd',
      'trade_name': 'Test Co',
      'logo_url': null,
      'website': website,
      'address': '1 Office Road',
      'city': 'Pune',
      'state': 'Maharashtra',
      'pin_code': '411001',
    };

class Call {
  Call(this.method, this.path, this.data);
  final String method;
  final String path;
  final Object? data;
}

class Server implements HttpClientAdapter {
  Server({Map<String, dynamic>? settings}) : settings = settings ?? settingsJson();
  Map<String, dynamic> settings;
  Map<String, dynamic> company = companyJson();
  int getStatus = 200;
  int companyStatus = 200;
  int putStatus = 200;
  String? putMessage = 'Use at most 6 conditions so they fit on the card.';
  int pdfStatus = 200;
  List<int> pdfBytes = utf8.encode('%PDF-1.4\n%synthetic\n');
  Completer<void>? holdGet;
  Completer<void>? holdPut;
  final calls = <Call>[];

  List<Call> of(String method, String path) => calls.where((c) => c.method == method && c.path == path).toList();

  ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add(Call(o.method, o.path, o.data));
    if (o.path == ApiConstants.settingsIdCard && o.method == 'GET') {
      final gate = holdGet;
      if (gate != null) await gate.future;
      if (getStatus != 200) return _json({'status': 'error', 'message': 'Server error.', 'data': {}}, getStatus);
      return _json({'status': 'success', 'message': 'ID card settings retrieved.', 'data': settings});
    }
    if (o.path == ApiConstants.settingsIdCard && o.method == 'PUT') {
      final gate = holdPut;
      if (gate != null) await gate.future;
      if (putStatus != 200) {
        return _json({'status': 'error', if (putMessage != null) 'message': putMessage, 'data': {}}, putStatus);
      }
      final fd = o.data as FormData;
      final f = {for (final e in fd.fields) e.key: e.value};
      settings = {
        ...settings,
        'signatory_label': f['signatory_label']!.isEmpty ? 'Authorised Signatory' : f['signatory_label'],
        'terms': f['terms'],
        'show_date_of_birth': f['show_date_of_birth'] == 'true',
        'show_residential_address': f['show_residential_address'] == 'true',
        'show_contact_details': f['show_contact_details'] == 'true',
        if (fd.files.any((e) => e.key == 'reference_pdf')) ...{
          'reference_pdf_name': fd.files.firstWhere((e) => e.key == 'reference_pdf').value.filename,
          'reference_pdf_size': fd.files.firstWhere((e) => e.key == 'reference_pdf').value.length,
          'reference_pdf_url': '/api/settings/id-card/reference-pdf/',
        },
        if (f['remove_reference_pdf'] == 'true') ...{
          'reference_pdf_name': '',
          'reference_pdf_size': null,
          'reference_pdf_url': null,
        },
        if (fd.files.any((e) => e.key == 'signature_image')) 'signature_url': 'https://media.example.test/new-sign.png',
        if (f['remove_signature'] == 'true') 'signature_url': null,
      };
      return _json({'status': 'success', 'message': 'ID card settings saved.', 'data': settings});
    }
    if (o.path == ApiConstants.settingsIdCardReferencePdf) {
      if (pdfStatus != 200) {
        return _json({'status': 'error', 'message': 'No reference PDF has been uploaded.', 'data': {}}, pdfStatus);
      }
      return ResponseBody.fromBytes(pdfBytes, 200, headers: {
        Headers.contentTypeHeader: ['application/pdf']
      });
    }
    if (o.path == ApiConstants.settingsCompany) {
      if (companyStatus != 200) return _json({'status': 'error', 'message': 'Nope', 'data': {}}, companyStatus);
      return _json({'status': 'success', 'data': company});
    }
    return _json({'status': 'success', 'data': {}});
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

UserEntity user(List<String> perms, {bool superuser = false}) => UserEntity(
      id: 'a1',
      email: 'admin@example.test',
      fullName: 'Test Admin',
      role: 'hr',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: superuser,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final editor = user(const ['settings.view', 'settings.edit']);
final viewer = user(const ['settings.view']);
final superuser = user(const [], superuser: true);

late Server server;
late Directory tmp;
IdCardPickedFile? nextPdf;
IdCardPickedFile? nextSig;

class _TempStore extends ProfileDocumentTempStore {
  _TempStore() : super(tempRoot: () async => tmp);
}

List<Override> overrides(UserEntity u) => [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      idCardReferencePdfPickerProvider.overrideWithValue(() async => nextPdf),
      idCardSignaturePickerProvider.overrideWithValue(() async => nextSig),
      profileDocumentTempStoreProvider.overrideWithValue(_TempStore()),
      profilePdfViewBuilderProvider.overrideWithValue((path, tracker) =>
          Text('PDF VIEW ${File(path).readAsStringSync().substring(0, 5)}', key: const Key('pdf-standin'))),
    ];

late GoRouter router;

Future<void> pumpApp(WidgetTester tester,
    {UserEntity? as, Server? with_, String start = AppRoutes.settingsIdCard, bool settle = true}) async {
  tester.view.physicalSize = const Size(1080, 9000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = with_ ?? Server();
  router = GoRouter(initialLocation: AppRoutes.settings, routes: [
    GoRoute(path: AppRoutes.settings, builder: (_, __) => const SettingsScreen()),
    GoRoute(path: AppRoutes.settingsIdCard, builder: (_, __) => const IdCardSettingsScreen()),
    GoRoute(path: AppRoutes.settingsCompany, builder: (_, __) => const Scaffold(body: Text('COMPANY INFO SCREEN'))),
  ]);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: overrides(as ?? editor),
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
  if (start != AppRoutes.settings) {
    router.push(start);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }
}

Finder byKey(String k) => find.byKey(Key(k));

Future<void> tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(byKey(key));
  await tester.tap(byKey(key));
  await tester.pumpAndSettle();
}

/// Taps Save and lets the (async) multipart request finish.
Future<void> save(WidgetTester tester, {String key = 'idcs-save'}) async {
  await tester.pump();
  expect(enabled(tester, key), isTrue, reason: 'Save should be enabled');
  await tester.ensureVisible(byKey(key));
  await tester.runAsync(() async {
    await tester.tap(byKey(key));
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
  await tester.pumpAndSettle();
}

bool enabled(WidgetTester tester, String key) => tester.widget<ButtonStyleButton>(byKey(key)).onPressed != null;

Map<String, String> fieldsOf(Call c) => {for (final e in (c.data as FormData).fields) e.key: e.value};
List<String> fieldOrder(Call c) => [for (final e in (c.data as FormData).fields) e.key];
Map<String, MultipartFile> filesOf(Call c) => {for (final e in (c.data as FormData).files) e.key: e.value};

IdCardPickedFile tempFile(String name, {int size = 1024, List<int>? bytes}) {
  final f = File('${tmp.path}/$name')..writeAsBytesSync(bytes ?? List.filled(size, 65));
  return IdCardPickedFile(path: f.path, name: name, size: bytes?.length ?? size);
}

String textOf(WidgetTester tester, String key) => tester.widget<TextField>(byKey(key)).controller!.text;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('idcs_test');
    nextPdf = null;
    nextSig = null;
  });
  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  // ── Model ─────────────────────────────────────────────────────────────────

  group('model (IdCardSettingsSerializer fields)', () {
    test('parses every field', () {
      final s = IdCardSettingsModel.fromJson(
          settingsJson(label: 'HR Head', terms: 'A\nB', dob: false, pdf: true, signature: true));
      expect([s.signatoryLabel, s.terms, s.defaultTerms], ['HR Head', 'A\nB', defaultTerms]);
      expect([s.showDateOfBirth, s.showResidentialAddress, s.showContactDetails], [false, true, true]);
      expect([s.referencePdfName, s.referencePdfSize, s.referencePdfUrl],
          ['id-card-design.pdf', 245760, '/api/settings/id-card/reference-pdf/']);
      expect(s.signatureUrl, 'https://media.example.test/sign.png');
      expect([s.updatedAt, s.updatedByName], ['2026-11-01T10:00:00Z', 'Test Admin']);
      expect(s.hasReferencePdf, isTrue);
    });

    test('missing or unexpected values fall back to web\'s form defaults; unknown keys are ignored', () {
      final s = IdCardSettingsModel.fromJson(const {
        'show_date_of_birth': 'false',
        'show_residential_address': 'maybe',
        'show_contact_details': null,
        'reference_pdf_size': '12',
        'signature_url': '',
        'future_setting': {'x': 1},
      });
      expect(s.signatoryLabel, 'Authorised Signatory');
      expect([s.terms, s.defaultTerms, s.referencePdfName], ['', '', '']);
      expect([s.showDateOfBirth, s.showResidentialAddress, s.showContactDetails], [false, true, true]);
      expect(s.referencePdfSize, 12);
      expect([s.referencePdfUrl, s.signatureUrl], [null, null]);
      expect(s.hasReferencePdf, isFalse);
      expect(IdCardSettingsModel.fromJson(const {}).toForm(), const IdCardSettingsForm());
    });

    test('form payload = web onSave FormData text fields (caption trimmed, terms as typed, "true"/"false")', () {
      const f = IdCardSettingsForm(
          signatoryLabel: '  HR Head  ', terms: ' line 1\n\nline 2 ', showDateOfBirth: false, showContactDetails: true);
      expect(f.toFields(), {
        'signatory_label': 'HR Head',
        'terms': ' line 1\n\nline 2 ',
        'show_date_of_birth': 'false',
        'show_residential_address': 'true',
        'show_contact_details': 'true',
      });
      expect(f.toFields().keys,
          ['signatory_label', 'terms', 'show_date_of_birth', 'show_residential_address', 'show_contact_details']);
    });

    test('termsFromText: typed lines (trimmed, blanks dropped) else the defaults; {company} filled in', () {
      expect(idCardTermsFromText(' One for {company} \n\n Two ', defaultTerms, 'Test Co'), ['One for Test Co', 'Two']);
      expect(idCardTermsFromText('   ', defaultTerms, null).first, 'This ID card is the property of the company.');
      expect(idCardTermsFromText('', defaultTerms, 'Test Co'), hasLength(3));
    });

    test('formatBytes as web', () {
      expect([formatIdCardBytes(null), formatIdCardBytes(0), formatIdCardBytes(512)], ['', '', '512 B']);
      expect([formatIdCardBytes(245760), formatIdCardBytes(3 * 1024 * 1024 + 1)], ['240 KB', '3.0 MB']);
    });

    test('file checks: reference = .pdf under 10 MB; signature = PNG/JPEG/WebP under 2 MB (web messages)', () {
      IdCardPickedFile f(String n, int s) => IdCardPickedFile(path: '/x/$n', name: n, size: s);
      expect(validateIdCardReferencePdf(f('Design.PDF', 10 * 1024 * 1024)), isNull);
      expect(validateIdCardReferencePdf(f('design.docx', 10)), 'The reference file must be a PDF.');
      expect(validateIdCardReferencePdf(f('big.pdf', 10 * 1024 * 1024 + 1)), 'The reference PDF must be under 10 MB.');
      for (final n in ['s.png', 's.JPG', 's.jpeg', 's.webp']) {
        expect(validateIdCardSignature(f(n, 2 * 1024 * 1024)), isNull, reason: n);
      }
      expect(validateIdCardSignature(f('s.gif', 10)), 'The signature must be a PNG, JPEG, or WebP image.');
      expect(validateIdCardSignature(f('s.svg', 10)), 'The signature must be a PNG, JPEG, or WebP image.');
      expect(validateIdCardSignature(f('s.png', 2 * 1024 * 1024 + 1)), 'The signature image must be under 2 MB.');
    });

    test('sample preview data = web sampleCardData with the company branding and current form', () {
      final c = CompanyModel.fromJson(companyJson());
      final d = idCardSettingsSample(
        company: c,
        form: const IdCardSettingsForm(signatoryLabel: '  ', showDateOfBirth: false, showContactDetails: false),
        defaultTerms: defaultTerms,
        signatureUrl: null,
      );
      expect(d.employee.fullName, '[Employee Name]');
      expect([d.employee.dateOfBirth, d.employee.phone, d.employee.email], [null, null, null]);
      expect(d.employee.residentialAddress, '[Residential address]');
      expect([d.company.name, d.company.website, d.company.websiteUrl],
          ['Test Co', 'testco.example', 'https://testco.example/']);
      expect(d.company.officeAddress, '[Branch office address]');
      expect(d.card.terms.first, 'This ID card is the property of Test Co.');
      expect(d.card.signatoryLabel, 'Authorised Signatory');
    });
  });

  // ── Screen ────────────────────────────────────────────────────────────────

  group('loading and errors', () {
    testWidgets('shows "Loading settings…" then the saved values', (tester) async {
      final s = Server(settings: settingsJson(label: 'HR Head', terms: 'Keep it safe.', contact: false));
      s.holdGet = Completer();
      await pumpApp(tester, with_: s, settle: false);
      await tester.pump();
      expect(byKey('idcs-loading'), findsOneWidget);
      expect(find.text('Loading settings…'), findsOneWidget);
      s.holdGet!.complete();
      await tester.pumpAndSettle();
      expect(textOf(tester, 'idcs-caption'), 'HR Head');
      expect(textOf(tester, 'idcs-terms'), 'Keep it safe.');
      expect(tester.widget<CheckboxListTile>(byKey('idcs-toggle-show_contact_details')).value, isFalse);
      expect(tester.widget<CheckboxListTile>(byKey('idcs-toggle-show_date_of_birth')).value, isTrue);
      expect(server.of('GET', ApiConstants.settingsIdCard), hasLength(1));
      expect(server.of('GET', ApiConstants.settingsCompany), hasLength(1));
    });

    testWidgets('load failure → "Could not load ID card settings." with Retry', (tester) async {
      final s = Server()..getStatus = 500;
      await pumpApp(tester, with_: s);
      expect(find.text('Could not load ID card settings.'), findsOneWidget);
      expect(byKey('idcs-save'), findsNothing);
      s.getStatus = 200;
      await tap(tester, 'idcs-retry');
      expect(byKey('idcs-caption'), findsOneWidget);
      expect(server.of('GET', ApiConstants.settingsIdCard), hasLength(2));
    });

    testWidgets('Company Info unavailable: the page still opens, branding shown as missing (web .catch)',
        (tester) async {
      final s = Server()..companyStatus = 403;
      await pumpApp(tester, with_: s);
      expect(byKey('idcs-caption'), findsOneWidget);
      expect(find.text('No logo'), findsOneWidget);
      expect(find.textContaining('(no website set)'), findsOneWidget);
    });
  });

  group('content', () {
    testWidgets('every web section, label and hint is present', (tester) async {
      await pumpApp(tester);
      for (final t in [
        'Employee ID card design, terms and authorised signature',
        'Reference design',
        'No reference PDF uploaded.',
        'Logo and website',
        'Edit in Company Info',
        'Card content',
        'Authorised signature',
        'Signature caption',
        'Terms & conditions',
        'Personal details printed on the card',
        'Layout preview',
      ]) {
        expect(find.text(t), findsWidgets, reason: t);
      }
      expect(find.textContaining('Keep the approved ID card PDF here for reference.'), findsOneWidget);
      expect(find.text('The card uses the company logo and website from Company Info (https://testco.example/).'),
          findsOneWidget);
      expect(find.textContaining('PNG, JPEG or WebP, up to 2 MB. Stored privately.'), findsOneWidget);
      expect(
          find.textContaining('One condition per line, up to 6. Use {company} for the company name.'), findsOneWidget);
      for (final (label, hint) in [
        ('Date of birth', 'Front of the card'),
        ('Residential address', 'Back of the card'),
        ('Phone and email', 'Back of the card (Contact Details)'),
      ]) {
        expect(find.text('$label — $hint', findRichText: true), findsOneWidget, reason: label);
      }
      expect(find.textContaining('Sample layout with placeholder text.', findRichText: true), findsOneWidget);
      // Terms placeholder = the default conditions; caption limited to 60.
      final terms = tester.widget<TextField>(byKey('idcs-terms'));
      expect(terms.decoration!.hintText, defaultTerms);
      expect(tester.widget<TextField>(byKey('idcs-caption')).maxLength, 60);
      expect(find.text('None'), findsOneWidget, reason: 'no signature');
    });

    testWidgets('stored reference PDF: name, size and View', (tester) async {
      await pumpApp(tester, with_: Server(settings: settingsJson(pdf: true, signature: true)));
      expect(find.text('id-card-design.pdf'), findsOneWidget);
      expect(find.text('240 KB'), findsOneWidget);
      expect(byKey('idcs-pdf-view'), findsOneWidget);
      expect(find.text('Replace PDF'), findsOneWidget);
      expect(byKey('idcs-pdf-remove'), findsOneWidget);
      expect(byKey('idcs-signature-url'), findsOneWidget);
      expect(find.text('Replace'), findsOneWidget);
    });

    testWidgets('caption is capped at 60 characters', (tester) async {
      await pumpApp(tester);
      await tester.enterText(byKey('idcs-caption'), 'x' * 80);
      await tester.pump();
      expect(textOf(tester, 'idcs-caption'), hasLength(60));
    });

    testWidgets('preview follows the form: toggles hide rows/sections, terms and caption update', (tester) async {
      await pumpApp(tester);
      Finder inBack(Finder f) => find.descendant(of: byKey('idcs-preview-back'), matching: f);
      Finder inFront(Finder f) => find.descendant(of: byKey('idcs-preview-front'), matching: f);
      expect(inFront(byKey('idc-row-dob')), findsOneWidget);
      expect(inBack(byKey('idc-section-res')), findsOneWidget);
      expect(inBack(byKey('idc-section-con')), findsOneWidget);
      expect(inBack(find.text('This ID card is the property of Test Co.')), findsOneWidget, reason: 'default terms');

      await tap(tester, 'idcs-toggle-show_date_of_birth');
      await tap(tester, 'idcs-toggle-show_residential_address');
      await tap(tester, 'idcs-toggle-show_contact_details');
      expect(inFront(byKey('idc-row-dob')), findsNothing);
      expect(inBack(byKey('idc-section-res')), findsNothing);
      expect(inBack(byKey('idc-section-con')), findsNothing);
      expect(inBack(byKey('idc-section-off')), findsOneWidget, reason: 'office address always shown');

      await tester.enterText(byKey('idcs-terms'), 'Return to {company} on exit.\n\nCarry it always.');
      await tester.enterText(byKey('idcs-caption'), 'HR Head');
      await tester.pumpAndSettle();
      expect(inBack(find.text('Return to Test Co on exit.')), findsOneWidget);
      expect(inBack(find.text('Carry it always.')), findsOneWidget);
      expect(inBack(find.text('This ID card is the property of Test Co.')), findsNothing);
      expect(inBack(find.text('HR Head')), findsOneWidget);
      expect(inFront(find.text('TEST CO')), findsNothing);
      expect(inFront(find.text('Test Co')), findsOneWidget, reason: 'company name as the logo text');
    });
  });

  group('permissions', () {
    testWidgets('settings.view only: read-only notice, every control disabled, no Save/Cancel/upload/remove',
        (tester) async {
      await pumpApp(tester, as: viewer, with_: Server(settings: settingsJson(pdf: true, signature: true)));
      expect(find.text('You can view these settings but not change them.'), findsOneWidget);
      for (final k in [
        'idcs-save',
        'idcs-save-top',
        'idcs-cancel',
        'idcs-pdf-upload',
        'idcs-pdf-remove',
        'idcs-sig-upload',
        'idcs-sig-remove'
      ]) {
        expect(byKey(k), findsNothing, reason: k);
      }
      expect(tester.widget<TextField>(byKey('idcs-caption')).enabled, isFalse);
      expect(tester.widget<TextField>(byKey('idcs-terms')).enabled, isFalse);
      for (final k in ['show_date_of_birth', 'show_residential_address', 'show_contact_details']) {
        expect(tester.widget<CheckboxListTile>(byKey('idcs-toggle-$k')).onChanged, isNull, reason: k);
      }
      // Viewing is still allowed (settings.view), as on web.
      expect(byKey('idcs-pdf-view'), findsOneWidget);
      expect(byKey('idcs-edit-company'), findsOneWidget);
      expect(byKey('idcs-preview'), findsOneWidget);
      expect(server.calls.where((c) => c.method != 'GET'), isEmpty);
    });

    testWidgets('settings.edit and superusers can edit', (tester) async {
      for (final u in [editor, superuser]) {
        await pumpApp(tester, as: u);
        expect(find.text('You can view these settings but not change them.'), findsNothing);
        expect(byKey('idcs-save'), findsOneWidget);
        expect(tester.widget<TextField>(byKey('idcs-caption')).enabled, isTrue);
      }
    });

    test('route needs settings.view (web settings gate; GET /settings/id-card/)', () {
      expect(requiredPermissionsFor(AppRoutes.settingsIdCard), ['settings.view']);
      expect(canAccessPath(viewer, AppRoutes.settingsIdCard), isTrue);
      expect(canAccessPath(user(const ['employees.view']), AppRoutes.settingsIdCard), isFalse);
      expect(canAccessPath(superuser, AppRoutes.settingsIdCard), isTrue);
    });
  });

  group('editing and saving', () {
    testWidgets('Save and Cancel are disabled until something changes; Cancel restores the saved values',
        (tester) async {
      await pumpApp(tester);
      expect(enabled(tester, 'idcs-save'), isFalse);
      expect(enabled(tester, 'idcs-save-top'), isFalse);
      expect(enabled(tester, 'idcs-cancel'), isFalse);
      await tester.enterText(byKey('idcs-caption'), 'HR Head');
      await tester.pump();
      expect(enabled(tester, 'idcs-save'), isTrue);
      expect(enabled(tester, 'idcs-cancel'), isTrue);
      // Back to the saved value → not dirty again (web compares the form).
      await tester.enterText(byKey('idcs-caption'), 'Authorised Signatory');
      await tester.pump();
      expect(enabled(tester, 'idcs-save'), isFalse);

      await tester.enterText(byKey('idcs-terms'), 'New term');
      await tap(tester, 'idcs-toggle-show_contact_details');
      await tap(tester, 'idcs-cancel');
      expect(textOf(tester, 'idcs-terms'), '');
      expect(tester.widget<CheckboxListTile>(byKey('idcs-toggle-show_contact_details')).value, isTrue);
      expect(enabled(tester, 'idcs-save'), isFalse);
      expect(server.of('PUT', ApiConstants.settingsIdCard), isEmpty);
    });

    testWidgets('Save → one multipart PUT with exactly web\'s fields; success notice; saved values adopted',
        (tester) async {
      await pumpApp(tester);
      await tester.enterText(byKey('idcs-caption'), '  HR Head  ');
      await tester.enterText(byKey('idcs-terms'), 'Line one\nLine two');
      await tap(tester, 'idcs-toggle-show_date_of_birth');
      await save(tester);
      final puts = server.of('PUT', ApiConstants.settingsIdCard);
      expect(puts, hasLength(1));
      expect(puts.single.data, isA<FormData>());
      expect(fieldOrder(puts.single),
          ['signatory_label', 'terms', 'show_date_of_birth', 'show_residential_address', 'show_contact_details']);
      expect(fieldsOf(puts.single), {
        'signatory_label': 'HR Head',
        'terms': 'Line one\nLine two',
        'show_date_of_birth': 'false',
        'show_residential_address': 'true',
        'show_contact_details': 'true',
      });
      expect(filesOf(puts.single), isEmpty);
      expect(find.text('ID card settings saved.'), findsOneWidget);
      expect(textOf(tester, 'idcs-caption'), 'HR Head', reason: 'server value adopted');
      expect(enabled(tester, 'idcs-save'), isFalse);
      // Editing again clears the success notice.
      await tester.enterText(byKey('idcs-caption'), 'X');
      await tester.pump();
      expect(find.text('ID card settings saved.'), findsNothing);
    });

    testWidgets('the top Save button saves the same way', (tester) async {
      await pumpApp(tester);
      await tester.enterText(byKey('idcs-caption'), 'HR Head');
      await tester.pump();
      await save(tester, key: 'idcs-save-top');
      expect(server.of('PUT', ApiConstants.settingsIdCard), hasLength(1));
    });

    testWidgets('save failure: the server message is shown, edits are kept, and saving again works', (tester) async {
      final s = Server()..putStatus = 400;
      await pumpApp(tester, with_: s);
      await tester.enterText(byKey('idcs-terms'), List.generate(7, (i) => 'Term $i').join('\n'));
      await save(tester);
      expect(find.text('Use at most 6 conditions so they fit on the card.'), findsOneWidget);
      expect(textOf(tester, 'idcs-terms'), startsWith('Term 0'));
      expect(enabled(tester, 'idcs-save'), isTrue);
      expect(find.text('ID card settings saved.'), findsNothing);

      s.putStatus = 200;
      await tester.enterText(byKey('idcs-terms'), 'Term 0');
      await save(tester);
      expect(find.text('ID card settings saved.'), findsOneWidget);
      expect(find.text('Use at most 6 conditions so they fit on the card.'), findsNothing);
      expect(server.of('PUT', ApiConstants.settingsIdCard), hasLength(2));
    });

    testWidgets('a failure without a server message → "Failed to save. Please try again."', (tester) async {
      final s = Server()
        ..putStatus = 500
        ..putMessage = null;
      await pumpApp(tester, with_: s);
      await tester.enterText(byKey('idcs-caption'), 'HR Head');
      await save(tester);
      expect(find.text('Failed to save. Please try again.'), findsOneWidget);
    });

    testWidgets('while saving: "Saving…", every save/cancel control disabled, repeated taps send nothing more',
        (tester) async {
      final s = Server()..holdPut = Completer();
      await pumpApp(tester, with_: s);
      await tester.enterText(byKey('idcs-caption'), 'HR Head');
      await tester.pump();
      await tester.ensureVisible(byKey('idcs-save'));
      await tester.runAsync(() async {
        await tester.tap(byKey('idcs-save'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      expect(find.text('Saving…'), findsNWidgets(2));
      for (final k in ['idcs-save', 'idcs-save-top', 'idcs-cancel', 'idcs-pdf-upload', 'idcs-sig-upload']) {
        expect(enabled(tester, k), isFalse, reason: k);
      }
      await tester.tap(byKey('idcs-save'), warnIfMissed: false);
      await tester.tap(byKey('idcs-save-top'), warnIfMissed: false);
      await tester.pump();
      s.holdPut!.complete();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      expect(s.of('PUT', ApiConstants.settingsIdCard), hasLength(1));
      expect(find.text('ID card settings saved.'), findsOneWidget);
    });
  });

  group('reference PDF', () {
    testWidgets('Upload: shown as pending, then sent as reference_pdf (no remove flag)', (tester) async {
      await pumpApp(tester);
      nextPdf = tempFile('approved-design.pdf', size: 2048);
      await tap(tester, 'idcs-pdf-upload');
      expect(find.text('approved-design.pdf (2 KB) — saves on Save Changes'), findsOneWidget);
      expect(find.text('Replace PDF'), findsOneWidget);
      expect(enabled(tester, 'idcs-save'), isTrue);
      await save(tester);
      final put = server.of('PUT', ApiConstants.settingsIdCard).single;
      expect(filesOf(put).keys, ['reference_pdf']);
      expect(filesOf(put)['reference_pdf']!.filename, 'approved-design.pdf');
      expect(fieldsOf(put).containsKey('remove_reference_pdf'), isFalse);
      expect(find.text('approved-design.pdf'), findsOneWidget, reason: 'now stored');
    });

    testWidgets('wrong type or too large → web\'s message; nothing pending', (tester) async {
      await pumpApp(tester);
      nextPdf = tempFile('design.docx');
      await tap(tester, 'idcs-pdf-upload');
      expect(find.text('The reference file must be a PDF.'), findsOneWidget);
      expect(byKey('idcs-pdf-pending'), findsNothing);
      nextPdf = const IdCardPickedFile(path: '/nope/big.pdf', name: 'big.pdf', size: 10 * 1024 * 1024 + 1);
      await tap(tester, 'idcs-pdf-upload');
      expect(find.text('The reference PDF must be under 10 MB.'), findsOneWidget);
      expect(enabled(tester, 'idcs-save'), isFalse);
      // A good pick clears the error.
      nextPdf = tempFile('ok.pdf');
      await tap(tester, 'idcs-pdf-upload');
      expect(byKey('idcs-error'), findsNothing);
    });

    testWidgets('Remove a stored PDF → "No reference PDF uploaded." and Save sends remove_reference_pdf=true',
        (tester) async {
      await pumpApp(tester, with_: Server(settings: settingsJson(pdf: true)));
      await tap(tester, 'idcs-pdf-remove');
      expect(find.text('No reference PDF uploaded.'), findsOneWidget);
      expect(find.text('Upload PDF'), findsOneWidget);
      await save(tester);
      final put = server.of('PUT', ApiConstants.settingsIdCard).single;
      expect(fieldsOf(put)['remove_reference_pdf'], 'true');
      expect(filesOf(put), isEmpty);
    });

    testWidgets('Remove a pending pick when nothing is stored → back to unchanged (no flag)', (tester) async {
      await pumpApp(tester);
      nextPdf = tempFile('a.pdf');
      await tap(tester, 'idcs-pdf-upload');
      await tap(tester, 'idcs-pdf-remove');
      expect(find.text('No reference PDF uploaded.'), findsOneWidget);
      expect(enabled(tester, 'idcs-save'), isFalse);
    });

    testWidgets('a new pick after Remove replaces the file and cancels the removal', (tester) async {
      await pumpApp(tester, with_: Server(settings: settingsJson(pdf: true)));
      await tap(tester, 'idcs-pdf-remove');
      nextPdf = tempFile('v2.pdf');
      await tap(tester, 'idcs-pdf-upload');
      await save(tester);
      final put = server.of('PUT', ApiConstants.settingsIdCard).single;
      expect(filesOf(put).keys, ['reference_pdf']);
      expect(fieldsOf(put).containsKey('remove_reference_pdf'), isFalse);
    });

    testWidgets('View downloads it with the login and opens the in-app viewer', (tester) async {
      await pumpApp(tester, with_: Server(settings: settingsJson(pdf: true)));
      await tester.ensureVisible(byKey('idcs-pdf-view'));
      await tester.runAsync(() async {
        await tester.tap(byKey('idcs-pdf-view'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      expect(server.of('GET', ApiConstants.settingsIdCardReferencePdf), hasLength(1));
      expect(find.byType(ProfileDocumentViewerScreen), findsOneWidget);
      expect(find.text('PDF VIEW %PDF-'), findsOneWidget);
      expect(find.text('id-card-design.pdf'), findsWidgets, reason: 'viewer title');
    });

    testWidgets('View failure shows the server\'s message', (tester) async {
      final s = Server(settings: settingsJson(pdf: true))..pdfStatus = 404;
      await pumpApp(tester, with_: s);
      await tester.ensureVisible(byKey('idcs-pdf-view'));
      await tester.runAsync(() async {
        await tester.tap(byKey('idcs-pdf-view'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      expect(find.text('No reference PDF has been uploaded.'), findsOneWidget);
      expect(find.byType(ProfileDocumentViewerScreen), findsNothing);
      expect(enabled(tester, 'idcs-pdf-view'), isTrue);
    });

    testWidgets('View of something that is not a PDF is refused', (tester) async {
      final s = Server(settings: settingsJson(pdf: true))..pdfBytes = utf8.encode('<html>login</html>');
      await pumpApp(tester, with_: s);
      await tester.ensureVisible(byKey('idcs-pdf-view'));
      await tester.runAsync(() async {
        await tester.tap(byKey('idcs-pdf-view'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      expect(find.byType(ProfileDocumentViewerScreen), findsNothing);
      expect(byKey('idcs-error'), findsOneWidget);
    });
  });

  group('signature', () {
    testWidgets('Upload: previewed in the box and on the card back, then sent as signature_image', (tester) async {
      await pumpApp(tester);
      nextSig = tempFile('sign.png');
      await tap(tester, 'idcs-sig-upload');
      expect(byKey('idcs-signature-file'), findsOneWidget);
      expect(find.descendant(of: byKey('idcs-preview-back'), matching: byKey('idc-signature-image')), findsOneWidget);
      expect(find.text('Replace'), findsOneWidget);
      await save(tester);
      final put = server.of('PUT', ApiConstants.settingsIdCard).single;
      expect(filesOf(put).keys, ['signature_image']);
      expect(filesOf(put)['signature_image']!.filename, 'sign.png');
      expect(fieldsOf(put).containsKey('remove_signature'), isFalse);
      expect(byKey('idcs-signature-url'), findsOneWidget, reason: 'stored signature shown after save');
    });

    testWidgets('wrong type or too large → web\'s message', (tester) async {
      await pumpApp(tester);
      nextSig = tempFile('sign.gif');
      await tap(tester, 'idcs-sig-upload');
      expect(find.text('The signature must be a PNG, JPEG, or WebP image.'), findsOneWidget);
      nextSig = const IdCardPickedFile(path: '/nope/big.png', name: 'big.png', size: 2 * 1024 * 1024 + 1);
      await tap(tester, 'idcs-sig-upload');
      expect(find.text('The signature image must be under 2 MB.'), findsOneWidget);
      expect(byKey('idcs-signature-none'), findsOneWidget);
      expect(enabled(tester, 'idcs-save'), isFalse);
    });

    testWidgets('Remove a stored signature → "None" and Save sends remove_signature=true', (tester) async {
      await pumpApp(tester, with_: Server(settings: settingsJson(signature: true)));
      await tap(tester, 'idcs-sig-remove');
      expect(byKey('idcs-signature-none'), findsOneWidget);
      expect(find.descendant(of: byKey('idcs-preview-back'), matching: byKey('idc-signature-image')), findsNothing);
      await save(tester);
      final put = server.of('PUT', ApiConstants.settingsIdCard).single;
      expect(fieldsOf(put)['remove_signature'], 'true');
      expect(filesOf(put), isEmpty);
      expect(byKey('idcs-signature-none'), findsOneWidget);
    });

    testWidgets('PDF and signature changes together → one PUT carrying both', (tester) async {
      await pumpApp(tester, with_: Server(settings: settingsJson(signature: true)));
      nextPdf = tempFile('d.pdf');
      await tap(tester, 'idcs-pdf-upload');
      await tap(tester, 'idcs-sig-remove');
      await save(tester);
      final put = server.of('PUT', ApiConstants.settingsIdCard).single;
      expect(filesOf(put).keys, ['reference_pdf']);
      expect(fieldsOf(put)['remove_signature'], 'true');
    });
  });

  group('navigation', () {
    testWidgets('the ID Card tile is under Company, opens the screen, and back returns to Settings', (tester) async {
      await pumpApp(tester, start: AppRoutes.settings);
      expect(find.text('ID Card'), findsOneWidget);
      expect(find.text('Employee ID card design, terms and authorised signature'), findsOneWidget);
      await tester.tap(find.text('Company'));
      await tester.pumpAndSettle();
      expect(find.text('ID Card'), findsOneWidget);
      await tester.tap(find.text('Modules'));
      await tester.pumpAndSettle();
      expect(find.text('ID Card'), findsNothing);
      await tester.tap(find.text('All Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ID Card'));
      await tester.pumpAndSettle();
      expect(find.byType(IdCardSettingsScreen), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('"Edit in Company Info" opens Company Info', (tester) async {
      await pumpApp(tester);
      await tap(tester, 'idcs-edit-company');
      expect(find.text('COMPANY INFO SCREEN'), findsOneWidget);
    });

    test('the real router registers /settings/id-card', () {
      expect(AppRoutes.settingsIdCard, '/settings/id-card');
      expect(ApiConstants.settingsIdCard, '/settings/id-card/');
      expect(ApiConstants.settingsIdCardReferencePdf, '/settings/id-card/reference-pdf/');
    });
  });
}
