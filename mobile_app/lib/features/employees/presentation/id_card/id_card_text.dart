import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/painting.dart' show Color;
import 'package:flutter/services.dart' show rootBundle;

// Text the `pdf` package can't draw correctly. It embeds TrueType glyphs
// but has no OpenType shaping for Indic scripts (Devanagari matras would be
// misplaced, conjuncts wouldn't form), so any text outside the scripts the
// bundled Noto Sans covers is drawn by Flutter's own text engine — which
// shapes every script, with the bundled Noto Sans Devanagari (and, on a
// device, the system fonts) — at 600 dpi and placed in the PDF as an image of
// exactly the text's size. Latin text stays real, selectable PDF text.
//
// The card's icons are drawn the same way: Flutter's Material Icons font is
// CFF-based ("OTTO"), which the `pdf` package can't embed.

/// The ID card's text families: web's card font, plus Devanagari offline.
const kIdCardFontFamily = 'NotoSans';
const kIdCardFontFallback = ['NotoSansDevanagari'];

/// Whether the `pdf` package can't draw [text] properly with Noto Sans:
/// anything beyond Latin (incl. extensions and IPA), Greek, Cyrillic, common
/// punctuation, currency and letter-like symbols.
bool idCardNeedsShapedText(String text) => text.runes.any((r) =>
    !(r < 0x0530 || (r >= 0x1E00 && r <= 0x1EFF) || (r >= 0x2000 && r <= 0x20CF) || (r >= 0x2100 && r <= 0x214F)));

/// One piece of text to draw, with the box it is laid out in (mm).
class IdCardTextSpec {
  const IdCardTextSpec({
    required this.text,
    required this.sizeMm,
    required this.widthMm,
    this.bold = false,
    this.color = 0xFF111C3D,
    this.align = ui.TextAlign.left,
    this.letterSpacingMm = 0,
    this.shrinkWrap = false,
    this.fontFamily,
  });

  /// An icon glyph ([IconData.fontFamily], e.g. Material Icons), [sizeMm] square.
  IdCardTextSpec.icon(int codePoint, String family, double sizeMm, {int color = 0xFFFFFFFF})
      : this(
          text: String.fromCharCode(codePoint),
          sizeMm: sizeMm,
          widthMm: sizeMm,
          color: color,
          align: ui.TextAlign.center,
          fontFamily: family,
        );

  final String text;
  final double sizeMm;

  /// Width the text wraps in; with [shrinkWrap] the image is only as wide as
  /// the text needs (at most this).
  final double widthMm;
  final bool bold;
  final int color;
  final ui.TextAlign align;
  final double letterSpacingMm;
  final bool shrinkWrap;

  /// Null: the card font (Noto Sans, Devanagari fallback).
  final String? fontFamily;

  bool get isIcon => fontFamily != null;

  @override
  bool operator ==(Object other) =>
      other is IdCardTextSpec &&
      other.text == text &&
      other.sizeMm == sizeMm &&
      other.widthMm == widthMm &&
      other.bold == bold &&
      other.color == color &&
      other.align == align &&
      other.letterSpacingMm == letterSpacingMm &&
      other.shrinkWrap == shrinkWrap &&
      other.fontFamily == fontFamily;

  @override
  int get hashCode => Object.hash(text, sizeMm, widthMm, bold, color, align, letterSpacingMm, shrinkWrap, fontFamily);
}

/// A rasterised [IdCardTextSpec]: PNG bytes and the size to place it at (mm).
class IdCardTextImage {
  const IdCardTextImage(this.png, this.widthMm, this.heightMm);
  final Uint8List png;
  final double widthMm;
  final double heightMm;
}

typedef IdCardTextRasterizer = Future<IdCardTextImage> Function(IdCardTextSpec spec);

/// 600 dpi.
const _pxPerMm = 600 / 25.4;

/// Draws [s] with Flutter's text engine (full shaping) into a PNG.
Future<IdCardTextImage> rasterizeIdCardText(IdCardTextSpec s) async {
  final fontSize = s.sizeMm * _pxPerMm;
  final weight = s.bold ? ui.FontWeight.w700 : ui.FontWeight.w400;
  final family = s.fontFamily ?? kIdCardFontFamily;
  final fallback = s.isIcon ? null : kIdCardFontFallback;
  ui.Paragraph build(double width) {
    final b = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: s.align,
      fontFamily: family,
      fontSize: fontSize,
      fontWeight: weight,
    ))
      ..pushStyle(ui.TextStyle(
        color: Color(s.color),
        fontFamily: family,
        fontFamilyFallback: fallback,
        fontSize: fontSize,
        fontWeight: weight,
        letterSpacing: s.letterSpacingMm * _pxPerMm,
      ))
      ..addText(s.text);
    return b.build()..layout(ui.ParagraphConstraints(width: width));
  }

  final maxW = s.widthMm * _pxPerMm;
  var p = build(maxW);
  var w = maxW;
  if (s.shrinkWrap) {
    w = p.maxIntrinsicWidth.ceilToDouble().clamp(1, maxW);
    p = build(w);
  }
  final pw = w.ceil().clamp(1, 100000);
  final ph = p.height.ceil().clamp(1, 100000);
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawParagraph(p, ui.Offset.zero);
  final image = await recorder.endRecording().toImage(pw, ph);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return IdCardTextImage(data!.buffer.asUint8List(), pw / _pxPerMm, ph / _pxPerMm);
}

/// Adds the bundled Noto fonts' SIL OFL 1.1 licences to the app's licence page.
void registerIdCardFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (family, file) in [
      ('Noto Sans', 'assets/fonts/OFL-NotoSans.txt'),
      ('Noto Sans Devanagari', 'assets/fonts/OFL-NotoSansDevanagari.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([family], await rootBundle.loadString(file));
    }
  });
}
