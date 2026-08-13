// ignore_for_file: use_super_parameters
// Subclasses carry a hardcoded statusCode alongside an optional default message,
// which requires an explicit super() call — making super parameters impossible per
// the Dart spec. The warning is suppressed at the file level.

class AppException implements Exception {
  final String message;
  final int? statusCode;

  const AppException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.statusCode});
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([String message = 'Your session has expired. Please log in again.'])
      : super(message, statusCode: 401);
}

/// A permission-denied response from an *authenticated* request — the user
/// is logged in but their role/permissions don't allow this action. Distinct
/// from [AccountLockedException], which is specifically the login-endpoint's
/// "too many failed attempts" lockout and can only ever come from `/login/`.
class ForbiddenException extends AppException {
  const ForbiddenException([String message = "You don't have permission to perform this action."])
      : super(message, statusCode: 403);
}

class NotFoundException extends AppException {
  const NotFoundException([String message = 'The requested information could not be found.'])
      : super(message, statusCode: 404);
}

class RateLimitException extends AppException {
  const RateLimitException([String message = 'Too many requests. Please try again later.'])
      : super(message, statusCode: 429);
}

class ServerException extends AppException {
  const ServerException([String message = 'Something went wrong on the server. Please try again.'])
      : super(message, statusCode: 500);
}

/// A 422 (or any backend field-validation failure) response — the request
/// was understood but the submitted data didn't pass validation.
class ValidationException extends AppException {
  const ValidationException(
      [String message = 'Please check the information you entered and try again.',
      int? statusCode])
      : super(message, statusCode: statusCode ?? 422);
}

class NoInternetException extends AppException {
  const NoInternetException(
      [super.message = 'No internet connection. Check your connection and try again.']);
}

class AccountLockedException extends AppException {
  const AccountLockedException([String message = 'Account locked. Please try again later.'])
      : super(message, statusCode: 403);
}
