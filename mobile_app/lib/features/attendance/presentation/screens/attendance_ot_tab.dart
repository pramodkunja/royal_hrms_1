part of 'attendance_screen.dart';

// ─── Tab 2: OT Entry ──────────────────────────────────────────────────────────

class _OtEntryTab extends ConsumerStatefulWidget {
  const _OtEntryTab();

  @override
  ConsumerState<_OtEntryTab> createState() => _OtEntryTabState();
}

class _OtEntryTabState extends ConsumerState<_OtEntryTab> {
  String? _employeeId;
  String _otType = 'regular';
  DateTime _date = DateTime.now();
  TimeOfDay? _otStart;
  TimeOfDay? _otEnd;
  // "Approved By": the chosen HR approver's employee_id (web OtEntryTab
  // approved_by), from GET /employees/hrs/?branch=<the employee's branch>.
  String? _approverId;
  String _employeeBranch = '';
  final _reasonCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  static const _otTypeLabels = {
    'regular': 'Regular (1.5×)',
    'holiday': 'Holiday (2×)',
    'weekly_off': 'Weekly Off (1.5×)',
  };

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? _otStart : _otEnd) ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => isStart ? _otStart = picked : _otEnd = picked);
  }

  /// Web OtEntryTab: "Add OT Entry" only for usePermission("attendance.create")
  /// (superuser flag or the permission — userHasPermission). The form and the
  /// OT records stay visible. The server also needs attendance staff
  /// (hr_attendance.py HROvertimeCreateView → can_manage_attendance).
  Future<void> _submit() async {
    if (!ref.read(permissionProvider('attendance.create'))) return;
    if (_employeeId == null) {
      setState(() => _error = 'Please select an employee.');
      return;
    }
    if (_otStart == null || _otEnd == null) {
      setState(() => _error = 'Please select OT start and end times.');
      return;
    }
    final startMinutes = _otStart!.hour * 60 + _otStart!.minute;
    final endMinutes = _otEnd!.hour * 60 + _otEnd!.minute;
    if (endMinutes <= startMinutes) {
      setState(() => _error = 'OT end time must be after the start time.');
      return;
    }

    // Only an approver currently listed for this employee's branch is sent.
    final approver = otApproverForSubmit(
      _approverId,
      _employeeBranch.isEmpty ? null : ref.read(employeeHrOptionsProvider(_employeeBranch)).valueOrNull,
    );
    if (approver.error != null) {
      setState(() {
        _approverId = null;
        _error = approver.error;
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final error = await ref.read(overtimeListProvider.notifier).create(
          employeeId: _employeeId!,
          date: _fmtDate(_date),
          otType: _otType,
          otStart: _fmtTime(_otStart!),
          otEnd: _fmtTime(_otEnd!),
          approvedBy: approver.approvedBy,
          reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _otStart = null;
      _otEnd = null;
      _approverId = null;
      _reasonCtrl.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text('OT entry added.'), backgroundColor: AppColors.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesProvider);
    final overtimeAsync = ref.watch(overtimeListProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(overtimeListProvider.notifier).refresh(),
      // Centred with a max width on large tablets; 12 dp gutter otherwise.
      child: LayoutBuilder(builder: (context, c) {
        final gutter = c.maxWidth > 1024 ? (c.maxWidth - 1000) / 2 : 12.0;
        return ListView(
        primary: false,
        padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 12),
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.cardShadow,
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.timer_outlined, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Add OT Entry', style: AppTextStyles.h4)),
                ]),
                const SizedBox(height: 16),
                const _FormLabel('Employee'),
                employeesAsync.when(
                  data: (employees) => DropdownButtonFormField<String>(
                    initialValue: _employeeId,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Select employee',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    isExpanded: true,
                    items: employees
                        .map((e) => DropdownMenuItem(
                              value: e.employeeId,
                              child: Text('${e.fullName} (${e.employeeId})', overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _employeeId = v;
                      _employeeBranch = employees.where((e) => e.employeeId == v).firstOrNull?.branch ?? '';
                      // Approvers are per branch: a new employee starts with none.
                      _approverId = null;
                    }),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) =>
                      Text(friendlyAttendanceError(e), style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const _FormLabel('Date'),
                    GestureDetector(
                      onTap: _pickDate,
                      child: _FakeInput(value: _fmtDate(_date), icon: Icons.calendar_today_outlined),
                    ),
                  ])),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const _FormLabel('OT Type'),
                    DropdownButtonFormField<String>(
                      initialValue: _otType,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      isExpanded: true,
                      items: _otTypeLabels.entries
                          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) => setState(() => _otType = v!),
                    ),
                  ])),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const _FormLabel('OT Start'),
                    GestureDetector(
                      onTap: () => _pickTime(true),
                      child: _FakeInput(
                        value: _otStart?.format(context) ?? 'Select time',
                        icon: Icons.access_time_outlined,
                      ),
                    ),
                  ])),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const _FormLabel('OT End'),
                    GestureDetector(
                      onTap: () => _pickTime(false),
                      child: _FakeInput(
                        value: _otEnd?.format(context) ?? 'Select time',
                        icon: Icons.access_time_outlined,
                      ),
                    ),
                  ])),
                ]),
                const SizedBox(height: 12),
                const _FormLabel('Approved By'),
                OtApproverField(
                  employeeSelected: _employeeId != null,
                  branch: _employeeBranch,
                  value: _approverId,
                  onChanged: (v) => setState(() {
                    _approverId = v;
                    _error = null;
                  }),
                ),
                const SizedBox(height: 12),
                const _FormLabel('Reason / Work Done'),
                TextField(
                  controller: _reasonCtrl,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: 'Describe the overtime work…',
                    hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(10),
                  ),
                  style: AppTextStyles.bodySmall,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 6),
                  Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
                ],
                const SizedBox(height: 14),
                if (ref.watch(permissionProvider('attendance.create')))
                  SizedBox(
                    key: const Key('ot-add-entry'),
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.add, size: 16),
                      label: const Text('Add OT Entry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Icon(Icons.table_rows_outlined, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Expanded(child: Text('OT Records', style: AppTextStyles.h4)),
          ]),
          const SizedBox(height: 10),
          overtimeAsync.when(
            data: (page) => page.results.isEmpty
                ? const ApprovalsEmptyState(
                    key: Key('ot-empty'),
                    kind: ApprovalsStateKind.empty,
                    title: 'No OT entries recorded yet.',
                    message: 'Overtime entries you add will appear here.',
                    icon: Icons.timer_outlined,
                    compact: true,
                  )
                : Column(children: [
                    ResponsiveCardColumns(children: [for (final r in page.results) OtRecordCard(record: r)]),
                    if (page.totalPages > 1) ...[
                      const SizedBox(height: 12),
                      _PaginationBar(
                        page: page.page,
                        totalPages: page.totalPages,
                        onPrev:
                            page.page > 1 ? () => ref.read(overtimePageProvider.notifier).state = page.page - 1 : null,
                        onNext: page.page < page.totalPages
                            ? () => ref.read(overtimePageProvider.notifier).state = page.page + 1
                            : null,
                      ),
                    ],
                  ]),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            // Error / offline / access-denied each read differently; Retry
            // (except for access denied) reloads the list.
            error: (e, _) => ApprovalsEmptyState.forError(
              e,
              key: const Key('ot-error'),
              compact: true,
              what: 'OT records',
              onRetry: () => ref.read(overtimeListProvider.notifier).refresh(),
            ),
          ),
        ],
      );
      }),
    );
  }
}
