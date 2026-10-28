import '../../domain/entities/email_log_entity.dart';
import '../../domain/repositories/email_log_repository.dart';
import '../datasources/email_log_remote_datasource.dart';

class EmailLogRepositoryImpl implements EmailLogRepository {
  final EmailLogRemoteDataSource _ds;
  EmailLogRepositoryImpl(this._ds);

  @override
  Future<EmailLogPageEntity> getEmailLogs({
    int page = 1,
    int pageSize = 20,
    String? search,
  }) =>
      _ds.fetchEmailLogs(page: page, pageSize: pageSize, search: search);
}
