import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/employees/presentation/widgets/custom_fields_block.dart'
    show profileFieldConfigProvider;
import 'package:mobile_app/features/facial_recognition/domain/entities/face_verification_status_entity.dart';
import 'package:mobile_app/features/facial_recognition/presentation/providers/facial_recognition_providers.dart';
import 'package:mobile_app/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:mobile_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:mobile_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:mobile_app/features/profile/presentation/widgets/profile_header.dart';
import 'package:mobile_app/features/profile/presentation/widgets/profile_sections.dart';
import 'package:mobile_app/features/settings/data/models/onboarding_field_config_model.dart';

// Task 99: My Profile redesign + web parity (ProfileClient.tsx). All writes
// go to a fake server — nothing real is called.

class _SignedIn extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState(
        user: UserEntity(
          id: 'u1',
          email: 'pat@example.test',
          fullName: 'Pat Kumar',
          role: 'employee',
          roleDisplay: 'Employee',
          mustChangePassword: false,
          permissions: [],
          onboardingStatus: 'complete',
          assessmentStatus: 'complete',
        ),
      );
}

Map<String, dynamic> meJson({
  String name = 'Pat Kumar',
  String designation = 'Engineer',
  String department = 'Engineering',
  String? photo,
  Map<String, dynamic>? manager = const {'id': 'EMP-2', 'name': 'Morgan Lee'},
  Map<String, dynamic>? approver = const {'id': 'EMP-3', 'name': 'Asha Rao'},
  Map<String, dynamic>? hr = const {'id': 'EMP-4', 'name': 'Hema Iyer'},
}) =>
    {
      'id': 'u1',
      'full_name': name,
      'email': 'pat@example.test',
      'phone': '9000000000',
      'employee_id': 'EMP-7',
      'department': department,
      'designation': designation,
      'branch': 'Surat',
      'role_name': 'employee',
      'role_display': 'Employee',
      'date_of_joining': '2026-01-05',
      'date_joined': '2026-01-01T00:00:00Z',
      'onboarding_status': 'complete',
      'assessment_status': 'pending',
      'notice_period_days': 30,
      'reporting_manager': manager,
      'reporting_approver': approver,
      'hr': hr,
      'profile_photo_url': photo,
      'profile': {
        'date_of_birth': '1995-03-09',
        'gender': 'Female',
        'marital_status': 'Single',
        'father_name': 'R Kumar',
        'blood_group': 'O+',
        'current_address': '12 Park Road',
        'permanent_address': '9 Home Street',
        'highest_qualification': 'B.Tech',
        'institution': 'Test University',
        'year_of_passing': 2017,
        'specialization': 'CS',
        'total_experience_years': '4.5',
        'previous_employer': 'Acme',
        'previous_designation': 'Dev',
        'leaving_reason': 'Growth',
        'account_number': '123456789012',
        'ifsc_code': 'TEST0001234',
        'bank_name': 'Test Bank',
        'bank_branch_name': 'Main',
        'account_holder_name': 'Pat Kumar',
        'account_type': 'savings',
        'emergency_name': 'Sam Kumar',
        'emergency_relationship': 'Parent',
        'emergency_phone': '9111111111',
        'emergency_email': 'sam@example.test',
        'custom_field_values': <String, dynamic>{},
      },
    };

class _Server implements HttpClientAdapter {
  Map<String, dynamic> me = meJson();
  int meStatus = 200;
  int patchStatus = 200;
  String patchMessage = 'Profile updated.';
  final writes = <String>[];
  final bodies = <Map<String, dynamic>>[];

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? _) async {
    if (o.method != 'GET') writes.add('${o.method} ${o.path}');
    if (o.method == 'GET' && o.path == '/employees/me/') {
      if (meStatus != 200) return _json(meStatus, {'status': 'error', 'message': 'Server error.', 'data': {}});
      return _json(200, {'status': 'success', 'message': 'ok', 'data': me});
    }
    if (o.method == 'PATCH' && o.path == '/employees/me/') {
      if (patchStatus >= 400) return _json(patchStatus, {'status': 'error', 'message': patchMessage, 'data': {}});
      bodies.add(Map<String, dynamic>.from(o.data as Map));
      return _json(200, {'status': 'success', 'message': 'ok', 'data': {}});
    }
    if (o.method == 'POST' && o.path == '/employees/me/photo/') {
      await body?.drain<void>();
      return _json(200, {
        'status': 'success',
        'message': 'ok',
        'data': {'profile_photo_url': null},
      });
    }
    if (o.method == 'DELETE' && o.path == '/employees/me/photo/') {
      return _json(200, {'status': 'success', 'message': 'ok', 'data': {}});
    }
    return _json(404, {'status': 'error', 'message': 'Not found', 'data': {}});
  }

  @override
  void close({bool force = false}) {}
}

OnboardingFieldConfigModel _cfg(String key, int step, {bool visible = true}) => OnboardingFieldConfigModel(
      fieldKey: key,
      label: key,
      fieldType: 'text',
      options: const [],
      allowMultiple: false,
      step: step,
      order: 0,
      visible: visible,
      required: false,
      isCustom: false,
      isLocked: false,
    );

late _Server server; // ignore: library_private_types_in_public_api

/// Real GETs/PATCH through the fake server, but the photo upload is recorded
/// instead of reading a file into a multipart body.
class _Ds extends ProfileRemoteDataSource {
  _Ds(super.dio, this.server);
  final _Server server;
  @override
  Future<String?> uploadPhoto(File file) async {
    server.writes.add('POST /employees/me/photo/');
    return null;
  }
}

Future<void> pumpProfile(
  WidgetTester tester, {
  Size size = const Size(412, 900),
  double textScale = 1,
  Map<int, List<OnboardingFieldConfigModel>> config = const {},
  bool faceOn = true,
  Future<File?> Function(ImageSource)? picker,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server;
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      dioProvider.overrideWithValue(dio),
      profileDataSourceProvider.overrideWithValue(_Ds(dio, server)),
      authStateProvider.overrideWith(_SignedIn.new),
      profileFieldConfigProvider.overrideWith((ref) async => config),
      faceVerificationStatusProvider.overrideWith((ref) async => FaceVerificationStatusEntity(isMandatory: faceOn)),
      if (picker != null) profilePhotoPickerProvider.overrideWithValue(picker),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const ProfileScreen(),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> openTab(WidgetTester tester, String tab) async {
  final f = find.byKey(ValueKey('profile-tab-$tab'));
  // On a short screen the strip starts below the fold: scroll until it pins.
  for (var i = 0; i < 6 && f.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -250));
    await tester.pump();
  }
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// The text shown under [label] in a read-only field.
Finder valueUnder(String label, String value) => find.descendant(
    of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first, matching: find.text(value));

TextField fieldLabelled(WidgetTester tester, String label) {
  final col = find.ancestor(of: find.text(label), matching: find.byType(Column)).first;
  return tester.widget<TextField>(find.descendant(of: col, matching: find.byType(TextField)).first);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => server = _Server());

  group('pure helpers', () {
    test('web date format (en-IN "5 Nov 2026")', () {
      expect(formatProfileDate('2026-11-05'), '5 Nov 2026');
      expect(formatProfileDate('2026-01-05T00:00:00Z'), '5 Jan 2026');
      expect(formatProfileDate('2026-09-05'), '5 Sept 2026'); // web en-IN writes "Sept"
      expect(formatProfileDate(null), '—');
      expect(formatProfileDate(''), '—');
      expect(formatProfileDate('not-a-date'), 'not-a-date');
    });

    test('bank account masking keeps the last 4 digits only', () {
      expect(maskedAccountNumber('123456789012'), '••••9012');
      expect(maskedAccountNumber('123'), '••••123');
      expect(maskedAccountNumber(''), '—');
    });

    test('photo rules use web wording', () {
      expect(profilePhotoSizeError(150 * 1024), isNull);
      expect(profilePhotoSizeError(100 * 1024), isNull);
      expect(profilePhotoSizeError(200 * 1024), isNull);
      expect(profilePhotoSizeError(50 * 1024), 'Image must be between 100 KB and 200 KB (selected file is 50 KB).');
      expect(profilePhotoSizeError(201 * 1024), 'Image must be between 100 KB and 200 KB (selected file is 201 KB).');
      expect(profilePhotoTypeError('/x/a.JPG'), isNull);
      expect(profilePhotoTypeError('/x/a.jpeg'), isNull);
      expect(profilePhotoTypeError('/x/a.png'), isNull);
      expect(profilePhotoTypeError('/x/a.gif'), 'Only JPG, JPEG, and PNG files are allowed.');
    });
  });

  group('identity header', () {
    testWidgets('name, role line, ID, branch, joined date and assigned people', (tester) async {
      await pumpProfile(tester);
      expect(find.text('Pat Kumar'), findsWidgets); // header + Full Name
      expect(find.text('Engineer · Engineering'), findsOneWidget);
      expect(find.text('EMP-7'), findsOneWidget);
      expect(find.text('Surat'), findsOneWidget);
      expect(find.text('Joined 5 Jan 2026'), findsOneWidget);
      expect(find.textContaining('Reporting Manager: Morgan Lee', findRichText: true), findsOneWidget);
      expect(find.textContaining('Reporting Approver: Asha Rao', findRichText: true), findsOneWidget);
      expect(find.textContaining('Assigned HR: Hema Iyer', findRichText: true), findsOneWidget);
      expect(find.text('PK'), findsOneWidget); // initials fallback, no photo
    });

    testWidgets('no designation/department → role; unassigned people are left out', (tester) async {
      server.me = meJson(designation: '', department: '', manager: null, approver: null, hr: null);
      await pumpProfile(tester);
      expect(find.text('Employee'), findsWidgets);
      expect(find.textContaining('Reporting Manager:', findRichText: true), findsNothing);
      expect(find.textContaining('Assigned HR:', findRichText: true), findsNothing);
    });

    testWidgets('a broken photo link falls back to initials without an error', (tester) async {
      server.me = meJson(photo: 'https://files.invalid/me.jpg');
      await pumpProfile(tester);
      expect(find.text('PK'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('tabs (web section list)', () {
    testWidgets('every web section is reachable; the default is Personal', (tester) async {
      await pumpProfile(tester);
      for (final t in ['personal', 'work', 'education', 'bank', 'documents', 'face', 'security']) {
        expect(find.byKey(ValueKey('profile-tab-$t')), findsOneWidget, reason: t);
      }
      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Work Information'), findsNothing);
      await openTab(tester, 'work');
      expect(find.text('Work Information'), findsOneWidget);
      expect(find.text('Personal Information'), findsNothing);
    });

    testWidgets('Face ID tab is hidden when the feature is switched off', (tester) async {
      await pumpProfile(tester, faceOn: false);
      expect(find.byKey(const ValueKey('profile-tab-face')), findsNothing);
      expect(find.byKey(const ValueKey('profile-tab-security')), findsOneWidget);
    });

    testWidgets('Save is on the Personal tab only (as on web)', (tester) async {
      await pumpProfile(tester);
      expect(find.text('Save Changes'), findsOneWidget);
      await openTab(tester, 'bank');
      expect(find.text('Save Changes'), findsNothing);
      await openTab(tester, 'personal');
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets('no HR-only controls leak into self-service', (tester) async {
      await pumpProfile(tester);
      for (final tab in ['personal', 'work', 'education', 'bank']) {
        await openTab(tester, tab);
        for (final hr in ['Salary', 'Payroll', 'Assets', 'ID Card', 'Edit Employee', 'Deactivate']) {
          expect(find.textContaining(hr), findsNothing, reason: '$tab shows $hr');
        }
      }
    });
  });

  group('field labels and values (web ProfileClient)', () {
    testWidgets('Personal tab', (tester) async {
      await pumpProfile(tester);
      expect(valueUnder('Full Name', 'Pat Kumar'), findsOneWidget);
      expect(valueUnder('Email', 'pat@example.test'), findsOneWidget);
      expect(valueUnder('Date of Birth', '9 Mar 1995'), findsOneWidget);
      expect(valueUnder('Gender', 'Female'), findsOneWidget);
      expect(valueUnder('Marital Status', 'Single'), findsOneWidget);
      expect(valueUnder('Blood Group', 'O+'), findsOneWidget);
      expect(valueUnder("Father's Name", 'R Kumar'), findsOneWidget);
      expect(fieldLabelled(tester, 'Phone').controller!.text, '9000000000');
      expect(fieldLabelled(tester, 'Current Address').controller!.text, '12 Park Road');
      expect(fieldLabelled(tester, 'Name').controller!.text, 'Sam Kumar');
      expect(fieldLabelled(tester, 'Relationship').controller!.text, 'Parent');
    });

    testWidgets('Work tab keeps assessment/onboarding badges and "Not assigned"', (tester) async {
      server.me = meJson(hr: null);
      await pumpProfile(tester);
      await openTab(tester, 'work');
      expect(find.text('Complete'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(valueUnder('HR', 'Not assigned'), findsOneWidget);
      expect(valueUnder('Notice Period', '30 days'), findsOneWidget);
      expect(valueUnder('Date of Joining', '5 Jan 2026'), findsOneWidget);
      expect(find.byType(TextField), findsNothing); // read-only
    });

    testWidgets('Education tab uses web labels and order', (tester) async {
      await pumpProfile(tester);
      await openTab(tester, 'education');
      for (final (l, v) in [
        ('Qualification', 'B.Tech'),
        ('Institution', 'Test University'),
        ('Year of Passing', '2017'),
        ('Specialization', 'CS'),
        ('Experience (yrs)', '4.5'),
        ('Previous Employer', 'Acme'),
        ('Previous Role', 'Dev'),
        ('Leaving Reason', 'Growth'),
      ]) {
        expect(valueUnder(l, v), findsOneWidget, reason: l);
      }
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('Bank tab masks the account number and says to contact HR', (tester) async {
      await pumpProfile(tester);
      await openTab(tester, 'bank');
      expect(valueUnder('Account Number', '••••9012'), findsOneWidget);
      expect(find.textContaining('123456789012'), findsNothing);
      expect(find.textContaining('56789012'), findsNothing);
      expect(find.text('Contact HR to update'), findsOneWidget);
      expect(valueUnder('Bank Name', 'Test Bank'), findsOneWidget);
      expect(valueUnder('Account Holder', 'Pat Kumar'), findsOneWidget);
      expect(valueUnder('IFSC Code', 'TEST0001234'), findsOneWidget);
      expect(valueUnder('Bank Branch', 'Main'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('empty values show the "—" placeholder', (tester) async {
      server.me = meJson()..['profile'] = <String, dynamic>{};
      await pumpProfile(tester);
      expect(valueUnder('Date of Birth', '—'), findsOneWidget);
      expect(valueUnder("Father's Name", '—'), findsOneWidget);
      await openTab(tester, 'bank');
      expect(valueUnder('Account Number', '—'), findsOneWidget);
    });
  });

  group('field visibility configuration', () {
    testWidgets('hidden built-in fields disappear; the rest stay', (tester) async {
      await pumpProfile(tester, config: {
        0: [_cfg('date_of_birth', 0, visible: false), _cfg('current_address', 0, visible: false)],
        3: [_cfg('emergency_phone', 3, visible: false)],
      });
      expect(find.text('Date of Birth'), findsNothing);
      expect(find.text('Gender'), findsOneWidget);
      expect(find.text('Current Address'), findsNothing);
      expect(find.text('Permanent Address'), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Relationship'), findsOneWidget);
      expect(find.text('Email'), findsWidgets);
      // Emergency "Phone" gone, the profile "Phone" stays (identity field).
      expect(find.text('Phone'), findsOneWidget);
    });

    testWidgets('hiding both addresses drops the Address card', (tester) async {
      await pumpProfile(tester, config: {
        0: [_cfg('current_address', 0, visible: false), _cfg('permanent_address', 0, visible: false)],
      });
      expect(find.text('Address'), findsNothing);
    });

    testWidgets('education and bank fields follow the config', (tester) async {
      await pumpProfile(tester, config: {
        1: [_cfg('institution', 1, visible: false)],
        2: [
          _cfg('bank_name', 2, visible: false),
          _cfg('account_number', 2, visible: false),
          _cfg('ifsc_code', 2, visible: false),
        ],
      });
      await openTab(tester, 'education');
      expect(find.text('Institution'), findsNothing);
      expect(find.text('Qualification'), findsOneWidget);
      await openTab(tester, 'bank');
      expect(find.text('Account Number'), findsNothing);
      expect(find.text('IFSC Code'), findsNothing);
      expect(find.text('Bank Name'), findsNothing);
      expect(find.text('Account Holder'), findsOneWidget);
      expect(find.textContaining('9012'), findsNothing);
    });

    testWidgets('a hidden field keeps its value in the save payload', (tester) async {
      await pumpProfile(tester, config: {
        0: [_cfg('current_address', 0, visible: false)],
      });
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(server.bodies.single['current_address'], '12 Park Road');
    });
  });

  group('edit, save and discard', () {
    testWidgets('save sends exactly the editable fields, then confirms', (tester) async {
      await pumpProfile(tester);
      await tester.enterText(find.byType(TextField).first, ' 9876543210 ');
      await tester.pump();
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(server.writes, ['PATCH /employees/me/']);
      expect(server.bodies.single, {
        'phone': '9876543210',
        'current_address': '12 Park Road',
        'permanent_address': '9 Home Street',
        'emergency_name': 'Sam Kumar',
        'emergency_relationship': 'Parent',
        'emergency_phone': '9111111111',
        'emergency_email': 'sam@example.test',
      });
      expect(find.text('Profile updated successfully.'), findsOneWidget);
    });

    testWidgets('a server rejection shows its message and nothing is "saved"', (tester) async {
      server
        ..patchStatus = 400
        ..patchMessage = 'Enter a valid phone number.';
      await pumpProfile(tester);
      await tester.enterText(find.byType(TextField).first, '9876543210');
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid phone number.'), findsOneWidget);
      expect(find.text('Profile updated successfully.'), findsNothing);
    });

    testWidgets('invalid phone / emergency email are caught before any request', (tester) async {
      await pumpProfile(tester);
      await tester.enterText(find.byType(TextField).first, 'abc');
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(server.writes, isEmpty);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('Discard is disabled until something changes, then restores the saved values', (tester) async {
      await pumpProfile(tester);
      OutlinedButton discard() => tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Discard'));
      expect(discard().onPressed, isNull);
      await tester.enterText(find.byType(TextField).first, '1111111111');
      await tester.pump();
      expect(discard().onPressed, isNotNull);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(fieldLabelled(tester, 'Phone').controller!.text, '9000000000');
      expect(discard().onPressed, isNull);
      expect(server.writes, isEmpty);
    });

    testWidgets('switching tabs keeps unsaved edits', (tester) async {
      await pumpProfile(tester);
      await tester.enterText(find.byType(TextField).first, '2222222222');
      await openTab(tester, 'work');
      await openTab(tester, 'personal');
      expect(fieldLabelled(tester, 'Phone').controller!.text, '2222222222');
    });
  });

  group('security tab (web ChangePasswordForm)', () {
    Future<String> attempt(WidgetTester tester, {String cur = '', String nw = '', String cfm = ''}) async {
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), cur);
      await tester.enterText(fields.at(1), nw);
      await tester.enterText(fields.at(2), cfm);
      await tester.tap(find.text('Update password'));
      await tester.pump();
      final snack = tester.widget<SnackBar>(find.byType(SnackBar));
      final text = ((snack.content) as Text).data!;
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold))).clearSnackBars();
      await tester.pumpAndSettle();
      return text;
    }

    testWidgets('web labels, messages and validation order', (tester) async {
      await pumpProfile(tester);
      await openTab(tester, 'security');
      for (final l in ['Current password', 'New password', 'Confirm new password']) {
        expect(find.text(l), findsWidgets, reason: l); // label (+ hint)
      }
      expect(await attempt(tester), 'Enter your current password.');
      expect(await attempt(tester, cur: 'old'), 'Enter a new password.');
      expect(await attempt(tester, cur: 'old', nw: 'a', cfm: 'b'), 'New passwords do not match.');
      expect(await attempt(tester, cur: 'same', nw: 'same', cfm: 'same'),
          'New password must differ from the current one.');
      expect(server.writes, isEmpty);
    });

    testWidgets('password fields can be shown and hidden', (tester) async {
      await pumpProfile(tester);
      await openTab(tester, 'security');
      bool obscured() => tester.widget<TextField>(find.byType(TextField).first).obscureText;
      expect(obscured(), isTrue);
      await tester.tap(find.byTooltip('Show password').first);
      await tester.pump();
      expect(obscured(), isFalse);
      await tester.tap(find.byTooltip('Hide password').first);
      await tester.pump();
      expect(obscured(), isTrue);
    });
  });

  group('profile photo', () {
    Future<File> tempFile(WidgetTester tester, String name, int bytes) async {
      late File f;
      await tester.runAsync(() async {
        f = File('${Directory.systemTemp.createTempSync('t99').path}/$name')..writeAsBytesSync(List.filled(bytes, 1));
      });
      addTearDown(() {
        try {
          f.parent.deleteSync(recursive: true);
        } catch (_) {}
      });
      return f;
    }

    Future<void> choose(WidgetTester tester, String option) async {
      await tester.tap(find.byKey(const ValueKey('profile-photo-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(option));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
    }

    testWidgets('too small / too large / wrong type are refused with web wording and nothing is sent', (tester) async {
      final small = await tempFile(tester, 'a.jpg', 50 * 1024);
      final big = await tempFile(tester, 'b.png', 250 * 1024);
      final gif = await tempFile(tester, 'c.gif', 150 * 1024);
      final queue = [small, big, gif];
      await pumpProfile(tester, picker: (_) async => queue.removeAt(0));
      await choose(tester, 'Upload from Device');
      expect(find.text('Image must be between 100 KB and 200 KB (selected file is 50 KB).'), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold))).clearSnackBars();
      await tester.pumpAndSettle();
      await choose(tester, 'Upload from Device');
      expect(find.text('Image must be between 100 KB and 200 KB (selected file is 250 KB).'), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold))).clearSnackBars();
      await tester.pumpAndSettle();
      await choose(tester, 'Upload from Device');
      expect(find.text('Only JPG, JPEG, and PNG files are allowed.'), findsOneWidget);
      expect(server.writes, isEmpty);
    });

    testWidgets('a valid photo is uploaded (mock) and confirmed', (tester) async {
      final ok = await tempFile(tester, 'me.jpg', 150 * 1024);
      await pumpProfile(tester, picker: (_) async => ok);
      await choose(tester, 'Capture Photo');
      expect(server.writes, ['POST /employees/me/photo/']);
      expect(find.text('Profile photo updated.'), findsOneWidget);
    });

    testWidgets('cancelling the picker changes nothing', (tester) async {
      await pumpProfile(tester, picker: (_) async => null);
      await choose(tester, 'Upload from Device');
      expect(server.writes, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('"Remove Current Photo" is offered only when there is a photo, and calls DELETE', (tester) async {
      await pumpProfile(tester);
      await tester.tap(find.byKey(const ValueKey('profile-photo-button')));
      await tester.pumpAndSettle();
      expect(find.text('Remove Current Photo'), findsNothing);
      await tester.tapAt(const Offset(10, 10)); // dismiss
      await tester.pumpAndSettle();

      server.me = meJson(photo: 'https://files.invalid/me.jpg');
      await pumpProfile(tester);
      await tester.tap(find.byKey(const ValueKey('profile-photo-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove Current Photo'));
      await tester.pumpAndSettle();
      expect(server.writes, ['DELETE /employees/me/photo/']);
      expect(find.text('Profile photo removed.'), findsOneWidget);
      expect(find.text('PK'), findsOneWidget);
    });
  });

  group('loading, error and retry', () {
    testWidgets('a failed load shows a retry; retry recovers', (tester) async {
      server.meStatus = 500;
      await pumpProfile(tester);
      expect(find.text('Personal Information'), findsNothing);
      expect(find.textContaining('Server error'), findsOneWidget);
      server.meStatus = 200;
      await tester.tap(find.textContaining('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Personal Information'), findsOneWidget);
    });

    testWidgets('a spinner shows while the profile loads', (tester) async {
      tester.view.physicalSize = const Size(412, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server;
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [dioProvider.overrideWithValue(dio), authStateProvider.overrideWith(_SignedIn.new)],
        child: const MaterialApp(home: ProfileScreen()),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });

  group('responsive layout', () {
    const tabs = ['personal', 'work', 'education', 'bank', 'documents', 'face', 'security'];

    Future<void> everyTab(WidgetTester tester) async {
      for (final t in tabs) {
        await openTab(tester, t);
        expect(tester.takeException(), isNull, reason: 'tab $t');
      }
    }

    testWidgets('small phone (320×568) — no overflow on any tab', (tester) async {
      server.me = meJson(name: 'Alexandria Wilhelmina Montgomery-Featherstonehaugh');
      await pumpProfile(tester, size: const Size(320, 568));
      await everyTab(tester);
    });

    testWidgets('small phone with very large system text (2.0×)', (tester) async {
      server.me = meJson(name: 'Alexandria Wilhelmina Montgomery-Featherstonehaugh');
      await pumpProfile(tester, size: const Size(320, 568), textScale: 2);
      await everyTab(tester);
    });

    testWidgets('typical phone with large text (1.5×)', (tester) async {
      await pumpProfile(tester, textScale: 1.5);
      await everyTab(tester);
    });

    testWidgets('long values wrap instead of being cut', (tester) async {
      const long = 'Bachelor of Technology in Computer Science and Engineering with Honours, Specialisation in AI';
      server.me = meJson()..['profile']['institution'] = long;
      await pumpProfile(tester, size: const Size(320, 568));
      await openTab(tester, 'education');
      expect(find.text(long), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('narrow width or large text stacks field pairs; roomy width keeps them side by side', (tester) async {
      Future<(Offset, Offset)> pair() async {
        await tester.scrollUntilVisible(find.text('Full Name'), 200, scrollable: find.byType(Scrollable).first);
        return (tester.getTopLeft(find.text('Full Name')), tester.getTopLeft(find.text('Email').first));
      }

      await pumpProfile(tester);
      var (a, b) = await pair();
      expect(a.dy, b.dy); // side by side
      await pumpProfile(tester, textScale: 1.6);
      (a, b) = await pair();
      expect(b.dy, greaterThan(a.dy)); // stacked
      await pumpProfile(tester, size: const Size(280, 800));
      (a, b) = await pair();
      expect(b.dy, greaterThan(a.dy));
    });

    testWidgets('tablet (1000×800) keeps content to a readable width', (tester) async {
      await pumpProfile(tester, size: const Size(1000, 800));
      await everyTab(tester);
      await openTab(tester, 'personal');
      final card =
          tester.getSize(find.ancestor(of: find.text('Personal Information'), matching: find.byType(Container)).first);
      expect(card.width, lessThanOrEqualTo(760));
    });

    testWidgets('keyboard open: the Save bar steps aside and every field stays reachable', (tester) async {
      await pumpProfile(tester, size: const Size(360, 640));
      expect(find.text('Save Changes'), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(find.text('Save Changes'), findsNothing);
      await tester.scrollUntilVisible(find.text('email@example.com'), 200, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.text('email@example.com'), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets('the Save bar fits a small screen with large text', (tester) async {
      await pumpProfile(tester, size: const Size(320, 568), textScale: 2);
      expect(tester.takeException(), isNull);
      final save = tester.getRect(find.widgetWithText(FilledButton, 'Save Changes'));
      expect(save.right, lessThanOrEqualTo(320));
      expect(save.bottom, lessThanOrEqualTo(568));
    });
  });
}
