import '../repositories/auth_repository.dart';

class VerifyOtpUseCase {
  final AuthRepository _repository;

  const VerifyOtpUseCase(this._repository);

  /// Returns a one-time [resetToken] used in the password reset step.
  Future<String> call(String email, String otp) => _repository.verifyOtp(email, otp);
}
