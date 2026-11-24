import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/router/access_control.dart' show userHasPermission;
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../shared/formatters/en_in_format.dart' show formatEnInDate;
import '../../../../approvals/presentation/widgets/approvals_kit.dart';
import '../../../../approvals/presentation/widgets/approvals_ui.dart'
    show ApprovalsBadge, ApprovalsIconBox, ApprovalsTone;
import '../../../../auth/domain/entities/user_entity.dart';
import '../../../../auth/presentation/providers/auth_providers.dart';
import '../../../../leave/presentation/providers/leave_providers.dart';
import '../../../data/datasources/settings_remote_datasource.dart';
import '../../../data/models/leave_policy_model.dart';
import '../../providers/settings_providers.dart';

/// Who sees the Carry Forward tab and the "Import Opening Balances" action:
/// web leave-policy page shows both with usePermission("leave.edit") — a
/// permission, never a role name (a Branch Admin holding it sees them too).
/// The server is authoritative: the carry-forward and opening-balance
/// endpoints require leave.approve and their refusal is shown as sent.
bool canManageCarryForward(UserEntity? user) => userHasPermission(user, 'leave.edit');

/// The "Carry Forward" tab — mirrors web's `CarryForwardTab.tsx`: pick a
/// from/to year range, Preview what would happen, then Run it; below, the
/// history of runs (paged, 20 a page).
///
/// Endpoints (`ApiConstants.carryForward*`):
///   GET  /leave/carry-forward/years/    — year pairs + defaults (read)
///   GET  /leave/carry-forward/history/  — past runs, paged (read)
///   POST /leave/carry-forward/preview/  — {from_year, to_year}; dry run
///   POST /leave/carry-forward/run/      — {from_year, to_year}; WRITES balances
///
/// Deliberate difference from web (Task 88 / HO-37): Run is enabled only after
/// a successful Preview for exactly the selected years (web allows Run without
/// one). Run writes leave balances and the POSTs were never exercised on
/// production, so a failed or missing preview can never lead to a Run. The
/// guard is keyed on the years the preview was REQUESTED for. After a run the
/// preview is cleared, so a second run needs a fresh preview (and cannot be
/// double-submitted from stale numbers).
class LeaveCarryForwardTab extends ConsumerStatefulWidget {
  const LeaveCarryForwardTab({super.key});

  @override
  ConsumerState<LeaveCarryForwardTab> createState() => _LeaveCarryForwardTabState();
}

/// What a Run attempt came back with (the HTTP status drives web's handling:
/// 409 = already executed, 400 = invalid selection, anything else = generic).
class _RunOutcome {
  const _RunOutcome({this.log, this.status, this.message = ''});
  final CarryForwardLogModel? log;
  final int? status;
  final String message;
  bool get ok => log != null;
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

  (int, int)? _previewedFor;
  bool get _hasMatchingPreview => _preview != null && _previewedFor != null && _previewedFor == (_fromYear, _toYear);

  void _onYearChanged() {
    setState(() {
      _preview = null;
      _previewedFor = null;
      _previewError = null;
      _duplicateWarning = null;
    });
  }

  Future<void> _runPreview() async {
    final from = _fromYear, to = _toYear;
    if (from == null || to == null || _previewLoading || _running) return;
    setState(() {
      _previewLoading = true;
      _previewError = null;
    });
    try {
      final result = await _ds.previewCarryForward(fromYear: from, toYear: to);
      if (!mounted) return;
      // Ignore a late response for years the user has since changed.
      if (_fromYear != from || _toYear != to) return;
      setState(() {
        _preview = result;
        _previewedFor = (from, to);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _preview = null;
        _previewedFor = null;
        _previewError = friendlySettingsError(e);
      });
    } finally {
      if (mounted) setState(() => _previewLoading = false);
    }
  }

  /// The one place that writes. Guarded against a second call while one is in flight.
  Future<_RunOutcome> _executeRun() async {
    final from = _fromYear, to = _toYear;
    if (from == null || to == null || _running) return const _RunOutcome(message: 'Already running.');
    setState(() {
      _running = true;
      _runError = null;
    });
    try {
      final log = await _ds.runCarryForward(fromYear: from, toYear: to);
      return _RunOutcome(log: log);
    } catch (e) {
      return _RunOutcome(status: e is DioException ? e.response?.statusCode : null, message: friendlySettingsError(e));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  /// Applies a finished run to the screen, as web's confirmRun does.
  void _applyOutcome(_RunOutcome o) {
    if (!mounted) return;
    if (o.ok) {
      final log = o.log!;
      setState(() {
        _duplicateWarning = null;
        // The balances changed: the old preview is stale, so a further run needs a new one.
        _preview = null;
        _previewedFor = null;
      });
      ref.invalidate(carryForwardHistoryProvider);
      ref.invalidate(carryForwardYearsProvider);
      // Leave balances and statistics that were read before this run are out of date now.
      ref.invalidate(leaveBalancesProvider);
      ref.invalidate(myLeaveBalancesProvider);
      ref.invalidate(leaveStatsProvider);
      ref.invalidate(myLeaveStatsProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Carry forward completed. ${log.totalProcessed} processed, ${log.totalSkipped} skipped.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    } else if (o.status == 409) {
      setState(() => _duplicateWarning = o.message.isNotEmpty
          ? o.message
          : 'This period has already been executed. Select a different year range or check the history below.');
    } else if (o.status == 400) {
      setState(() => _runError = o.message.isNotEmpty ? o.message : 'Invalid year selection.');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Something went wrong. Please try again.'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _showRunConfirm() async {
    final from = _fromYear, to = _toYear;
    if (from == null || to == null || _running) return;
    setState(() => _runError = null);
    final p = _hasMatchingPreview ? _preview : null;
    final outcome = await showDialog<_RunOutcome>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RunConfirmDialog(
        fromYear: from,
        toYear: to,
        pendingCount: p?.pendingCount,
        alreadyProcessedCount: p?.alreadyProcessedCount,
        onRun: _executeRun,
      ),
    );
    if (outcome != null) _applyOutcome(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    if (user != null && !canManageCarryForward(user)) {
      return const _Centered(
        child: ApprovalsEmptyState(
          key: Key('carry-forward-denied'),
          kind: ApprovalsStateKind.denied,
          title: 'Access Denied',
          message: 'You do not have permission to view carry-forward operations.',
        ),
      );
    }

    final yearsAsync = ref.watch(carryForwardYearsProvider);
    return yearsAsync.when(
      loading: () => const _Centered(child: ApprovalsLoading(label: 'Loading year options…')),
      error: (e, _) => _Centered(
        child: ApprovalsEmptyState.forError(e,
            key: const Key('carry-forward-years-error'),
            what: 'year options',
            onRetry: () => ref.invalidate(carryForwardYearsProvider)),
      ),
      data: (years) {
        if (!_yearsInitialized) {
          _fromYear = years.defaultFrom;
          _toYear = years.defaultTo;
          _yearsInitialized = true;
        }
        final fromOptions = years.years.map((y) => y.fromYear).toSet().toList()..sort();
        final toOptions =
            years.years.map((y) => y.toYear).toSet().where((y) => _fromYear == null || y > _fromYear!).toList()..sort();
        final noYears = fromOptions.isEmpty;

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(carryForwardYearsProvider);
            ref.invalidate(carryForwardHistoryProvider);
          },
          child: LayoutBuilder(builder: (context, box) {
            final wide = box.maxWidth >= 700;
            final side = box.maxWidth > 1000 ? (box.maxWidth - 1000) / 2 : 16.0;
            final controls = noYears
                ? const ApprovalsEmptyState(
                    key: Key('carry-forward-no-years'),
                    kind: ApprovalsStateKind.empty,
                    title: 'No leave year data found',
                    message: 'Employees must have leave balances recorded before carry-forward can be run.',
                    icon: Icons.event_busy_outlined,
                    compact: true,
                  )
                : _ControlsCard(
                    fromYear: _fromYear,
                    toYear: _toYear,
                    fromOptions: fromOptions,
                    toOptions: toOptions,
                    previewLoading: _previewLoading,
                    running: _running,
                    hasMatchingPreview: _hasMatchingPreview,
                    previewError: _previewError,
                    runError: _runError,
                    onFrom: (v) {
                      setState(() {
                        _fromYear = v;
                        // A To Year that is no longer after From is replaced by the first valid one.
                        final valid = years.years.map((y) => y.toYear).toSet().where((y) => v == null || y > v).toList()
                          ..sort();
                        if (_toYear == null || !valid.contains(_toYear)) _toYear = valid.isEmpty ? null : valid.first;
                      });
                      _onYearChanged();
                    },
                    onTo: (v) {
                      setState(() => _toYear = v);
                      _onYearChanged();
                    },
                    onPreview: _runPreview,
                    onRun: _showRunConfirm,
                  );
            return ListView(
              key: const Key('carry-forward-list'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(side, 16, side, 32),
              children: [
                const _ScopeBanner(),
                const SizedBox(height: 16),
                controls,
                if (_duplicateWarning != null) ...[
                  const SizedBox(height: 16),
                  _DuplicateWarning(
                      message: _duplicateWarning!, onClose: () => setState(() => _duplicateWarning = null)),
                ],
                if (_preview != null) ...[
                  const SizedBox(height: 16),
                  _PreviewCard(preview: _preview!, wide: wide),
                ],
                const SizedBox(height: 16),
                _HistoryCard(wide: wide),
              ],
            );
          }),
        );
      },
    );
  }
}

// ── Pieces ──────────────────────────────────────────────────────────────────────

class _Centered extends StatelessWidget {
  const _Centered({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [child],
      );
}

BoxDecoration _cardBox() => BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    );

class _ScopeBanner extends StatelessWidget {
  const _ScopeBanner();
  @override
  Widget build(BuildContext context) => Container(
        key: const Key('carry-forward-banner'),
        padding: const EdgeInsets.all(14),
        decoration: _cardBox().copyWith(border: Border.all(color: AppColors.primary.withValues(alpha: 0.25))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ApprovalsIconBox(Icons.repeat_rounded, color: AppColors.primary, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Carry Forward Unused Leave',
                  style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 3),
              Text(
                'Select a year range, preview what will happen, then run to carry forward unused leave balances into the next year.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.4),
              ),
            ]),
          ),
        ]),
      );
}

/// From / To year, Preview and Run — pairs side by side when there is room, stacked
/// (full-width ≥44dp buttons) on a narrow screen or at large text.
class _ControlsCard extends StatelessWidget {
  const _ControlsCard({
    required this.fromYear,
    required this.toYear,
    required this.fromOptions,
    required this.toOptions,
    required this.previewLoading,
    required this.running,
    required this.hasMatchingPreview,
    required this.previewError,
    required this.runError,
    required this.onFrom,
    required this.onTo,
    required this.onPreview,
    required this.onRun,
  });

  final int? fromYear;
  final int? toYear;
  final List<int> fromOptions;
  final List<int> toOptions;
  final bool previewLoading;
  final bool running;
  final bool hasMatchingPreview;
  final String? previewError;
  final String? runError;
  final ValueChanged<int?> onFrom;
  final ValueChanged<int?> onTo;
  final VoidCallback onPreview;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    final busy = previewLoading || running;
    final ready = fromYear != null && toYear != null;
    final preview = OutlinedButton.icon(
      key: const Key('carry-forward-preview'),
      onPressed: busy || !ready ? null : onPreview,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        foregroundColor: AppColors.primary,
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.45)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      icon: previewLoading
          ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
          : const Icon(Icons.visibility_outlined, size: 18),
      label: Text(previewLoading ? 'Previewing…' : 'Preview'),
    );
    final run = FilledButton.icon(
      key: const Key('carry-forward-run'),
      onPressed: busy || !ready || !hasMatchingPreview ? null : onRun,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        backgroundColor: AppColors.error,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      icon: const Icon(Icons.play_arrow_rounded, size: 18),
      label: const Text('Run Carry Forward'),
    );
    return Container(
      key: const Key('carry-forward-controls'),
      decoration: _cardBox(),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        LayoutBuilder(builder: (context, c) {
          final stacked = c.maxWidth < 300 || scale > 1.3;
          final from = _YearField(label: 'From Year', value: fromYear, options: fromOptions, onChanged: onFrom);
          final to = _YearField(label: 'To Year', value: toYear, options: toOptions, onChanged: onTo);
          return stacked
              ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [from, const SizedBox(height: 12), to])
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: from),
                  const SizedBox(width: 12),
                  Expanded(child: to),
                ]);
        }),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, c) {
          final stacked = c.maxWidth < 340 || scale > 1.3;
          return stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch, children: [preview, const SizedBox(height: 8), run])
              : Row(children: [Expanded(child: preview), const SizedBox(width: 10), Expanded(child: run)]);
        }),
        if (!hasMatchingPreview) ...[
          const SizedBox(height: 12),
          Row(
            key: const Key('carry-forward-preview-required'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Preview the selected years first. Run is enabled only after a successful preview.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
        if (previewError != null) ...[const SizedBox(height: 12), _InlineError(message: previewError!)],
        if (runError != null) ...[const SizedBox(height: 12), _InlineError(message: runError!)],
      ]),
    );
  }
}

class _YearField extends StatelessWidget {
  const _YearField({required this.label, required this.value, required this.options, required this.onChanged});
  final String label;
  final int? value;
  final List<int> options;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final safe = options.toSet().toList()..sort();
    if (value != null && !safe.contains(value)) safe.add(value!);
    OutlineInputBorder border(Color c) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      DropdownButtonFormField<int>(
        key: Key('carry-forward-${label.toLowerCase().replaceAll(' ', '-')}'),
        initialValue: value,
        isExpanded: true,
        borderRadius: BorderRadius.circular(12),
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          border: border(AppColors.border),
          enabledBorder: border(AppColors.border),
          focusedBorder: border(AppColors.primary),
        ),
        items: [for (final y in safe) DropdownMenuItem(value: y, child: Text('$y'))],
        onChanged: onChanged,
      ),
    ]);
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.error_outline, size: 18, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error))),
        ]),
      );
}

class _DuplicateWarning extends StatelessWidget {
  const _DuplicateWarning({required this.message, required this.onClose});
  final String message;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) => Container(
        key: const Key('carry-forward-duplicate'),
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: AppTextStyles.bodySmall.copyWith(height: 1.45))),
          IconButton(
            tooltip: 'Dismiss',
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 18),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ]),
      );
}

/// Labelled number: the small caption above a bold value.
class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value, {this.color});
  final String label;
  final String value;
  final Color? color;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 1),
        Text(value,
            style: AppTextStyles.label
                .copyWith(fontWeight: FontWeight.w700, fontSize: 15, color: color ?? AppColors.textPrimary)),
      ]);
}

class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.icon, required this.title});
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Row(children: [
          ApprovalsIconBox(icon, color: AppColors.primary, size: 32),
          const SizedBox(width: 10),
          Expanded(
              child: Semantics(
                  header: true,
                  child: Text(title, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, fontSize: 14)))),
        ]),
      );
}

/// A title with a status badge: side by side when there is room, the badge under the
/// title on a narrow card or at large text (so a long name is never squeezed mid-word).
class _HeadWithBadge extends StatelessWidget {
  const _HeadWithBadge({required this.title, required this.badge});
  final Widget title;
  final Widget badge;
  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    return LayoutBuilder(builder: (context, c) {
      final stacked = c.maxWidth < 280 || scale > 1.3;
      if (stacked) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 6), badge]);
      }
      return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: title), const SizedBox(width: 8), badge]);
    });
  }
}

// ── Preview ─────────────────────────────────────────────────────────────────────

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview, required this.wide});
  final CarryForwardPreviewModel preview;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final rows = preview.previewRows;
    return Container(
      key: const Key('carry-forward-preview-card'),
      decoration: _cardBox(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // "Preview — 2025 → 2026": the arrow is an icon, not a glyph the font may lack.
        _SectionHead(icon: Icons.visibility_outlined, title: 'Preview — ${preview.fromYear} to ${preview.toYear}'),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Wrap(spacing: 18, runSpacing: 10, children: [
            _Figure('Total rows', '${preview.totalRows}'),
            _Figure('To process', '${preview.pendingCount}', color: AppColors.success),
            _Figure('Already done', '${preview.alreadyProcessedCount}'),
          ]),
        ),
        Divider(height: 1, color: AppColors.border),
        if (preview.totalRows == 0)
          const Padding(
            padding: EdgeInsets.all(12),
            child: ApprovalsEmptyState(
              key: Key('carry-forward-preview-empty'),
              kind: ApprovalsStateKind.empty,
              title: 'Nothing to carry forward',
              message: 'No employees have unused leave to carry forward for this period.',
              icon: Icons.event_busy_outlined,
              compact: true,
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(builder: (context, c) {
              final cols = wide ? 2 : 1;
              final w = (c.maxWidth - 10 * (cols - 1)) / cols;
              return Wrap(spacing: 10, runSpacing: 10, children: [
                for (var i = 0; i < rows.length; i++) SizedBox(width: w, child: _PreviewRow(row: rows[i], index: i)),
              ]);
            }),
          ),
      ]),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.row, required this.index});
  final CarryForwardPreviewRow row;
  final int index;

  @override
  Widget build(BuildContext context) {
    final done = row.alreadyProcessed;
    return Opacity(
      opacity: done ? 0.6 : 1,
      child: Container(
        key: Key('carry-forward-row-$index'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _HeadWithBadge(
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(row.employeeName,
                  style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, fontSize: 14, height: 1.3)),
              const SizedBox(height: 2),
              Text(row.employeeId,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ]),
            badge: ApprovalsBadge(done ? 'Already Done' : 'Pending', done ? ApprovalsTone.neutral : ApprovalsTone.info),
          ),
          const SizedBox(height: 8),
          Text(row.leaveTypeDisplay, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          Wrap(spacing: 20, runSpacing: 8, children: [
            _Figure('Unused days', '${row.unusedDays}'),
            _Figure('Carry forward', '${row.carryForwardAmount}', color: AppColors.primary),
            _Figure('Expiry date', row.expiryDate ?? 'Never'),
          ]),
        ]),
      ),
    );
  }
}

// ── History ─────────────────────────────────────────────────────────────────────

/// Web fmtDateTime: "6 Nov 2026, 10:15" (24-hour, local time).
String _fmtDateTime(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '—';
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${formatEnInDate(d)}, $hh:$mm';
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(carryForwardHistoryProvider);
    final page = ref.watch(carryForwardHistoryPageProvider);
    return Container(
      key: const Key('carry-forward-history'),
      decoration: _cardBox(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const _SectionHead(icon: Icons.history, title: 'Carry Forward History'),
        Divider(height: 1, color: AppColors.border),
        historyAsync.when(
          loading: () => const ApprovalsLoading(label: 'Loading history…'),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(12),
            child: ApprovalsEmptyState.forError(e,
                key: const Key('carry-forward-history-error'),
                what: 'history',
                compact: true,
                onRetry: () => ref.invalidate(carryForwardHistoryProvider)),
          ),
          data: (history) {
            if (history.results.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: ApprovalsEmptyState(
                  key: Key('carry-forward-history-empty'),
                  kind: ApprovalsStateKind.empty,
                  title: 'No history yet',
                  message: 'No carry-forward runs have been executed yet.',
                  icon: Icons.history_toggle_off,
                  compact: true,
                ),
              );
            }
            return Column(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: LayoutBuilder(builder: (context, c) {
                  final cols = wide ? 2 : 1;
                  final w = (c.maxWidth - 10 * (cols - 1)) / cols;
                  return Wrap(spacing: 10, runSpacing: 10, children: [
                    for (final log in history.results) SizedBox(width: w, child: _HistoryRow(log: log)),
                  ]);
                }),
              ),
              if (history.totalPages > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 6,
                    children: [
                      Text('Page $page of ${history.totalPages}',
                          key: const Key('carry-forward-page'),
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        OutlinedButton.icon(
                          key: const Key('carry-forward-prev'),
                          onPressed: page > 1
                              ? () => ref.read(carryForwardHistoryPageProvider.notifier).state = page - 1
                              : null,
                          style: _pager(),
                          icon: const Icon(Icons.chevron_left, size: 18),
                          label: const Text('Prev'),
                        ),
                        OutlinedButton(
                          key: const Key('carry-forward-next'),
                          onPressed: page < history.totalPages
                              ? () => ref.read(carryForwardHistoryPageProvider.notifier).state = page + 1
                              : null,
                          style: _pager(),
                          child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [Text('Next'), Icon(Icons.chevron_right, size: 18)]),
                        ),
                      ]),
                    ],
                  ),
                ),
            ]);
          },
        ),
      ]),
    );
  }

  ButtonStyle _pager() => OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        foregroundColor: AppColors.primary,
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      );
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.log});
  final CarryForwardLogModel log;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('carry-forward-log-${log.id}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _HeadWithBadge(
          title: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
            Text('${log.fromYear}', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
            Icon(Icons.arrow_forward, size: 16, color: AppColors.textSecondary),
            Text('${log.toYear}', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
          ]),
          badge: ApprovalsBadge(log.isCompleted ? 'Completed' : 'Incomplete',
              log.isCompleted ? ApprovalsTone.success : ApprovalsTone.warning),
        ),
        const SizedBox(height: 6),
        Text('Executed by ${log.executedByName.isEmpty ? '—' : log.executedByName}',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        Wrap(spacing: 20, runSpacing: 8, children: [
          _Figure('Processed', '${log.totalProcessed}', color: AppColors.success),
          _Figure('Skipped', '${log.totalSkipped}'),
          _Figure('Failed', '${log.totalFailed}', color: log.totalFailed > 0 ? AppColors.error : null),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.schedule, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Expanded(
            child: Text(_fmtDateTime(log.createdAt),
                key: Key('carry-forward-log-date-${log.id}'),
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          ),
        ]),
      ]),
    );
  }
}

// ── Run confirmation ────────────────────────────────────────────────────────────

/// Says exactly what will happen (years, how many employee-leave combinations
/// when a matching preview is known, that it cannot be undone), disables itself
/// while the run is in flight, and can only be closed once it has answered.
class _RunConfirmDialog extends StatefulWidget {
  const _RunConfirmDialog({
    required this.fromYear,
    required this.toYear,
    required this.pendingCount,
    required this.alreadyProcessedCount,
    required this.onRun,
  });
  final int fromYear;
  final int toYear;
  final int? pendingCount;
  final int? alreadyProcessedCount;
  final Future<_RunOutcome> Function() onRun;

  @override
  State<_RunConfirmDialog> createState() => _RunConfirmDialogState();
}

class _RunConfirmDialogState extends State<_RunConfirmDialog> {
  bool _running = false;

  Future<void> _go() async {
    if (_running) return;
    setState(() => _running = true);
    final outcome = await widget.onRun();
    if (mounted) Navigator.of(context).pop(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.pendingCount;
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    final cancel = TextButton(
      key: const Key('carry-forward-confirm-cancel'),
      onPressed: _running ? null : () => Navigator.of(context).pop(),
      style: TextButton.styleFrom(foregroundColor: AppColors.primary, minimumSize: const Size(0, 44)),
      child: const Text('Cancel'),
    );
    final run = FilledButton(
      key: const Key('carry-forward-confirm-run'),
      onPressed: _running ? null : _go,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.error,
        disabledBackgroundColor: _running ? AppColors.error : null,
        disabledForegroundColor: _running ? Colors.white : null,
        minimumSize: const Size(0, 44),
      ),
      child: _running
          ? const Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 8),
              Text('Running…'),
            ])
          : const Text('Run Carry Forward'),
    );
    return PopScope(
      canPop: !_running,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(Icons.warning_amber_rounded, color: AppColors.error),
        ),
        title:
            Text('Run Carry Forward', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, fontSize: 17)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(
              'This will carry forward unused leave'
              '${n != null ? ' for $n employee-leave combination${n != 1 ? 's' : ''}' : ''}'
              ' from ${widget.fromYear} to ${widget.toYear}. This cannot be undone. Continue?',
              key: const Key('carry-forward-confirm-text'),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(height: 1.5),
            ),
            if (n != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.backgroundLow, borderRadius: BorderRadius.circular(10)),
                child: Wrap(alignment: WrapAlignment.center, spacing: 20, runSpacing: 8, children: [
                  _Figure('Period', '${widget.fromYear}–${widget.toYear}'),
                  _Figure('To process', '$n', color: AppColors.error),
                  if (widget.alreadyProcessedCount != null) _Figure('Already done', '${widget.alreadyProcessedCount}'),
                ]),
              ),
            ],
          ]),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowDirection: VerticalDirection.down,
        actions: scale > 1.3 ? [run, cancel] : [cancel, run],
      ),
    );
  }
}
