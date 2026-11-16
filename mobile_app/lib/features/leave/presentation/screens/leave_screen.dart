import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/blue_hero_banner.dart';
import '../widgets/leave_dashboard_tab.dart';
import '../widgets/apply_leave_tab.dart';
import '../widgets/team_calendar_tab.dart';
import '../widgets/leave_analytics_tab.dart';

class LeaveScreen extends ConsumerStatefulWidget {
  const LeaveScreen({super.key});

  @override
  ConsumerState<LeaveScreen> createState() => _LeaveScreenState();
}

/// Web leave/_client.tsx (LeavePageClient): Dashboard, Apply Leave, Team
/// Calendar, Analytics — the same four tabs for everyone. Approving other
/// people's leave lives only in the Approvals screen, and the page has no
/// branch filter (the backend scopes every list). The old mobile-only
/// Approvals tab and system_admin branch filter, both decided by role
/// name, are gone (Task 71 finding M3).
class _LeaveScreenState extends ConsumerState<LeaveScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 4, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabController = _tabController;

    const tabs = [
      Tab(text: 'Dashboard'),
      Tab(text: 'Apply Leave'),
      Tab(text: 'Team Calendar'),
      Tab(text: 'Analytics'),
    ];
    final tabViews = [
      const LeaveDashboardTab(),
      ApplyLeaveTab(
        onDashboard: () => tabController.animateTo(0),
      ),
      const TeamCalendarTab(),
      const LeaveAnalyticsTab(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header (blue hero) ─────────────────────────────────────────────
            BlueHeroBanner(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Title + subtitle
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Leave Management',
                            style:
                                AppTextStyles.h4.copyWith(color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(
                          'Apply for leave and track your own requests',
                          style: AppTextStyles.caption.copyWith(
                              color: Colors.white.withValues(alpha: 0.85)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ── Tab bar (pinned, plain background) ──────────────────────────────
            Container(
              color: AppColors.surface,
              child: TabBar(
                controller: tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: tabs,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 2.5,
                labelStyle: AppTextStyles.label.copyWith(fontSize: 12),
                unselectedLabelStyle:
                    AppTextStyles.label.copyWith(fontSize: 12),
                dividerColor: AppColors.border,
                padding: EdgeInsets.zero,
              ),
            ),

            // ── Tab content ───────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: tabController,
                children: tabViews,
              ),
            ),
          ],
        ),
      ),
      // Hidden while already on the Apply Leave tab (index 1) — redundant there.
      //
      // Scoped to its own ListenableBuilder (rather than a TabController
      // listener calling setState on the whole screen, as this used to do)
      // so switching tabs no longer reconstructs `tabs`/`tabViews` and
      // reruns every tab body's build()/ref.watch calls just to show or
      // hide this button — only this small builder re-evaluates on tab
      // change now. Trade-off: Scaffold's built-in FAB show/hide scale
      // transition no longer applies here (the property it receives is
      // always a non-null widget), so the button appears/disappears
      // instantly instead of animating — everything else about it is
      // unchanged.
      floatingActionButton: ListenableBuilder(
        listenable: tabController,
        builder: (context, _) => tabController.index == 1
            ? const SizedBox.shrink()
            : FloatingActionButton.extended(
                heroTag: 'leave-apply-fab',
                onPressed: () => tabController.animateTo(1),
                backgroundColor: AppColors.primary,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Apply My Leave',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
      ),
    );
  }
}
