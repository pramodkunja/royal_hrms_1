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
import 'package:mobile_app/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:mobile_app/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:mobile_app/features/onboarding/presentation/widgets/onboarding_custom_file_field.dart';

import 'onboarding_fake_server.dart';

// Phase 4.1: PAN number before the PAN card upload, the Documents step's
// Save Draft against the server's real answers, and choosing the first
// unfinished step only once the signed-in employee is known.

class _NullSecureStorage extends SecureStorageService {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

UserEntity _user({String onboarding = 'draft', bool mustChangePassword = false}) => UserEntity(
    id: 'u1',
    email: 'e@example.com',
    fullName: 'Pat',
    role: 'employee',
    roleDisplay: 'Employee',
    mustChangePassword: mustChangePassword,
    permissions: const [],
    onboardingStatus: onboarding,
    assessmentStatus: 'complete');

/// Auth that resolves only when [gate] completes (a slow /me response).
class _Auth extends AuthNotifier {
  _Auth(this.gate);
  final Completer<void>? gate;
  int builds = 0;
  @override
  Future<AuthState> build() async {
    builds++;
    if (gate != null) await gate!.future;
    return AuthState(user: _user());
  }
}

List<Map<String, dynamic>> _fields() => [
      field('gender', 'Gender', 0, 1, type: 'dropdown', required: true),
      field('highest_qualification', 'Highest Qualification', 1, 1, required: true),
      field('bank_name', 'Bank Name', 2, 1),
      field('emergency_name', 'Contact Name', 3, 1, required: true),
    ];

List<Map<String, dynamic>> _docsWithPan() => [
      docType('pan_card', 'PAN Card', 1, required: true),
      docType('aadhaar_card', 'Aadhaar Card', 2, required: true),
    ];

late FakeOnboardingServer server;
late ProviderContainer container;
late List<PlatformFile?> picks;

PlatformFile pdf(String name) => PlatformFile(name: name, size: 2048, bytes: Uint8List(2048));

/// Opens the wizard. With [authGate] the wizard is shown before auth has
/// resolved; otherwise auth is loaded first, as the router guarantees.
Future<void> pumpWizard(WidgetTester tester,
    {List<Map<String, dynamic>>? docs,
    Map<String, Object?>? profile,
    List<int> completed = const [0, 1, 2, 3],
    Completer<void>? authGate,
    Completer<void>? holdProfile}) async {
  tester.view.physicalSize = const Size(1080, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = FakeOnboardingServer(
      fields: _fields(), docTypes: docs ?? _docsWithPan(), profile: profile, completedSteps: completed)
    ..holdProfile = holdProfile;
  picks = [];
  final direct = authGate != null;
  final router = GoRouter(initialLocation: direct ? AppRoutes.onboarding : '/start', routes: [
    GoRoute(path: '/start', builder: (_, __) => const Scaffold(body: Text('START'))),
    GoRoute(path: AppRoutes.onboarding, builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: AppRoutes.onboardingAwaiting, builder: (_, __) => const Scaffold(body: Text('AWAITING'))),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullSecureStorage()),
      authStateProvider.overrideWith(() => _Auth(authGate)),
      faceVerificationStatusProvider
          .overrideWith((ref) async => const FaceVerificationStatusEntity(isMandatory: false)),
      onboardingFilePickerProvider.overrideWithValue(() async => picks.isEmpty ? null : picks.removeAt(0)),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  if (direct) {
    await tester.pump();
    container = ProviderScope.containerOf(tester.element(find.byType(OnboardingScreen)));
    return;
  }
  await tester.pumpAndSettle();
  await ProviderScope.containerOf(tester.element(find.text('START'))).read(authStateProvider.future);
  router.go(AppRoutes.onboarding);
  if (holdProfile != null) {
    await tester.pump();
    await tester.pump();
  } else {
    await tester.pumpAndSettle();
  }
  container = ProviderScope.containerOf(tester.element(find.byType(OnboardingScreen)));
}

final panInput = find.byKey(const Key('onboarding-pan-number'));

Finder uploadOn(String type) =>
    find.descendant(of: find.byKey(Key('onboarding-doc-$type')), matching: find.text('Upload'));

Future<void> tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> clearSnackBars(WidgetTester tester) async {
  ScaffoldMessenger.of(tester.element(find.byType(OnboardingScreen))).clearSnackBars();
  await tester.pumpAndSettle();
}

String panText(WidgetTester tester) => tester.widget<TextField>(panInput).controller!.text;

List<String> callLog() => [for (final c in server.calls) '${c.method} ${c.path}'];

int indexOf(String call) => callLog().indexOf(call);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('PAN number before the PAN card', () {
    testWidgets('shown only when PAN Card is a configured document type', (tester) async {
      await pumpWizard(tester, docs: [docType('aadhaar_card', 'Aadhaar Card', 1, required: true)]);
      expect(find.byKey(const Key('onboarding-doc-aadhaar_card')), findsOneWidget);
      expect(panInput, findsNothing);
    });

    testWidgets('appears under the PAN card, prefilled from the profile', (tester) async {
      await pumpWizard(tester, profile: {'pan_number': 'ABCDE1234F'});
      expect(panInput, findsOneWidget);
      expect(panText(tester), 'ABCDE1234F');
      final card = tester.getBottomLeft(find.byKey(const Key('onboarding-doc-pan_card'))).dy;
      expect(tester.getTopLeft(panInput).dy, greaterThanOrEqualTo(card));
    });

    testWidgets('a missing or malformed PAN stops before the file chooser', (tester) async {
      await pumpWizard(tester);
      picks.add(pdf('pan.pdf'));
      await tap(tester, uploadOn('pan_card'));
      expect(find.text('Enter your PAN number before uploading the PAN card.'), findsOneWidget);
      await tester.enterText(panInput, 'abc12');
      await tap(tester, uploadOn('pan_card'));
      expect(find.text('Enter a valid PAN (e.g. ABCDE1234F) — 5 letters, 4 digits, 1 letter.'), findsOneWidget);
      expect(picks, hasLength(1)); // the chooser never opened
      expect(server.count('PATCH', '/onboarding/step/4/'), 0);
      expect(server.count('POST', '/onboarding/documents/'), 0);
    });

    testWidgets('saves the PAN, then uploads the card', (tester) async {
      await pumpWizard(tester);
      await tester.enterText(panInput, 'abcde1234f');
      await tester.pump();
      expect(panText(tester), 'ABCDE1234F'); // typed in capitals
      picks.add(pdf('pan.pdf'));
      await tap(tester, uploadOn('pan_card'));

      final patch = server.calls.firstWhere((c) => c.method == 'PATCH');
      expect(patch.path, '/onboarding/step/4/');
      expect(patch.body, {'pan_number': 'ABCDE1234F'});
      expect(indexOf('PATCH /onboarding/step/4/'), lessThan(indexOf('POST /onboarding/documents/')));
      final form = server.calls.lastWhere((c) => c.method == 'POST').body as FormData;
      expect(form.fields.single.value, 'pan_card');
      expect(server.profile['pan_number'], 'ABCDE1234F');
      expect(server.documents.single['document_type'], 'pan_card');
      expect(panText(tester), 'ABCDE1234F');
    });

    testWidgets('a refused PAN blocks the upload and keeps what was typed', (tester) async {
      await pumpWizard(tester);
      server.takenPans.add('ABCDE1234F');
      await tester.enterText(panInput, 'ABCDE1234F');
      picks.add(pdf('pan.pdf'));
      await tap(tester, uploadOn('pan_card'));
      expect(find.text('This PAN is already registered to [Employee Name] ([Employee ID]).'), findsOneWidget);
      expect(server.count('POST', '/onboarding/documents/'), 0);
      expect(panText(tester), 'ABCDE1234F');
      // Editing the number clears the message.
      await tester.enterText(panInput, 'ABCDE1234G');
      await tester.pumpAndSettle();
      expect(find.textContaining('already registered'), findsNothing);
    });

    testWidgets('a connection failure while saving the PAN is reported; nothing is uploaded', (tester) async {
      await pumpWizard(tester);
      server.dropNextStep4 = true;
      await tester.enterText(panInput, 'ABCDE1234F');
      picks.add(pdf('pan.pdf'));
      await tap(tester, uploadOn('pan_card'));
      expect(find.text('No internet connection. Check your connection and try again.'), findsOneWidget);
      expect(server.count('POST', '/onboarding/documents/'), 0);
      expect(panText(tester), 'ABCDE1234F');
    });

    testWidgets('an upload failure after the PAN was saved keeps the PAN and reports the failure', (tester) async {
      await pumpWizard(tester);
      server.failNextDocumentUpload = true;
      await tester.enterText(panInput, 'ABCDE1234F');
      picks.add(pdf('pan.pdf'));
      await tap(tester, uploadOn('pan_card'));
      expect(server.profile['pan_number'], 'ABCDE1234F');
      expect(server.documents, isEmpty);
      expect(find.text('Upload failed. Please try again.'), findsOneWidget);
      expect(panText(tester), 'ABCDE1234F');
      expect(uploadOn('pan_card'), findsOneWidget); // can try again

      await clearSnackBars(tester);
      picks.add(pdf('pan.pdf'));
      await tap(tester, uploadOn('pan_card'));
      expect(server.documents.single['document_type'], 'pan_card');
    });

    testWidgets('other document types upload without touching the PAN', (tester) async {
      await pumpWizard(tester);
      picks.add(pdf('aadhaar.pdf'));
      await tap(tester, uploadOn('aadhaar_card'));
      expect(server.count('PATCH', '/onboarding/step/4/'), 0);
      expect(server.documents.single['document_type'], 'aadhaar_card');
    });
  });

  group('Save Draft on the Documents step', () {
    testWidgets('missing required documents: the server refusal is shown, nothing moves', (tester) async {
      await pumpWizard(tester, profile: {'pan_number': 'ABCDE1234F'});
      picks.add(pdf('aadhaar.pdf'));
      await tap(tester, uploadOn('aadhaar_card'));
      await clearSnackBars(tester);
      await tap(tester, find.text('Save Draft'));

      expect(find.text('Please upload the following required documents: PAN Card.'), findsOneWidget);
      expect(server.calls.last.body, isEmpty); // the plain document check
      expect(container.read(onboardingStepProvider), 4);
      expect(server.count('POST', '/onboarding/'), 0);
      expect(find.text('AWAITING'), findsNothing);
      // What was there stays: the uploaded document and the PAN number.
      expect(find.textContaining('aadhaar.pdf'), findsOneWidget);
      expect(panText(tester), 'ABCDE1234F');
    });

    testWidgets('all required documents present: the server confirmation is shown; not submitted', (tester) async {
      await pumpWizard(tester, docs: [docType('aadhaar_card', 'Aadhaar Card', 1, required: true)]);
      picks.add(pdf('aadhaar.pdf'));
      await tap(tester, uploadOn('aadhaar_card'));
      await clearSnackBars(tester);
      await tap(tester, find.text('Save Draft'));
      expect(find.text('Documents verified. You can proceed to submit.'), findsOneWidget);
      expect(container.read(onboardingStepProvider), 4);
      expect(server.submitted, isFalse);
      expect(find.text('AWAITING'), findsNothing);
    });

    testWidgets('a connection failure is reported, not treated as saved', (tester) async {
      await pumpWizard(tester, docs: [docType('aadhaar_card', 'Aadhaar Card', 1, required: true)]);
      picks.add(pdf('aadhaar.pdf'));
      await tap(tester, uploadOn('aadhaar_card'));
      await clearSnackBars(tester);
      server.dropNextStep4 = true;
      await tap(tester, find.text('Save Draft'));
      expect(find.text('No internet connection. Check your connection and try again.'), findsOneWidget);
      expect(find.textContaining('Documents verified'), findsNothing);
      expect(container.read(onboardingStepProvider), 4);
      expect(find.textContaining('aadhaar.pdf'), findsOneWidget);
    });
  });

  group('first unfinished step', () {
    testWidgets('waits for a slow auth response, then opens the first unfinished step', (tester) async {
      final gate = Completer<void>();
      await pumpWizard(tester, completed: const [0, 1], authGate: gate);
      await tester.pump(const Duration(milliseconds: 300));
      expect(server.count('GET', '/onboarding/'), 0); // nothing fetched before auth
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      gate.complete();
      await tester.pumpAndSettle();
      expect(container.read(onboardingStepProvider), 2);
      expect(find.text('Bank Name'), findsOneWidget);
      expect(server.count('GET', '/onboarding/'), 1);
    });

    testWidgets('an auth change while the profile is loading cannot leave the wrong step', (tester) async {
      final hold = Completer<void>();
      await pumpWizard(tester, completed: const [0, 1, 2], holdProfile: hold);
      container.invalidate(authStateProvider); // e.g. a profile refresh
      await tester.pump();
      await tester.pump();
      hold.complete();
      await tester.pumpAndSettle();
      expect(container.read(onboardingStepProvider), 3);
      expect(find.text('Contact Name *'), findsOneWidget);
    });

    testWidgets('a failed first load does not stop a later load from choosing the step', (tester) async {
      final hold = Completer<void>();
      await pumpWizard(tester, completed: const [0], holdProfile: hold);
      server.failNextProfile = true;
      hold.complete();
      await tester.pumpAndSettle();
      expect(container.read(onboardingStepProvider), 0); // nothing known yet
      container.invalidate(onboardingProfileProvider); // e.g. after a save
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(server.count('GET', '/onboarding/'), 2);
      expect(container.read(onboardingStepProvider), 1);
    });

    testWidgets('a reload after the employee moves on does not reset the step', (tester) async {
      await pumpWizard(tester, completed: const [0, 1, 2]);
      expect(container.read(onboardingStepProvider), 3);
      container.read(onboardingStepProvider.notifier).state = 1;
      container.invalidate(onboardingProfileProvider);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(server.count('GET', '/onboarding/'), 2);
      expect(container.read(onboardingStepProvider), 1);
    });
  });

  group('gate and redirect precedence (unchanged)', () {
    AuthState signedIn(UserEntity u) => AuthState(user: u);

    test('nothing opens the wizard while auth is still unknown', () {
      expect(resolveAuthRedirect(authState: null, path: AppRoutes.onboarding), AppRoutes.login);
    });

    test('a forced password change still comes before onboarding', () {
      expect(
          resolveAuthRedirect(
              authState: signedIn(_user(onboarding: 'pending', mustChangePassword: true)), path: AppRoutes.onboarding),
          AppRoutes.changePassword);
    });

    test('an employee mid-onboarding stays in the wizard; others are sent on', () {
      expect(resolveAuthRedirect(authState: signedIn(_user()), path: AppRoutes.onboarding), isNull);
      expect(resolveAuthRedirect(authState: signedIn(_user()), path: AppRoutes.dashboard), AppRoutes.onboarding);
      expect(resolveAuthRedirect(authState: signedIn(_user(onboarding: 'submitted')), path: AppRoutes.onboarding),
          AppRoutes.onboardingAwaiting);
    });
  });
}
