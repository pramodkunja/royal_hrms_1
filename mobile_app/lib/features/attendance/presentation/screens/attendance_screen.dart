import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

// ─── Static data ──────────────────────────────────────────────────────────────

class _AttendanceRecord {
  final String name, code, department, branch;
  final String? clockIn, clockOut, totalHrs, ot;
  final String status;
  const _AttendanceRecord({
    required this.name, required this.code, required this.department,
    required this.branch, this.clockIn, this.clockOut, this.totalHrs, this.ot,
    required this.status,
  });
}

const _kAttendance = [
  _AttendanceRecord(name: 'Arjun Sharma',  code: 'E001', department: 'Engineering', branch: 'Bengaluru Tech',  clockIn: '09:05', clockOut: '18:15', totalHrs: '9h 10m', ot: '10m', status: 'Present'),
  _AttendanceRecord(name: 'Priya Nair',    code: 'E002', department: 'Design',       branch: 'Chennai HQ',      clockIn: '09:42', clockOut: '18:30', totalHrs: '8h 48m', ot: null,  status: 'Late'),
  _AttendanceRecord(name: 'Rohit Verma',   code: 'E003', department: 'Sales',        branch: 'Mumbai Office',   clockIn: null,    clockOut: null,    totalHrs: null,      ot: null,  status: 'Absent'),
  _AttendanceRecord(name: 'Sneha Iyer',    code: 'E004', department: 'HR',           branch: 'Chennai HQ',      clockIn: null,    clockOut: null,    totalHrs: null,      ot: null,  status: 'On Leave'),
  _AttendanceRecord(name: 'Karthik Raj',   code: 'E005', department: 'Finance',      branch: 'Chennai HQ',      clockIn: '08:55', clockOut: '13:05', totalHrs: '4h 10m', ot: null,  status: 'Half Day'),
  _AttendanceRecord(name: 'Meera Pillai',  code: 'E006', department: 'Engineering', branch: 'Bengaluru Tech',  clockIn: '09:02', clockOut: '18:45', totalHrs: '9h 43m', ot: '43m', status: 'Present'),
  _AttendanceRecord(name: 'Vikram Singh',  code: 'E007', department: 'Operations',   branch: 'Mumbai Office',   clockIn: '09:18', clockOut: '18:10', totalHrs: '8h 52m', ot: null,  status: 'Late'),
  _AttendanceRecord(name: 'Divya Menon',   code: 'E008', department: 'Marketing',    branch: 'Chennai HQ',      clockIn: '08:58', clockOut: '18:05', totalHrs: '9h 07m', ot: '7m',  status: 'Present'),
  _AttendanceRecord(name: 'Arun Krishnan', code: 'E009', department: 'Engineering', branch: 'Bengaluru Tech',  clockIn: '09:03', clockOut: '18:00', totalHrs: '8h 57m', ot: null,  status: 'Present'),
  _AttendanceRecord(name: 'Lakshmi Rao',   code: 'E010', department: 'Finance',      branch: 'Chennai HQ',      clockIn: '09:00', clockOut: '18:00', totalHrs: '9h 00m', ot: null,  status: 'Present'),
  _AttendanceRecord(name: 'Ravi Kumar',    code: 'E011', department: 'IT',           branch: 'Bengaluru Tech',  clockIn: null,    clockOut: null,    totalHrs: null,      ot: null,  status: 'Weekly Off'),
  _AttendanceRecord(name: 'Anita Desai',   code: 'E012', department: 'HR',           branch: 'Mumbai Office',   clockIn: '09:10', clockOut: '17:55', totalHrs: '8h 45m', ot: null,  status: 'Present'),
];

class _OtRecord {
  final String name, code, date, otHours, type, otAmount, approvedBy, status;
  const _OtRecord({
    required this.name, required this.code, required this.date,
    required this.otHours, required this.type, required this.otAmount,
    required this.approvedBy, required this.status,
  });
}

const _kOtRecords = [
  _OtRecord(name: 'Arjun Sharma', code: 'E001', date: '27 Jun 2025', otHours: '2h 00m', type: 'Regular', otAmount: '₹ 625', approvedBy: 'Sneha Iyer', status: 'Approved'),
  _OtRecord(name: 'Meera Pillai', code: 'E006', date: '28 Jun 2025', otHours: '1h 45m', type: 'Regular', otAmount: '₹ 547', approvedBy: 'Karthik Raj', status: 'Pending'),
  _OtRecord(name: 'Vikram Singh', code: 'E007', date: '26 Jun 2025', otHours: '3h 00m', type: 'Holiday', otAmount: '₹ 1406', approvedBy: 'Sneha Iyer', status: 'Approved'),
  _OtRecord(name: 'Priya Nair',   code: 'E002', date: '25 Jun 2025', otHours: '1h 30m', type: 'Regular', otAmount: '₹ 469', approvedBy: 'Karthik Raj', status: 'Rejected'),
];

class _InvalidPunch {
  final String deviceId, rawTime, cardBioId, issue, suggestedMatch, branch;
  const _InvalidPunch({
    required this.deviceId, required this.rawTime, required this.cardBioId,
    required this.issue, required this.suggestedMatch, required this.branch,
  });
}

const _kInvalidPunches = [
  _InvalidPunch(deviceId: 'DEV-CH-03', rawTime: '2025-06-29 09:04:12', cardBioId: 'BIO-00412', issue: 'No employee match', suggestedMatch: 'Rohit Verma (E003)?', branch: 'Mumbai Office'),
  _InvalidPunch(deviceId: 'DEV-BL-01', rawTime: '2025-06-29 18:55:33', cardBioId: 'BIO-00887', issue: 'Duplicate punch',    suggestedMatch: 'Meera Pillai (E006)',  branch: 'Bengaluru Tech'),
  _InvalidPunch(deviceId: 'DEV-CH-02', rawTime: '2025-06-28 14:22:09', cardBioId: 'BIO-00214', issue: 'Future timestamp',   suggestedMatch: 'Divya Menon (E008)',   branch: 'Chennai HQ'),
];

class _UnpunchRecord {
  final String name, code, date, clockIn, expectedOut, branch;
  const _UnpunchRecord({
    required this.name, required this.code, required this.date,
    required this.clockIn, required this.expectedOut, required this.branch,
  });
}

const _kUnpunches = [
  _UnpunchRecord(name: 'Vikram Singh',  code: 'E007', date: '28 Jun 2025', clockIn: '09:18', expectedOut: '18:00', branch: 'Mumbai Office'),
  _UnpunchRecord(name: 'Karthik Raj',   code: 'E005', date: '27 Jun 2025', clockIn: '08:55', expectedOut: '18:00', branch: 'Chennai HQ'),
  _UnpunchRecord(name: 'Lakshmi Rao',   code: 'E010', date: '27 Jun 2025', clockIn: '09:00', expectedOut: '18:00', branch: 'Chennai HQ'),
  _UnpunchRecord(name: 'Arun Krishnan', code: 'E009', date: '26 Jun 2025', clockIn: '09:03', expectedOut: '18:00', branch: 'Bengaluru Tech'),
  _UnpunchRecord(name: 'Ravi Kumar',    code: 'E011', date: '26 Jun 2025', clockIn: '08:50', expectedOut: '18:00', branch: 'Bengaluru Tech'),
  _UnpunchRecord(name: 'Anita Desai',   code: 'E012', date: '25 Jun 2025', clockIn: '09:10', expectedOut: '18:00', branch: 'Mumbai Office'),
  _UnpunchRecord(name: 'Priya Nair',    code: 'E002', date: '25 Jun 2025', clockIn: '09:42', expectedOut: '18:00', branch: 'Chennai HQ'),
];

// ─── Colour helpers ───────────────────────────────────────────────────────────

Color _statusColor(String s) => switch (s) {
  'Present'    => const Color(0xFF1B8A6B),
  'Late'       => const Color(0xFFB45309),
  'Absent'     => const Color(0xFFC0392B),
  'On Leave'   => const Color(0xFF1E4E8C),
  'Half Day'   => const Color(0xFF6B21A8),
  'Weekly Off' => const Color(0xFF6B7280),
  'Approved'   => const Color(0xFF1B8A6B),
  'Pending'    => const Color(0xFFB45309),
  'Rejected'   => const Color(0xFFC0392B),
  _            => const Color(0xFF6B7280),
};

Color _statusBg(String s) => switch (s) {
  'Present'    => const Color(0xFFD8F3DC),
  'Late'       => const Color(0xFFFEF3C7),
  'Absent'     => const Color(0xFFFFDAD6),
  'On Leave'   => const Color(0xFFDDEAFB),
  'Half Day'   => const Color(0xFFF3E8FF),
  'Weekly Off' => const Color(0xFFF3F4F6),
  'Approved'   => const Color(0xFFD8F3DC),
  'Pending'    => const Color(0xFFFEF3C7),
  'Rejected'   => const Color(0xFFFFDAD6),
  _            => const Color(0xFFF3F4F6),
};

Color _issueColor(String s) => switch (s) {
  'No employee match' => const Color(0xFFC0392B),
  'Duplicate punch'   => const Color(0xFFB45309),
  'Future timestamp'  => const Color(0xFF6B21A8),
  _                   => const Color(0xFF6B7280),
};

Color _issueBg(String s) => switch (s) {
  'No employee match' => const Color(0xFFFFDAD6),
  'Duplicate punch'   => const Color(0xFFFEF3C7),
  'Future timestamp'  => const Color(0xFFF3E8FF),
  _                   => const Color(0xFFF3F4F6),
};

String _initials(String name) {
  final p = name.trim().split(' ');
  if (p.length >= 2) return '${p.first[0]}${p.last[0]}'.toUpperCase();
  return p.first.isNotEmpty ? p.first[0].toUpperCase() : '?';
}

// ─── Main Screen ──────────────────────────────────────────────────────────────

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with SingleTickerProviderStateMixin {
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
    return NestedScrollView(
      headerSliverBuilder: (_, __) => [
        SliverToBoxAdapter(child: _StatsBar()),
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
                _BadgeTab(label: 'Invalid Punches', count: _kInvalidPunches.length),
                _BadgeTab(label: 'Un-punches', count: _kUnpunches.length),
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

class _StatsBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final stats = [
      _Stat('Present Today', '8', 'of 12 employees', Icons.people_alt_outlined, const Color(0xFF1B8A6B), const Color(0xFFD8F3DC), const Color(0xFF1B8A6B), 0.67),
      _Stat('Absent', '2', 'No check-in recorded', Icons.person_off_outlined, const Color(0xFFC0392B), const Color(0xFFFFDAD6), const Color(0xFFC0392B), 0.17),
      _Stat('Late Arrivals', '2', 'Arrived after 09:15', Icons.schedule_outlined, const Color(0xFFB45309), const Color(0xFFFEF3C7), const Color(0xFFB45309), 0.17),
      _Stat('On Leave', '2', 'Approved leave', Icons.event_available_outlined, const Color(0xFF1E4E8C), const Color(0xFFDDEAFB), const Color(0xFF1B8A6B), 0.17),
    ];

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
              Text('Mon, 30 Jun 2025', style: AppTextStyles.labelSmall.copyWith(color: const Color(0xFF6B7280))),
            ],
          ),
          const SizedBox(height: 2),
          Text('Monitor daily attendance, overtime, and correction requests',
            style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF6B7280))),
          const SizedBox(height: 14),
          Row(
            children: stats.map((s) => Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _StatCard(stat: s),
            ))).toList(),
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

class _AttendanceTab extends StatefulWidget {
  const _AttendanceTab();

  @override
  State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab> {
  String _branch = 'All Branches';
  String _dept   = 'All Departments';

  static const _branches = ['All Branches', 'Bengaluru Tech', 'Chennai HQ', 'Mumbai Office'];
  static const _depts    = ['All Departments', 'Engineering', 'Design', 'Sales', 'HR', 'Finance', 'Marketing', 'Operations', 'IT'];

  List<_AttendanceRecord> get _filtered => _kAttendance.where((r) {
    final bOk = _branch == 'All Branches'    || r.branch == _branch;
    final dOk = _dept   == 'All Departments' || r.department == _dept;
    return bOk && dOk;
  }).toList();

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    final counts = {
      'Present': rows.where((r) => r.status == 'Present').length,
      'Late':    rows.where((r) => r.status == 'Late').length,
      'Absent':  rows.where((r) => r.status == 'Absent').length,
      'On Leave':rows.where((r) => r.status == 'On Leave').length,
      'Half Day':rows.where((r) => r.status == 'Half Day').length,
      'Weekly Off': rows.where((r) => r.status == 'Weekly Off').length,
    };

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Filters
        Row(children: [
          Expanded(child: _Dropdown(value: _branch, items: _branches, onChanged: (v) => setState(() => _branch = v!))),
          const SizedBox(width: 8),
          Expanded(child: _Dropdown(value: _dept,   items: _depts,   onChanged: (v) => setState(() => _dept = v!))),
        ]),
        const SizedBox(height: 10),

        // Status chips row
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

        // Cards
        ...rows.map((r) => _AttendanceCard(record: r)),
      ],
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  final _AttendanceRecord record;
  const _AttendanceCard({required this.record});

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(name: record.name),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.name, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
                    Text('${record.code} · ${record.department}',
                      style: AppTextStyles.labelSmall.copyWith(color: const Color(0xFF6B7280))),
                  ],
                ),
              ),
              _StatusBadge(status: record.status),
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _TimeCell(label: 'Clock In',
              value: record.clockIn,
              isLate: record.status == 'Late' && record.clockIn != null)),
            Expanded(child: _TimeCell(label: 'Clock Out', value: record.clockOut)),
            Expanded(child: _TimeCell(label: 'Total Hrs',  value: record.totalHrs)),
            if (record.ot != null)
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
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                  foregroundColor: AppColors.primary,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: Text('View', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _TimeCell extends StatelessWidget {
  final String label;
  final String? value;
  final bool isLate, isOt;
  const _TimeCell({required this.label, this.value, this.isLate = false, this.isOt = false});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTextStyles.labelSmall.copyWith(color: const Color(0xFF9CA3AF), fontSize: 10)),
      const SizedBox(height: 2),
      Text(
        value ?? '—',
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

class _OtEntryTab extends StatefulWidget {
  const _OtEntryTab();

  @override
  State<_OtEntryTab> createState() => _OtEntryTabState();
}

class _OtEntryTabState extends State<_OtEntryTab> {
  String _empSel = 'Arjun Sharma (E001)';
  String _otType = 'Regular (1.5×)';
  String _appBy  = 'Sneha Iyer (HR Manager)';

  static const _employees = ['Arjun Sharma (E001)', 'Priya Nair (E002)', 'Karthik Raj (E005)', 'Meera Pillai (E006)', 'Vikram Singh (E007)'];
  static const _otTypes   = ['Regular (1.5×)', 'Holiday (2×)', 'Emergency (2.5×)'];
  static const _approvers = ['Sneha Iyer (HR Manager)', 'Karthik Raj (Finance Head)', 'Meera Pillai (Eng Lead)'];

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(12),
    children: [
      // Form card
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
            _Dropdown(value: _empSel, items: _employees, onChanged: (v) => setState(() => _empSel = v!)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _FormLabel('Date'),
                _FakeInput(value: '30/06/2025', icon: Icons.calendar_today_outlined),
              ])),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _FormLabel('OT Type'),
                _Dropdown(value: _otType, items: _otTypes, onChanged: (v) => setState(() => _otType = v!)),
              ])),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _FormLabel('OT Start'),
                _FakeInput(value: '06:00 PM', icon: Icons.access_time_outlined),
              ])),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _FormLabel('OT End'),
                _FakeInput(value: '08:00 PM', icon: Icons.access_time_outlined),
              ])),
            ]),
            const SizedBox(height: 12),
            _FormLabel('Approved By'),
            _Dropdown(value: _appBy, items: _approvers, onChanged: (v) => setState(() => _appBy = v!)),
            const SizedBox(height: 12),
            _FormLabel('Reason / Work Done'),
            TextField(
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Describe the overtime work…',
                hintStyle: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF9CA3AF)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.primary)),
                contentPadding: const EdgeInsets.all(10),
              ),
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 16),
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

      // OT Records
      Row(children: [
        const Icon(Icons.table_rows_outlined, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text('OT Records', style: AppTextStyles.h4),
      ]),
      const SizedBox(height: 10),
      ..._kOtRecords.map((r) => _OtCard(record: r)),
    ],
  );
}

class _OtCard extends StatelessWidget {
  final _OtRecord record;
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
          _Avatar(name: record.name),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(record.name, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
            Text(record.code, style: AppTextStyles.labelSmall.copyWith(color: const Color(0xFF6B7280))),
          ])),
          _StatusBadge(status: record.status),
        ]),
        const SizedBox(height: 10),
        const Divider(height: 1, color: Color(0xFFF3F4F6)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _KV(k: 'Date',    v: record.date)),
          Expanded(child: _KV(k: 'OT Hrs',  v: record.otHours, vColor: AppColors.primary)),
          Expanded(child: _KV(k: 'Type',    v: record.type)),
          Expanded(child: _KV(k: 'Amount',  v: record.otAmount, vColor: const Color(0xFF1B8A6B))),
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            const Icon(Icons.person_outline, size: 12, color: Color(0xFF6B7280)),
            const SizedBox(width: 4),
            Text(record.approvedBy, style: AppTextStyles.labelSmall.copyWith(color: const Color(0xFF6B7280))),
          ]),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
              foregroundColor: AppColors.primary,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: Text('View', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ]),
      ]),
    ),
  );
}

// ─── Tab 3: Invalid Punches ───────────────────────────────────────────────────

class _InvalidPunchesTab extends StatelessWidget {
  const _InvalidPunchesTab();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(12),
    children: [
      _InfoBanner(
        icon: Icons.info_outline,
        color: const Color(0xFF1E4E8C),
        bg: const Color(0xFFEFF6FF),
        border: const Color(0xFFBFDBFE),
        message: 'These punches could not be matched to an employee or contain data errors. Review and fix each record before it affects payroll.',
      ),
      const SizedBox(height: 12),
      ..._kInvalidPunches.map((p) => _InvalidPunchCard(punch: p)),
    ],
  );
}

class _InvalidPunchCard extends StatelessWidget {
  final _InvalidPunch punch;
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
            decoration: BoxDecoration(color: _issueBg(punch.issue), borderRadius: BorderRadius.circular(20)),
            child: Text(punch.issue, style: AppTextStyles.labelSmall.copyWith(color: _issueColor(punch.issue), fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 10),
        const Divider(height: 1, color: Color(0xFFF3F4F6)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _KV(k: 'Raw Time', v: punch.rawTime, small: true)),
          Expanded(child: _KV(k: 'Card/Bio', v: punch.cardBioId)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _KV(k: 'Suggested Match', v: punch.suggestedMatch)),
          Expanded(child: _KV(k: 'Branch', v: punch.branch)),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.build_outlined, size: 14),
            label: const Text('Fix'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ]),
    ),
  );
}

// ─── Tab 4: Un-punches ────────────────────────────────────────────────────────

class _UnpunchesTab extends StatelessWidget {
  const _UnpunchesTab();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(12),
    children: [
      _InfoBanner(
        icon: Icons.warning_amber_outlined,
        color: const Color(0xFFB45309),
        bg: const Color(0xFFFFFBEB),
        border: const Color(0xFFFDE68A),
        message: 'These employees have a Clock In but no matching Clock Out for that day. The system cannot compute their total hours until the missing punch is resolved.',
      ),
      const SizedBox(height: 12),
      ..._kUnpunches.map((r) => _UnpunchCard(record: r)),
    ],
  );
}

class _UnpunchCard extends StatelessWidget {
  final _UnpunchRecord record;
  const _UnpunchCard({required this.record});

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
          _Avatar(name: record.name),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(record.name, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
            Text(record.code, style: AppTextStyles.labelSmall.copyWith(color: const Color(0xFF6B7280))),
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
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.fingerprint_outlined, size: 14),
            label: const Text('Add Punch'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ]),
    ),
  );
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) => Container(
    width: 38, height: 38,
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(9),
    ),
    alignment: Alignment.center,
    child: Text(_initials(name), style: AppTextStyles.label.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
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
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
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
    items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
    onChanged: onChanged,
  );
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
