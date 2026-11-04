import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/wfh_daily_report_entity.dart';
import '../providers/wfh_providers.dart';
import '../providers/wfh_report_providers.dart';
import '../wfh_report_strings.dart';
import 'wfh_report_card.dart';
import 'wfh_report_form.dart';
import 'wfh_report_section.dart';

/// "Daily Work Report" tab — web's WfhDailyReports: the submit form, the
/// user's own reports, and (only when there are any) the reports they may
/// review. The backend returns plain lists (no paging, no date filter).
class WfhDailyReportsTab extends ConsumerWidget {
  const WfhDailyReportsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(wfhMyReportsProvider);
    final review = ref.watch(wfhReviewReportsProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(wfhMyReportsProvider);
        ref.invalidate(wfhReviewReportsProvider);
        await Future.wait([
          ref.read(wfhMyReportsProvider.future).catchError((_) => const <WfhDailyReportEntity>[]),
          ref.read(wfhReviewReportsProvider.future).catchError((_) => const <WfhDailyReportEntity>[]),
        ]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
        children: [
          const WfhReportForm(),
          const SizedBox(height: 16),
          _ReportList(
            title: WfhReportStrings.myReports,
            value: mine,
            onRetry: () => ref.invalidate(wfhMyReportsProvider),
          ),
          // Exactly web's rule: the reviewer-only block appears only when
          // reviewable reports exist. A failed load alone never shows it, so
          // a plain employee (or a company with WFH disabled, where both
          // lists fail with the same message) sees no reviewer error. If a
          // refresh fails after reports were shown, Riverpod keeps the
          // previous rows and the block shows the error with Retry.
          if ((review.valueOrNull ?? const []).isNotEmpty) ...[
            const SizedBox(height: 16),
            _ReportList(
              title: WfhReportStrings.toReview,
              value: review,
              showEmployee: true,
              onRetry: () => ref.invalidate(wfhReviewReportsProvider),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReportList extends StatelessWidget {
  final String title;
  final AsyncValue<List<WfhDailyReportEntity>> value;
  final bool showEmployee;
  final VoidCallback onRetry;

  const _ReportList({required this.title, required this.value, required this.onRetry, this.showEmployee = false});

  @override
  Widget build(BuildContext context) {
    return WfhReportSection(
      title: title,
      children: [
        value.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WfhReportNotice(text: friendlyWfhError(e), ok: false),
              TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
            ],
          ),
          data: (rows) => rows.isEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(WfhReportStrings.noReports, style: AppTextStyles.body),
                    const SizedBox(height: 2),
                    Text(WfhReportStrings.noReportsHint, style: AppTextStyles.bodySecondary.copyWith(fontSize: 12)),
                  ],
                )
              : Column(
                  children: [
                    for (final r in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: WfhReportCard(key: ValueKey('wfh-report-${r.id}'), report: r, showEmployee: showEmployee),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
