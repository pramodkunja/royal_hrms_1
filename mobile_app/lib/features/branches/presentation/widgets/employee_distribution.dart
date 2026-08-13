import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/branch_entity.dart';
import '../providers/branch_providers.dart';

/// Employee Distribution chart — backed by the same
/// GET /branch/branches/distribution/ endpoint the web dashboard uses
/// (employee count per active branch), not derived from the branch list.
class EmployeeDistributionSection extends ConsumerWidget {
  const EmployeeDistributionSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final distAsync = ref.watch(branchDistributionProvider);

    return distAsync.when(
      loading: () => const _DistributionCardShell(child: _DistributionShimmer()),
      error: (e, _) => const SizedBox.shrink(),
      data: (distribution) {
        if (distribution.isEmpty) return const SizedBox.shrink();
        return _DistributionCardShell(
          subtitle: _subtitle(distribution),
          child: _DistributionChart(distribution: distribution),
        );
      },
    );
  }

  String _subtitle(List<BranchDistributionEntity> distribution) {
    final total = distribution.fold<int>(0, (sum, d) => sum + d.employees);
    final branchWord = distribution.length == 1 ? 'branch' : 'branches';
    return '$total employees across ${distribution.length} active $branchWord';
  }
}

// ── Card shell (header + body) ───────────────────────────────────────────────

class _DistributionCardShell extends StatelessWidget {
  final String? subtitle;
  final Widget child;
  const _DistributionCardShell({this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: AppColors.primary,
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.bar_chart_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Employee Distribution',
                          style: AppTextStyles.label.copyWith(
                              color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chart ─────────────────────────────────────────────────────────────────────

class _DistributionChart extends StatelessWidget {
  final List<BranchDistributionEntity> distribution;
  const _DistributionChart({required this.distribution});

  static const _chartHeight = 180.0;
  static const _barWidth = 40.0;
  static const _barSpacing = 20.0;

  int get _axisMax {
    final maxValue = distribution.map((d) => d.employees).fold<int>(0, math.max);
    return _niceAxisMax(maxValue);
  }

  @override
  Widget build(BuildContext context) {
    final axisMax = _axisMax;
    final barColors = [
      AppColors.primary,
      AppColors.info,
      AppColors.secondary,
      AppColors.warning,
    ];

    return SizedBox(
      height: _chartHeight + 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _chartHeight,
            width: 26,
            child: _AxisLabels(axisMax: axisMax),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Stack(
              children: [
                const Positioned.fill(
                  child: SizedBox(height: _chartHeight, child: _GridLines()),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (int i = 0; i < distribution.length; i++)
                        Padding(
                          padding: EdgeInsets.only(
                              right: i == distribution.length - 1 ? 0 : _barSpacing),
                          child: _Bar(
                            data: distribution[i],
                            axisMax: axisMax,
                            height: _chartHeight,
                            width: _barWidth,
                            color: barColors[i % barColors.length],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounds a raw maximum up to a "nice" round number (1/2/5 × 10^n) so axis
/// labels read as 0, 5, 10, 15, 20 instead of 0, 4.75, 9.5, ... .
int _niceAxisMax(int maxValue, {int divisions = 4}) {
  if (maxValue <= 0) return divisions;
  final rawStep = maxValue / divisions;
  final magnitude = math.pow(10, (math.log(rawStep) / math.ln10).floor()).toDouble();
  final residual = rawStep / magnitude;
  final niceResidual = residual <= 1 ? 1 : (residual <= 2 ? 2 : (residual <= 5 ? 5 : 10));
  final step = (niceResidual * magnitude).ceil();
  return step * divisions;
}

class _AxisLabels extends StatelessWidget {
  final int axisMax;
  const _AxisLabels({required this.axisMax});

  @override
  Widget build(BuildContext context) {
    const divisions = 4;
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(divisions + 1, (i) {
        final value = (axisMax * (divisions - i) / divisions).round();
        return Text(
          '$value',
          style: AppTextStyles.caption.copyWith(fontSize: 10),
        );
      }),
    );
  }
}

class _GridLines extends StatelessWidget {
  const _GridLines();

  @override
  Widget build(BuildContext context) {
    const divisions = 4;
    return Column(
      children: List.generate(divisions + 1, (i) {
        final isBaseline = i == divisions;
        return Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 1,
              color: isBaseline ? AppColors.border : AppColors.border.withValues(alpha: 0.5),
            ),
          ),
        );
      }),
    );
  }
}

class _Bar extends StatelessWidget {
  final BranchDistributionEntity data;
  final int axisMax;
  final double height;
  final double width;
  final Color color;

  const _Bar({
    required this.data,
    required this.axisMax,
    required this.height,
    required this.width,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = axisMax > 0 ? (data.employees / axisMax).clamp(0.0, 1.0) : 0.0;
    return Tooltip(
      message: '${data.branch}: ${data.employees} Employees',
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '${data.employees}',
              style: AppTextStyles.labelSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: fraction),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => FractionallySizedBox(
                    heightFactor: value,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [color, color.withValues(alpha: 0.7)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              data.branchCode,
              style: AppTextStyles.caption.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _DistributionShimmer extends StatelessWidget {
  const _DistributionShimmer();

  static const _heights = [0.5, 0.8, 0.35, 0.65, 0.45];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _heights
            .map((h) => Container(
                  width: 34,
                  height: 180 * h,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  ),
                ))
            .toList(),
      ),
    );
  }
}
