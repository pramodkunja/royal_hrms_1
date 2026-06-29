import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/document_remote_datasource.dart';
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
  }) async {
    try {
      final created = await _repo.createDocument(
        filePath: filePath,
        fileName: fileName,
        title: title,
        description: description,
        category: category,
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
}

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
