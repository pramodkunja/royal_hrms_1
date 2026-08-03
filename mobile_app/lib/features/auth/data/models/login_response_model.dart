import 'user_model.dart';

class LoginResponseModel {
  final UserModel user;
  // The access/refresh tokens returned in the response body (not just the
  // cookie). Used by the client to send Authorization: Bearer headers and to
  // drive silent refresh on platforms where the httpOnly refresh cookie may
  // not reach the server (e.g. web when the app isn't served from the same
  // origin as the API).
  final String? accessToken;
  final String? refreshToken;

  const LoginResponseModel({required this.user, this.accessToken, this.refreshToken});

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    // Backend envelope: { success, message, data: { access, refresh, user } }
    final data = json['data'] as Map<String, dynamic>;
    return LoginResponseModel(
      user: UserModel.fromJson(data['user'] as Map<String, dynamic>),
      accessToken: data['access'] as String?,
      refreshToken: data['refresh'] as String?,
    );
  }
}
