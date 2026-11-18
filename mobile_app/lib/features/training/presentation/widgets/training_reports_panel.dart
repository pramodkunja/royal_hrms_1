import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_error_state.dart';
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
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
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
          icon: const Icon(Icons.event_outlined, size: 16),
          label: Text(value.isEmpty ? label : '$label: $value', overflow: TextOverflow.ellipsis),
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          select('course', 'Course', _f.course, [for (final c in courses) (c.id, c.title)],
              (v) => _f = _f.copyWith(course: v)),
          const SizedBox(height: 10),
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
          const SizedBox(height: 10),
          select('department', 'Department', _f.department, [for (final d in picker?.departments ?? const []) (d, d)],
              (v) => _f = _f.copyWith(department: v)),
          const SizedBox(height: 10),
          select('branch', 'Branch', _f.branch, [for (final b in picker?.branches ?? const []) (b, b)],
              (v) => _f = _f.copyWith(branch: v)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              dateButton('Assigned from', _f.from, true),
              dateButton('Assigned to', _f.to, false),
              if (_f != const TrainingReportFilter())
                TextButton(
                  key: const Key('training-report-clear'),
                  onPressed: () => setState(() => _f = const TrainingReportFilter()),
                  child: const Text('Clear filters'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...rowsAsync.when(
            skipLoadingOnRefresh: true,
            loading: () => [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ),
            ],
            error: (e, _) => [AppErrorState.forError(e, onRetry: () => ref.invalidate(trainingReportProvider(_f)))],
            data: (rows) => [
              Row(
                children: [
                  Expanded(
                    child: Text('${rows.length} record(s)',
                        key: const Key('training-report-count'),
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ),
                  OutlinedButton.icon(
                    key: const Key('training-report-export'),
                    onPressed: _exporting || rows.isEmpty ? null : _export,
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: Text(_exporting ? 'Exporting…' : 'Export CSV'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (rows.isEmpty) const TrainingNote('No matching records.', icon: Icons.search_off),
              for (final r in rows) TrainingAssignmentCard(row: r, showCourse: true),
            ],
          ),
        ],
      ),
    );
  }
}
