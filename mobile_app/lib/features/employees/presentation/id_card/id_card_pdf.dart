import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui show TextAlign;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show IconData;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/network/api_client.dart';
import '../../data/models/employee_id_card_model.dart';
import 'id_card_spec.dart';
import 'id_card_text.dart';

// The printable ID card — what web prints with window.print() from
// IdCardPrintSheet + idCardPrintCss: the same front/back template at exactly
// 50 × 85 mm, as a real PDF.
//  - card: one face per page, page = 50 × 85 mm, no margin.
//  - a4:   both faces side by side at actual size on one A4 page (15 mm
//          margin, 10 mm apart) with dashed cut guides 1 mm outside.
// Text is the bundled Noto Sans (offline, embedded in the PDF). Text in other
// scripts (Devanagari, …) is drawn by Flutter and embedded as a 600 dpi image
// — see id_card_text.dart. Long text wraps; a face whose content is taller
// than the card is scaled down to fit rather than cut off.

typedef _S = IdCardSpec;

double _mm(double v) => v * PdfPageFormat.mm;

PdfColor _c(int argb) => PdfColor.fromInt(argb);
final _navy = _c(0xFF111C3D);
final _gold = _c(0xFFB8862B);
final _termsGold = _c(0xFFC8963A);
const _white = PdfColors.white;

/// Page size for each layout (what the print dialog is given).
PdfPageFormat idCardPageFormat(IdCardPrintLayout layout) => layout == IdCardPrintLayout.card
    ? PdfPageFormat(_mm(_S.cardW), _mm(_S.cardH))
    : PdfPageFormat.a4.copyWith(marginLeft: _mm(15), marginRight: _mm(15), marginTop: _mm(15), marginBottom: _mm(15));

/// Fonts and images the PDF embeds. Any of them may be null — the card then
/// falls back exactly as the screen preview does.
class IdCardPdfAssets {
  const IdCardPdfAssets({
    required this.base,
    required this.bold,
    this.logo,
    this.photo,
    this.signature,
  });

  final pw.Font base;
  final pw.Font bold;
  final Uint8List? logo;
  final Uint8List? photo;
  final Uint8List? signature;
}

/// Web's card font is Noto Sans. (Its icons are drawn as images — see
/// id_card_text.dart.)
class IdCardPdfFonts {
  const IdCardPdfFonts(this.base, this.bold);
  final pw.Font base;
  final pw.Font bold;
}

/// Bundled with the app (assets/fonts, SIL OFL 1.1) — no download.
const kIdCardFontAssets = (regular: 'assets/fonts/NotoSans-Regular.ttf', bold: 'assets/fonts/NotoSans-Bold.ttf');

/// Loads the bundled fonts. Helvetica is only a last resort if the bundle
/// can't be read.
Future<IdCardPdfFonts> loadBundledIdCardFonts() async {
  try {
    return IdCardPdfFonts(
      pw.Font.ttf(await rootBundle.load(kIdCardFontAssets.regular)),
      pw.Font.ttf(await rootBundle.load(kIdCardFontAssets.bold)),
    );
  } catch (_) {
    return IdCardPdfFonts(pw.Font.helvetica(), pw.Font.helveticaBold());
  }
}

final idCardPdfFontsProvider = Provider<Future<IdCardPdfFonts> Function()>((ref) => loadBundledIdCardFonts);

/// Draws non-Latin text for the PDF (Flutter's text engine). Tests override it.
final idCardTextRasterizerProvider = Provider<IdCardTextRasterizer>((ref) => rasterizeIdCardText);

/// Downloads an image for the PDF (the card's logo / photo / signature URLs
/// are absolute). Returns null when it can't be fetched or isn't an image the
/// PDF can embed.
final idCardImageLoaderProvider = Provider<Future<Uint8List?> Function(String url)>((ref) => (url) async {
      try {
        final res = await ref.read(dioProvider).get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
        final data = res.data;
        if (data == null || data.isEmpty) return null;
        final bytes = Uint8List.fromList(data);
        return isEmbeddableImage(bytes) ? bytes : null;
      } catch (_) {
        return null;
      }
    });

/// JPEG, or anything the image package can decode (PNG, GIF, WebP, BMP…).
bool isEmbeddableImage(Uint8List bytes) {
  if (bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) return true;
  try {
    return img.decodeImage(bytes) != null;
  } catch (_) {
    return false;
  }
}

Future<IdCardPdfAssets> loadIdCardPdfAssets(
  IdCardData data, {
  required Future<IdCardPdfFonts> Function() fonts,
  required Future<Uint8List?> Function(String url) image,
}) async {
  final f = await fonts();
  Future<Uint8List?> get(String? url) => url == null ? Future.value(null) : image(url);
  final results =
      await Future.wait([get(data.company.logoUrl), get(data.employee.photoUrl), get(data.card.signatureUrl)]);
  return IdCardPdfAssets(
    base: f.base,
    bold: f.bold,
    logo: results[0],
    photo: results[1],
    signature: results[2],
  );
}

/// Prints (system print dialog — which also offers "Save as PDF") or shares
/// the PDF. Tests override it.
/// The print system asks [IdCardPrintLayoutCallback] for the PDF for the
/// paper it has selected (and again whenever the user changes it).
typedef IdCardPrintLayoutCallback = Future<Uint8List> Function(PdfPageFormat paper);

class IdCardOutput {
  const IdCardOutput({required this.print, required this.share});

  /// [format] is the size requested from the print dialog; [layout] builds
  /// the document for the paper actually chosen.
  final Future<bool> Function(IdCardPrintLayoutCallback layout, String name, PdfPageFormat format) print;
  final Future<bool> Function(Uint8List bytes, String filename) share;
}

final idCardOutputProvider = Provider<IdCardOutput>((ref) => IdCardOutput(
      print: (layout, name, format) => Printing.layoutPdf(onLayout: layout, name: name, format: format),
      share: (bytes, filename) => Printing.sharePdf(bytes: bytes, filename: filename),
    ));

/// The paper chosen in the print dialog can't hold a 50 × 85 mm card.
class IdCardPaperTooSmall implements Exception {
  const IdCardPaperTooSmall(this.paper);
  final PdfPageFormat paper;

  String get message {
    String mm(double pt) => (pt / PdfPageFormat.mm).toStringAsFixed(0);
    return 'The selected paper (${mm(paper.width)} × ${mm(paper.height)} mm) is smaller than the '
        '${_S.cardW.toStringAsFixed(0)} × ${_S.cardH.toStringAsFixed(0)} mm ID card. Choose a larger paper size '
        '(portrait), or use the A4 sheet layout.';
  }

  @override
  String toString() => message;
}

/// Rounding slack for paper sizes reported by the print system (≈ 0.2 mm).
const _kPaperSlackPt = .5;

bool idCardFitsOn(PdfPageFormat paper) =>
    paper.width + _kPaperSlackPt >= _mm(_S.cardW) && paper.height + _kPaperSlackPt >= _mm(_S.cardH);

String idCardFileName(IdCardData data, String fallbackId) {
  final code = (data.employee.employeeId ?? fallbackId).replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  return 'id-card-$code.pdf';
}

// ── Document ─────────────────────────────────────────────────────────────────

/// Builds the document. Text in [shaped] is placed as its image; any other
/// text that needs shaping is recorded in [needsShaping] (if given) and, so
/// the card is never missing a value, drawn as plain PDF text meanwhile.
///
/// [paper] (card layout only): print on that paper — each page is the paper's
/// size with one face at exactly 50 × 85 mm in its centre, never scaled.
/// Without it (Share PDF, or a printer offering the card size) each page is
/// the card itself. Throws [IdCardPaperTooSmall] if the card doesn't fit.
/// The A4 layout always uses A4.
pw.Document buildIdCardDocument(
  IdCardData data,
  IdCardPrintLayout layout,
  IdCardPdfAssets a, {
  Map<IdCardTextSpec, IdCardTextImage> shaped = const {},
  Set<IdCardTextSpec>? needsShaping,
  PdfPageFormat? paper,
}) {
  if (layout == IdCardPrintLayout.card && paper != null && !idCardFitsOn(paper)) throw IdCardPaperTooSmall(paper);
  final doc = pw.Document(
    title: 'ID Card${data.employee.fullName == null ? '' : ' — ${data.employee.fullName}'}',
    theme: pw.ThemeData.withFont(base: a.base, bold: a.bold),
  );
  final tx = _Texts(shaped, needsShaping ?? {});
  final front = _front(data, a, tx);
  final back = _back(data, a, tx);
  final format = idCardPageFormat(layout);
  if (layout == IdCardPrintLayout.card) {
    // The page is the paper (margins are the printer's concern); the face
    // keeps its own fixed 50 × 85 mm size, centred.
    // (A paper within rounding of the card size is treated as the card size,
    // so the face is never squeezed.)
    final page = paper == null
        ? format
        : PdfPageFormat(math.max(paper.width, format.width), math.max(paper.height, format.height));
    for (final face in [front, back]) {
      doc.addPage(pw.Page(pageFormat: page, margin: pw.EdgeInsets.zero, build: (_) => pw.Center(child: face)));
    }
  } else {
    pw.Widget guide(pw.Widget face) => pw.Container(
          padding: pw.EdgeInsets.all(_mm(1)),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _c(0xFF9AA3B8), width: _mm(.2), style: pw.BorderStyle.dashed),
          ),
          child: face,
        );
    doc.addPage(pw.Page(
      pageFormat: format,
      build: (_) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [guide(front), pw.SizedBox(width: _mm(10)), guide(back)],
      ),
    ));
  }
  return doc;
}

/// The specs of every text on the card that must be drawn by Flutter.
Set<IdCardTextSpec> idCardShapedTextSpecs(IdCardData data, IdCardPdfAssets assets) {
  final needed = <IdCardTextSpec>{};
  buildIdCardDocument(data, IdCardPrintLayout.card, assets, needsShaping: needed);
  return needed;
}

/// Draws every text/icon the card needs from Flutter (once per card).
Future<Map<IdCardTextSpec, IdCardTextImage>> rasterizeIdCardTexts(
  IdCardData data,
  IdCardPdfAssets assets, {
  IdCardTextRasterizer rasterize = rasterizeIdCardText,
}) async =>
    {for (final s in idCardShapedTextSpecs(data, assets)) s: await rasterize(s)};

Future<Uint8List> buildIdCardPdf(
  IdCardData data,
  IdCardPrintLayout layout,
  IdCardPdfAssets assets, {
  IdCardTextRasterizer rasterize = rasterizeIdCardText,
  Map<IdCardTextSpec, IdCardTextImage>? shaped,
  PdfPageFormat? paper,
}) async {
  shaped ??= await rasterizeIdCardTexts(data, assets, rasterize: rasterize);
  return buildIdCardDocument(data, layout, assets, shaped: shaped, paper: paper).save();
}

const _kGlyphOverhang = .5;

/// Card text: plain PDF text when Noto Sans can draw it, otherwise the
/// Flutter-drawn image of it.
class _Texts {
  _Texts(this.shaped, this.needed);
  final Map<IdCardTextSpec, IdCardTextImage> shaped;
  final Set<IdCardTextSpec> needed;

  /// An icon, drawn by Flutter; blank (same size) until it has been drawn.
  pw.Widget icon(IconData icon, double sizeMm, int color) {
    final spec = IdCardTextSpec.icon(icon.codePoint, icon.fontFamily ?? 'MaterialIcons', sizeMm, color: color);
    final img = shaped[spec];
    if (img == null) needed.add(spec);
    return pw.SizedBox(
      width: _mm(sizeMm),
      height: _mm(sizeMm),
      child: img == null ? null : pw.Image(pw.MemoryImage(img.png), fit: pw.BoxFit.contain),
    );
  }

  pw.Widget call(
    String text,
    double size,
    double widthMm, {
    bool bold = false,
    int color = 0xFF111C3D,
    pw.TextAlign align = pw.TextAlign.left,
    double letter = 0,
    bool shrinkWrap = false,
    bool singleLine = false,
  }) {
    if (idCardNeedsShapedText(text)) {
      final spec = IdCardTextSpec(
        text: text,
        sizeMm: size,
        widthMm: widthMm,
        bold: bold,
        color: color,
        align: align == pw.TextAlign.center ? ui.TextAlign.center : ui.TextAlign.left,
        letterSpacingMm: letter,
        shrinkWrap: shrinkWrap,
      );
      final img = shaped[spec];
      if (img != null) {
        return pw.SizedBox(
          width: _mm(img.widthMm),
          height: _mm(img.heightMm),
          child: pw.Image(pw.MemoryImage(img.png), fit: pw.BoxFit.fill),
        );
      }
      needed.add(spec);
    }
    final t = pw.Text(text,
        textAlign: align, softWrap: !singleLine, style: _t(size, bold: bold, color: _c(color), letter: letter));
    // The pdf package's line breaker lets a line's last glyph overhang the
    // box slightly; break lines a little short so no glyph is cut off.
    return shrinkWrap
        ? t
        : pw.SizedBox(
            width: _mm(widthMm),
            child: pw.Padding(padding: pw.EdgeInsets.only(right: _mm(_kGlyphOverhang)), child: t),
          );
  }
}

// ── Faces ────────────────────────────────────────────────────────────────────

pw.TextStyle _t(double size, {bool bold = false, PdfColor? color, double letter = 0}) => pw.TextStyle(
      fontSize: _mm(size),
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color ?? _navy,
      letterSpacing: _mm(letter),
    );

pw.Widget _goldRule(double h, {List<double> stops = const [0, .2, .8, 1]}) => pw.Container(
      width: _mm(_S.ruleW),
      height: _mm(h),
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(colors: [_white, _gold, _gold, _white], stops: stops),
      ),
    );

pw.Widget _glyph(_Texts tx, IconData icon, double size, int color) => tx.icon(icon, size, color);

pw.Widget _icoCircle(_Texts tx, IdCardIcon icon, double size, double glyph) => pw.Container(
      width: _mm(size),
      height: _mm(size),
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(color: _navy, shape: pw.BoxShape.circle),
      child: _glyph(tx, _S.icon(icon), glyph, 0xFFFFFFFF),
    );

pw.Widget _logo(IdCardData d, IdCardPdfAssets a, _Texts tx) => pw.Padding(
      padding: pw.EdgeInsets.only(top: _mm(_S.logoTop)),
      child: pw.SizedBox(
        height: _mm(_S.logoH),
        width: _mm(_S.logoMaxW),
        child: pw.Center(
          child: a.logo != null
              ? pw.Image(pw.MemoryImage(a.logo!), fit: pw.BoxFit.contain)
              : pw.FittedBox(
                  fit: pw.BoxFit.scaleDown,
                  child: tx(d.company.name ?? '', _S.logoTextSize, _S.logoMaxW,
                      bold: true, align: pw.TextAlign.center, letter: .07),
                ),
        ),
      ),
    );

pw.Widget _footer(IdCardData d, IdCardPdfAssets a, _Texts tx) => pw.Container(
      height: _mm(_S.footerH),
      color: _navy,
      padding: pw.EdgeInsets.symmetric(horizontal: _mm(2)),
      alignment: pw.Alignment.center,
      child: d.company.website == null
          ? null
          : pw.FittedBox(
              fit: pw.BoxFit.scaleDown,
              child: pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
                _glyph(tx, _S.icon(IdCardIcon.website), _S.footerIcon, 0xFFFFFFFF),
                pw.SizedBox(width: _mm(_S.footerGap)),
                tx(d.company.website!, _S.footerText, 200, color: 0xFFFFFFFF, shrinkWrap: true, singleLine: true),
              ]),
            ),
    );

pw.Widget _face(pw.Widget body, pw.Widget footer) => pw.Container(
      width: _mm(_S.cardW),
      height: _mm(_S.cardH),
      color: _white,
      child: pw.Column(children: [
        pw.Expanded(child: pw.ClipRect(child: body)),
        footer,
      ]),
    );

/// Fits [content] (laid out [widthMm] wide, any height) into the space
/// available, scaling it down only when it's too tall.
pw.Widget _fit(double widthMm, pw.Widget content) => pw.FittedBox(
      fit: pw.BoxFit.scaleDown,
      alignment: pw.Alignment.topCenter,
      child: pw.SizedBox(width: _mm(widthMm), child: content),
    );

pw.Widget _front(IdCardData d, IdCardPdfAssets a, _Texts tx) {
  final e = d.employee;
  final rows = idCardFrontRows(e);
  final emptyPhoto = pw.Container(
    decoration: pw.BoxDecoration(color: _c(0xFFEEF1F7), shape: pw.BoxShape.circle),
    alignment: pw.Alignment.center,
    child: _glyph(tx, _S.icon(IdCardIcon.person), _S.photoIcon, 0xFF9AA3B8),
  );
  return _face(
    _fit(
        _S.cardW,
        pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [
          _logo(d, a, tx),
          pw.Container(
            margin: pw.EdgeInsets.only(top: _mm(_S.photoTop)),
            width: _mm(_S.photo),
            height: _mm(_S.photo),
            padding: pw.EdgeInsets.all(_mm(_S.photoPad)),
            decoration: pw.BoxDecoration(
              color: _white,
              shape: pw.BoxShape.circle,
              border: pw.Border.all(color: _gold, width: _mm(_S.photoBorder)),
            ),
            child: pw.ClipOval(
              child: a.photo != null ? pw.Image(pw.MemoryImage(a.photo!), fit: pw.BoxFit.cover) : emptyPhoto,
            ),
          ),
          pw.Padding(
            padding: pw.EdgeInsets.fromLTRB(_mm(_S.sidePad), _mm(_S.nameTop), _mm(_S.sidePad), 0),
            child: tx((e.fullName ?? '').toUpperCase(), _S.nameSize, _S.cardW - 2 * _S.sidePad,
                bold: true, align: pw.TextAlign.center, letter: .04),
          ),
          if (e.designation != null) ...[
            pw.SizedBox(height: _mm(_S.ruleGap)),
            _goldRule(_S.ruleH),
            pw.SizedBox(height: _mm(_S.ruleGap)),
            pw.Padding(
              padding: pw.EdgeInsets.symmetric(horizontal: _mm(_S.sidePad)),
              child: tx(e.designation!.toUpperCase(), _S.desigSize, _S.cardW - 2 * _S.sidePad,
                  align: pw.TextAlign.center, letter: .04),
            ),
          ],
          pw.Padding(
            padding: pw.EdgeInsets.fromLTRB(_mm(_S.rowsLeft), _mm(_S.rowsTop), _mm(_S.rowsRight), 0),
            child: pw.Column(children: [
              for (final (i, r) in rows.indexed)
                pw.ConstrainedBox(
                  constraints: pw.BoxConstraints(minHeight: _mm(_S.rowH)),
                  child: pw.Stack(alignment: pw.Alignment.centerLeft, overflow: pw.Overflow.visible, children: [
                    pw.Padding(
                      padding: pw.EdgeInsets.symmetric(vertical: _mm(.5)),
                      child: pw.Row(children: [
                        _icoCircle(tx, r.icon, _S.rowIco, _S.rowIcoGlyph),
                        pw.SizedBox(width: _mm(_S.rowGap)),
                        tx(r.text, _S.rowText, _rowTextW),
                      ]),
                    ),
                    if (i < rows.length - 1)
                      pw.Positioned(
                        left: _mm(_S.rowLineLeft),
                        right: _mm(_S.rowLineRight),
                        bottom: 0,
                        child: pw.Container(
                          height: _mm(_S.ruleH),
                          decoration: pw.BoxDecoration(
                            gradient: pw.LinearGradient(
                                colors: [_white, _gold, _gold, _white], stops: const [0, .12, .88, 1]),
                          ),
                        ),
                      ),
                  ]),
                ),
            ]),
          ),
        ])),
    _footer(d, a, tx),
  );
}

const _rowTextW = _S.cardW - _S.rowsLeft - _S.rowsRight - _S.rowIco - _S.rowGap;
const _backW = _S.cardW - _S.backLeft - _S.backRight;
const _secTextW = _backW - _S.secIco - _S.secGap;

pw.Widget _back(IdCardData d, IdCardPdfAssets a, _Texts tx) {
  final sections = idCardBackSections(d);
  pw.Widget secRule() => pw.Padding(
        padding: pw.EdgeInsets.symmetric(vertical: _mm(_S.secRuleGap)),
        child: pw.Center(child: _goldRule(_S.secRuleH)),
      );
  return _face(
    pw.Column(children: [
      _logo(d, a, tx),
      pw.Expanded(
        child: pw.Padding(
          padding: pw.EdgeInsets.fromLTRB(_mm(_S.backLeft), _mm(_S.backTop), _mm(_S.backRight), 0),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
            pw.Expanded(
              child: _fit(
                _backW,
                pw.Column(
                    mainAxisSize: pw.MainAxisSize.min,
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, s) in sections.indexed) ...[
                        if (i > 0) secRule(),
                        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                          pw.Padding(
                            padding: pw.EdgeInsets.only(top: _mm(.1)),
                            child: _icoCircle(tx, s.icon, _S.secIco, _S.secIcoGlyph),
                          ),
                          pw.SizedBox(width: _mm(_S.secGap)),
                          pw.Expanded(
                            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                              tx(s.title, _S.secTitle, _secTextW, bold: true),
                              for (final line in s.lines)
                                pw.Padding(
                                  padding: pw.EdgeInsets.only(top: _mm(.3)),
                                  child: tx(line, _S.secText, _secTextW),
                                ),
                            ]),
                          ),
                        ]),
                      ],
                      if (sections.isNotEmpty) secRule(),
                      if (d.card.terms.isNotEmpty) ...[
                        pw.SizedBox(height: _mm(_S.pillTop)),
                        pw.Center(
                          child: pw.Container(
                            padding: pw.EdgeInsets.symmetric(vertical: _mm(_S.pillPadV), horizontal: _mm(_S.pillPadH)),
                            decoration: pw.BoxDecoration(
                                color: _navy, borderRadius: pw.BorderRadius.circular(_mm(_S.pillRadius))),
                            child:
                                pw.Text('Terms & Conditions:', style: _t(_S.pillText, bold: true, color: _termsGold)),
                          ),
                        ),
                        pw.SizedBox(height: _mm(_S.termsTop)),
                        for (final t in d.card.terms)
                          pw.Padding(
                            padding: pw.EdgeInsets.only(bottom: _mm(_S.termsGap)),
                            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                              pw.SizedBox(width: _mm(_S.termsIndent), child: pw.Text('•', style: _t(_S.termsText))),
                              tx(t, _S.termsText, _backW - _S.termsIndent),
                            ]),
                          ),
                      ],
                    ]),
              ),
            ),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Padding(
                padding: pw.EdgeInsets.only(bottom: _mm(_S.signBottom)),
                child: pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [
                  pw.SizedBox(
                    height: _mm(_S.signH),
                    width: _mm(_S.signMaxW),
                    child: a.signature == null
                        ? null
                        : pw.Image(pw.MemoryImage(a.signature!),
                            fit: pw.BoxFit.contain, alignment: pw.Alignment.bottomCenter),
                  ),
                  tx(d.card.signatoryLabel, _S.signLabel, _backW, bold: true, shrinkWrap: true),
                ]),
              ),
            ),
          ]),
        ),
      ),
    ]),
    _footer(d, a, tx),
  );
}
