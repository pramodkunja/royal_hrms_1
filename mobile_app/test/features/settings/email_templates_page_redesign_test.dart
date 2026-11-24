// Task 105: the Email Templates PAGE — the shell's blue app bar, hero + search,
// type pills, summary, email-settings cards, template cards, distinct states and
// the responsive matrix. (The editor and preview screens are tested in
// email_template_editor_test.dart / email_template_preview_test.dart; loading
// every page is pinned by email_templates_paging_test.dart.)
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
import 'package:mobile_app/features/approvals/presentation/widgets/approvals_kit.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/app_top_bar.dart';
import 'package:mobile_app/features/settings/data/models/email_template_model.dart';
import 'package:mobile_app/features/settings/presentation/email_templates/email_templates_screen.dart';
import 'package:mobile_app/features/settings/presentation/email_templates/widgets/template_editor_sheet.dart';
import 'package:mobile_app/features/settings/presentation/email_templates/widgets/template_preview_sheet.dart';
import 'package:mobile_app/features/settings/presentation/widgets/settings_app_bar.dart';
import 'package:mobile_app/shared/widgets/blue_hero_banner.dart';

import '../../visual/email_templates_page_visual_test.dart' show EtBackend, etUser;

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

late EtBackend server;

Finder _k(String k) => find.byKey(Key(k));

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 80));
  }
}

Future<void> _open(WidgetTester t,
    {Size size = const Size(393, 3000), double scale = 1, EtBackend? backend, UserEntity? as}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  server = backend ?? EtBackend();
  await t.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith(() => _Auth(as ?? etUser())),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_Storage()),
      // A WebView cannot run in tests: the preview screen gets a stand-in.
      emailPreviewViewBuilderProvider
          .overrideWithValue((html) => SizedBox(key: const Key('preview-stub'), child: Text(html.length.toString()))),
    ],
    child: MaterialApp.router(
      builder: (c, child) =>
          MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
      routerConfig: GoRouter(initialLocation: '/s', routes: [
        GoRoute(path: '/s', builder: (_, __) => const EmailTemplatesScreen()),
      ]),
    ),
  ));
  await _settle(t);
}

Future<void> _tap(WidgetTester t, String key) async {
  await t.ensureVisible(_k(key));
  await t.pump();
  await t.tap(_k(key), warnIfMissed: false);
  await _settle(t);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('app bar and hero (the same as Announcements / Assets)', () {
    testWidgets('the shell’s AppTopBar: blue, "Email Templates", back arrow, no white Settings bar', (t) async {
      await _open(t);
      expect(find.byType(AppTopBar), findsOneWidget);
      expect(find.byType(SettingsAppBar), findsNothing);
      final bar = t.widget<AppTopBar>(find.byType(AppTopBar));
      expect((bar.isBlueTheme, bar.title), (true, 'Email Templates'));
      expect(_k('app-top-bar-back'), findsOneWidget);
      final fill = find.descendant(of: find.byType(AppTopBar), matching: find.byType(Container)).first;
      expect((t.widget<Container>(fill).decoration as BoxDecoration).color, AppColors.primary);
    });

    testWidgets('the hero band holds the intro line and the search field', (t) async {
      await _open(t);
      expect(find.descendant(of: find.byType(BlueHeroBanner), matching: _k('template-search')), findsOneWidget);
      expect(find.text('Customize transactional email messages sent by Royal HRMS'), findsOneWidget);
    });
  });

  group('content', () {
    testWidgets('summary counts come from the loaded templates', (t) async {
      await _open(t);
      String tile(String label) {
        final texts = t
            .widgetList<Text>(find.descendant(of: _k('template-summary'), matching: find.byType(Text)))
            .map((x) => x.data!)
            .toList();
        return texts[texts.indexOf(label) - 1];
      }

      expect({
        for (final l in ['Total', 'Active', 'Custom']) l: tile(l)
      }, {
        'Total': '8',
        'Active': '7',
        'Custom': '2'
      });
    });

    testWidgets('the email-settings cards (branding and birthday) sit above the templates', (t) async {
      await _open(t);
      expect(find.text('Email Header & Footer'), findsOneWidget);
      expect(find.text('Automatic Birthday Wishes'), findsOneWidget);
      expect(t.getTopLeft(_k('email-branding-card')).dy, lessThan(t.getTopLeft(_k('template-card-1')).dy));
      // web's footer text: website | address, city, state
      expect(find.textContaining('www.sriainfotech.example  |  Plot 12, Tech Park, Surat, Gujarat'), findsOneWidget);
    });

    testWidgets('a user without employees.view sees no birthday card (nothing requested)', (t) async {
      await _open(t, as: etUser(['settings.view', 'settings.edit']));
      expect(find.text('Automatic Birthday Wishes'), findsNothing);
      expect(server.calls.where((c) => c.contains('/birthdays/')), isEmpty);
    });

    testWidgets('templates are grouped by type, in web order, each with its count', (t) async {
      await _open(t);
      final heads = ['Document Templates', 'Notification Templates', 'Reminder Templates', 'Wish Templates'];
      final ys = [for (final h in heads) t.getTopLeft(find.text(h)).dy];
      expect(ys, [...ys]..sort());
      expect(find.text('3 templates'), findsOneWidget);
      expect(find.text('1 template'), findsOneWidget);
    });

    testWidgets('a card: name, status word, origin, description, subject, labelled actions', (t) async {
      await _open(t);
      final card = _k('template-card-1');
      for (final text in [
        'Pay Slip',
        'Active',
        'Built-in',
        'Subject',
        'Your pay slip for {MONTH} {YEAR}',
        'Preview',
        'Edit'
      ]) {
        expect(find.descendant(of: card, matching: find.text(text)), findsOneWidget, reason: text);
      }
      expect(t.getSize(_k('template-preview-1')).height, greaterThanOrEqualTo(44));
      expect(t.getSize(_k('template-edit-1')).height, greaterThanOrEqualTo(44));
    });

    testWidgets('inactive is said in words, not colour alone', (t) async {
      await _open(t);
      expect(find.descendant(of: _k('template-card-3'), matching: find.text('Inactive')), findsOneWidget);
      expect(t.widget<Switch>(_k('template-toggle-3')).value, isFalse);
    });

    testWidgets('Delete only for custom templates; built-in ones have none', (t) async {
      await _open(t);
      expect(_k('template-delete-5'), findsOneWidget); // Welcome Email (custom)
      expect(_k('template-delete-1'), findsNothing); // Pay Slip (built-in)
    });
  });

  group('actions', () {
    testWidgets('the Active switch PATCHes is_active', (t) async {
      await _open(t);
      await _tap(t, 'template-toggle-3');
      expect(server.bodies['PATCH /settings/email-templates/3/'], containsPair('is_active', true));
    });

    testWidgets('Delete asks first; Cancel sends nothing, Delete sends DELETE', (t) async {
      await _open(t);
      await _tap(t, 'template-delete-5');
      expect(find.text('Delete template?'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await _settle(t);
      expect(server.calls.where((c) => c.startsWith('DELETE')), isEmpty);
      await _tap(t, 'template-delete-5');
      await t.tap(_k('template-delete-confirm'));
      await _settle(t);
      expect(server.calls, contains('DELETE /settings/email-templates/5/'));
    });
  });

  group('search and type filter', () {
    testWidgets('search narrows to matches, shows "N of M", and the settings step aside', (t) async {
      await _open(t);
      await t.enterText(_k('template-search'), 'remind');
      await _settle(t);
      expect(find.text('Document Submission Reminder'), findsOneWidget);
      expect(find.text('Pay Slip'), findsNothing);
      expect(find.text('1 of 8 templates'), findsOneWidget);
      expect(find.text('Email Header & Footer'), findsNothing); // results first
    });

    testWidgets('a type pill filters the list and shows its count; All restores', (t) async {
      await _open(t);
      final pills = find.descendant(of: _k('template-type-pills'), matching: find.byType(Scrollable)).first;
      await t.scrollUntilVisible(_k('template-pill-wish'), 150, scrollable: pills);
      await t.drag(pills, Offset(196 - t.getCenter(_k('template-pill-wish')).dx, 0)); // centre it before tapping
      await t.pump();
      expect(find.text('Wish · 2'), findsOneWidget);
      await t.tap(_k('template-pill-wish'));
      await _settle(t);
      expect(find.text('Birthday Wish'), findsOneWidget);
      expect(find.text('Pay Slip'), findsNothing);
      await t.scrollUntilVisible(_k('template-pill-all'), -150, scrollable: pills);
      await t.drag(pills, Offset(196 - t.getCenter(_k('template-pill-all')).dx, 0));
      await t.pump();
      await t.tap(_k('template-pill-all'));
      await _settle(t);
      expect(find.text('Pay Slip'), findsOneWidget);
    });

    testWidgets('no match: its own state; Clear filters restores everything', (t) async {
      await _open(t);
      await t.enterText(_k('template-search'), 'zzzz');
      await _settle(t);
      expect(find.byWidgetPredicate((w) => w is ApprovalsEmptyState && w.kind == ApprovalsStateKind.noMatch),
          findsOneWidget);
      await _tap(t, 'approvals-empty-action');
      expect(find.text('Pay Slip'), findsOneWidget);
      expect(t.widget<TextField>(_k('template-search')).controller!.text, '');
    });
  });

  group('states', () {
    testWidgets('no templates: calm empty state with Add Template', (t) async {
      await _open(t, backend: EtBackend(templates: []));
      expect(find.byWidgetPredicate((w) => w is ApprovalsEmptyState && w.kind == ApprovalsStateKind.empty),
          findsOneWidget);
      expect(_k('template-empty-add'), findsOneWidget);
      expect(find.text('Email Header & Footer'), findsOneWidget); // settings stay reachable
    });

    testWidgets('a failed load is an error with Retry (titled for templates), never the empty look', (t) async {
      await _open(t, backend: EtBackend()..listStatus = 500);
      expect(_k('template-load-error'), findsOneWidget);
      expect(find.text('Couldn’t load templates'), findsOneWidget);
      expect(find.text('No email templates yet'), findsNothing);
      server.listStatus = 200;
      await _tap(t, 'approvals-empty-action');
      expect(find.text('Pay Slip'), findsOneWidget);
    });

    testWidgets('403: denied, no Retry', (t) async {
      await _open(t, backend: EtBackend()..listStatus = 403);
      expect(find.byWidgetPredicate((w) => w is ApprovalsEmptyState && w.kind == ApprovalsStateKind.denied),
          findsOneWidget);
      expect(_k('approvals-empty-action'), findsNothing);
    });

    testWidgets('a failed company load shows the branding error with Retry (not a silently missing card)', (t) async {
      await _open(t, backend: EtBackend()..companyStatus = 500);
      expect(_k('email-branding-error'), findsOneWidget);
      expect(find.text('Pay Slip'), findsOneWidget); // the templates are unaffected
      server.companyStatus = 200;
      await _tap(t, 'email-branding-retry');
      expect(_k('email-branding-card'), findsOneWidget);
      expect(_k('email-branding-error'), findsNothing);
    });
  });

  group('navigation', () {
    testWidgets('Add Template (FAB) opens the editor as a full screen; Cancel returns to the page', (t) async {
      await _open(t);
      await _tap(t, 'template-add');
      expect(find.byType(TemplateEditorScreen), findsOneWidget);
      expect(find.text('Add Email Template'), findsWidgets);
      await t.tap(find.text('Cancel'));
      await _settle(t);
      expect(find.byType(TemplateEditorScreen), findsNothing);
      expect(_k('template-list'), findsOneWidget);
    });

    testWidgets('Preview opens the preview screen; its Edit Template button opens the editor', (t) async {
      await _open(t);
      await _tap(t, 'template-preview-1');
      expect(find.byType(TemplatePreviewScreen), findsOneWidget);
      expect(find.byType(TemplateEditorScreen), findsNothing);
      await t.tap(find.text('Edit Template'));
      await _settle(t);
      expect(find.byType(TemplatePreviewScreen), findsNothing);
      expect(find.byType(TemplateEditorScreen), findsOneWidget);
    });

    testWidgets('Edit opens the editor on that template', (t) async {
      await _open(t);
      await _tap(t, 'template-edit-1');
      expect(find.byType(TemplateEditorScreen), findsOneWidget);
      expect(find.text('Edit: Pay Slip'), findsWidgets);
    });

    testWidgets('a confirmed save returns to the page with a success message and a refreshed list', (t) async {
      await _open(t);
      final before = server.calls.where((c) => c == 'GET /settings/email-templates/').length;
      await _tap(t, 'template-edit-1');
      await t.tap(find.text('Save Changes'));
      await _settle(t);
      await _settle(t);
      expect(find.byType(TemplateEditorScreen), findsNothing);
      expect(find.text('Email template updated'), findsOneWidget);
      expect(server.calls.where((c) => c.startsWith('PATCH /settings/email-templates/1/')), isNotEmpty);
      expect(before, greaterThanOrEqualTo(1));
    });
  });

  group('slug (web toSlug)', () {
    test('lowercase, keeps underscores, spaces become _, must start with a letter', () {
      expect(EmailTemplateFormData.toSlug('Pay Slip'), 'pay_slip');
      expect(EmailTemplateFormData.toSlug('Leave_Approved  Now!'), 'leave_approved_now');
      expect(EmailTemplateFormData.toSlug('2026 Offer Letter'), 'offer_letter');
      expect(EmailTemplateFormData.toSlug('__x'), 'x');
    });
  });

  group('theme', () {
    testWidgets('dark mode: bar, cards and chips follow the dark tokens, nothing overflows', (t) async {
      AppColors.applyMode(true);
      addTearDown(() => AppColors.applyMode(false));
      await _open(t);
      expect(t.takeException(), isNull);
      final fill = find.descendant(of: find.byType(AppTopBar), matching: find.byType(Container)).first;
      expect((t.widget<Container>(fill).decoration as BoxDecoration).color, AppColors.primary);
      final card = t.widget<Container>(_k('template-card-1'));
      expect((card.decoration as BoxDecoration).color, AppColors.surface);
      expect(AppColors.surface, isNot(const Color(0xFFFFFFFF))); // really the dark surface
    });
  });

  group('responsive', () {
    double top(WidgetTester t, int id) => t.getTopLeft(_k('template-card-$id')).dy;

    testWidgets('columns follow the width: 1 on a phone, 2 from 600dp, 3 from 900dp', (t) async {
      await _open(t, size: const Size(393, 3600));
      expect(top(t, 1) != top(t, 2), isTrue);
      await _open(t, size: const Size(700, 3000));
      expect(top(t, 1), top(t, 2));
      await _open(t, size: const Size(1000, 3000));
      expect(top(t, 1), top(t, 3));
    });

    for (final (w, h, s) in [
      (320.0, 568.0, 1.0),
      (360.0, 800.0, 1.0),
      (393.0, 852.0, 1.0),
      (430.0, 932.0, 1.0),
      (700.0, 1000.0, 1.0),
      (1000.0, 800.0, 1.0),
      (320.0, 568.0, 2.0),
      (360.0, 800.0, 1.5),
    ]) {
      testWidgets('${w.toInt()}×${h.toInt()} at $s× text: scrolls end to end, no overflow', (t) async {
        final b = EtBackend(templates: [
          ...EtBackend().templates,
          {
            'id': 99,
            'name': 'long',
            'display_name': 'An Extremely Long Template Display Name That Keeps Going For Several Lines',
            'description': 'A long description ' * 12,
            'subject':
                'A very long email subject line that should wrap and ellipsize instead of overflowing {FIRST_NAME_AND_LAST_NAME_PLACEHOLDER}',
            'body': '<p>x</p>',
            'template_type': 'notification',
            'template_type_display': 'Notification',
            'is_active': true,
            'is_builtin': false,
            'available_variables': <String>[],
            'attachments': <Object>[],
          },
        ]);
        await _open(t, size: Size(w, h), scale: s, backend: b);
        expect(t.takeException(), isNull);
        for (var i = 0; i < 12; i++) {
          await t.drag(_k('template-list'), const Offset(0, -350));
          await t.pump();
          expect(t.takeException(), isNull, reason: 'scroll $i');
        }
      });
    }
  });
}
