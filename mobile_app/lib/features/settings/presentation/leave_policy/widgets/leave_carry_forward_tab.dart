import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../auth/presentation/providers/auth_providers.dart';
import '../../../data/datasources/settings_remote_datasource.dart';
import '../../../data/models/leave_policy_model.dart';
import '../../providers/settings_providers.dart';

const kCarryForwardRoles = ['system_admin', 'hr_admin', 'hr'];

/// The "Carry Forward" tab — mirrors web's `CarryForwardTab.tsx` exactly:
/// pick a from/to year range, Preview what would happen, then Run it.
///
/// IMPORTANT: as of this writing, none of the 4 endpoints this tab calls
/// (`/leave/carry-forward/years|preview|run|history/`) exist anywhere in the
/// Django backend (confirmed by grepping apps/hrms/urls.py) — so every
/// action here 404s on the real server today, exactly as it does on the web
/// app itself. This is not a mobile-only stub: it's a faithful port of a
/// feature the web team built the frontend for before the backend, and it
/// will start working the moment those routes are added — no mobile changes
/// needed then. See ApiConstants.carryForward* for the same note.
class LeaveCarryForwardTab extends ConsumerStatefulWidget {
  const LeaveCarryForwardTab({super.key});

  @override
  ConsumerState<LeaveCarryForwardTab> createState() => _LeaveCarryForwardTabState();
}

class _LeaveCarryForwardTabState extends ConsumerState<LeaveCarryForwardTab> {
  int? _fromYear;
  int? _toYear;
  bool _yearsInitialized = false;

  CarryForwardPreviewModel? _preview;
  bool _previewLoading = false;
  String? _previewError;

  bool _running = false;
  String? _runError;
  String? _duplicateWarning;

  SettingsRemoteDataSource get _ds => ref.read(settingsDataSourceProvider);

  void _onYearChanged() {
    setState(() {
      _preview = null;
      _previewError = null;
      _duplicateWarning = null;
    });
  }

  Future<void> _runPreview() async {
    final from = _fromYear, to = _toYear;
    if (from == null || to == null) return;
    setState(() {
      _previewLoading = true;
      _previewError = null;
    });
    try {
      final result = await _ds.previewCarryForward(fromYear: from, toYear: to);
      if (!mounted) return;
      setState(() => _preview = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _previewError = friendlySettingsError(e));
    } finally {
      if (mounted) setState(() => _previewLoading = false);
    }
  }

  Future<void> _confirmRun() async {
    final from = _fromYear, to = _toYear;
    if (from == null || to == null) return;
    setState(() {
      _running = true;
      _runError = null;
    });
    try {
      final result = await _ds.runCarryForward(fromYear: from, toYear: to);
      if (!mounted) return;
      Navigator.pop(context);
      setState(() => _duplicateWarning = null);
      ref.invalidate(carryForwardHistoryProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Carry forward completed. ${result.totalProcessed} processed, ${result.totalSkipped} skipped.'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      final msg = friendlySettingsError(e);
      // Mirrors web's 409-vs-other split: a duplicate-period run surfaces as
      // an inline dismissible warning rather than a generic error banner.
      if (msg.toLowerCase().contains('already') || msg.toLowerCase().contains('duplicate')) {
        setState(() => _duplicateWarning = msg);
      } else {
        setState(() => _runError = msg);
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  void _showRunConfirm() {
    setState(() => _runError = null);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          const Text('Run Carry Forward'),
        ]),
        content: Text(
          'This will carry forward unused leave'
          '${_preview != null && _preview!.fromYear == _fromYear && _preview!.toYear == _toYear ? ' for ${_preview!.pendingCount} employee-leave combination${_preview!.pendingCount != 1 ? 's' : ''}' : ''}'
          ' from $_fromYear to $_toYear. This cannot be undone. Continue?',
          style: AppTextStyles.body.copyWith(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: _running ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _running ? null : _confirmRun,
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: _running
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Run Carry Forward'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authStateProvider).valueOrNull?.user?.role;
    if (role != null && !kCarryForwardRoles.contains(role)) {
      return const _LockedView();
    }

    final yearsAsync = ref.watch(carryForwardYearsProvider);

    return yearsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorCard(
        message: '${friendlySettingsError(e)} — unable to load available year pairs.',
      ),
      data: (years) {
        if (!_yearsInitialized) {
          _fromYear = years.defaultFrom;
          _toYear = years.defaultTo;
          _yearsInitialized = true;
        }
        final fromOptions = years.years.map((y) => y.fromYear).toSet().toList()..sort();
        final toOptions = years.years
            .map((y) => y.toYear)
            .toSet()
            .where((y) => _fromYear == null || y > _fromYear!)
            .toList()
          ..sort();
        final noYears = fromOptions.isEmpty;

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(carryForwardYearsProvider);
            ref.invalidate(carryForwardHistoryProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // ── Scope banner ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(Icons.repeat_rounded, size: 20, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Carry Forward Unused Leave',
                              style: AppTextStyles.label
                                  .copyWith(fontWeight: FontWeight.w700, fontSize: 13)),
                          const SizedBox(height: 3),
                          Text(
                            'Select a year range, preview what will happen, then run to '
                            'carry forward unused leave balances into the next year.',
                            style: AppTextStyles.caption
                                .copyWith(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (noYears)
                const _EmptyCard(
                  icon: Icons.event_busy_outlined,
                  title: 'No leave year data found',
                  message:
                      'Employees must have leave balances recorded before carry-forward can be run.',
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppColors.cardShadow,
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _YearDropdown(
                              label: 'From Year',
                              value: _fromYear,
                              options: fromOptions,
                              onChanged: (v) {
                                setState(() => _fromYear = v);
                                _onYearChanged();
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _YearDropdown(
                              label: 'To Year',
                              value: _toYear,
                              options: toOptions,
                              onChanged: (v) {
                                setState(() => _toYear = v);
                                _onYearChanged();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: (_previewLoading || _running || _fromYear == null || _toYear == null)
                                  ? null
                                  : _runPreview,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(46),
                                foregroundColor: AppColors.primary,
                                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: _previewLoading
                                  ? SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: AppColors.primary))
                                  : const Icon(Icons.visibility_outlined, size: 16),
                              label: Text(_previewLoading ? 'Previewing…' : 'Preview'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: (_previewLoading || _running || _fromYear == null || _toYear == null)
                                  ? null
                                  : _showRunConfirm,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(46),
                                backgroundColor: AppColors.error,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.play_arrow_rounded, size: 16),
                              label: const Text('Run'),
                            ),
                          ),
                        ],
                      ),
                      if (_previewError != null) ...[
                        const SizedBox(height: 12),
                        _InlineError(message: _previewError!),
                      ],
                      if (_runError != null) ...[
                        const SizedBox(height: 12),
                        _InlineError(message: _runError!),
                      ],
                    ],
                  ),
                ),

              if (_duplicateWarning != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_duplicateWarning!,
                            style: AppTextStyles.body.copyWith(fontSize: 12, height: 1.4)),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _duplicateWarning = null),
                        icon: const Icon(Icons.close, size: 16),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ],

              if (_preview != null) ...[
                const SizedBox(height: 16),
                _PreviewCard(preview: _preview!),
              ],

              const SizedBox(height: 16),
              const _HistoryCard(),
            ],
          ),
        );
      },
    );
  }
}

// ── Year dropdown ──────────────────────────────────────────────────────────────

class _YearDropdown extends StatelessWidget {
  final String label;
  final int? value;
  final List<int> options;
  final ValueChanged<int?> onChanged;
  const _YearDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final safeOptions = options.toSet().toList()..sort();
    if (value != null && !safeOptions.contains(value)) safeOptions.add(value!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        DropdownButtonFormField<int>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.border)),
          ),
          items: safeOptions
              .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ── Preview card ───────────────────────────────────────────────────────────────

class _PreviewCard extends StatelessWidget {
  final CarryForwardPreviewModel preview;
  const _PreviewCard({required this.preview});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.visibility_outlined, size: 15, color: AppColors.primary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Preview — ${preview.fromYear} → ${preview.toYear}',
                      style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              _MiniBadge(label: 'Total: ${preview.totalRows}', color: AppColors.textSecondary),
              _MiniBadge(label: 'To Process: ${preview.pendingCount}', color: AppColors.success),
              _MiniBadge(
                  label: 'Already Done: ${preview.alreadyProcessedCount}',
                  color: AppColors.textSecondary),
            ]),
          ),
          Divider(height: 1, color: AppColors.border),
          if (preview.totalRows == 0)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('Nothing to carry forward for this period.',
                    style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
              ),
            )
          else
            ...preview.previewRows.map((row) => Opacity(
                  opacity: row.alreadyProcessed ? 0.55 : 1,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${row.employeeName} · ${row.employeeId}',
                                  style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(
                                  '${row.leaveTypeDisplay} · ${row.unusedDays} unused → '
                                  '${row.carryForwardAmount} carried · expires ${row.expiryDate ?? 'Never'}',
                                  style: AppTextStyles.caption
                                      .copyWith(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _MiniBadge(
                          label: row.alreadyProcessed ? 'Already Done' : 'Pending',
                          color: row.alreadyProcessed ? AppColors.textHint : AppColors.info,
                        ),
                      ],
                    ),
                  ),
                )),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── History card ───────────────────────────────────────────────────────────────

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(carryForwardHistoryProvider);
    final page = ref.watch(carryForwardHistoryPageProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.history, size: 15, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Text('Carry Forward History',
                  style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
          ),
          Divider(height: 1, color: AppColors.border),
          historyAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(20),
              child: Text(friendlySettingsError(e),
                  style: AppTextStyles.body.copyWith(color: AppColors.error, fontSize: 12)),
            ),
            data: (history) {
              if (history.results.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text('No carry-forward runs have been executed yet.',
                        style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
                  ),
                );
              }
              return Column(
                children: [
                  ...history.results.map((log) => Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${log.fromYear} → ${log.toYear}',
                                      style: AppTextStyles.bodySmall
                                          .copyWith(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  Text(
                                      'By ${log.executedByName} · ${log.totalProcessed} processed, '
                                      '${log.totalSkipped} skipped'
                                      '${log.totalFailed > 0 ? ', ${log.totalFailed} failed' : ''}',
                                      style: AppTextStyles.caption
                                          .copyWith(fontSize: 11, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            _MiniBadge(
                              label: log.isCompleted ? 'Completed' : 'Incomplete',
                              color: log.isCompleted ? AppColors.success : AppColors.warning,
                            ),
                          ],
                        ),
                      )),
                  if (history.totalPages > 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Page $page of ${history.totalPages}',
                              style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
                          Row(children: [
                            TextButton(
                              onPressed: page > 1
                                  ? () => ref.read(carryForwardHistoryPageProvider.notifier).state =
                                      page - 1
                                  : null,
                              child: const Text('Prev'),
                            ),
                            TextButton(
                              onPressed: page < history.totalPages
                                  ? () => ref.read(carryForwardHistoryPageProvider.notifier).state =
                                      page + 1
                                  : null,
                              child: const Text('Next'),
                            ),
                          ]),
                        ],
                      ),
                    )
                  else
                    const SizedBox(height: 4),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Shared small pieces ─────────────────────────────────────────────────────────

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: AppTextStyles.caption
                .copyWith(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      );
}

class _InlineError extends StatelessWidget {
  final String message;
  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(message,
            style: AppTextStyles.body.copyWith(color: AppColors.error, fontSize: 12)),
      );
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _EmptyCard({required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(title, style: AppTextStyles.h4, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message, style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
          ],
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.textHint),
              const SizedBox(height: 12),
              Text('Could not load', style: AppTextStyles.h4),
              const SizedBox(height: 6),
              Text(message, style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

class _LockedView extends StatelessWidget {
  const _LockedView();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 48, color: AppColors.textHint),
              const SizedBox(height: 12),
              Text('Access Denied', style: AppTextStyles.h4),
              const SizedBox(height: 6),
              Text('You do not have permission to view carry-forward operations.',
                  style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
