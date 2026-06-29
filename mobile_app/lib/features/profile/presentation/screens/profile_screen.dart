import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../widgets/profile_widgets.dart';
import '../widgets/profile_sections.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Personal info
  final _firstNameCtrl = TextEditingController(text: 'System');
  final _lastNameCtrl = TextEditingController(text: 'Admin');
  final _emailCtrl = TextEditingController(text: 'sysadmin@royal.com');
  final _phoneCtrl = TextEditingController(text: '+91 98765 43210');
  final _roleCtrl = TextEditingController(text: 'system_admin');
  final _userIdCtrl =
      TextEditingController(text: 'e662e137-e63c-4b86-a8da');

  // Password
  final _curPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _cfmPassCtrl = TextEditingController();

  // Address
  final _streetCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();

  // Bank
  final _bankNameCtrl = TextEditingController();
  final _acctNoCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _panCtrl = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _firstNameCtrl, _lastNameCtrl, _emailCtrl, _phoneCtrl,
      _roleCtrl, _userIdCtrl, _curPassCtrl, _newPassCtrl, _cfmPassCtrl,
      _streetCtrl, _cityCtrl, _pinCtrl, _stateCtrl, _countryCtrl,
      _bankNameCtrl, _acctNoCtrl, _ifscCtrl, _panCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _header()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              child: Column(
                children: [
                  _personalInfo(),
                  const SizedBox(height: 16),
                  _changePassword(),
                  const SizedBox(height: 16),
                  ProfileAddressSection(
                    streetCtrl: _streetCtrl,
                    cityCtrl: _cityCtrl,
                    pinCtrl: _pinCtrl,
                    stateCtrl: _stateCtrl,
                    countryCtrl: _countryCtrl,
                  ),
                  const SizedBox(height: 16),
                  ProfileBankSection(
                    bankNameCtrl: _bankNameCtrl,
                    acctNoCtrl: _acctNoCtrl,
                    ifscCtrl: _ifscCtrl,
                    panCtrl: _panCtrl,
                  ),
                  const SizedBox(height: 16),
                  const ProfileDocumentsSection(),
                ],
              ),
            ),
          ),
        ],
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
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Changes saved successfully')),
            ),
            icon: const Icon(Icons.save_outlined, size: 15),
            label: const Text('Save Changes'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _personalInfo() {
    return ProfileSectionCard(
      icon: Icons.manage_accounts_outlined,
      title: 'Personal Information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + name row
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.primary,
                child: Text(
                  'SA',
                  style: AppTextStyles.h3.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('System Admin',
                        style: AppTextStyles.label.copyWith(
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('system_admin',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.upload_outlined, size: 13),
                      label: const Text('Change photo'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        textStyle: const TextStyle(fontSize: 11),
                        side: const BorderSide(color: AppColors.border),
                        foregroundColor: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ProfileFieldRow(
            left: ProfileField(label: 'First Name', controller: _firstNameCtrl),
            right: ProfileField(label: 'Last Name', controller: _lastNameCtrl),
          ),
          const SizedBox(height: 12),
          ProfileFieldRow(
            left: ProfileField(
                label: 'Email',
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress),
            right: ProfileField(
                label: 'Phone',
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone),
          ),
          const SizedBox(height: 12),
          ProfileFieldRow(
            left: ProfileField(
                label: 'Role', controller: _roleCtrl, readOnly: true),
            right: ProfileField(
                label: 'User ID', controller: _userIdCtrl, readOnly: true),
          ),
        ],
      ),
    );
  }

  Widget _changePassword() {
    return ProfileSectionCard(
      icon: Icons.lock_outline,
      title: 'Change Password',
      child: Column(
        children: [
          ProfileField(
              label: 'Current Password',
              controller: _curPassCtrl,
              obscureText: true,
              hint: '••••••••'),
          const SizedBox(height: 12),
          ProfileFieldRow(
            left: ProfileField(
                label: 'New Password',
                controller: _newPassCtrl,
                obscureText: true,
                hint: '••••••••'),
            right: ProfileField(
                label: 'Confirm Password',
                controller: _cfmPassCtrl,
                obscureText: true,
                hint: '••••••••'),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.lock_outline, size: 13),
              label: const Text('Update Password'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                textStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

}
