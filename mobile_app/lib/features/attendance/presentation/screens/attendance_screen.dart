import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../employees/presentation/providers/employee_providers.dart';
import '../../domain/entities/attendance_entity.dart';
import '../providers/attendance_providers.dart';

// ─── Colour helpers ───────────────────────────────────────────────────────────

Color _statusColor(String s) => switch (s) {
  'Present'    => const Color(0xFF1B8A6B),
  'Late'       => const Color(0xFFB45309),
  'Absent'     => const Color(0xFFC0392B),
  'On Leave'   => const Color(0xFF1E4E8C),
  'Half Day'   => const Color(0xFF6B21A8),
  'Weekly Off' => const Color(0xFF6B7280),
  'Holiday'    => const Color(0xFFB5651D),
  'Incomplete' => const Color(0xFF9333EA),
  'approved' || 'Approved'   => const Color(0xFF1B8A6B),
  'pending' || 'Pending'    => const Color(0xFFB45309),
  'rejected' || 'Rejected'   => const Color(0xFFC0392B),
  _            => const Color(0xFF6B7280),
};

Color _statusBg(String s) => switch (s) {
  'Present'    => const Color(0xFFD8F3DC),
  'Late'       => const Color(0xFFFEF3C7),
  'Absent'     => const Color(0xFFFFDAD6),
  'On Leave'   => const Color(0xFFDDEAFB),
  'Half Day'   => const Color(0xFFF3E8FF),
  'Weekly Off' => const Color(0xFFF3F4F6),
  'Holiday'    => const Color(0xFFFDEBD3),
  'Incomplete' => const Color(0xFFF3E8FF),
  'approved' || 'Approved'   => const Color(0xFFD8F3DC),
  'pending' || 'Pending'    => const Color(0xFFFEF3C7),
  'rejected' || 'Rejected'   => const Color(0xFFFFDAD6),
  _            => const Color(0xFFF3F4F6),
};

Color _issueColor(String issueType) => switch (issueType) {
  'no-match'  => const Color(0xFFC0392B),
  'duplicate' => const Color(0xFFB45309),
  'future'    => const Color(0xFF6B21A8),
  _           => const Color(0xFF6B7280),
};

Color _issueBg(String issueType) => switch (issueType) {
  'no-match'  => const Color(0xFFFFDAD6),
  'duplicate' => const Color(0xFFFEF3C7),
  'future'    => const Color(0xFFF3E8FF),
  _           => const Color(0xFFF3F4F6),
};

String _initials(String name) {
  final p = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
  if (p.length >= 2) return '${p.first[0]}${p.last[0]}'.toUpperCase();
  return p.isNotEmpty && p.first.isNotEmpty ? p.first[0].toUpperCase() : '?';
}

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _todayDisplay() {
  final now = DateTime.now();
  return '${_weekdayNames[now.weekday - 1]}, ${now.day} ${_monthNames[now.month - 1]} ${now.year}';
}

// ─── Main Screen ──────────────────────────────────────────────────────────────

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(attendanceDashboardProvider);
    final invalidCount = dashboardAsync.valueOrNull?.invalidPunchesCount ?? 0;
    final unpunchCount = dashboardAsync.valueOrNull?.unPunchesCount ?? 0;

    return NestedScrollView(
      headerSliverBuilder: (_, __) => [
        const SliverToBoxAdapter(child: _StatsBar()),
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabBarDelegate(
            TabBar(
              controller: _tab,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primary,
              unselectedLabelColor: const Color(0xFF6B7280),
              labelStyle: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
              unselectedLabelStyle: AppTextStyles.label,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2.5,
              dividerColor: const Color(0xFFE5E7EB),
              tabs: [
                const Tab(text: 'Attendance'),
                const Tab(text: 'OT Entry'),
                _BadgeTab(label: 'Invalid Punches', count: invalidCount),
                _BadgeTab(label: 'Un-punches', count: unpunchCount),
              ],
            ),
          ),
        ),
      ],
      body: TabBarView(
        controller: _tab,
        children: const [
          _AttendanceTab(),
          _OtEntryTab(),
          _InvalidPunchesTab(),
          _UnpunchesTab(),
        ],
      ),
    );
  }
}

// ─── Tab bar delegate ─────────────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(_, __, ___) => Container(
    color: Colors.white,
    child: tabBar,
  );

  @override
  bool shouldRebuild(_) => false;
}

class _BadgeTab extends StatelessWidget {
  final String label;
  final int count;
  const _BadgeTab({required this.label, required this.count});

  @override
  Widget build(BuildContext context) => Tab(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(10)),
          child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

// ─── Stats bar ────────────────────────────────────────────────────────────────

class _StatsBar extends ConsumerWidget {
  const _StatsBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(attendanceDashboardProvider);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Attendance & Time', style: AppTextStyles.h3),
              Text(_todayDisplay(), style: AppTextStyles.labelSmall.copyWith(color: const Color(0xFF6B7280))),
            ],
          ),
          const SizedBox(height: 2),
          Text('Monitor daily attendance, overtime, and correction requests',
            style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF6B7280))),
          const SizedBox(height: 14),
          dashboardAsync.when(
            data: (d) {
              final total = d.totalEmployees > 0 ? d.totalEmployees : 1;
              final stats = [
                _Stat('Present Today', '${d.presentToday}', 'of ${d.totalEmployees} employees',
                    Icons.people_alt_outlined, const Color(0xFF1B8A6B), const Color(0xFFD8F3DC),
                    const Color(0xFF1B8A6B), (d.presentToday / total).clamp(0.0, 1.0)),
                _Stat('Absent', '${d.absent}', 'No check-in recorded',
                    Icons.person_off_outlined, const Color(0xFFC0392B), const Color(0xFFFFDAD6),
                    const Color(0xFFC0392B), (d.absent / total).clamp(0.0, 1.0)),
                _Stat('Late Arrivals', '${d.lateArrivals}', 'Arrived late',
                    Icons.schedule_outlined, const Color(0xFFB45309), const Color(0xFFFEF3C7),
                    const Color(0xFFB45309), (d.lateArrivals / total).clamp(0.0, 1.0)),
                _Stat('On Leave', '${d.onLeave}', 'Approved leave',
                    Icons.event_available_outlined, const Color(0xFF1E4E8C), const Color(0xFFDDEAFB),
                    const Color(0xFF1B8A6B), (d.onLeave / total).clamp(0.0, 1.0)),
              ];
              return Row(
                children: stats.map((s) => Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _StatCard(stat: s),
                ))).toList(),
              );
            },
            loading: () => const SizedBox(
              height: 90,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => SizedBox(
              height: 60,
              child: Center(
                child: Text(friendlyAttendanceError(e),
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat {
  final String label, value, sub;
  final IconData icon;
  final Color iconColor, iconBg, barColor;
  final double barFraction;
  const _Stat(this.label, this.value, this.sub, this.icon, this.iconColor, this.iconBg, this.barColor, this.barFraction);
}

class _StatCard extends StatelessWidget {
  final _Stat stat;
  const _StatCard({required this.stat});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text(stat.label, style: AppTextStyles.labelSmall.copyWith(color: const Color(0xFF6B7280)), maxLines: 1, overflow: TextOverflow.ellipsis)),
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(color: stat.iconBg, borderRadius: BorderRadius.circular(6)),
              child: Icon(stat.icon, size: 14, color: stat.iconColor),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(stat.value, style: AppTextStyles.h3.copyWith(color: const Color(0xFF1A2433), height: 1)),
        const SizedBox(height: 2),
        Text(stat.sub, style: AppTextStyles.labelSmall.copyWith(color: const Color(0xFF6B7280), fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: stat.barFraction,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: AlwaysStoppedAnimation(stat.barColor),
            minHeight: 3,
          ),
        ),
      ],
    ),
  );
}

// ─── Tab 1: Attendance ────────────────────────────────────────────────────────

class _AttendanceTab extends ConsumerWidget {
  const _AttendanceTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(attendanceRecordsProvider);
    final branchList = ref.watch(employeeBranchNameListProvider);
    final deptList = ref.watch(employeeDepartmentListProvider);
    final selectedBranch = ref.watch(hrAttendanceBranchFilterProvider);
    final selectedDept = ref.watch(hrAttendanceDepartmentFilterProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(attendanceDashboardProvider);
        await ref.read(attendanceRecordsProvider.notifier).refresh();
      },
      child: recordsAsync.when(
        data: (rows) {
          final counts = <String, int>{};
          for (final r in rows) {
            counts[r.status] = (counts[r.status] ?? 0) + 1;
          }

          return ListView(
            // Each TabBarView child would otherwise inherit the same
            // PrimaryScrollController from the enclosing NestedScrollView —
            // fine on mobile (no Scrollbar rendered), but on web/desktop the
            // Scrollbar requires exactly one attached ScrollPosition and
            // throws when multiple tabs' ListViews share the controller.
            primary: false,
            padding: const EdgeInsets.all(12),
            children: [
              Row(children: [
                Expanded(
                  child: _Dropdown(
                    value: selectedBranch.isEmpty ? 'All Branches' : selectedBranch,
                    items: ['All Branches', ...branchList],
                    onChanged: (v) => ref.read(hrAttendanceBranchFilterProvider.notifier).state =
                        (v == 'All Branches') ? '' : v!,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Dropdown(
                    value: selectedDept.isEmpty ? 'All Departments' : selectedDept,
                    items: ['All Departments', ...deptList],
                    onChanged: (v) => ref.read(hrAttendanceDepartmentFilterProvider.notifier).state =
                        (v == 'All Departments') ? '' : v!,
                  ),
                ),
              ]),
              const SizedBox(height: 10),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ...counts.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _Chip(label: '${e.value} ${e.key}', color: _statusColor(e.key), bg: _statusBg(e.key)),
                    )),
                    Text('Total: ${rows.length} employees',
                      style: AppTextStyles.labelSmall.copyWith(color: const Color(0xFF6B7280))),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              if (rows.isEmpty)
                const _EmptyState(message: 'No attendance records for today.'),
              ...rows.map((r) => _AttendanceCard(record: r)),
            ],
          );
        },
        loading: () => const Center(child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        )),
        error: (e, _) => _ErrorState(
          message: friendlyAttendanceError(e),
          onRetry: () => ref.read(attendanceRecordsProvider.notifier).refresh(),
        ),
      ),
    );
  }
}

class _AttendanceCard extends ConsumerWidget {
  final AttendanceRowEntity record;
  const _AttendanceCard({required this.record});

  // recordId is only present when an AttendanceRecord exists for this employee/date.
  // The backend route is `records/<uuid:pk>/` — a strict UUID path converter — so
  // there is no way to look up a detail for rows with no record (e.g. Absent).
  void _showDetail(BuildContext context, WidgetRef ref) {
    final recordId = record.recordId;
    if (recordId == null) return;
    final key = (id: recordId, isEmployeeId: false);
    showDialog(
      context: context,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final detailAsync = ref.watch(attendanceRecordDetailProvider(key));
          return AlertDialog(
            title: Text(record.name),
            content: detailAsync.when(
              data: (d) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _KVRow('Status', d.status),
                  _KVRow('Clock In', d.clockIn),
                  _KVRow('Clock Out', d.clockOut),
                  _KVRow('Total Hours', d.totalHours),
                  _KVRow('Overtime', d.overtime),
                  if (d.note != null && d.note!.isNotEmpty) _KVRow('Note', d.note!),
                  if (d.punches.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Punches', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    ...d.punches.map((p) => Text(
                        '${p.punchType} · ${p.time} · ${p.mode}',
                        style: const TextStyle(fontSize: 12))),
                  ],
                ],
              ),
              loading: () => const SizedBox(
                height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (e, _) => Text(friendlyAttendanceError(e),
                  style: const TextStyle(color: AppColors.error, fontSize: 12)),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(name: record.name, initials: record.initials),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.name, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
                    Text('${record.employeeId} · ${record.department}',
                      style: AppTextStyles.labelSmall.copyWith(color: const Color(0xFF6B7280))),
                  ],
                ),
              ),
              _StatusBadge(status: record.status),
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _TimeCell(label: 'Clock In', value: record.clockIn, isLate: record.isLate)),
            Expanded(child: _TimeCell(label: 'Clock Out', value: record.clockOut)),
            Expanded(child: _TimeCell(label: 'Total Hrs', value: record.totalHours)),
            if (record.ot != '—')
              Expanded(child: _TimeCell(label: 'OT', value: record.ot, isOt: true)),
          ]),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.business_outlined, size: 12, color: Color(0xFF6B7280)),
                const SizedBox(width: 4),
                Text(record.branch, style: AppTextStyles.labelSmall.copyWith(color: const Color(0xFF6B7280))),
              ]),
              if (record.recordId != null)
                OutlinedButton(
                  onPressed: () => _showDetail(context, ref),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                    foregroundColor: AppColors.primary,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: Text('View', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                )
              else
                Text('No record', style: AppTextStyles.labelSmall.copyWith(color: const Color(0xFF9CA3AF))),
            ],
          ),
        ],
      ),
    ),
  );
}

class _KVRow extends StatelessWidget {
  final String k, v;
  const _KVRow(this.k, this.v);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Text('$k: $v', style: const TextStyle(fontSize: 12)),
  );
}

class _TimeCell extends StatelessWidget {
  final String label;
  final String value;
  final bool isLate, isOt;
  const _TimeCell({required this.label, required this.value, this.isLate = false, this.isOt = false});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTextStyles.labelSmall.copyWith(color: const Color(0xFF9CA3AF), fontSize: 10)),
      const SizedBox(height: 2),
      Text(
        value,
        style: AppTextStyles.label.copyWith(
          color: isLate ? const Color(0xFFC0392B) : isOt ? const Color(0xFF1B8A6B) : const Color(0xFF1A2433),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    ],
  );
}

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
  final _approvedByCtrl = TextEditingController();
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
    _approvedByCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context, initialDate: _date,
      firstDate: DateTime(2020), lastDate: DateTime.now(),
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

  Future<void> _submit() async {
    if (_employeeId == null) {
      setState(() => _error = 'Please select an employee.');
      return;
    }
    if (_otStart == null || _otEnd == null) {
      setState(() => _error = 'Please select OT start and end times.');
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
          approvedBy: _approvedByCtrl.text.trim().isEmpty ? null : _approvedByCtrl.text.trim(),
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
      _approvedByCtrl.clear();
      _reasonCtrl.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OT entry added.'), backgroundColor: AppColors.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesProvider);
    final overtimeAsync = ref.watch(overtimeListProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(overtimeListProvider.notifier).refresh(),
      child: ListView(
        primary: false,
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.timer_outlined, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('Add OT Entry', style: AppTextStyles.h4),
                ]),
                const SizedBox(height: 16),
                _FormLabel('Employee'),
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
                    onChanged: (v) => setState(() => _employeeId = v),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text(friendlyAttendanceError(e),
                      style: const TextStyle(color: AppColors.error, fontSize: 12)),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _FormLabel('Date'),
                    GestureDetector(
                      onTap: _pickDate,
                      child: _FakeInput(value: _fmtDate(_date), icon: Icons.calendar_today_outlined),
                    ),
                  ])),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _FormLabel('OT Type'),
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
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _FormLabel('OT Start'),
                    GestureDetector(
                      onTap: () => _pickTime(true),
                      child: _FakeInput(
                        value: _otStart?.format(context) ?? 'Select time',
                        icon: Icons.access_time_outlined,
                      ),
                    ),
                  ])),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _FormLabel('OT End'),
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
                _FormLabel('Approved By (optional — employee ID or name)'),
                TextField(
                  controller: _approvedByCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. E001 or Jane Doe',
                    hintStyle: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF9CA3AF)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(10),
                  ),
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 12),
                _FormLabel('Reason / Work Done'),
                TextField(
                  controller: _reasonCtrl,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: 'Describe the overtime work…',
                    hintStyle: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF9CA3AF)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(10),
                  ),
                  style: AppTextStyles.bodySmall,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 6),
                  Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(width: 14, height: 14,
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
            const Icon(Icons.table_rows_outlined, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text('OT Records', style: AppTextStyles.h4),
          ]),
          const SizedBox(height: 10),
          overtimeAsync.when(
            data: (rows) => rows.isEmpty
                ? const _EmptyState(message: 'No OT entries recorded yet.')
                : Column(children: rows.map((r) => _OtCard(record: r)).toList()),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Text(friendlyAttendanceError(e),
                style: const TextStyle(color: AppColors.error, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _OtCard extends StatelessWidget {
  final OvertimeRowEntity record;
  const _OtCard({required this.record});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _Avatar(name: record.name, initials: record.initials),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(record.name, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
            Text(record.employeeId, style: AppTextStyles.labelSmall.copyWith(color: const Color(0xFF6B7280))),
          ])),
          _StatusBadge(status: record.status),
        ]),
        const SizedBox(height: 10),
        const Divider(height: 1, color: Color(0xFFF3F4F6)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _KV(k: 'Date',    v: record.date)),
          Expanded(child: _KV(k: 'OT Hrs',  v: record.otHours, vColor: AppColors.primary)),
          Expanded(child: _KV(k: 'Type',    v: record.otType)),
          Expanded(child: _KV(k: 'Amount',  v: '₹ ${record.otAmount}', vColor: const Color(0xFF1B8A6B))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.person_outline, size: 12, color: Color(0xFF6B7280)),
          const SizedBox(width: 4),
          Text('Approved by: ${record.approvedBy}', style: AppTextStyles.labelSmall.copyWith(color: const Color(0xFF6B7280))),
        ]),
      ]),
    ),
  );
}

// ─── Tab 3: Invalid Punches (read-only — no persisted model or fix action on backend) ──

class _InvalidPunchesTab extends ConsumerWidget {
  const _InvalidPunchesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invalidAsync = ref.watch(invalidPunchesProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(invalidPunchesProvider),
      child: ListView(
        primary: false,
        padding: const EdgeInsets.all(12),
        children: [
          const _InfoBanner(
            icon: Icons.info_outline,
            color: Color(0xFF1E4E8C),
            bg: Color(0xFFEFF6FF),
            border: Color(0xFFBFDBFE),
            message: 'These punches could not be matched to an employee or contain data errors. This view is read-only — there is no automated fix for flagged punches yet.',
          ),
          const SizedBox(height: 12),
          invalidAsync.when(
            data: (rows) => rows.isEmpty
                ? const _EmptyState(message: 'No invalid punches for today.')
                : Column(children: rows.map((p) => _InvalidPunchCard(punch: p)).toList()),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => _ErrorState(
              message: friendlyAttendanceError(e),
              onRetry: () => ref.invalidate(invalidPunchesProvider),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvalidPunchCard extends StatelessWidget {
  final InvalidPunchEntity punch;
  const _InvalidPunchCard({required this.punch});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(6)),
            child: Row(children: [
              const Icon(Icons.devices_outlined, size: 13, color: Color(0xFF6B7280)),
              const SizedBox(width: 4),
              Text(punch.deviceId, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF1A2433))),
            ]),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _issueBg(punch.issueType), borderRadius: BorderRadius.circular(20)),
            child: Text(punch.issue, style: AppTextStyles.labelSmall.copyWith(color: _issueColor(punch.issueType), fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 10),
        const Divider(height: 1, color: Color(0xFFF3F4F6)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _KV(k: 'Raw Time', v: punch.rawTime, small: true)),
          Expanded(child: _KV(k: 'Card/Bio', v: punch.biometricId)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _KV(k: 'Suggested Fix', v: punch.suggestedMatch)),
          Expanded(child: _KV(k: 'Branch', v: punch.branch)),
        ]),
      ]),
    ),
  );
}

// ─── Tab 4: Un-punches ────────────────────────────────────────────────────────

class _UnpunchesTab extends ConsumerWidget {
  const _UnpunchesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unpunchesAsync = ref.watch(unpunchesProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(unpunchesProvider.notifier).refresh(),
      child: ListView(
        primary: false,
        padding: const EdgeInsets.all(12),
        children: [
          const _InfoBanner(
            icon: Icons.warning_amber_outlined,
            color: Color(0xFFB45309),
            bg: Color(0xFFFFFBEB),
            border: Color(0xFFFDE68A),
            message: 'These employees have a Clock In but no matching Clock Out for that day. Approve their pending correction request to resolve it, or wait for them to submit one.',
          ),
          const SizedBox(height: 12),
          unpunchesAsync.when(
            data: (rows) => rows.isEmpty
                ? const _EmptyState(message: 'No un-punches for today.')
                : Column(children: rows.map((r) => _UnpunchCard(record: r)).toList()),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => _ErrorState(
              message: friendlyAttendanceError(e),
              onRetry: () => ref.read(unpunchesProvider.notifier).refresh(),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnpunchCard extends ConsumerStatefulWidget {
  final UnpunchRowEntity record;
  const _UnpunchCard({required this.record});

  @override
  ConsumerState<_UnpunchCard> createState() => _UnpunchCardState();
}

class _UnpunchCardState extends ConsumerState<_UnpunchCard> {
  bool _reviewing = false;

  Future<void> _review(bool approve) async {
    final correctionId = widget.record.correctionId;
    if (correctionId == null) return;
    setState(() => _reviewing = true);
    final error = await ref
        .read(unpunchesProvider.notifier)
        .reviewCorrection(correctionId, approve: approve);
    if (!mounted) return;
    setState(() => _reviewing = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? 'Correction approved.' : 'Correction rejected.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _Avatar(name: record.name, initials: record.initials),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(record.name, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
              Text(record.employeeId, style: AppTextStyles.labelSmall.copyWith(color: const Color(0xFF6B7280))),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFFFDAD6), borderRadius: BorderRadius.circular(20)),
              child: Text('OUT missing', style: AppTextStyles.labelSmall.copyWith(color: const Color(0xFFC0392B), fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _KV(k: 'Date',         v: record.date)),
            Expanded(child: _KV(k: 'Clock In',      v: record.clockIn, vColor: AppColors.primary)),
            Expanded(child: _KV(k: 'Expected Out',  v: record.expectedOut)),
            Expanded(child: _KV(k: 'Branch',        v: record.branch, small: true)),
          ]),
          const SizedBox(height: 10),
          if (record.correctionPending && record.correctionId != null)
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reviewing ? null : () => _review(false),
                  icon: const Icon(Icons.close, size: 14),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _reviewing ? null : () => _review(true),
                  icon: _reviewing
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check, size: 14),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),
            ])
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                'Awaiting employee correction request',
                style: AppTextStyles.labelSmall.copyWith(color: const Color(0xFF6B7280)),
              ),
            ),
        ]),
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String name;
  final String? initials;
  const _Avatar({required this.name, this.initials});

  @override
  Widget build(BuildContext context) => Container(
    width: 38, height: 38,
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(9),
    ),
    alignment: Alignment.center,
    child: Text((initials?.isNotEmpty ?? false) ? initials! : _initials(name),
        style: AppTextStyles.label.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
  );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: _statusBg(status), borderRadius: BorderRadius.circular(20)),
    child: Text(status, style: AppTextStyles.labelSmall.copyWith(color: _statusColor(status), fontWeight: FontWeight.w600)),
  );
}

class _KV extends StatelessWidget {
  final String k;
  final String v;
  final Color? vColor;
  final bool small;
  const _KV({required this.k, required this.v, this.vColor, this.small = false});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(k, style: AppTextStyles.labelSmall.copyWith(color: const Color(0xFF9CA3AF), fontSize: 10)),
      const SizedBox(height: 2),
      Text(v,
        style: AppTextStyles.label.copyWith(
          color: vColor ?? const Color(0xFF1A2433),
          fontWeight: FontWeight.w500,
          fontSize: small ? 11 : 12,
        ),
        maxLines: 1, overflow: TextOverflow.ellipsis,
      ),
    ],
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color, bg;
  const _Chip({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: AppTextStyles.labelSmall.copyWith(color: color, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _Dropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _Dropdown({required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final safeItems = items.toSet().toList();
    if (!safeItems.contains(value)) safeItems.insert(0, value);
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.primary)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        isDense: true,
      ),
      style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF1A2433)),
      isExpanded: true,
      items: safeItems.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
    );
  }
}

class _FakeInput extends StatelessWidget {
  final String value;
  final IconData icon;
  const _FakeInput({required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFD1D5DB)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(children: [
      Expanded(child: Text(value, style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF1A2433)))),
      Icon(icon, size: 15, color: const Color(0xFF6B7280)),
    ]),
  );
}

class _FormLabel extends StatelessWidget {
  final String text;
  const _FormLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Text(text, style: AppTextStyles.labelSmall.copyWith(color: const Color(0xFF374151), fontWeight: FontWeight.w600)),
  );
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color, bg, border;
  final String message;
  const _InfoBanner({required this.icon, required this.color, required this.bg, required this.border, required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: border)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 15, color: color)),
      const SizedBox(width: 8),
      Expanded(child: Text(message, style: AppTextStyles.bodySmall.copyWith(color: color))),
    ]),
  );
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Center(
      child: Text(message, style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF6B7280))),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(40),
    child: Column(
      children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 32),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}
