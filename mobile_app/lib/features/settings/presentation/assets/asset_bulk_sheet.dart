import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/asset_catalogue.dart';
import '../leave_policy/monthly_leave/monthly_leave_providers.dart'
    show PickedFile, monthlyImportFilePickerProvider, monthlySampleSaverProvider;
import 'assets_settings_screen.dart' show assetCatalogueApiProvider;

// Settings → Assets → Bulk Import / Bulk Assign — web
// _components/BulkImportAssetsModal.tsx, BulkAssignAssetsModal.tsx,
// lib/assetImport.ts, lib/assetAssignImport.ts over backend
// views_import.py / views_assign_import.py:
//  - POST /assets/import/ (assets.create) and /assets/assignments/import/
//    (assets.edit), multipart `file` (.csv / .xlsx, ≤ 5 MB, ≤ 1000 rows),
//    `dry_run=true` for the preview (nothing saved). The confirm request
//    re-uploads the file and the server checks every row again.
//  - GET …/sample/?format=csv|xlsx — the template.
//  - Results: rows with a status and errors, counts (preview) or summary
//    (done), and error_report_csv (base64 CSV, or null).
// Assets already assigned are reported, never reassigned (server).

/// Picks a .csv / .xlsx file (tests override it).
final assetBulkFilePickerProvider =
    Provider<Future<PickedFile?> Function()>((ref) => ref.watch(monthlyImportFilePickerProvider));

/// Saves a file; returns where, or null when cancelled (tests override it).
final assetBulkFileSaverProvider = Provider<Future<String?> Function(String fileName, Uint8List bytes)>(
    (ref) => ref.watch(monthlySampleSaverProvider));

const kAssetImportMaxBytes = 5 * 1024 * 1024;

/// Web checkImportFile: null when acceptable, else the reason.
String? checkAssetImportFile(String name, int size) {
  final n = name.toLowerCase();
  if (!n.endsWith('.csv') && !n.endsWith('.xlsx')) return 'Upload a .csv or .xlsx file.';
  if (size > kAssetImportMaxBytes) return 'File must not exceed 5 MB.';
  if (size == 0) return 'The file is empty.';
  return null;
}

/// Web errorText: "Column: message · …".
String assetImportErrorText(Object? errors) => [
      for (final e in (errors is List ? errors : const []))
        if (e is Map)
          ('${e['column'] ?? ''}'.isNotEmpty ? '${e['column']}: ${e['message'] ?? ''}' : '${e['message'] ?? ''}'),
    ].join(' · ');

/// (header, required) — mirrors services_import.COLUMNS / services_assign_import.COLUMNS.
const kAssetImportColumns = <(String, bool)>[
  ('Asset Tag', true), ('Asset Name', true), ('Category', true), ('Category Other', false), //
  ('Asset Type', true), ('Asset Type Other', false), ('Branch', true), ('Brand', false), ('Model', false), //
  ('Serial Number', false), ('Purchase Date', false), ('Purchase Price', false), ('Vendor', false), //
  ('Warranty Start Date', false), ('Warranty End Date', false), ('Condition', false), ('Description', false),
];
const kAssetAssignColumns = <(String, bool)>[
  ('Asset Tag', true), ('Employee ID', true), ('Assigned Date', true), ('Condition at Assignment', true), //
  ('Expected Return Date', false), ('Remarks', false),
];

enum AssetBulkKind { import, assign }

class _Cfg {
  const _Cfg(this.kind);
  final AssetBulkKind kind;
  bool get assign => kind == AssetBulkKind.assign;
  String get title => assign ? 'Bulk Assign Assets' : 'Bulk Import Assets';
  String get path => assign ? ApiConstants.assetAssignImport : ApiConstants.assetImport;
  String get samplePath => assign ? ApiConstants.assetAssignImportSample : ApiConstants.assetImportSample;
  String sampleName(String f) => assign ? 'asset_assignment_sample.$f' : 'asset_import_sample.$f';
  String get reportName => assign ? 'asset_assignment_errors.csv' : 'asset_import_errors.csv';
  List<(String, bool)> get columns => assign ? kAssetAssignColumns : kAssetImportColumns;
  String get intro => assign
      ? 'Upload a CSV or Excel (.xlsx) file with one existing asset and one employee per row (up to 1000 rows, 5 MB). '
          'Only Available assets can be assigned; assets that are already assigned are reported, never reassigned. '
          'Nothing is assigned until you confirm.'
      : 'Upload a CSV or Excel (.xlsx) file with one asset per row (up to 1000 rows, 5 MB). Each row is checked '
          'with the same rules as Add Asset; nothing is saved until you confirm. New assets start as Available.';
  String get note => assign
      ? 'Condition is new, good, fair or damaged; dates as YYYY-MM-DD.'
      : 'Branch is a branch code or name; dates as YYYY-MM-DD.';
  String get doneFallback => assign ? 'Assignment failed.' : 'Import failed.';
}

/// Opens the sheet. Returns true when anything was created / assigned.
Future<bool> showAssetBulkSheet(BuildContext context, AssetBulkKind kind) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      builder: (_) => AssetBulkSheet(kind: kind),
    ) ??
    false;

class AssetBulkSheet extends ConsumerStatefulWidget {
  const AssetBulkSheet({super.key, required this.kind});
  final AssetBulkKind kind;

  @override
  ConsumerState<AssetBulkSheet> createState() => _AssetBulkSheetState();
}

class _AssetBulkSheetState extends ConsumerState<AssetBulkSheet> {
  late final _cfg = _Cfg(widget.kind);
  PickedFile? _file;
  Map<String, dynamic>? _preview;
  Map<String, dynamic>? _result;
  String? _busy; // preview | send
  String? _sampleDl;
  String? _error;
  bool _confirming = false; // Bulk Assign only
  bool _changed = false; // anything created / assigned

  int _n(Map<String, dynamic>? m, String k) => (m?[k] as num?)?.toInt() ?? 0;
  Map<String, dynamic>? get _counts => (_preview?['counts'] as Map?)?.cast<String, dynamic>();
  Map<String, dynamic>? get _summary => (_result?['summary'] as Map?)?.cast<String, dynamic>();
  int get _ready => _n(_counts, 'ready');

  void _reset() => setState(() {
        _file = null;
        _preview = null;
        _result = null;
        _error = null;
        _confirming = false;
      });

  Future<void> _pick() async {
    if (_busy != null) return;
    final f = await ref.read(assetBulkFilePickerProvider)();
    if (!mounted || f == null) return;
    setState(() {
      _preview = null;
      _result = null;
      _error = null;
      _confirming = false;
      final problem = checkAssetImportFile(f.name, f.size);
      if (problem != null) {
        _error = problem;
        _file = null;
      } else {
        _file = f;
      }
    });
  }

  Future<void> _sample(String format) async {
    if (_sampleDl != null) return;
    setState(() => _sampleDl = format);
    try {
      final bytes = await ref.read(assetCatalogueApiProvider).sample(_cfg.samplePath, format);
      await ref.read(assetBulkFileSaverProvider)(_cfg.sampleName(format), Uint8List.fromList(bytes));
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to download the sample.');
    } finally {
      if (mounted) setState(() => _sampleDl = null);
    }
  }

  Future<void> _send(bool dryRun) async {
    final f = _file;
    if (f == null || _busy != null) return;
    setState(() {
      _busy = dryRun ? 'preview' : 'send';
      _error = null;
    });
    try {
      final data = await ref
          .read(assetCatalogueApiProvider)
          .bulkUpload(_cfg.path, fileName: f.name, bytes: f.bytes, dryRun: dryRun);
      if (!mounted) return;
      setState(() {
        if (dryRun) {
          _preview = data;
        } else {
          _result = data;
          _preview = null;
          _confirming = false;
          final summary = (data['summary'] as Map?)?.cast<String, dynamic>();
          if (_n(summary, _cfg.assign ? 'assigned' : 'created') > 0) _changed = true;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _confirming = false;
        _error = assetError(e, dryRun ? 'Could not check the file.' : _cfg.doneFallback).message;
      });
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _downloadReport(String b64) async {
    try {
      await ref.read(assetBulkFileSaverProvider)(_cfg.reportName, base64Decode(b64));
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't save the error report.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = (_result?['error_report_csv'] ?? _preview?['error_report_csv']) as String?;
    final small = AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.textSecondary);
    return PopScope(
      canPop: _busy == null,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
            child: Row(children: [
              Expanded(
                child: Text(_cfg.title, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              IconButton(
                key: const Key('bulk-close'),
                tooltip: 'Close',
                onPressed: _busy != null ? null : () => Navigator.of(context).pop(_changed),
                icon: const Icon(Icons.close),
              ),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (_preview == null && _result == null) ...[
                  Text(_cfg.intro, style: small),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(style: small, children: [
                      const TextSpan(text: 'Required columns: ', style: TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(text: '${_cfg.columns.where((c) => c.$2).map((c) => c.$1).join(', ')}. '),
                      const TextSpan(text: 'Optional: ', style: TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(text: '${_cfg.columns.where((c) => !c.$2).map((c) => c.$1).join(', ')}. '),
                      TextSpan(text: _cfg.note),
                    ]),
                    key: const Key('bulk-columns'),
                  ),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    for (final (f, label) in [('csv', 'Download Sample CSV'), ('xlsx', 'Download Sample Excel')])
                      OutlinedButton.icon(
                        key: Key('bulk-sample-$f'),
                        onPressed: _sampleDl != null ? null : () => _sample(f),
                        icon: const Icon(Icons.download, size: 16),
                        label: Text(_sampleDl == f ? 'Downloading…' : label),
                      ),
                    OutlinedButton.icon(
                      key: const Key('bulk-pick'),
                      onPressed: _busy != null ? null : _pick,
                      icon: const Icon(Icons.upload_file, size: 16),
                      label: Text(_file != null ? 'Choose another file' : 'Choose CSV / Excel file'),
                    ),
                  ]),
                  if (_file != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_file!.name, key: const Key('bulk-file-name'), style: AppTextStyles.bodySmall),
                    ),
                ],
                if (_error != null) _banner(_error!, AppColors.error, 'bulk-error'),
                if (_preview != null) ...[
                  _banner(
                    _cfg.assign
                        ? 'Preview (nothing assigned yet): $_ready ready, ${_n(_counts, 'already_assigned')} already assigned, '
                            '${_n(_counts, 'error')} with errors. Only ready rows are assigned.'
                        : 'Preview (nothing saved yet): $_ready ready, ${_n(_counts, 'duplicate')} duplicate, '
                            '${_n(_counts, 'error')} with errors. Only ready rows are imported.',
                    _n(_counts, 'error') > 0 ? AppColors.warning : AppColors.info,
                    'bulk-preview-summary',
                  ),
                  if (_confirming)
                    _banner(
                      'Assign $_ready asset(s) to the employees listed as Ready? Each row is checked again before saving; '
                          'anything that changed since this preview is reported instead of assigned.',
                      AppColors.warning,
                      'bulk-confirm-note',
                    ),
                  _rows((_preview!['rows'] as List?) ?? const []),
                ],
                if (_result != null) ...[
                  _banner(
                    _cfg.assign
                        ? 'Finished: ${_n(_summary, 'assigned')} assigned, ${_n(_summary, 'already_assigned')} already assigned, '
                            '${_n(_summary, 'failed')} failed, ${_n(_summary, 'skipped')} skipped (of ${_n(_summary, 'total')} rows).'
                        : 'Import finished: ${_n(_summary, 'created')} created, ${_n(_summary, 'duplicate')} duplicate, '
                            '${_n(_summary, 'failed')} failed, ${_n(_summary, 'skipped')} skipped (of ${_n(_summary, 'total')} rows).',
                    _n(_summary, 'failed') > 0 ? AppColors.warning : AppColors.success,
                    'bulk-result-summary',
                  ),
                  _rows((_result!['rows'] as List?) ?? const []),
                ],
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 6, children: [
              if (report != null)
                TextButton.icon(
                  key: const Key('bulk-report'),
                  onPressed: _busy != null ? null : () => _downloadReport(report),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Download error report'),
                ),
              ..._footer(),
            ]),
          ),
        ]),
      ),
    );
  }

  List<Widget> _footer() {
    final busy = _busy != null;
    if (_result != null) {
      return [
        OutlinedButton(
            key: const Key('bulk-another'),
            onPressed: _reset,
            child: Text(_cfg.assign ? 'Assign another file' : 'Import another file')),
        FilledButton(
            key: const Key('bulk-done'),
            onPressed: () => Navigator.of(context).pop(_changed),
            child: const Text('Done')),
      ];
    }
    if (_preview != null && _confirming) {
      return [
        OutlinedButton(
            key: const Key('bulk-back'),
            onPressed: busy ? null : () => setState(() => _confirming = false),
            child: const Text('Back')),
        FilledButton(
          key: const Key('bulk-send'),
          onPressed: busy ? null : () => _send(false),
          child: Text(_busy == 'send' ? 'Assigning…' : 'Yes, assign $_ready asset(s)'),
        ),
      ];
    }
    if (_preview != null) {
      return [
        OutlinedButton(key: const Key('bulk-cancel'), onPressed: busy ? null : _reset, child: const Text('Cancel')),
        FilledButton(
          key: const Key('bulk-send'),
          onPressed: busy || _ready == 0
              ? null
              : (_cfg.assign ? () => setState(() => _confirming = true) : () => _send(false)),
          child: Text(
              _cfg.assign ? 'Assign $_ready asset(s)…' : (_busy == 'send' ? 'Importing…' : 'Import $_ready asset(s)')),
        ),
      ];
    }
    return [
      OutlinedButton(
          key: const Key('bulk-cancel'),
          onPressed: busy ? null : () => Navigator.of(context).pop(_changed),
          child: const Text('Cancel')),
      FilledButton(
        key: const Key('bulk-preview'),
        onPressed: _file == null || busy ? null : () => _send(true),
        child: Text(_busy == 'preview' ? 'Checking…' : 'Preview'),
      ),
    ];
  }

  Widget _banner(String text, Color color, String key) => Container(
        key: Key(key),
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: AppTextStyles.caption.copyWith(color: color)),
      );

  Widget _rows(List rows) {
    (String, Color) status(String s) => switch (s) {
          'ready' => ('Ready', AppColors.success),
          'created' => ('Created', AppColors.success),
          'assigned' => ('Assigned', AppColors.success),
          'duplicate' => ('Duplicate', AppColors.warning),
          'already_assigned' => ('Already assigned', AppColors.warning),
          'error' => ('Error', AppColors.error),
          _ => (s, AppColors.textSecondary),
        };
    String or(Object? v) => '${v ?? ''}'.isEmpty ? '—' : '$v';
    return Column(key: const Key('bulk-rows'), children: [
      for (final r in rows)
        if (r is Map)
          Container(
            key: Key('bulk-row-${r['row']}'),
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('Row ${r['row']}', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(status('${r['status']}').$1,
                    key: Key('bulk-row-status-${r['row']}'),
                    style: AppTextStyles.caption
                        .copyWith(color: status('${r['status']}').$2, fontWeight: FontWeight.w700)),
              ]),
              if (_cfg.assign) ...[
                // Web mappingText: "Asset name (TAG)" → "Employee name (ID)".
                Text(
                    '${'${r['asset_name'] ?? ''}'.isNotEmpty ? '${r['asset_name']} (${r['asset_tag']})' : or(r['asset_tag'])} → '
                    '${'${r['employee_name'] ?? ''}'.isNotEmpty ? '${r['employee_name']} (${r['employee_id']})' : or(r['employee_id'])}',
                    style: AppTextStyles.bodySmall),
              ] else
                Text('${or(r['asset_tag'])} · ${or(r['asset_name'])} · ${or(r['branch'])}',
                    style: AppTextStyles.bodySmall),
              if (assetImportErrorText(r['errors']).isNotEmpty)
                Text(assetImportErrorText(r['errors']),
                    key: Key('bulk-row-errors-${r['row']}'), style: AppTextStyles.caption.copyWith(fontSize: 12)),
            ]),
          ),
    ]);
  }
}
