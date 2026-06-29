import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/announcement_model.dart';
import '../providers/announcement_providers.dart';

// ── Category metadata ─────────────────────────────────────────────────────────

const _kCategoryMeta = <String, ({Color color, IconData icon, String label})>{
  'general':     (color: AppColors.primary,        icon: Icons.campaign_outlined,    label: 'General'),
  'policy':      (color: Color(0xFFB45309),         icon: Icons.gavel_outlined,       label: 'Policy'),
  'event':       (color: Color(0xFF7C3AED),         icon: Icons.event_outlined,       label: 'Event'),
  'celebration': (color: Color(0xFFD4487B),         icon: Icons.celebration_outlined, label: 'Celebration'),
};

({Color color, IconData icon, String label}) _catMeta(String cat) =>
    _kCategoryMeta[cat] ??
    (color: AppColors.textHint, icon: Icons.article_outlined, label: cat);

// ── Card ──────────────────────────────────────────────────────────────────────

class AnnouncementCard extends ConsumerStatefulWidget {
  final AnnouncementModel announcement;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const AnnouncementCard({
    super.key,
    required this.announcement,
    this.onEdit,
    this.onDelete,
  });

  @override
  ConsumerState<AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends ConsumerState<AnnouncementCard> {
  bool _isExpanded = false;

  // Show "Read more" when body likely overflows 3 lines (~160 chars)
  static const int _expandThreshold = 160;

  @override
  Widget build(BuildContext context) {
    final meta = _catMeta(widget.announcement.category);
    final bodyText = widget.announcement.body;
    final isLong = bodyText.length > _expandThreshold;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: meta.color, width: 4)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(announcement: widget.announcement, meta: meta),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bodyText,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                    maxLines: _isExpanded ? null : 3,
                    overflow: _isExpanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                  ),
                  if (isLong) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isExpanded ? 'Read less' : 'Read more',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: meta.color,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 15,
                            color: meta.color,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, color: AppColors.border),
          _CardFooter(
            announcement: widget.announcement,
            onEdit:   widget.announcement.canEdit ? widget.onEdit : null,
            onDelete: widget.announcement.canEdit ? widget.onDelete : null,
            onReact:  () => ref
                .read(announcementsProvider.notifier)
                .toggleReaction(widget.announcement.id),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  final AnnouncementModel announcement;
  final ({Color color, IconData icon, String label}) meta;

  const _CardHeader({required this.announcement, required this.meta});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  announcement.title,
                  style: AppTextStyles.h4.copyWith(height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _CategoryChip(meta: meta),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: meta.color.withValues(alpha: 0.15),
                child: Text(
                  announcement.postedByName.isNotEmpty
                      ? announcement.postedByName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: meta.color,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  announcement.postedByName,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _formatDate(announcement.createdAt),
                style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
              ),
              if (announcement.isPinned) ...[
                const SizedBox(width: 6),
                const Icon(Icons.push_pin, size: 13, color: Color(0xFFC99A2E)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inHours < 1)    return '${diff.inMinutes}m ago';
    if (diff.inDays < 1)     return '${diff.inHours}h ago';
    if (diff.inDays < 30)    return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────

class _CardFooter extends StatelessWidget {
  final AnnouncementModel announcement;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback onReact;

  const _CardFooter({
    required this.announcement,
    this.onEdit,
    this.onDelete,
    required this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          _IconCount(
            icon: announcement.hasReacted ? Icons.favorite : Icons.favorite_border,
            color: announcement.hasReacted ? const Color(0xFFD4487B) : AppColors.textHint,
            count: announcement.reactionsCount,
            onTap: onReact,
          ),
          const SizedBox(width: 4),
          _IconCount(
            icon: Icons.visibility_outlined,
            color: AppColors.textHint,
            count: announcement.viewsCount,
          ),
          const Spacer(),
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: AppColors.textHint,
              visualDensity: VisualDensity.compact,
              onPressed: onEdit,
              tooltip: 'Edit',
            ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              color: AppColors.error,
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
              tooltip: 'Delete',
            ),
        ],
      ),
    );
  }
}

class _IconCount extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int count;
  final VoidCallback? onTap;

  const _IconCount({required this.icon, required this.color, required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category chip ─────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final ({Color color, IconData icon, String label}) meta;

  const _CategoryChip({required this.meta});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: meta.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: meta.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, size: 11, color: meta.color),
          const SizedBox(width: 4),
          Text(
            meta.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: meta.color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
