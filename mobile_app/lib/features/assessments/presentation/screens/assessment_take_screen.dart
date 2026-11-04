import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../data/models/assessment_portal_models.dart';
import '../../data/models/my_assessment_model.dart';
import '../assessment_take_rules.dart';
import '../providers/assessment_take_providers.dart';
import '../providers/assessments_providers.dart';
import '../providers/my_assessments_providers.dart';
import '../widgets/assessment_instructions_view.dart';
import '../widgets/assessment_item_view.dart';
import '../widgets/assessment_result_view.dart';
import '../widgets/my_assessment_card.dart';

/// Opens a video item outside the app. Overridable in tests.
final assessmentVideoOpenerProvider =
    Provider<Future<void> Function(String url)>((ref) => (url) async {
          final uri = Uri.tryParse(url);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        });

/// Taking one assessment: instructions → items in order → the server's
/// result, with retake when allowed (web: app/onboarding/assessments).
/// Every response is saved on the server as it is submitted.
class AssessmentTakeScreen extends ConsumerStatefulWidget {
  final String assignmentId;
  const AssessmentTakeScreen({super.key, required this.assignmentId});

  @override
  ConsumerState<AssessmentTakeScreen> createState() =>
      _AssessmentTakeScreenState();
}

class _AssessmentTakeScreenState extends ConsumerState<AssessmentTakeScreen> {
  bool _started = false;
  int? _index;
  // Kept per item id, so list refreshes never reset an employee's work.
  final _picked = <String, String>{}; // chosen, not yet submitted
  final _saved = <String, AssessmentItemResponse>{}; // confirmed by the server
  bool _saving = false;
  String? _itemError;
  bool _completing = false;
  AssessmentCompleteResult? _result;
  bool _retrying = false;
  String? _retakeError;
  Timer? _ticker;
  int? _remaining;
  bool _autoSubmitted = false;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  AssessmentItemResponse? _responseFor(
          MyAssessmentAssignment a, String itemId) =>
      a.responseFor(itemId) ?? _saved[itemId];

  bool _done(MyAssessmentAssignment a, AssessmentPortalItem item) =>
      a.isItemDone(item) || _saved.containsKey(item.id);

  void _startTimerIfNeeded(MyAssessmentAssignment a) {
    if (_ticker != null || a.isComplete || a.timeRemainingSecs == null) return;
    _remaining = a.timeRemainingSecs;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining = (_remaining ?? 0) - 1);
      if ((_remaining ?? 1) <= 0 && !_autoSubmitted && _result == null) {
        _autoSubmitted = true; // time is up: submit once, as web does
        _ticker?.cancel();
        _complete();
      }
    });
  }

  Future<void> _save(
      MyAssessmentAssignment a, AssessmentPortalItem item) async {
    if (_saving) return;
    final option =
        item.type == AssessmentItemType.quiz ? _picked[item.id] : null;
    if (item.type == AssessmentItemType.quiz && option == null) return;
    setState(() {
      _saving = true;
      _itemError = null;
    });
    try {
      final r = await ref
          .read(assessmentActionsProvider)
          .respond(a.id, item.id, selectedOption: option);
      if (!mounted) return;
      setState(() => _saved[item.id] = AssessmentItemResponse(
            itemId: item.id,
            isWatched: item.type == AssessmentItemType.video,
            selectedOption: option ?? '',
            isCorrect: r.isCorrect,
            scoreAwarded: r.scoreAwarded,
          ));
    } catch (e) {
      // The picked option stays selected so the employee can simply retry.
      if (mounted) setState(() => _itemError = friendlyAssessmentError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmAndComplete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit assessment?'),
        content: const Text(
            'Your score will be calculated now. You can\'t change your answers after submitting.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit')),
        ],
      ),
    );
    if (ok == true) await _complete();
  }

  Future<void> _complete() async {
    if (_completing || _result != null) return;
    setState(() {
      _completing = true;
      _itemError = null;
    });
    try {
      final r = await ref
          .read(assessmentActionsProvider)
          .complete(widget.assignmentId);
      if (!mounted) return;
      _ticker?.cancel();
      setState(() => _result = r);
      await ref.read(assessmentGateSyncProvider)();
    } catch (e) {
      if (mounted) setState(() => _itemError = friendlyAssessmentError(e));
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  Future<void> _retake() async {
    if (_retrying) return;
    setState(() {
      _retrying = true;
      _retakeError = null;
    });
    try {
      await ref.read(assessmentActionsProvider).retry(widget.assignmentId);
      if (!mounted) return;
      _ticker?.cancel();
      setState(() {
        _ticker = null;
        _remaining = null;
        _autoSubmitted = false;
        _result = null;
        _started = false;
        _index = null;
        _picked.clear();
        _saved.clear();
      });
    } catch (e) {
      if (mounted) setState(() => _retakeError = friendlyAssessmentError(e));
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  void _leave() =>
      context.canPop() ? context.pop() : context.go(AppRoutes.myAssessments);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myAssessmentsProvider);
    MyAssessmentAssignment? a;
    for (final x
        in async.valueOrNull?.assignments ?? const <MyAssessmentAssignment>[]) {
      if (x.id == widget.assignmentId) a = x;
    }
    if (a != null) _startTimerIfNeeded(a);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(a?.title ?? 'Assessment', overflow: TextOverflow.ellipsis),
        actions: [
          if (_remaining != null &&
              _result == null &&
              !(a?.isComplete ?? false))
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(formatCountdown(_remaining!),
                    key: const Key('assessment-timer'),
                    style: AppTextStyles.labelLarge.copyWith(
                        color: (_remaining ?? 0) <= 60
                            ? AppColors.error
                            : AppColors.textPrimary)),
              ),
            ),
        ],
      ),
      body: a != null
          ? _body(a)
          : async.hasError
              ? AppErrorState(
                  title: 'Could not load the assessment',
                  message: friendlyAssessmentError(async.error!),
                  onRetry: () => ref.invalidate(myAssessmentsProvider),
                )
              : async.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : const AppErrorState(
                      title: 'Assessment not found',
                      message: 'This assessment is no longer assigned to you.'),
    );
  }

  Widget _body(MyAssessmentAssignment a) {
    final now = ref.read(assessmentClockProvider)();
    if (_result != null || a.isComplete) {
      final r = _result;
      return AssessmentResultView(
        title: a.title,
        score: r?.score ?? a.score,
        maxScore: r?.maxScore ?? a.maxScore,
        percentage: r?.scorePercentage ?? a.scorePercent,
        passPercentage: r?.passPercentage ?? a.passPercentage,
        passed: r?.passed ?? a.passed,
        attemptNumber: a.attemptCount,
        completedOn: r == null && a.completedAt != null
            ? formatAssessmentDate(a.completedAt)
            : null,
        // Shown once the refreshed list confirms the attempt is complete and
        // the server's attempt count still allows another.
        onRetake: canRetry(a, now, passed: r?.passed) ? _retake : null,
        retaking: _retrying,
        retakeError: _retakeError,
        doneLabel: 'Done',
        onDone: _leave,
      );
    }
    final fresh = a.status == MyAssessmentStatus.pending &&
        a.responses.isEmpty &&
        _saved.isEmpty;
    if (!_started && fresh) {
      return AssessmentInstructionsView(
        assignment: a,
        blockedReason: startBlockedReason(a, now),
        onStart: () => setState(() {
          _started = true;
          _index = 0;
        }),
      );
    }
    final items = a.orderedItems;
    if (items.isEmpty) {
      return const AppErrorState(
          title: 'No items', message: 'This assessment has no items.');
    }
    final i = (_index ?? resumeIndex(a)).clamp(0, items.length - 1);
    final item = items[i];
    final done = _done(a, item);
    final allDone = items.every((it) => _done(a, it));
    return AssessmentItemView(
      key: ValueKey(item.id),
      item: item,
      index: i,
      total: items.length,
      response: _responseFor(a, item.id),
      done: done,
      selected: _picked[item.id],
      onSelect: (k) => setState(() => _picked[item.id] = k),
      saving: _saving,
      error: _itemError,
      onSave: () => _save(a, item),
      onOpenVideo: () => ref.read(assessmentVideoOpenerProvider)(item.videoUrl),
      onPrevious: i > 0
          ? () => setState(() {
                _index = i - 1;
                _itemError = null;
              })
          : null,
      onNext: done && i < items.length - 1
          ? () => setState(() {
                _index = i + 1;
                _itemError = null;
              })
          : null,
      onSubmitAssessment: allDone ? _confirmAndComplete : null,
      submitting: _completing,
    );
  }
}
