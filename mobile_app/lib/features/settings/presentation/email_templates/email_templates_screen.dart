import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/router/app_router.dart' show AppRoutes;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/blue_hero_banner.dart';
import '../../../approvals/presentation/widgets/approvals_kit.dart';
import '../../../approvals/presentation/widgets/approvals_ui.dart' show ApprovalsIconBox;
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../dashboard/presentation/widgets/pushed_app_top_bar.dart';
import '../../data/models/email_template_model.dart';
import '../providers/settings_providers.dart';
import 'birthday_settings_providers.dart' show canViewBirthdaySettings;
import 'widgets/birthday_settings_card.dart';
import 'widgets/email_branding_card.dart';
import 'widgets/template_card.dart';
import 'widgets/template_editor_sheet.dart';
import 'widgets/template_preview_sheet.dart';

// ── Type metadata ─────────────────────────────────────────────────────────────

const _kTypeLabel = {
  'document': 'Document Templates',
  'notification': 'Notification Templates',
  'reminder': 'Reminder Templates',
  'wish': 'Wish Templates',
};

const _kTypeOrder = ['document', 'notification', 'reminder', 'wish'];

String _label(String type) => _kTypeLabel[type] ?? 'Other Templates';

// ── Screen ────────────────────────────────────────────────────────────────────

/// Settings → Email Templates (web `settings/email-templates`): the email
/// header/footer branding, the automatic birthday wishes settings, and every
/// template grouped by type, with search, Preview, Edit, Active switch and
/// (custom templates) Delete. Outside the dashboard shell, so it carries the
/// shell's own blue `AppTopBar` through `PushedAppTopBar`.
class EmailTemplatesScreen extends ConsumerStatefulWidget {
  const EmailTemplatesScreen({super.key});

  @override
  ConsumerState<EmailTemplatesScreen> createState() => _EmailTemplatesScreenState();
}

class _EmailTemplatesScreenState extends ConsumerState<EmailTemplatesScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _type = ''; // '' = every type (a view filter over the loaded list)

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() => _search = '');
  }

  Future<void> _refresh() async {
    ref.invalidate(emailTemplatesProvider);
    await ref.read(emailTemplatesProvider.future).then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(emailTemplatesProvider);
    final templates = async.valueOrNull;
    final narrowed = _search.isNotEmpty || _type.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      // The same blue bar Announcements (and every shell screen) has.
      appBar: const PushedAppTopBar(title: 'Email Templates', fallbackRoute: AppRoutes.settings),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('template-add'),
        onPressed: () => _openEditor(context, null),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Template', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Hero(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
          ),
          if (templates != null && templates.isNotEmpty)
            _TypePills(templates: templates, selected: _type, onSelect: (v) => setState(() => _type = v)),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _refresh,
              child: LayoutBuilder(builder: (context, box) {
                final cols = box.maxWidth >= 900 ? 3 : (box.maxWidth >= 600 ? 2 : 1);
                const gap = 12.0;
                final side = box.maxWidth > 1120 ? (box.maxWidth - 1120) / 2 + 16 : 16.0;
                final cardWidth = ((box.maxWidth > 1120 ? 1120.0 : box.maxWidth) - 32 - gap * (cols - 1)) / cols;
                return ListView(
                  key: const Key('template-list'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(side, 12, side, 96),
                  children: [
                    // While searching / filtering, the templates come first: the summary and the
                    // email settings step aside so a match is never pushed below the fold.
                    if (!narrowed) ...[
                      if (templates != null && templates.isNotEmpty) ...[
                        _Summary(templates: templates),
                        const SizedBox(height: 16),
                      ],
                      _SettingsSection(
                          canViewBirthday: canViewBirthdaySettings(ref.watch(authStateProvider).valueOrNull?.user)),
                      const SizedBox(height: 18),
                    ],
                    ...async.when(
                      loading: () => [const ApprovalsLoading(label: 'Loading templates…')],
                      error: (e, _) => [
                        KeyedSubtree(
                          key: const Key('template-load-error'),
                          child: ApprovalsEmptyState.forError(e, onRetry: _refresh, compact: true, what: 'templates'),
                        ),
                      ],
                      data: (all) => _templatesContent(context, all, cols, gap, cardWidth),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _templatesContent(
      BuildContext context, List<EmailTemplateModel> all, int cols, double gap, double cardWidth) {
    if (all.isEmpty) {
      return [
        KeyedSubtree(
          key: const Key('template-empty'),
          child: Column(children: [
            const ApprovalsEmptyState(
              kind: ApprovalsStateKind.empty,
              title: 'No email templates yet',
              message: 'Create templates to personalise the transactional emails the system sends.',
              icon: Icons.mail_outline,
              compact: true,
            ),
            FilledButton.icon(
              key: const Key('template-empty-add'),
              onPressed: () => _openEditor(context, null),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Template'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size(0, 44)),
            ),
          ]),
        ),
      ];
    }

    bool matches(EmailTemplateModel t) {
      if (_type.isNotEmpty && (t.templateType ?? 'other') != _type) return false;
      if (_search.isEmpty) return true;
      return t.displayName.toLowerCase().contains(_search) ||
          t.subject.toLowerCase().contains(_search) ||
          (t.category ?? '').toLowerCase().contains(_search) ||
          (t.description ?? '').toLowerCase().contains(_search);
    }

    final filtered = all.where(matches).toList();
    final groups = <String, List<EmailTemplateModel>>{};
    for (final t in filtered) {
      groups.putIfAbsent(t.templateType ?? 'other', () => []).add(t);
    }
    final keys = [..._kTypeOrder.where(groups.containsKey), ...groups.keys.where((k) => !_kTypeOrder.contains(k))];

    final narrowed = _search.isNotEmpty || _type.isNotEmpty;
    return [
      _PagingStatus(loaded: all.length),
      if (narrowed && filtered.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text('${filtered.length} of ${all.length} template${all.length == 1 ? '' : 's'}',
              key: const Key('template-count'),
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        ),
      if (filtered.isEmpty)
        KeyedSubtree(
          key: const Key('template-no-match'),
          child: ApprovalsEmptyState(
            kind: ApprovalsStateKind.noMatch,
            title: 'No templates match',
            message:
                _search.isNotEmpty ? 'Nothing matches “${_searchCtrl.text.trim()}”.' : 'No templates of this type.',
            actionLabel: 'Clear filters',
            onAction: () {
              _clearSearch();
              setState(() => _type = '');
            },
            compact: true,
          ),
        )
      else
        for (final key in keys) ...[
          _SectionHeader(type: key, count: groups[key]!.length),
          const SizedBox(height: 10),
          Wrap(spacing: gap, runSpacing: gap, children: [
            for (final t in groups[key]!)
              SizedBox(
                width: cardWidth,
                child: TemplateCard(
                  template: t,
                  onEdit: () => _openEditor(context, t),
                  onPreview: () => _openPreview(context, t),
                  onDelete: t.isBuiltin ? null : () => _confirmDelete(context, t),
                  onToggleActive: (v) => _toggleActive(context, t.id, v),
                ),
              ),
          ]),
          const SizedBox(height: 20),
        ],
    ];
  }

  /// Add / Edit: a full screen; true = the server confirmed a save.
  Future<void> _openEditor(BuildContext context, EmailTemplateModel? t) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TemplateEditorScreen(template: t)),
    );
    if (saved == true && context.mounted) {
      _toast(context, t == null ? 'Email template created' : 'Email template updated', true);
    }
  }

  /// Preview: a full screen; its "Edit Template" closes it and opens the editor (as web).
  Future<void> _openPreview(BuildContext context, EmailTemplateModel t) async {
    final result = await Navigator.of(context).push<TemplatePreviewResult>(
      MaterialPageRoute(builder: (_) => TemplatePreviewScreen(template: t)),
    );
    if (result == TemplatePreviewResult.edit && context.mounted) await _openEditor(context, t);
  }

  Future<void> _toggleActive(BuildContext context, int id, bool isActive) async {
    final error = await ref.read(emailTemplatesProvider.notifier).toggleActive(id, isActive);
    if (!context.mounted || error == null) return;
    _toast(context, error, false);
  }

  Future<void> _confirmDelete(BuildContext context, EmailTemplateModel t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(Icons.delete_outline, color: AppColors.error),
        ),
        title: Text('Delete template?', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Text('Delete “${t.displayName}”? This cannot be undone.',
            textAlign: TextAlign.center, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary, minimumSize: const Size(0, 44)),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('template-delete-confirm'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error, minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final error = await ref.read(emailTemplatesProvider.notifier).remove(t.id);
    if (context.mounted) _toast(context, error ?? '"${t.displayName}" deleted.', error == null);
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

// ── Hero: the blue band under the app bar (as Announcements / Assets) ─────────

class _Hero extends StatelessWidget {
  const _Hero({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return BlueHeroBanner(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.mail_outline, size: 20, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Customize transactional email messages sent by Royal HRMS',
                style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.9))),
          ),
        ]),
        const SizedBox(height: 12),
        TextField(
          key: const Key('template-search'),
          controller: controller,
          textInputAction: TextInputAction.search,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
          decoration: heroSearchFieldDecoration(
            hintText: 'Search templates…',
            showClear: controller.text.isNotEmpty,
            onClear: () {
              controller.clear();
              onChanged('');
            },
          ),
          onChanged: onChanged,
        ),
      ]),
    );
  }
}

// ── Type pills (a view filter over the loaded templates, with counts) ─────────

class _TypePills extends StatelessWidget {
  const _TypePills({required this.templates, required this.selected, required this.onSelect});
  final List<EmailTemplateModel> templates;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final t in templates) {
      counts.update(t.templateType ?? 'other', (n) => n + 1, ifAbsent: () => 1);
    }
    final keys = [..._kTypeOrder.where(counts.containsKey), ...counts.keys.where((k) => !_kTypeOrder.contains(k))];
    final entries = <(String, String, int)>[
      ('', 'All', templates.length),
      for (final k in keys) (k, _label(k).replaceAll(' Templates', ''), counts[k]!),
    ];
    return SizedBox(
      height: 56,
      child: ListView.separated(
        key: const Key('template-type-pills'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (value, label, count) = entries[i];
          final on = selected == value;
          return Semantics(
            selected: on,
            button: true,
            child: InkWell(
              key: Key('template-pill-${value.isEmpty ? 'all' : value}'),
              borderRadius: BorderRadius.circular(22),
              onTap: () => onSelect(value),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: on ? AppColors.primary : AppColors.border),
                ),
                child: Text('$label · $count',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: on ? Colors.white : AppColors.textPrimary,
                        fontWeight: on ? FontWeight.w700 : FontWeight.w600)),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Summary (counted from the loaded templates) ───────────────────────────────

class _Summary extends StatelessWidget {
  const _Summary({required this.templates});
  final List<EmailTemplateModel> templates;

  @override
  Widget build(BuildContext context) {
    final active = templates.where((t) => t.isActive).length;
    final custom = templates.where((t) => !t.isBuiltin).length;
    final tiles = <(IconData, Color, int, String)>[
      (Icons.mail_outline, AppColors.primary, templates.length, 'Total'),
      (Icons.check_circle_outline, AppColors.success, active, 'Active'),
      (Icons.edit_note_outlined, AppColors.warning, custom, 'Custom'),
    ];
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    return Container(
      key: const Key('template-summary'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(builder: (context, c) {
        final cols = (scale > 1.3 || c.maxWidth < 260) ? 1 : 3;
        final w = (c.maxWidth - 12 * (cols - 1)) / cols;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final (icon, color, value, label) in tiles)
            SizedBox(
              width: w,
              child: Row(children: [
                ApprovalsIconBox(icon, color: color, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$value',
                        style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                  ]),
                ),
              ]),
            ),
        ]);
      }),
    );
  }
}

// ── Email settings: branding + birthday wishes ────────────────────────────────

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.canViewBirthday});
  final bool canViewBirthday;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final two = c.maxWidth >= 600 && canViewBirthday;
      final w = two ? (c.maxWidth - 12) / 2 : c.maxWidth;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Email settings', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 10),
        Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(width: w, child: const EmailBrandingCard()),
          if (canViewBirthday) SizedBox(width: w, child: const BirthdaySettingsCard()),
        ]),
      ]);
    });
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.type, required this.count});
  final String type;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = templateTypeColor(type);
    final large = MediaQuery.textScalerOf(context).scale(10) / 10 > 1.3;
    final countText = Text('$count template${count == 1 ? '' : 's'}',
        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600));
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      ApprovalsIconBox(templateTypeIcon(type), color: color, size: 32),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(
            header: true,
            child: Text(_label(type), style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          // At large text the count sits under the title instead of squeezing it.
          if (large) countText,
        ]),
      ),
      if (!large) countText,
    ]);
  }
}

/// Shown while later pages of templates are still loading, or when one
/// failed (the templates already loaded stay listed; Retry resumes).
class _PagingStatus extends ConsumerWidget {
  const _PagingStatus({required this.loaded});

  final int loaded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paging = ref.watch(emailTemplatesPagingProvider);
    if (paging.complete) return const SizedBox.shrink();
    final of = paging.total != null ? ' ($loaded of ${paging.total})' : '';
    if (paging.error == null) {
      return Padding(
        key: const Key('email-templates-loading-more'),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        child: Row(
          children: [
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 8),
            Text('Loading more templates…$of', style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
          ],
        ),
      );
    }
    return Container(
      key: const Key('email-templates-load-more-error'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('Some templates couldn\'t be loaded$of. ${paging.error}',
                style: AppTextStyles.caption.copyWith(color: AppColors.error)),
          ),
          TextButton(
            key: const Key('email-templates-load-more-retry'),
            onPressed: () => ref.read(emailTemplatesProvider.notifier).loadRemaining(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
