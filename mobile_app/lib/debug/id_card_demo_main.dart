// DEBUG-ONLY demo of the Employee ID Card screen, for checking the native
// print / share path on an emulator without signing in or calling a server:
//
//   flutter run -d <emulator> -t lib/debug/id_card_demo_main.dart
//
// Every value below is synthetic. Nothing here is imported by lib/main.dart,
// so it is not part of the app's release build; in a non-debug build this
// entry point shows a notice and does nothing.

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/domain/entities/user_entity.dart';
import '../features/auth/presentation/controllers/auth_notifier.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/auth/presentation/states/auth_state.dart';
import '../features/employees/data/models/employee_id_card_model.dart';
import '../features/employees/presentation/id_card/id_card_pdf.dart';
import '../features/employees/presentation/id_card/id_card_text.dart';
import '../features/employees/presentation/providers/employee_providers.dart';
import '../features/employees/presentation/screens/employee_id_card_screen.dart';

const _demoUser = UserEntity(
  id: 'demo',
  email: 'demo@example.test',
  fullName: 'Demo Viewer',
  role: 'hr',
  roleDisplay: 'HR',
  mustChangePassword: false,
  permissions: ['employees.view'],
  onboardingStatus: 'complete',
  assessmentStatus: 'complete',
);

class _DemoAuth extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState(user: _demoUser);
}

const _company =
    IdCardCompany(name: 'Demo Company', website: 'demo.example', officeAddress: '1 Demo Road, Pune 411001');
const _card = IdCardConfig(
  terms: ['This card is the property of Demo Company.', 'If found, please return it to the address above.'],
  signatoryLabel: 'Authorised Signatory',
  showDateOfBirth: true,
  showResidentialAddress: true,
  showContactDetails: true,
);

final demoCards = <String, (String, IdCardData)>{
  'DEMO-EN': (
    'English',
    const IdCardData(
      employee: IdCardEmployee(
        employeeId: 'DEMO-EN',
        fullName: 'Nia Example',
        designation: 'QA Analyst',
        department: 'Quality',
        dateOfJoining: '05/01/2026',
        dateOfBirth: '01/02/1995',
        bloodGroup: 'O+',
        location: 'Pune',
        residentialAddress: '12 Sample Lane, Pune 411005',
        phone: '9000000000',
        email: 'nia@example.test',
      ),
      company: _company,
      card: _card,
      missing: ['Company logo', 'Employee photo'],
    ),
  ),
  'DEMO-HI': (
    'Devanagari (Hindi / Marathi)',
    const IdCardData(
      employee: IdCardEmployee(
        employeeId: 'DEMO-HI',
        fullName: 'अनन्या शर्मा',
        designation: 'गुणवत्ता विश्लेषक',
        department: 'गुणवत्ता',
        dateOfJoining: '05/01/2026',
        bloodGroup: 'B+',
        location: 'पुणे',
        residentialAddress: 'फ्लैट 12, शिवाजी नगर, पुणे, महाराष्ट्र 411005',
        phone: '9000000001',
        email: 'ananya@example.test',
      ),
      company: IdCardCompany(name: 'डेमो कंपनी', website: 'demo.example', officeAddress: '1 डेमो रोड, पुणे 411001'),
      card: IdCardConfig(
        terms: ['यह कार्ड डेमो कंपनी की संपत्ति है।', 'If found, please return it.'],
        signatoryLabel: 'अधिकृत हस्ताक्षरकर्ता',
        showResidentialAddress: true,
        showContactDetails: true,
      ),
    ),
  ),
  'DEMO-LONG': (
    'Long multilingual text',
    const IdCardData(
      employee: IdCardEmployee(
        employeeId: 'DEMO-LONG-000123',
        fullName: 'Venkata Subramanian Lakshminarayanan Raghavendra Krishnamurthy',
        designation: 'Senior Principal Quality Assurance Automation Engineer',
        department: 'Platform Quality Engineering and Release Management',
        dateOfJoining: '05/01/2026',
        dateOfBirth: '01/02/1995',
        bloodGroup: 'AB-',
        location: 'Hinjewadi Phase III, Pune / हिंजवडी, पुणे',
        residentialAddress: 'फ्लैट 1204, टावर बी, लॉन्ग रेजीडेंसी कॉम्प्लेक्स, बाणेर रोड, पुणे, महाराष्ट्र 411045 — '
            'Flat 1204, Tower B, Long Residency Complex, Baner Road, Pune, Maharashtra 411045',
        phone: '9000000002',
        email: 'venkata.subramanian.lakshminarayanan@example.test',
      ),
      company: IdCardCompany(
        name: 'Demo Company Private Limited',
        website: 'careers.demo-company-private-limited.example',
        officeAddress: 'Plot 77, Phase III, Hinjewadi Rajiv Gandhi Infotech Park, Maan, Mulshi, Pune 411057',
      ),
      card: IdCardConfig(
        terms: [
          'This card is the property of Demo Company and must be returned on separation.',
          'कार्ड गुम होने पर तुरंत एचआर को सूचित करें और नया कार्ड प्राप्त करें।',
          'The card holder must display this card at all times while on company premises.',
          'Misuse of this card may lead to disciplinary action as per company policy.',
        ],
        signatoryLabel: 'Authorised Signatory',
        showDateOfBirth: true,
        showResidentialAddress: true,
        showContactDetails: true,
      ),
    ),
  ),
};

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerIdCardFontLicenses();
  if (!kDebugMode) {
    runApp(const MaterialApp(
        home: Scaffold(body: Center(child: Text('ID card demo is available in debug builds only.')))));
    return;
  }
  runApp(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(_DemoAuth.new),
      employeeIdCardProvider.overrideWith((ref, id) async => demoCards[id]!.$2),
      // No server: the demo cards have no logo / photo / signature URLs.
      idCardImageLoaderProvider.overrideWithValue((_) async => null),
    ],
    child: MaterialApp(
      title: 'ID Card demo (debug)',
      debugShowCheckedModeBanner: true,
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('ID Card demo — synthetic data')),
          body: ListView(children: [
            for (final MapEntry(key: id, value: (label, _)) in demoCards.entries)
              ListTile(
                key: Key('demo-$id'),
                title: Text(label),
                subtitle: Text(id),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => EmployeeIdCardScreen(employeeId: id))),
              ),
          ]),
        ),
      ),
    ),
  ));
}
