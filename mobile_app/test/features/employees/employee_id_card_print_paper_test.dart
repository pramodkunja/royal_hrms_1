import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mobile_app/features/employees/data/models/employee_id_card_model.dart';
import 'package:mobile_app/features/employees/presentation/id_card/id_card_pdf.dart';
import 'package:mobile_app/features/employees/presentation/id_card/id_card_text.dart';
import 'package:pdf/pdf.dart';

// Task 31.2: Card-layout printing on the paper Android's print system picks
// (it has no 50 × 85 mm size). Each page is the selected paper; each face is
// exactly 50 × 85 mm, centred, never scaled. Measured from the saved PDF
// itself: page MediaBoxes, and the card face's position, size and transform
// read from the page content streams. Synthetic data only.

const mm = PdfPageFormat.mm;
const cardW = 50 * mm, cardH = 85 * mm;

/// A page's MediaBox and the card faces drawn on it.
class PdfPageInfo {
  PdfPageInfo(this.width, this.height, this.faces);
  final double width, height;
  final List<FacePlacement> faces;
}

/// Where a card face (its white 50 × 85 mm background) was painted: bottom
/// left corner, size after the current transform, and whether any scaling /
/// rotation was in effect.
class FacePlacement {
  FacePlacement(this.x, this.y, this.w, this.h, this.transformed);
  final double x, y, w, h;
  final bool transformed;
  @override
  String toString() => 'face @($x, $y) $w × $h${transformed ? ' (transformed)' : ''}';
}

/// Reads page sizes and card-face placements from the PDF bytes: decodes each
/// page's content stream and tracks q/Q/cm to the face rectangle's fill.
List<PdfPageInfo> inspect(Uint8List bytes) {
  final raw = latin1.decode(bytes);
  final boxes = RegExp(r'/MediaBox\s*\[([^\]]*)\]')
      .allMatches(raw)
      .map((m) => m.group(1)!.trim().split(RegExp(r'\s+')).map(double.parse).toList())
      .toList();
  final contents = <String>[];
  for (final m in RegExp('stream\r?\n').allMatches(raw)) {
    final end = raw.indexOf('endstream', m.end);
    try {
      final d = latin1.decode(zlib.decode(bytes.sublist(m.end, end)));
      if (d.startsWith('0 Tr') || d.contains(' cm')) contents.add(d);
    } catch (_) {}
  }
  expect(contents, hasLength(boxes.length), reason: 'one content stream per page');
  return [
    for (final (i, b) in boxes.indexed) PdfPageInfo(b[2] - b[0], b[3] - b[1], _faces(contents[i])),
  ];
}

List<FacePlacement> _faces(String content) {
  // Current transform as [a, b, c, d, e, f].
  var m = [1.0, 0.0, 0.0, 1.0, 0.0, 0.0];
  final stack = <List<double>>[];
  final nums = <double>[];
  final faces = <FacePlacement>[];
  List<double>? pendingRect;
  for (final tok in content.split(RegExp(r'\s+'))) {
    final n = double.tryParse(tok);
    if (n != null) {
      nums.add(n);
      continue;
    }
    switch (tok) {
      case 'q':
        stack.add(List.of(m));
      case 'Q':
        m = stack.removeLast();
      case 'cm':
        final [a, b, c, d, e, f] = nums.sublist(nums.length - 6);
        m = [
          a * m[0] + b * m[2],
          a * m[1] + b * m[3],
          c * m[0] + d * m[2],
          c * m[1] + d * m[3],
          e * m[0] + f * m[2] + m[4],
          e * m[1] + f * m[3] + m[5],
        ];
      case 're':
        final r = nums.sublist(nums.length - 4);
        pendingRect = ((r[2] - cardW).abs() < .01 && (r[3] - cardH).abs() < .01) ? r : null;
      case 'f':
        if (pendingRect != null) {
          final r = pendingRect;
          final transformed =
              (m[0] - 1).abs() > 1e-6 || m[1].abs() > 1e-6 || m[2].abs() > 1e-6 || (m[3] - 1).abs() > 1e-6;
          faces.add(FacePlacement(m[0] * r[0] + m[2] * r[1] + m[4], m[1] * r[0] + m[3] * r[1] + m[5], r[2] * m[0],
              r[3] * m[3], transformed));
        }
        pendingRect = null;
      case 'rg' || 'RG' || 'cs' || 'scn':
        break; // colour set between the rectangle and its fill
      default:
        if (tok != 'W' && tok != 'n') pendingRect = null;
    }
    nums.clear(); // any operator consumes its operands
  }
  return faces;
}

Map<String, dynamic> cardJson({String name = 'Nia Test', String address = '12 Test Lane, Pune'}) => {
      'employee': {
        'employee_id': 'EMP-7',
        'full_name': name,
        'designation': 'QA Analyst',
        'department': 'Quality',
        'date_of_joining': '05/01/2026',
        'blood_group': 'O+',
        'location': 'Pune',
        'residential_address': address,
        'phone': '9000000007',
        'email': 'nia.test@example.test',
      },
      'company': {'name': 'Test Co', 'website': 'testco.example', 'office_address': '1 Office Road, Pune'},
      'card': {
        'terms': ['This card is the property of Test Co.'],
        'signatory_label': 'Authorised Signatory'
      },
    };

Future<IdCardTextImage> fakeRaster(IdCardTextSpec s) async =>
    IdCardTextImage(Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 2))), s.widthMm, s.sizeMm * 1.4);

late IdCardPdfAssets assets;
final data = IdCardData.fromJson(cardJson());

Future<List<PdfPageInfo>> cardOn(PdfPageFormat? paper,
        {IdCardData? d, IdCardPrintLayout layout = IdCardPrintLayout.card}) async =>
    inspect(await buildIdCardPdf(d ?? data, layout, assets, rasterize: fakeRaster, paper: paper));

void expectCentredCards(List<PdfPageInfo> pages, PdfPageFormat paper) {
  expect(pages, hasLength(2), reason: 'front and back on separate pages');
  for (final p in pages) {
    expect(p.width, closeTo(paper.width, .01));
    expect(p.height, closeTo(paper.height, .01));
    expect(p.faces, hasLength(1), reason: 'one face per page');
    final f = p.faces.single;
    expect(f.transformed, isFalse, reason: 'no scaling: $f');
    expect(f.w, closeTo(cardW, .01));
    expect(f.h, closeTo(cardH, .01));
    expect(f.x, closeTo((paper.width - cardW) / 2, .01), reason: 'centred horizontally');
    expect(f.y, closeTo((paper.height - cardH) / 2, .01), reason: 'centred vertically');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final f = await loadBundledIdCardFonts();
    assets = IdCardPdfAssets(base: f.base, bold: f.bold);
  });

  group('card layout printed on the selected paper', () {
    test('Letter: two Letter pages, each with one exact 50 × 85 mm face in the centre', () async {
      expectCentredCards(await cardOn(PdfPageFormat.letter), PdfPageFormat.letter);
    });

    test('A4 paper (card layout): centred 50 × 85 mm face per A4 page', () async {
      expectCentredCards(await cardOn(PdfPageFormat.a4), PdfPageFormat.a4);
    });

    final papers = {
      'A5': PdfPageFormat.a5,
      'A6': PdfPageFormat.a6,
      'Legal': PdfPageFormat.legal,
      '4 × 6 in photo': const PdfPageFormat(4 * PdfPageFormat.inch, 6 * PdfPageFormat.inch),
      'A4 landscape': PdfPageFormat.a4.landscape,
      'CR80 card (54 × 86 mm)': const PdfPageFormat(54 * mm, 85.6 * mm),
      'exactly 50 × 85 mm': const PdfPageFormat(cardW, cardH),
    };
    for (final MapEntry(key: name, value: paper) in papers.entries) {
      test('$name: centred, actual size, not enlarged', () async {
        expectCentredCards(await cardOn(paper), paper);
      });
    }

    test('Android-rounded 50 × 85 mm (whole mils, ~0.01 mm short): page = card, face not squeezed', () async {
      expectCentredCards(
          await cardOn(const PdfPageFormat(1968 * 72 / 1000, 3346 * 72 / 1000)), const PdfPageFormat(cardW, cardH));
    });

    test('printer margins in the reported format are ignored for the page size (page = paper)', () async {
      final withMargins =
          PdfPageFormat.letter.copyWith(marginLeft: 20, marginTop: 30, marginRight: 20, marginBottom: 30);
      expectCentredCards(await cardOn(withMargins), PdfPageFormat.letter);
    });

    for (final (name, paper) in [
      ('ISO A8 (52 × 74 mm)', const PdfPageFormat(52 * mm, 74 * mm)),
      ('card-size landscape (85 × 50 mm)', const PdfPageFormat(85 * mm, 50 * mm)),
      ('49 × 85 mm', const PdfPageFormat(49 * mm, 85 * mm)),
    ]) {
      test('paper smaller than the card ($name) fails clearly — no PDF, no scaling', () async {
        await expectLater(
          buildIdCardPdf(data, IdCardPrintLayout.card, assets, rasterize: fakeRaster, paper: paper),
          throwsA(isA<IdCardPaperTooSmall>().having((e) => e.message, 'message',
              allOf(contains('smaller than the 50 × 85 mm ID card'), contains('Choose a larger paper size')))),
        );
      });
    }

    test('the message names the selected paper in mm', () {
      expect(const IdCardPaperTooSmall(PdfPageFormat(52 * mm, 74 * mm)).message,
          startsWith('The selected paper (52 × 74 mm)'));
      expect(idCardFitsOn(PdfPageFormat.a6), isTrue);
      expect(idCardFitsOn(const PdfPageFormat(52 * mm, 74 * mm)), isFalse);
    });
  });

  group('unchanged paths', () {
    test('Share PDF (no paper): two pages that ARE the card, 50 × 85 mm, face at the origin', () async {
      final pages = await cardOn(null);
      expectCentredCards(pages, const PdfPageFormat(cardW, cardH));
      for (final p in pages) {
        expect(p.faces.single.x, closeTo(0, .01));
        expect(p.faces.single.y, closeTo(0, .01));
      }
    });

    for (final paper in [null, PdfPageFormat.letter]) {
      test(
          'A4 sheet layout${paper == null ? '' : ' (paper ignored: Letter)'}: one A4 page, both faces at '
          'actual size side by side 10 mm apart with 1 mm cut-guide padding', () async {
        final pages = await cardOn(paper, layout: IdCardPrintLayout.a4);
        expect(pages, hasLength(1));
        final p = pages.single;
        expect(p.width, closeTo(PdfPageFormat.a4.width, .01));
        expect(p.height, closeTo(PdfPageFormat.a4.height, .01));
        expect(p.faces, hasLength(2));
        final [front, back] = p.faces;
        for (final f in p.faces) {
          expect(f.transformed, isFalse);
          expect(f.w, closeTo(cardW, .01));
          expect(f.h, closeTo(cardH, .01));
          // Top edge: 15 mm margin + 1 mm guide padding (+ guide border).
          expect(PdfPageFormat.a4.height - (f.y + f.h), closeTo(16 * mm, .5 * mm));
        }
        // Faces 10 mm apart plus each guide's 1 mm padding (and border).
        expect(back.x - (front.x + cardW), closeTo(12 * mm, .5 * mm));
        // Centred as a pair.
        expect(front.x + (back.x + cardW) - PdfPageFormat.a4.width, closeTo(0, .01));
        expect(front.y, closeTo(back.y, .01));
      });
    }
  });

  group('Unicode and long text still render on the selected paper', () {
    test('Devanagari card on Letter: texts drawn as images, faces exact and centred', () async {
      final hi = IdCardData.fromJson(cardJson(name: 'अनन्या शर्मा', address: 'फ्लैट 12, शिवाजी नगर, पुणे 411005'));
      final drawn = <String>[];
      final bytes =
          await buildIdCardPdf(hi, IdCardPrintLayout.card, assets, paper: PdfPageFormat.letter, rasterize: (s) {
        if (!s.isIcon) drawn.add(s.text);
        return fakeRaster(s);
      });
      expect(drawn, unorderedEquals(['अनन्या शर्मा', 'फ्लैट 12, शिवाजी नगर, पुणे 411005']));
      expectCentredCards(inspect(bytes), PdfPageFormat.letter);
      expect(latin1.decode(bytes), contains('NotoSans'));
    });

    test('very long multilingual text on A4 paper: faces stay exact and centred', () async {
      final long = IdCardData.fromJson(cardJson(
        name: 'Venkata Subramanian Lakshminarayanan Raghavendra Krishnamurthy',
        address: 'फ्लैट 1204, टावर बी, लॉन्ग रेजीडेंसी कॉम्प्लेक्स, पुणे — Flat 1204, Tower B, Long Residency ' * 3,
      ));
      expectCentredCards(await cardOn(PdfPageFormat.a4, d: long), PdfPageFormat.a4);
    });
  });
}
