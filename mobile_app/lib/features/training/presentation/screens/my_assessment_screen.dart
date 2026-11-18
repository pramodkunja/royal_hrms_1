import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../data/models/training_models.dart';
import '../providers/training_providers.dart';
import '../widgets/training_widgets.dart';

/// The course's linked assessment (web my-learning AssessmentPanel.tsx).
/// Questions, pass mark, attempt limit, time limit and scoring all come from
/// the server; this screen never scores anything. Start opens (or resumes) an
/// attempt; Submit sends {question id: option key}.
class MyAssessmentScreen extends ConsumerStatefulWidget {
  const MyAssessmentScreen({super.key, required this.assignmentId, required this.courseTitle});
  final String assignmentId;
  final String courseTitle;

  @override
  ConsumerState<MyAssessmentScreen> createState() => _MyAssessmentScreenState();
}

class _MyAssessmentScreenState extends ConsumerState<MyAssessmentScreen> {
  List<TrainingQuestion>? _questions;
  final Map<String, String> _answers = {};
  TrainingAssessmentResult? _result;
  bool _retake = false;
  bool _busy = false;

  void _snack(String msg, {Color? color}) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: color ?? AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
      ));

  Future<void> _start(TrainingAssessmentState state) async {
    setState(() {
      _busy = true;
      _result = null;
      _retake = state.passed == true;
    });
    try {
      final attempt = await ref.read(trainingDatasourceProvider).startAssessment(widget.assignmentId);
      if (!mounted) return;
      setState(() {
        _questions = attempt.questions;
        _answers.clear();
      });
    } catch (e) {
      if (mounted) _snack(userFriendlyMessage(e), color: AppColors.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit(TrainingAssessmentState state) async {
    final qs = _questions;
    if (qs == null) return;
    final missing = qs.where((q) => !_answers.containsKey(q.id)).length;
    if (missing > 0) {
      final ok = await confirmTrainingAction(
        context,
        title: 'Submit assessment?',
        message: '$missing question(s) unanswered. Submit anyway?',
        confirmLabel: 'Submit',
      );
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final r = await ref.read(trainingDatasourceProvider).submitAssessment(widget.assignmentId, Map.of(_answers));
      if (!mounted) return;
      setState(() {
        _result = r;
        _questions = null;
      });
      if (_retake) {
        final best = [state.bestScorePercent ?? 0, r.percentage].reduce((a, b) => a > b ? a : b);
        _snack('Retake score ${r.percentage}% — your best score is $best%.', color: AppColors.info);
      } else {
        _snack(
          r.passed ? 'Passed — ${r.percentage}%' : 'Not passed — ${r.percentage}% (pass mark ${r.passPercentage}%)',
          color: r.passed ? AppColors.success : AppColors.error,
        );
      }
      ref.invalidate(myTrainingDetailProvider(widget.assignmentId));
      ref.invalidate(myTrainingListProvider);
    } catch (e) {
      if (mounted) _snack(userFriendlyMessage(e), color: AppColors.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Leaving mid-attempt: answers are not saved (the attempt stays open on
  /// the server and resumes on the next Start).
  Future<bool> _confirmLeave() async {
    if (_questions == null) return true;
    return confirmTrainingAction(
      context,
      title: 'Leave the assessment?',
      message: 'Your answers have not been submitted and will be lost.',
      confirmLabel: 'Leave',
      destructive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(myTrainingDetailProvider(widget.assignmentId));
    final state = detailAsync.valueOrNull?.assessment;

    return PopScope(
      canPop: _questions == null,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) {
          setState(() => _questions = null);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
            title:
                Text(state?.title.isNotEmpty == true ? state!.title : 'Assessment', overflow: TextOverflow.ellipsis)),
        body: state == null
            ? (detailAsync.hasError
                ? AppErrorState.forError(detailAsync.error!,
                    onRetry: () => ref.invalidate(myTrainingDetailProvider(widget.assignmentId)))
                : Center(child: CircularProgressIndicator(color: AppColors.primary)))
            : ListView(
                key: const Key('my-assessment'),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  Text(
                    [
                      'Pass mark ${state.passPercentage}%',
                      state.attemptsText,
                      if (state.timeLimitMins != null && state.timeLimitMins! > 0)
                        '${state.timeLimitMins} minute time limit',
                    ].join(' · '),
                    key: const Key('my-assessment-meta'),
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  if (_result != null) _resultBanner(state, _result!),
                  if (_questions == null) ..._intro(state) else ..._questionList(state),
                ],
              ),
      ),
    );
  }

  Widget _resultBanner(TrainingAssessmentState state, TrainingAssessmentResult r) {
    final best = [state.bestScorePercent ?? 0, r.percentage].reduce((a, b) => a > b ? a : b);
    final (text, color, bg) = _retake
        ? (
            'Retake score ${r.percentage}%. Your best score is $best% — the course stays completed.',
            AppColors.info,
            AppColors.infoContainer
          )
        : (
            '${r.passed ? 'Passed' : 'Not passed'} — ${r.percentage}% (pass mark ${r.passPercentage}%).',
            r.passed ? AppColors.success : AppColors.error,
            r.passed ? AppColors.successContainer : AppColors.errorContainer,
          );
    return Container(
      key: const Key('my-assessment-result'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
    );
  }

  List<Widget> _intro(TrainingAssessmentState s) {
    final notice = TextStyle(fontSize: 13, color: AppColors.textSecondary);
    return [
      if (s.passed == true) ...[
        Text('You passed — best score ${s.bestScorePercent ?? 0}%.',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.success)),
        if (s.canRetake)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Optional: retake it to improve your score'
              '${s.attemptsLeft != null ? ' (${s.attemptsLeft} retake${s.attemptsLeft == 1 ? '' : 's'} left)' : ''}. '
              'Your best score is kept and the course stays completed.',
              style: notice,
            ),
          ),
        const SizedBox(height: 10),
      ],
      if (!s.hasQuestions)
        Text('This assessment has no questions yet — contact HR.', key: const Key('my-assessment-noq'), style: notice),
      if (s.passed != true && !s.unlocked && s.hasQuestions)
        Text('Complete the required learning materials to unlock it.',
            key: const Key('my-assessment-locked'), style: notice),
      if (s.passed != true && s.unlocked && !s.canAttempt && s.hasQuestions && s.startsOn == null)
        Text('No attempts left. HR can reset your attempts.',
            key: const Key('my-assessment-no-attempts'), style: notice),
      if (s.lastResult != null && _result == null && s.passed != true)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Last attempt: ${s.lastResult!.percentage}%.', style: notice),
        ),
      if (s.canAttempt) ...[
        const SizedBox(height: 14),
        FilledButton(
          key: const Key('my-assessment-start'),
          onPressed: _busy ? null : () => _start(s),
          child: Text(_busy
              ? 'Starting…'
              : s.passed == true
                  ? 'Retake to improve score'
                  : (s.attemptsUsed > 0 ? 'Try again' : 'Start assessment')),
        ),
      ],
    ];
  }

  List<Widget> _questionList(TrainingAssessmentState s) => [
        for (final (i, q) in _questions!.indexed)
          TrainingCard(
            key: Key('my-assessment-q-${q.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${i + 1}. ${q.question}${q.section.isNotEmpty ? ' · ${q.section}' : ''}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                RadioGroup<String>(
                  groupValue: _answers[q.id],
                  onChanged: (v) => setState(() => v == null ? _answers.remove(q.id) : _answers[q.id] = v),
                  child: Column(
                    children: [
                      for (final o in q.options)
                        RadioListTile<String>(
                          key: Key('my-assessment-opt-${q.id}-${o.key}'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: o.key,
                          title: Text(o.text, style: const TextStyle(fontSize: 13)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            key: const Key('my-assessment-submit'),
            onPressed: _busy ? null : () => _submit(s),
            child: Text(_busy ? 'Submitting…' : 'Submit'),
          ),
        ),
      ];
}
