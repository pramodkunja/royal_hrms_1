import '../../domain/entities/document_entity.dart';
import '../../domain/repositories/document_repository.dart';
import '../datasources/document_remote_datasource.dart';
import '../models/policy_ack_models.dart';

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
    bool requiresAcknowledgement = false,
  }) =>
      _ds.createDocument(
        filePath: filePath,
        fileName: fileName,
        title: title,
        description: description,
        category: category,
        requiresAcknowledgement: requiresAcknowledgement,
      );

  @override
  Future<void> deleteDocument(int id) => _ds.deleteDocument(id);

  @override
  Future<List<PendingAcknowledgement>> getPendingAcknowledgements() => _ds.fetchPendingAcknowledgements();

  @override
  Future<DocumentEntity> getDocument(int id) => _ds.fetchDocument(id);

  @override
  Future<String> acknowledge(int id, int version) => _ds.acknowledge(id, version);

  @override
  Future<AckReport> getAcknowledgementReport(int id) => _ds.fetchAcknowledgementReport(id);

  @override
  Future<DocumentEntity> setRequiresAcknowledgement(int id, bool value) =>
      _ds.setRequiresAcknowledgement(id, value);
}
