// ignore_for_file: prefer_const_literals_to_create_immutables
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/settings/data/models/company_model.dart';
import 'package:mobile_app/features/settings/data/models/company_plan_model.dart';
import 'package:mobile_app/features/settings/domain/company_validation.dart';
import 'package:mobile_app/features/settings/domain/plan_details_logic.dart';
import 'package:mobile_app/shared/formatters/en_in_format.dart';

// Task 100 — pure logic ported from web settings/company/page.tsx `validate()`
// and handleLogoChange, lib/planDetails.ts, lib/currency.ts `formatMoney`.
// The expected date/money strings were produced by Node's Intl (en-IN).

CompanyModel valid() => const CompanyModel(
      companyName: 'Test Company Pvt Ltd',
      tradeName: '',
      gstin: '27AAPFU0939F1ZV',
      cin: 'U74999MH2020PTC123456',
      pan: 'AAPFU0939F',
      tan: 'MUMA12345B',
      address: '1 Test Street',
      city: 'Mumbai',
      state: 'Maharashtra',
      pinCode: '400001',
      website: '',
      officialPhone: '',
    );

PlanModuleRow row(String key,
        {bool included = false,
        bool enabled = false,
        String source = 'not_included',
        String access = 'off',
        List<String> requiredBy = const [],
        String label = ''}) =>
    PlanModuleRow(
      key: key,
      label: label.isEmpty ? key : label,
      description: '',
      category: '',
      included: included,
      enabled: enabled,
      source: source,
      access: access,
      requiredBy: requiredBy,
    );

void main() {
  group('validateCompany (web validate)', () {
    test('a complete record is valid', () => expect(validateCompany(valid()), isEmpty));

    test('empty form reports every required field with web text', () {
      final e = validateCompany(CompanyModel.empty());
      expect(e, {
        'company_name': 'Company name is required.',
        'gstin': 'GSTIN is required.',
        'cin': 'CIN is required.',
        'pan': 'PAN is required.',
        'tan': 'TAN is required.',
        'address': 'Address is required.',
        'city': 'City is required.',
        'state': 'State / UT is required.',
        'pin_code': 'PIN code is required.',
      });
    });

    test('format messages', () {
      final e = validateCompany(valid().copyWith(gstin: 'BAD', cin: 'BAD', pan: 'BAD', tan: 'BAD', pinCode: '12345'));
      expect(e['gstin'], 'Enter a valid 15-character GSTIN.');
      expect(e['cin'], 'Enter a valid CIN (e.g. U74999MH2020PTC123456).');
      expect(e['pan'], 'Enter a valid 10-character PAN.');
      expect(e['tan'], 'Enter a valid 10-character TAN.');
      expect(e['pin_code'], 'PIN code must be exactly 6 digits.');
    });

    test('identifiers are checked upper-cased; required checks use the trimmed value', () {
      expect(validateCompany(valid().copyWith(gstin: '27aapfu0939f1zv', pan: 'aapfu0939f')), isEmpty);
      final blank = validateCompany(valid().copyWith(companyName: '   ', city: '  ', gstin: '  '));
      expect(blank['company_name'], 'Company name is required.');
      expect(blank['city'], 'City is required.');
      expect(blank['gstin'], 'GSTIN is required.');
      // A padded but otherwise valid value fails the format test (web does not trim before it).
      expect(validateCompany(valid().copyWith(pan: ' AAPFU0939F'))['pan'], 'Enter a valid 10-character PAN.');
    });

    test('website and phone are optional but checked when present', () {
      expect(validateCompany(valid().copyWith(website: 'https://a.test', officialPhone: '+91 98765 43210')), isEmpty);
      expect(validateCompany(valid().copyWith(website: 'ftp://a.test'))['website'],
          'Must start with http:// or https://.');
      expect(validateCompany(valid().copyWith(website: 'a.test'))['website'], 'Must start with http:// or https://.');
      expect(validateCompany(valid().copyWith(officialPhone: 'abc'))['official_phone'], 'Enter a valid phone number.');
      expect(
          validateCompany(valid().copyWith(officialPhone: '123456'))['official_phone'], 'Enter a valid phone number.');
      expect(validateCompany(valid().copyWith(officialPhone: '022-1234.5678'))['official_phone'], isNull);
      // Web's pattern allows a leading "+" only.
      expect(validateCompany(valid().copyWith(officialPhone: '98765+43210'))['official_phone'],
          'Enter a valid phone number.');
    });

    test('field order follows the form top to bottom', () {
      expect(kCompanyFieldOrder.first, 'company_name');
      expect(kCompanyFieldOrder.last, 'official_phone');
      expect(validateCompany(CompanyModel.empty()).keys.every(kCompanyFieldOrder.contains), isTrue);
    });
  });

  group('logo rules (web handleLogoChange)', () {
    test('allowed types: JPEG, PNG, WebP, SVG (any case)', () {
      for (final f in ['a.jpg', 'a.JPEG', 'a.png', 'a.webp', 'a.SVG', '/x/y.logo.png']) {
        expect(companyLogoError(f, 1000), isNull, reason: f);
      }
    });
    test('other types are refused first, with web text', () {
      for (final f in ['a.gif', 'a.pdf', 'a', 'a.bmp', '/x/png']) {
        expect(companyLogoError(f, 1000), 'Only JPEG, PNG, WebP, or SVG files are allowed.', reason: f);
      }
      expect(companyLogoError('a.gif', 9 * 1024 * 1024), 'Only JPEG, PNG, WebP, or SVG files are allowed.');
    });
    test('5 MB is the limit', () {
      expect(companyLogoError('a.png', 5 * 1024 * 1024), isNull);
      expect(companyLogoError('a.png', 5 * 1024 * 1024 + 1), 'Logo must be under 5 MB.');
    });
  });

  group('save payload (web FormData)', () {
    test('trimmed; GSTIN/CIN/PAN/TAN upper-cased; state as selected', () {
      final p = valid()
          .copyWith(
            companyName: '  Acme Ltd ',
            tradeName: ' Acme ',
            gstin: ' 27aapfu0939f1zv ',
            cin: 'u74999mh2020ptc123456',
            pan: ' aapfu0939f',
            tan: 'muma12345b ',
            address: ' 1 Road ',
            city: ' Pune ',
            pinCode: ' 411001 ',
            website: ' https://a.test ',
            officialPhone: ' 022 1234 ',
          )
          .toSavePayload();
      expect(p, {
        'company_name': 'Acme Ltd',
        'trade_name': 'Acme',
        'gstin': '27AAPFU0939F1ZV',
        'cin': 'U74999MH2020PTC123456',
        'pan': 'AAPFU0939F',
        'tan': 'MUMA12345B',
        'address': '1 Road',
        'city': 'Pune',
        'state': 'Maharashtra',
        'pin_code': '411001',
        'website': 'https://a.test',
        'official_phone': '022 1234',
      });
    });
  });

  group('en-IN formatting (matches Node Intl)', () {
    test('dates: September is "Sept"', () {
      expect(formatEnInDate(DateTime(2026, 9, 5), padDay: true), '05 Sept 2026');
      expect(formatEnInDate(DateTime(2026, 11, 5)), '5 Nov 2026');
      expect(formatEnInDate(DateTime(2026, 1, 1)), '1 Jan 2026');
      expect([for (var m = 1; m <= 12; m++) formatEnInDate(DateTime(2026, m, 5)).split(' ')[1]].join(','),
          'Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sept,Oct,Nov,Dec');
    });
    test('date-time: "5 Nov 2026, 3:45 pm"', () {
      expect(formatEnInDateTime(DateTime(2026, 11, 5, 15, 45)), '5 Nov 2026, 3:45 pm');
      expect(formatEnInDateTime(DateTime(2026, 11, 5, 9, 5)), '5 Nov 2026, 9:05 am');
      expect(formatEnInDateTime(DateTime(2026, 11, 5, 0, 30)), '5 Nov 2026, 12:30 am');
      expect(formatEnInDateTime(DateTime(2026, 11, 5, 12, 0)), '5 Nov 2026, 12:00 pm');
    });
    test('money', () {
      expect(formatMoney('1234567.891', 'INR'), '₹12,34,567.89');
      expect(formatMoney('1234567', 'USD'), r'$1,234,567');
      expect(formatMoney('0.5', 'INR'), '₹0.5');
      expect(formatMoney('12.10', 'INR'), '₹12.1');
      expect(formatMoney('100', 'INR'), '₹100');
      expect(formatMoney('999', 'INR'), '₹999');
      expect(formatMoney('1000', 'INR'), '₹1,000');
      expect(formatMoney('100000', 'INR'), '₹1,00,000');
      expect(formatMoney('49', 'XYZ'), 'XYZ 49');
      expect(formatMoney('100', 'AED'), '‎' 'د.إ 100');
      expect(formatMoney('100', 'eur'), '€100');
      expect(formatMoney('oops'), '₹NaN');
    });
  });

  group('plan logic (web lib/planDetails.ts)', () {
    test('labels', () {
      expect(kSourceLabel['dependency'], 'Included');
      expect(kSourceLabel['added'], 'Added for your company');
      expect(kAccessLabel['pending'], 'Activates when payment is confirmed');
      expect(kPaymentLabel['partially_paid'], 'Partially paid');
      expect(kActivationLabel['setting_up'], 'Being set up');
      expect(periodLabel('yearly'), 'Yearly');
      expect(periodLabel('monthly'), 'Monthly');
      expect(periodLabel(''), 'Not set');
    });

    test('sourceNote / enabledOutsidePlan', () {
      expect(sourceNote(row('a', source: 'dependency', requiredBy: ['Payroll', 'HR'])), 'Required by Payroll, HR');
      expect(sourceNote(row('a', source: 'dependency')), '');
      expect(sourceNote(row('a', source: 'plan', requiredBy: ['x'])), '');
      expect(enabledOutsidePlan(row('a', enabled: true), true), isTrue);
      expect(enabledOutsidePlan(row('a', enabled: true), false), isFalse);
      expect(enabledOutsidePlan(row('a', enabled: true, included: true), true), isFalse);
    });

    test('summary line, with and without pending', () {
      final rows = [
        row('a', included: true, enabled: true),
        row('b', included: true, access: 'pending'),
        row('c'),
      ];
      final s = moduleSummary(rows);
      expect((s.included, s.enabled, s.pending, s.notIncluded), (2, 1, 1, 1));
      expect(moduleSummaryLine(s), '2 included · 1 enabled · 1 activate after payment · 1 not included');
      expect(moduleSummaryLine(moduleSummary([row('a', included: true, enabled: true)])),
          '1 included · 1 enabled · 0 not included');
    });

    test('included modules first, then A–Z', () {
      final sorted = sortedModules([
        row('z', label: 'Zeta'),
        row('b', label: 'beta', included: true),
        row('a', label: 'Alpha', included: true),
        row('y', label: 'Yak'),
      ]);
      expect(sorted.map((r) => r.label), ['Alpha', 'beta', 'Yak', 'Zeta']);
    });

    PlanDetails details({bool hasPlan = true}) => PlanDetails.fromJson({
          'has_plan': hasPlan,
          'current': null,
          'modules': [
            {'key': 'hr', 'label': 'HR', 'included': true, 'enabled': true, 'source': 'plan', 'access': 'enabled'},
            {
              'key': 'pay',
              'label': 'Payroll',
              'included': false,
              'enabled': true,
              'source': 'not_included',
              'access': 'enabled'
            },
            {
              'key': 'ats',
              'label': 'ATS',
              'included': false,
              'enabled': false,
              'source': 'not_included',
              'access': 'off'
            },
            {
              'key': 'lms',
              'label': 'LMS',
              'included': false,
              'enabled': false,
              'source': 'not_included',
              'access': 'off'
            },
          ],
          'enabled_modules': ['hr', 'pay'],
          'other_plans': [
            {
              'code': 'pro',
              'name': 'Pro',
              'modules': ['hr', 'ats']
            },
          ],
        });

    test('comparison: with a plan the current column is what it includes', () {
      final rows = comparisonRows(details());
      expect(rows.map((r) => r.key), ['hr', 'ats']); // pay not included, lms in nobody's plan
      expect(rows.first.current, isTrue);
      expect(rows.last.current, isFalse);
      expect(rows.last.plans, {'pro': true});
    });

    test('comparison: with no plan the enabled modules are "today"', () {
      final rows = comparisonRows(details(hasPlan: false));
      expect(rows.map((r) => r.key), ['hr', 'pay', 'ats']);
      expect(rows.where((r) => r.current).map((r) => r.key), ['hr', 'pay']);
    });

    test('module labels fall back to the key', () {
      expect(moduleLabels(details(), ['hr', 'ghost']), ['HR', 'ghost']);
    });

    test('GST suffix', () {
      expect(gstSuffix(true, '18.00'), ' (GST incl.)');
      expect(gstSuffix(false, '18.00'), ' + 18% GST');
      expect(gstSuffix(false, '12.5'), ' + 12.5% GST');
      expect(gstSuffix(false, '0'), ' + 0% GST');
    });
  });

  group('PlanDetails.fromJson is defensive', () {
    test('an empty or sparse body does not throw', () {
      final d = PlanDetails.fromJson({});
      expect(d.hasPlan, isFalse);
      expect(d.current, isNull);
      expect(d.modules, isEmpty);
      expect(d.payments, isEmpty);
      final odd = PlanDetails.fromJson({
        'current': {'plan_name': 'P', 'days_left': '5', 'employee_count': null, 'features': 'oops'},
        'modules': [
          1,
          null,
          {'key': 'a'}
        ],
        'payments': {'not': 'a list'},
        'other_plans': [
          {
            'code': 'x',
            'estimates': [
              {'total': 12}
            ]
          },
        ],
      });
      expect(odd.current!.planName, 'P');
      expect(odd.current!.daysLeft, 5);
      expect(odd.current!.features, isEmpty);
      expect(odd.modules.single.key, 'a');
      expect(odd.otherPlans.single.estimates.single.total, '12');
      expect(odd.otherPlans.single.fitsEmployeeCount, isTrue);
    });
  });
}
