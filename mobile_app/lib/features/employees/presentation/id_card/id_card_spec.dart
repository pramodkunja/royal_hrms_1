import 'package:flutter/material.dart';

import '../../data/models/employee_id_card_model.dart';

// The ID card template's measurements, from web components/idcard/
// IdCardFaces.tsx ID_CARD_CSS (all in millimetres, so the printed card is
// exactly 50 × 85 mm). Shared by the on-screen preview and the PDF.
class IdCardSpec {
  IdCardSpec._();

  static const cardW = 50.0;
  static const cardH = 85.0;

  static const navy = Color(0xFF111C3D);
  static const gold = Color(0xFFB8862B);
  static const termsGold = Color(0xFFC8963A);
  static const photoEmptyBg = Color(0xFFEEF1F7);
  static const photoEmptyFg = Color(0xFF9AA3B8);

  // Front
  static const logoH = 8.6, logoTop = 2.0, logoMaxW = 34.0, logoTextSize = 2.3;
  static const photo = 17.6, photoTop = 1.8, photoBorder = 0.3, photoPad = 0.45, photoIcon = 8.0;
  static const nameTop = 2.0, nameSize = 2.15, sidePad = 3.0, desigSize = 1.85;
  static const ruleH = 0.22, ruleW = 17.0, ruleGap = 0.9;
  static const rowsTop = 2.2, rowsLeft = 4.2, rowsRight = 3.0, rowH = 5.9;
  static const rowIco = 4.8, rowIcoGlyph = 2.8, rowGap = 1.5, rowText = 1.85, rowLineLeft = 8.0, rowLineRight = 1.5;
  static const footerH = 4.9, footerText = 1.7, footerIcon = 2.4, footerGap = 1.2;

  // Back
  static const backTop = 2.0, backRight = 3.0, backLeft = 4.4;
  static const secIco = 3.0, secIcoGlyph = 1.8, secGap = 1.3, secTitle = 1.8, secText = 1.7;
  static const secRuleH = 0.2, secRuleGap = 1.5;
  static const pillText = 1.85, pillPadV = 0.55, pillPadH = 2.4, pillRadius = 2.0, pillTop = 0.6;
  static const termsTop = 1.3, termsIndent = 3.2, termsText = 1.8, termsGap = 0.3;
  static const signH = 7.0, signMaxW = 15.0, signLabel = 1.55, signBottom = 0.8;
  static const lineHeight = 1.3;

  /// Material Icons glyphs standing in for web's Tabler icons.
  static IconData icon(IdCardIcon i) => switch (i) {
        IdCardIcon.code => Icons.badge_outlined,
        IdCardIcon.dob => Icons.cake_outlined,
        IdCardIcon.doj => Icons.calendar_today_outlined,
        IdCardIcon.department => Icons.account_balance_outlined,
        IdCardIcon.blood => Icons.bloodtype_outlined,
        IdCardIcon.location => Icons.place_outlined,
        IdCardIcon.residential => Icons.place_outlined,
        IdCardIcon.office => Icons.apartment_outlined,
        IdCardIcon.contact => Icons.contact_phone_outlined,
        IdCardIcon.website => Icons.public,
        IdCardIcon.person => Icons.person,
      };
}
