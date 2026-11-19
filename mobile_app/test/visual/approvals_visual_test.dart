import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/employees/presentation/widgets/custom_fields_block.dart'
    show profileFieldConfigProvider;
import 'package:mobile_app/features/facial_recognition/domain/entities/face_verification_status_entity.dart';
import 'package:mobile_app/features/facial_recognition/presentation/providers/facial_recognition_providers.dart';
import 'package:mobile_app/features/profile/presentation/screens/profile_screen.dart';

import 'shot_harness.dart';

// Task 101.1 — render evidence. Run with T1011_SHOTS=1 to write PNGs to
// docs/qa/client_handover_2026-11-19/evidence/t1011/. Without it these tests do
// nothing (they are skipped), so the normal suite writes no files.

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

const _me = {
  'id': 'u1',
  'full_name': 'Priya Natarajan',
  'email': 'priya.n@example.test',
  'phone': '9876501234',
  'employee_id': 'EMP-0042',
  'department': 'Engineering',
  'designation': 'Senior Engineer',
  'branch': 'Surat',
  'role_name': 'employee',
  'role_display': 'Employee',
  'date_of_joining': '2024-01-15',
  'date_joined': '2024-01-15T00:00:00Z',
  'onboarding_status': 'complete',
  'assessment_status': 'complete',
  'notice_period_days': 30,
  'reporting_manager': {'id': 'EMP-0007', 'name': 'Morgan Lee'},
  'reporting_approver': {'id': 'EMP-0003', 'name': 'Asha Rao'},
  'hr': {'id': 'EMP-0004', 'name': 'Hema Iyer'},
  'profile_photo_url': null,
  'profile': {
    'date_of_birth': '1993-03-09',
    'gender': 'Female',
    'marital_status': 'Single',
    'father_name': 'R Natarajan',
    'blood_group': 'O+',
    'current_address': '12 Park Road, Surat',
    'permanent_address': '9 Home Street, Chennai',
    'emergency_name': 'Sam Natarajan',
    'emergency_relationship': 'Parent',
    'emergency_phone': '9111111111',
    'emergency_email': 'sam@example.test',
    'custom_field_values': <String, dynamic>{},
  },
};

class _Server implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    final body = o.path == '/employees/me/'
        ? {'status': 'success', 'message': 'ok', 'data': _me}
        : {'status': 'success', 'data': {}};
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('reference: My Profile (Task 99)', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(loadShotFonts);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authStateProvider.overrideWith(_SignedIn.new),
        dioProvider
            .overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = _Server()),
        profileFieldConfigProvider.overrideWith((ref) async => const {}),
        faceVerificationStatusProvider
            .overrideWith((ref) async => const FaceVerificationStatusEntity(isMandatory: true)),
      ],
      child: shotFrame(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(appBar: shotAppBar('My Profile'), body: const ProfileScreen()),
      )),
    ));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    await shoot(tester, '00_my_profile_reference');
  }, skip: !shotsEnabled);
}
