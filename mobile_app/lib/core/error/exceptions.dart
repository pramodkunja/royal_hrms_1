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
  const UnauthorizedException([String message = 'Session expired. Please log in again.'])
      : super(message, statusCode: 401);
}

class ForbiddenException extends AppException {
  const ForbiddenException([String message = 'You do not have permission to perform this action.'])
      : super(message, statusCode: 403);
}

class NotFoundException extends AppException {
  const NotFoundException([String message = 'The requested resource was not found.'])
      : super(message, statusCode: 404);
}

class RateLimitException extends AppException {
  const RateLimitException([String message = 'Too many requests. Please try again later.'])
      : super(message, statusCode: 429);
}

class ServerException extends AppException {
  const ServerException([String message = 'An unexpected server error occurred.'])
      : super(message, statusCode: 500);
}

class ValidationException extends AppException {
  const ValidationException(super.message, {super.statusCode});
}

class NoInternetException extends AppException {
  const NoInternetException(
      [super.message = 'No internet connection. Please check your network.']);
}

class AccountLockedException extends AppException {
  const AccountLockedException([String message = 'Account locked. Please try again later.'])
      : super(message, statusCode: 403);
}
