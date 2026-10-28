import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/blue_hero_banner.dart';
import '../widgets/request_wfh_tab.dart';
import '../widgets/my_wfh_requests_tab.dart';

// Matches web's app/dashboard/work-from-home/_client.tsx exactly — just
// "Request Work From Home" + "My Requests". Approving/rejecting WFH
// requests is NOT part of this screen on web (it happens in the generic
// cross-feature Approvals page, alongside leave/expense/attendance
// correction) — see lib/features/approvals/ for that integration, where
// UnifiedApprovalKind.wfh is one of the merged request kinds.
class WfhScreen extends StatefulWidget {
  const WfhScreen({super.key});

  @override
  State<WfhScreen> createState() => _WfhScreenState();
}

class _WfhScreenState extends State<WfhScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BlueHeroBanner(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Work From Home',
                      style: AppTextStyles.h4.copyWith(color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(
                    'Request a date range to work remotely and track your requests',
                    style: AppTextStyles.caption
                        .copyWith(color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),
            Container(
              color: AppColors.surface,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(text: 'Request Work From Home'),
                  Tab(text: 'My Requests'),
                ],
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 2.5,
                labelStyle: AppTextStyles.label.copyWith(fontSize: 12),
                unselectedLabelStyle: AppTextStyles.label.copyWith(fontSize: 12),
                dividerColor: AppColors.border,
                padding: EdgeInsets.zero,
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  RequestWfhTab(onSubmitted: () => _tabController.animateTo(1)),
                  const MyWfhRequestsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
