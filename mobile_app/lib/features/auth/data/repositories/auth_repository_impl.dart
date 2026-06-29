import 'dart:convert';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/constants/app_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/forgot_password_models.dart';
import '../models/login_request_model.dart';
import '../models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    dataSource: ref.watch(authRemoteDataSourceProvider),
    storage: ref.watch(secureStorageProvider),
    cookieJar: ref.watch(cookieJarProvider),
  );
});

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _dataSource;
  final SecureStorageService _storage;
  final CookieJar _cookieJar;

  const AuthRepositoryImpl({
    required AuthRemoteDataSource dataSource,
    required SecureStorageService storage,
    required CookieJar cookieJar,
  })  : _dataSource = dataSource,
        _storage = storage,
        _cookieJar = cookieJar;

  @override
  Future<UserEntity> login(String email, String password) async {
    final response = await _dataSource.login(LoginRequestModel(email: email, password: password));
    await _cacheUser(response.user);
    // Persist the access token so AuthInterceptor can send it as a Bearer header.
    // This makes auth work reliably on native even if the cookie jar is empty.
    if (response.accessToken != null && response.accessToken!.isNotEmpty) {
      await _storage.write(AppConstants.keyAccessToken, response.accessToken!);
    }
    return response.user;
  }

  @override
  Future<void> logout() async {
    await _dataSource.logout();
    await clearSession();
  }

  @override
  Future<void> forgotPassword(String email) =>
      _dataSource.forgotPassword(ForgotPasswordRequestModel(email: email));

  @override
  Future<String> verifyOtp(String email, String otp) =>
      _dataSource.verifyOtp(VerifyOtpRequestModel(email: email, otp: otp));

  @override
  Future<void> resetPassword(String resetToken, String newPassword) =>
      _dataSource.resetPassword(
        ResetPasswordRequestModel(resetToken: resetToken, newPassword: newPassword),
      );

  @override
  Future<UserEntity?> getCachedUser() async {
    final raw = await _storage.read(AppConstants.keyUserData);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return UserModel.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clearSession() async {
    await _storage.deleteAll();
    // Browser manages its own cookies on web; only clear the jar on native.
    if (!kIsWeb) {
      await _cookieJar.delete(Uri.parse(ApiConstants.baseUrl), true);
    }
  }

  Future<void> _cacheUser(UserModel user) async {
    await _storage.write(AppConstants.keyUserData, jsonEncode(user.toJson()));
    await _storage.write(AppConstants.keyIsLoggedIn, 'true');
  }
}
