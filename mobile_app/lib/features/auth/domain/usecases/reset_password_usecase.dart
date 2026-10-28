import '../repositories/auth_repository.dart';

class ResetPasswordUseCase {
  final AuthRepository _repository;

  const ResetPasswordUseCase(this._repository);

  Future<void> call(
    String companyCode,
    String resetToken,
    String newPassword,
    String confirmPassword,
  ) =>
      _repository.resetPassword(companyCode.trim(), resetToken, newPassword, confirmPassword);
}
