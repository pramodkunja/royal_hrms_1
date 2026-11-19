import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/assessments/presentation/widgets/my_assessment_card.dart' show formatAssessmentDate;
import 'package:mobile_app/features/attendance/presentation/widgets/late_justification.dart' show fmtLateDate;
import 'package:mobile_app/features/documents/presentation/widgets/document_type_helpers.dart' show formatDocDate;
import 'package:mobile_app/features/employees/data/models/promotion_record_model.dart' show formatPromotionDate;
import 'package:mobile_app/features/employees/domain/employee_profile_sections.dart' show webShortDate;
import 'package:mobile_app/features/employees/presentation/widgets/employee_assets_tab.dart' show fmtAssetDate;
import 'package:mobile_app/features/employees/presentation/widgets/employee_salary_payroll_tabs.dart' show fmtPayMonth;
import 'package:mobile_app/features/leave/presentation/widgets/leave_preview_panel.dart' show leavePreviewDate;

// Task 100.1 / HO-76 — web writes September as "Sept" wherever it formats with
// toLocaleDateString("en-IN" | "en-GB") (verified with Node Intl), and "Sep"
// where it uses en-US or its own month arrays. Expected strings below are what
// the web formatter of the same screen produces for 5 September 2026.

void main() {
  group('September follows the web formatter of the same screen', () {
    test('en-IN day-2-digit screens: assessments, late justification, assets/salary/payroll, promotions', () {
      expect(formatAssessmentDate('2026-09-05T12:00:00Z'), '05 Sept 2026'); // assessments/page.tsx fmt
      expect(fmtLateDate('2026-09-05'), '05 Sept 2026'); // LateJustificationsTab.tsx fmtDate
      expect(fmtAssetDate('2026-09-05'), '05 Sept 2026'); // lib/assetHolder.ts, AssetsTab/SalaryTab/PayrollTab
      expect(formatPromotionDate('2026-09-05'), '05 Sept 2026'); // PromotionTab.tsx fmtDate
    });

    test('en-IN numeric-day screens: documents, leave', () {
      expect(formatDocDate(DateTime(2026, 9, 5)), '5 Sept 2026'); // documents/_data.ts formatUploadedAt
      expect(leavePreviewDate('2026-09-05'), '5 Sept 2026'); // leave/_data.ts fmtDate
    });

    test('en-IN month + year (payroll tab)', () {
      expect(fmtPayMonth('2026-09-05'), 'Sept 2026'); // PayrollTab.tsx { month: "short", year }
    });

    test('weekday form keeps its month token (web: "Sat, 05 Sept, 2026")', () {
      expect(fmtLateDate('2026-09-05', withWeekday: true), contains('05 Sept 2026'));
    });

    test('other months are unchanged', () {
      expect(fmtAssetDate('2026-11-05'), '05 Nov 2026');
      expect(fmtAssetDate('2026-01-31'), '31 Jan 2026');
      expect(formatDocDate(DateTime(2026, 8, 5)), '5 Aug 2026');
      expect(leavePreviewDate('2026-10-05'), '5 Oct 2026');
      expect(fmtPayMonth('2026-12-01'), 'Dec 2026');
    });

    test('where web itself writes "Sep" (en-US), Flutter still does', () {
      expect(webShortDate('2026-09-05'), 'Sep 5, 2026'); // employees/[id]/page.tsx en-US
    });
  });

  // Every remaining 'Sep' month table is intentional. If one is added or one of
  // these changes, this fails: check the web formatter of that screen first
  // (en-IN/en-GB → "Sept"; en-US or a hand-written array → "Sep").
  group('audit lock — remaining "Sep" tables (HO-76)', () {
    const allowed = <String, String>{
      // web writes "Sep" itself
      'features/settings/presentation/holiday_calendar/holiday_calendar_screen.dart': 'web MONTH_SHORT arrays',
      'features/separation/presentation/widgets/separation_status.dart': 'web separation/_workflow.ts MONTHS array',
      'features/wfh/presentation/widgets/request_wfh_tab.dart': 'web WFH components, en-US',
      'features/wfh/presentation/widgets/wfh_request_detail_sheet.dart': 'web WFH components, en-US',
      'features/wfh/presentation/widgets/my_wfh_requests_tab.dart': 'web WFH components, en-US',
      'features/profile/presentation/widgets/profile_documents_section.dart': 'web employees/[id]/page.tsx, en-US',
      'features/employees/domain/employee_profile_sections.dart': 'web employees/[id]/page.tsx, en-US',
      'features/employees/presentation/screens/employee_profile_screen.dart': 'web _data.ts / ProfileForm.tsx arrays',
      // no verifiable web counterpart
      'features/settings/presentation/leave_policy/widgets/late_arrival_limit_card.dart':
          'web uses a native month input',
      'features/assessments/presentation/widgets/item_row.dart': 'no web counterpart',
      'features/expenses/presentation/widgets/expense_form_sheet.dart': 'web uses a native date input',
      'features/dashboard/presentation/screens/employee_dashboard_view.dart': 'month picker: no web counterpart',
      'features/dashboard/presentation/widgets/dashboard_section.dart': 'todayLabel: no per-role web match',
      'features/branches/presentation/utils/branch_formatters.dart': 'web shows no branch dates',
      'features/payroll/presentation/screens/my_payslip_screen.dart': 'label is never rendered (dead code)',
      'features/employees/presentation/widgets/add_employee_sheet.dart': 'web uses a native date input',
      'features/employees/presentation/widgets/leave_credits_section.dart': 'web uses locale-less toLocaleString()',
      'debug/leave_statement_demo_main.dart': 'debug demo entry point',
    };

    test('only the reviewed files still hold a September "Sep" table', () {
      final found = <String>{};
      for (final e in Directory('lib').listSync(recursive: true)) {
        if (e is! File || !e.path.endsWith('.dart')) continue;
        if (e.readAsStringSync().contains("'Sep'")) found.add(e.path.substring('lib/'.length));
      }
      expect(found.difference(allowed.keys.toSet()), isEmpty,
          reason: 'a new "Sep" table — check the web formatter of that screen (en-IN/en-GB → "Sept")');
      expect(allowed.keys.toSet().difference(found), isEmpty,
          reason: 'listed file no longer has a "Sep" table — remove it from the allow-list');
    });
  });
}
