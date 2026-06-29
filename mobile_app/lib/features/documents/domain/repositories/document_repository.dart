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
  });
  Future<void> deleteDocument(int id);
}
