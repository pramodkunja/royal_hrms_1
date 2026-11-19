import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../approvals/presentation/widgets/approvals_kit.dart';
import '../../data/models/training_models.dart';
import '../providers/training_file_io.dart';
import '../providers/training_providers.dart';
import 'training_widgets.dart';

/// Web training/page.tsx ReportsPanel (training.view_reports): filters by
/// course, status, department, branch and assignment date range, then the
/// scoped assignment rows. Department / branch choices come from the
/// employee picker (training.assign); without it those lists are empty, as
/// on web. Export CSV saves the same rows where the user chooses.
class TrainingReportsPanel extends ConsumerStatefulWidget {
  const TrainingReportsPanel({super.key});

  @override
  ConsumerState<TrainingReportsPanel> createState() => _TrainingReportsPanelState();
}

class _TrainingReportsPanelState extends ConsumerState<TrainingReportsPanel> with AutomaticKeepAliveClientMixin {
  TrainingReportFilter _f = const TrainingReportFilter();

  bool _exporting = false;

  @override
  bool get wantKeepAlive => true;

  /// Web exportCsv: the same filters + export=csv; the file is saved where
  /// the user chooses (Android's "Save to" screen — the browser download on
  /// web). Nothing is written until the user picks a place.
  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final bytes = await ref.read(trainingAdminActionsProvider).exportCsv(_f);
      final saved = await ref.read(trainingFileSaverProvider)('training-report.csv', bytes);
      if (saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Report saved.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(userFriendlyMessage(e)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _pickDate({required bool from}) async {
    final current = DateTime.tryParse(from ? _f.from : _f.to);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => _f = from ? _f.copyWith(from: trainingIsoDate(picked)) : _f.copyWith(to: trainingIsoDate(picked)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final courses = ref.watch(trainingCoursesProvider(false)).valueOrNull ?? const <TrainingCourse>[];
    final picker = ref.watch(trainingPickerProvider('')).valueOrNull;
    final rowsAsync = ref.watch(trainingReportProvider(_f));
    final filtered = _f != const TrainingReportFilter();

    Widget select(String key, String label, String value, List<(String, String)> options, ValueChanged<String> set) {
      final valid = value.isEmpty || options.any((o) => o.$1 == value);
      // initialValue + a value-specific key: the field is rebuilt when the
      // filter changes elsewhere (e.g. "Clear filters").
      return KeyedSubtree(
        key: Key('training-report-$key'),
        child: DropdownButtonFormField<String>(
          key: ValueKey('training-report-$key=$value'),
          isExpanded: true,
          initialValue: valid ? value : '',
          iconEnabledColor: AppColors.textSecondary,
          decoration: trainingInput(label),
          items: [
            const DropdownMenuItem(value: '', child: Text('All')),
            for (final (v, l) in options) DropdownMenuItem(value: v, child: Text(l, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => setState(() => set(v ?? '')),
        ),
      );
    }

    Widget dateButton(String label, String value, bool from) => OutlinedButton.icon(
          key: Key('training-report-${from ? 'from' : 'to'}'),
          onPressed: () => _pickDate(from: from),
          style: trainingOutlinedStyle(),
          icon: const Icon(Icons.event_outlined, size: 16),
          label: Align(
            alignment: Alignment.centerLeft,
            child: Text(value.isEmpty ? label : '$label: $value', overflow: TextOverflow.ellipsis),
          ),
        );

    final selects = [
      select('course', 'Course', _f.course, [for (final c in courses) (c.id, c.title)], (v) => _f = _f.copyWith(course: v)),
      select(
          'status',
          'Status',
          _f.status,
          [
            for (final s in [
              TrainingStatus.assigned,
              TrainingStatus.inProgress,
              TrainingStatus.completed,
              TrainingStatus.overdue,
              TrainingStatus.failed,
            ])
              (s.api, s.label),
          ],
          (v) => _f = _f.copyWith(status: v)),
      select('department', 'Department', _f.department, [for (final d in picker?.departments ?? const []) (d, d)],
          (v) => _f = _f.copyWith(department: v)),
      select('branch', 'Branch', _f.branch, [for (final b in picker?.branches ?? const []) (b, b)],
          (v) => _f = _f.copyWith(branch: v)),
    ];

    final filterCard = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(builder: (context, box) {
        final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
        final cols = (box.maxWidth < 330 || scale > 1.4) ? 1 : 2;
        final w = (box.maxWidth - (cols - 1) * 10) / cols;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: TrainingSectionHeader(Icons.tune, 'Filters', subtitle: filtered ? 'Filters applied' : null)),
                if (filtered)
                  TextButton(
                    key: const Key('training-report-clear'),
                    style: trainingTextStyle(),
                    onPressed: () => setState(() => _f = const TrainingReportFilter()),
                    child: const Text('Clear filters'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final s in selects) SizedBox(width: w, child: s),
              SizedBox(width: w, child: dateButton('Assigned from', _f.from, true)),
              SizedBox(width: w, child: dateButton('Assigned to', _f.to, false)),
            ]),
          ],
        );
      }),
    );

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(trainingReportProvider(_f));
        await ref.read(trainingReportProvider(_f).future).catchError((_) => <TrainingAssignmentRow>[]);
      },
      child: ListView(
        key: const Key('training-reports'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
        children: [
          filterCard,
          const SizedBox(height: 14),
          ...rowsAsync.when(
            skipLoadingOnRefresh: true,
            loading: () => [const ApprovalsLoading(label: 'Loading report…')],
            error: (e, _) => [
              TrainingStateView.error(e, what: 'the report', onRetry: () => ref.invalidate(trainingReportProvider(_f))),
            ],
            data: (rows) => [
              LayoutBuilder(builder: (context, c) {
                final count = Text('${rows.length} record(s)',
                    key: const Key('training-report-count'),
                    style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary));
                final export = OutlinedButton.icon(
                  key: const Key('training-report-export'),
                  style: trainingOutlinedStyle(),
                  onPressed: _exporting || rows.isEmpty ? null : _export,
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: Text(_exporting ? 'Exporting…' : 'Export CSV'),
                );
                final oneLine =
                    trainingActionsFit(context, c.maxWidth, ['Exporting…', '${rows.length} record(s)'], chrome: 40, extra: 24);
                return oneLine
                    ? Row(children: [Expanded(child: count), export])
                    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        count,
                        const SizedBox(height: 8),
                        export,
                      ]);
              }),
              const SizedBox(height: 10),
              if (rows.isEmpty)
                filtered
                    ? TrainingStateView.noMatch(
                        key: const Key('training-report-no-match'),
                        title: 'No matching records.',
                        message: 'No assignments fit these filters.',
                        actionLabel: 'Clear filters',
                        onClear: () => setState(() => _f = const TrainingReportFilter()),
                      )
                    : TrainingStateView.empty(
                        key: const Key('training-report-empty'),
                        title: 'No matching records.',
                        message: 'Assignments in your scope will be reported here.',
                        icon: Icons.assessment_outlined,
                        compact: true,
                      ),
              for (final r in rows) TrainingAssignmentCard(row: r, showCourse: true),
            ],
          ),
        ],
      ),
    );
  }
}
