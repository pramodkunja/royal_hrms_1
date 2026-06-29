import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/error/exceptions.dart';
import 'package:mobile_app/core/network/api_client.dart';
import '../models/forgot_password_models.dart';
import '../models/login_request_model.dart';
import '../models/login_response_model.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSource(ref.watch(dioProvider)),
);

class AuthRemoteDataSource {
  final Dio _dio;

  const AuthRemoteDataSource(this._dio);

  Future<LoginResponseModel> login(LoginRequestModel request) async {
    try {
      final response = await _dio.post(ApiConstants.login, data: request.toJson());
      return LoginResponseModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw parseDioException(e);
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post(ApiConstants.logout);
    } on DioException catch (e) {
      // Swallow 401 on logout (session may already be expired)
      if (e.response?.statusCode != 401) throw parseDioException(e);
    }
  }

  Future<void> forgotPassword(ForgotPasswordRequestModel request) async {
    try {
      await _dio.post(ApiConstants.forgotPassword, data: request.toJson());
    } on DioException catch (e) {
      throw parseDioException(e);
    }
  }

  Future<String> verifyOtp(VerifyOtpRequestModel request) async {
    try {
      final response = await _dio.post(ApiConstants.verifyOtp, data: request.toJson());
      final data = response.data as Map<String, dynamic>;
      final token = (data['data'] as Map<String, dynamic>?)?['reset_token'] as String?;
      if (token == null) throw const ServerException('Invalid OTP response from server.');
      return token;
    } on DioException catch (e) {
      throw parseDioException(e);
    }
  }

  Future<void> resetPassword(ResetPasswordRequestModel request) async {
    try {
      await _dio.post(ApiConstants.resetPassword, data: request.toJson());
    } on DioException catch (e) {
      throw parseDioException(e);
    }
  }
}
