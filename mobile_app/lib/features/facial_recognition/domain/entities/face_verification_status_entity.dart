// Mirrors GET /attendance/face-verification/status/ — the org-wide toggle
// (Attendance Rules -> Face ID Verification) every authenticated user can
// read, regardless of role, so both the Profile self-service card and the
// clock-in flow know whether to ask for a face capture at all.
class FaceVerificationStatusEntity {
  final bool isMandatory;

  const FaceVerificationStatusEntity({required this.isMandatory});
}
