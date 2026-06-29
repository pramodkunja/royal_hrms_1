import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'profile_widgets.dart';

class ProfileAddressSection extends StatelessWidget {
  final TextEditingController streetCtrl;
  final TextEditingController cityCtrl;
  final TextEditingController pinCtrl;
  final TextEditingController stateCtrl;
  final TextEditingController countryCtrl;

  const ProfileAddressSection({
    super.key,
    required this.streetCtrl,
    required this.cityCtrl,
    required this.pinCtrl,
    required this.stateCtrl,
    required this.countryCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      icon: Icons.location_on_outlined,
      title: 'Address',
      child: Column(
        children: [
          ProfileField(
            label: 'Street Address',
            controller: streetCtrl,
            hint: 'e.g. 42, 3rd Cross, HSR Layout',
          ),
          const SizedBox(height: 12),
          ProfileFieldRow(
            left: ProfileField(
                label: 'City', controller: cityCtrl, hint: 'City'),
            right: ProfileField(
                label: 'PIN Code',
                controller: pinCtrl,
                hint: 'PIN Code',
                keyboardType: TextInputType.number),
          ),
          const SizedBox(height: 12),
          ProfileFieldRow(
            left: ProfileField(
                label: 'State', controller: stateCtrl, hint: 'State'),
            right: ProfileField(
                label: 'Country',
                controller: countryCtrl,
                hint: 'Country'),
          ),
        ],
      ),
    );
  }
}

class ProfileBankSection extends StatelessWidget {
  final TextEditingController bankNameCtrl;
  final TextEditingController acctNoCtrl;
  final TextEditingController ifscCtrl;
  final TextEditingController panCtrl;

  const ProfileBankSection({
    super.key,
    required this.bankNameCtrl,
    required this.acctNoCtrl,
    required this.ifscCtrl,
    required this.panCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      icon: Icons.account_balance_outlined,
      title: 'Bank Details',
      child: Column(
        children: [
          ProfileFieldRow(
            left: ProfileField(
                label: 'Bank Name',
                controller: bankNameCtrl,
                hint: 'e.g. HDFC Bank'),
            right: ProfileField(
                label: 'Account Number',
                controller: acctNoCtrl,
                hint: 'Account number'),
          ),
          const SizedBox(height: 12),
          ProfileFieldRow(
            left: ProfileField(
                label: 'IFSC Code',
                controller: ifscCtrl,
                hint: 'e.g. HDFC0001234'),
            right: ProfileField(
                label: 'PAN Number',
                controller: panCtrl,
                hint: 'e.g. ABCDE1234F'),
          ),
        ],
      ),
    );
  }
}

class ProfileDocumentsSection extends StatelessWidget {
  const ProfileDocumentsSection({super.key});

  static const _docs = [
    'Aadhaar Card',
    'PAN Card',
    'Degree Certificate',
    'Offer Letter',
  ];

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      icon: Icons.folder_outlined,
      title: 'Documents',
      child: Column(
        children: [
          for (var i = 0; i < _docs.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            ProfileDocumentItem(name: _docs[i]),
          ],
        ],
      ),
    );
  }
}
