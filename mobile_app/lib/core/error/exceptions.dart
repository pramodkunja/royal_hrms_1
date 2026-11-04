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

/// The company has this module switched off. The backend's tenant
/// middleware (apps/tenants/middleware.py) answers every request under a
/// gated path (/attendance/, /announcements/, /recruitment/, /leave/,
/// /expenses/, /separation/, /payroll/, /voice/, /assessments/) with 403
/// and the message "<Module> is not enabled for your company. Contact your
/// administrator to enable it." — that message is kept and shown as is.
/// A 403 like any other, so existing `is ForbiddenException` checks still
/// hold; retrying does not help.
class ModuleDisabledException extends ForbiddenException {
  const ModuleDisabledException([String message = kModuleDisabledFallback]) : super(message);
}

/// Shown only if a module-disabled refusal ever arrives without its text.
const kModuleDisabledFallback =
    'This module is not enabled for your company. Contact your administrator to enable it.';

/// The wording the backend uses for a disabled module (tenant middleware,
/// and the voice executor's "{label} is not enabled for your company.").
/// The backend sends no separate code for this case, so its own message is
/// the only signal; nothing is inferred from a request merely failing.
bool isModuleDisabledMessage(String? message) =>
    message != null && message.toLowerCase().contains('is not enabled for your company');

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
