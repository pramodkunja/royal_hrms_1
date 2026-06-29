import '../entities/user_entity.dart';

abstract class AuthRepository {
  /// Authenticates the user and returns the logged-in [UserEntity].
  Future<UserEntity> login(String email, String password);

  /// Ends the current session on both the server and locally.
  Future<void> logout();

  /// Sends an OTP to the provided email for password reset.
  Future<void> forgotPassword(String email);

  /// Verifies the OTP and returns a one-time reset token.
  Future<String> verifyOtp(String email, String otp);

  /// Resets the password using the one-time reset token.
  Future<void> resetPassword(String resetToken, String newPassword);

  /// Reads cached user data from secure storage; returns null if not logged in.
  Future<UserEntity?> getCachedUser();

  /// Removes all locally stored session data.
  Future<void> clearSession();
}
