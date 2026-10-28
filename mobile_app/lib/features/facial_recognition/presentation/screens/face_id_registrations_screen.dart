import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/blue_hero_banner.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/face_employee_entity.dart';
import '../../domain/entities/face_registration_entity.dart';
import '../providers/facial_recognition_providers.dart';
import '../widgets/face_capture_bottom_sheet.dart';
import '../widgets/face_consent_text.dart';
import '../widgets/face_status_badge.dart';

/// HR-assisted registration — HR captures an employee's face in person and
/// it's approved immediately (mirrors web's app/dashboard/face-id-registrations/page.tsx).
/// Gated on the same `facial_recognition.approve` permission the backend
/// checks (see apps/attendance/views/face_registration_hr.py::_has_perm).
class FaceIdRegistrationsScreen extends ConsumerStatefulWidget {
  const FaceIdRegistrationsScreen({super.key});

  @override
  ConsumerState<FaceIdRegistrationsScreen> createState() => _FaceIdRegistrationsScreenState();
}

class _FaceIdRegistrationsScreenState extends ConsumerState<FaceIdRegistrationsScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<FaceEmployeeEntity> _employees = [];
  bool _loadingEmployees = false;

  FaceEmployeeEntity? _selected;
  FaceRegistrationEntity? _status;
  bool _loadingStatus = false;
  bool _registering = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() => _loadingEmployees = true);
    try {
      final results = await ref.read(facialRecognitionRepositoryProvider).searchEmployees(query);
      if (!mounted) return;
      setState(() => _employees = results);
    } catch (_) {
      if (!mounted) return;
      setState(() => _employees = []);
    } finally {
      if (mounted) setState(() => _loadingEmployees = false);
    }
  }

  Future<void> _selectEmployee(FaceEmployeeEntity employee) async {
    setState(() {
      _selected = employee;
      _status = null;
      _loadingStatus = true;
    });
    try {
      final status =
          await ref.read(facialRecognitionRepositoryProvider).getEmployeeStatus(employee.uuid);
      if (!mounted) return;
      setState(() => _status = status);
    } finally {
      if (mounted) setState(() => _loadingStatus = false);
    }
  }

  Future<void> _handleRegisterTap() async {
    if (_status?.status == FaceRegistrationStatus.approved) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Replace existing Face ID?'),
          content: Text(
            '${_selected?.fullName ?? "This employee"} already has an approved Face ID. '
            'Capturing a new one will replace it immediately.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Replace')),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await _openCapture();
  }

  Future<void> _openCapture() async {
    final employee = _selected;
    if (employee == null || !mounted) return;

    final result = await showFaceCaptureSheet(
      context,
      title: 'Register Face ID',
      subtitle: employee.fullName,
      consentNoticeText: kFaceConsentNoticeHr,
    );
    if (result?.captured.embedding == null || !mounted) return;

    setState(() => _registering = true);
    try {
      final registration = await ref.read(facialRecognitionRepositoryProvider).hrRegister(
            employeeUuid: employee.uuid,
            faceEmbedding: result!.captured.embedding!,
            livenessPassed: result.captured.livenessPassed,
            livenessScore: result.captured.livenessScore,
            consentAcknowledged: result.consentAcknowledged,
          );
      if (!mounted) return;
      setState(() => _status = registration);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Face ID registered for ${employee.fullName}.'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not register Face ID: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final canRegister = user?.hasPermission('facial_recognition.approve') ?? false;

    if (!canRegister) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 44, color: AppColors.textHint),
                const SizedBox(height: 12),
                Text(
                  "You don't have permission to manage face ID registrations.",
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Contact an HR administrator if you believe this is a mistake.',
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            BlueHeroBanner(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Face ID Registrations',
                      style: AppTextStyles.h4.copyWith(color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(
                    'Register or update an employee\'s face ID in person — approved immediately.',
                    style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    decoration: heroSearchFieldDecoration(hintText: 'Search by name, email or ID…'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Deliberately no AnimatedSwitcher here — it lays children out
            // inside a Stack, which hands non-positioned children LOOSE
            // constraints instead of tight ones. A scrollable (ListView /
            // SingleChildScrollView) given loose width constraints shrinks
            // to its own intrinsic width instead of filling the screen,
            // which is exactly what showed up as a centered card with gaps
            // down both sides. Expanded gives its child tight constraints
            // directly, so this fills the full width unconditionally.
            Expanded(
              child: _selected == null ? _employeeList() : _statusPanel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _employeeList() {
    if (_loadingEmployees) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_employees.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_search_outlined, size: 40, color: AppColors.textHint),
              const SizedBox(height: 10),
              Text('No employees match.', style: AppTextStyles.caption),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _employees.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final employee = _employees[index];
        return Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _selectEmployee(employee),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
              child: Row(
                children: [
                  FaceInitialsAvatar(name: employee.fullName),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employee.fullName,
                          style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [employee.employeeId, employee.email, if (employee.branch != null) employee.branch!]
                              .where((s) => s.isNotEmpty)
                              .join(' · '),
                          style: AppTextStyles.caption.copyWith(fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.textHint),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _statusPanel() {
    final employee = _selected!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => setState(() => _selected = null),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Back to search'),
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FaceInitialsAvatar(name: employee.fullName, size: 48),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(employee.fullName, style: AppTextStyles.h4),
                          const SizedBox(height: 2),
                          Text(
                            [employee.employeeId, employee.email, if (employee.department != null) employee.department!]
                                .where((s) => s.isNotEmpty)
                                .join(' · '),
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('Face ID Status', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    if (_loadingStatus)
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      FaceStatusBadge(status: _status?.status),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: (_loadingStatus || _registering) ? null : _handleRegisterTap,
                    icon: _registering
                        ? const SizedBox(
                            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.camera_alt_outlined),
                    label: Text(_status?.status == FaceRegistrationStatus.approved ? 'Update Face ID' : 'Register Face ID'),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
