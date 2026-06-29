class AppConstants {
  AppConstants._();

  static const String appName = 'Royal HRMS';
  static const String appVersion = '1.0.0';

  // Secure storage keys
  static const String keyUserData = 'royal_hrms_user_data';
  static const String keyIsLoggedIn = 'royal_hrms_logged_in';
  static const String keyAccessToken = 'royal_hrms_access_token';

  // OTP
  static const int otpLength = 6;
  static const int otpExpiryMinutes = 10;

  // Validation
  static const int minPasswordLength = 8;
  static const int maxLoginAttempts = 5;
  static const int lockoutMinutes = 30;

  // Pagination
  static const int defaultPageSize = 20;
}
