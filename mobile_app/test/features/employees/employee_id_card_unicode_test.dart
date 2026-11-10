import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mobile_app/features/employees/data/models/employee_id_card_model.dart';
import 'package:mobile_app/features/employees/presentation/id_card/id_card_faces.dart';
import 'package:mobile_app/features/employees/presentation/id_card/id_card_pdf.dart';
import 'package:mobile_app/features/employees/presentation/id_card/id_card_spec.dart';
import 'package:mobile_app/features/employees/presentation/id_card/id_card_text.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// Task 31.1: the ID card PDF with the bundled Noto Sans (offline, embedded)
// and non-Latin text (Devanagari) drawn by Flutter's text engine and placed
// as images; long text wraps and is scaled to fit instead of cut off.
// Synthetic data only.

Map<String, dynamic> cardJson({
  String name = 'Nia Test',
  String designation = 'QA Analyst',
  String address = '12 Test Lane, Pune',
  String office = '1 Office Road, Pune',
  String location = 'Pune',
  List<String> terms = const ['This card is the property of Test Co.'],
  String signatory = 'Authorised Signatory',
}) =>
    {
      'employee': {
        'employee_id': 'EMP-7',
        'full_name': name,
        'designation': designation,
        'department': 'Quality',
        'date_of_joining': '05/01/2026',
        'date_of_birth': '01/02/1995',
        'blood_group': 'O+',
        'location': location,
        'residential_address': address,
        'phone': '9000000007',
        'email': 'nia.test@example.test',
      },
      'company': {'name': 'Test Co', 'website': 'testco.example', 'office_address': office},
      'card': {'terms': terms, 'signatory_label': signatory},
      'missing': <String>[],
    };

const hindiName = 'अनन्या शर्मा';
const hindiAddress = 'फ्लैट 12, शिवाजी नगर, पुणे, महाराष्ट्र 411005';
const marathiDesignation = 'गुणवत्ता विश्लेषक';

/// Records what it is asked to draw; returns a small real PNG of the box size.
class FakeRasterizer {
  final calls = <IdCardTextSpec>[];
  Future<IdCardTextImage> call(IdCardTextSpec s) async {
    calls.add(s);
    final png = Uint8List.fromList(img.encodePng(img.Image(width: 8, height: 2)));
    return IdCardTextImage(png, s.widthMm, s.sizeMm * 1.4);
  }
}

late IdCardPdfAssets assets;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final f = await loadBundledIdCardFonts();
    assets = IdCardPdfAssets(base: f.base, bold: f.bold);
  });

  group('bundled fonts (offline)', () {
    test('Noto Sans regular + bold load from the app bundle, not the network or Helvetica', () async {
      final f = await loadBundledIdCardFonts();
      expect(f.base, isA<pw.TtfFont>());
      expect(f.bold, isA<pw.TtfFont>());
      expect(f.base.fontName, contains('NotoSans'));
      expect(f.bold.fontName, contains('Bold'));
    });

    test('font files and their SIL OFL licences are bundled and declared in pubspec', () {
      for (final name in [
        'NotoSans-Regular.ttf',
        'NotoSans-Bold.ttf',
        'NotoSansDevanagari-Regular.ttf',
        'NotoSansDevanagari-Bold.ttf',
        'OFL-NotoSans.txt',
        'OFL-NotoSansDevanagari.txt',
      ]) {
        expect(File('assets/fonts/$name').existsSync(), isTrue, reason: name);
      }
      expect(File('assets/fonts/OFL-NotoSansDevanagari.txt').readAsStringSync(), contains('SIL OPEN FONT LICENSE'));
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('family: NotoSans\n'));
      expect(pubspec, contains('family: NotoSansDevanagari'));
      expect(pubspec, contains('- assets/fonts/'));
    });

    test('the Noto Sans font is embedded in the saved PDF', () async {
      final bytes = await buildIdCardPdf(IdCardData.fromJson(cardJson()), IdCardPrintLayout.card, assets,
          rasterize: FakeRasterizer().call);
      expect(latin1.decode(bytes), contains('NotoSans'));
      expect(latin1.decode(bytes), isNot(contains('Helvetica')));
    });
  });

  group('which text needs shaping', () {
    test('Latin, accented Latin, Greek, Cyrillic and punctuation stay PDF text; Indic and CJK do not', () {
      for (final t in ['EMP-7', 'Nia Test', 'José Müller-Øster', 'Ελένη', 'Иван', '12 Test Lane, Pune – 411005 ₹']) {
        expect(idCardNeedsShapedText(t), isFalse, reason: t);
      }
      for (final t in [hindiName, hindiAddress, 'Asha / आशा', 'ગુજરાત', 'தமிழ்', 'বাংলা', '山田']) {
        expect(idCardNeedsShapedText(t), isTrue, reason: t);
      }
    });

    test('an all-English card needs no text images (everything is real PDF text)', () {
      expect(idCardShapedTextSpecs(IdCardData.fromJson(cardJson()), assets).where((s) => !s.isIcon), isEmpty);
    });

    test('icons are drawn by Flutter (Material Icons is CFF, which the pdf package cannot embed)', () async {
      final specs = idCardShapedTextSpecs(IdCardData.fromJson(cardJson()), assets).where((s) => s.isIcon).toList();
      expect(specs.map((s) => s.fontFamily).toSet(), {'MaterialIcons'});
      // Every card icon: 6 rows, 3 back sections, website, empty photo.
      expect(specs.map((s) => s.text.runes.single).toSet(),
          {for (final i in IdCardIcon.values) IdCardSpec.icon(i).codePoint});
      final r = FakeRasterizer();
      final bytes =
          await buildIdCardPdf(IdCardData.fromJson(cardJson()), IdCardPrintLayout.card, assets, rasterize: r.call);
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
      expect(r.calls.where((s) => s.isIcon), hasLength(specs.length));
    });
  });

  group('Devanagari card', () {
    final data = IdCardData.fromJson(cardJson(
      name: hindiName,
      designation: marathiDesignation,
      address: hindiAddress,
      location: 'पुणे',
      signatory: 'अधिकृत स्वाक्षरीकर्ता',
    ));

    test('exactly the Devanagari texts are drawn as images, each at its box width', () {
      final specs = idCardShapedTextSpecs(data, assets).where((s) => !s.isIcon);
      final byText = {for (final s in specs) s.text: s};
      expect(byText.keys,
          unorderedEquals([hindiName, marathiDesignation, hindiAddress, 'Location: पुणे', 'अधिकृत स्वाक्षरीकर्ता']));
      expect(byText[hindiName]!.bold, isTrue);
      expect(byText[hindiName]!.align, TextAlign.center);
      expect(byText[hindiName]!.widthMm, closeTo(IdCardSpec.cardW - 2 * IdCardSpec.sidePad, 1e-9));
      expect(byText[hindiName]!.sizeMm, IdCardSpec.nameSize);
      expect(
          byText[hindiAddress]!.widthMm,
          closeTo(IdCardSpec.cardW - IdCardSpec.backLeft - IdCardSpec.backRight - IdCardSpec.secIco - IdCardSpec.secGap,
              1e-9));
      expect(
          byText['Location: पुणे']!.widthMm,
          closeTo(IdCardSpec.cardW - IdCardSpec.rowsLeft - IdCardSpec.rowsRight - IdCardSpec.rowIco - IdCardSpec.rowGap,
              1e-9));
      expect(byText['अधिकृत स्वाक्षरीकर्ता']!.shrinkWrap, isTrue);
    });

    for (final layout in IdCardPrintLayout.values) {
      test('${layout.name} layout: every Devanagari text is rasterised once and the PDF saves', () async {
        final r = FakeRasterizer();
        final bytes = await buildIdCardPdf(data, layout, assets, rasterize: r.call);
        expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
        final texts = r.calls.where((s) => !s.isIcon).map((s) => s.text).toList();
        expect(texts.toSet(), hasLength(5));
        expect(texts, hasLength(5));
        // Images embedded: one XObject per drawn text, per face it appears on.
        expect(RegExp(r'/Subtype\s*/Image').allMatches(latin1.decode(bytes)).length, greaterThanOrEqualTo(5));
      });
    }

    test('page sizes are unchanged: card 2 × 50 × 85 mm, A4 one page', () {
      final card = buildIdCardDocument(data, IdCardPrintLayout.card, assets).document.pdfPageList.pages;
      expect(card, hasLength(2));
      for (final p in card) {
        expect(p.pageFormat.width, closeTo(50 * PdfPageFormat.mm, .01));
        expect(p.pageFormat.height, closeTo(85 * PdfPageFormat.mm, .01));
      }
      final a4 = buildIdCardDocument(data, IdCardPrintLayout.a4, assets).document.pdfPageList.pages;
      expect(a4, hasLength(1));
      expect(a4.single.pageFormat.width, closeTo(PdfPageFormat.a4.width, .01));
    });

    testWidgets('the real rasteriser (Flutter text engine) produces a 600 dpi PNG of the box', (tester) async {
      const spec = IdCardTextSpec(text: hindiName, sizeMm: IdCardSpec.nameSize, widthMm: 44, bold: true);
      final out = (await tester.runAsync(() => rasterizeIdCardText(spec)))!;
      final decoded = img.decodePng(out.png)!;
      expect(decoded.width, closeTo(44 * 600 / 25.4, 1));
      expect(out.widthMm, closeTo(44, .05));
      expect(out.heightMm, greaterThan(IdCardSpec.nameSize * .9));
      expect(decoded.height, closeTo(out.heightMm * 600 / 25.4, 1));
      final inked = decoded.where((p) => p.a > 0).length;
      expect(inked, greaterThan(0), reason: 'text pixels drawn');

      final narrow = (await tester.runAsync(
          () => rasterizeIdCardText(const IdCardTextSpec(text: 'पुणे', sizeMm: 1.7, widthMm: 40, shrinkWrap: true))))!;
      expect(narrow.widthMm, lessThan(40), reason: 'shrink-wrapped to the text');
    });
  });

  group('long multilingual text (no silent clipping)', () {
    final terms = [
      for (var i = 0; i < 8; i++)
        i.isEven ? 'Return this card to HR on separation. ' * 2 : 'कार्ड गुम होने पर तुरंत एचआर को सूचित करें। ' * 2,
    ];
    final data = IdCardData.fromJson(cardJson(
      name: 'Venkata Subramanian Lakshminarayanan Raghavendra Krishnamurthy',
      designation: 'Senior Principal Quality Assurance Automation Engineer',
      address: '${hindiAddress * 3} Flat 1204, Tower B, Long Residency Complex, Pune 411005',
      office: 'Plot 77, Phase III, Hinjewadi Rajiv Gandhi Infotech Park, Maan, Mulshi, Pune, Maharashtra 411057',
      terms: terms,
    ));

    test('every text is kept — none dropped — and each card face is still exactly 50 × 85 mm', () async {
      final r = FakeRasterizer();
      final bytes = await buildIdCardPdf(data, IdCardPrintLayout.card, assets, rasterize: r.call);
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
      final drawn = r.calls.map((s) => s.text).toSet();
      expect(drawn, containsAll([data.employee.residentialAddress, terms[1]]));
      final pages = buildIdCardDocument(data, IdCardPrintLayout.card, assets).document.pdfPageList.pages;
      expect(pages, hasLength(2));
      for (final p in pages) {
        expect(p.pageFormat.height, closeTo(85 * PdfPageFormat.mm, .01));
      }
    });

    test('A4 sheet with guides still lays out on one page', () async {
      final bytes = await buildIdCardPdf(data, IdCardPrintLayout.a4, assets, rasterize: FakeRasterizer().call);
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    });

    testWidgets('preview: long and Devanagari text wraps in full and fits the card (no overflow)', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              IdCardFrontFace(data: data, scale: 6),
              IdCardBackFace(data: data, scale: 6),
            ]),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      final name = tester.widget<Text>(find.byKey(const Key('idc-name')));
      expect(name.data, data.employee.fullName!.toUpperCase());
      expect(name.maxLines, isNull, reason: 'wraps instead of ellipsis');
      expect(tester.getSize(find.byType(IdCardFrontFace)), const Size(300, 510));
      expect(tester.getSize(find.byType(IdCardBackFace)), const Size(300, 510));
      expect(find.text(terms[1]), findsWidgets);
    });
  });
}
