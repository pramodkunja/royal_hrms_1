enum ForgotPasswordStep { email, otp, reset, success }

class ForgotPasswordState {
  final ForgotPasswordStep step;
  final String? email;
  final String? resetToken;
  final bool isLoading;
  final String? errorMessage;

  const ForgotPasswordState({
    this.step = ForgotPasswordStep.email,
    this.email,
    this.resetToken,
    this.isLoading = false,
    this.errorMessage,
  });

  ForgotPasswordState copyWith({
    ForgotPasswordStep? step,
    String? email,
    String? resetToken,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ForgotPasswordState(
      step: step ?? this.step,
      email: email ?? this.email,
      resetToken: resetToken ?? this.resetToken,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
