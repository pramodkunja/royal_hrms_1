import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/error/exceptions.dart';
import '../../data/datasources/document_remote_datasource.dart';
import '../../data/models/policy_ack_models.dart';
import '../../data/repositories/document_repository_impl.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/repositories/document_repository.dart';

final documentDataSourceProvider = Provider<DocumentRemoteDataSource>((ref) {
  return DocumentRemoteDataSource(ref.watch(dioProvider));
});

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepositoryImpl(ref.watch(documentDataSourceProvider));
});

// ── Stats ─────────────────────────────────────────────────────────────────────

final documentStatsProvider =
    AsyncNotifierProvider.autoDispose<DocumentStatsNotifier, DocumentStatsEntity>(
        DocumentStatsNotifier.new);

class DocumentStatsNotifier
    extends AutoDisposeAsyncNotifier<DocumentStatsEntity> {
  DocumentRepository get _repo => ref.read(documentRepositoryProvider);

  @override
  Future<DocumentStatsEntity> build() => _repo.getStats();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.getStats());
  }
}

// ── Document list ─────────────────────────────────────────────────────────────

final documentListProvider =
    AsyncNotifierProvider.autoDispose<DocumentListNotifier, List<DocumentEntity>>(
        DocumentListNotifier.new);

class DocumentListNotifier
    extends AutoDisposeAsyncNotifier<List<DocumentEntity>> {
  DocumentRepository get _repo => ref.read(documentRepositoryProvider);

  @override
  Future<List<DocumentEntity>> build() => _repo.getDocuments();

  Future<String?> upload({
    required String filePath,
    required String fileName,
    required String title,
    required String description,
    required String category,
    bool requiresAcknowledgement = false,
  }) async {
    try {
      final created = await _repo.createDocument(
        filePath: filePath,
        fileName: fileName,
        title: title,
        description: description,
        category: category,
        requiresAcknowledgement: requiresAcknowledgement,
      );
      state = AsyncData([created, ...state.valueOrNull ?? []]);
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> remove(int id) async {
    try {
      await _repo.deleteDocument(id);
      state = AsyncData(
        (state.valueOrNull ?? []).where((d) => d.id != id).toList(),
      );
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.getDocuments());
  }

  /// Swaps in a fresher copy of one document (after an acknowledgement,
  /// a requirement change, or reloading a newer version).
  void replace(DocumentEntity doc) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData([for (final d in current) d.id == doc.id ? doc : d]);
  }
}

// ── Policy acknowledgement ───────────────────────────────────────────────────

/// Documents the signed-in user still has to acknowledge.
final pendingAcknowledgementsProvider = FutureProvider.autoDispose<List<PendingAcknowledgement>>(
  (ref) => ref.read(documentRepositoryProvider).getPendingAcknowledgements(),
);

/// HR's report for one document (documents.edit).
final acknowledgementReportProvider = FutureProvider.autoDispose.family<AckReport, int>(
  (ref, id) => ref.read(documentRepositoryProvider).getAcknowledgementReport(id),
);

/// The outcome of acknowledging: the updated document, or the server's
/// refusal. On a version conflict (409) [document] is the reloaded current
/// version, which the employee must read and acknowledge again.
typedef AckOutcome = ({DocumentEntity? document, String? error, bool conflict});

class PolicyAckActions {
  PolicyAckActions(this._ref);
  final Ref _ref;
  DocumentRepository get _repo => _ref.read(documentRepositoryProvider);

  void _publish(DocumentEntity doc) {
    _ref.read(documentListProvider.notifier).replace(doc);
    _ref.invalidate(pendingAcknowledgementsProvider);
  }

  Future<AckOutcome> acknowledge(DocumentEntity doc) async {
    try {
      final at = await _repo.acknowledge(doc.id, doc.version);
      final updated = doc.copyWithAck(myAcknowledgedAt: at.isEmpty ? DateTime.now().toIso8601String() : at);
      _publish(updated);
      return (document: updated, error: null, conflict: false);
    } on AppException catch (e) {
      if (e.statusCode == 409) {
        // A newer file was uploaded: show the current version instead.
        DocumentEntity? fresh;
        try {
          fresh = await _repo.getDocument(doc.id);
          _publish(fresh);
        } catch (_) {
          fresh = null;
        }
        return (document: fresh, error: e.message, conflict: true);
      }
      return (document: null, error: userFriendlyMessage(e), conflict: false);
    } catch (e) {
      return (document: null, error: userFriendlyMessage(e), conflict: false);
    }
  }

  /// documents.edit: switch acknowledgement on or off for a document.
  Future<({DocumentEntity? document, String? error})> setRequired(DocumentEntity doc, bool value) async {
    try {
      final updated = await _repo.setRequiresAcknowledgement(doc.id, value);
      _publish(updated);
      _ref.invalidate(acknowledgementReportProvider(doc.id));
      return (document: updated, error: null);
    } catch (e) {
      return (document: null, error: userFriendlyMessage(e));
    }
  }

  Future<DocumentEntity> load(int id) => _repo.getDocument(id);
}

final policyAckActionsProvider = Provider<PolicyAckActions>((ref) => PolicyAckActions(ref));

// ── Filter / search state ─────────────────────────────────────────────────────

final documentFilterProvider =
    StateProvider.autoDispose<String>((ref) => 'all');

final documentSearchProvider =
    StateProvider.autoDispose<String>((ref) => '');

// ── Derived filtered list ─────────────────────────────────────────────────────

final filteredDocumentsProvider =
    Provider.autoDispose<List<DocumentEntity>>((ref) {
  final allDocs = ref.watch(documentListProvider).valueOrNull ?? [];
  final filter = ref.watch(documentFilterProvider);
  final search = ref.watch(documentSearchProvider).toLowerCase().trim();

  return allDocs.where((d) {
    final matchFilter = filter == 'all' || d.category == filter;
    final matchSearch = search.isEmpty ||
        d.title.toLowerCase().contains(search) ||
        d.uploadedByName.toLowerCase().contains(search) ||
        d.fileType.toLowerCase().contains(search);
    return matchFilter && matchSearch;
  }).toList();
});

// ── Error helper ──────────────────────────────────────────────────────────────

String _friendly(Object e) {
  final msg = e.toString();
  if (msg.contains('SocketException') || msg.contains('connection')) {
    return 'Cannot reach server. Check your connection.';
  }
  if (msg.contains('401')) return 'Session expired. Please log in again.';
  if (msg.contains('403')) return 'You do not have permission to do this.';
  if (msg.contains('404')) return 'Resource not found.';
  if (msg.contains('413')) return 'File too large. Maximum size is 25 MB.';
  if (msg.contains('500')) return 'Server error. Please try again later.';
  return msg.replaceAll('Exception:', '').trim();
}
