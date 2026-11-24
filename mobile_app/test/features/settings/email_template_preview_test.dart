// Task 105: the Email Template preview — the HTML wrapper (port of web
// buildEmailPreview, hardened) and the full-screen preview page.
//
// A WebView cannot run in widget tests, so the page is driven through
// emailPreviewViewBuilderProvider with a stand-in that only shows the HTML
// STRING it was given. Nothing here proves the HTML renders; it proves what is
// handed to the view and how the page around it behaves.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/features/settings/data/models/company_model.dart';
import 'package:mobile_app/features/settings/data/models/email_template_model.dart';
import 'package:mobile_app/features/settings/presentation/email_templates/widgets/email_preview_html.dart';
import 'package:mobile_app/features/settings/presentation/email_templates/widgets/template_preview_sheet.dart';

import 'email_template_fakes.dart';

CompanyModel company({
  String name = 'Acme Test Pvt Ltd',
  String? logo,
  String website = '',
  String address = '',
  String city = '',
  String state = '',
}) =>
    CompanyModel.fromJson({
      'company_name': name,
      'logo_url': logo,
      'website': website,
      'address': address,
      'city': city,
      'state': state,
    });

Finder _k(String k) => find.byKey(Key(k));

Widget standIn(String html) => SingleChildScrollView(child: Text(html, key: const Key('standin')));

/// The HTML string the stand-in view was given.
String shown(WidgetTester t) => t.widget<Text>(_k('standin')).data!;

Future<EtBackend> open(
  WidgetTester t, {
  Size size = const Size(393, 852),
  double scale = 1,
  EtBackend? backend,
  required EmailTemplateModel template,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final s = backend ?? EtBackend();
  await t.pumpWidget(etApp(
    s,
    (_) => TemplatePreviewScreen(template: template),
    scale: scale,
    extra: [emailPreviewViewBuilderProvider.overrideWithValue(standIn)],
  ));
  await t.tap(_k('host-open'));
  await t.pumpAndSettle();
  return s;
}

Object? hostResult(WidgetTester t) => t.state<EtHostState>(find.byType(EtHost)).result;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('buildEmailPreviewHtml', () {
    test('wraps the body unescaped in a 600px card with header, body and footer', () {
      final html = buildEmailPreviewHtml('<p>Hello <b>{NAME}</b></p>', company: company(website: 'https://a.example'));
      expect(html, contains('<p>Hello <b>{NAME}</b></p>'), reason: 'body is the email HTML, as on web');
      expect(html, contains('max-width:600px'));
      expect(html, contains('border-bottom:3px solid #4f46e5'));
      expect(html.indexOf('Acme Test Pvt Ltd'), lessThan(html.indexOf('Hello')), reason: 'header above body');
      expect(html.indexOf('Hello'), lessThan(html.indexOf('https://a.example')), reason: 'footer below body');
    });

    test('keeps {placeholders} as typed (web does not fill them in)', () {
      final html = buildEmailPreviewHtml('Dear {EMPLOYEE_NAME}, {MONTH}');
      expect(html, contains('Dear {EMPLOYEE_NAME}, {MONTH}'));
    });

    test('has a restrictive CSP and a viewport meta', () {
      final html = buildEmailPreviewHtml('x');
      expect(
          html,
          contains('<meta http-equiv="Content-Security-Policy" content="default-src \'none\'; '
              'img-src https: http: data:; style-src \'unsafe-inline\'; font-src https: data:">'));
      expect(html, contains('<meta name="viewport" content="width=device-width,initial-scale=1">'));
      expect(html, isNot(contains('script-src')));
    });

    test('the wrapper introduces no script, frame, form, link or external stylesheet', () {
      final html = buildEmailPreviewHtml('plain', company: company(website: 'https://a.example', address: '1 St'));
      for (final bad in ['<script', '<iframe', '<form', '<link', '<object', '<embed', '@import', 'javascript:']) {
        expect(html.toLowerCase(), isNot(contains(bad)), reason: bad);
      }
    });

    test('responsive CSS: wide tables, long URLs and images cannot force sideways scrolling', () {
      final html = buildEmailPreviewHtml('x');
      expect(html, contains('img { max-width:100%; height:auto; }'));
      expect(html, contains('table { max-width:100%; }'));
      expect(html, contains('overflow-wrap:anywhere'));
      expect(html, contains('word-break:break-word'));
      expect(html, contains('background:#f4f4f7'));
      expect(html, contains('margin:0'));
    });

    test('hostile company fields are escaped, never executed', () {
      final html = buildEmailPreviewHtml('b',
          company: company(
            name: '"><script>alert(1)</script>',
            website: '<img src=x onerror=alert(2)>',
            address: "'; DROP --",
            city: '<b>City</b>',
            state: 'A&B',
          ));
      expect(html, isNot(contains('<script')));
      expect(html, isNot(contains('<img src=x')));
      expect(html, isNot(contains('<b>City</b>')));
      expect(html, contains('&quot;&gt;&lt;script&gt;alert(1)&lt;/script&gt;'));
      expect(html, contains('&lt;img src=x onerror=alert(2)&gt;'));
      expect(html, contains('&#39;; DROP --'));
      expect(html, contains('A&amp;B'));
    });

    group('logo', () {
      test('an https logo is used, attribute-safely', () {
        final html = buildEmailPreviewHtml('b', company: company(logo: 'https://cdn.example/l.png?a=1&b=2'));
        expect(html, contains('<img src="https://cdn.example/l.png?a=1&amp;b=2" alt="Acme Test Pvt Ltd"'));
        expect(html, isNot(contains('font-size:18px;font-weight:700')), reason: 'no name fallback when a logo is used');
      });

      test('http and data:image logos are used', () {
        expect(buildEmailPreviewHtml('b', company: company(logo: 'http://x.example/l.png')),
            contains('src="http://x.example/l.png"'));
        expect(buildEmailPreviewHtml('b', company: company(logo: 'data:image/png;base64,AAAA')),
            contains('src="data:image/png;base64,AAAA"'));
      });

      test('other schemes fall back to the company name', () {
        for (final bad in [
          'javascript:alert(1)',
          'data:text/html;base64,AAAA',
          'file:///etc/passwd',
          '//x/l.png',
          'ftp://x/l.png'
        ]) {
          final html = buildEmailPreviewHtml('b', company: company(logo: bad));
          expect(html, isNot(contains('<img')), reason: bad);
          expect(html, contains('font-size:18px;font-weight:700'), reason: bad);
        }
      });

      test('a quote in the URL cannot break out of the attribute', () {
        final html = buildEmailPreviewHtml('b', company: company(logo: 'https://x.example/a"onerror="alert(1)'));
        expect(html, isNot(contains('"onerror=')));
        expect(html, contains('&quot;onerror=&quot;'));
      });
    });

    group('header and footer', () {
      test('no logo: the company name is the header', () {
        expect(buildEmailPreviewHtml('b', company: company()), contains('>Acme Test Pvt Ltd</span>'));
      });

      test('footer is website | address (address = address, city, state)', () {
        final html = buildEmailPreviewHtml('b',
            company: company(website: 'https://a.example', address: '1 Main St', city: 'Pune', state: 'MH'));
        expect(html, contains('https://a.example &nbsp;|&nbsp; 1 Main St, Pune, MH'));
      });

      test('footer: only a website, or only an address', () {
        final w = buildEmailPreviewHtml('b', company: company(website: 'https://a.example'));
        expect(w, contains('>\n      https://a.example\n    </div>'));
        expect(w, isNot(contains('&nbsp;|&nbsp;')));
        final a = buildEmailPreviewHtml('b', company: company(city: 'Pune'));
        expect(a, contains('>\n      Pune\n    </div>'));
      });

      test('footer falls back to the company name; and name to [Company]', () {
        final n = buildEmailPreviewHtml('b', company: company());
        expect(n, contains('>\n      Acme Test Pvt Ltd\n    </div>'));
        for (final c in [null, company(name: ''), company(name: '   ')]) {
          final html = buildEmailPreviewHtml('b', company: c);
          expect(html, contains('>[Company]</span>'));
          expect(html, contains('>\n      [Company]\n    </div>'));
        }
      });
    });
  });

  group('emailPreviewPlainText', () {
    test('strips tags, decodes entities, keeps paragraphs and bullets, collapses space', () {
      const html = '<style>p{color:red}</style><p>Hello&nbsp;&nbsp;<b>World</b> &amp; co &#8211; &#x2014; ok</p>'
          '<p>Second</p><ul><li>One</li><li>Two</li></ul><script>bad()</script>'
          'Line<br>Break\n\n\n\n<!-- hidden -->End &unknown;';
      final t = emailPreviewPlainText(html);
      expect(t, contains('Hello World & co – — ok'));
      expect(t, contains('• One'));
      expect(t, contains('• Two'));
      expect(t, contains('Line\nBreak'));
      expect(t, isNot(contains('<')));
      expect(t, isNot(contains('color:red')));
      expect(t, isNot(contains('bad()')));
      expect(t, isNot(contains('hidden')));
      expect(t, isNot(contains('\n\n\n')));
      expect(t, contains('&unknown;'), reason: 'unknown entities stay as typed');
      expect(t.startsWith('Hello'), isTrue);
    });

    test('empty and tag-only bodies give empty text', () {
      expect(emailPreviewPlainText(''), '');
      expect(emailPreviewPlainText('<div><p></p></div>'), '');
    });
  });

  group('TemplatePreviewScreen', () {
    final base = etModel(
      body: '<h2>Payslip</h2><p>Hello {EMPLOYEE_NAME}</p>',
      attachments: [
        {
          'id': 3,
          'filename': 'policy.pdf',
          'mime_type': 'application/pdf',
          'size': 10,
          'url': 'https://f.example/p.pdf'
        }
      ],
    );

    testWidgets('shows name, category, status, subject, variables and attachment names', (t) async {
      await open(t, template: (base));
      expect(find.text('Preview — Pay Slip'), findsOneWidget, reason: 'app bar');
      expect(_k('et-preview-name'), findsOneWidget);
      expect(find.text('Document Templates'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Built-in'), findsNothing);
      expect(find.text('Your payslip for {MONTH}'), findsOneWidget);
      expect(find.text('{EMPLOYEE_NAME}'), findsOneWidget);
      expect(find.text('{MONTH}'), findsOneWidget);
      expect(_k('et-preview-attachment-3'), findsOneWidget);
      expect(find.text('policy.pdf'), findsOneWidget);
      expect(find.text('Rendered'), findsOneWidget);
      expect(find.text('Text'), findsOneWidget);
    });

    testWidgets('inactive and built-in templates say so', (t) async {
      await open(t, template: (etModel(active: false, builtin: true)));
      expect(find.text('Inactive'), findsOneWidget);
      expect(find.text('Built-in'), findsOneWidget);
      expect(find.text('Active'), findsNothing);
    });

    testWidgets('no variables / attachments: those sections are absent', (t) async {
      await open(t, template: (etModel(vars: const [])));
      expect(_k('et-preview-variables'), findsNothing);
      expect(find.text('ATTACHMENTS'), findsNothing);
    });

    testWidgets('the rendered view is handed the wrapped HTML with the company header and footer', (t) async {
      await open(t, template: (base));
      final html = shown(t);
      expect(html, contains('<h2>Payslip</h2><p>Hello {EMPLOYEE_NAME}</p>'));
      expect(html, contains('Acme Test Pvt Ltd'));
      expect(html, contains('https://acme.example.test &nbsp;|&nbsp; 1 Test Street, Pune, MH'));
      expect(html, contains('Content-Security-Policy'));
    });

    testWidgets('a company that fails to load still previews, with web\'s [Company] default', (t) async {
      final s = EtBackend()..companyStatus = 500;
      await open(t, backend: s, template: (base));
      expect(shown(t), contains('[Company]'));
      expect(shown(t), contains('Hello {EMPLOYEE_NAME}'));
      expect(t.takeException(), isNull);
    });

    testWidgets('Rendered | Text toggle: text mode shows readable selectable text and hides the view', (t) async {
      await open(t, template: (base));
      expect(_k('et-preview-rendered'), findsOneWidget);
      expect(_k('et-preview-text'), findsNothing);

      await t.tap(_k('et-preview-mode-text'));
      await t.pumpAndSettle();
      expect(_k('et-preview-rendered'), findsNothing);
      expect(_k('standin'), findsNothing);
      expect(_k('et-preview-text'), findsOneWidget);
      expect(find.byType(SelectableText), findsWidgets);
      expect(find.textContaining('Payslip'), findsWidgets);
      expect(find.textContaining('<h2>'), findsNothing, reason: 'tags stripped');

      await t.tap(_k('et-preview-mode-rendered'));
      await t.pumpAndSettle();
      expect(_k('et-preview-rendered'), findsOneWidget);
      expect(_k('et-preview-text'), findsNothing);
    });

    testWidgets('text mode of an empty body says so', (t) async {
      await open(t, template: (etModel(body: '')));
      await t.tap(_k('et-preview-mode-text'));
      await t.pumpAndSettle();
      expect(find.text('This template has no body.'), findsOneWidget);
    });

    testWidgets('Edit Template pops with TemplatePreviewResult.edit', (t) async {
      await open(t, template: (base));
      await t.tap(_k('et-preview-edit'));
      await t.pumpAndSettle();
      expect(hostResult(t), TemplatePreviewResult.edit);
      expect(_k('et-preview-edit'), findsNothing);
    });

    testWidgets('Close and the back arrow pop with null', (t) async {
      await open(t, template: (base));
      await t.tap(_k('et-preview-close'));
      await t.pumpAndSettle();
      expect(hostResult(t), isNull);

      await t.tap(_k('host-open'));
      await t.pumpAndSettle();
      await t.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await t.pumpAndSettle();
      expect(hostResult(t), isNull);
    });

    testWidgets('a very long subject, long variable names and long filenames wrap — no overflow (320dp, 2x text)',
        (t) async {
      final long = etModel(
        subject:
            'Your quarterly performance review summary and compensation revision letter for the period ${'ending ' * 8}March',
        vars: const ['A_VERY_LONG_VARIABLE_NAME_THAT_KEEPS_GOING_AND_GOING_FOR_ETERNITY', 'SHORT'],
        displayName: 'Quarterly Performance Review And Compensation Revision Notification',
        attachments: [
          {
            'id': 1,
            'filename': 'a-really-long-attachment-file-name-for-the-annual-report-final-v3.pdf',
            'mime_type': 'application/pdf',
            'size': 5,
            'url': 'https://f.example/x.pdf'
          }
        ],
      );
      await open(t, size: const Size(320, 568), scale: 2, template: (long));
      expect(t.takeException(), isNull);
      // 2x text on a short screen: details start collapsed so the email gets the room.
      expect(_k('et-preview-details'), findsNothing);
      await t.tap(_k('et-preview-details-toggle'));
      await t.pumpAndSettle();
      expect(_k('et-preview-details'), findsOneWidget);
      expect(t.takeException(), isNull);
      expect(_k('et-preview-rendered'), findsOneWidget);
    });

    testWidgets('details toggle hides and shows the metadata; roomy screens start open', (t) async {
      await open(t, template: (base));
      expect(_k('et-preview-details'), findsOneWidget);
      await t.tap(_k('et-preview-details-toggle'));
      await t.pumpAndSettle();
      expect(_k('et-preview-details'), findsNothing);
      expect(_k('et-preview-rendered'), findsOneWidget, reason: 'the email is still there');
      await t.tap(_k('et-preview-details-toggle'));
      await t.pumpAndSettle();
      expect(_k('et-preview-details'), findsOneWidget);
    });

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
            'responsive ${size.width.toInt()}x${size.height.toInt()} @${scale}x: no overflow, buttons reachable',
            (t) async {
          await open(t, size: size, scale: scale, template: (base));
          expect(t.takeException(), isNull);
          expect(_k('et-preview-edit'), findsOneWidget);
          expect(_k('et-preview-close'), findsOneWidget);
          final edit = t.getRect(_k('et-preview-edit'));
          expect(edit.height, greaterThanOrEqualTo(48));
          expect(edit.bottom, lessThanOrEqualTo(size.height));
          expect(edit.right, lessThanOrEqualTo(size.width));
          final view = t.getRect(_k('et-preview-rendered'));
          expect(view.height, greaterThan(60), reason: 'the email keeps usable height');
          await t.tap(_k('et-preview-mode-text'));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        });
      }
    }
  });
}
