import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/models/announcement_model.dart';
import 'providers/announcement_providers.dart';
import 'widgets/announcement_card.dart';
import 'widgets/post_announcement_sheet.dart';

class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(announcementsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(context, ref, null),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Post Announcement',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (err, _) => _ErrorView(message: err.toString()),
        data:    (page) => _Body(
          page:     page,
          onEdit:   (a) => _openSheet(context, ref, a),
          onDelete: (a) => _confirmDelete(context, ref, a),
        ),
      ),
    );
  }

  Future<void> _openSheet(
      BuildContext context, WidgetRef ref, AnnouncementModel? editing) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: PostAnnouncementSheet(editing: editing, ref: ref),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, AnnouncementModel ann) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete announcement?'),
        content: Text(
            'Delete "${ann.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final error =
        await ref.read(announcementsProvider.notifier).remove(ann.id);
    if (context.mounted && error != null) {
      _toast(context, error, false);
    }
  }

  void _toast(BuildContext context, String msg, bool ok) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _Body extends ConsumerWidget {
  final AnnouncementPage page;
  final void Function(AnnouncementModel) onEdit;
  final void Function(AnnouncementModel) onDelete;

  const _Body({required this.page, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(announcementCategoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatsRow(stats: page.stats),
        _CategoryFilter(selected: selectedCategory),
        if (page.announcements.isEmpty)
          const Expanded(child: _EmptyView())
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: page.announcements.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final ann = page.announcements[i];
                return AnnouncementCard(
                  announcement: ann,
                  onEdit:   () => onEdit(ann),
                  onDelete: () => onDelete(ann),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ── Stats grid (2×2) ──────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final AnnouncementStats stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.campaign_outlined,
                  count: stats.totalCount,
                  label: 'Total Posts',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.push_pin_outlined,
                  count: stats.pinnedCount,
                  label: 'Pinned',
                  color: const Color(0xFFC99A2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.favorite_border,
                  count: stats.totalReactions,
                  label: 'Reactions',
                  color: const Color(0xFFD4487B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.visibility_outlined,
                  count: stats.totalViews,
                  label: 'Total Views',
                  color: const Color(0xFF0D7490),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final Color color;
  const _StatCard({required this.icon, required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.0,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category filter ────────────────────────────────────────────────────────────

class _CategoryFilter extends ConsumerWidget {
  final String? selected;
  const _CategoryFilter({required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const categories = [
      (value: null,          label: 'All Posts',    icon: Icons.article_outlined),
      (value: 'general',     label: 'General',      icon: Icons.campaign_outlined),
      (value: 'policy',      label: 'Policy',       icon: Icons.gavel_outlined),
      (value: 'event',       label: 'Event',        icon: Icons.event_outlined),
      (value: 'celebration', label: 'Celebration',  icon: Icons.celebration_outlined),
    ];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat      = categories[i];
          final isActive = selected == cat.value;
          return GestureDetector(
            onTap: () => ref
                .read(announcementCategoryProvider.notifier)
                .state = cat.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isActive ? AppColors.primary : AppColors.border),
                boxShadow: isActive ? AppColors.cardShadow : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    cat.icon,
                    size: 13,
                    color: isActive ? Colors.white : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    cat.label,
                    style: AppTextStyles.label.copyWith(
                      color: isActive ? Colors.white : AppColors.textSecondary,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Empty / Error ─────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.campaign_outlined, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text('No announcements yet', style: AppTextStyles.h4),
            const SizedBox(height: 6),
            Text(
              'Be the first to post an announcement.',
              style: AppTextStyles.bodySecondary,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text('Could not load announcements', style: AppTextStyles.h4),
            const SizedBox(height: 6),
            Text(message, style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
