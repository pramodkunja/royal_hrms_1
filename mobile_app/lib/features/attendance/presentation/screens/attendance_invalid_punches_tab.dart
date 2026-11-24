part of 'attendance_screen.dart';

// ─── Tab 3: Invalid Punches (Assign / Convert / Discard) ───────────────────────

class _InvalidPunchesTab extends ConsumerWidget {
  const _InvalidPunchesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invalidAsync = ref.watch(invalidPunchesProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(invalidPunchesProvider.notifier).refresh(),
      // Centred with a max width on large tablets; 12 dp gutter otherwise.
      child: LayoutBuilder(builder: (context, c) {
        final gutter = c.maxWidth > 1024 ? (c.maxWidth - 1000) / 2 : 12.0;
        return ListView(
          primary: false,
          padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 12),
          children: [
            _InfoBanner(
              icon: Icons.info_outline,
              color: AppColors.info,
              bg: AppColors.infoContainer,
              border: AppColors.info.withValues(alpha: 0.3),
              message: 'These punches could not be matched to an employee or contain data errors. '
                  'Review and fix each record before it affects payroll.',
            ),
            const SizedBox(height: 12),
            invalidAsync.when(
              data: (rows) => rows.isEmpty
                  ? const ApprovalsEmptyState(
                      key: Key('invalid-punches-empty'),
                      kind: ApprovalsStateKind.empty,
                      title: 'No invalid punches for today.',
                      message: 'Punches that need attention will be listed here.',
                      icon: Icons.fingerprint,
                      compact: true,
                    )
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 2, bottom: 8),
                        child: Text(rows.length == 1 ? '1 invalid punch' : '${rows.length} invalid punches',
                            key: const Key('invalid-punches-count'),
                            style: AppTextStyles.labelSmall
                                .copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                      ),
                      ResponsiveCardColumns(children: [for (final p in rows) _InvalidPunchCard(punch: p)]),
                    ]),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ApprovalsEmptyState.forError(
                e,
                key: const Key('invalid-punches-error'),
                compact: true,
                what: 'invalid punches',
                onRetry: () => ref.read(invalidPunchesProvider.notifier).refresh(),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _InvalidPunchCard extends ConsumerStatefulWidget {
  final InvalidPunchEntity punch;
  const _InvalidPunchCard({required this.punch});

  @override
  ConsumerState<_InvalidPunchCard> createState() => _InvalidPunchCardState();
}

class _InvalidPunchCardState extends ConsumerState<_InvalidPunchCard> {
  bool _busy = false;

  /// Web InvalidPunchesTab: Assign, Convert and Discard all need
  /// usePermission("attendance.edit") (superuser flag or the permission —
  /// userHasPermission). The server also checks attendance staff +
  /// attendance.create (apps/attendance/views/hr_audit_actions.py).
  bool get _canEdit => ref.read(permissionProvider('attendance.edit'));

  Future<void> _run(Future<String?> Function() action) async {
    setState(() => _busy = true);
    final error = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Done.'),
        backgroundColor: error != null ? AppColors.error : AppColors.success,
      ),
    );
  }

  Future<void> _assign() async {
    if (!_canEdit) return;
    final assignedTo = await showDialog<String>(
      context: context,
      builder: (_) => const _AssignPunchDialog(),
    );
    if (assignedTo == null || !mounted) return;
    await _run(() => ref.read(invalidPunchesProvider.notifier).assign(widget.punch.id, assignedTo: assignedTo));
  }

  Future<void> _convert() async {
    if (!_canEdit) return;
    final result = await showDialog<({String punchType, String time})>(
      context: context,
      builder: (_) => const _ConvertPunchDialog(),
    );
    if (result == null || !mounted) return;
    await _run(() => ref.read(invalidPunchesProvider.notifier).convert(
          widget.punch.id,
          targetPunchType: result.punchType,
          targetTime: result.time,
        ));
  }

  Future<void> _discard() async {
    if (!_canEdit) return;
    final remarks = await showDialog<String>(
      context: context,
      builder: (_) => const _DiscardPunchDialog(),
    );
    if (remarks == null || !mounted) return;
    await _run(() => ref.read(invalidPunchesProvider.notifier).discard(widget.punch.id, remarks: remarks));
  }

  @override
  Widget build(BuildContext context) => InvalidPunchCard(
        key: ValueKey('invalid-punch-${widget.punch.id}'),
        punch: widget.punch,
        canEdit: ref.watch(permissionProvider('attendance.edit')),
        busy: _busy,
        onAssign: _assign,
        onConvert: _convert,
        onDiscard: _discard,
      );
}

class _AssignPunchDialog extends ConsumerStatefulWidget {
  const _AssignPunchDialog();
  @override
  ConsumerState<_AssignPunchDialog> createState() => _AssignPunchDialogState();
}

class _AssignPunchDialogState extends ConsumerState<_AssignPunchDialog> {
  String? _selectedId;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final hrUsersAsync = ref.watch(hrUsersProvider);
    return AlertDialog(
      scrollable: true,
      title: const Text('Assign Invalid Punch'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _FormLabel('HR User'),
            hrUsersAsync.when(
              data: (users) => DropdownButtonFormField<String>(
                initialValue: _selectedId,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Select HR user',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                isExpanded: true,
                items: users
                    .map((u) => DropdownMenuItem(
                          value: u.id,
                          child: Text('${u.fullName} (${u.employeeId})', overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) =>
                  Text(friendlyAttendanceError(e), style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_selectedId == null) {
              setState(() => _error = 'Please select an HR user.');
              return;
            }
            Navigator.pop(context, _selectedId);
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          child: const Text('Assign'),
        ),
      ],
    );
  }
}

class _ConvertPunchDialog extends StatefulWidget {
  const _ConvertPunchDialog();
  @override
  State<_ConvertPunchDialog> createState() => _ConvertPunchDialogState();
}

class _ConvertPunchDialogState extends State<_ConvertPunchDialog> {
  String _punchType = 'OUT';
  TimeOfDay? _time;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Convert Invalid Punch'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _FormLabel('Punch Type'),
            DropdownButtonFormField<String>(
              initialValue: _punchType,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'IN', child: Text('IN')),
                DropdownMenuItem(value: 'OUT', child: Text('OUT')),
              ],
              onChanged: (v) => setState(() => _punchType = v!),
            ),
            const SizedBox(height: 12),
            const _FormLabel('Target Time'),
            GestureDetector(
              onTap: () async {
                final picked = await showTimePicker(context: context, initialTime: _time ?? TimeOfDay.now());
                if (picked != null) setState(() => _time = picked);
              },
              child: _FakeInput(
                value: _time?.format(context) ?? 'Select time',
                icon: Icons.access_time_outlined,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_time == null) {
              setState(() => _error = 'Please select a target time.');
              return;
            }
            final hh = _time!.hour.toString().padLeft(2, '0');
            final mm = _time!.minute.toString().padLeft(2, '0');
            Navigator.pop(context, (punchType: _punchType, time: '$hh:$mm'));
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          child: const Text('Convert'),
        ),
      ],
    );
  }
}

class _DiscardPunchDialog extends StatefulWidget {
  const _DiscardPunchDialog();
  @override
  State<_DiscardPunchDialog> createState() => _DiscardPunchDialogState();
}

class _DiscardPunchDialogState extends State<_DiscardPunchDialog> {
  final _remarksCtrl = TextEditingController();

  @override
  void dispose() {
    _remarksCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Discard Invalid Punch'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _FormLabel('Remarks (optional)'),
            TextField(
              controller: _remarksCtrl,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Why is this punch being discarded?',
                hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(10),
              ),
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _remarksCtrl.text.trim()),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
          child: const Text('Discard'),
        ),
      ],
    );
  }
}
