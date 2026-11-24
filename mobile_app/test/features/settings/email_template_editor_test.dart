// ignore_for_file: depend_on_referenced_packages
// Task 105: the full-screen Add / Edit Email Template page. Real widget, real
// route push, real notifier; the server is a stand-in (email_template_fakes.dart).
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/features/settings/data/models/email_template_model.dart';
import 'package:mobile_app/features/settings/presentation/email_templates/widgets/template_editor_sheet.dart';
import 'package:mobile_app/shared/widgets/blue_app_bar.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'email_template_fakes.dart';

Finder _k(String k) => find.byKey(Key(k));

class FakePicker extends FilePicker with MockPlatformInterfaceMixin {
  PlatformFile? next;
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    dynamic onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async =>
      next == null ? null : FilePickerResult([next!]);
}

late FakePicker picker;

// The file is never read: uploads go through EtDataSource, which only records them.
PlatformFile tempFile(String name, {int? size}) => PlatformFile(name: name, size: size ?? 4, path: '/tmp/t105/$name');

Future<EtBackend> open(
  WidgetTester t, {
  EmailTemplateModel? template,
  Size size = const Size(393, 852),
  double scale = 1,
  EtBackend? backend,
  double keyboard = 0,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  if (keyboard > 0) t.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(t.view.reset);
  final s = backend ?? (EtBackend()..templates = [etJson()]);
  await t.pumpWidget(etApp(s, (_) => TemplateEditorScreen(template: template), scale: scale));
  await t.tap(_k('host-open'));
  await t.pumpAndSettle();
  return s;
}

Object? hostResult(WidgetTester t) => t.state<EtHostState>(find.byType(EtHost, skipOffstage: false)).result;

bool onEditor() => _k('et-form').evaluate().isNotEmpty;

Future<void> pickCategory(WidgetTester t, String label) async {
  await t.ensureVisible(_k('et-field-category'));
  await t.tap(_k('et-field-category'));
  await t.pumpAndSettle();
  await t.tap(find.text(label).last);
  await t.pumpAndSettle();
}

Future<void> fillAdd(WidgetTester t,
    {String name = 'Welcome Letter',
    String subject = 'Welcome {EMPLOYEE_NAME}',
    String body = '<p>Hi {EMPLOYEE_NAME}, join on {JOIN_DATE}</p>',
    bool category = true}) async {
  await t.enterText(_k('et-field-display-name'), name);
  await t.enterText(_k('et-field-subject'), subject);
  await t.enterText(_k('et-field-body'), body);
  await t.pump();
  if (category) await pickCategory(t, 'Notification Templates');
}

Future<void> tapSave(WidgetTester t) async {
  await t.ensureVisible(_k('et-save'));
  await t.tap(_k('et-save'));
  await t.pumpAndSettle();
}

List<String> asterisks(WidgetTester t) => [
      for (final w in t.widgetList<RichText>(find.byType(RichText)))
        if (w.text.toPlainText().endsWith(' *')) w.text.toPlainText()
    ];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => FilePicker.platform = picker = FakePicker());

  group('add mode', () {
    testWidgets('every field is there; required ones carry a red *; sections in order', (t) async {
      await open(t);
      expect(find.byType(BlueAppBar), findsOneWidget);
      expect(find.text('Add Email Template'), findsOneWidget);
      for (final k in [
        'et-field-display-name',
        'et-field-name',
        'et-field-category',
        'et-field-subject',
        'et-field-body',
        'et-toolbar',
        'et-add-file',
        'et-active',
        'et-save',
        'et-cancel',
      ]) {
        expect(_k(k), findsOneWidget, reason: k);
      }
      expect(asterisks(t), ['Display Name *', 'Slug (name) *', 'Category *', 'Subject *', 'Body *']);
      expect(
          find.text('Supports HTML. Use the toolbar to format, or type {VARIABLE} tokens directly.'), findsOneWidget);
      expect(find.text('Create Template'), findsOneWidget);
      final ys = [
        for (final s in ['Basics', 'Message', 'Variables', 'Attachments', 'Status']) t.getTopLeft(find.text(s)).dy
      ];
      expect(ys, [...ys]..sort(), reason: 'Basics, Message, Variables, Attachments, Status top to bottom');
      expect(find.text('Type {VARIABLE} in the subject or body to detect a tag.'), findsOneWidget);
    });

    testWidgets('labels sit above their inputs', (t) async {
      await open(t);
      for (final p in [
        ('Display Name', 'et-field-display-name'),
        ('Subject', 'et-field-subject'),
        ('Slug (name)', 'et-field-name')
      ]) {
        final label = t.getTopLeft(find.textContaining(p.$1).first).dy;
        expect(label, lessThan(t.getTopLeft(_k(p.$2)).dy), reason: p.$1);
      }
    });

    testWidgets('slug follows the display name until edited; refresh re-links it', (t) async {
      await open(t);
      await t.enterText(_k('et-field-display-name'), 'Pay Slip 2026!');
      await t.pump();
      expect(t.widget<TextField>(_k('et-field-name')).controller!.text, 'pay_slip_2026');
      await t.enterText(_k('et-field-name'), 'custom_slug');
      await t.pump();
      await t.enterText(_k('et-field-display-name'), 'Other Name');
      await t.pump();
      expect(t.widget<TextField>(_k('et-field-name')).controller!.text, 'custom_slug', reason: 'edited slug is kept');
      await t.tap(_k('et-slug-regen'));
      await t.pump();
      expect(t.widget<TextField>(_k('et-field-name')).controller!.text, 'other_name');
    });

    testWidgets('empty save shows every required error, sends nothing, scrolls to the first', (t) async {
      final s = await open(t, size: const Size(393, 500));
      await t.ensureVisible(_k('et-field-body'));
      await t.pumpAndSettle();
      await tapSave(t);
      for (final m in [
        'Display name is required',
        'Slug is required',
        'Category is required',
        'Subject is required',
        'Body is required',
      ]) {
        expect(find.text(m), findsOneWidget, reason: m);
      }
      expect(s.requests.where((r) => r.method == 'POST' && r.path == ApiConstants.settingsEmailTemplates), isEmpty);
      // scrolled back up to the first refused field
      final first = t.getRect(_k('et-field-display-name'));
      expect(first.top, greaterThan(0));
      expect(first.bottom, lessThan(500));
      // typing clears that field's error only
      await t.enterText(_k('et-field-display-name'), 'X');
      await t.pump();
      expect(find.text('Display name is required'), findsNothing);
      expect(find.text('Subject is required'), findsOneWidget);
    });

    testWidgets('a bad slug is refused with web\'s rule', (t) async {
      final s = await open(t);
      await fillAdd(t);
      await t.enterText(_k('et-field-name'), '9Bad Slug');
      await t.pump();
      await tapSave(t);
      expect(find.textContaining('Lowercase letters, numbers, underscores only'), findsOneWidget);
      expect(s.where('POST', ApiConstants.settingsEmailTemplates), isEmpty);
    });

    testWidgets('create sends the web payload once, then pops true', (t) async {
      final s = await open(t);
      await fillAdd(t);
      await tapSave(t);
      final posts = s.where('POST', ApiConstants.settingsEmailTemplates).toList();
      expect(posts, hasLength(1));
      expect(posts.single.data, {
        'display_name': 'Welcome Letter',
        'name': 'welcome_letter',
        'subject': 'Welcome {EMPLOYEE_NAME}',
        'body': '<p>Hi {EMPLOYEE_NAME}, join on {JOIN_DATE}</p>',
        'template_type': 'notification',
        'is_active': true,
        'available_variables': ['EMPLOYEE_NAME', 'JOIN_DATE'],
      });
      expect(onEditor(), isFalse);
      expect(hostResult(t), true);
    });

    testWidgets('Active switch off is sent as is_active false', (t) async {
      final s = await open(t);
      await fillAdd(t);
      await t.ensureVisible(_k('et-active'));
      await t.tap(_k('et-active'));
      await t.pump();
      await tapSave(t);
      expect(s.where('POST', ApiConstants.settingsEmailTemplates).single.data['is_active'], false);
    });

    testWidgets('a server refusal keeps everything typed, shows a banner, and a retry sends again', (t) async {
      final s = await open(t, backend: EtBackend()..createStatus = 400);
      await fillAdd(t);
      await tapSave(t);
      expect(onEditor(), isTrue);
      expect(hostResult(t), 'unset', reason: 'not confirmed → nothing popped');
      expect(_k('et-save-error'), findsOneWidget);
      expect(find.text('Email template with this name already exists.'), findsOneWidget);
      expect(t.widget<TextField>(_k('et-field-display-name')).controller!.text, 'Welcome Letter');
      expect(t.widget<TextField>(_k('et-field-subject')).controller!.text, 'Welcome {EMPLOYEE_NAME}');
      expect(t.widget<TextField>(_k('et-field-body')).controller!.text, contains('JOIN_DATE'));
      expect(find.text('Notification Templates'), findsOneWidget, reason: 'category kept');
      expect(t.widget<FilledButton>(_k('et-save')).onPressed, isNotNull, reason: 'unlocked again');
      // banner is in view (scrolled to the top)
      expect(t.getRect(_k('et-save-error')).top, greaterThanOrEqualTo(0));

      s.createStatus = null;
      await tapSave(t);
      expect(s.where('POST', ApiConstants.settingsEmailTemplates), hasLength(2));
      expect(hostResult(t), true);
    });

    testWidgets('while saving: spinner + Saving…, fields locked, a second tap sends nothing, back is blocked',
        (t) async {
      final s = EtBackend()..templates = [etJson()];
      await open(t, backend: s);
      await fillAdd(t);
      s.hold = Completer<void>();
      await t.ensureVisible(_k('et-save'));
      await t.tap(_k('et-save'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('Saving…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(t.widget<FilledButton>(_k('et-save')).onPressed, isNull);
      expect(t.widget<OutlinedButton>(_k('et-cancel')).onPressed, isNull);
      expect(t.widget<TextField>(_k('et-field-subject')).enabled, isFalse);
      expect(t.widget<TextField>(_k('et-field-body')).enabled, isFalse);
      expect(t.widget<Switch>(_k('et-active')).onChanged, isNull);
      await t.tap(_k('et-save'), warnIfMissed: false);
      await t.pump();
      expect(s.where('POST', ApiConstants.settingsEmailTemplates), hasLength(1));
      await t.binding.handlePopRoute(); // system back while saving
      await t.pump();
      expect(onEditor(), isTrue, reason: 'back is blocked while a save is running');

      s.hold!.complete();
      await t.pumpAndSettle();
      expect(onEditor(), isFalse);
      expect(hostResult(t), true);
      expect(s.where('POST', ApiConstants.settingsEmailTemplates), hasLength(1));
    });

    testWidgets('Cancel and system back leave without asking, with no result', (t) async {
      final s = await open(t);
      await t.enterText(_k('et-field-subject'), 'typed');
      await t.tap(_k('et-cancel'));
      await t.pumpAndSettle();
      expect(onEditor(), isFalse);
      expect(hostResult(t), isNull);
      expect(s.where('POST', ApiConstants.settingsEmailTemplates), isEmpty);

      await t.tap(_k('host-open'));
      await t.pumpAndSettle();
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(onEditor(), isFalse);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('category: dropdown lists the server categories; Create new category posts and selects it', (t) async {
      final s = await open(t);
      await t.ensureVisible(_k('et-field-category'));
      await t.tap(_k('et-field-category'));
      await t.pumpAndSettle();
      for (final c in [
        'Document Templates',
        'Notification Templates',
        'Reminder Templates',
        'Wish Templates',
        'Create new category'
      ]) {
        expect(find.text(c), findsWidgets, reason: c);
      }
      await t.tap(find.text('Create new category').last);
      await t.pumpAndSettle();
      expect(find.text('Create Category'), findsOneWidget);
      await t.enterText(_k('et-new-category-name'), 'Payroll Notices');
      await t.tap(_k('et-new-category-create'));
      await t.pumpAndSettle();
      final post = s.where('POST', ApiConstants.settingsEmailTemplateCategories).single;
      expect(post.data, {'name': 'payroll_notices', 'display_name': 'Payroll Notices'});
      expect(find.text('Payroll Notices'), findsOneWidget, reason: 'selected');
      await fillAdd(t, name: 'N', category: false);
      await tapSave(t);
      expect(s.where('POST', ApiConstants.settingsEmailTemplates).single.data['template_type'], 'payroll_notices');
    });

    testWidgets('a refused new category shows the message and selects nothing', (t) async {
      final s = await open(t, backend: EtBackend()..categoryStatus = 400);
      await t.ensureVisible(_k('et-field-category'));
      await t.tap(_k('et-field-category'));
      await t.pumpAndSettle();
      await t.tap(find.text('Create new category').last);
      await t.pumpAndSettle();
      await t.enterText(_k('et-new-category-name'), 'Dup');
      await t.tap(_k('et-new-category-create'));
      await t.pumpAndSettle();
      expect(find.text('Email template with this name already exists.'), findsOneWidget, reason: 'toast');
      expect(find.text('Select category'), findsOneWidget);
      expect(s.where('POST', ApiConstants.settingsEmailTemplates), isEmpty);
    });

    testWidgets('variables: detected from subject and body (tags stripped), tap inserts into the body', (t) async {
      await open(t);
      await t.enterText(_k('et-field-subject'), 'Hi {FIRST}');
      await t.enterText(_k('et-field-body'), '<p style="x:{NOT_A_VAR}">Dear {LAST}</p>');
      await t.pump();
      expect(_k('et-var-FIRST'), findsOneWidget);
      expect(_k('et-var-LAST'), findsOneWidget);
      await t.ensureVisible(_k('et-var-FIRST'));
      await t.tap(_k('et-var-FIRST'));
      await t.pump();
      expect(t.widget<TextField>(_k('et-field-body')).controller!.text, endsWith('{FIRST}'));
    });

    testWidgets('toolbar: bold, italic, underline, strike, bullets, numbered, link', (t) async {
      await open(t);
      final body = t.widget<TextField>(_k('et-field-body')).controller!;
      body.text = 'word';
      body.selection = const TextSelection(baseOffset: 0, extentOffset: 4);
      await t.tap(_k('et-tool-bold'));
      await t.pump();
      expect(body.text, '<b>word</b>');
      body.text = 'x';
      body.selection = const TextSelection(baseOffset: 0, extentOffset: 1);
      await t.tap(_k('et-tool-italic'));
      expect(body.text, '<i>x</i>');
      body.text = 'x';
      body.selection = const TextSelection(baseOffset: 0, extentOffset: 1);
      await t.tap(_k('et-tool-underline'));
      expect(body.text, '<u>x</u>');
      body.text = 'x';
      body.selection = const TextSelection(baseOffset: 0, extentOffset: 1);
      await t.tap(_k('et-tool-strike'));
      expect(body.text, '<s>x</s>');
      body.text = 'a\nb';
      body.selection = const TextSelection(baseOffset: 0, extentOffset: 3);
      await t.tap(_k('et-tool-bullets'));
      expect(body.text, '<ul><li>a</li><li>b</li></ul>');
      body.text = 'a\nb';
      body.selection = const TextSelection(baseOffset: 0, extentOffset: 3);
      await t.tap(_k('et-tool-numbers'));
      expect(body.text, '<ol><li>a</li><li>b</li></ol>');
      body.text = 'site';
      body.selection = const TextSelection(baseOffset: 0, extentOffset: 4);
      await t.tap(_k('et-tool-link'));
      await t.pumpAndSettle();
      await t.enterText(_k('et-link-url'), 'https://x.example');
      await t.tap(_k('et-link-insert'));
      await t.pumpAndSettle();
      expect(body.text, '<a href="https://x.example">site</a>');
    });

    group('attachments (uploaded after create)', () {
      testWidgets('a valid file is listed as pending, can be removed, and uploads once the template exists', (t) async {
        final s = await open(t);
        picker.next = tempFile('policy.pdf');
        await t.ensureVisible(_k('et-add-file'));
        await t.tap(_k('et-add-file'));
        await t.pumpAndSettle();
        expect(find.text('policy.pdf'), findsOneWidget);
        expect(find.textContaining('will upload on save'), findsOneWidget);
        picker.next = tempFile('gone.png');
        await t.tap(_k('et-add-file'));
        await t.pumpAndSettle();
        await t.tap(_k('et-pending-remove-gone.png'));
        await t.pumpAndSettle();
        expect(find.text('gone.png'), findsNothing);

        await fillAdd(t);
        await tapSave(t);
        final uploads = s.where('POST', '/settings/email-templates/50/').toList();
        expect(uploads, hasLength(1), reason: 'only the kept file, to the new template id');
        expect(uploads.single.data['file'], 'policy.pdf');
        expect(uploads.single.data['mime'], 'application/pdf');
        expect(hostResult(t), true);
      });

      testWidgets('over 10 MB and unsupported types are refused with web\'s messages', (t) async {
        await open(t);
        await t.ensureVisible(_k('et-add-file'));
        picker.next = tempFile('big.pdf', size: 10 * 1024 * 1024 + 1);
        await t.tap(_k('et-add-file'));
        await t.pumpAndSettle();
        expect(find.text('File size must not exceed 10 MB.'), findsOneWidget);
        expect(find.text('big.pdf'), findsNothing);
        await t.pump(const Duration(seconds: 5));
        await t.pumpAndSettle();
        picker.next = tempFile('run.exe');
        await t.tap(_k('et-add-file'));
        await t.pumpAndSettle();
        expect(find.text('Unsupported file type.'), findsOneWidget);
        expect(find.text('run.exe'), findsNothing);
      });

      testWidgets('exactly 10 MB is accepted', (t) async {
        await open(t);
        await t.ensureVisible(_k('et-add-file'));
        picker.next = tempFile('edge.docx', size: 10 * 1024 * 1024);
        await t.tap(_k('et-add-file'));
        await t.pumpAndSettle();
        expect(find.text('edge.docx'), findsOneWidget);
      });
    });
  });

  group('edit mode', () {
    final tplAttachments = [
      {
        'id': 3,
        'filename': 'policy.pdf',
        'mime_type': 'application/pdf',
        'size': 2048,
        'url': 'https://f.example/p.pdf'
      }
    ];
    final tpl = etModel(attachments: tplAttachments);

    testWidgets('title, locked name/category, no slug, prefilled message, known variables', (t) async {
      await open(t, template: tpl);
      expect(find.text('Edit: Pay Slip'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
      expect(_k('et-field-name'), findsNothing);
      expect(find.descendant(of: _k('et-field-display-name'), matching: find.text('Pay Slip')), findsOneWidget);
      expect(find.descendant(of: _k('et-field-category'), matching: find.text('Document Templates')), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));
      expect(t.widget<TextField>(_k('et-field-subject')).controller!.text, 'Your payslip for {MONTH}');
      expect(t.widget<TextField>(_k('et-field-body')).controller!.text, contains('{EMPLOYEE_NAME}'));
      expect(_k('et-var-EMPLOYEE_NAME'), findsOneWidget);
      expect(_k('et-var-MONTH'), findsOneWidget);
      expect(asterisks(t), ['Subject *', 'Body *']);
      expect(find.text('policy.pdf'), findsOneWidget);
    });

    testWidgets('save sends the edit payload once (PATCH) and pops true', (t) async {
      final s = await open(t, template: tpl);
      await t.enterText(_k('et-field-subject'), 'New subject {EXTRA}');
      await t.pump();
      await tapSave(t);
      final patch = s.where('PATCH', ApiConstants.settingsEmailTemplateDetail(7)).toList();
      expect(patch, hasLength(1));
      expect(patch.single.data, {
        'display_name': 'Pay Slip',
        'subject': 'New subject {EXTRA}',
        'body': '<p>Hello {EMPLOYEE_NAME},</p><p>Your payslip is ready.</p>',
        'template_type': 'document',
        'is_active': true,
        'available_variables': ['EMPLOYEE_NAME', 'EXTRA', 'MONTH'],
      });
      expect(s.where('POST', ApiConstants.settingsEmailTemplates), isEmpty);
      expect(hostResult(t), true);
    });

    testWidgets('empty subject and body are refused; nothing sent', (t) async {
      final s = await open(t, template: tpl);
      await t.enterText(_k('et-field-subject'), '   ');
      await t.enterText(_k('et-field-body'), '');
      await t.pump();
      await tapSave(t);
      expect(find.text('Subject is required'), findsOneWidget);
      expect(find.text('Body is required'), findsOneWidget);
      expect(s.where('PATCH', ApiConstants.settingsEmailTemplateDetail(7)), isEmpty);
    });

    testWidgets('a server refusal keeps the edit and shows the message; nothing popped', (t) async {
      final s = await open(t,
          template: tpl,
          backend: EtBackend()
            ..patchStatus = 400
            ..templates = [etJson()]);
      await t.enterText(_k('et-field-subject'), 'Kept subject');
      await t.pump();
      await tapSave(t);
      expect(onEditor(), isTrue);
      expect(hostResult(t), 'unset');
      expect(_k('et-save-error'), findsOneWidget);
      expect(t.widget<TextField>(_k('et-field-subject')).controller!.text, 'Kept subject');
      s.patchStatus = null;
      await tapSave(t);
      expect(hostResult(t), true);
      expect(s.where('PATCH', ApiConstants.settingsEmailTemplateDetail(7)), hasLength(2));
    });

    testWidgets('saving: one PATCH however often the button is tapped', (t) async {
      final s = EtBackend()..templates = [etJson()];
      await open(t, template: tpl, backend: s);
      s.hold = Completer<void>();
      await t.ensureVisible(_k('et-save'));
      await t.tap(_k('et-save'));
      await t.pump();
      await t.tap(_k('et-save'), warnIfMissed: false);
      await t.tap(_k('et-save'), warnIfMissed: false);
      await t.pump();
      expect(find.text('Saving…'), findsOneWidget);
      s.hold!.complete();
      await t.pumpAndSettle();
      expect(s.where('PATCH', ApiConstants.settingsEmailTemplateDetail(7)), hasLength(1));
    });

    testWidgets('Active switch is sent', (t) async {
      final s = await open(t, template: tpl);
      await t.ensureVisible(_k('et-active'));
      await t.tap(_k('et-active'));
      await t.pump();
      await tapSave(t);
      expect(s.where('PATCH', ApiConstants.settingsEmailTemplateDetail(7)).single.data['is_active'], false);
    });

    testWidgets('adding a file uploads at once; removing asks first, then deletes', (t) async {
      final s = await open(t, template: tpl, backend: EtBackend()..templates = [etJson(attachments: tplAttachments)]);
      picker.next = tempFile('extra.pdf');
      await t.ensureVisible(_k('et-add-file'));
      await t.tap(_k('et-add-file'));
      await t.pumpAndSettle();
      expect(s.where('POST', ApiConstants.settingsEmailTemplateDetail(7)), hasLength(1));
      expect(find.text('extra.pdf'), findsOneWidget);

      await t.ensureVisible(_k('et-attachment-remove-3'));
      await t.tap(_k('et-attachment-remove-3'));
      await t.pumpAndSettle();
      expect(find.text('Remove Attachment'), findsOneWidget);
      expect(s.where('DELETE', ApiConstants.settingsEmailTemplateDetail(7)), isEmpty, reason: 'not before confirming');
      await t.tap(_k('et-remove-confirm'));
      await t.pumpAndSettle();
      final del = s.where('DELETE', ApiConstants.settingsEmailTemplateDetail(7)).single;
      expect(del.query, {'attachment_id': 3});
      expect(find.text('policy.pdf'), findsNothing);
    });
  });

  group('keyboard and size', () {
    testWidgets('keyboard up on a short screen hides the action bar; on a tall screen it stays', (t) async {
      await open(t, size: const Size(360, 640), keyboard: 320);
      expect(_k('et-save'), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('keyboard up on a tall screen keeps the pinned bar', (t) async {
      await open(t, size: const Size(393, 852), keyboard: 300);
      expect(_k('et-save'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    for (final edit in [false, true]) {
      for (final size in const [
        Size(320, 568),
        Size(360, 800),
        Size(393, 852),
        Size(430, 932),
        Size(700, 1000),
        Size(1000, 800)
      ]) {
        for (final scale in const [1.0, 1.5, 2.0]) {
          testWidgets(
              '${edit ? 'edit' : 'add'} ${size.width.toInt()}x${size.height.toInt()} @${scale}x: no overflow, pinned buttons usable',
              (t) async {
            final long = etModel(
              subject: 'A very long subject ${'word ' * 30}',
              vars: const ['A_VERY_LONG_VARIABLE_NAME_THAT_KEEPS_GOING_AND_GOING_FOR_ETERNITY_AND_BEYOND', 'B'],
              displayName: 'A long template display name that needs to wrap somewhere sensible',
              attachments: [
                {
                  'id': 3,
                  'filename': 'an-extremely-long-attachment-filename-for-the-annual-report-final-v3.pdf',
                  'mime_type': 'application/pdf',
                  'size': 2048,
                  'url': 'https://f.example/p.pdf'
                }
              ],
            );
            await open(t, template: edit ? long : null, size: size, scale: scale);
            expect(t.takeException(), isNull);
            if (!edit) {
              await t.tap(_k('et-save'));
              await t.pumpAndSettle();
              expect(t.takeException(), isNull, reason: 'with every error showing');
              expect(find.text('Display name is required'), findsOneWidget);
            }
            final save = t.getRect(_k('et-save'));
            expect(save.height, greaterThanOrEqualTo(48));
            expect(save.bottom, lessThanOrEqualTo(size.height));
            expect(save.right, lessThanOrEqualTo(size.width));
            final cancel = t.getRect(_k('et-cancel'));
            expect(cancel.height, greaterThanOrEqualTo(48));
            expect(cancel.right, lessThanOrEqualTo(size.width));
            expect(save.overlaps(cancel), isFalse);
            await t.drag(_k('et-form'), const Offset(0, -3000));
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
          });
        }
      }
    }
  });
}
