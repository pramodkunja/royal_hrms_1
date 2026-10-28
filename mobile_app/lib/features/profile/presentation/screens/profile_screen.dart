import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/validators/form_validators.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../separation/presentation/widgets/profile_separation_section.dart';
import '../../data/models/my_profile_model.dart';
import '../providers/profile_providers.dart';
import '../widgets/profile_face_id_section.dart';
import '../widgets/profile_sections.dart';

// ignore_for_file: use_build_context_synchronously

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // Editable fields
  final _phoneCtrl = TextEditingController();
  final _currentAddressCtrl = TextEditingController();
  final _permanentAddressCtrl = TextEditingController();
  final _emergencyNameCtrl = TextEditingController();
  final _emergencyRelationshipCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();
  final _emergencyEmailCtrl = TextEditingController();

  // Password
  final _curPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _cfmPassCtrl = TextEditingController();

  bool _saving = false;
  bool _changingPassword = false;
  // Tracks which profile.id the controllers were last populated from, so we
  // don't clobber in-progress edits on every provider rebuild.
  String? _hydratedForId;

  @override
  void dispose() {
    for (final c in [
      _phoneCtrl, _currentAddressCtrl, _permanentAddressCtrl,
      _emergencyNameCtrl, _emergencyRelationshipCtrl,
      _emergencyPhoneCtrl, _emergencyEmailCtrl,
      _curPassCtrl, _newPassCtrl, _cfmPassCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _hydrate(MyProfileModel profile) {
    if (_hydratedForId == profile.id) return;
    _hydratedForId = profile.id;
    _phoneCtrl.text = profile.phone;
    _currentAddressCtrl.text = profile.detail.currentAddress;
    _permanentAddressCtrl.text = profile.detail.permanentAddress;
    _emergencyNameCtrl.text = profile.detail.emergencyName;
    _emergencyRelationshipCtrl.text = profile.detail.emergencyRelationship;
    _emergencyPhoneCtrl.text = profile.detail.emergencyPhone;
    _emergencyEmailCtrl.text = profile.detail.emergencyEmail;
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.error : null,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // Mirrors backend's lenient phone/email rules for these fields
  // (accounts/serializers.py _PHONE_RE_PROFILE for phone/emergency_phone,
  // Django's EmailField for emergency_email) so a bad value is caught here
  // instead of round-tripping to the API for a 400.
  String? _validateBeforeSave() {
    final phoneError = FormValidators.lenientPhone(_phoneCtrl.text);
    if (phoneError != null) return phoneError;
    final emergencyPhoneError = FormValidators.lenientPhone(_emergencyPhoneCtrl.text);
    if (emergencyPhoneError != null) return 'Emergency contact: $emergencyPhoneError';
    final emergencyEmailText = _emergencyEmailCtrl.text.trim();
    if (emergencyEmailText.isNotEmpty && FormValidators.email(emergencyEmailText) != null) {
      return 'Enter a valid emergency contact email address.';
    }
    return null;
  }

  Future<void> _onSave() async {
    if (_saving) return;
    final validationError = _validateBeforeSave();
    if (validationError != null) {
      _showSnack(validationError, isError: true);
      return;
    }
    setState(() => _saving = true);
    final data = MyProfileUpdateData(
      phone: _phoneCtrl.text,
      currentAddress: _currentAddressCtrl.text,
      permanentAddress: _permanentAddressCtrl.text,
      emergencyName: _emergencyNameCtrl.text,
      emergencyRelationship: _emergencyRelationshipCtrl.text,
      emergencyPhone: _emergencyPhoneCtrl.text,
      emergencyEmail: _emergencyEmailCtrl.text,
    );
    final err = await ref.read(myProfileProvider.notifier).updateProfile(data);
    if (!mounted) return;
    setState(() => _saving = false);
    _showSnack(err ?? 'Changes saved successfully', isError: err != null);
  }

  Future<void> _onChangePassword() async {
    final oldPass = _curPassCtrl.text;
    final newPass = _newPassCtrl.text;
    final confirmPass = _cfmPassCtrl.text;

    // Client-side validation order mirrors the web app: old required → new
    // required → new must equal confirm → new must differ from old. Server
    // enforces length/complexity — we don't duplicate that here.
    if (oldPass.isEmpty) {
      _showSnack('Current password is required.', isError: true);
      return;
    }
    if (newPass.isEmpty) {
      _showSnack('New password is required.', isError: true);
      return;
    }
    if (newPass != confirmPass) {
      _showSnack('New password and confirm password do not match.', isError: true);
      return;
    }
    if (newPass == oldPass) {
      _showSnack('New password must be different from the current password.',
          isError: true);
      return;
    }

    setState(() => _changingPassword = true);
    final err = await changeMyPassword(
      ref,
      oldPassword: oldPass,
      newPassword: newPass,
      confirmPassword: confirmPass,
    );
    if (!mounted) return;
    setState(() => _changingPassword = false);

    if (err != null) {
      _showSnack(err, isError: true);
      return;
    }

    _curPassCtrl.clear();
    _newPassCtrl.clear();
    _cfmPassCtrl.clear();
    await _forceLogoutAfterPasswordChange();
  }

  // The backend blacklists the refresh token and clears auth cookies on a
  // successful password change — the session is already dead server-side,
  // so we must log out locally and send the user back to login rather than
  // leaving them on a screen backed by a session that no longer exists.
  Future<void> _forceLogoutAfterPasswordChange() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Password Changed'),
        content: const Text('Password changed. Please log in again.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    await ref.read(authStateProvider.notifier).logout();
    if (mounted) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: profileAsync.when(
          data: (profile) {
            _hydrate(profile);
            return RefreshIndicator(
              onRefresh: () => ref.read(myProfileProvider.notifier).refresh(),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _header()),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                      child: Column(
                        children: [
                          ProfilePersonalSection(
                            profile: profile,
                            phoneCtrl: _phoneCtrl,
                          ),
                          const SizedBox(height: 16),
                          const ProfileSeparationSection(),
                          const SizedBox(height: 16),
                          ProfileAddressSection(
                            currentAddressCtrl: _currentAddressCtrl,
                            permanentAddressCtrl: _permanentAddressCtrl,
                          ),
                          const SizedBox(height: 16),
                          ProfileEducationSection(profile: profile),
                          const SizedBox(height: 16),
                          ProfileBankSection(profile: profile),
                          const SizedBox(height: 16),
                          ProfileEmergencySection(
                            nameCtrl: _emergencyNameCtrl,
                            relationshipCtrl: _emergencyRelationshipCtrl,
                            phoneCtrl: _emergencyPhoneCtrl,
                            emailCtrl: _emergencyEmailCtrl,
                          ),
                          const SizedBox(height: 16),
                          ProfileChangePasswordSection(
                            currentCtrl: _curPassCtrl,
                            newCtrl: _newPassCtrl,
                            confirmCtrl: _cfmPassCtrl,
                            loading: _changingPassword,
                            onSubmit: _onChangePassword,
                          ),
                          const SizedBox(height: 16),
                          const ProfileFaceIdSection(),
                          const SizedBox(height: 16),
                          const ProfileDocumentsSection(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AppErrorState(
            message: friendlyProfileError(e),
            onRetry: () => ref.invalidate(myProfileProvider),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('My Profile', style: AppTextStyles.h4),
                const SizedBox(height: 2),
                Text(
                  'View and update your personal information',
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: _saving ? null : _onSave,
            icon: _saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(Icons.save_outlined, size: 15),
            label: Text(_saving ? 'Saving…' : 'Save Changes'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: AppTextStyles.bodySmall
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
