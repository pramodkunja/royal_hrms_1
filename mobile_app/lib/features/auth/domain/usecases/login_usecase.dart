import '../../../../shared/formatters/company_code_formatter.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository _repository;

  const LoginUseCase(this._repository);

  Future<UserEntity> call(String companyCode, String email, String password) {
    return _repository.login(normalizeCompanyCode(companyCode), email.trim().toLowerCase(), password);
  }
}
