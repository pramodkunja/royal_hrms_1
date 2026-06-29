import 'user_model.dart';

class LoginResponseModel {
  final UserModel user;
  // The access token returned in the response body (not the cookie).
  // Used by the mobile client to send Authorization: Bearer headers.
  final String? accessToken;

  const LoginResponseModel({required this.user, this.accessToken});

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    // Backend envelope: { success, message, data: { access, user } }
    final data = json['data'] as Map<String, dynamic>;
    return LoginResponseModel(
      user: UserModel.fromJson(data['user'] as Map<String, dynamic>),
      accessToken: data['access'] as String?,
    );
  }
}
