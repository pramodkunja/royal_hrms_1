import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/org_chart_entity.dart';
import '../providers/org_chart_providers.dart';
import '../widgets/org_dept_card.dart';
import '../widgets/org_md_card.dart';

class OrgChartScreen extends ConsumerWidget {
  const OrgChartScreen({super.key});

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
            // ── Header ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: chartAsync.when(
                loading: () => const _HeaderShimmer(),
                error: (_, __) => const _HeaderShimmer(),
                data: (chart) => _Header(companyName: chart.companyName),
              ),
            ),

            // ── Content ──────────────────────────────────────────────────────
            chartAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (e, _) => SliverFillRemaining(
                child: _ErrorView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(orgChartProvider),
                ),
              ),
              data: (chart) => SliverToBoxAdapter(
                child: _OrgTree(chart: chart),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String companyName;
  const _Header({required this.companyName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Organisation Chart', style: AppTextStyles.h4),
          const SizedBox(height: 2),
          Text(
            companyName,
            style: AppTextStyles.caption.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _HeaderShimmer extends StatelessWidget {
  const _HeaderShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              height: 18, width: 180, color: AppColors.border,
              margin: const EdgeInsets.only(bottom: 6)),
          Container(height: 12, width: 140, color: AppColors.border),
        ],
      ),
    );
  }
}

// ── Full org tree ──────────────────────────────────────────────────────────────

class _OrgTree extends StatelessWidget {
  final OrgChartEntity chart;
  const _OrgTree({required this.chart});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        children: [
          // Managing Director card
          OrgMdCard(member: chart.managingDirector),

          if (chart.departments.isNotEmpty) ...[
            // Connector: MD card → first dept
            Center(
              child: Container(
                width: 1.5,
                height: 32,
                color: AppColors.border,
              ),
            ),

            // Department nodes
            ...chart.departments.asMap().entries.map((entry) {
              final index = entry.key;
              final dept = entry.value;
              final isLast = index == chart.departments.length - 1;
              return _DeptRow(dept: dept, isLast: isLast);
            }),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text(
                'No departments found.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textHint),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Dept row with tree connector ──────────────────────────────────────────────

class _DeptRow extends StatelessWidget {
  final DepartmentNodeEntity dept;
  final bool isLast;
  const _DeptRow({required this.dept, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tree connector
            SizedBox(
              width: 24,
              child: CustomPaint(
                painter: _BranchPainter(
                  isLast: isLast,
                  color: AppColors.border,
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Department card
            Expanded(child: OrgDeptCard(dept: dept)),
          ],
        ),
      ),
    );
  }
}

// ── Tree branch painter ────────────────────────────────────────────────────────

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

    // Vertical line from top down to branch point
    canvas.drawLine(Offset(cx, 0), Offset(cx, branchY), paint);

    // Continue vertical line below branch (if not last)
    if (!isLast) {
      canvas.drawLine(
          Offset(cx, branchY), Offset(cx, size.height), paint);
    }

    // Horizontal branch right to card
    canvas.drawLine(Offset(cx, branchY), Offset(size.width, branchY), paint);
  }

  @override
  bool shouldRepaint(_BranchPainter old) =>
      old.isLast != isLast || old.color != color;
}

// ── Error view ─────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text('Failed to load org chart',
              style: AppTextStyles.label
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Text(message,
              style: AppTextStyles.caption, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
