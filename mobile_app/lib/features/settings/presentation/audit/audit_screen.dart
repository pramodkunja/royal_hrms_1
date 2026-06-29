import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/audit_model.dart';
import '../providers/settings_providers.dart';
import '../widgets/settings_app_bar.dart';

class AuditScreen extends ConsumerStatefulWidget {
  const AuditScreen({super.key});

  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen> {
  final _searchCtrl = TextEditingController();
  bool _showFilters = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(auditLogProvider);
    final filters = ref.watch(auditFiltersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SettingsAppBar(
        title: 'Audit Log',
        trailing: IconButton(
          icon: Icon(
            _showFilters ? Icons.filter_list_off : Icons.filter_list,
            color: _hasActiveFilters(filters) ? AppColors.primary : AppColors.textSecondary,
          ),
          onPressed: () => setState(() => _showFilters = !_showFilters),
        ),
      ),
      body: Column(
        children: [
          _SearchField(
            controller: _searchCtrl,
            onChanged: (v) => ref.read(auditFiltersProvider.notifier).state =
                filters.copyWith(search: v, page: 1),
          ),
          if (_showFilters)
            _FilterRow(filters: filters),
          if (_hasActiveFilters(filters))
            _ActiveFilterBanner(
              filters: filters,
              onClear: () {
                _searchCtrl.clear();
                ref.read(auditFiltersProvider.notifier).state =
                    const AuditLogFilters();
              },
            ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(message: e.toString()),
              data: (page) => page.entries.isEmpty
                  ? const _EmptyView()
                  : _AuditList(page: page, filters: filters),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasActiveFilters(AuditLogFilters f) =>
      f.module.isNotEmpty || f.dateFrom.isNotEmpty || f.dateTo.isNotEmpty || f.search.isNotEmpty;
}

// ── Search ────────────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: controller,
        style: AppTextStyles.body,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search by user, module or action…',
          hintStyle: AppTextStyles.body.copyWith(color: AppColors.textHint),
          prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textHint),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () { controller.clear(); onChanged(''); },
                )
              : null,
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}

// ── Filters ───────────────────────────────────────────────────────────────────

class _FilterRow extends ConsumerWidget {
  final AuditLogFilters filters;
  const _FilterRow({required this.filters});

  static const _kModules = [
    '', 'auth', 'employees', 'attendance', 'leave',
    'payroll', 'recruitment', 'settings', 'documents',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      color: AppColors.background,
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: filters.module.isEmpty ? '' : filters.module,
              style: AppTextStyles.body,
              decoration: _dec('Module'),
              items: _kModules.map((m) => DropdownMenuItem(
                value: m,
                child: Text(m.isEmpty ? 'All modules' : m, style: AppTextStyles.body),
              )).toList(),
              onChanged: (v) => ref.read(auditFiltersProvider.notifier).state =
                  filters.copyWith(module: v ?? '', page: 1),
            ),
          ),
          const SizedBox(width: 8),
          _DateChip(
            label: filters.dateFrom.isEmpty ? 'From date' : filters.dateFrom,
            active: filters.dateFrom.isNotEmpty,
            onTap: () => _pick(context, ref, isFrom: true),
          ),
          const SizedBox(width: 6),
          _DateChip(
            label: filters.dateTo.isEmpty ? 'To date' : filters.dateTo,
            active: filters.dateTo.isNotEmpty,
            onTap: () => _pick(context, ref, isFrom: false),
          ),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context, WidgetRef ref, {required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    final s =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    ref.read(auditFiltersProvider.notifier).state = isFrom
        ? filters.copyWith(dateFrom: s, page: 1)
        : filters.copyWith(dateTo: s, page: 1);
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    labelStyle: AppTextStyles.caption,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    isDense: true,
  );
}

class _DateChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _DateChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: active ? AppColors.primary : AppColors.textSecondary,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _ActiveFilterBanner extends StatelessWidget {
  final AuditLogFilters filters;
  final VoidCallback onClear;
  const _ActiveFilterBanner({required this.filters, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_outlined, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text('Filters active', style: AppTextStyles.caption.copyWith(color: AppColors.primary)),
          const Spacer(),
          GestureDetector(
            onTap: onClear,
            child: Text('Clear all',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primary, fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── List ──────────────────────────────────────────────────────────────────────

class _AuditList extends ConsumerWidget {
  final AuditLogPage page;
  final AuditLogFilters filters;
  const _AuditList({required this.page, required this.filters});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                '${page.total} record${page.total == 1 ? '' : 's'}  ·  Page ${page.currentPage} of ${page.totalPages}',
                style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            itemCount: page.entries.length + (page.hasNext ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              if (i == page.entries.length) {
                return _LoadMoreBtn(
                  onTap: () => ref.read(auditFiltersProvider.notifier).state =
                      filters.copyWith(page: filters.page + 1),
                );
              }
              return _AuditCard(entry: page.entries[i]);
            },
          ),
        ),
      ],
    );
  }
}

class _LoadMoreBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _LoadMoreBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.expand_more, size: 18),
        label: const Text('Load more'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

// ── Audit card ────────────────────────────────────────────────────────────────

class _AuditCard extends StatelessWidget {
  final AuditLogEntry entry;
  const _AuditCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final accent = _moduleColor(entry.module);
    final hasFooter = (entry.objectId != null && entry.objectId!.isNotEmpty) ||
        entry.ipAddress != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: accent, width: 3)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ModuleAvatar(module: entry.module),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Badges + timestamp ───────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Wrap prevents overflow when module/action names are long
                      Expanded(
                        child: Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: [
                            _Badge(
                              label: entry.module,
                              color: _moduleColor(entry.module),
                            ),
                            _ActionBadge(action: entry.action),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Date + time stacked at the right
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatDate(entry.createdAt),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textHint,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _formatTime(entry.createdAt),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textHint,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  // ── Actor ────────────────────────────────────────────────
                  Text(
                    entry.actorName,
                    style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (entry.actorRole.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      entry.actorRole,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  // ── Footer: object + IP ──────────────────────────────────
                  if (hasFooter) ...[
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (entry.objectId != null && entry.objectId!.isNotEmpty)
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.link_outlined,
                                  size: 12,
                                  color: AppColors.textHint,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'ID: \${entry.objectId}',
                                    style: AppTextStyles.caption
                                        .copyWith(fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (entry.ipAddress != null) ...[
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.router_outlined,
                            size: 12,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              entry.ipAddress!,
                              style: AppTextStyles.caption.copyWith(fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _moduleColor(String module) => switch (module.toLowerCase()) {
    'auth'        => const Color(0xFF9B51E0),
    'employees'   => AppColors.primary,
    'leave'       => const Color(0xFF219653),
    'payroll'     => const Color(0xFFF2994A),
    'settings'    => const Color(0xFF2D9CDB),
    'recruitment' => const Color(0xFFEB5757),
    _             => AppColors.textHint,
  };

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day} / ${dt.month} / ${dt.year}';
    } catch (_) {
      return '';
    }
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return iso;
    }
  }
}

class _ModuleAvatar extends StatelessWidget {
  final String module;
  const _ModuleAvatar({required this.module});

  @override
  Widget build(BuildContext context) {
    final icon = switch (module.toLowerCase()) {
      'auth'        => Icons.lock_outline,
      'employees'   => Icons.badge_outlined,
      'leave'       => Icons.beach_access_outlined,
      'payroll'     => Icons.payments_outlined,
      'settings'    => Icons.settings_outlined,
      'recruitment' => Icons.people_outline,
      _             => Icons.history_rounded,
    };
    final color = switch (module.toLowerCase()) {
      'auth'        => const Color(0xFF9B51E0),
      'employees'   => AppColors.primary,
      'leave'       => const Color(0xFF219653),
      'payroll'     => const Color(0xFFF2994A),
      'settings'    => const Color(0xFF2D9CDB),
      'recruitment' => const Color(0xFFEB5757),
      _             => AppColors.textHint,
    };
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label.isEmpty ? '—' : label,
      style: AppTextStyles.caption.copyWith(color: color, fontSize: 10, fontWeight: FontWeight.w600),
    ),
  );
}

class _ActionBadge extends StatelessWidget {
  final String action;
  const _ActionBadge({required this.action});

  Color get _color => switch (action.toLowerCase()) {
    'delete' || 'remove' || 'deleted' => AppColors.error,
    'create' || 'add' || 'created'    => AppColors.success,
    'login'  || 'logout'              => const Color(0xFF9B51E0),
    _                                 => const Color(0xFFF2994A),
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: _color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      action.isEmpty ? '—' : action,
      style: AppTextStyles.caption.copyWith(color: _color, fontSize: 10, fontWeight: FontWeight.w600),
    ),
  );
}

// ── Empty / Error ─────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.history_rounded, size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text('No audit records', style: AppTextStyles.h4),
          const SizedBox(height: 6),
          Text('System activities will appear here.', style: AppTextStyles.bodySecondary),
        ],
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
            Text('Could not load audit log', style: AppTextStyles.h4),
            const SizedBox(height: 6),
            Text(message, style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
