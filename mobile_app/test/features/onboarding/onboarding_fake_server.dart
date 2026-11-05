import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:mobile_app/core/constants/api_constants.dart';

// A stand-in for the production onboarding API (apps/accounts/views.py,
// origin/production), applying its rules:
//  - GET /onboarding/field-config/ — every field, grouped by step;
//  - GET /onboarding/document-type-config/ — every document type;
//  - PATCH /onboarding/step/<n>/ keeps only that step's configured keys,
//    skips file-type keys, stores custom values as given; serializer
//    refusals come back 422 with per-field errors in `data`;
//  - POST/DELETE /onboarding/custom-file-fields/ — PDF/JPG/PNG by content
//    type, at most 5 MB, a single-file field replaces its previous file;
//  - POST /onboarding/documents/ — the type must be a visible config row;
//    a non-multiple type replaces its previous file;
//  - POST /onboarding/ — refuses while required visible fields, required
//    file fields or required documents are missing.

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

ResponseBody _ok(String message, Object? data) => _json(200, {'status': 'success', 'message': message, 'data': data});

ResponseBody _fail(int status, String message, [Object? data]) =>
    _json(status, {'status': 'error', 'message': message, 'data': data ?? {}});

Map<String, dynamic> field(String key, String label, int step, int order,
        {String type = 'text',
        bool required = false,
        bool visible = true,
        bool custom = false,
        bool multiple = false,
        List<String> options = const []}) =>
    {
      'field_key': key,
      'label': label,
      'field_type': type,
      'options': options,
      'allow_multiple': multiple,
      'step': step,
      'order': order,
      'visible': visible,
      'required': required,
      'is_custom': custom,
      'is_locked': false,
      'updated_at': '2026-11-01T10:00:00Z',
    };

Map<String, dynamic> docType(String key, String label, int order,
        {bool required = false, bool visible = true, bool multiple = false}) =>
    {
      'type_key': key,
      'label': label,
      'order': order,
      'visible': visible,
      'required': required,
      'allow_multiple': multiple,
      'is_custom': false,
      'is_locked': false,
    };

const _allowedMime = {'application/pdf', 'image/jpeg', 'image/png'};
const _maxBytes = 5 * 1024 * 1024;

class FakeOnboardingServer implements HttpClientAdapter {
  FakeOnboardingServer({
    required this.fields,
    required this.docTypes,
    Map<String, Object?>? profile,
    this.completedSteps = const [],
  }) : profile = {...?profile};

  final List<Map<String, dynamic>> fields;
  final List<Map<String, dynamic>> docTypes;
  final Map<String, Object?> profile; // built-in values
  final custom = <String, Object?>{}; // custom_field_values
  List<int> completedSteps;
  final customFiles = <Map<String, dynamic>>[];
  final documents = <Map<String, dynamic>>[];
  bool submitted = false;

  /// PANs already registered to another employee (409 on save).
  final takenPans = <String>{};

  /// The next PATCH /onboarding/step/4/ fails with no response.
  bool dropNextStep4 = false;

  /// The next document upload is refused (500).
  bool failNextDocumentUpload = false;

  /// The next GET /onboarding/ fails (500).
  bool failNextProfile = false;

  /// When set, GET /onboarding/ waits for it before answering.
  Completer<void>? holdProfile;

  bool failConfig = false;

  /// The next custom-file upload / removal fails with no response at all
  /// (offline), as a real connection failure does.
  bool dropNextCustomFileUpload = false;
  bool dropNextCustomFileDelete = false;

  /// The next custom-file upload is refused with this status and message;
  /// a null message gives a bare non-JSON body (e.g. a proxy's 502 page).
  ({int status, String? message})? refuseNextCustomFileUpload;

  /// When set, the next custom-file upload waits for it before answering.
  Completer<void>? holdNextCustomFileUpload;

  /// field_key → serializer message returned (422) when that key is saved
  /// with a non-empty value.
  final rejections = <String, String>{};

  int _nextId = 100;
  final calls = <({String method, String path, Object? body})>[];

  int count(String method, String path) => calls.where((c) => c.method == method && c.path == path).length;

  List<Map<String, dynamic>> _stepFields(int step) => fields.where((f) => f['step'] == step).toList();

  Map<String, dynamic>? _field(String key) {
    for (final f in fields) {
      if (f['field_key'] == key) return f;
    }
    return null;
  }

  Object? valueOf(String key) => _field(key)?['is_custom'] == true ? custom[key] : profile[key];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add((method: o.method, path: o.path, body: o.data));
    final p = o.path;
    final m = o.method;

    if (p == ApiConstants.onboardingFieldConfig && m == 'GET') {
      if (failConfig) return _fail(500, 'Server error.');
      final byStep = <String, List<Map<String, dynamic>>>{};
      for (final f in fields) {
        byStep.putIfAbsent('${f['step']}', () => []).add(f);
      }
      return _ok('Field configuration retrieved.', byStep);
    }
    if (p == ApiConstants.onboardingDocumentTypeConfig && m == 'GET') {
      if (failConfig) return _fail(500, 'Server error.');
      return _ok('Document types retrieved.', docTypes);
    }
    if (p == ApiConstants.onboardingProfile && m == 'GET') {
      if (holdProfile != null) await holdProfile!.future;
      if (failNextProfile) {
        failNextProfile = false;
        return _fail(500, 'Server error.');
      }
      return _ok('Profile retrieved.', {
        ...profile,
        'custom_field_values': custom,
        'completed_steps': completedSteps,
      });
    }
    if (p == ApiConstants.onboardingDocuments && m == 'GET') {
      return _ok('Documents retrieved.', documents);
    }
    if (p == ApiConstants.onboardingCustomFileFields && m == 'GET') {
      return _ok('Files retrieved.', customFiles);
    }
    if (p == ApiConstants.onboardingCustomFileFields && m == 'POST') {
      final gate = holdNextCustomFileUpload;
      if (gate != null) {
        holdNextCustomFileUpload = null;
        await gate.future;
      }
      if (dropNextCustomFileUpload) {
        dropNextCustomFileUpload = false;
        throw DioException(
            requestOptions: o, type: DioExceptionType.connectionError, message: 'SocketException: Failed host lookup');
      }
      final refusal = refuseNextCustomFileUpload;
      if (refusal != null) {
        refuseNextCustomFileUpload = null;
        final message = refusal.message;
        return message == null
            ? ResponseBody.fromString('<html><body>502 Bad Gateway</body></html>', refusal.status, headers: {
                Headers.contentTypeHeader: ['text/html'],
              })
            : _fail(refusal.status, message);
      }
      return _uploadCustomFile(o.data as FormData);
    }
    if (p.startsWith(ApiConstants.onboardingCustomFileFields) && m == 'DELETE') {
      if (dropNextCustomFileDelete) {
        dropNextCustomFileDelete = false;
        throw DioException(requestOptions: o, type: DioExceptionType.connectionTimeout, message: 'Connection timed out');
      }
      final id = int.parse(p.split('/').where((s) => s.isNotEmpty).last);
      final before = customFiles.length;
      customFiles.removeWhere((f) => f['id'] == id);
      return before == customFiles.length ? _fail(404, 'File not found.') : _ok('File removed.', null);
    }
    if (p == ApiConstants.onboardingDocuments && m == 'POST') {
      if (failNextDocumentUpload) {
        failNextDocumentUpload = false;
        return _fail(500, 'Upload failed. Please try again.');
      }
      return _uploadDocument(o.data as FormData);
    }
    final step = RegExp(r'^/onboarding/step/(\d+)/$').firstMatch(p);
    if (step != null && step.group(1) == '4' && dropNextStep4) {
      dropNextStep4 = false;
      throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
    }
    if (step != null && m == 'PATCH') {
      return _saveStep(int.parse(step.group(1)!), (o.data as Map).cast());
    }
    if (p == ApiConstants.onboardingProfile && m == 'POST') return _submit();
    return _fail(404, 'Not found: $m $p');
  }

  ResponseBody _saveStep(int step, Map<String, dynamic> body) {
    if (step == 4) return _saveStep4(body);
    final keys = {for (final f in _stepFields(step)) f['field_key'] as String};
    final errors = <String, List<String>>{};
    body.forEach((k, v) {
      if (!keys.contains(k) || _field(k)!['field_type'] == 'file') return;
      if (rejections.containsKey(k) && '$v'.isNotEmpty) errors[k] = [rejections[k]!];
    });
    if (errors.isNotEmpty) return _fail(422, errors.values.first.first, errors);
    body.forEach((k, v) {
      if (!keys.contains(k) || _field(k)!['field_type'] == 'file') return;
      if (_field(k)!['is_custom'] == true) {
        custom[k] = v;
      } else {
        profile[k] = (v == '' || v == null) ? null : v;
      }
    });
    completedSteps = {...completedSteps, step}.toList();
    return _ok('Profile saved.', {for (final k in keys) k: valueOf(k)});
  }

  // _save_profile_step, step == 4 (production).
  ResponseBody _saveStep4(Map<String, dynamic> body) {
    if (body.containsKey('pan_number')) {
      final raw = '${body['pan_number'] ?? ''}'.trim();
      if (raw.isEmpty) return _fail(400, 'PAN number is required.');
      final pan = raw.toUpperCase();
      if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(pan)) {
        return _fail(400, 'Enter a valid PAN (e.g. ABCDE1234F) — 5 letters, 4 digits, 1 letter.');
      }
      if (takenPans.contains(pan)) {
        return _fail(409, 'This PAN is already registered to [Employee Name] ([Employee ID]).');
      }
      profile['pan_number'] = pan;
      return _ok('PAN number saved.', {'pan_number': pan});
    }
    final missing = [
      for (final t in docTypes)
        if (t['visible'] == true && t['required'] == true && !documents.any((d) => d['document_type'] == t['type_key']))
          t['label'],
    ];
    if (missing.isNotEmpty) {
      return _fail(422, 'Please upload the following required documents: ${missing.join(', ')}.');
    }
    return _ok('Documents verified. You can proceed to submit.', null);
  }

  String? _checkFile(MultipartFile file) {
    if (file.length <= 0) return 'Uploaded file is empty.';
    final type = file.contentType?.mimeType;
    if (!_allowedMime.contains(type)) return 'Only PDF, JPG, and PNG files are allowed.';
    if (file.length > _maxBytes) return 'File size exceeds the 5 MB limit.';
    return null;
  }

  ResponseBody _uploadCustomFile(FormData form) {
    final key = form.fields.firstWhere((e) => e.key == 'field_key').value;
    final file = form.files.firstWhere((e) => e.key == 'file').value;
    final f = _field(key);
    if (f == null || f['field_type'] != 'file') return _fail(400, 'Unknown file field.');
    final problem = _checkFile(file);
    if (problem != null) return _fail(400, problem);
    if (f['allow_multiple'] != true) customFiles.removeWhere((e) => e['field_key'] == key);
    final row = {
      'id': _nextId++,
      'field_key': key,
      'file_url': 'https://files.invalid/$key/${file.filename}',
      'file_name': file.filename,
      'file_size': file.length,
      'uploaded_at': '2026-11-03T10:00:00Z',
    };
    customFiles.add(row);
    return _json(201, {'status': 'success', 'message': 'File uploaded.', 'data': row});
  }

  ResponseBody _uploadDocument(FormData form) {
    final type = form.fields.firstWhere((e) => e.key == 'document_type').value;
    final file = form.files.firstWhere((e) => e.key == 'file').value;
    final cfg = docTypes.where((t) => t['type_key'] == type && t['visible'] == true);
    if (cfg.isEmpty) return _fail(400, 'Invalid document type.');
    final problem = _checkFile(file);
    if (problem != null) return _fail(400, problem);
    if (cfg.first['allow_multiple'] != true) {
      documents.removeWhere((d) => d['document_type'] == type);
    }
    final row = {
      'id': _nextId++,
      'document_type': type,
      'document_type_display': cfg.first['label'],
      'file': 'https://files.invalid/docs/${file.filename}',
      'file_name': file.filename,
    };
    documents.add(row);
    return _json(201, {'status': 'success', 'message': 'Document uploaded.', 'data': row});
  }

  ResponseBody _submit() {
    final missing = <String>[];
    for (final f in fields) {
      if (f['step'] as int > 3 || f['visible'] != true || f['required'] != true) continue;
      final key = f['field_key'] as String;
      final present = f['field_type'] == 'file'
          ? customFiles.any((c) => c['field_key'] == key)
          : '${valueOf(key) ?? ''}'.trim().isNotEmpty;
      if (!present) missing.add(f['label'] as String);
    }
    if (missing.isNotEmpty) {
      return _fail(400, 'Please complete the following required fields before submitting: ${missing.join(', ')}.');
    }
    final missingDocs = [
      for (final t in docTypes)
        if (t['visible'] == true && t['required'] == true && !documents.any((d) => d['document_type'] == t['type_key']))
          t['label'],
    ];
    if (missingDocs.isNotEmpty) {
      return _fail(400, 'Please upload the following required documents before submitting: ${missingDocs.join(', ')}.');
    }
    submitted = true;
    return _ok('Onboarding submitted. Awaiting HR approval.', null);
  }

  @override
  void close({bool force = false}) {}
}
