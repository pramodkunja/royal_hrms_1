// Every recovery request carries `company_code`: the backend resolves the
// tenant (company schema) from it before looking up the email, OTP or reset
// token (ForgotPasswordSerializer / VerifyOTPSerializer /
// ResetPasswordSerializer in apps/accounts/serializers.py).

class ForgotPasswordRequestModel {
  final String companyCode;
  final String email;

  const ForgotPasswordRequestModel({required this.companyCode, required this.email});

  Map<String, dynamic> toJson() => {'company_code': companyCode, 'email': email};
}

class VerifyOtpRequestModel {
  final String companyCode;
  final String email;
  final String otp;

  const VerifyOtpRequestModel({
    required this.companyCode,
    required this.email,
    required this.otp,
  });

  Map<String, dynamic> toJson() => {'company_code': companyCode, 'email': email, 'otp': otp};
}

class ResetPasswordRequestModel {
  final String companyCode;
  final String resetToken;
  final String newPassword;
  final String confirmPassword;

  const ResetPasswordRequestModel({
    required this.companyCode,
    required this.resetToken,
    required this.newPassword,
    required this.confirmPassword,
  });

  Map<String, dynamic> toJson() => {
        'company_code': companyCode,
        'reset_token': resetToken,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      };
}
