import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart' show dioProvider;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../employees/data/datasources/employee_assets_datasource.dart' show kAssetConditions;
import '../../../employees/presentation/widgets/employee_assets_tab.dart' show employeeAssetsProvider, fmtAssetDate;
import '../../data/models/asset_catalogue.dart';
import '../../../../shared/formatters/en_in_format.dart' show formatEnInDate;
import '../../../../shared/widgets/blue_app_bar.dart';
import '../../../profile/presentation/widgets/profile_widgets.dart' show ProfileSectionCard, ProfileTwoUp;
import '../../../../core/router/app_router.dart' show AppRoutes;
import '../../../../shared/widgets/blue_hero_banner.dart';
import '../../../approvals/presentation/widgets/approvals_kit.dart';
import '../../../approvals/presentation/widgets/approvals_ui.dart'
    show ApprovalsBadge, ApprovalsIconBox, ApprovalsTone, approvalsToneColor;
import '../../../dashboard/presentation/widgets/pushed_app_top_bar.dart';
import 'asset_bulk_sheet.dart' show AssetBulkKind, showAssetBulkSheet;

// Settings → Assets — web settings/assets/page.tsx (Asset Management). The
// list, filters, pagination, Add / Edit (category and type from the master
// lists, quick-add, "Other"), read-only Assignment Details, Delete, Send to
// Maintenance and Complete Maintenance. Buttons follow web usePermission
// (superuser flag or the permission): assets.create / assets.edit /
// assets.delete; the server checks them again and limits non-admins to their
// own branch. Assigning / returning stays on the employee's profile → Assets.

final assetCatalogueApiProvider = Provider<AssetCatalogueApi>((ref) => AssetCatalogueApi(ref.watch(dioProvider)));

typedef AssetQuery = ({String search, String status, String category, String assetType, String branch, int page});

final assetCatalogueProvider = FutureProvider.autoDispose.family<AssetPage, AssetQuery>((ref, q) => ref
    .read(assetCatalogueApiProvider)
    .list(
        search: q.search,
        status: q.status,
        category: q.category,
        assetType: q.assetType,
        branch: q.branch,
        page: q.page));

/// Branch / category / type options. A failed load surfaces as an error: the
/// form says so and offers Retry (web just showed an empty list); the Assets
/// list filters read these with valueOrNull, so they still simply offer none.
final assetBranchOptionsProvider =
    FutureProvider.autoDispose<List<NamedOption>>((ref) => ref.read(assetCatalogueApiProvider).branches());
final assetCategoriesProvider =
    FutureProvider.autoDispose<List<NamedOption>>((ref) => ref.read(assetCatalogueApiProvider).categories());
final assetTypesProvider = FutureProvider.autoDispose
    .family<List<NamedOption>, String?>((ref, categoryId) => ref.read(assetCatalogueApiProvider).types(categoryId));

/// Picks a date (replaceable in tests).
final assetDatePickerProvider = Provider<Future<DateTime?> Function(BuildContext, DateTime?)>(
  (ref) => (context, initial) => showDatePicker(
        context: context,
        initialDate: initial ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      ),
);

bool _has(UserEntity? u, String p) => u != null && (u.isSuperuser || u.permissions.contains(p));

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class AssetsSettingsScreen extends ConsumerStatefulWidget {
  const AssetsSettingsScreen({super.key});

  @override
  ConsumerState<AssetsSettingsScreen> createState() => _AssetsSettingsScreenState();
}

class _AssetsSettingsScreenState extends ConsumerState<AssetsSettingsScreen> {
  AssetQuery _q = (search: '', status: '', category: '', assetType: '', branch: '', page: 1);
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _setQuery(AssetQuery q) => setState(() => _q = q);

  /// Any filter change goes back to page 1 (web resets the page with each filter).
  void _emit({String? search, String? status, String? category, String? assetType, String? branch}) => _setQuery((
        search: search ?? _q.search,
        status: status ?? _q.status,
        category: category ?? _q.category,
        assetType: assetType ?? _q.assetType,
        branch: branch ?? _q.branch,
        page: 1,
      ));

  /// Typed filters apply after a short pause (web refetches per key).
  void _typed(void Function() apply) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), apply);
  }

  bool get _hasFilters =>
      _q.search.isNotEmpty ||
      _q.status.isNotEmpty ||
      _q.category.isNotEmpty ||
      _q.assetType.isNotEmpty ||
      _q.branch.isNotEmpty;

  int get _sheetFilterCount => [_q.branch, _q.category, _q.assetType].where((v) => v.isNotEmpty).length;

  void _clearAll() {
    _debounce?.cancel();
    _search.clear();
    _setQuery((search: '', status: '', category: '', assetType: '', branch: '', page: 1));
  }

  void _refresh() => ref.invalidate(assetCatalogueProvider);

  /// Web onImported / onAssigned: the list (and, after an assignment, any
  /// open employee asset lists) reload when something was saved.
  Future<void> _bulk(AssetBulkKind kind) async {
    final changed = await showAssetBulkSheet(context, kind);
    if (!changed || !mounted) return;
    _refresh();
    if (kind == AssetBulkKind.assign) ref.invalidate(employeeAssetsProvider);
  }

  /// Add / Edit open as a full screen (blue app bar, pinned actions); true = saved.
  Future<void> _openForm(CatalogueAsset? editing) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AssetFormScreen(editing: editing)),
    );
    if (saved == true) _refresh();
  }

  Future<void> _delete(CatalogueAsset a) async {
    final deleted = await showDialog<bool>(context: context, builder: (_) => _DeleteAssetDialog(asset: a));
    if (deleted == true) _refresh();
  }

  Future<void> _maintenance(CatalogueAsset a, {required bool complete}) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => complete ? _CompleteMaintenanceSheet(asset: a) : _SendToMaintenanceSheet(asset: a),
    );
    if (done == true) _refresh();
  }

  Future<void> _openFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FilterSheet(
        query: _q,
        branches: ref.read(assetBranchOptionsProvider).valueOrNull ?? const <NamedOption>[],
        onBranch: (v) => _emit(branch: v),
        onCategory: (v) => _typed(() => _emit(category: v.trim())),
        onAssetType: (v) => _typed(() => _emit(assetType: v.trim())),
        onClear: () {
          _debounce?.cancel();
          _setQuery((search: _q.search, status: _q.status, category: '', assetType: '', branch: '', page: 1));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final canCreate = _has(user, 'assets.create');
    final canEdit = _has(user, 'assets.edit');
    final canDelete = _has(user, 'assets.delete');
    final async = ref.watch(assetCatalogueProvider(_q));
    // Watched here so the options are loaded by the time the filter sheet (or a chip) needs them.
    final branchOptions = ref.watch(assetBranchOptionsProvider).valueOrNull ?? const <NamedOption>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      // The same blue bar Announcements (and every shell screen) has.
      appBar: const PushedAppTopBar(title: 'Asset Management', fallbackRoute: AppRoutes.settings),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              key: const Key('asset-add'),
              onPressed: () => _openForm(null),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add Asset', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Hero(
            controller: _search,
            filterCount: _sheetFilterCount,
            onSearch: (v) => _typed(() => _emit(search: v.trim())),
            onFilters: _openFilters,
          ),
          _StatusPills(selected: _q.status, onSelect: (v) => _emit(status: v)),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => ref.refresh(assetCatalogueProvider(_q).future).then((_) {}, onError: (_) {}),
              child: LayoutBuilder(builder: (context, box) {
                final cols = box.maxWidth >= 900 ? 3 : (box.maxWidth >= 600 ? 2 : 1);
                const gap = 12.0;
                final inner = (box.maxWidth > 1120 ? 1120.0 : box.maxWidth) - 32;
                final cardWidth = (inner - gap * (cols - 1)) / cols;
                final page = async.valueOrNull;
                return ListView(
                  key: const Key('asset-list'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(box.maxWidth > 1120 ? (box.maxWidth - 1120) / 2 + 16 : 16, 10,
                      box.maxWidth > 1120 ? (box.maxWidth - 1120) / 2 + 16 : 16, 96),
                  children: [
                    if (_sheetFilterCount > 0 || _q.search.isNotEmpty)
                      _AppliedFilters(
                        query: _q,
                        branchName:
                            branchOptions.where((b) => b.id == _q.branch).map((b) => b.name).firstOrNull ?? _q.branch,
                        onClearSearch: () {
                          _search.clear();
                          _emit(search: '');
                        },
                        onClearBranch: () => _emit(branch: ''),
                        onClearCategory: () => _emit(category: ''),
                        onClearType: () => _emit(assetType: ''),
                        onClearAll: _clearAll,
                      ),
                    // Web page actions: Bulk Assign (assets.edit), Bulk Import (assets.create).
                    if (canEdit || canCreate)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Wrap(spacing: 8, runSpacing: 8, children: [
                          if (canEdit)
                            OutlinedButton.icon(
                              key: const Key('asset-bulk-assign'),
                              onPressed: () => _bulk(AssetBulkKind.assign),
                              style: _pillButton(),
                              icon: const Icon(Icons.group_add_outlined, size: 18),
                              label: const Text('Bulk Assign'),
                            ),
                          if (canCreate)
                            OutlinedButton.icon(
                              key: const Key('asset-bulk-import'),
                              onPressed: () => _bulk(AssetBulkKind.import),
                              style: _pillButton(),
                              icon: const Icon(Icons.upload_file, size: 18),
                              label: const Text('Bulk Import'),
                            ),
                        ]),
                      ),
                    if (page != null && page.results.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text('${page.count} asset${page.count == 1 ? '' : 's'}',
                            key: const Key('asset-count'),
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                      ),
                    ...async.when(
                      loading: () => [const ApprovalsLoading(label: 'Loading assets…')],
                      error: (e, _) => [
                        KeyedSubtree(
                          key: const Key('asset-load-error'),
                          child: ApprovalsEmptyState.forError(e, onRetry: _refresh, compact: true, what: 'assets'),
                        ),
                      ],
                      data: (page) => page.results.isEmpty
                          ? [
                              KeyedSubtree(
                                key: const Key('asset-empty'),
                                child: _hasFilters
                                    ? ApprovalsEmptyState(
                                        kind: ApprovalsStateKind.noMatch,
                                        title: 'No assets match your filters',
                                        message: 'No assets found.',
                                        actionLabel: 'Clear filters',
                                        onAction: _clearAll,
                                        compact: true,
                                      )
                                    : const ApprovalsEmptyState(
                                        kind: ApprovalsStateKind.empty,
                                        title: 'No assets yet',
                                        message: 'No assets found.',
                                        icon: Icons.inventory_2_outlined,
                                        compact: true,
                                      ),
                              ),
                            ]
                          : [
                              Wrap(spacing: gap, runSpacing: gap, children: [
                                for (final a in page.results)
                                  SizedBox(
                                    width: cardWidth,
                                    child: _AssetCard(
                                      asset: a,
                                      canEdit: canEdit,
                                      canDelete: canDelete,
                                      onEdit: () => _openForm(a),
                                      onDelete: () => _delete(a),
                                      onSendToMaintenance: () => _maintenance(a, complete: false),
                                      onCompleteMaintenance: () => _maintenance(a, complete: true),
                                    ),
                                  ),
                              ]),
                              if (page.totalPages > 1)
                                _Pager(
                                  page: page.page,
                                  totalPages: page.totalPages,
                                  onPrev: _q.page <= 1
                                      ? null
                                      : () => _setQuery((
                                            search: _q.search,
                                            status: _q.status,
                                            category: _q.category,
                                            assetType: _q.assetType,
                                            branch: _q.branch,
                                            page: _q.page - 1
                                          )),
                                  onNext: _q.page >= page.totalPages
                                      ? null
                                      : () => _setQuery((
                                            search: _q.search,
                                            status: _q.status,
                                            category: _q.category,
                                            assetType: _q.assetType,
                                            branch: _q.branch,
                                            page: _q.page + 1
                                          )),
                                ),
                            ],
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
}

ButtonStyle _pillButton() => OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      minimumSize: const Size(0, 44),
      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      textStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
    );

// ── Hero: the blue band under the app bar (as Announcements) with search + filters ─────────

class _Hero extends StatelessWidget {
  const _Hero({required this.controller, required this.filterCount, required this.onSearch, required this.onFilters});
  final TextEditingController controller;
  final int filterCount;
  final ValueChanged<String> onSearch;
  final VoidCallback onFilters;

  @override
  Widget build(BuildContext context) {
    return BlueHeroBanner(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.inventory_2_outlined, size: 20, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text("Track company equipment and who it's assigned to",
                style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.9))),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              key: const Key('asset-search'),
              controller: controller,
              textInputAction: TextInputAction.search,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
              decoration: heroSearchFieldDecoration(hintText: 'Search tag, name, serial number…'),
              onChanged: onSearch,
            ),
          ),
          const SizedBox(width: 8),
          Stack(clipBehavior: Clip.none, children: [
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton.filled(
                key: const Key('asset-filters'),
                tooltip: 'Filters',
                onPressed: onFilters,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.tune_rounded),
              ),
            ),
            if (filterCount > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  key: const Key('asset-filters-count'),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.circular(10)),
                  child: Text('$filterCount',
                      style: AppTextStyles.caption
                          .copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
                ),
              ),
          ]),
        ]),
      ]),
    );
  }
}

// ── Status pills (web's Status select as one-tap pills; the value sent is identical) ──────

class _StatusPills extends StatelessWidget {
  const _StatusPills({required this.selected, required this.onSelect});
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final all = <(String, String)>[('', 'All Statuses'), ...kAssetStatuses];
    return SizedBox(
      height: 56,
      child: ListView.separated(
        key: const Key('asset-status-pills'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        itemCount: all.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (v, label) = all[i];
          final on = selected == v;
          return Semantics(
            selected: on,
            button: true,
            child: InkWell(
              key: Key('asset-pill-${v.isEmpty ? 'all' : v}'),
              borderRadius: BorderRadius.circular(22),
              onTap: () => onSelect(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: on ? AppColors.primary : AppColors.border),
                ),
                child: Text(label,
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

// ── Applied filters (removable) ───────────────────────────────────────────────────────────

class _AppliedFilters extends StatelessWidget {
  const _AppliedFilters({
    required this.query,
    required this.branchName,
    required this.onClearSearch,
    required this.onClearBranch,
    required this.onClearCategory,
    required this.onClearType,
    required this.onClearAll,
  });
  final AssetQuery query;
  final String branchName;
  final VoidCallback onClearSearch;
  final VoidCallback onClearBranch;
  final VoidCallback onClearCategory;
  final VoidCallback onClearType;
  final VoidCallback onClearAll;

  Widget _chip(String key, IconData icon, String label, VoidCallback onClear) => InputChip(
        key: Key(key),
        avatar: Icon(icon, size: 16, color: AppColors.primary),
        label: Text(label, overflow: TextOverflow.ellipsis),
        labelStyle: AppTextStyles.caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        backgroundColor: AppColors.surface,
        side: BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        deleteIcon: const Icon(Icons.close, size: 16),
        deleteButtonTooltipMessage: 'Remove filter',
        onDeleted: onClear,
        visualDensity: VisualDensity.compact,
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (query.search.isNotEmpty) _chip('asset-chip-search', Icons.search, '"${query.search}"', onClearSearch),
        if (query.branch.isNotEmpty) _chip('asset-chip-branch', Icons.business_outlined, branchName, onClearBranch),
        if (query.category.isNotEmpty)
          _chip('asset-chip-category', Icons.category_outlined, query.category, onClearCategory),
        if (query.assetType.isNotEmpty)
          _chip('asset-chip-type', Icons.devices_other_outlined, query.assetType, onClearType),
        TextButton(
          key: const Key('asset-clear-filters'),
          onPressed: onClearAll,
          style: TextButton.styleFrom(foregroundColor: AppColors.primary, minimumSize: const Size(0, 40)),
          child: const Text('Clear all'),
        ),
      ]),
    );
  }
}

// ── Filter sheet (web: branch, category, asset type; status is the pill row) ──────────────

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.query,
    required this.branches,
    required this.onBranch,
    required this.onCategory,
    required this.onAssetType,
    required this.onClear,
  });
  final AssetQuery query;
  final List<NamedOption> branches;
  final ValueChanged<String> onBranch;
  final ValueChanged<String> onCategory;
  final ValueChanged<String> onAssetType;
  final VoidCallback onClear;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _branch = widget.query.branch;
  late final _category = TextEditingController(text: widget.query.category);
  late final _type = TextEditingController(text: widget.query.assetType);

  @override
  void dispose() {
    _category.dispose();
    _type.dispose();
    super.dispose();
  }

  OutlineInputBorder _border(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c, width: w));

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        filled: true,
        fillColor: AppColors.surface,
        border: _border(AppColors.border),
        enabledBorder: _border(AppColors.border),
        focusedBorder: _border(AppColors.primary, 1.5),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: Text('Filters', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, fontSize: 16))),
            TextButton(
              key: const Key('asset-sheet-clear'),
              onPressed: () {
                widget.onClear();
                setState(() {
                  _branch = '';
                  _category.clear();
                  _type.clear();
                });
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              child: const Text('Clear'),
            ),
          ]),
          const SizedBox(height: 8),
          _label('Branch'),
          KeyedSubtree(
            key: const Key('asset-filter-branch'),
            child: DropdownButtonFormField<String>(
              key: ValueKey('asset-filter-branch-${widget.branches.length}-$_branch'),
              initialValue: widget.branches.any((b) => b.id == _branch) ? _branch : '',
              isExpanded: true,
              borderRadius: BorderRadius.circular(12),
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
              decoration: _dec(''),
              items: [
                const DropdownMenuItem(value: '', child: Text('All Branches')),
                for (final b in widget.branches)
                  DropdownMenuItem(value: b.id, child: Text(b.name, maxLines: 2, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) {
                setState(() => _branch = v ?? '');
                widget.onBranch(v ?? '');
              },
            ),
          ),
          const SizedBox(height: 14),
          _label('Category'),
          TextField(
            key: const Key('asset-filter-category'),
            controller: _category,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
            decoration: _dec('Category'),
            onChanged: widget.onCategory,
          ),
          const SizedBox(height: 14),
          _label('Asset Type'),
          TextField(
            key: const Key('asset-filter-type'),
            controller: _type,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
            decoration: _dec('Asset Type'),
            onChanged: widget.onAssetType,
          ),
          const SizedBox(height: 18),
          FilledButton(
            key: const Key('asset-sheet-done'),
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: const Text('Done'),
          ),
        ]),
      ),
    );
  }
}

// ── Pager ─────────────────────────────────────────────────────────────────────────────────

class _Pager extends StatelessWidget {
  const _Pager({required this.page, required this.totalPages, required this.onPrev, required this.onNext});
  final int page;
  final int totalPages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const Key('asset-prev'),
              onPressed: onPrev,
              style: _pillButton(),
              icon: const Icon(Icons.chevron_left),
              label: const Text('Prev'),
            ),
            Text('Page $page of $totalPages',
                key: const Key('asset-page'),
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            OutlinedButton(
              key: const Key('asset-next'),
              onPressed: onNext,
              style: _pillButton(),
              child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Text('Next'), SizedBox(width: 4), Icon(Icons.chevron_right, size: 20)]),
            ),
          ]),
    );
  }
}

// ── Asset card ────────────────────────────────────────────────────────────────────────────

ApprovalsTone _statusTone(String status) => switch (status) {
      'available' => ApprovalsTone.success,
      'assigned' => ApprovalsTone.info,
      'under_repair' => ApprovalsTone.warning,
      'damaged' || 'lost' => ApprovalsTone.error,
      _ => ApprovalsTone.neutral, // retired, disposed
    };

ApprovalsTone _conditionTone(String condition) => switch (condition.toLowerCase()) {
      'new' || 'good' => ApprovalsTone.success,
      'fair' => ApprovalsTone.warning,
      'damaged' => ApprovalsTone.error,
      _ => ApprovalsTone.neutral,
    };

class _AssetCard extends StatelessWidget {
  const _AssetCard({
    required this.asset,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
    required this.onSendToMaintenance,
    required this.onCompleteMaintenance,
  });

  final CatalogueAsset asset;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSendToMaintenance;
  final VoidCallback onCompleteMaintenance;

  ButtonStyle _action(Color color) => TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
      );

  @override
  Widget build(BuildContext context) {
    final a = asset;
    final tone = _statusTone(a.status);
    final accent = approvalsToneColor(tone);
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    final badge = ApprovalsBadge(a.statusDisplay, tone, key: Key('asset-status-${a.id}'));
    final title = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(a.assetName,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.label.copyWith(fontSize: 15, fontWeight: FontWeight.w700, height: 1.3)),
      const SizedBox(height: 4),
      Container(
        key: Key('asset-tag-${a.id}'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: AppColors.backgroundLow, borderRadius: BorderRadius.circular(6)),
        child: Text(a.assetTag,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700, letterSpacing: 0.4, fontSize: 11.5)),
      ),
    ]);
    final hasActions = canEdit || canDelete;
    return Container(
      key: Key('asset-row-${a.id}'),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        // Status-coloured accent edge, as on the Announcements cards.
        Positioned(left: 0, top: 0, bottom: 0, width: 4, child: ColoredBox(color: accent)),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              LayoutBuilder(builder: (context, c) {
                final stacked = c.maxWidth < 260 || scale > 1.3;
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (!stacked) ...[
                    ApprovalsIconBox(Icons.inventory_2_outlined, color: accent, size: 40),
                    const SizedBox(width: 10)
                  ],
                  Expanded(
                    child: stacked
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [title, const SizedBox(height: 6), badge])
                        : title,
                  ),
                  if (!stacked) ...[const SizedBox(width: 8), badge],
                ]);
              }),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                ApprovalsChip(a.categoryLabel, icon: Icons.category_outlined),
                ApprovalsChip(a.typeLabel, icon: Icons.devices_other_outlined),
                ApprovalsChip(a.branchName, icon: Icons.business_outlined),
                ApprovalsChip('Condition: ${a.conditionDisplay}',
                    icon: Icons.verified_outlined, tone: _conditionTone(a.conditionDisplay)),
              ]),
              if (hasActions) ...[
                const SizedBox(height: 8),
                Divider(height: 1, color: AppColors.border.withValues(alpha: 0.7)),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(alignment: WrapAlignment.end, spacing: 2, children: [
                    if (canEdit && a.status == 'damaged')
                      Tooltip(
                        message: 'Send to Maintenance',
                        child: Semantics(
                          label: 'Send to Maintenance',
                          excludeSemantics: true,
                          button: true,
                          child: TextButton.icon(
                            key: Key('asset-maintenance-${a.id}'),
                            onPressed: onSendToMaintenance,
                            style: _action(AppColors.warning),
                            icon: const Icon(Icons.build_outlined, size: 18),
                            label: const Text('Maintenance'),
                          ),
                        ),
                      ),
                    if (canEdit && a.status == 'under_repair' && a.activeMaintenance != null)
                      Tooltip(
                        message: 'Complete Maintenance',
                        child: Semantics(
                          label: 'Complete Maintenance',
                          excludeSemantics: true,
                          button: true,
                          child: TextButton.icon(
                            key: Key('asset-complete-${a.id}'),
                            onPressed: onCompleteMaintenance,
                            style: _action(AppColors.success),
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            label: const Text('Complete'),
                          ),
                        ),
                      ),
                    if (canEdit)
                      TextButton.icon(
                        key: Key('asset-edit-${a.id}'),
                        onPressed: onEdit,
                        style: _action(AppColors.primary),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit'),
                      ),
                    if (canDelete)
                      TextButton.icon(
                        key: Key('asset-delete-${a.id}'),
                        onPressed: onDelete,
                        style: _action(AppColors.error),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Delete'),
                      ),
                  ]),
                ),
              ] else
                const SizedBox(height: 8),
            ]),
          ),
        ),
      ]),
    );
  }
}

Widget _errorBox(String text, String key) => Container(
      key: Key(key),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.error_outline, size: 18, color: AppColors.error),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error))),
      ]),
    );

/// Sheet header: drag handle, title, close.
Widget _sheetHeader(BuildContext context, String title, {bool busy = false}) => Column(children: [
      const SizedBox(height: 10),
      Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 8, 4),
        child: Row(children: [
          Expanded(child: Text(title, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, fontSize: 16))),
          IconButton(
              tooltip: 'Close',
              onPressed: busy ? null : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close)),
        ]),
      ),
    ]);

/// The page's input look (rounded outline, white fill), shared by the sheets.
InputDecoration _inputDeco({String? hint, Widget? suffix}) {
  OutlineInputBorder border(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c, width: w));
  return InputDecoration(
    hintText: hint,
    hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    filled: true,
    fillColor: AppColors.surface,
    border: border(AppColors.border),
    enabledBorder: border(AppColors.border),
    focusedBorder: border(AppColors.primary, 1.5),
    suffixIcon: suffix,
  );
}

/// Label above its control; a trailing " *" is drawn red.
Widget _labelled(String label, Widget control) {
  final required = label.endsWith(' *');
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text.rich(
        TextSpan(children: [
          TextSpan(text: required ? label.substring(0, label.length - 2) : label),
          if (required) TextSpan(text: ' *', style: TextStyle(color: AppColors.error)),
        ]),
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 6),
      control,
    ]),
  );
}

// ── Add / Edit ────────────────────────────────────────────────────────────────

/// Add Asset / Edit asset (web's Add/Edit modal) as a full screen: the blue app
/// bar, section cards, and a pinned Cancel / Save bar. Same fields, defaults,
/// payload and server-side validation as web; nothing is validated on the
/// device that web does not validate. Pops `true` after the server confirmed.
class AssetFormScreen extends ConsumerStatefulWidget {
  const AssetFormScreen({super.key, this.editing});
  final CatalogueAsset? editing;

  @override
  ConsumerState<AssetFormScreen> createState() => _AssetFormScreenState();
}

class _AssetFormScreenState extends ConsumerState<AssetFormScreen> {
  late final Map<String, String> _form = widget.editing == null ? blankAssetForm() : assetFormFrom(widget.editing!);
  final _ctrls = <String, TextEditingController>{};
  final _anchors = <String, GlobalKey>{};
  final _scroll = ScrollController();
  Map<String, String> _errors = {};
  String? _saveError;
  bool _saving = false;

  /// The order fields appear in, to find the first one the server refused.
  static const _order = [
    'asset_tag',
    'asset_name',
    'brand',
    'model',
    'serial_number',
    'category',
    'category_other',
    'asset_type',
    'asset_type_other',
    'condition',
    'branch',
    'purchase_date',
    'purchase_price',
    'vendor',
    'warranty_start_date',
    'warranty_end_date',
    'description',
  ];

  TextEditingController _c(String f) => _ctrls.putIfAbsent(f, () => TextEditingController(text: _form[f]));
  GlobalKey _anchor(String f) => _anchors.putIfAbsent(f, GlobalKey.new);

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  void _set(String f, String v) => setState(() {
        _form[f] = v;
        _errors.remove(f);
      });

  /// Web changeCategory: a new category clears the type (and the other names).
  void _changeCategory(String name) => setState(() {
        _errors.remove('category');
        _form['category'] = name;
        if (name != kAssetOther) _form['category_other'] = '';
        _form['asset_type'] = '';
        _form['asset_type_other'] = '';
        _c('category_other').text = _form['category_other']!;
        _c('asset_type_other').text = '';
      });

  void _changeType(String name) => setState(() {
        _errors.remove('asset_type');
        _form['asset_type'] = name;
        if (name != kAssetOther) {
          _form['asset_type_other'] = '';
          _c('asset_type_other').text = '';
        }
      });

  /// After a refused save: bring the first refused field (or, for a message
  /// with no field, the banner at the top) into view.
  void _showProblem() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final first = _order.where(_errors.containsKey).firstOrNull;
      final ctx = first == null ? null : _anchors[first]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, alignment: 0.15, duration: const Duration(milliseconds: 250));
      } else if (_scroll.hasClients) {
        _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _saveError = null;
      _errors = {};
    });
    final api = ref.read(assetCatalogueApiProvider);
    try {
      final payload = assetPayload(_form);
      if (widget.editing == null) {
        await api.create(payload);
      } else {
        await api.update(widget.editing!.id, payload);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      final err = assetError(e, 'Failed to save asset. Please try again.');
      if (mounted) {
        setState(() {
          _errors = err.fields;
          _saveError = err.message;
        });
        _showProblem();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _quickAdd({required bool type, required String? categoryId}) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _QuickAddDialog(type: type, categoryName: _form['category']!, categoryId: categoryId),
    );
    if (name == null || !mounted) return;
    if (type) {
      ref.invalidate(assetTypesProvider(categoryId));
      _changeType(name);
    } else {
      ref.invalidate(assetCategoriesProvider);
      _changeCategory(name);
    }
  }

  // ── Controls ──────────────────────────────────────────────────────────────

  OutlineInputBorder _border(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c, width: w));

  InputDecoration _decoration({String? hint, String? error, Widget? suffix, bool enabled = true}) => InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
        errorText: error,
        errorMaxLines: 4,
        errorStyle: AppTextStyles.caption.copyWith(color: AppColors.error, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        filled: true,
        fillColor: enabled ? AppColors.surface : AppColors.backgroundLow,
        border: _border(AppColors.border),
        enabledBorder: _border(AppColors.border),
        disabledBorder: _border(AppColors.border),
        focusedBorder: _border(AppColors.primary, 1.5),
        errorBorder: _border(AppColors.error),
        focusedErrorBorder: _border(AppColors.error, 1.5),
        suffixIcon: suffix,
      );

  /// A labelled field: label above, control below, its own scroll anchor.
  Widget _field(String f, String label, Widget control, {bool required = false, String? helper}) => Padding(
        key: _anchor(f),
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text.rich(
            TextSpan(children: [
              TextSpan(text: label),
              if (required) TextSpan(text: ' *', style: TextStyle(color: AppColors.error)),
            ]),
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          control,
          if (helper != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(helper, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 12)),
            ),
        ]),
      );

  Widget _text(String f, String label,
          {String? hint, TextInputType? keyboard, int maxLines = 1, bool required = false, TextInputAction? action}) =>
      _field(
        f,
        label,
        TextField(
          key: Key('asset-field-$f'),
          controller: _c(f),
          keyboardType: keyboard,
          textInputAction: action ?? (maxLines > 1 ? TextInputAction.newline : TextInputAction.next),
          minLines: maxLines > 1 ? 3 : 1,
          maxLines: maxLines,
          enabled: !_saving,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
          decoration: _decoration(hint: hint, error: _errors[f]),
          onChanged: (v) => _set(f, v),
        ),
        required: required,
      );

  Widget _date(String f, String label) {
    final value = _form[f] ?? '';
    final parsed = DateTime.tryParse(value);
    final shown = parsed == null ? null : formatEnInDate(parsed);
    return _field(
      f,
      label,
      InkWell(
        key: Key('asset-field-$f'),
        borderRadius: BorderRadius.circular(10),
        onTap: _saving
            ? null
            : () async {
                FocusScope.of(context).unfocus();
                final picked = await ref.read(assetDatePickerProvider)(context, parsed);
                if (picked != null && mounted) _set(f, _iso(picked));
              },
        child: InputDecorator(
          decoration: _decoration(
            error: _errors[f],
            suffix: value.isEmpty
                ? Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textHint)
                : IconButton(
                    key: Key('asset-clear-$f'),
                    tooltip: 'Clear $label',
                    icon: Icon(Icons.close, size: 18, color: AppColors.textHint),
                    onPressed: _saving ? null : () => _set(f, ''),
                  ),
          ),
          child: Text(
            shown ?? 'Select date',
            style: AppTextStyles.bodySmall.copyWith(color: shown == null ? AppColors.textHint : AppColors.textPrimary),
          ),
        ),
      ),
    );
  }

  /// A dropdown over a list that may still be loading, empty or have failed
  /// (those states are said out loud instead of showing a silently empty menu).
  Widget _select(String f, String label, String value, List<(String, String)> options,
      {required ValueChanged<String>? onChanged,
      String? error,
      String placeholder = '',
      bool required = false,
      AsyncValue<Object?>? source,
      VoidCallback? onRetry,
      String? emptyNote,
      Widget? trailing}) {
    final loading = source != null && source.isLoading && !source.hasValue;
    final failed = source != null && source.hasError && !source.hasValue;
    final selected = options.any((o) => o.$1 == value) ? value : '';
    final control = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: KeyedSubtree(
          key: Key('asset-field-$f'),
          child: DropdownButtonFormField<String>(
            key: ValueKey('$f-$selected-${options.length}-$loading'),
            initialValue: selected,
            isExpanded: true,
            menuMaxHeight: 340,
            borderRadius: BorderRadius.circular(12),
            icon: loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
            decoration: _decoration(error: error, enabled: onChanged != null && !_saving),
            selectedItemBuilder: (_) => [
              if (placeholder.isNotEmpty)
                Text(loading ? 'Loading…' : placeholder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint)),
              for (final (_, l) in options) Text(l, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
            items: [
              if (placeholder.isNotEmpty) DropdownMenuItem(value: '', child: Text(placeholder)),
              for (final (v, l) in options)
                DropdownMenuItem(value: v, child: Text(l, maxLines: 2, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: onChanged == null || _saving ? null : (v) => onChanged(v ?? ''),
          ),
        ),
      ),
      if (trailing != null) ...[const SizedBox(width: 8), trailing],
    ]);
    return _field(f, label, control,
            required: required, helper: failed ? null : (!loading && options.isEmpty ? emptyNote : null))
        .withRetry(failed: failed, onRetry: onRetry, what: label);
  }

  Widget _plus(String key, String tooltip, VoidCallback? onTap) => SizedBox(
        width: 48,
        height: 48,
        child: OutlinedButton(
          key: Key(key),
          onPressed: _saving ? null : onTap,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: AppColors.primary,
            side: BorderSide(color: onTap == null ? AppColors.border : AppColors.primary.withValues(alpha: 0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Tooltip(message: tooltip, child: const Icon(Icons.add, size: 20)),
        ),
      );

  Widget _banner(String text) => Container(
        key: const Key('asset-save-error'),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.error_outline, size: 18, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error))),
        ]),
      );

  Widget _actionBar(BuildContext context, bool editing) {
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    final cancel = OutlinedButton(
      key: const Key('asset-cancel'),
      onPressed: _saving ? null : () => Navigator.of(context).pop(),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        foregroundColor: AppColors.textPrimary,
        side: BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      child: const Text('Cancel'),
    );
    final save = FilledButton(
      key: const Key('asset-save'),
      onPressed: _saving ? null : _save,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        backgroundColor: AppColors.primary,
        // While saving the button stays blue with its spinner (not a greyed-out look).
        disabledBackgroundColor: _saving ? AppColors.primary : null,
        disabledForegroundColor: _saving ? Colors.white : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      child: _saving
          ? const Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 10),
              Text('Saving…'),
            ])
          : Text(editing ? 'Save Changes' : 'Create Asset'),
    );
    return Material(
      color: AppColors.surface,
      elevation: 4,
      shadowColor: Colors.black12,
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: LayoutBuilder(builder: (context, c) {
                if (c.maxWidth < 300 || scale > 1.3) {
                  return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        save,
                        const SizedBox(height: 8),
                        cancel,
                      ]);
                }
                return Row(children: [
                  Expanded(child: cancel),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: save),
                ]);
              }),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing;
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final canQuickAdd = _has(user, 'assets.create');
    final categoriesAsync = ref.watch(assetCategoriesProvider);
    final categories = categoriesAsync.valueOrNull ?? const <NamedOption>[];
    final category = _form['category']!;
    final selectedCategoryId = categories.where((c) => c.name == category).firstOrNull?.id;
    final typesAsync = ref.watch(assetTypesProvider(selectedCategoryId));
    final types = typesAsync.valueOrNull ?? const <NamedOption>[];
    final branchesAsync = ref.watch(assetBranchOptionsProvider);
    final branches = branchesAsync.valueOrNull ?? const <NamedOption>[];
    final type = _form['asset_type']!;
    // Web: a legacy value missing from the master list is kept as an option.
    final categoryOptions = [
      for (final c in categories) (c.name, c.name),
      if (category.isNotEmpty && !categories.any((c) => c.name == category)) (category, category),
    ];
    final typeOptions = [
      for (final t in types) (t.name, t.name),
      if (type.isNotEmpty && !types.any((t) => t.name == type)) (type, type),
    ];
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final tight = MediaQuery.sizeOf(context).height - MediaQuery.viewInsetsOf(context).bottom < 480;

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: BlueAppBar(title: editing == null ? 'Add Asset' : 'Edit: ${editing.assetTag}'),
        // With the keyboard up on a very short screen the bar would eat the form: it
        // returns as soon as the keyboard closes.
        bottomNavigationBar: keyboardOpen && tight ? null : _actionBar(context, editing != null),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            // Not a lazy list: every field is built, so a refused field far down can be scrolled to.
            child: SingleChildScrollView(
              key: const Key('asset-form'),
              controller: _scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (_saveError != null) _banner(_saveError!),
                if (editing != null) ...[_AssignmentDetails(asset: editing), const SizedBox(height: 12)],
                ProfileSectionCard(
                  icon: Icons.inventory_2_outlined,
                  title: 'Asset Information',
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _text('asset_tag', 'Asset Tag', hint: 'e.g. LAP-001', required: true),
                    _text('asset_name', 'Asset Name', hint: 'e.g. Dell Latitude 5420', required: true),
                    ProfileTwoUp(left: _text('brand', 'Brand'), right: _text('model', 'Model')),
                    _text('serial_number', 'Serial Number'),
                  ]),
                ),
                const SizedBox(height: 12),
                ProfileSectionCard(
                  icon: Icons.category_outlined,
                  title: 'Classification',
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _select('category', 'Category', category, categoryOptions,
                        required: true,
                        placeholder: 'Select category…',
                        error: _errors['category'],
                        source: categoriesAsync,
                        onRetry: () => ref.invalidate(assetCategoriesProvider),
                        emptyNote: 'No categories yet. Add one with +.',
                        onChanged: _changeCategory,
                        trailing: canQuickAdd
                            ? _plus(
                                'asset-add-category', 'Add Category', () => _quickAdd(type: false, categoryId: null))
                            : null),
                    if (category == kAssetOther)
                      _text('category_other', 'Other category', hint: 'Other category — enter a name'),
                    _select('asset_type', 'Asset Type', type, typeOptions,
                        required: true,
                        placeholder: category.isEmpty ? 'Select a category first' : 'Select asset type…',
                        error: _errors['asset_type'],
                        source: category.isEmpty ? null : typesAsync,
                        onRetry: () => ref.invalidate(assetTypesProvider(selectedCategoryId)),
                        emptyNote: category.isEmpty ? null : 'No asset types in this category. Add one with +.',
                        onChanged: category.isEmpty ? null : _changeType,
                        trailing: canQuickAdd
                            ? _plus(
                                'asset-add-type',
                                'Add Asset Type',
                                selectedCategoryId == null
                                    ? null
                                    : () => _quickAdd(type: true, categoryId: selectedCategoryId))
                            : null),
                    if (type == kAssetOther)
                      _text('asset_type_other', 'Other asset type', hint: 'Other asset type — enter a name'),
                  ]),
                ),
                const SizedBox(height: 12),
                ProfileSectionCard(
                  icon: Icons.business_outlined,
                  title: 'Condition & Location',
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _select('condition', 'Condition', _form['condition']!, kAssetConditions,
                        onChanged: (v) => _set('condition', v)),
                    _select('branch', 'Branch', _form['branch']!, [for (final b in branches) (b.id, b.name)],
                        required: true,
                        placeholder: 'Select branch…',
                        error: _errors['branch'],
                        source: branchesAsync,
                        onRetry: () => ref.invalidate(assetBranchOptionsProvider),
                        emptyNote: 'No branches available.',
                        onChanged: (v) => _set('branch', v)),
                  ]),
                ),
                const SizedBox(height: 12),
                ProfileSectionCard(
                  icon: Icons.receipt_long_outlined,
                  title: 'Purchase Details',
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    ProfileTwoUp(
                      left: _date('purchase_date', 'Purchase Date'),
                      right: _text('purchase_price', 'Purchase Price',
                          keyboard: const TextInputType.numberWithOptions(decimal: true), hint: '0.00'),
                    ),
                    _text('vendor', 'Vendor'),
                  ]),
                ),
                const SizedBox(height: 12),
                ProfileSectionCard(
                  icon: Icons.verified_user_outlined,
                  title: 'Warranty',
                  child: ProfileTwoUp(
                    left: _date('warranty_start_date', 'Warranty Start'),
                    right: _date('warranty_end_date', 'Warranty End'),
                  ),
                ),
                const SizedBox(height: 12),
                ProfileSectionCard(
                  icon: Icons.notes_outlined,
                  title: 'Notes',
                  child: _text('description', 'Description / Remarks', maxLines: 4),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

extension on Widget {
  /// Under a dropdown whose list failed to load: the failure, with Retry.
  Widget withRetry({required bool failed, required VoidCallback? onRetry, required String what}) {
    if (!failed) return this;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      this,
      Padding(
        padding: const EdgeInsets.only(bottom: 14, top: 0),
        child: Builder(builder: (context) {
          return Row(children: [
            Icon(Icons.error_outline, size: 16, color: AppColors.error),
            const SizedBox(width: 6),
            Expanded(
              child: Text("Couldn't load ${what.toLowerCase()} options.",
                  style: AppTextStyles.caption.copyWith(color: AppColors.error, fontSize: 12)),
            ),
            TextButton(
              key: Key('asset-retry-${what.toLowerCase().replaceAll(' ', '_')}'),
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: AppColors.primary, minimumSize: const Size(48, 40)),
              child: const Text('Retry'),
            ),
          ]);
        }),
      ),
    ]);
  }
}

/// Web AssignmentDetails: the current holder, re-read from the asset; on a
/// failed refresh the list row's data is shown with a note. Read-only.
class _AssignmentDetails extends ConsumerStatefulWidget {
  const _AssignmentDetails({required this.asset});
  final CatalogueAsset asset;

  @override
  ConsumerState<_AssignmentDetails> createState() => _AssignmentDetailsState();
}

class _AssignmentDetailsState extends ConsumerState<_AssignmentDetails> {
  CatalogueAsset? _fresh;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    ref.read(assetCatalogueApiProvider).detail(widget.asset.id).then((a) {
      if (mounted) setState(() => _fresh = a);
    }, onError: (_) {
      if (mounted) setState(() => _failed = true);
    }).whenComplete(() {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final view = holderView(_fresh ?? widget.asset);
    final small = AppTextStyles.caption.copyWith(fontSize: 12);
    // Label above its value: wraps cleanly at any width or text size.
    Widget item(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: small.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary)),
          ]),
        );
    return KeyedSubtree(
      key: const Key('asset-assignment-details'),
      child: ProfileSectionCard(
        icon: Icons.how_to_reg_outlined,
        title: 'Assignment Details',
        trailing: Text(
          _loading ? 'Loading…' : (view is HolderAssigned ? view.status : 'Not assigned'),
          key: const Key('asset-holder-badge'),
          style: small.copyWith(fontWeight: FontWeight.w600, color: AppColors.primary),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          switch (view) {
            HolderAssigned() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                item('Assigned to', view.employee),
                item('Employee ID', view.code ?? '—'),
                item('Assigned on', fmtAssetDate(view.assignedDate)),
                item('Expected return', view.expectedReturn != null ? fmtAssetDate(view.expectedReturn!) : 'Not set'),
              ]),
            HolderNone() => Text(view.message, style: AppTextStyles.bodySmall),
          },
          if (_failed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text("Couldn't refresh the assignment; showing the details from the list.",
                  key: const Key('asset-holder-stale'), style: small.copyWith(color: AppColors.warning)),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text("Read-only. Assign or return assets from the employee's profile → Assets.", style: small),
          ),
        ]),
      ),
    );
  }
}

/// Web quick-add Category / Asset Type modals.
class _QuickAddDialog extends ConsumerStatefulWidget {
  const _QuickAddDialog({required this.type, required this.categoryName, required this.categoryId});
  final bool type;
  final String categoryName;
  final String? categoryId;

  @override
  ConsumerState<_QuickAddDialog> createState() => _QuickAddDialogState();
}

class _QuickAddDialogState extends ConsumerState<_QuickAddDialog> {
  final _name = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = widget.type ? 'Asset Type name is required.' : 'Category name is required.');
      return;
    }
    if (widget.type && (widget.categoryId ?? '').isEmpty) {
      setState(() => _error = 'Select a category first.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = ref.read(assetCatalogueApiProvider);
      final created = widget.type ? await api.addType(name, widget.categoryId!) : await api.addCategory(name);
      if (mounted) Navigator.of(context).pop(created);
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = assetError(e, widget.type ? 'Failed to add asset type.' : 'Failed to add category.').message);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c, width: w));
    return AlertDialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(widget.type ? 'Add Asset Type' : 'Add Category',
          style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, fontSize: 16)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_error != null) _errorBox(_error!, 'asset-quick-add-error'),
          if (widget.type)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('Category: ${widget.categoryName}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
            ),
          Text(widget.type ? 'Asset Type Name *' : 'Category Name *',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            key: const Key('asset-quick-add-name'),
            controller: _name,
            autofocus: true,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              filled: true,
              fillColor: AppColors.surface,
              border: border(AppColors.border),
              enabledBorder: border(AppColors.border),
              focusedBorder: border(AppColors.primary, 1.5),
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('asset-quick-add-submit'),
          onPressed: _saving ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: Text(_saving ? 'Adding…' : (widget.type ? 'Add Asset Type' : 'Add Category')),
        ),
      ],
    );
  }
}

// ── Delete ────────────────────────────────────────────────────────────────────

class _DeleteAssetDialog extends ConsumerStatefulWidget {
  const _DeleteAssetDialog({required this.asset});
  final CatalogueAsset asset;

  @override
  ConsumerState<_DeleteAssetDialog> createState() => _DeleteAssetDialogState();
}

class _DeleteAssetDialogState extends ConsumerState<_DeleteAssetDialog> {
  bool _deleting = false;
  String? _error;

  Future<void> _confirm() async {
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ref.read(assetCatalogueApiProvider).delete(widget.asset.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = assetError(e, 'Failed to delete asset.').message);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(Icons.delete_outline, color: AppColors.error),
        ),
        title: Text('Delete Asset?', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(
            'Are you sure you want to delete ${widget.asset.assetTag} — ${widget.asset.assetName}? '
            'This action cannot be undone.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          if (_error != null) ...[const SizedBox(height: 12), _errorBox(_error!, 'asset-delete-error')],
        ]),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: _deleting ? null : () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary, minimumSize: const Size(0, 44)),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('asset-delete-confirm'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error, minimumSize: const Size(0, 44)),
            onPressed: _deleting ? null : _confirm,
            child: Text(_deleting ? 'Deleting…' : 'Yes, Delete'),
          ),
        ],
      );
}

// ── Maintenance ───────────────────────────────────────────────────────────────

class _SendToMaintenanceSheet extends ConsumerStatefulWidget {
  const _SendToMaintenanceSheet({required this.asset});
  final CatalogueAsset asset;

  @override
  ConsumerState<_SendToMaintenanceSheet> createState() => _SendToMaintenanceSheetState();
}

class _SendToMaintenanceSheetState extends ConsumerState<_SendToMaintenanceSheet> {
  late String _start = _iso(DateTime.now());
  String _expected = '';
  final _issue = TextEditingController();
  final _vendor = TextEditingController();
  final _cost = TextEditingController();
  final _notes = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_issue, _vendor, _cost, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_issue.text.trim().isEmpty) {
      setState(() => _error = 'Issue / Reason is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(assetCatalogueApiProvider).sendToMaintenance(widget.asset.id, {
        'maintenance_start_date': _start,
        'issue': _issue.text,
        'expected_completion_date': _expected.isEmpty ? null : _expected,
        'vendor': _vendor.text,
        'estimated_cost': _cost.text.isEmpty ? null : _cost.text,
        'notes': _notes.text,
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = assetError(e, 'Failed to send asset to maintenance.').message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pick(bool start) async {
    final picked = await ref.read(assetDatePickerProvider)(context, DateTime.tryParse(start ? _start : _expected));
    if (picked != null && mounted) setState(() => start ? _start = _iso(picked) : _expected = _iso(picked));
  }

  @override
  Widget build(BuildContext context) => _MaintenanceScaffold(
        title: 'Send to Maintenance — ${widget.asset.assetTag}',
        error: _error,
        saving: _saving,
        submitLabel: _saving ? 'Sending…' : 'Send to Maintenance',
        onSubmit: _submit,
        children: [
          _dateTile('maint-start', 'Maintenance Start Date *', _start, () => _pick(true)),
          _field('maint-issue', 'Issue / Reason *', _issue, hint: "What's wrong with it?", maxLines: 3),
          _dateTile('maint-expected', 'Expected Completion Date (optional)', _expected, () => _pick(false)),
          _field('maint-vendor', 'Vendor / Service Center (optional)', _vendor),
          _field('maint-cost', 'Estimated Cost (optional)', _cost,
              keyboard: const TextInputType.numberWithOptions(decimal: true)),
          _field('maint-notes', 'Notes (optional)', _notes, maxLines: 2),
        ],
      );
}

class _CompleteMaintenanceSheet extends ConsumerStatefulWidget {
  const _CompleteMaintenanceSheet({required this.asset});
  final CatalogueAsset asset;

  @override
  ConsumerState<_CompleteMaintenanceSheet> createState() => _CompleteMaintenanceSheetState();
}

class _CompleteMaintenanceSheetState extends ConsumerState<_CompleteMaintenanceSheet> {
  late String _completed = _iso(DateTime.now());
  String _outcome = 'repaired';
  String _resulting = 'good';
  final _notes = TextEditingController();
  final _cost = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _notes.dispose();
    _cost.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final record = widget.asset.activeMaintenance;
    if (record == null) return;
    if (_notes.text.trim().isEmpty) {
      setState(() => _error = 'Repair/Maintenance notes are required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(assetCatalogueApiProvider).completeMaintenance(record.id, {
        'completed_date': _completed,
        'outcome': _outcome,
        'maintenance_notes': _notes.text,
        'actual_cost': _cost.text.isEmpty ? null : _cost.text,
        // Web: resulting_condition only for a repair (undefined → not sent).
        if (_outcome == 'repaired') 'resulting_condition': _resulting,
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = assetError(e, 'Failed to complete maintenance.').message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final issue = widget.asset.activeMaintenance?.issue ?? '';
    return _MaintenanceScaffold(
      title: 'Complete Maintenance — ${widget.asset.assetTag}',
      error: _error,
      saving: _saving,
      submitLabel: _saving ? 'Saving…' : 'Complete Maintenance',
      onSubmit: _submit,
      children: [
        if (issue.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text.rich(TextSpan(style: AppTextStyles.caption, children: [
              const TextSpan(text: 'Issue: '),
              TextSpan(text: issue, style: const TextStyle(fontWeight: FontWeight.w700)),
            ])),
          ),
        _dateTile('complete-date', 'Completed Date *', _completed, () async {
          final picked = await ref.read(assetDatePickerProvider)(context, DateTime.tryParse(_completed));
          if (picked != null && mounted) setState(() => _completed = _iso(picked));
        }),
        _dropdown('complete-outcome', 'Outcome *', _outcome, kMaintenanceOutcomes, (v) => setState(() => _outcome = v)),
        if (_outcome == 'repaired')
          _dropdown(
              'complete-condition',
              'Resulting Condition',
              _resulting,
              [
                for (final c in kAssetConditions)
                  if (c.$1 != 'damaged') c
              ],
              (v) => setState(() => _resulting = v)),
        _field('complete-notes', 'Repair / Maintenance Notes *', _notes, maxLines: 3),
        _field('complete-cost', 'Actual Cost (optional)', _cost,
            keyboard: const TextInputType.numberWithOptions(decimal: true)),
      ],
    );
  }
}

Widget _field(String key, String label, TextEditingController c,
        {String? hint, int maxLines = 1, TextInputType? keyboard}) =>
    _labelled(
      label,
      TextField(
        key: Key(key),
        controller: c,
        minLines: maxLines > 1 ? maxLines : 1,
        maxLines: maxLines,
        keyboardType: keyboard,
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
        decoration: _inputDeco(hint: hint),
      ),
    );

Widget _dateTile(String key, String label, String value, VoidCallback onTap) {
  final parsed = DateTime.tryParse(value);
  return _labelled(
    label,
    InkWell(
      key: Key(key),
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: InputDecorator(
        decoration: _inputDeco(suffix: Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textHint)),
        child: Text(
          parsed == null ? 'Select date' : formatEnInDate(parsed),
          style: AppTextStyles.bodySmall.copyWith(color: parsed == null ? AppColors.textHint : AppColors.textPrimary),
        ),
      ),
    ),
  );
}

Widget _dropdown(
        String key, String label, String value, List<(String, String)> options, ValueChanged<String> onChanged) =>
    _labelled(
      label,
      KeyedSubtree(
        key: Key(key),
        child: DropdownButtonFormField<String>(
          key: ValueKey('$key-$value'),
          initialValue: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
          decoration: _inputDeco(),
          items: [for (final (v, l) in options) DropdownMenuItem(value: v, child: Text(l))],
          onChanged: (v) => onChanged(v ?? value),
        ),
      ),
    );

class _MaintenanceScaffold extends StatelessWidget {
  const _MaintenanceScaffold({
    required this.title,
    required this.error,
    required this.saving,
    required this.submitLabel,
    required this.onSubmit,
    required this.children,
  });

  final String title;
  final String? error;
  final bool saving;
  final String submitLabel;
  final VoidCallback onSubmit;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    final cancel = OutlinedButton(
      onPressed: saving ? null : () => Navigator.of(context).pop(),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        foregroundColor: AppColors.textPrimary,
        side: BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      child: const Text('Cancel'),
    );
    final submit = FilledButton(
      key: const Key('maint-submit'),
      onPressed: saving ? null : onSubmit,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      child: Text(submitLabel, textAlign: TextAlign.center),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _sheetHeader(context, title, busy: saving),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (error != null) _errorBox(error!, 'maint-error'),
              ...children,
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: LayoutBuilder(builder: (context, c) {
            if (c.maxWidth < 320 || scale > 1.3) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [submit, const SizedBox(height: 8), cancel]);
            }
            return Row(children: [
              Expanded(child: cancel),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: submit),
            ]);
          }),
        ),
      ]),
    );
  }
}
