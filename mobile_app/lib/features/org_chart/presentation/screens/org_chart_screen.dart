import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../../shared/widgets/blue_hero_banner.dart';
import '../../domain/entities/org_chart_entity.dart';
import '../providers/org_chart_providers.dart';
import '../widgets/org_dept_card.dart';
import '../widgets/org_root_card.dart';

const _kDeptPalette = [
  Color(0xFFE65100),
  Color(0xFF1565C0),
  Color(0xFF2E7D32),
  Color(0xFF6A1B9A),
  Color(0xFF00838F),
  Color(0xFFAD1457),
  Color(0xFF37474F),
  Color(0xFFC62828),
];

class OrgChartScreen extends ConsumerWidget {
  const OrgChartScreen({super.key});

  void _openProfile(BuildContext context, OrgPersonEntity person) {
    if (person.employeeId.isEmpty) return;
    context.push(AppRoutes.employeeProfilePath(person.employeeId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartAsync = ref.watch(orgChartProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(orgChartProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: chartAsync.when(
                loading: () => const _HeaderShimmer(),
                error: (_, __) => const _Header(),
                data: (chart) => _Header(scope: chart.scope),
              ),
            ),
            chartAsync.when(
              loading: () => SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ),
              error: (e, _) => SliverFillRemaining(
                child: AppErrorState(
                  message: userFriendlyMessage(e),
                  title: 'Failed to load org chart',
                  onRetry: () => ref.invalidate(orgChartProvider),
                ),
              ),
              data: (chart) => chart.groups.isEmpty
                  ? const SliverFillRemaining(
                      child: AppEmptyState(
                        icon: Icons.account_tree_outlined,
                        title: 'No organisation data',
                        message: 'There are no active employees to display yet.',
                      ),
                    )
                  : SliverToBoxAdapter(child: _OrgGroups(chart: chart, onTapPerson: (p) => _openProfile(context, p))),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  final OrgChartScope? scope;
  const _Header({this.scope});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedBranch = ref.watch(orgChartSelectedBranchProvider);
    return BlueHeroBanner(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Organisation Chart', style: AppTextStyles.h4.copyWith(color: Colors.white)),
          const SizedBox(height: 2),
          Text(
            selectedBranch ?? 'All branches',
            style: AppTextStyles.caption.copyWith(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
          ),
          if (scope == OrgChartScope.company) ...[
            const SizedBox(height: 12),
            _BranchPicker(selectedBranch: selectedBranch),
          ],
        ],
      ),
    );
  }
}

class _BranchPicker extends ConsumerWidget {
  final String? selectedBranch;
  const _BranchPicker({required this.selectedBranch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final namesAsync = ref.watch(orgChartBranchNamesProvider);
    return namesAsync.when(
      loading: () => const SizedBox(height: 32),
      error: (_, __) => const SizedBox.shrink(),
      data: (names) {
        if (names.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _BranchChip(
                label: 'All Branches',
                selected: selectedBranch == null,
                onTap: () => ref.read(orgChartSelectedBranchProvider.notifier).state = null,
              ),
              const SizedBox(width: 8),
              for (final name in names) ...[
                _BranchChip(
                  label: name,
                  selected: selectedBranch == name,
                  onTap: () => ref.read(orgChartSelectedBranchProvider.notifier).state = name,
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BranchChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _BranchChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.primary : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderShimmer extends StatelessWidget {
  const _HeaderShimmer();

  @override
  Widget build(BuildContext context) {
    return BlueHeroBanner(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 18, width: 180, color: Colors.white.withValues(alpha: 0.25), margin: const EdgeInsets.only(bottom: 6)),
          Container(height: 12, width: 140, color: Colors.white.withValues(alpha: 0.25)),
        ],
      ),
    );
  }
}

// ── Groups (usually one; several when "All Branches" is selected) ────────

class _OrgGroups extends StatelessWidget {
  final OrgChartEntity chart;
  final ValueChanged<OrgPersonEntity> onTapPerson;
  const _OrgGroups({required this.chart, required this.onTapPerson});

  @override
  Widget build(BuildContext context) {
    final showBranchLabels = chart.groups.length > 1;
    var colorIndex = 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        children: [
          for (final group in chart.groups) ...[
            if (showBranchLabels) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  group.branch.isEmpty ? 'Unassigned' : group.branch,
                  style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 10),
            ],
            _OrgTree(
              group: group,
              nextColorIndex: () => _kDeptPalette[colorIndex++ % _kDeptPalette.length],
              onTapPerson: onTapPerson,
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}

class _OrgTree extends StatelessWidget {
  final OrgChartGroupEntity group;
  final Color Function() nextColorIndex;
  final ValueChanged<OrgPersonEntity> onTapPerson;
  const _OrgTree({required this.group, required this.nextColorIndex, required this.onTapPerson});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OrgRootCard(
          person: group.root,
          onTap: group.root == null ? null : () => onTapPerson(group.root!),
        ),
        if (group.departments.isNotEmpty) ...[
          Center(child: Container(width: 1.5, height: 32, color: AppColors.border)),
          ...group.departments.asMap().entries.map((entry) {
            final isLast = entry.key == group.departments.length - 1;
            return _DeptRow(
              dept: entry.value,
              isLast: isLast,
              color: nextColorIndex(),
              onTapPerson: onTapPerson,
            );
          }),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Text(
              'No departments found.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

class _DeptRow extends StatelessWidget {
  final OrgDepartmentEntity dept;
  final bool isLast;
  final Color color;
  final ValueChanged<OrgPersonEntity> onTapPerson;
  const _DeptRow({required this.dept, required this.isLast, required this.color, required this.onTapPerson});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 24, child: CustomPaint(painter: _BranchPainter(isLast: isLast, color: AppColors.border))),
            const SizedBox(width: 6),
            Expanded(child: OrgDeptCard(dept: dept, color: color, onTapPerson: onTapPerson)),
          ],
        ),
      ),
    );
  }
}

class _BranchPainter extends CustomPainter {
  final bool isLast;
  final Color color;
  const _BranchPainter({required this.isLast, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const branchY = 32.0;
    final cx = size.width / 2;
    canvas.drawLine(Offset(cx, 0), Offset(cx, branchY), paint);
    if (!isLast) canvas.drawLine(Offset(cx, branchY), Offset(cx, size.height), paint);
    canvas.drawLine(Offset(cx, branchY), Offset(size.width, branchY), paint);
  }

  @override
  bool shouldRepaint(_BranchPainter old) => old.isLast != isLast || old.color != color;
}
