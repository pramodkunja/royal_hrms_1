import 'package:flutter/material.dart';

import '../../data/models/employee_id_card_model.dart';
import 'id_card_spec.dart';
import 'id_card_text.dart' show kIdCardFontFamily, kIdCardFontFallback;

// On-screen front/back of the ID card — web IdCardFront / IdCardBack, drawn
// at [scale] logical pixels per millimetre, in the bundled Noto Sans (with
// Noto Sans Devanagari for Hindi/Marathi text). Long text wraps; when a face's
// content is taller than the card it is scaled down to fit (same as the PDF),
// so nothing is silently cut off.

typedef _S = IdCardSpec;

class _Mm {
  const _Mm(this.s);
  final double s;
  double call(double mm) => mm * s;
}

TextStyle _text(_Mm mm, double size, {bool bold = false, Color color = _S.navy, double height = 1.2}) => TextStyle(
      fontFamily: kIdCardFontFamily,
      fontFamilyFallback: kIdCardFontFallback,
      fontSize: mm(size),
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      color: color,
      height: height,
    );

Widget _goldRule(_Mm mm, double h) => Container(
      width: mm(_S.ruleW),
      height: mm(h),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, _S.gold, _S.gold, Colors.transparent],
          stops: [0, .2, .8, 1],
        ),
      ),
    );

Widget _icoCircle(_Mm mm, IdCardIcon icon, double size, double glyph) => Container(
      width: mm(size),
      height: mm(size),
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: _S.navy, shape: BoxShape.circle),
      child: Icon(_S.icon(icon), size: mm(glyph), color: Colors.white),
    );

class _Logo extends StatelessWidget {
  const _Logo({required this.data, required this.mm});
  final IdCardData data;
  final _Mm mm;

  @override
  Widget build(BuildContext context) {
    final name = Text(data.company.name ?? '',
        key: const Key('idc-logo-text'),
        textAlign: TextAlign.center,
        style: _text(mm, _S.logoTextSize, bold: true).copyWith(letterSpacing: mm(.07)));
    return Padding(
      padding: EdgeInsets.only(top: mm(_S.logoTop)),
      child: SizedBox(
        height: mm(_S.logoH),
        width: mm(_S.logoMaxW),
        child: Center(
          child: data.company.logoUrl == null
              ? FittedBox(fit: BoxFit.scaleDown, child: SizedBox(width: mm(_S.logoMaxW), child: name))
              : Image.network(data.company.logoUrl!,
                  key: const Key('idc-logo-image'),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      FittedBox(fit: BoxFit.scaleDown, child: SizedBox(width: mm(_S.logoMaxW), child: name))),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.data, required this.mm});
  final IdCardData data;
  final _Mm mm;

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('idc-footer'),
        height: mm(_S.footerH),
        color: _S.navy,
        padding: EdgeInsets.symmetric(horizontal: mm(2)),
        alignment: Alignment.center,
        child: data.company.website == null
            ? null
            : Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_S.icon(IdCardIcon.website), size: mm(_S.footerIcon), color: Colors.white),
                SizedBox(width: mm(_S.footerGap)),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(data.company.website!,
                        maxLines: 1, softWrap: false, style: _text(mm, _S.footerText, color: Colors.white)),
                  ),
                ),
              ]),
      );
}

/// A card face: white, exactly 50 × 85 mm, footer pinned to the bottom.
class _Face extends StatelessWidget {
  const _Face({required this.mm, required this.body, required this.footer});
  final _Mm mm;
  final Widget body;
  final Widget footer;

  @override
  Widget build(BuildContext context) => Container(
        width: mm(_S.cardW),
        height: mm(_S.cardH),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE3E7EF)),
          boxShadow: const [BoxShadow(color: Color(0x2E111C3D), blurRadius: 12, offset: Offset(0, 2))],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(children: [
          Expanded(child: ClipRect(child: body)),
          footer,
        ]),
      );
}

class IdCardFrontFace extends StatelessWidget {
  const IdCardFrontFace({super.key, required this.data, this.scale = 5});
  final IdCardData data;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final mm = _Mm(scale);
    final e = data.employee;
    final emptyPhoto = Container(
      key: const Key('idc-photo-empty'),
      decoration: const BoxDecoration(color: _S.photoEmptyBg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(_S.icon(IdCardIcon.person), size: mm(_S.photoIcon), color: _S.photoEmptyFg),
    );
    return _Face(
      mm: mm,
      footer: _Footer(data: data, mm: mm),
      body: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: mm(_S.cardW),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _Logo(data: data, mm: mm),
            Container(
              margin: EdgeInsets.only(top: mm(_S.photoTop)),
              width: mm(_S.photo),
              height: mm(_S.photo),
              padding: EdgeInsets.all(mm(_S.photoPad)),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: _S.gold, width: mm(_S.photoBorder)),
              ),
              child: ClipOval(
                child: e.photoUrl == null
                    ? emptyPhoto
                    : Image.network(e.photoUrl!,
                        key: const Key('idc-photo-image'), fit: BoxFit.cover, errorBuilder: (_, __, ___) => emptyPhoto),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(mm(_S.sidePad), mm(_S.nameTop), mm(_S.sidePad), 0),
              child: Text((e.fullName ?? '').toUpperCase(),
                  key: const Key('idc-name'),
                  textAlign: TextAlign.center,
                  style: _text(mm, _S.nameSize, bold: true).copyWith(letterSpacing: mm(.04))),
            ),
            if (e.designation != null) ...[
              SizedBox(height: mm(_S.ruleGap)),
              _goldRule(mm, _S.ruleH),
              SizedBox(height: mm(_S.ruleGap)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: mm(_S.sidePad)),
                child: Text(e.designation!.toUpperCase(),
                    key: const Key('idc-designation'),
                    textAlign: TextAlign.center,
                    style: _text(mm, _S.desigSize).copyWith(letterSpacing: mm(.04))),
              ),
            ],
            Padding(
              padding: EdgeInsets.fromLTRB(mm(_S.rowsLeft), mm(_S.rowsTop), mm(_S.rowsRight), 0),
              child: Column(children: [
                for (final (i, r) in idCardFrontRows(e).indexed)
                  ConstrainedBox(
                    key: Key('idc-row-${r.key}'),
                    constraints: BoxConstraints(minHeight: mm(_S.rowH)),
                    child: Stack(alignment: Alignment.centerLeft, children: [
                      Padding(
                          padding: EdgeInsets.symmetric(vertical: mm(.5)),
                          child: Row(children: [
                            _icoCircle(mm, r.icon, _S.rowIco, _S.rowIcoGlyph),
                            SizedBox(width: mm(_S.rowGap)),
                            Expanded(
                              child: Text(r.text, style: _text(mm, _S.rowText)),
                            ),
                          ])),
                      if (i < idCardFrontRows(e).length - 1)
                        Positioned(
                          left: mm(_S.rowLineLeft),
                          right: mm(_S.rowLineRight),
                          bottom: 0,
                          child: Container(
                            height: mm(_S.ruleH),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.transparent, _S.gold, _S.gold, Colors.transparent],
                                stops: [0, .12, .88, 1],
                              ),
                            ),
                          ),
                        ),
                    ]),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class IdCardBackFace extends StatelessWidget {
  const IdCardBackFace({super.key, required this.data, this.scale = 5, this.signatureImage});
  final IdCardData data;
  final double scale;

  /// Shown instead of [IdCardConfig.signatureUrl] — Settings → ID Card's
  /// preview of a signature picked but not saved yet (web's blob preview).
  final ImageProvider? signatureImage;

  @override
  Widget build(BuildContext context) {
    final mm = _Mm(scale);
    final sections = idCardBackSections(data);
    return _Face(
      mm: mm,
      footer: _Footer(data: data, mm: mm),
      body: Column(children: [
        _Logo(data: data, mm: mm),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(mm(_S.backLeft), mm(_S.backTop), mm(_S.backRight), 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: mm(_S.cardW - _S.backLeft - _S.backRight),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (i, s) in sections.indexed) ...[
                            if (i > 0) _secRule(mm),
                            Row(
                              key: Key('idc-section-${s.key}'),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(top: mm(.1)),
                                  child: _icoCircle(mm, s.icon, _S.secIco, _S.secIcoGlyph),
                                ),
                                SizedBox(width: mm(_S.secGap)),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(s.title, style: _text(mm, _S.secTitle, bold: true, height: _S.lineHeight)),
                                    for (final line in s.lines)
                                      Padding(
                                        padding: EdgeInsets.only(top: mm(.3)),
                                        child: Text(line, style: _text(mm, _S.secText, height: _S.lineHeight)),
                                      ),
                                  ]),
                                ),
                              ],
                            ),
                          ],
                          if (sections.isNotEmpty) _secRule(mm),
                          if (data.card.terms.isNotEmpty) ...[
                            SizedBox(height: mm(_S.pillTop)),
                            Center(
                              child: Container(
                                key: const Key('idc-terms-pill'),
                                padding: EdgeInsets.symmetric(vertical: mm(_S.pillPadV), horizontal: mm(_S.pillPadH)),
                                decoration: BoxDecoration(
                                    color: _S.navy, borderRadius: BorderRadius.circular(mm(_S.pillRadius))),
                                child: Text('Terms & Conditions:',
                                    style: _text(mm, _S.pillText, bold: true, color: _S.termsGold)),
                              ),
                            ),
                            SizedBox(height: mm(_S.termsTop)),
                            for (final t in data.card.terms)
                              Padding(
                                padding: EdgeInsets.only(bottom: mm(_S.termsGap)),
                                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  SizedBox(
                                    width: mm(_S.termsIndent),
                                    child: Text('•', style: _text(mm, _S.termsText, height: _S.lineHeight)),
                                  ),
                                  Expanded(child: Text(t, style: _text(mm, _S.termsText, height: _S.lineHeight))),
                                ]),
                              ),
                          ],
                        ]),
                  ),
                ),
              ),
              // Signature, bottom-right (web .idc-sign: margin-top auto).
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(bottom: mm(_S.signBottom)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(
                      height: mm(_S.signH),
                      width: mm(_S.signMaxW),
                      child: signatureImage != null
                          ? Image(
                              image: signatureImage!,
                              key: const Key('idc-signature-image'),
                              fit: BoxFit.contain,
                              alignment: Alignment.bottomCenter,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink())
                          : data.card.signatureUrl == null
                              ? null
                              : Image.network(data.card.signatureUrl!,
                                  key: const Key('idc-signature-image'),
                                  fit: BoxFit.contain,
                                  alignment: Alignment.bottomCenter,
                                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                    ),
                    Text(data.card.signatoryLabel,
                        key: const Key('idc-signatory'), style: _text(mm, _S.signLabel, bold: true)),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _secRule(_Mm mm) => Padding(
        padding: EdgeInsets.symmetric(vertical: mm(_S.secRuleGap)),
        child: Center(child: _goldRule(mm, _S.secRuleH)),
      );
}
