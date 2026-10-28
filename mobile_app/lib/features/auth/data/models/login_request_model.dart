class LoginRequestModel {
  final String companyCode;
  final String email;
  final String password;

  const LoginRequestModel({
    required this.companyCode,
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() =>
      {'company_code': companyCode, 'email': email, 'password': password};
}
