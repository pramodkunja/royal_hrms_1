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
import '../widgets/profile_documents_section.dart';
import '../../../employees/presentation/widgets/custom_fields_block.dart' show profileFieldConfigProvider;
import '../../../facial_recognition/presentation/providers/facial_recognition_providers.dart';
import '../widgets/profile_custom_fields.dart';
import '../widgets/profile_face_id_section.dart';
import '../widgets/profile_header.dart';
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
  ProfileTab _tab = ProfileTab.personal;
  bool _dirty = false;
  MyProfileModel? _loaded;
  // Tracks which profile.id the controllers were last populated from, so we
  // don't clobber in-progress edits on every provider rebuild.
  String? _hydratedForId;

  List<TextEditingController> get _editCtrls => [
        _phoneCtrl,
        _currentAddressCtrl,
        _permanentAddressCtrl,
        _emergencyNameCtrl,
        _emergencyRelationshipCtrl,
        _emergencyPhoneCtrl,
        _emergencyEmailCtrl,
      ];

  @override
  void initState() {
    super.initState();
    for (final c in _editCtrls) {
      c.addListener(_recomputeDirty);
    }
  }

  // Compares the edit fields with what was loaded/saved, so Discard only
  // offers itself when there is something to discard.
  void _recomputeDirty() {
    final p = _loaded;
    if (p == null) return;
    final base = MyProfileUpdateData.fromProfile(p);
    final now = [
      _phoneCtrl.text,
      _currentAddressCtrl.text,
      _permanentAddressCtrl.text,
      _emergencyNameCtrl.text,
      _emergencyRelationshipCtrl.text,
      _emergencyPhoneCtrl.text,
      _emergencyEmailCtrl.text,
    ];
    final was = [
      base.phone,
      base.currentAddress,
      base.permanentAddress,
      base.emergencyName,
      base.emergencyRelationship,
      base.emergencyPhone,
      base.emergencyEmail,
    ];
    var dirty = false;
    for (var i = 0; i < now.length; i++) {
      if (now[i] != was[i]) dirty = true;
    }
    if (dirty != _dirty && mounted) setState(() => _dirty = dirty);
  }

  void _discard() {
    final p = _loaded;
    if (p == null) return;
    _hydratedForId = null;
    _hydrate(p);
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    for (final c in [
      _phoneCtrl,
      _currentAddressCtrl,
      _permanentAddressCtrl,
      _emergencyNameCtrl,
      _emergencyRelationshipCtrl,
      _emergencyPhoneCtrl,
      _emergencyEmailCtrl,
      _curPassCtrl,
      _newPassCtrl,
      _cfmPassCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _hydrate(MyProfileModel profile) {
    _loaded = profile;
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
    if (err == null) _recomputeDirty();
    // Web: "Profile updated successfully." (web shows a generic failure
    // line; the server's own reason is more useful on a phone).
    _showSnack(err ?? 'Profile updated successfully.', isError: err != null);
  }

  Future<void> _onChangePassword() async {
    final oldPass = _curPassCtrl.text;
    final newPass = _newPassCtrl.text;
    final confirmPass = _cfmPassCtrl.text;

    // Client-side validation order mirrors the web app: old required → new
    // required → new must equal confirm → new must differ from old. Server
    // enforces length/complexity — we don't duplicate that here.
    if (oldPass.isEmpty) {
      _showSnack('Enter your current password.', isError: true);
      return;
    }
    if (newPass.isEmpty) {
      _showSnack('Enter a new password.', isError: true);
      return;
    }
    if (newPass != confirmPass) {
      _showSnack('New passwords do not match.', isError: true);
      return;
    }
    if (newPass == oldPass) {
      _showSnack('New password must differ from the current one.', isError: true);
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

  /// Face ID tab is hidden once the org has the feature switched off (web
  /// `faceTabHidden`); kept while loading so it doesn't flash away.
  List<ProfileTab> _visibleTabs() {
    final status = ref.watch(faceVerificationStatusProvider);
    final hideFace = status.hasValue && !(status.value?.isMandatory ?? false);
    return [
      for (final t in ProfileTab.values)
        if (t != ProfileTab.face || !hideFace) t
    ];
  }

  Widget _tabBody(ProfileTab tab, MyProfileModel profile, ProfileFieldConfig config) {
    const gap = SizedBox(height: 16);
    switch (tab) {
      case ProfileTab.personal:
        return Column(children: [
          ProfilePersonalSection(profile: profile, phoneCtrl: _phoneCtrl, config: config),
          ProfileCustomFields(step: 0, values: profile.detail.customFieldValues),
          if (ProfileAddressSection.anyVisible(config)) ...[
            gap,
            ProfileAddressSection(
              currentAddressCtrl: _currentAddressCtrl,
              permanentAddressCtrl: _permanentAddressCtrl,
              config: config,
            ),
          ],
          gap,
          ProfileEmergencySection(
            nameCtrl: _emergencyNameCtrl,
            relationshipCtrl: _emergencyRelationshipCtrl,
            phoneCtrl: _emergencyPhoneCtrl,
            emailCtrl: _emergencyEmailCtrl,
            config: config,
          ),
          ProfileCustomFields(step: 3, values: profile.detail.customFieldValues),
        ]);
      case ProfileTab.work:
        return Column(children: [
          ProfileWorkSection(profile: profile),
          gap,
          const ProfileSeparationSection(),
        ]);
      case ProfileTab.education:
        return Column(children: [
          ProfileEducationSection(profile: profile, config: config),
          ProfileCustomFields(step: 1, values: profile.detail.customFieldValues),
        ]);
      case ProfileTab.bank:
        return Column(children: [
          ProfileBankSection(profile: profile, config: config),
          ProfileCustomFields(step: 2, values: profile.detail.customFieldValues),
        ]);
      case ProfileTab.documents:
        return const ProfileDocumentsSection();
      case ProfileTab.face:
        return const ProfileFaceIdSection();
      case ProfileTab.security:
        return ProfileChangePasswordSection(
          currentCtrl: _curPassCtrl,
          newCtrl: _newPassCtrl,
          confirmCtrl: _cfmPassCtrl,
          loading: _changingPassword,
          onSubmit: _onChangePassword,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);
    final config = ref.watch(profileFieldConfigProvider).valueOrNull;
    final tabs = _visibleTabs();
    final tab = tabs.contains(_tab) ? _tab : ProfileTab.personal;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: profileAsync.when(
          data: (profile) {
            _hydrate(profile);
            return RefreshIndicator(
              onRefresh: () => ref.read(myProfileProvider.notifier).refresh(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [_title(), const SizedBox(height: 14), ProfileHeaderCard(profile: profile)],
                          ),
                        ),
                      ),
                      // Pinned, so a section is always one tap away however
                      // far the page is scrolled.
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _TabStripDelegate(
                          extent: 58 + 30 * (MediaQuery.textScalerOf(context).scale(10) / 10 - 1).clamp(0.0, 1.5),
                          tabs: tabs,
                          selected: tab,
                          onSelected: (t) {
                            FocusScope.of(context).unfocus();
                            setState(() => _tab = t);
                          },
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 32),
                        sliver: SliverToBoxAdapter(child: _tabBody(tab, profile, config)),
                      ),
                    ],
                  ),
                ),
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
      // Web shows Save only on the Personal tab; hidden while typing so the
      // keyboard keeps the room.
      bottomNavigationBar: (profileAsync.hasValue && tab == ProfileTab.personal && !keyboardOpen) ? _saveBar() : null,
    );
  }

  Widget _title() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('My Profile', style: AppTextStyles.h4),
        const SizedBox(height: 2),
        Text('View and update your personal information', style: AppTextStyles.caption.copyWith(fontSize: 12)),
      ],
    );
  }

  Widget _saveBar() {
    return Material(
      color: AppColors.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: (_dirty && !_saving) ? _discard : null,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                    child: const Text('Discard'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _onSave,
                      icon: _saving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_outlined, size: 16),
                      label: Text(_saving ? 'Saving…' : 'Save Changes'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(0, 46),
                        textStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The profile's sections, in web's tab order.
enum ProfileTab {
  personal('Personal', Icons.account_circle_outlined),
  work('Work Info', Icons.work_outline),
  education('Education', Icons.school_outlined),
  bank('Bank Details', Icons.account_balance_outlined),
  documents('Documents', Icons.description_outlined),
  face('Face ID', Icons.face_outlined),
  security('Security', Icons.lock_outline);

  const ProfileTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Horizontally scrolling section chips (web's section sidebar, as a strip).
class ProfileTabStrip extends StatelessWidget {
  const ProfileTabStrip({super.key, required this.tabs, required this.selected, required this.onSelected});

  final List<ProfileTab> tabs;
  final ProfileTab selected;
  final ValueChanged<ProfileTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final t in tabs)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                button: true,
                selected: t == selected,
                label: t.label,
                child: ChoiceChip(
                  key: ValueKey('profile-tab-${t.name}'),
                  avatar: Icon(t.icon, size: 16, color: t == selected ? Colors.white : AppColors.textSecondary),
                  label: Text(t.label),
                  selected: t == selected,
                  showCheckmark: false,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  side: BorderSide(color: t == selected ? AppColors.primary : AppColors.border),
                  labelStyle: AppTextStyles.bodySmall.copyWith(
                    color: t == selected ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) => onSelected(t),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabStripDelegate extends SliverPersistentHeaderDelegate {
  _TabStripDelegate({required this.extent, required this.tabs, required this.selected, required this.onSelected});

  final double extent;
  final List<ProfileTab> tabs;
  final ProfileTab selected;
  final ValueChanged<ProfileTab> onSelected;

  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: ProfileTabStrip(tabs: tabs, selected: selected, onSelected: onSelected),
    );
  }

  @override
  bool shouldRebuild(covariant _TabStripDelegate old) => true;
}
