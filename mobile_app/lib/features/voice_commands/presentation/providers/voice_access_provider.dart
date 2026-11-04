import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app/core/router/app_router.dart' show kAssessmentGateEnabled;
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';

/// Whether the signed-in user may use the voice assistant at all — the one
/// rule shared by the mic overlay (visibility) and VoiceCommandController
/// (every action), so the two can never disagree.
///
/// Not allowed:
///  - signed out;
///  - onboarding still pending/draft, or submitted and awaiting approval;
///  - `must_change_password` from the login response. The backend does not
///    enforce that flag on any endpoint (including /voice/parse/, which can
///    clock the user in or out), so the app must: a temporary or
///    admin-reset password has to be replaced before anything else, voice
///    included (see resolveAuthRedirect). A successful change ends the
///    session; the flag only clears through a fresh login whose response
///    says so;
///  - the onboarding assessment gate (UserEntity.needsAssessments): until the
///    required assessments are done only they are open (resolveAuthRedirect),
///    and voice commands such as clocking in must not get around that.
bool isVoiceAssistantAllowed(AuthState? authState) {
  final user = authState?.user;
  if (!(authState?.isAuthenticated ?? false) || user == null) return false;
  return !user.mustChangePassword &&
      !user.needsOnboarding &&
      !user.awaitingApproval &&
      !(kAssessmentGateEnabled && user.needsAssessments);
}

final voiceAssistantAllowedProvider = Provider<bool>(
  (ref) => isVoiceAssistantAllowed(ref.watch(authStateProvider).valueOrNull),
);
