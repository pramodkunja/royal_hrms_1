import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../../shared/widgets/app_loading_widget.dart';
import '../../../../shared/widgets/blue_hero_banner.dart';
import '../../domain/entities/email_log_entity.dart';
import '../providers/email_log_providers.dart';
import '../widgets/email_log_card.dart';
import '../widgets/email_log_detail_sheet.dart';

/// Ports Recruitment's Email Log (backend GET /recruitment/emails/,
/// web's app/dashboard/email-logs/page.tsx) — the only email-logging
/// feature in the system. Read-only: the backend supports search + pagination
/// only (no status/date/type filter, no sort, no retry/resend/delete — see
/// CandidateEmailLogView). Visibility is already gated on the recruitment.view
/// permission by the dashboard nav (nav_config.dart); if this screen is ever
/// reached without that permission the backend's 403 surfaces as a normal
/// AppErrorState, same as every other permission-gated screen in the app.
class EmailLogScreen extends ConsumerStatefulWidget {
  const EmailLogScreen({super.key});

  @override
  ConsumerState<EmailLogScreen> createState() => _EmailLogScreenState();
}

class _EmailLogScreenState extends ConsumerState<EmailLogScreen> {
  final _scrollController = ScrollController();
  late final TextEditingController _searchCtrl;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: ref.read(emailLogSearchProvider));
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 200;
    if (_scrollController.position.pixels >= threshold) {
      final search = ref.read(emailLogSearchProvider);
      ref.read(emailLogsProvider(search).notifier).loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      ref.read(emailLogSearchProvider.notifier).state = value.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(emailLogSearchProvider);
    final logsAsync = ref.watch(emailLogsProvider(search));

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
                  Text('Email Logs', style: AppTextStyles.h4.copyWith(color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(
                    'Recruitment emails sent to candidates',
                    style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search by candidate or email…',
                  hintStyle: AppTextStyles.caption,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
                style: AppTextStyles.bodySmall,
              ),
            ),
            Expanded(
              child: logsAsync.when(
                loading: () => const AppLoadingWidget(),
                error: (e, _) => AppErrorState(
                  message: userFriendlyMessage(e),
                  onRetry: () => ref.read(emailLogsProvider(search).notifier).refresh(),
                ),
                data: (state) => _buildList(context, search, state),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, String search, EmailLogLoadMoreState state) {
    if (state.items.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(emailLogsProvider(search).notifier).refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: AppEmptyState(
              icon: Icons.mail_outline,
              title: search.isEmpty ? 'No email logs found' : 'No emails match your search',
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(emailLogsProvider(search).notifier).refresh(),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: state.items.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          if (i >= state.items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final email = state.items[i];
          return EmailLogCard(
            email: email,
            onTap: () => showEmailLogDetailSheet(context, email),
          );
        },
      ),
    );
  }
}
