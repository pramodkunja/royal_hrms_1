import '../repositories/auth_repository.dart';

class ResetPasswordUseCase {
  final AuthRepository _repository;

  const ResetPasswordUseCase(this._repository);

  Future<void> call(String resetToken, String newPassword) =>
      _repository.resetPassword(resetToken, newPassword);
}
