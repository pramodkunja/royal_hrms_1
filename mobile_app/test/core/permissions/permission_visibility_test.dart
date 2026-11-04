import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/permissions/permission_providers.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/features/announcements/data/models/announcement_model.dart';
import 'package:mobile_app/features/announcements/presentation/announcement_permissions.dart';
import 'package:mobile_app/features/announcements/presentation/announcements_screen.dart';
import 'package:mobile_app/features/announcements/presentation/providers/announcement_providers.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/documents/domain/entities/document_entity.dart';
import 'package:mobile_app/features/documents/presentation/widgets/document_detail_dialog.dart';
import 'package:mobile_app/features/documents/presentation/widgets/document_list_states.dart';
import 'package:mobile_app/features/employees/data/models/employee_model.dart';
import 'package:mobile_app/features/employees/presentation/widgets/employee_card.dart';

// Phase 5 (A): action buttons follow the signed-in user's permissions —
// the same rule the backend applies (has_perm: superuser or settings.edit
// passes; otherwise the exact codename). Viewing stays open; only the
// actions the server would refuse are hidden.

UserEntity user(List<String> perms, {bool superuser = false, String id = 'u1'}) => UserEntity(
    id: id,
    email: 'e@example.com',
    fullName: 'Pat',
    role: 'employee',
    roleDisplay: 'Employee',
    mustChangePassword: false,
    permissions: perms,
    isSuperuser: superuser,
    onboardingStatus: 'complete',
    assessmentStatus: 'complete');

class _Auth extends AuthNotifier {
  _Auth(this.initial);
  final UserEntity? initial;
  @override
  Future<AuthState> build() async => AuthState(user: initial);
  void become(UserEntity? u) => state = AsyncData(AuthState(user: u));
}

class _Failing extends AuthNotifier {
  @override
  Future<AuthState> build() async => throw Exception('profile unavailable');
}

/// Answers every request with an empty success (announcement view pings).
class _OkAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async =>
      ResponseBody.fromString(jsonEncode({'status': 'success', 'message': 'ok', 'data': {}}), 200, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });
  @override
  void close({bool force = false}) {}
}

AnnouncementModel ann(String id, {bool canEdit = false}) => AnnouncementModel.fromJson({
      'id': id,
      'title': 'Title $id',
      'body': 'Body',
      'category': 'general',
      'posted_by_name': 'HR',
      'can_edit': canEdit,
      'created_at': '2026-11-01T10:00:00Z',
      'updated_at': '2026-11-01T10:00:00Z',
    });

class _Announcements extends AnnouncementsNotifier {
  _Announcements(this.items);
  final List<AnnouncementModel> items;
  @override
  Future<AnnouncementPage> build() async => AnnouncementPage(
      announcements: items,
      stats: const AnnouncementStats(totalCount: 0, pinnedCount: 0, totalViews: 0, totalReactions: 0),
      currentPage: 1,
      totalPages: 1);
}

const fullHr = [
  'announcements.create',
  'announcements.edit',
  'announcements.delete',
  'documents.view',
  'documents.create',
  'documents.edit',
  'documents.delete',
  'employees.view',
  'employees.create',
  'employees.edit',
];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('permissionProvider', () {
    Future<ProviderContainer> containerFor(AuthNotifier Function() auth) async {
      final c = ProviderContainer(overrides: [authStateProvider.overrideWith(auth)]);
      addTearDown(c.dispose);
      try {
        await c.read(authStateProvider.future);
      } catch (_) {}
      return c;
    }

    test('full, partial and view-only permissions', () async {
      final full = await containerFor(() => _Auth(user(fullHr)));
      expect(full.read(permissionProvider('documents.delete')), isTrue);
      final partial = await containerFor(() => _Auth(user(['documents.view', 'documents.create'])));
      expect(partial.read(permissionProvider('documents.create')), isTrue);
      expect(partial.read(permissionProvider('documents.delete')), isFalse);
      final viewOnly = await containerFor(() => _Auth(user(['documents.view'])));
      expect(viewOnly.read(permissionProvider('documents.create')), isFalse);
    });

    test('superuser and settings.edit pass every check, as on the server', () async {
      final su = await containerFor(() => _Auth(user(const [], superuser: true)));
      expect(su.read(permissionProvider('employees.create')), isTrue);
      final admin = await containerFor(() => _Auth(user(['settings.edit'])));
      expect(admin.read(permissionProvider('announcements.delete')), isTrue);
    });

    test('no user, auth still loading or auth failed: nothing is granted', () async {
      final none = await containerFor(() => _Auth(null));
      expect(none.read(permissionProvider('documents.view')), isFalse);
      final failed = await containerFor(_Failing.new);
      expect(failed.read(permissionProvider('documents.view')), isFalse);
      final loading = ProviderContainer(overrides: [authStateProvider.overrideWith(() => _Auth(user(fullHr)))]);
      addTearDown(loading.dispose);
      expect(loading.read(permissionProvider('documents.view')), isFalse); // before auth resolves
    });

    test('follows the signed-in user when permissions change', () async {
      final auth = _Auth(user(['documents.view']));
      final c = await containerFor(() => auth);
      final seen = <bool>[];
      c.listen(permissionProvider('documents.create'), (_, v) => seen.add(v), fireImmediately: true);
      auth.become(user(['documents.view', 'documents.create']));
      await Future<void>.delayed(Duration.zero);
      auth.become(null); // signed out
      await Future<void>.delayed(Duration.zero);
      expect(seen, [false, true, false]);
    });
  });

  group('announcement actions (backend CanPostAnnouncement + can_edit)', () {
    test('post needs announcements.create', () {
      expect(canPostAnnouncements(user(['announcements.create'])), isTrue);
      expect(canPostAnnouncements(user(const [])), isFalse);
      expect(canPostAnnouncements(null), isFalse);
    });

    test('edit/delete need the row can_edit and the matching codename', () {
      final mine = ann('1', canEdit: true);
      final others = ann('2');
      expect(announcementActions(mine, user(fullHr)), (edit: true, delete: true));
      expect(announcementActions(others, user(fullHr)), (edit: false, delete: false));
      expect(announcementActions(mine, user(['announcements.edit'])), (edit: true, delete: false));
      expect(announcementActions(mine, user(const [])), (edit: false, delete: false));
    });

    Future<void> pump(WidgetTester tester, UserEntity u, List<AnnouncementModel> items) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(), // fresh overrides per pump
        overrides: [
          authStateProvider.overrideWith(() => _Auth(u)),
          announcementsProvider.overrideWith(() => _Announcements(items)),
          dioProvider.overrideWithValue(
              Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = _OkAdapter()),
        ],
        child: const MaterialApp(home: AnnouncementsScreen()),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('employee: can read, no Post / Edit / Delete', (tester) async {
      await pump(tester, user(const []), [ann('1', canEdit: true)]);
      expect(find.text('Title 1'), findsOneWidget); // read access kept
      expect(find.byKey(const Key('post-announcement')), findsNothing);
      expect(find.byTooltip('Edit'), findsNothing);
      expect(find.byTooltip('Delete'), findsNothing);
    });

    testWidgets('HR: Post, and Edit/Delete only on rows the server marks editable', (tester) async {
      await pump(tester, user(fullHr), [ann('1', canEdit: true), ann('2')]);
      expect(find.byKey(const Key('post-announcement')), findsOneWidget);
      expect(find.byTooltip('Edit'), findsOneWidget);
      expect(find.byTooltip('Delete'), findsOneWidget);
    });

    testWidgets('empty list: the invitation to post is only for those who may', (tester) async {
      await pump(tester, user(const []), const []);
      expect(find.text('Nothing has been posted yet.'), findsOneWidget);
      await pump(tester, user(['announcements.create']), const []);
      expect(find.text('Be the first to post an announcement.'), findsOneWidget);
    });
  });

  group('documents', () {
    final doc = DocumentEntity(
      id: 1,
      title: 'Leave Policy',
      description: '',
      category: 'policy',
      categoryDisplay: 'Policy',
      fileUrl: 'https://files.invalid/p.pdf',
      fileName: 'p.pdf',
      fileType: 'pdf',
      fileSize: 10,
      fileSizeDisplay: '10 B',
      uploadedByName: 'HR',
      uploadedAt: DateTime(2026, 11, 1),
      isActive: true,
    );

    Future<void> pumpDialog(WidgetTester tester, UserEntity u) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(), // fresh overrides per pump
        overrides: [authStateProvider.overrideWith(() => _Auth(u))],
        child: MaterialApp(home: Scaffold(body: DocumentDetailDialog(document: doc))),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('Delete only with documents.delete; Preview/Download stay', (tester) async {
      await pumpDialog(tester, user(['documents.view']));
      expect(find.byKey(const Key('document-delete')), findsNothing);
      expect(find.text('Preview'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
      await pumpDialog(tester, user(['documents.view', 'documents.delete']));
      expect(find.byKey(const Key('document-delete')), findsOneWidget);
    });

    testWidgets('empty list offers Upload only to uploaders', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: DocumentEmptyView(onUpload: null))));
      expect(find.text('Upload Document'), findsNothing);
      expect(find.text('No documents have been shared yet.'), findsOneWidget);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: DocumentEmptyView(onUpload: () {}))));
      expect(find.text('Upload Document'), findsOneWidget);
    });
  });

  group('employees', () {
    final emp = EmployeeModel.fromJson(const {
      'id': '1',
      'employee_id': 'EMP-1',
      'full_name': 'Sam',
      'email': 's@example.com',
      'is_active': true,
    });

    testWidgets('the card hides Edit without employees.edit; View stays', (tester) async {
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: SizedBox(width: 220, child: EmployeeCard(employee: emp, onView: () {})))));
      expect(find.byKey(const Key('employee-card-edit')), findsNothing);
      expect(find.byIcon(Icons.remove_red_eye_outlined), findsOneWidget);
      await tester.pumpWidget(MaterialApp(
          home:
              Scaffold(body: SizedBox(width: 220, child: EmployeeCard(employee: emp, onView: () {}, onEdit: () {})))));
      expect(find.byKey(const Key('employee-card-edit')), findsOneWidget);
    });

    test('Bulk Import opens only with employees.create', () {
      String? go(UserEntity u) =>
          resolveAuthRedirect(authState: AuthState(user: u), path: AppRoutes.employeeBulkImport);
      expect(go(user(['employees.view'])), AppRoutes.dashboard);
      expect(go(user(['employees.view', 'employees.create'])), isNull);
    });
  });
}
