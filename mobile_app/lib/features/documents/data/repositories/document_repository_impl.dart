import '../../domain/entities/document_entity.dart';
import '../../domain/repositories/document_repository.dart';
import '../datasources/document_remote_datasource.dart';

class DocumentRepositoryImpl implements DocumentRepository {
  final DocumentRemoteDataSource _ds;
  DocumentRepositoryImpl(this._ds);

  @override
  Future<DocumentStatsEntity> getStats() => _ds.fetchStats();

  @override
  Future<List<DocumentEntity>> getDocuments({
    String? category,
    String? search,
  }) =>
      _ds.fetchDocuments(category: category, search: search);

  @override
  Future<DocumentEntity> createDocument({
    required String filePath,
    required String fileName,
    required String title,
    required String description,
    required String category,
  }) =>
      _ds.createDocument(
        filePath: filePath,
        fileName: fileName,
        title: title,
        description: description,
        category: category,
      );

  @override
  Future<void> deleteDocument(int id) => _ds.deleteDocument(id);
}
