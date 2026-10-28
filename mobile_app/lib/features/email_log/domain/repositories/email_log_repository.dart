import '../entities/email_log_entity.dart';

abstract class EmailLogRepository {
  Future<EmailLogPageEntity> getEmailLogs({
    int page = 1,
    int pageSize = 20,
    String? search,
  });
}
