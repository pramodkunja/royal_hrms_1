class ForgotPasswordRequestModel {
  final String email;

  const ForgotPasswordRequestModel({required this.email});

  Map<String, dynamic> toJson() => {'email': email};
}

class VerifyOtpRequestModel {
  final String email;
  final String otp;

  const VerifyOtpRequestModel({required this.email, required this.otp});

  Map<String, dynamic> toJson() => {'email': email, 'otp': otp};
}

class ResetPasswordRequestModel {
  final String resetToken;
  final String newPassword;

  const ResetPasswordRequestModel({required this.resetToken, required this.newPassword});

  Map<String, dynamic> toJson() => {
        'reset_token': resetToken,
        'new_password': newPassword,
      };
}
