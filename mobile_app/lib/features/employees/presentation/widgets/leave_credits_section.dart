import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/leave_credit_models.dart';
import '../providers/leave_credit_providers.dart';

/// Web `new Date(iso).toLocaleString()`, in the device's local time.
String leaveCreditDateTime(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso.isEmpty ? '—' : iso;
  final l = d.toLocal();
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
  final min = l.minute.toString().padLeft(2, '0');
  return '${l.day} ${m[l.month - 1]} ${l.year}, $h:$min ${l.hour < 12 ? 'AM' : 'PM'}';
}

sealed class _Pending {
  const _Pending(this.reason, this.key);
  final String reason;
  final String key;
}

class _PendingAdjust extends _Pending {
  const _PendingAdjust(this.leaveType, this.label, this.amount, super.reason, super.key);
  final String leaveType;
  final String label;
  final double amount;
}

class _PendingReverse extends _Pending {
  const _PendingReverse(this.txn, super.reason, super.key);
  final LeaveCreditTxn txn;
}

/// Employee Profile → Leave → "Manage Leave Credits", as web
/// LeaveCreditsSection.tsx (mounted in LeaveTab's Annual view with
/// `schedule="annual"`): the yearly credit statement, signed adjustments and
/// compensating reversals behind a review/confirm step, the append-only
/// history and the monthly view. Renders nothing for users who may not
/// manage this employee's credits (no leave.approve, or the server's 403/404).
class LeaveCreditsSection extends ConsumerStatefulWidget {
  const LeaveCreditsSection({super.key, required this.employeeId, this.schedule = 'annual'});

  final String employeeId;

  /// Only leave types whose policy has this credit schedule; null shows all.
  final String? schedule;

  @override
  ConsumerState<LeaveCreditsSection> createState() => _LeaveCreditsSectionState();
}

class _LeaveCreditsSectionState extends ConsumerState<LeaveCreditsSection> {
  late int _year = DateTime.now().year;
  String? _leaveType;
  String? _formType;
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  final _reverseReason = TextEditingController();
  LeaveCreditTxn? _reverseFor;
  String _reverseKey = '';
  _Pending? _pending;
  bool _submitting = false;
  ({bool ok, String text})? _message;
  bool _historyOpen = false;
  bool _monthlyOpen = false;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    _reverseReason.dispose();
    super.dispose();
  }

  LeaveCreditQuery get _query => (employeeId: widget.employeeId, year: _year, leaveType: _leaveType);

  List<LeaveCreditRow> _rows(LeaveCreditOverview d) =>
      d.summaries.where((r) => widget.schedule == null || r.creditSchedule == widget.schedule).toList();

  List<LeaveCreditTypeOption> _typeOptions(LeaveCreditOverview d, List<LeaveCreditRow> rows) => [
        for (final r in rows) LeaveCreditTypeOption(value: r.leaveType, label: r.label),
        for (final t in d.assignable)
          if ((widget.schedule == null || t.creditSchedule == widget.schedule) &&
              !rows.any((r) => r.leaveType == t.value))
            t,
      ];

  String _selected(LeaveCreditOverview d, List<LeaveCreditRow> rows) =>
      d.leaveType != null && rows.any((r) => r.leaveType == d.leaveType) ? d.leaveType! : '';

  String _effectiveFormType(List<LeaveCreditTypeOption> options, String selected) {
    if (_formType != null && options.any((o) => o.value == _formType)) return _formType!;
    if (selected.isNotEmpty) return selected;
    return options.isEmpty ? '' : options.first.value;
  }

  void _changeYear(int delta) => setState(() {
        _year += delta;
        _pending = null;
      });

  void _reviewAdjustment(List<LeaveCreditTypeOption> options, String formType) {
    setState(() => _message = null);
    final raw = _amount.text.trim();
    final value = double.tryParse(raw);
    void fail(String t) => setState(() => _message = (ok: false, text: t));
    if (formType.isEmpty) return fail('Choose a leave type.');
    if (raw.isEmpty || value == null || !value.isFinite || value == 0) {
      return fail('Enter a non-zero number of days, e.g. 2 or -1.5.');
    }
    if (_reason.text.trim().isEmpty) return fail('A reason is required.');
    final label = options.where((o) => o.value == formType).firstOrNull?.label ?? formType;
    setState(() => _pending = _PendingAdjust(formType, label, value, _reason.text.trim(), newLeaveCreditKey()));
  }

  void _reviewReversal() {
    setState(() => _message = null);
    final txn = _reverseFor;
    if (txn == null) return;
    if (_reverseReason.text.trim().isEmpty) {
      setState(() => _message = (ok: false, text: 'A reason is required to reverse an adjustment.'));
      return;
    }
    if (_reverseKey.isEmpty) _reverseKey = newLeaveCreditKey();
    setState(() => _pending = _PendingReverse(txn, _reverseReason.text.trim(), _reverseKey));
  }

  Future<void> _confirm() async {
    final p = _pending;
    if (p == null || _submitting) return;
    setState(() {
      _submitting = true;
      _message = null;
    });
    final service = ref.read(leaveCreditServiceProvider);
    try {
      switch (p) {
        case _PendingAdjust():
          await service.adjust(
            employeeId: widget.employeeId,
            leaveType: p.leaveType,
            year: _year,
            amount: p.amount,
            reason: p.reason,
            idempotencyKey: p.key,
          );
          if (!mounted) return;
          _amount.clear();
          _reason.clear();
          _message = (ok: true, text: '${signedDays(p.amount)} day(s) recorded for ${p.label}.');
        case _PendingReverse():
          await service.reverse(
            employeeId: widget.employeeId,
            txnId: p.txn.id,
            reason: p.reason,
            idempotencyKey: p.key,
          );
          if (!mounted) return;
          _reverseFor = null;
          _reverseReason.clear();
          _reverseKey = '';
          _message = (ok: true, text: 'Adjustment reversed.');
      }
      setState(() => _pending = null);
    } on LeaveCreditBusy {
      // Another write is still running; this tap is ignored.
    } catch (e) {
      // The pending action keeps its key, so a retry can never apply twice.
      if (mounted) setState(() => _message = (ok: false, text: leaveCreditError(e)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(leaveCreditOverviewProvider(_query));
    final data = async.valueOrNull;
    if (async.hasValue && data == null) return const SizedBox.shrink(key: Key('leave-credits-hidden'));

    // The server preselects the first balance; if that type isn't in this
    // view, select the first one that is (web's useEffect).
    if (data != null && widget.schedule != null && data.leaveType != null) {
      final rows = _rows(data);
      if (rows.isNotEmpty && !rows.any((r) => r.leaveType == data.leaveType)) {
        final first = rows.first.leaveType;
        if (_leaveType != first) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _leaveType = first);
          });
        }
      }
    }

    final loading = async.isLoading;
    return Container(
      key: const Key('leave-credits-section'),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.tune, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(child: Text('Manage Leave Credits', style: AppTextStyles.label)),
              IconButton(
                key: const Key('leave-credit-year-prev'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: loading ? null : () => _changeYear(-1),
              ),
              Text('$_year', key: const Key('leave-credit-year'), style: AppTextStyles.label),
              IconButton(
                key: const Key('leave-credit-year-next'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: loading || (data != null && _year >= data.currentYear) ? null : () => _changeYear(1),
              ),
            ],
          ),
          if (async.hasError && data == null) ...[
            _Banner(
              key: const Key('leave-credit-load-error'),
              ok: false,
              text: leaveCreditError(async.error!),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('leave-credit-retry'),
                onPressed: () => ref.invalidate(leaveCreditOverviewProvider(_query)),
                child: const Text('Retry'),
              ),
            ),
          ],
          if (_message case final m?) ...[
            const SizedBox(height: 6),
            _Banner(key: const Key('leave-credit-message'), ok: m.ok, text: m.text),
          ],
          const SizedBox(height: 8),
          if (data == null && !async.hasError)
            Padding(
              key: const Key('leave-credit-loading'),
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else
            ..._body(data),
        ],
      ),
    );
  }

  List<Widget> _body(LeaveCreditOverview? data) {
    final rows = data == null ? const <LeaveCreditRow>[] : _rows(data);
    final selected = data == null ? '' : _selected(data, rows);
    final options = data == null ? const <LeaveCreditTypeOption>[] : _typeOptions(data, rows);
    final formType = _effectiveFormType(options, selected);
    final pending = _pending;
    final canEditYear = data != null && data.canEditYear;

    return [
      if (data == null || rows.isEmpty)
        Padding(
          key: const Key('leave-credit-empty'),
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Text(
            widget.schedule != null && data != null && data.summaries.isNotEmpty
                ? 'No ${widget.schedule} leave types for $_year.'
                : 'No leave balances for $_year.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySecondary,
          ),
        )
      else
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _StatementCard(
              row: r,
              selected: r.leaveType == selected,
              onTap: () => setState(() {
                _leaveType = r.leaveType;
                _reverseFor = null;
                _pending = null;
              }),
            ),
          ),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
        child: Text(
          '* Credited before adjustment history began (annual allocation, opening balance import and earlier '
          'changes). Not itemised.',
          style: AppTextStyles.caption.copyWith(fontSize: 10),
        ),
      ),
      if (canEditYear) ...[
        const SizedBox(height: 14),
        _Panel(
          key: const Key('leave-credit-adjust-form'),
          children: [
            Text('Assign or adjust credits for $_year', style: AppTextStyles.label.copyWith(fontSize: 13)),
            const SizedBox(height: 10),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Leave type', isDense: true),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  key: const Key('leave-credit-type'),
                  isExpanded: true,
                  isDense: true,
                  value: formType.isEmpty ? null : formType,
                  items: [
                    for (final o in options)
                      DropdownMenuItem(value: o.value, child: Text(o.label, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: pending != null ? null : (v) => setState(() => _formType = v),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('leave-credit-amount'),
              controller: _amount,
              enabled: pending == null,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(
                  labelText: 'Days (+ add / − remove)', hintText: 'e.g. 2 or -1.5', isDense: true),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('leave-credit-reason'),
              controller: _reason,
              enabled: pending == null,
              maxLength: 1000,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Reason (required)', isDense: true),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const Key('leave-credit-review'),
                onPressed: pending != null || _submitting ? null : () => _reviewAdjustment(options, formType),
                child: const Text('Review'),
              ),
            ),
          ],
        ),
      ],
      if (pending != null) ...[
        const SizedBox(height: 12),
        _ConfirmPanel(
          text: _confirmText(pending, data),
          submitting: _submitting,
          onConfirm: _confirm,
          onCancel: () => setState(() => _pending = null),
        ),
      ],
      if (selected.isNotEmpty && data != null) ...[
        const SizedBox(height: 12),
        _Collapsible(
          toggleKey: const Key('leave-credit-history-toggle'),
          title: 'Adjustment history — ${data.monthly?.label ?? data.leaveType}, $_year',
          open: _historyOpen,
          onToggle: () => setState(() {
            // A half-filled reversal shouldn't linger out of sight.
            if (_historyOpen) _reverseFor = null;
            _historyOpen = !_historyOpen;
          }),
          children: [
            if (data.transactions.isEmpty)
              Text('No manual adjustments recorded.', style: AppTextStyles.bodySecondary)
            else
              for (final t in data.transactions)
                _TxnCard(
                  txn: t,
                  showReverse: t.canReverse && canEditYear,
                  onReverse: pending != null
                      ? null
                      : () => setState(() {
                            _reverseFor = t;
                            _reverseReason.clear();
                            _reverseKey = '';
                            _pending = null;
                            _message = null;
                          }),
                ),
            if (_reverseFor case final r? when pending == null) ...[
              const SizedBox(height: 8),
              TextField(
                key: const Key('leave-credit-reverse-reason'),
                controller: _reverseReason,
                maxLength: 1000,
                minLines: 1,
                maxLines: 3,
                decoration:
                    InputDecoration(labelText: 'Reason for reversing ${signedDays(r.amount)} day(s)', isDense: true),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const Key('leave-credit-reverse-cancel'),
                    onPressed: () => setState(() => _reverseFor = null),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('leave-credit-reverse-review'),
                    onPressed: _reviewReversal,
                    child: const Text('Review'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ],
      if (selected.isNotEmpty && data?.monthly != null) ...[
        const SizedBox(height: 10),
        _Collapsible(
          toggleKey: const Key('leave-credit-monthly-toggle'),
          title: 'Monthly view — ${data!.monthly!.label}, $_year',
          open: _monthlyOpen,
          onToggle: () => setState(() => _monthlyOpen = !_monthlyOpen),
          children: [_MonthlyTable(monthly: data.monthly!, year: _year)],
        ),
      ],
    ];
  }

  List<InlineSpan> _confirmText(_Pending p, LeaveCreditOverview? data) {
    const bold = TextStyle(fontWeight: FontWeight.w700);
    return switch (p) {
      _PendingAdjust() => [
          const TextSpan(text: 'Record '),
          TextSpan(text: '${signedDays(p.amount)} day(s)', style: bold),
          const TextSpan(text: ' of '),
          TextSpan(text: p.label, style: bold),
          const TextSpan(text: ' for '),
          TextSpan(text: data?.fullName ?? '', style: bold),
          TextSpan(text: ' in $_year?\nReason: ${p.reason}'),
        ],
      _PendingReverse() => [
          const TextSpan(text: 'Reverse the '),
          TextSpan(text: '${signedDays(p.txn.amount)} day(s)', style: bold),
          TextSpan(
              text: ' adjustment from ${leaveCreditDateTime(p.txn.createdAt)}? This records a '
                  '${signedDays(-p.txn.amount)} day(s) entry; the original stays in history.\nReason: ${p.reason}'),
        ],
    };
  }
}

// ── Pieces ────────────────────────────────────────────────────────────────────

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.ok, required this.text});
  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = ok ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ok ? Icons.check_circle_outline : Icons.error_outline, size: 16, color: c),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: AppTextStyles.caption.copyWith(color: c, fontSize: 12))),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({super.key, required this.children, this.color});
  final List<Widget> children;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color?.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color ?? AppColors.border, width: color == null ? 1 : 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

class _ConfirmPanel extends StatelessWidget {
  const _ConfirmPanel({required this.text, required this.submitting, required this.onConfirm, required this.onCancel});
  final List<InlineSpan> text;
  final bool submitting;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => _Panel(
        key: const Key('leave-credit-confirm-panel'),
        color: AppColors.warning,
        children: [
          Text.rich(TextSpan(children: text),
              key: const Key('leave-credit-confirm-text'), style: AppTextStyles.body.copyWith(fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton(
                key: const Key('leave-credit-confirm'),
                onPressed: submitting ? null : onConfirm,
                child: Text(submitting ? 'Saving…' : 'Confirm'),
              ),
              const SizedBox(width: 8),
              TextButton(
                key: const Key('leave-credit-cancel'),
                onPressed: submitting ? null : onCancel,
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      );
}

class _StatementCard extends StatelessWidget {
  const _StatementCard({required this.row, required this.selected, required this.onTap});
  final LeaveCreditRow row;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, String value, {bool strong = false}) => SizedBox(
          width: 92,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10)),
              Text(value,
                  style: AppTextStyles.label
                      .copyWith(fontSize: 13, fontWeight: strong ? FontWeight.w800 : FontWeight.w600)),
            ],
          ),
        );
    return Material(
      color: selected ? AppColors.primary.withValues(alpha: 0.06) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: Key('leave-credit-row-${row.leaveType}'),
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row.label, style: AppTextStyles.label.copyWith(fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  cell('Allocated / Opening*', creditNum(row.openingOrAllocated)),
                  cell('Carry-forward', creditNum(row.carriedForward)),
                  cell('Adjustments', signedDays(row.manualAdjustments)),
                  cell('Total Credits', creditNum(row.totalCredits), strong: true),
                  cell('Used', creditNum(row.used)),
                  cell('Pending', creditNum(row.pending)),
                  cell('Remaining', creditNum(row.remaining), strong: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Collapsible extends StatelessWidget {
  const _Collapsible(
      {required this.toggleKey,
      required this.title,
      required this.open,
      required this.onToggle,
      required this.children});
  final Key toggleKey;
  final String title;
  final bool open;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: toggleKey,
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Row(
                    children: [
                      Expanded(child: Text(title, style: AppTextStyles.label.copyWith(fontSize: 13))),
                      Icon(open ? Icons.expand_less : Icons.expand_more, size: 18, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
            if (open)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
              ),
          ],
        ),
      );
}

String _short(String? id) => id == null ? '' : (id.length > 8 ? id.substring(0, 8) : id);

class _TxnCard extends StatelessWidget {
  const _TxnCard({required this.txn, required this.showReverse, required this.onReverse});
  final LeaveCreditTxn txn;
  final bool showReverse;
  final VoidCallback? onReverse;

  @override
  Widget build(BuildContext context) {
    final t = txn;
    Widget badge(String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.textSecondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(text, style: AppTextStyles.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w700)),
        );
    return Container(
      key: Key('leave-credit-txn-${t.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(signedDays(t.amount),
                  style: AppTextStyles.label.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: t.amount > 0 ? AppColors.success : AppColors.error)),
              const SizedBox(width: 8),
              Text('Total after ${creditNum(t.totalAfter)}', style: AppTextStyles.caption.copyWith(fontSize: 11)),
              const Spacer(),
              Text(leaveCreditDateTime(t.createdAt), style: AppTextStyles.caption.copyWith(fontSize: 10)),
            ],
          ),
          if (t.reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(t.reason, style: AppTextStyles.body.copyWith(fontSize: 12)),
          ],
          const SizedBox(height: 4),
          Text('By ${t.createdByName ?? '—'}', style: AppTextStyles.caption.copyWith(fontSize: 10)),
          if (t.isReversal || t.reversedBy != null || showReverse) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (t.isReversal) badge('Reversal of ${_short(t.reverses)}'),
                if (t.reversedBy != null) badge('Reversed'),
                if (showReverse)
                  OutlinedButton(
                    key: Key('leave-credit-reverse-${t.id}'),
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: onReverse,
                    child: const Text('Reverse'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MonthlyTable extends StatelessWidget {
  const _MonthlyTable({required this.monthly, required this.year});
  final LeaveCreditMonthly monthly;
  final int year;

  @override
  Widget build(BuildContext context) {
    final m = monthly;
    TableRow row(String a, String b, String c, {bool bold = false}) {
      final s = AppTextStyles.caption
          .copyWith(fontSize: 11, color: AppColors.textPrimary, fontWeight: bold ? FontWeight.w700 : FontWeight.w400);
      Widget cell(String t, {bool right = false}) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(t, style: s, textAlign: right ? TextAlign.right : TextAlign.left),
          );
      return TableRow(children: [cell(a), cell(b, right: true), cell(c, right: true)]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Table(
          key: const Key('leave-credit-monthly-table'),
          columnWidths: const {0: FlexColumnWidth(1.6), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1.2)},
          children: [
            row('Month', 'Credit adjustments', 'Leave used (working days)', bold: true),
            for (final mo in m.months)
              row(mo.label, mo.creditAdjustments != 0 ? signedDays(mo.creditAdjustments) : '—',
                  mo.used != 0 ? creditNum(mo.used) : '—'),
            if (m.adjustmentsOutsideYear != 0)
              row('Adjustments recorded in another year', signedDays(m.adjustmentsOutsideYear), ''),
            if (m.usedInNextYearMonths != 0)
              row('Leave days falling in ${year + 1} (counted against $year)', '', creditNum(m.usedInNextYearMonths)),
            if (m.usedNotItemised != 0)
              row('Used before history / not linked to a leave request', '', creditNum(m.usedNotItemised)),
            row('Total', signedDays(m.totalCreditAdjustments), creditNum(m.totalUsed), bold: true),
          ],
        ),
        if (m.approximatedRequests > 0) ...[
          const SizedBox(height: 6),
          Text(
            '${m.approximatedRequests} leave request(s) no longer fall on any working day under current calendars '
            'and are shown in their start month.',
            style: AppTextStyles.caption.copyWith(fontSize: 10),
          ),
        ],
      ],
    );
  }
}
