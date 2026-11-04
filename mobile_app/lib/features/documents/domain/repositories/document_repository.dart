import '../../data/models/policy_ack_models.dart';
import '../entities/document_entity.dart';

abstract class DocumentRepository {
  Future<DocumentStatsEntity> getStats();
  Future<List<DocumentEntity>> getDocuments({String? category, String? search});
  Future<DocumentEntity> createDocument({
    required String filePath,
    required String fileName,
    required String title,
    required String description,
    required String category,
    bool requiresAcknowledgement = false,
  });
  Future<void> deleteDocument(int id);

  Future<List<PendingAcknowledgement>> getPendingAcknowledgements();
  Future<DocumentEntity> getDocument(int id);
  Future<String> acknowledge(int id, int version);
  Future<AckReport> getAcknowledgementReport(int id);
  Future<DocumentEntity> setRequiresAcknowledgement(int id, bool value);
}
