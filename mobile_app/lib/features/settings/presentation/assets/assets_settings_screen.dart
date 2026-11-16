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
import '../widgets/settings_app_bar.dart';
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

/// Web: a failed branch / master-data load just offers no options.
final assetBranchOptionsProvider = FutureProvider.autoDispose<List<NamedOption>>(
    (ref) => ref.read(assetCatalogueApiProvider).branches().catchError((_) => const <NamedOption>[]));
final assetCategoriesProvider = FutureProvider.autoDispose<List<NamedOption>>(
    (ref) => ref.read(assetCatalogueApiProvider).categories().catchError((_) => const <NamedOption>[]));
final assetTypesProvider = FutureProvider.autoDispose.family<List<NamedOption>, String?>((ref, categoryId) =>
    ref.read(assetCatalogueApiProvider).types(categoryId).catchError((_) => const <NamedOption>[]));

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

  void _setQuery(AssetQuery q) => setState(() => _q = q);

  void _refresh() => ref.invalidate(assetCatalogueProvider);

  /// Web onImported / onAssigned: the list (and, after an assignment, any
  /// open employee asset lists) reload when something was saved.
  Future<void> _bulk(AssetBulkKind kind) async {
    final changed = await showAssetBulkSheet(context, kind);
    if (!changed || !mounted) return;
    _refresh();
    if (kind == AssetBulkKind.assign) ref.invalidate(employeeAssetsProvider);
  }

  Future<void> _openForm(CatalogueAsset? editing) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AssetFormSheet(editing: editing),
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
      builder: (_) => complete ? _CompleteMaintenanceSheet(asset: a) : _SendToMaintenanceSheet(asset: a),
    );
    if (done == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final canCreate = _has(user, 'assets.create');
    final canEdit = _has(user, 'assets.edit');
    final canDelete = _has(user, 'assets.delete');
    final async = ref.watch(assetCatalogueProvider(_q));
    final branches = ref.watch(assetBranchOptionsProvider).valueOrNull ?? const <NamedOption>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SettingsAppBar(title: 'Asset Management'),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              key: const Key('asset-add'),
              onPressed: () => _openForm(null),
              icon: const Icon(Icons.add),
              label: const Text('Add Asset'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(assetCatalogueProvider(_q).future).then((_) {}, onError: (_) {}),
        child: ListView(
          key: const Key('asset-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            Text("Track company equipment and who it's assigned to", style: AppTextStyles.bodySecondary),
            // Web page actions: Bulk Assign (assets.edit), Bulk Import (assets.create).
            if (canEdit || canCreate)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(spacing: 8, runSpacing: 6, children: [
                  if (canEdit)
                    OutlinedButton.icon(
                      key: const Key('asset-bulk-assign'),
                      onPressed: () => _bulk(AssetBulkKind.assign),
                      icon: const Icon(Icons.group_add_outlined, size: 16),
                      label: const Text('Bulk Assign'),
                    ),
                  if (canCreate)
                    OutlinedButton.icon(
                      key: const Key('asset-bulk-import'),
                      onPressed: () => _bulk(AssetBulkKind.import),
                      icon: const Icon(Icons.upload_file, size: 16),
                      label: const Text('Bulk Import'),
                    ),
                ]),
              ),
            const SizedBox(height: 12),
            _Filters(query: _q, branches: branches, onChanged: _setQuery),
            const SizedBox(height: 12),
            ...async.when(
              loading: () => [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              ],
              error: (e, _) => [
                Padding(
                  key: const Key('asset-load-error'),
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(children: [
                    Text(assetError(e, "Couldn't load assets.").message,
                        textAlign: TextAlign.center, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
                    TextButton(key: const Key('asset-retry'), onPressed: _refresh, child: const Text('Retry')),
                  ]),
                ),
              ],
              data: (page) => page.results.isEmpty
                  ? [
                      Padding(
                        key: const Key('asset-empty'),
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(children: [
                          Icon(Icons.inventory_2_outlined, size: 32, color: AppColors.textHint),
                          const SizedBox(height: 8),
                          Text('No assets found.', style: AppTextStyles.bodySecondary),
                        ]),
                      ),
                    ]
                  : [
                      for (final a in page.results)
                        _AssetCard(
                          asset: a,
                          canEdit: canEdit,
                          canDelete: canDelete,
                          onEdit: () => _openForm(a),
                          onDelete: () => _delete(a),
                          onSendToMaintenance: () => _maintenance(a, complete: false),
                          onCompleteMaintenance: () => _maintenance(a, complete: true),
                        ),
                      if (page.totalPages > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            TextButton.icon(
                              key: const Key('asset-prev'),
                              onPressed: _q.page <= 1
                                  ? null
                                  : () => _setQuery((
                                        search: _q.search,
                                        status: _q.status,
                                        category: _q.category,
                                        assetType: _q.assetType,
                                        branch: _q.branch,
                                        page: _q.page - 1
                                      )),
                              icon: const Icon(Icons.chevron_left),
                              label: const Text('Prev'),
                            ),
                            Text('Page ${page.page} of ${page.totalPages}',
                                key: const Key('asset-page'), style: AppTextStyles.caption),
                            TextButton.icon(
                              key: const Key('asset-next'),
                              onPressed: _q.page >= page.totalPages
                                  ? null
                                  : () => _setQuery((
                                        search: _q.search,
                                        status: _q.status,
                                        category: _q.category,
                                        assetType: _q.assetType,
                                        branch: _q.branch,
                                        page: _q.page + 1
                                      )),
                              icon: const Icon(Icons.chevron_right),
                              label: const Text('Next'),
                            ),
                          ]),
                        ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filters (web: search, status, category, asset type, branch; each resets to page 1) ──

class _Filters extends StatefulWidget {
  const _Filters({required this.query, required this.branches, required this.onChanged});
  final AssetQuery query;
  final List<NamedOption> branches;
  final ValueChanged<AssetQuery> onChanged;

  @override
  State<_Filters> createState() => _FiltersState();
}

class _FiltersState extends State<_Filters> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _emit({String? search, String? status, String? category, String? assetType, String? branch}) {
    final q = widget.query;
    widget.onChanged((
      search: search ?? q.search,
      status: status ?? q.status,
      category: category ?? q.category,
      assetType: assetType ?? q.assetType,
      branch: branch ?? q.branch,
      page: 1,
    ));
  }

  /// Typed filters are applied after a short pause (web refetches per key).
  void _typed(void Function() apply) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), apply);
  }

  InputDecoration _dec(String hint, {IconData? icon}) => InputDecoration(
        hintText: hint,
        isDense: true,
        prefixIcon: icon == null ? null : Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      );

  @override
  Widget build(BuildContext context) {
    final q = widget.query;
    return Column(children: [
      TextField(
        key: const Key('asset-search'),
        decoration: _dec('Search tag, name, serial number…', icon: Icons.search),
        onChanged: (v) => _typed(() => _emit(search: v.trim())),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            key: const Key('asset-filter-status'),
            initialValue: q.status,
            isExpanded: true,
            decoration: _dec(''),
            items: [
              const DropdownMenuItem(value: '', child: Text('All Statuses')),
              for (final (v, l) in kAssetStatuses) DropdownMenuItem(value: v, child: Text(l)),
            ],
            onChanged: (v) => _emit(status: v ?? ''),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<String>(
            key: ValueKey('asset-filter-branch-${widget.branches.length}'),
            initialValue: widget.branches.any((b) => b.id == q.branch) ? q.branch : '',
            isExpanded: true,
            decoration: _dec(''),
            items: [
              const DropdownMenuItem(value: '', child: Text('All Branches')),
              for (final b in widget.branches) DropdownMenuItem(value: b.id, child: Text(b.name)),
            ],
            onChanged: (v) => _emit(branch: v ?? ''),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: TextField(
            key: const Key('asset-filter-category'),
            decoration: _dec('Category'),
            onChanged: (v) => _typed(() => _emit(category: v.trim())),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            key: const Key('asset-filter-type'),
            decoration: _dec('Asset Type'),
            onChanged: (v) => _typed(() => _emit(assetType: v.trim())),
          ),
        ),
      ]),
    ]);
  }
}

// ── List row ──────────────────────────────────────────────────────────────────

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

  @override
  Widget build(BuildContext context) {
    final a = asset;
    final caption = AppTextStyles.caption.copyWith(fontSize: 12);
    return Container(
      key: Key('asset-row-${a.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(a.assetTag,
                style: AppTextStyles.labelSmall.copyWith(fontFamily: 'monospace', fontWeight: FontWeight.w700)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration:
                BoxDecoration(color: AppColors.info.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Text(a.statusDisplay,
                key: Key('asset-status-${a.id}'),
                style: AppTextStyles.caption.copyWith(color: AppColors.info, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 2),
        Text(a.assetName, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
        Text('${a.categoryLabel} · ${a.typeLabel}', style: caption),
        Text('${a.branchName} · Condition: ${a.conditionDisplay}', style: caption),
        if (canEdit || canDelete)
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (canEdit && a.status == 'damaged')
              IconButton(
                key: Key('asset-maintenance-${a.id}'),
                tooltip: 'Send to Maintenance',
                onPressed: onSendToMaintenance,
                icon: const Icon(Icons.build_outlined, size: 20),
              ),
            if (canEdit && a.status == 'under_repair' && a.activeMaintenance != null)
              IconButton(
                key: Key('asset-complete-${a.id}'),
                tooltip: 'Complete Maintenance',
                onPressed: onCompleteMaintenance,
                icon: const Icon(Icons.check_circle_outline, size: 20),
              ),
            if (canEdit)
              IconButton(
                key: Key('asset-edit-${a.id}'),
                tooltip: 'Edit',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 20),
              ),
            if (canDelete)
              IconButton(
                key: Key('asset-delete-${a.id}'),
                tooltip: 'Delete',
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, size: 20, color: AppColors.error),
              ),
          ]),
      ]),
    );
  }
}

Widget _errorBox(String text, String key) => Container(
      key: Key(key),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
    );

Widget _sheetHeader(BuildContext context, String title, {bool busy = false}) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
      child: Row(children: [
        Expanded(child: Text(title, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, fontSize: 16))),
        IconButton(
            tooltip: 'Close',
            onPressed: busy ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close)),
      ]),
    );

// ── Add / Edit ────────────────────────────────────────────────────────────────

class AssetFormSheet extends ConsumerStatefulWidget {
  const AssetFormSheet({super.key, this.editing});
  final CatalogueAsset? editing;

  @override
  ConsumerState<AssetFormSheet> createState() => _AssetFormSheetState();
}

class _AssetFormSheetState extends ConsumerState<AssetFormSheet> {
  late final Map<String, String> _form = widget.editing == null ? blankAssetForm() : assetFormFrom(widget.editing!);
  final _ctrls = <String, TextEditingController>{};
  Map<String, String> _errors = {};
  String? _saveError;
  bool _saving = false;

  TextEditingController _c(String f) => _ctrls.putIfAbsent(f, () => TextEditingController(text: _form[f]));

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
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

  Future<void> _save() async {
    if (_saving) return;
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

  Widget _text(String f, String label, {String? hint, TextInputType? keyboard, int maxLines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          key: Key('asset-field-$f'),
          controller: _c(f),
          keyboardType: keyboard,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            isDense: true,
            errorText: _errors[f],
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => _set(f, v),
        ),
      );

  Widget _date(String f, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          key: Key('asset-field-$f'),
          onTap: () async {
            final picked = await ref.read(assetDatePickerProvider)(context, DateTime.tryParse(_form[f] ?? ''));
            if (picked != null && mounted) _set(f, _iso(picked));
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              isDense: true,
              errorText: _errors[f],
              border: const OutlineInputBorder(),
              suffixIcon: (_form[f] ?? '').isEmpty
                  ? const Icon(Icons.event, size: 18)
                  : IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => _set(f, '')),
            ),
            child: Text((_form[f] ?? '').isEmpty ? '—' : _form[f]!, style: AppTextStyles.bodySmall),
          ),
        ),
      );

  Widget _select(String key, String label, String value, List<(String, String)> options,
          {required ValueChanged<String>? onChanged, String? error, String placeholder = '', Widget? trailing}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: KeyedSubtree(
              key: Key(key),
              child: DropdownButtonFormField<String>(
                key: ValueKey('$key-$value-${options.length}'),
                initialValue: options.any((o) => o.$1 == value) ? value : '',
                isExpanded: true,
                decoration: InputDecoration(
                    labelText: label, isDense: true, errorText: error, border: const OutlineInputBorder()),
                items: [
                  if (placeholder.isNotEmpty) DropdownMenuItem(value: '', child: Text(placeholder)),
                  for (final (v, l) in options) DropdownMenuItem(value: v, child: Text(l)),
                ],
                onChanged: onChanged == null ? null : (v) => onChanged(v ?? ''),
              ),
            ),
          ),
          if (trailing != null) trailing,
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing;
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final canQuickAdd = _has(user, 'assets.create');
    final categories = ref.watch(assetCategoriesProvider).valueOrNull ?? const <NamedOption>[];
    final category = _form['category']!;
    final selectedCategoryId = categories.where((c) => c.name == category).firstOrNull?.id;
    final types = ref.watch(assetTypesProvider(selectedCategoryId)).valueOrNull ?? const <NamedOption>[];
    final branches = ref.watch(assetBranchOptionsProvider).valueOrNull ?? const <NamedOption>[];
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

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _sheetHeader(context, editing == null ? 'Add Asset' : 'Edit: ${editing.assetTag}', busy: _saving),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (_saveError != null) _errorBox(_saveError!, 'asset-save-error'),
              if (editing != null) _AssignmentDetails(asset: editing),
              _text('asset_tag', 'Asset Tag *', hint: 'e.g. LAP-001'),
              _text('asset_name', 'Asset Name *', hint: 'e.g. Dell Latitude 5420'),
              _select('asset-field-category', 'Category *', category, categoryOptions,
                  placeholder: 'Select category…',
                  error: _errors['category'],
                  onChanged: _changeCategory,
                  trailing: canQuickAdd
                      ? IconButton(
                          key: const Key('asset-add-category'),
                          tooltip: 'Add Category',
                          onPressed: () => _quickAdd(type: false, categoryId: null),
                          icon: const Icon(Icons.add))
                      : null),
              if (category == kAssetOther) _text('category_other', 'Other category — enter a name'),
              _select('asset-field-asset_type', 'Asset Type *', type, typeOptions,
                  placeholder: category.isEmpty ? 'Select a category first' : 'Select asset type…',
                  error: _errors['asset_type'],
                  onChanged: category.isEmpty ? null : _changeType,
                  trailing: canQuickAdd
                      ? IconButton(
                          key: const Key('asset-add-type'),
                          tooltip: 'Add Asset Type',
                          onPressed: selectedCategoryId == null
                              ? null
                              : () => _quickAdd(type: true, categoryId: selectedCategoryId),
                          icon: const Icon(Icons.add))
                      : null),
              if (type == kAssetOther) _text('asset_type_other', 'Other asset type — enter a name'),
              _text('brand', 'Brand'),
              _text('model', 'Model'),
              _text('serial_number', 'Serial Number'),
              _select('asset-field-branch', 'Branch *', _form['branch']!, [for (final b in branches) (b.id, b.name)],
                  placeholder: 'Select branch…', error: _errors['branch'], onChanged: (v) => _set('branch', v)),
              _date('purchase_date', 'Purchase Date'),
              _text('purchase_price', 'Purchase Price', keyboard: const TextInputType.numberWithOptions(decimal: true)),
              _text('vendor', 'Vendor'),
              _select('asset-field-condition', 'Condition', _form['condition']!, kAssetConditions,
                  onChanged: (v) => _set('condition', v)),
              _date('warranty_start_date', 'Warranty Start'),
              _date('warranty_end_date', 'Warranty End'),
              _text('description', 'Description / Remarks', maxLines: 3),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const Key('asset-save'),
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : (editing == null ? 'Create Asset' : 'Save Changes')),
              ),
            ),
          ]),
        ),
      ]),
    );
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
    Widget item(String label, String value) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            SizedBox(width: 120, child: Text(label, style: small)),
            Expanded(child: Text(value, style: AppTextStyles.bodySmall)),
          ]),
        );
    return Container(
      key: const Key('asset-assignment-details'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.how_to_reg_outlined, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(child: Text('Assignment Details', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600))),
          Text(
            _loading ? 'Loading…' : (view is HolderAssigned ? view.status : 'Not assigned'),
            key: const Key('asset-holder-badge'),
            style: small,
          ),
        ]),
        switch (view) {
          HolderAssigned() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              item('Assigned to', view.employee),
              item('Employee ID', view.code ?? '—'),
              item('Assigned on', fmtAssetDate(view.assignedDate)),
              item('Expected return', view.expectedReturn != null ? fmtAssetDate(view.expectedReturn!) : 'Not set'),
            ]),
          HolderNone() => Padding(padding: const EdgeInsets.only(top: 6), child: Text(view.message, style: small)),
        },
        if (_failed)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text("Couldn't refresh the assignment; showing the details from the list.",
                key: const Key('asset-holder-stale'), style: small.copyWith(color: AppColors.warning)),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text("Read-only. Assign or return assets from the employee's profile → Assets.", style: small),
        ),
      ]),
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
    return AlertDialog(
      title: Text(widget.type ? 'Add Asset Type' : 'Add Category'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_error != null) _errorBox(_error!, 'asset-quick-add-error'),
        if (widget.type) Text('Category: ${widget.categoryName}', style: AppTextStyles.caption),
        TextField(
          key: const Key('asset-quick-add-name'),
          controller: _name,
          autofocus: true,
          decoration: InputDecoration(labelText: widget.type ? 'Asset Type Name *' : 'Category Name *'),
        ),
      ]),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          key: const Key('asset-quick-add-submit'),
          onPressed: _saving ? null : _submit,
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
        title: const Text('Delete Asset?'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(
            'Are you sure you want to delete ${widget.asset.assetTag} — ${widget.asset.assetName}? '
            'This action cannot be undone.',
          ),
          if (_error != null) ...[const SizedBox(height: 12), _errorBox(_error!, 'asset-delete-error')],
        ]),
        actions: [
          TextButton(onPressed: _deleting ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            key: const Key('asset-delete-confirm'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
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
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: Key(key),
        controller: c,
        maxLines: maxLines,
        keyboardType: keyboard,
        decoration:
            InputDecoration(labelText: label, hintText: hint, isDense: true, border: const OutlineInputBorder()),
      ),
    );

Widget _dateTile(String key, String label, String value, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        key: Key(key),
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
              labelText: label,
              isDense: true,
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(Icons.event, size: 18)),
          child: Text(value.isEmpty ? '—' : value, style: AppTextStyles.bodySmall),
        ),
      ),
    );

Widget _dropdown(
        String key, String label, String value, List<(String, String)> options, ValueChanged<String> onChanged) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: KeyedSubtree(
        key: Key(key),
        child: DropdownButtonFormField<String>(
          key: ValueKey('$key-$value'),
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
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
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _sheetHeader(context, title, busy: saving),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (error != null) _errorBox(error!, 'maint-error'),
                ...children,
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Row(children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                    key: const Key('maint-submit'), onPressed: saving ? null : onSubmit, child: Text(submitLabel)),
              ),
            ]),
          ),
        ]),
      );
}
