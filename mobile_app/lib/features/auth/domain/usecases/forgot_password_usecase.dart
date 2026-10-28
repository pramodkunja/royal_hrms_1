import '../repositories/auth_repository.dart';

class ForgotPasswordUseCase {
  final AuthRepository _repository;

  const ForgotPasswordUseCase(this._repository);

  Future<void> call(String companyCode, String email) =>
      _repository.forgotPassword(companyCode.trim(), email.trim().toLowerCase());
}
