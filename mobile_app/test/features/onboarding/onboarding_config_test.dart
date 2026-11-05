import 'dart:async';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/facial_recognition/domain/entities/face_verification_status_entity.dart';
import 'package:mobile_app/features/facial_recognition/presentation/providers/facial_recognition_providers.dart';
import 'package:mobile_app/features/onboarding/data/datasources/onboarding_datasource.dart';
import 'package:mobile_app/features/onboarding/data/models/onboarding_config_models.dart';
import 'package:mobile_app/features/onboarding/data/models/onboarding_model.dart';
import 'package:mobile_app/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:mobile_app/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:mobile_app/features/onboarding/presentation/widgets/onboarding_custom_file_field.dart';
import 'package:mobile_app/features/settings/data/models/onboarding_field_config_model.dart';

import 'onboarding_fake_server.dart';

// Phase 4: the employee onboarding wizard driven by the admin's
// configuration — fields (order, visibility, required, type), document
// types, and custom file fields — against a stand-in for the production API.

class _NullSecureStorage extends SecureStorageService {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState(
      user: UserEntity(
          id: 'u1',
          email: 'e@example.com',
          fullName: 'Pat',
          role: 'employee',
          roleDisplay: 'Employee',
          mustChangePassword: false,
          permissions: [],
          onboardingStatus: 'draft',
          assessmentStatus: 'complete'));
}

/// Personal step, deliberately listed out of order; father_name is hidden.
List<Map<String, dynamic>> _fields() => [
      field('date_of_birth', 'Date of Birth', 0, 2, type: 'date'),
      field('gender', 'Gender', 0, 1, type: 'dropdown', required: true),
      field('father_name', "Father's Name", 0, 3, visible: false),
      field('tshirt_size', 'T-shirt Size', 0, 4, type: 'dropdown', custom: true, options: ['S', 'M', 'L']),
      field('remote_ok', 'Open to remote work', 0, 5, type: 'checkbox', custom: true),
      field('favourite_tool', 'Favourite Tool', 0, 6, type: 'rating', custom: true),
      field('id_proof', 'ID Proof', 0, 7, type: 'file', required: true, custom: true),
      field('highest_qualification', 'Highest Qualification', 1, 1, required: true),
      field('years_coding', 'Years Coding', 1, 2, type: 'number', custom: true),
      field('bank_name', 'Bank Name', 2, 1),
      field('emergency_name', 'Contact Name', 3, 1, required: true),
      field('emergency_phone', 'Contact Phone', 3, 2, required: true),
    ];

List<Map<String, dynamic>> _docTypes() => [
      docType('aadhaar_card', 'Aadhaar Card', 2, required: true),
      docType('resume', 'Resume', 1, multiple: true),
      docType('experience_letter', 'Experience Letter', 3, visible: false),
    ];

late FakeOnboardingServer server;
late ProviderContainer container;
late List<PlatformFile?> picks;

PlatformFile pdf(String name, {int size = 2048}) => PlatformFile(name: name, size: size, bytes: Uint8List(size));

Future<void> pumpWizard(WidgetTester tester,
    {List<Map<String, dynamic>>? fields,
    List<Map<String, dynamic>>? docs,
    Map<String, Object?>? profile,
    List<int> completed = const [],
    bool failConfig = false}) async {
  tester.view.physicalSize = const Size(1080, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = FakeOnboardingServer(
      fields: fields ?? _fields(), docTypes: docs ?? _docTypes(), profile: profile, completedSteps: completed)
    ..failConfig = failConfig;
  picks = [];
  final router = GoRouter(initialLocation: '/start', routes: [
    GoRoute(path: '/start', builder: (_, __) => const Scaffold(body: Text('START'))),
    GoRoute(path: AppRoutes.onboarding, builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: AppRoutes.onboardingAwaiting, builder: (_, __) => const Scaffold(body: Text('AWAITING'))),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullSecureStorage()),
      authStateProvider.overrideWith(_Auth.new),
      faceVerificationStatusProvider
          .overrideWith((ref) async => const FaceVerificationStatusEntity(isMandatory: false)),
      onboardingFilePickerProvider.overrideWithValue(() async => picks.isEmpty ? null : picks.removeAt(0)),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
  // As in the app, auth is loaded before the wizard opens.
  await ProviderScope.containerOf(tester.element(find.text('START'))).read(authStateProvider.future);
  router.go(AppRoutes.onboarding);
  await tester.pumpAndSettle();
  container = ProviderScope.containerOf(tester.element(find.byType(OnboardingScreen)));
}

Finder fieldKey(String key) => find.byKey(Key('onboarding-field-$key'));

Future<void> type(WidgetTester tester, String key, String text) async {
  final input = find.descendant(of: fieldKey(key), matching: find.byType(EditableText));
  await tester.ensureVisible(input);
  await tester.enterText(input, text);
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, String key, String option) async {
  await tester.ensureVisible(fieldKey(key));
  await tester.tap(fieldKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> goToStep(WidgetTester tester, int step) async {
  container.read(onboardingStepProvider.notifier).state = step;
  await tester.pumpAndSettle();
}

double _top(WidgetTester tester, String key) => tester.getTopLeft(fieldKey(key)).dy;

Map<String, dynamic> lastPatch(int step) =>
    (server.calls.lastWhere((c) => c.method == 'PATCH' && c.path == '/onboarding/step/$step/').body as Map).cast();

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('configured fields', () {
    testWidgets('render visible fields in configured order with required markers', (tester) async {
      await pumpWizard(tester);
      expect(fieldKey('gender'), findsOneWidget);
      expect(fieldKey('father_name'), findsNothing); // hidden by the admin
      expect(find.text('Gender *'), findsOneWidget);
      expect(find.text('Date of Birth'), findsOneWidget); // optional — no marker
      expect(find.text('ID Proof *'), findsOneWidget);
      // Built-in fields the admin did not configure are not shown.
      expect(find.text('Current Address'), findsNothing);
      expect(_top(tester, 'gender'), lessThan(_top(tester, 'date_of_birth')));
      expect(_top(tester, 'date_of_birth'), lessThan(_top(tester, 'tshirt_size')));
      expect(_top(tester, 'tshirt_size'), lessThan(_top(tester, 'remote_ok')));
      expect(_top(tester, 'remote_ok'), lessThan(_top(tester, 'favourite_tool')));
    });

    testWidgets('an unknown field type is shown as a text input, not a crash', (tester) async {
      await pumpWizard(tester);
      expect(tester.takeException(), isNull);
      expect(find.descendant(of: fieldKey('favourite_tool'), matching: find.byType(EditableText)), findsOneWidget);
    });

    testWidgets('prefill comes from the profile and custom_field_values', (tester) async {
      await pumpWizard(tester, profile: {'date_of_birth': '1990-04-12', 'gender': 'female'});
      expect(find.text('1990-04-12'), findsOneWidget);
      expect(find.text('Female'), findsOneWidget);
    });

    testWidgets('required fields block saving — nothing is sent', (tester) async {
      await pumpWizard(tester);
      await tapText(tester, 'Save & Continue');
      expect(find.text('Gender is required.'), findsOneWidget);
      expect(find.text('ID Proof is required.'), findsOneWidget);
      expect(find.textContaining('Please fill in: Gender, ID Proof'), findsOneWidget);
      expect(server.count('PATCH', '/onboarding/step/0/'), 0);
      expect(container.read(onboardingStepProvider), 0);
    });

    testWidgets('saving sends every visible non-file value by field_key and advances', (tester) async {
      await pumpWizard(tester);
      picks.add(pdf('passport.pdf'));
      await tapText(tester, 'Upload');
      await choose(tester, 'gender', 'Male');
      await choose(tester, 'tshirt_size', 'M');
      await tester.tap(find.text('Open to remote work'));
      await tester.pumpAndSettle();
      await type(tester, 'favourite_tool', 'Vim');
      await tapText(tester, 'Save & Continue');

      final body = lastPatch(0);
      expect(body, {
        'gender': 'male',
        'date_of_birth': '',
        'tshirt_size': 'M',
        'remote_ok': 'true',
        'favourite_tool': 'Vim',
      });
      expect(body.containsKey('father_name'), isFalse); // hidden
      expect(body.containsKey('id_proof'), isFalse); // file — own endpoint
      expect(server.custom['tshirt_size'], 'M');
      expect(server.profile['gender'], 'male');
      expect(container.read(onboardingStepProvider), 1);
      expect(fieldKey('highest_qualification'), findsOneWidget);
    });

    testWidgets('number fields reject text before sending', (tester) async {
      await pumpWizard(tester, completed: const [0]);
      await goToStep(tester, 1);
      await type(tester, 'highest_qualification', 'B.Tech');
      await type(tester, 'years_coding', 'ten');
      await tapText(tester, 'Save & Continue');
      expect(find.text('Enter a number.'), findsOneWidget);
      expect(server.count('PATCH', '/onboarding/step/1/'), 0);
      await type(tester, 'years_coding', '10');
      await tester.pump(const Duration(seconds: 5)); // the error snackbar clears
      await tester.pumpAndSettle();
      await tapText(tester, 'Save & Continue');
      expect(lastPatch(1), {'highest_qualification': 'B.Tech', 'years_coding': '10'});
    });

    testWidgets('unsaved values survive moving between steps', (tester) async {
      await pumpWizard(tester, completed: const [0]);
      await goToStep(tester, 1);
      await type(tester, 'highest_qualification', 'MBA');
      await tapText(tester, 'Previous');
      expect(container.read(onboardingStepProvider), 0);
      await goToStep(tester, 1);
      expect(find.text('MBA'), findsOneWidget);
      expect(server.count('PATCH', '/onboarding/step/1/'), 0);
    });

    testWidgets('a server refusal shows under its field and keeps what was typed', (tester) async {
      await pumpWizard(tester, completed: const [0, 1, 2]);
      server.rejections['emergency_phone'] = 'Enter a valid phone number.';
      await goToStep(tester, 3);
      await type(tester, 'emergency_name', 'Sam');
      await type(tester, 'emergency_phone', '12');
      await tapText(tester, 'Save & Continue');
      expect(find.text('Enter a valid phone number.'), findsWidgets);
      expect(find.text('Sam'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(container.read(onboardingStepProvider), 3);
      expect(server.profile['emergency_phone'], isNull);
    });

    testWidgets('a step with no configured fields says so', (tester) async {
      await pumpWizard(tester, fields: _fields().where((f) => f['step'] != 2).toList(), completed: const [0, 1]);
      await goToStep(tester, 2);
      expect(find.text('No fields are configured for this step.'), findsOneWidget);
    });

    testWidgets('a configuration load failure offers Retry, never a fixed form', (tester) async {
      await pumpWizard(tester, failConfig: true);
      expect(find.text('Could not load the onboarding form. Please try again.'), findsOneWidget);
      expect(fieldKey('gender'), findsNothing);
      server.failConfig = false;
      await tapText(tester, 'Retry');
      expect(fieldKey('gender'), findsOneWidget);
    });
  });

  group('custom file fields', () {
    testWidgets('upload sends field_key and the file with its content type; list updates', (tester) async {
      await pumpWizard(tester);
      picks.add(pdf('passport.pdf', size: 3000));
      await tapText(tester, 'Upload');
      final call = server.calls.lastWhere((c) => c.method == 'POST');
      expect(call.path, '/onboarding/custom-file-fields/');
      final form = call.body as FormData;
      expect(form.fields.single.key, 'field_key');
      expect(form.fields.single.value, 'id_proof');
      expect(form.files.single.value.contentType?.mimeType, 'application/pdf');
      expect(find.textContaining('passport.pdf'), findsOneWidget);
      expect(find.text('Replace'), findsOneWidget); // single-file field
    });

    testWidgets('a disallowed type or an oversized file is refused before sending', (tester) async {
      await pumpWizard(tester);
      picks.add(PlatformFile(name: 'notes.docx', size: 10, bytes: Uint8List(10)));
      await tapText(tester, 'Upload');
      expect(find.text('Only PDF, JPG, and PNG files are allowed.'), findsOneWidget);
      picks.add(pdf('scan.png', size: 6 * 1024 * 1024));
      await tapText(tester, 'Upload');
      expect(find.text('File size 6.0 MB exceeds the 5 MB limit.'), findsOneWidget);
      expect(server.count('POST', '/onboarding/custom-file-fields/'), 0);
    });

    testWidgets('a single-file field replaces its file; Remove deletes it', (tester) async {
      await pumpWizard(tester);
      picks.addAll([pdf('a.pdf'), pdf('b.jpg')]);
      await tapText(tester, 'Upload');
      await tapText(tester, 'Replace');
      expect(server.customFiles.map((f) => f['file_name']), ['b.jpg']);
      expect(find.textContaining('a.pdf'), findsNothing);
      await tester.tap(find.byTooltip('Remove'));
      await tester.pumpAndSettle();
      expect(server.customFiles, isEmpty);
      expect(server.count('DELETE', '/onboarding/custom-file-fields/101/'), 1);
      expect(find.text('Upload'), findsOneWidget);
    });

    testWidgets('a multi-file field keeps adding', (tester) async {
      await pumpWizard(tester, fields: [
        field('certs', 'Certificates', 0, 1, type: 'file', custom: true, multiple: true),
      ]);
      picks.addAll([pdf('one.pdf'), pdf('two.pdf')]);
      await tapText(tester, 'Upload');
      await tapText(tester, 'Add another');
      expect(server.customFiles.length, 2);
      expect(find.textContaining('one.pdf'), findsOneWidget);
      expect(find.textContaining('two.pdf'), findsOneWidget);
    });
  });

  // Phase 11.7: failures never show raw DioException text.
  group('custom file field failures', () {
    Finder fileField(String key) => find.byKey(Key('onboarding-file-$key'));
    Finder inField(String key, Finder f) => find.descendant(of: fileField(key), matching: f);
    void expectNoRawError() {
      expect(find.textContaining('DioException'), findsNothing);
      expect(find.textContaining('SocketException'), findsNothing);
      expect(find.textContaining('Exception:'), findsNothing);
    }

    testWidgets('a refused upload shows the server message; nothing is listed; Upload works again', (tester) async {
      await pumpWizard(tester);
      for (final (status, message) in [
        (400, 'Uploaded file is empty.'),
        (403, '"ID Proof" can no longer be edited here. Contact HR to update it.'),
      ]) {
        server.refuseNextCustomFileUpload = (status: status, message: message);
        picks.add(pdf('passport.pdf'));
        await tapText(tester, 'Upload');
        expect(inField('id_proof', find.text(message)), findsOneWidget, reason: '$status');
        expectNoRawError();
      }
      expect(server.customFiles, isEmpty);
      expect(find.textContaining('passport.pdf'), findsNothing);
      // The button is usable again, and a later upload clears the error.
      picks.add(pdf('passport.pdf'));
      await tapText(tester, 'Upload');
      expect(find.textContaining('passport.pdf'), findsOneWidget);
      expect(find.textContaining('can no longer be edited'), findsNothing);
    });

    testWidgets('a refusal without a server message gets the usual status message, not raw text', (tester) async {
      await pumpWizard(tester);
      server.refuseNextCustomFileUpload = (status: 502, message: null);
      picks.add(pdf('passport.pdf'));
      await tapText(tester, 'Upload');
      expect(inField('id_proof', find.text('Something went wrong on the server. Please try again.')), findsOneWidget);
      expect(find.textContaining('Bad Gateway'), findsNothing);
      expectNoRawError();
    });

    testWidgets('upload with no connection: a friendly message, then a retry succeeds', (tester) async {
      await pumpWizard(tester);
      server.dropNextCustomFileUpload = true;
      picks.add(pdf('passport.pdf'));
      await tapText(tester, 'Upload');
      expect(inField('id_proof', find.text(kCustomFileUploadConnectionError)), findsOneWidget);
      expectNoRawError();
      expect(server.customFiles, isEmpty);
      expect(find.text('Upload'), findsOneWidget); // not stuck "Uploading…"

      picks.add(pdf('passport.pdf'));
      await tapText(tester, 'Upload');
      expect(find.text(kCustomFileUploadConnectionError), findsNothing);
      expect(find.textContaining('passport.pdf'), findsOneWidget);
    });

    testWidgets('remove with no connection: a friendly message, the file stays, a retry removes it', (tester) async {
      await pumpWizard(tester);
      picks.add(pdf('passport.pdf'));
      await tapText(tester, 'Upload');
      server.dropNextCustomFileDelete = true;
      await tester.tap(find.byTooltip('Remove'));
      await tester.pumpAndSettle();
      expect(inField('id_proof', find.text(kCustomFileDeleteConnectionError)), findsOneWidget);
      expectNoRawError();
      expect(server.customFiles, hasLength(1));
      expect(find.textContaining('passport.pdf'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove'));
      await tester.pumpAndSettle();
      expect(server.customFiles, isEmpty);
      expect(find.text(kCustomFileDeleteConnectionError), findsNothing);
    });

    test('the provider maps each failure without exposing raw text', () async {
      final c = ProviderContainer(overrides: [
        dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))
          ..httpClientAdapter = FakeOnboardingServer(fields: _fields(), docTypes: _docTypes())),
      ]);
      addTearDown(c.dispose);
      final fake = (c.read(dioProvider).httpClientAdapter as FakeOnboardingServer)
        ..dropNextCustomFileUpload = true
        ..dropNextCustomFileDelete = true;
      c.listen(onboardingProfileProvider, (_, __) {});
      final n = c.read(onboardingProfileProvider.notifier);
      expect(await n.uploadCustomFile('id_proof', 'a.pdf', List.filled(10, 1)), kCustomFileUploadConnectionError);
      expect(await n.deleteCustomFile(5), kCustomFileDeleteConnectionError);
      fake.refuseNextCustomFileUpload = (status: 400, message: 'Uploaded file is empty.');
      expect(await n.uploadCustomFile('id_proof', 'a.pdf', List.filled(10, 1)), 'Uploaded file is empty.');
      // Local validation is unchanged and sends nothing.
      expect(await n.uploadCustomFile('id_proof', 'a.docx', List.filled(10, 1)),
          'Only PDF, JPG, and PNG files are allowed.');
      // A removal the server refuses keeps its message.
      expect(await n.deleteCustomFile(999), 'File not found.');
    });

    testWidgets('two file fields on one step work independently', (tester) async {
      await pumpWizard(tester, fields: [
        field('id_proof', 'ID Proof', 0, 1, type: 'file', required: true, custom: true),
        field('certs', 'Certificates', 0, 2, type: 'file', custom: true, multiple: true),
      ]);
      expect(fileField('id_proof'), findsOneWidget);
      expect(fileField('certs'), findsOneWidget);
      Finder button(String key) => inField(key, find.byType(OutlinedButton));
      bool enabled(String key) => tester.widget<OutlinedButton>(button(key)).onPressed != null;

      // While ID Proof uploads, only ID Proof is busy.
      final gate = server.holdNextCustomFileUpload = Completer<void>();
      picks.add(pdf('passport.pdf'));
      await tester.tap(inField('id_proof', find.text('Upload')));
      await tester.pump();
      expect(inField('id_proof', find.text('Uploading…')), findsOneWidget);
      expect(enabled('id_proof'), isFalse);
      expect(inField('certs', find.text('Upload')), findsOneWidget);
      expect(enabled('certs'), isTrue);
      gate.complete();
      await tester.pumpAndSettle();

      // A failure on Certificates stays on Certificates.
      server.dropNextCustomFileUpload = true;
      picks.add(pdf('degree.pdf'));
      await tester.tap(inField('certs', find.text('Upload')));
      await tester.pumpAndSettle();
      expect(inField('certs', find.text(kCustomFileUploadConnectionError)), findsOneWidget);
      expect(inField('id_proof', find.text(kCustomFileUploadConnectionError)), findsNothing);
      expect(enabled('id_proof'), isTrue);

      // Each file is stored and shown under its own field_key.
      picks.add(pdf('degree.pdf'));
      await tester.tap(inField('certs', find.text('Upload')));
      await tester.pumpAndSettle();
      expect({for (final f in server.customFiles) f['file_name']: f['field_key']},
          {'passport.pdf': 'id_proof', 'degree.pdf': 'certs'});
      expect(inField('id_proof', find.textContaining('passport.pdf')), findsOneWidget);
      expect(inField('id_proof', find.textContaining('degree.pdf')), findsNothing);
      expect(inField('certs', find.textContaining('degree.pdf')), findsOneWidget);
      expect(inField('certs', find.textContaining('passport.pdf')), findsNothing);
      expect(inField('id_proof', find.text('Replace')), findsOneWidget); // single-file
      expect(inField('certs', find.text('Add another')), findsOneWidget); // multi-file

      // Removing one leaves the other.
      await tester.tap(inField('id_proof', find.byTooltip('Remove')));
      await tester.pumpAndSettle();
      expect(server.customFiles.map((f) => f['field_key']), ['certs']);
      expect(inField('certs', find.textContaining('degree.pdf')), findsOneWidget);
    });
  });

  group('documents', () {
    testWidgets('show the configured types in order with required markers', (tester) async {
      await pumpWizard(tester, completed: const [0, 1, 2, 3]);
      expect(container.read(onboardingStepProvider), 4);
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Aadhaar Card *'), findsOneWidget);
      expect(find.text('Experience Letter'), findsNothing); // hidden
      expect(find.text('PAN Card'), findsNothing); // not configured
      final resume = tester.getTopLeft(find.byKey(const Key('onboarding-doc-resume'))).dy;
      final aadhaar = tester.getTopLeft(find.byKey(const Key('onboarding-doc-aadhaar_card'))).dy;
      expect(resume, lessThan(aadhaar));
    });

    testWidgets('submit is held back while a required document is missing', (tester) async {
      await pumpWizard(tester, completed: const [0, 1, 2, 3]);
      await tapText(tester, 'Submit for Approval');
      expect(find.text('Please upload: Aadhaar Card'), findsOneWidget);
      expect(find.text('Submit for Approval?'), findsNothing);
      expect(server.count('POST', '/onboarding/'), 0);
    });

    testWidgets('a document upload is sent with its type and a checked content type', (tester) async {
      await pumpWizard(tester, completed: const [0, 1, 2, 3]);
      picks.add(PlatformFile(name: 'aadhaar.exe', size: 10, bytes: Uint8List(10)));
      await tester.tap(
          find.descendant(of: find.byKey(const Key('onboarding-doc-aadhaar_card')), matching: find.text('Upload')));
      await tester.pumpAndSettle();
      expect(find.text('Only PDF, JPG, and PNG files are allowed.'), findsOneWidget);
      expect(server.count('POST', '/onboarding/documents/'), 0);

      picks.add(pdf('aadhaar.png'));
      await tester.tap(
          find.descendant(of: find.byKey(const Key('onboarding-doc-aadhaar_card')), matching: find.text('Upload')));
      await tester.pumpAndSettle();
      final form = server.calls.lastWhere((c) => c.method == 'POST').body as FormData;
      expect(form.fields.single.value, 'aadhaar_card');
      expect(form.files.single.value.contentType?.mimeType, 'image/png');
      expect(server.documents.single['document_type'], 'aadhaar_card');
      expect(find.text('Replace'), findsOneWidget); // non-multiple type
    });

    testWidgets('full submission once everything required is present', (tester) async {
      await pumpWizard(tester, completed: const [
        0,
        1,
        2,
        3
      ], profile: {
        'gender': 'male',
        'highest_qualification': 'BSc',
        'emergency_name': 'Sam',
        'emergency_phone': '9000000000',
      });
      server.customFiles.add({
        'id': 7,
        'field_key': 'id_proof',
        'file_url': 'https://files.invalid/x.pdf',
        'file_name': 'x.pdf',
        'file_size': 100,
      });
      picks.add(pdf('aadhaar.pdf'));
      await tester.tap(
          find.descendant(of: find.byKey(const Key('onboarding-doc-aadhaar_card')), matching: find.text('Upload')));
      await tester.pumpAndSettle();
      await tapText(tester, 'Submit for Approval');
      await tapText(tester, 'Submit');
      expect(server.submitted, isTrue);
      expect(find.text('AWAITING'), findsOneWidget);
    });

    testWidgets('a server refusal at submit is shown and the wizard stays', (tester) async {
      // Required ID Proof file is missing on the server.
      await pumpWizard(tester, completed: const [
        0,
        1,
        2,
        3
      ], docs: [
        docType('resume', 'Resume', 1),
      ]);
      await tapText(tester, 'Submit for Approval');
      await tapText(tester, 'Submit');
      expect(find.textContaining('Please complete the following required fields'), findsOneWidget);
      expect(server.submitted, isFalse);
      expect(find.text('AWAITING'), findsNothing);
    });
  });

  group('models and rules', () {
    test('fieldsFor keeps visible rows in order; document types likewise', () {
      final config = OnboardingConfig(
        fieldsByStep: OnboardingConfig.parseFields({
          '0': _fields().where((f) => f['step'] == 0).toList(),
          'x': [field('bad', 'Bad', 9, 1)],
        }),
        documentTypes: OnboardingConfig.parseDocumentTypes(_docTypes()),
      );
      expect(config.fieldsFor(0).map((f) => f.fieldKey),
          ['gender', 'date_of_birth', 'tshirt_size', 'remote_ok', 'favourite_tool', 'id_proof']);
      expect(config.fieldsFor(5), isEmpty);
      expect(config.visibleDocumentTypes.map((t) => t.typeKey), ['resume', 'aadhaar_card']);
    });

    test('upload rules match the backend', () {
      expect(onboardingUploadMime('A.PDF'), 'application/pdf');
      expect(onboardingUploadMime('photo.jpeg'), 'image/jpeg');
      expect(onboardingUploadMime('noext'), isNull);
      expect(onboardingUploadError('a.pdf', 0), 'Uploaded file is empty.');
      expect(onboardingUploadError('a.gif', 10), 'Only PDF, JPG, and PNG files are allowed.');
      expect(onboardingUploadError('a.pdf', kOnboardingUploadMaxBytes), isNull);
      expect(onboardingUploadError('a.pdf', kOnboardingUploadMaxBytes + 1), 'File size 5.0 MB exceeds the 5 MB limit.');
    });

    test('profile values flatten built-in and custom values as text', () {
      final values = OnboardingProfileModel.flatValues({
        'gender': 'male',
        'year_of_passing': 2014,
        'date_of_birth': null,
        'completed_steps': [0],
        'custom_field_values': {'remote_ok': 'true', 'shoe_size': 9},
      });
      expect(values, {'gender': 'male', 'year_of_passing': '2014', 'remote_ok': 'true', 'shoe_size': '9'});
    });

    test('missing required documents ignores hidden and uploaded types', () {
      final types = OnboardingConfig.parseDocumentTypes([
        docType('a', 'A', 1, required: true),
        docType('b', 'B', 2, required: true, visible: false),
        docType('c', 'C', 3, required: true),
        docType('d', 'D', 4),
      ]);
      final docs = [
        OnboardingDocModel.fromJson({'id': 1, 'document_type': 'c', 'file': 'u', 'file_name': 'c.pdf'}),
      ];
      expect(missingRequiredDocuments(types, docs), ['A']);
    });

    test('custom file rows parse integer ids and sizes', () {
      final f = CustomFileValue.fromJson(
          {'id': 12, 'field_key': 'k', 'file_name': 'x.pdf', 'file_size': 2048, 'file_url': 'u'});
      expect((f.id, f.fieldKey, f.fileSize), (12, 'k', 2048));
    });

    test('a 422 step save carries the per-field messages', () async {
      final s = FakeOnboardingServer(fields: _fields(), docTypes: const [])
        ..rejections['emergency_phone'] = 'Enter a valid phone number.';
      final ds = OnboardingDatasource(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = s);
      await expectLater(
        ds.saveStep(3, {'emergency_phone': '1'}),
        throwsA(isA<OnboardingSaveException>()
            .having((e) => e.message, 'message', 'Enter a valid phone number.')
            .having((e) => e.fieldErrors, 'fields', {'emergency_phone': 'Enter a valid phone number.'})),
      );
    });

    test('settings field model types cover what the renderer supports', () {
      expect(OnboardingFieldConfigModel.fieldTypeLabels.keys.toSet(),
          containsAll(['text', 'textarea', 'number', 'date', 'dropdown', 'checkbox', 'file']));
    });
  });
}
