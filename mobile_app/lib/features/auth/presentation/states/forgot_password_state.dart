enum ForgotPasswordStep { email, otp, reset, success }

class ForgotPasswordState {
  final ForgotPasswordStep step;
  // Captured on the email step and reused for OTP verification, OTP resend
  // and the final reset — the backend needs it on all three requests.
  final String? companyCode;
  final String? email;
  final String? resetToken;
  final bool isLoading;
  final String? errorMessage;

  const ForgotPasswordState({
    this.step = ForgotPasswordStep.email,
    this.companyCode,
    this.email,
    this.resetToken,
    this.isLoading = false,
    this.errorMessage,
  });

  ForgotPasswordState copyWith({
    ForgotPasswordStep? step,
    String? companyCode,
    String? email,
    String? resetToken,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ForgotPasswordState(
      step: step ?? this.step,
      companyCode: companyCode ?? this.companyCode,
      email: email ?? this.email,
      resetToken: resetToken ?? this.resetToken,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
