import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../../shared/widgets/app_loading_widget.dart';
import '../../../../shared/widgets/blue_hero_banner.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/separation_entity.dart';
import '../providers/separation_providers.dart';
import '../widgets/separation_form_sheet.dart';
import '../widgets/separation_status.dart';

// Status filter chips shown above the list. 'pending' bundles both
// pending/stage2_pending — the two-stage chain's in-progress statuses —
// since the backend's own status_display already surfaces which specific
// stage is pending (see SeparationRequestSerializer.get_status_display).
const _kStatusFilters = [
  ('', 'All'),
  ('pending,stage2_pending', 'Pending'),
  ('approved', 'Approved'),
  ('rejected', 'Rejected'),
  ('cancelled', 'Cancelled'),
];

class SeparationScreen extends ConsumerStatefulWidget {
  const SeparationScreen({super.key});

  @override
  ConsumerState<SeparationScreen> createState() => _SeparationScreenState();
}

class _SeparationScreenState extends ConsumerState<SeparationScreen> {
  String _scope = ''; // '' = my requests, 'team' = approval queue
  String _status = '';
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final filter = (scope: _scope, status: _status);
      ref.read(separationListProvider(filter).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final canApprove = (user?.hasPermission('separation.approve') ?? false) ||
        (user?.hasPermission('settings.edit') ?? false);
    final canPickEmployee = (user?.hasPermission('employees.view') ?? false) ||
        (user?.hasPermission('settings.edit') ?? false);

    final filter = (scope: _scope, status: _status);
    final listAsync = ref.watch(separationListProvider(filter));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BlueHeroBanner(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Separation & Exit',
                      style: AppTextStyles.h4.copyWith(color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(
                    _scope == 'team'
                        ? 'Requests you can act on'
                        : 'Your separation requests',
                    style: AppTextStyles.caption
                        .copyWith(color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),
            if (canApprove)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _ScopeTab(
                        label: 'My Requests',
                        selected: _scope == '',
                        onTap: () => setState(() => _scope = ''),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ScopeTab(
                        label: 'Team Requests',
                        selected: _scope == 'team',
                        onTap: () => setState(() => _scope = 'team'),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              height: 50,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                itemCount: _kStatusFilters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final (value, label) = _kStatusFilters[i];
                  return _StatusFilterChip(
                    label: label,
                    selected: _status == value,
                    onTap: () => setState(() => _status = value),
                  );
                },
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () =>
                    ref.read(separationListProvider(filter).notifier).refresh(),
                child: listAsync.when(
                  data: (state) => state.items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.5,
                              child: AppEmptyState(
                                icon: Icons.logout_outlined,
                                title: _scope == 'team'
                                    ? 'No requests to act on'
                                    : 'No separation requests',
                                message: _scope == 'team'
                                    ? 'Nothing needs your attention right now.'
                                    : 'You have not filed a separation request.',
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                          itemCount: state.items.length + (state.hasMore ? 1 : 0),
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            if (i >= state.items.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                    child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))),
                              );
                            }
                            return _RequestCard(
                              request: state.items[i],
                              showEmployee: _scope == 'team',
                            );
                          },
                        ),
                  loading: () => const AppLoadingWidget(),
                  error: (e, _) => AppErrorState(
                    message: friendlySeparationError(e),
                    onRetry: () =>
                        ref.read(separationListProvider(filter).notifier).refresh(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'separation-request-fab',
        onPressed: () => showSeparationFormSheet(context,
            canPickEmployee: canPickEmployee),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Request Separation',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _ScopeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ScopeTab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.label.copyWith(
            fontSize: 12,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _StatusFilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final SeparationRequestEntity request;
  final bool showEmployee;
  const _RequestCard({required this.request, required this.showEmployee});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push(
        AppRoutes.separationDetailPath(request.id),
        extra: request,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(request.requestRef,
                              style: AppTextStyles.label.copyWith(fontSize: 13)),
                          if (request.canApprove) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('Action needed',
                                  style: AppTextStyles.caption.copyWith(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.error)),
                            ),
                          ],
                        ],
                      ),
                      if (showEmployee)
                        Text(
                          [request.employeeName, request.employeeCode]
                              .where((s) => s.isNotEmpty)
                              .join(' · '),
                          style: AppTextStyles.caption.copyWith(fontSize: 11),
                        ),
                    ],
                  ),
                ),
                SeparationStatusChip(
                    status: request.status, label: request.statusDisplay),
              ],
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _InfoBit(
                      label: 'Type', value: request.separationTypeDisplay),
                ),
                Expanded(
                  child: _InfoBit(
                    label: 'Last Working Day',
                    value: formatSeparationDate(request.proposedLastWorkingDay),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBit extends StatelessWidget {
  final String label;
  final String value;
  const _InfoBit({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: AppTextStyles.caption.copyWith(fontSize: 10, color: AppColors.textHint)),
        Text(value, style: AppTextStyles.body.copyWith(fontSize: 12)),
      ],
    );
  }
}
