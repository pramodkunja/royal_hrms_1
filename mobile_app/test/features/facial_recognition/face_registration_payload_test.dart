import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/features/facial_recognition/data/datasources/facial_recognition_remote_datasource.dart';

// Registration requests carry the 128-d descriptor in face_embedding plus, as
// web (useFaceRegistrationCapture / useHRFaceRegistration), how many frames
// were averaged and their mean pairwise distance. Stand-in server only.

class Recorder implements HttpClientAdapter {
  final bodies = <String, Map<String, dynamic>>{};
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    bodies[o.path] = Map<String, dynamic>.from(o.data as Map);
    return ResponseBody.fromString(
        jsonEncode({
          'status': 'success',
          'data': {'id': 'r1', 'status': 'pending'},
        }),
        201,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  final descriptor = List<double>.generate(128, (i) => i / 1000);

  test('self registration: 128 values in face_embedding + capture_frame_count / capture_variance', () async {
    final rec = Recorder();
    final ds =
        FacialRecognitionRemoteDataSource(Dio(BaseOptions(baseUrl: 'https://t.invalid/api'))..httpClientAdapter = rec);
    await ds.submitRegistration(
      faceEmbedding: descriptor,
      livenessPassed: true,
      livenessScore: 0.9,
      consentAcknowledged: true,
      captureFrameCount: 4,
      captureVariance: 0.12,
    );
    final body = rec.bodies[ApiConstants.faceRegistrationSubmit]!;
    expect((body['face_embedding'] as List), hasLength(128));
    expect(body['capture_frame_count'], 4);
    expect(body['capture_variance'], 0.12);
    expect(body['liveness_passed'], isTrue);
    expect(body['consent_acknowledged'], isTrue);
  });

  test('HR-assisted registration: same fields plus employee_uuid; omitted when not measured', () async {
    final rec = Recorder();
    final ds =
        FacialRecognitionRemoteDataSource(Dio(BaseOptions(baseUrl: 'https://t.invalid/api'))..httpClientAdapter = rec);
    await ds.hrRegister(
      employeeUuid: 'e-uuid',
      faceEmbedding: descriptor,
      livenessPassed: true,
      consentAcknowledged: true,
      captureFrameCount: 4,
      captureVariance: 0.08,
    );
    final body = rec.bodies[ApiConstants.faceRegistrationHrRegister]!;
    expect(body['employee_uuid'], 'e-uuid');
    expect((body['face_embedding'] as List), hasLength(128));
    expect([body['capture_frame_count'], body['capture_variance']], [4, 0.08]);

    await ds.submitRegistration(faceEmbedding: descriptor, livenessPassed: true, consentAcknowledged: true);
    final bare = rec.bodies[ApiConstants.faceRegistrationSubmit]!;
    expect(bare.containsKey('capture_frame_count'), isFalse);
    expect(bare.containsKey('capture_variance'), isFalse);
  });
}
