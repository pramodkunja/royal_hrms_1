import 'package:mobile_app/core/constants/app_constants.dart';

class FormValidators {
  FormValidators._();

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required.';
    final pattern = RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');
    if (!pattern.hasMatch(value.trim())) return 'Enter a valid email address.';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required.';
    if (value.length < AppConstants.minPasswordLength) {
      return 'Password must be at least ${AppConstants.minPasswordLength} characters.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Please confirm your password.';
    if (value != original) return 'Passwords do not match.';
    return null;
  }

  static String? otp(String? value) {
    if (value == null || value.trim().isEmpty) return 'OTP is required.';
    if (value.trim().length != AppConstants.otpLength) {
      return 'Enter the ${AppConstants.otpLength}-digit OTP.';
    }
    if (!RegExp(r'^\d+$').hasMatch(value.trim())) return 'OTP must contain digits only.';
    return null;
  }

  static String? required(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required.';
    return null;
  }

  // Mirrors backend/apps/recruitment/serializers.py (_NAME_RE, _POSITION_RE,
  // _PHONE_RE, validate_interview_date) so Add/Edit Candidate give the same
  // feedback client-side before hitting the API.
  static final RegExp candidateNameRe = RegExp(r"^[A-Za-z][A-Za-z .'-]*$");
  static final RegExp candidatePositionRe = RegExp(r'^[A-Za-z][A-Za-z .&/-]*$');
  static final RegExp candidatePhoneRe = RegExp(r'^\+?[0-9]{10,15}$');

  static String sanitizeCandidateName(String value) =>
      value.replaceAll(RegExp(r"[^A-Za-z .'-]"), '');

  static String sanitizeCandidatePosition(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z .&/-]'), '');

  static String sanitizeCandidatePhone(String value) {
    var digitsAndPlus = value.replaceAll(RegExp(r'[^\d+]'), '');
    if (digitsAndPlus.contains('+')) {
      digitsAndPlus = '+${digitsAndPlus.replaceAll('+', '')}';
    }
    final maxLength = digitsAndPlus.startsWith('+') ? 16 : 15;
    return digitsAndPlus.length > maxLength ? digitsAndPlus.substring(0, maxLength) : digitsAndPlus;
  }

  static String? candidateName(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Full name is required.';
    if (!candidateNameRe.hasMatch(v)) return 'Name must contain letters only (no numbers).';
    return null;
  }

  static String? candidatePosition(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Position applied is required.';
    if (!candidatePositionRe.hasMatch(v)) return 'Position must contain letters only (no numbers).';
    return null;
  }

  static String? candidatePhone(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    if (!candidatePhoneRe.hasMatch(v)) return 'Enter a valid phone number (10-15 digits).';
    return null;
  }

  /// [original] is the previously-saved date (edit flow only) — a past date
  /// that hasn't changed is allowed through (the interview already happened).
  static String? interviewDate(DateTime? value, {DateTime? original}) {
    if (value == null) return null;
    if (original != null && _isSameDate(value, original)) return null;
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    if (value.isBefore(todayDateOnly)) return 'Interview date cannot be in the past.';
    return null;
  }

  static bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // Mirrors backend/apps/hrms/serializers.py _LEAVE_NAME_RE / validate_leave_type_label.
  static final RegExp leaveTypeNameRe = RegExp(r'^[A-Za-z][A-Za-z -]*$');

  static String sanitizeLeaveTypeName(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z -]'), '');

  static String? leaveTypeName(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Leave type name is required.';
    if (!leaveTypeNameRe.hasMatch(v)) {
      return 'Leave type name can only contain letters, spaces, and hyphens.';
    }
    return null;
  }
}
