import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/datasources/approval_datasource.dart';
import '../../data/models/approval_model.dart';
import '../providers/approval_providers.dart';

// ─── Status helpers ───────────────────────────────────────────────────────────

String _statusLabel(String status) => switch (status) {
  'submitted' => 'Submitted',
  'complete'  => 'Approved',
  'pending'   => 'Needs Revision',
  _           => status,
};

Color _statusColor(String status) => switch (status) {
  'submitted' => const Color(0xFFB45309),
  'complete'  => AppColors.success,
  'pending'   => AppColors.error,
  _           => AppColors.textHint,
};

Color _statusBg(String status) => switch (status) {
  'submitted' => const Color(0xFFFEF3C7),
  'complete'  => AppColors.successContainer,
  'pending'   => AppColors.errorContainer,
  _           => const Color(0xFFF3F4F6),
};

String _fmtDate(String? raw) {
  if (raw == null || raw.isEmpty) return '—';
  try {
    final dt = DateTime.parse(raw);
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  } catch (_) {
    return raw.length > 10 ? raw.substring(0, 10) : raw;
  }
}

// ─── Main screen ──────────────────────────────────────────────────────────────

class CandidateReviewScreen extends ConsumerWidget {
  const CandidateReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(approvalsProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (e, _) => _ErrorView(message: e.toString(), onRetry: () => ref.refresh(approvalsProvider)),
      data:    (rows) => _Body(rows: rows),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text('Failed to load approvals', style: AppTextStyles.h4),
          const SizedBox(height: 6),
          Text(message, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

class _Body extends ConsumerWidget {
  final List<ApprovalUser> rows;
  const _Body({required this.rows});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total     = rows.length;
    final pending   = rows.where((r) => r.onboardingStatus == 'submitted').length;
    final approved  = rows.where((r) => r.onboardingStatus == 'complete').length;
    final revision  = rows.where((r) => r.onboardingStatus == 'pending').length;

    return RefreshIndicator(
      onRefresh: () => ref.read(approvalsProvider.notifier).reload(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Onboarding Approvals', style: AppTextStyles.h2),
                  const SizedBox(height: 2),
                  Text('Review and approve employee onboarding submissions',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  _StatsBar(total: total, pending: pending, approved: approved, revision: revision),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          if (rows.isEmpty)
            SliverFillRemaining(
              child: _EmptyState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _ApprovalTile(
                    user: rows[i],
                    onReview: () => _openReview(context, ref, rows[i]),
                  ),
                  childCount: rows.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openReview(BuildContext context, WidgetRef ref, ApprovalUser user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewSheet(
        user: user,
        ds: ref.read(approvalDataSourceProvider),
        onAction: (decision, {remarks, department, designation}) async {
          final err = await ref.read(approvalsProvider.notifier).act(
            user.id,
            decision: decision,
            remarks: remarks ?? '',
            department: department,
            designation: designation,
          );
          return err;
        },
      ),
    );
  }
}

// ─── Stats bar ────────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  final int total, pending, approved, revision;
  const _StatsBar({required this.total, required this.pending, required this.approved, required this.revision});

  @override
  Widget build(BuildContext context) {
    final stats = [
      _Stat('Total',         total,    Icons.people_outline,       AppColors.primary, const Color(0xFFEEF2FF)),
      _Stat('Pending',       pending,  Icons.remove_red_eye_outlined, const Color(0xFFB45309), const Color(0xFFFEF3C7)),
      _Stat('Approved',      approved, Icons.check_circle_outline,  AppColors.success, AppColors.successContainer),
      _Stat('Needs Revision',revision, Icons.refresh_outlined,      AppColors.error,   AppColors.errorContainer),
    ];
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: stats.map((s) => _StatCard(stat: s)).toList(),
    );
  }
}

class _Stat {
  final String label;
  final int value;
  final IconData icon;
  final Color color, bg;
  const _Stat(this.label, this.value, this.icon, this.color, this.bg);
}

class _StatCard extends StatelessWidget {
  final _Stat stat;
  const _StatCard({required this.stat});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
    ),
    child: Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: stat.bg, borderRadius: BorderRadius.circular(8)),
          child: Icon(stat.icon, color: stat.color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${stat.value}', style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700, height: 1)),
              const SizedBox(height: 2),
              Text(stat.label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─── List tile ────────────────────────────────────────────────────────────────

class _ApprovalTile extends StatelessWidget {
  final ApprovalUser user;
  final VoidCallback onReview;
  const _ApprovalTile({required this.user, required this.onReview});

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
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Text(user.initials, style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              // Name + email
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.fullName.isNotEmpty ? user.fullName : '—',
                      style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(user.email, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusBg(user.onboardingStatus),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_statusLabel(user.onboardingStatus),
                  style: AppTextStyles.labelSmall.copyWith(color: _statusColor(user.onboardingStatus), fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Meta row
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              if (user.designation.isNotEmpty)
                _Meta(icon: Icons.badge_outlined, text: user.designation),
              if (user.branch.isNotEmpty)
                _Meta(icon: Icons.business_outlined, text: user.branch),
              _Meta(icon: Icons.calendar_today_outlined, text: _fmtDate(user.dateJoined)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onReview,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 9),
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Review', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: AppColors.textSecondary),
      const SizedBox(width: 4),
      Text(text, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
    ],
  );
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.how_to_reg_outlined, size: 56, color: AppColors.textHint),
        const SizedBox(height: 12),
        Text('No onboarding submissions', style: AppTextStyles.h4.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text('Onboarding submissions from new employees\nwill appear here.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint), textAlign: TextAlign.center),
      ],
    ),
  );
}

// ─── Review bottom sheet ──────────────────────────────────────────────────────

typedef _ActionCallback = Future<String?> Function(
  String decision, {
  String? remarks,
  String? department,
  String? designation,
});

class _ReviewSheet extends StatefulWidget {
  final ApprovalUser user;
  final ApprovalRemoteDataSource ds;
  final _ActionCallback onAction;

  const _ReviewSheet({required this.user, required this.ds, required this.onAction});

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final _remarksCtrl = TextEditingController();
  bool _acting      = false;
  bool _showAssign  = false;
  String? _actionErr;
  String? _assignErr;

  // dept/desig selection
  List<Map<String, dynamic>> _depts  = [];
  List<Map<String, dynamic>> _desigs = [];
  List<Map<String, dynamic>> _allDesigs = [];
  String _selDept  = '';
  String _selDesig = '';
  bool _loadingDepts = false;

  @override
  void dispose() {
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDeptsAndDesigs() async {
    setState(() => _loadingDepts = true);
    try {
      final results = await Future.wait([
        widget.ds.fetchDepartments(),
        widget.ds.fetchDesignations(),
      ]);
      if (mounted) {
        setState(() {
          _depts     = results[0];
          _allDesigs = results[1];
          _selDept   = widget.user.department;
          _selDesig  = widget.user.designation;
          _desigs    = _filterDesigs(_selDept, results[1]);
        });
      }
    } catch (_) {
      if (mounted) setState(() { _depts = []; _allDesigs = []; });
    } finally {
      if (mounted) setState(() => _loadingDepts = false);
    }
  }

  List<Map<String, dynamic>> _filterDesigs(String deptName, List<Map<String, dynamic>> all) =>
      all.where((d) => (d['department_name'] as String? ?? '') == deptName).toList();

  Future<void> _handleReject() async {
    setState(() { _acting = true; _actionErr = null; });
    final err = await widget.onAction('reject', remarks: _remarksCtrl.text.trim());
    if (!mounted) return;
    if (err != null) {
      setState(() { _acting = false; _actionErr = err; });
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleApproveClick() async {
    setState(() { _showAssign = true; _assignErr = null; });
    if (_depts.isEmpty) await _loadDeptsAndDesigs();
  }

  Future<void> _handleConfirm() async {
    if (_selDept.isEmpty || _selDesig.isEmpty) {
      setState(() => _assignErr = 'Please select both Department and Designation.');
      return;
    }
    setState(() { _acting = true; _actionErr = null; _assignErr = null; });
    final err = await widget.onAction(
      'approve',
      remarks: _remarksCtrl.text.trim(),
      department: _selDept,
      designation: _selDesig,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() { _acting = false; _actionErr = err; });
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFD1D5DB), borderRadius: BorderRadius.circular(2))),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Expanded(child: Text('Review — ${widget.user.fullName}',
                    style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                ],
              ),
            ),
            const Divider(height: 1),
            // Scrollable body
            Expanded(
              child: ListView(
                controller: controller,
                padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPad + 8),
                children: [
                  if (_actionErr != null) ...[
                    _ErrorBanner(message: _actionErr!),
                    const SizedBox(height: 12),
                  ],

                  _Section(title: 'Basic Info', children: [
                    _Row(label: 'Email',       value: widget.user.email),
                    _Row(label: 'Phone',       value: widget.user.phone),
                    _Row(label: 'Department',  value: widget.user.department),
                    _Row(label: 'Designation', value: widget.user.designation),
                    _Row(label: 'Branch',      value: widget.user.branch),
                    _Row(label: 'Role',        value: widget.user.roleDisplay.isNotEmpty ? widget.user.roleDisplay : 'Candidate'),
                  ]),

                  if (widget.user.profile != null) ...[
                    _Section(title: 'Personal', children: [
                      _Row(label: 'DOB',            value: widget.user.profile!.dateOfBirth),
                      _Row(label: 'Gender',         value: widget.user.profile!.gender),
                      _Row(label: 'Marital Status', value: widget.user.profile!.maritalStatus),
                      _Row(label: 'Father Name',    value: widget.user.profile!.fatherName),
                      _Row(label: 'Blood Group',    value: widget.user.profile!.bloodGroup),
                      _Row(label: 'Current Address',value: widget.user.profile!.currentAddress),
                    ]),
                    _Section(title: 'Education & Experience', children: [
                      _Row(label: 'Qualification',    value: widget.user.profile!.highestQualification),
                      _Row(label: 'Institution',      value: widget.user.profile!.institution),
                      _Row(label: 'Year of Passing',  value: widget.user.profile!.yearOfPassing?.toString()),
                      _Row(label: 'Experience (yrs)', value: widget.user.profile!.totalExperienceYears),
                      _Row(label: 'Prev Employer',    value: widget.user.profile!.previousEmployer),
                    ]),
                    _Section(title: 'Bank Details', children: [
                      _Row(label: 'Account Holder', value: widget.user.profile!.accountHolderName),
                      _Row(label: 'Account No.',
                        value: () {
                          final acc = widget.user.profile!.accountNumber;
                          if (acc == null || acc.isEmpty) return null;
                          return '••••${acc.length > 4 ? acc.substring(acc.length - 4) : acc}';
                        }()),
                      _Row(label: 'IFSC',         value: widget.user.profile!.ifscCode),
                      _Row(label: 'Bank',         value: widget.user.profile!.bankName),
                      _Row(label: 'Branch',       value: widget.user.profile!.bankBranchName),
                      _Row(label: 'Account Type', value: widget.user.profile!.accountType),
                    ]),
                    _Section(title: 'Emergency Contact', children: [
                      _Row(label: 'Name',         value: widget.user.profile!.emergencyName),
                      _Row(label: 'Relationship', value: widget.user.profile!.emergencyRelationship),
                      _Row(label: 'Phone',        value: widget.user.profile!.emergencyPhone),
                    ]),
                  ],

                  // Documents
                  _Section(
                    title: 'Documents (${widget.user.documents.length})',
                    children: widget.user.documents.isEmpty
                        ? [const _EmptyDocs()]
                        : widget.user.documents.map((d) => _DocRow(doc: d)).toList(),
                  ),

                  // Remarks
                  const SizedBox(height: 4),
                  Text('Remarks (optional)', style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _remarksCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Notes for the employee or for record…',
                      hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.primary)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    style: AppTextStyles.bodySmall,
                  ),

                  // Assign role section (revealed on Approve tap)
                  if (_showAssign) ...[
                    const SizedBox(height: 16),
                    _AssignSection(
                      loading:   _loadingDepts,
                      depts:     _depts,
                      desigs:    _desigs,
                      selDept:   _selDept,
                      selDesig:  _selDesig,
                      assignErr: _assignErr,
                      onDeptChanged: (name) => setState(() {
                        _selDept  = name;
                        _selDesig = '';
                        _assignErr = null;
                        _desigs = _filterDesigs(name, _allDesigs);
                      }),
                      onDesigChanged: (name) => setState(() { _selDesig = name; _assignErr = null; }),
                    ),
                  ],

                  const SizedBox(height: 24),
                  // Footer buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _acting ? null : _handleReject,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(_acting ? '…' : 'Send Back for Corrections',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _acting ? null : (_showAssign ? _handleConfirm : _handleApproveClick),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _acting
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(_showAssign ? 'Confirm & Activate' : 'Approve & Activate ✓',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Assign dept/desig section ────────────────────────────────────────────────

class _AssignSection extends StatelessWidget {
  final bool loading;
  final List<Map<String, dynamic>> depts, desigs;
  final String selDept, selDesig;
  final String? assignErr;
  final ValueChanged<String> onDeptChanged, onDesigChanged;

  const _AssignSection({
    required this.loading, required this.depts, required this.desigs,
    required this.selDept, required this.selDesig, this.assignErr,
    required this.onDeptChanged, required this.onDesigChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.how_to_reg_outlined, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text('Assign Role', style: AppTextStyles.label.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
        ]),
        if (assignErr != null) ...[
          const SizedBox(height: 8),
          _ErrorBanner(message: assignErr!),
        ],
        const SizedBox(height: 12),
        Text('Department *', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        loading
            ? const SizedBox(height: 44, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
            : _DropdownField(
                value: selDept.isEmpty ? null : selDept,
                hint: '— Select Department —',
                items: depts.map((d) => d['name'] as String).toList(),
                onChanged: (v) => onDeptChanged(v ?? ''),
              ),
        const SizedBox(height: 10),
        Text('Designation *', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        _DropdownField(
          value: selDesig.isEmpty ? null : selDesig,
          hint: selDept.isEmpty ? 'Select department first' : '— Select Designation —',
          items: desigs.map((d) => d['name'] as String).toList(),
          onChanged: selDept.isEmpty ? null : (v) => onDesigChanged(v ?? ''),
        ),
        if (selDept.isNotEmpty && desigs.isEmpty && !loading)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('No designations found for this department.',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
          ),
      ],
    ),
  );
}

class _DropdownField extends StatelessWidget {
  final String? value;
  final String hint;
  final List<String> items;
  final ValueChanged<String?>? onChanged;

  const _DropdownField({required this.value, required this.hint, required this.items, this.onChanged});

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: value,
    hint: Text(hint, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint)),
    decoration: InputDecoration(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.primary)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true,
    ),
    isExpanded: true,
    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
    items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
    onChanged: onChanged,
  );
}

// ─── Shared widgets inside sheet ──────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(title.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: children),
        ),
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  final String label;
  final String? value;
  const _Row({required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(width: 16),
          Flexible(child: Text(value!, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w500), textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  final ApprovalDocument doc;
  const _DocRow({required this.doc});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
    child: Row(
      children: [
        const Icon(Icons.insert_drive_file_outlined, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(doc.documentTypeDisplay, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
              Text(doc.fileName, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        if (doc.fileUrl != null && doc.fileUrl!.isNotEmpty)
          TextButton.icon(
            onPressed: () {}, // URL launcher can be added if needed
            icon: const Icon(Icons.open_in_new, size: 13),
            label: const Text('View'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              textStyle: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w600),
            ),
          )
        else
          Text('No link', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textHint)),
      ],
    ),
  );
}

class _EmptyDocs extends StatelessWidget {
  const _EmptyDocs();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: Text('No documents uploaded.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
  );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.errorContainer,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.only(top: 1), child: Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.error)),
        const SizedBox(width: 6),
        Expanded(child: Text(message, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error))),
      ],
    ),
  );
}
