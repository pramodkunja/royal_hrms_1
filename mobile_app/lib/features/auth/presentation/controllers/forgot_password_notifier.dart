import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/forgot_password_usecase.dart';
import '../../domain/usecases/reset_password_usecase.dart';
import '../../domain/usecases/verify_otp_usecase.dart';
import '../states/forgot_password_state.dart';

class ForgotPasswordNotifier extends Notifier<ForgotPasswordState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  ForgotPasswordState build() => const ForgotPasswordState();

  Future<void> sendOtp(String companyCode, String email) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await ForgotPasswordUseCase(_repository)(companyCode, email);
      state = state.copyWith(
        isLoading: false,
        companyCode: companyCode.trim(),
        email: email,
        step: ForgotPasswordStep.otp,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _friendlyMessage(e));
    }
  }

  Future<void> verifyOtp(String otp) async {
    final companyCode = state.companyCode;
    final email = state.email;
    if (companyCode == null || email == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final token = await VerifyOtpUseCase(_repository)(companyCode, email, otp);
      state = state.copyWith(
        isLoading: false,
        resetToken: token,
        step: ForgotPasswordStep.reset,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _friendlyMessage(e));
    }
  }

  Future<void> resetPassword(String newPassword, String confirmPassword) async {
    final companyCode = state.companyCode;
    final resetToken = state.resetToken;
    if (companyCode == null || resetToken == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await ResetPasswordUseCase(_repository)(
        companyCode,
        resetToken,
        newPassword,
        confirmPassword,
      );
      state = state.copyWith(isLoading: false, step: ForgotPasswordStep.success);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _friendlyMessage(e));
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
  void reset() => state = const ForgotPasswordState();

  String _friendlyMessage(Object error) {
    final raw = error.toString();
    if (raw.contains('XMLHttpRequest') || raw.contains('SocketException')) {
      return 'Cannot connect to server. Please check your network.';
    }
    if (raw.contains('TimeoutException')) return 'Request timed out. Please try again.';
    return raw;
  }
}
