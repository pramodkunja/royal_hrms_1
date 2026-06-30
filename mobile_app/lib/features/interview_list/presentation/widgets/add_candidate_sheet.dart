import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/api_constants.dart';
import '../providers/interview_providers.dart';

part 'add_candidate_form.dart';

class AddCandidateSheet extends ConsumerStatefulWidget {
  const AddCandidateSheet({super.key});

  @override
  ConsumerState<AddCandidateSheet> createState() =>
      _AddCandidateSheetState();
}

class _AddCandidateSheetState
    extends ConsumerState<AddCandidateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _posCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  int? _selectedBranch;
  String _mode = 'in_person';
  DateTime? _interviewDate;
  bool _loading = false;
  List<Map<String, dynamic>> _branches = [];

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(ApiConstants.branches,
          queryParameters: {'page_size': 100});
      final data = res.data is Map ? res.data['data'] : res.data;
      final results =
          (data is Map ? data['results'] : data) as List<dynamic>;
      if (mounted) {
        setState(() {
          _branches = results
              .map((e) => {
                    'id': (e as Map<String, dynamic>)['id'],
                    'name': e['branch_name'] ?? '',
                  })
              .toList();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _emailCtrl,
      _posCtrl,
      _phoneCtrl,
      _notesCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBranch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a branch')),
      );
      return;
    }
    setState(() => _loading = true);
    final data = {
      'name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'position_applied': _posCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'branch': _selectedBranch,
      'interview_mode': _mode,
      if (_interviewDate != null)
        'interview_date':
            _interviewDate!.toIso8601String().split('T').first,
      if (_notesCtrl.text.trim().isNotEmpty)
        'notes': _notesCtrl.text.trim(),
    };
    final err = await _addCandidate(data);
    if (!mounted) return;
    setState(() => _loading = false);
    if (err == null) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(err), backgroundColor: AppColors.error),
      );
    }
  }

  Future<String?> _addCandidate(Map<String, dynamic> data) async {
    try {
      await ref
          .read(candidateListProvider.notifier)
          .addCandidate(data);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, ctrl) => Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 12),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Add Candidate to Interview List',
                        style: AppTextStyles.label
                            .copyWith(fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            // Form
            Expanded(
              child: _AddCandidateFormContent(
                formKey: _formKey,
                nameCtrl: _nameCtrl,
                emailCtrl: _emailCtrl,
                posCtrl: _posCtrl,
                phoneCtrl: _phoneCtrl,
                notesCtrl: _notesCtrl,
                selectedBranch: _selectedBranch,
                branches: _branches,
                mode: _mode,
                interviewDate: _interviewDate,
                loading: _loading,
                onSubmit: _submit,
                onCancel: () => Navigator.pop(context),
                onBranchChanged: (v) =>
                    setState(() => _selectedBranch = v),
                onModeChanged: (v) =>
                    setState(() => _mode = v ?? 'in_person'),
                onDateChanged: (v) =>
                    setState(() => _interviewDate = v),
                scrollCtrl: ctrl,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
