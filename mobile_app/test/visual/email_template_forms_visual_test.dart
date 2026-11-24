import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/features/settings/presentation/email_templates/widgets/template_editor_sheet.dart';
import 'package:mobile_app/features/settings/presentation/email_templates/widgets/template_preview_sheet.dart';

import '../features/settings/email_template_fakes.dart';
import 'shot_harness.dart';

// Task 105: render evidence for the full-screen Email Template preview and
// editor. Runs only with T1011_SHOTS=1 (T1011_OUT, T1011_PREFIX). Real widgets,
// real Poppins, the real route push from a host page.
//
// The preview's WebView cannot render in a test: those shots use a STAND-IN
// view (a labelled box), so they show the page around the email, not the email.

const _bodyHtml = '<div><h2>Payslip for {MONTH}</h2><p>Hello {EMPLOYEE_NAME},</p>'
    '<p>Your payslip is ready. <a href="https://example.test/payslip/123456789">Open it here</a>.</p>'
    '<ul><li>Basic</li><li>Allowances</li></ul><p>Regards,<br>HR Team</p></div>';

Widget _standIn(String html) => Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      color: const Color(0xFFF4F4F7),
      child: Text(
        'STAND-IN VIEW\nThe WebView cannot render in a test.\n${html.length} characters of HTML were handed to it.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
      ),
    );

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _loadMono(WidgetTester t) async {
  // The body field uses the platform 'monospace' family, which a test does not have.
  const candidates = ['/System/Library/Fonts/Monaco.ttf', '/System/Library/Fonts/Supplemental/Courier New.ttf'];
  final file = candidates.map(File.new).where((f) => f.existsSync()).firstOrNull;
  if (file == null) return;
  final loader = FontLoader('monospace')..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  await loader.load();
}

Future<EtBackend> _open(
  WidgetTester t,
  WidgetBuilder builder, {
  Size size = const Size(393, 852),
  double scale = 1,
  EtBackend? backend,
  double keyboard = 0,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  if (keyboard > 0) t.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(t.view.reset);
  await t.runAsync(() async {
    await loadShotFonts();
    await _loadMono(t);
  });
  final s = backend ?? (EtBackend()..templates = [etJson()]);
  await t.pumpWidget(shotFrame(etApp(s, builder, scale: scale, extra: [
    emailPreviewViewBuilderProvider.overrideWithValue(_standIn),
  ])));
  await t.tap(find.byKey(const Key('host-open')));
  await _settle(t);
  return s;
}

Future<void> _type(WidgetTester t, String key, String text) async {
  await t.enterText(find.byKey(Key(key)), text);
  await t.pump();
}

Future<void> _pickCategory(WidgetTester t, String label) async {
  await t.tap(find.byKey(const Key('et-field-category')));
  await _settle(t);
  await t.tap(find.text(label).last);
  await _settle(t);
}

Future<void> _fill(WidgetTester t, {bool category = true}) async {
  await _type(t, 'et-field-display-name', 'Welcome Letter');
  await _type(t, 'et-field-subject', 'Welcome to the team, {EMPLOYEE_NAME}');
  await _type(t, 'et-field-body', '<p>Hi {EMPLOYEE_NAME},</p><p>Your first day is {JOIN_DATE}.</p>');
  if (category) await _pickCategory(t, 'Notification Templates');
}

dynamic get _tpl => etModel(
      body: _bodyHtml,
      attachments: [
        {
          'id': 3,
          'filename': 'leave-policy-2026.pdf',
          'mime_type': 'application/pdf',
          'size': 20480,
          'url': 'https://f.example/p.pdf'
        }
      ],
    );

void shot(String name, Future<void> Function(WidgetTester t) body) {
  testWidgets('shot $name', (t) async {
    await body(t);
    await shoot(t, name);
  }, skip: !shotsEnabled);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Widget preview(BuildContext _) => TemplatePreviewScreen(template: _tpl);
  Widget add(BuildContext _) => const TemplateEditorScreen();
  Widget edit(BuildContext _) => TemplateEditorScreen(
        template: etModel(
          attachments: [
            {
              'id': 3,
              'filename': 'leave-policy-2026.pdf',
              'mime_type': 'application/pdf',
              'size': 20480,
              'url': 'https://f.example/p.pdf'
            }
          ],
        ),
      );

  // ── Preview (stand-in view) ────────────────────────────────────────────────
  shot('01_preview_standin', (t) => _open(t, preview));
  shot('02_preview_text_mode', (t) async {
    await _open(t, preview);
    await t.tap(find.byKey(const Key('et-preview-mode-text')));
    await _settle(t);
  });
  shot('03_preview_long_subject', (t) async {
    await _open(
        t,
        (_) => TemplatePreviewScreen(
                template: etModel(
              body: _bodyHtml,
              displayName: 'Quarterly Performance Review And Compensation Revision Notification',
              subject:
                  'Your quarterly performance review summary and compensation revision letter for the period ending March {FINANCIAL_YEAR}',
              builtin: true,
              vars: const [
                'EMPLOYEE_NAME',
                'A_VERY_LONG_VARIABLE_NAME_THAT_KEEPS_GOING_AND_GOING_FOR_ETERNITY',
                'MONTH'
              ],
            )));
  });
  shot('04_preview_320dp_2x', (t) => _open(t, preview, size: const Size(320, 568), scale: 2));
  shot('04b_preview_320dp_2x_details_open', (t) async {
    await _open(t, preview, size: const Size(320, 568), scale: 2);
    await t.tap(find.byKey(const Key('et-preview-details-toggle')));
    await _settle(t);
  });
  shot('05_preview_tablet_1000', (t) => _open(t, preview, size: const Size(1000, 800)));

  // ── Editor ─────────────────────────────────────────────────────────────────
  shot('10_add_empty', (t) => _open(t, add));
  shot('10b_add_empty_full_page', (t) => _open(t, add, size: const Size(393, 2300)));
  shot('11_add_partly_filled', (t) async {
    await _open(t, add);
    await _type(t, 'et-field-display-name', 'Welcome Letter');
    await _type(t, 'et-field-subject', 'Welcome to the team');
  });
  shot('12_add_fully_filled_full_page', (t) async {
    await _open(t, add, size: const Size(393, 2300));
    await _fill(t);
  });
  shot('13_category_dropdown_open', (t) async {
    await _open(t, add);
    await t.tap(find.byKey(const Key('et-field-category')));
    await _settle(t);
  });
  shot('14_validation_errors_full_page', (t) async {
    await _open(t, add, size: const Size(393, 2300));
    await t.tap(find.byKey(const Key('et-save')));
    await _settle(t);
  });
  shot('14b_validation_errors_viewport', (t) async {
    await _open(t, add);
    await t.ensureVisible(find.byKey(const Key('et-field-body')));
    await t.tap(find.byKey(const Key('et-save')));
    await _settle(t);
  });
  shot('15_server_error_banner', (t) async {
    await _open(t, add, backend: EtBackend()..createStatus = 400);
    await _fill(t);
    await t.tap(find.byKey(const Key('et-save')));
    await _settle(t);
  });
  shot('16_saving', (t) async {
    final s = EtBackend()..templates = [etJson()];
    await _open(t, add, backend: s);
    await _fill(t);
    s.hold = Completer<void>();
    await t.tap(find.byKey(const Key('et-save')));
    await t.pump(const Duration(milliseconds: 150));
  });
  shot('17_keyboard_open', (t) async {
    await _open(t, add, keyboard: 300);
    await t.tap(find.byKey(const Key('et-field-subject')));
    await _settle(t);
  });
  shot('17b_keyboard_open_short_screen', (t) async {
    await _open(t, add, size: const Size(360, 640), keyboard: 320);
  });
  shot('18_add_320dp_2x', (t) async {
    await _open(t, add, size: const Size(320, 568), scale: 2);
  });
  shot('18b_add_320dp_2x_full_page', (t) async {
    await _open(t, add, size: const Size(320, 5200), scale: 2);
  });
  shot('19_add_tablet_1000', (t) async {
    await _open(t, add, size: const Size(1000, 1400));
    await _fill(t);
  });
  shot('20_edit_mode', (t) => _open(t, edit));
  shot('20b_edit_mode_full_page', (t) => _open(t, edit, size: const Size(393, 2000)));
}
