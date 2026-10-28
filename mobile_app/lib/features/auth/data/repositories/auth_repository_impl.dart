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
  Future<UserEntity> login(String companyCode, String email, String password) async {
    final response = await _dataSource.login(
      LoginRequestModel(companyCode: companyCode, email: email, password: password),
    );
    await _cacheUser(response.user);
    // Persist the access/refresh tokens so AuthInterceptor can send the access
    // token as a Bearer header and drive silent refresh from the stored
    // refresh token. This makes auth work reliably on native even if the
    // cookie jar is empty, and on web when the httpOnly refresh cookie can't
    // reach the server (e.g. a cross-site dev setup).
    if (response.accessToken != null && response.accessToken!.isNotEmpty) {
      await _storage.write(AppConstants.keyAccessToken, response.accessToken!);
    }
    if (response.refreshToken != null && response.refreshToken!.isNotEmpty) {
      await _storage.write(AppConstants.keyRefreshToken, response.refreshToken!);
    }
    return response.user;
  }

  @override
  Future<void> logout() async {
    // clearSession() must run even when the server-side logout call fails
    // (e.g. a 401 because the session was already invalid — the exact case
    // when the app's cached user predates a backend switch or an expired/
    // revoked cookie) — otherwise the stale cached user in secure storage is
    // never deleted, and AuthNotifier.build() restores it again on every
    // subsequent launch, permanently re-triggering the same 401 flood.
    try {
      await _dataSource.logout();
    } finally {
      await clearSession();
    }
  }

  @override
  Future<void> forgotPassword(String companyCode, String email) => _dataSource.forgotPassword(
        ForgotPasswordRequestModel(companyCode: companyCode, email: email),
      );

  @override
  Future<String> verifyOtp(String companyCode, String email, String otp) =>
      _dataSource.verifyOtp(
        VerifyOtpRequestModel(companyCode: companyCode, email: email, otp: otp),
      );

  @override
  Future<void> resetPassword(
    String companyCode,
    String resetToken,
    String newPassword,
    String confirmPassword,
  ) =>
      _dataSource.resetPassword(
        ResetPasswordRequestModel(
          companyCode: companyCode,
          resetToken: resetToken,
          newPassword: newPassword,
          confirmPassword: confirmPassword,
        ),
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
