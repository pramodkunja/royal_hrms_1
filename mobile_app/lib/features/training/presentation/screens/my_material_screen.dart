import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/blue_app_bar.dart';
import '../../../approvals/presentation/widgets/approvals_ui.dart';
import '../../data/models/training_models.dart';
import '../providers/training_office_opener.dart';
import '../providers/training_providers.dart';
import '../widgets/training_pdf_view.dart';
import '../widgets/training_video_player.dart';
import '../widgets/training_widgets.dart';
import 'training_course_screen.dart' show trainingLinkLauncherProvider;

/// One learning material (web my-learning MaterialViewer.tsx). The server
/// decides completion; this screen only reports what happened:
///  - open: sent once, when a material the app can show is opened (web
///    sends it when the viewer appears). Never completes anything.
///  - progress: playback reports for tracked videos (uploaded, YouTube,
///    direct links) — at most every 10 s, plus on play / pause / end. The
///    server completes the video at 90% of the length HR set.
///  - confirm: "I have read this" (documents, after the minimum reading
///    time) / "I have watched this" (untracked videos HR allows). Offered
///    only when web offers it (trainingCanConfirm).
/// Nothing is sent while the course is closed (failed assessment): content
/// is still shown, as on web. Opening the original link of an external
/// video sends nothing and completes nothing. PowerPoint / Word files are
/// opened in another app from a temporary private copy (HO-47).
class MyMaterialScreen extends ConsumerStatefulWidget {
  const MyMaterialScreen({super.key, required this.training, required this.material});
  final MyTraining training;
  final TrainingMaterial material;

  @override
  ConsumerState<MyMaterialScreen> createState() => _MyMaterialScreenState();
}

class _MyMaterialScreenState extends ConsumerState<MyMaterialScreen> {
  late TrainingMaterial _m = widget.material;
  bool _busy = false;
  String? _openError;
  String? _videoError;
  bool _sourceLoading = false;
  String? _sourceUrl;
  Timer? _tick;
  late final TrainingHeartbeat _heartbeat = TrainingHeartbeat(
    send: (p, d) => _post('progress', position: p, duration: d),
  );

  bool get _disabled => widget.training.isClosed;
  TrainingPlayerKind get _kind => trainingPlayerKind(_m);

  /// What the app can actually show (so "open" is only recorded for those).
  bool get _displayable => _m.isPdf || _kind != TrainingPlayerKind.none;

  @override
  void initState() {
    super.initState();
    if (_m.isUploadedVideo) _loadSource();
    if (_displayable && !_disabled && !_m.isOpened) _recordOpen();
    if (_m.isDocument && !_m.isCompleted) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _loadSource() async {
    setState(() => _sourceLoading = true);
    try {
      final url = await ref.read(trainingDatasourceProvider).fetchVideoSource(_m.id);
      if (!mounted) return;
      setState(() {
        _sourceUrl = url;
        if (url == null) _videoError = 'This video can only be played on the web app.';
      });
    } catch (e) {
      if (mounted) setState(() => _videoError = userFriendlyMessage(e));
    } finally {
      if (mounted) setState(() => _sourceLoading = false);
    }
  }

  Future<void> _recordOpen() async {
    try {
      await _post('open');
    } catch (e) {
      if (mounted) setState(() => _openError = userFriendlyMessage(e));
    }
  }

  /// POSTs one action and adopts the server's view of the material.
  Future<void> _post(String action, {double? position, double? duration}) async {
    if (_disabled) return;
    final r = await ref
        .read(trainingDatasourceProvider)
        .materialAction(widget.training.id, _m.id, action, position: position, duration: duration);
    if (!mounted) return;
    setState(() => _m = r.material);
    if (_m.isCompleted) _tick?.cancel();
  }

  void _onBeat(double position, double? duration, {bool force = false}) {
    if (_disabled || !_m.isTracked) return; // untracked videos: the server refuses reports
    _heartbeat.beat(position, duration, force: force);
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      await _post('confirm');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Marked as complete.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(userFriendlyMessage(e)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _officeBusy = false;

  /// HO-47: PowerPoint / Word. Like web (which records "open" when the
  /// material is shown and then offers the download), "open" is recorded
  /// when the employee opens the file — here on the explicit tap, before the
  /// hand-off — and "I have read this" follows the server's minimum time.
  Future<void> _openOffice() async {
    setState(() => _officeBusy = true);
    try {
      if (!_disabled && !_m.isOpened) await _recordOpen();
      final r = await ref.read(trainingOfficeOpenerProvider).open(_m.id, _m.fileFormat);
      final msg = trainingOfficeOpenMessage(r);
      if (msg.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(userFriendlyMessage(e)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _officeBusy = false);
    }
  }

  Future<void> _openOriginal() async {
    final uri = Uri.tryParse(_m.externalUrl);
    final ok = uri != null && uri.scheme == 'https' && await ref.read(trainingLinkLauncherProvider)(uri);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Could not open the video link.'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Widget _content(BuildContext context) {
    if (_m.isDocument) {
      if (_m.isPdf) {
        return SizedBox(
          key: const Key('my-material-pdf'),
          height: MediaQuery.sizeOf(context).height * 0.62,
          child: TrainingPdfView(materialId: _m.id, fileFormat: _m.fileFormat),
        );
      }
      if (!TrainingOfficeOpener.supports(_m.fileFormat)) {
        return Text('This file type can\'t be opened on mobile — open the course on the web app.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary));
      }
      return Column(
        key: const Key('my-material-office'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_m.fileFormat.toUpperCase()} files open in PowerPoint / Word. Open it, read it, then come back '
            'to confirm.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('my-material-open-office'),
            style: trainingOutlinedStyle(),
            onPressed: _officeBusy ? null : _openOffice,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(_officeBusy ? 'Opening…' : 'Open in another app'),
          ),
        ],
      );
    }
    if (_videoError != null) {
      return TrainingBanner(
        key: const Key('my-material-video-error'),
        text: _videoError!,
        icon: Icons.error_outline,
        color: AppColors.error,
        background: AppColors.errorContainer,
      );
    }
    if (_m.isUploadedVideo && (_sourceLoading || _sourceUrl == null)) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (_kind == TrainingPlayerKind.none) {
      return Text('This video type is not supported.', style: TextStyle(color: AppColors.textSecondary));
    }
    return KeyedSubtree(
      key: const Key('my-material-player'),
      child: ref.read(trainingVideoPlayerBuilderProvider)(
        material: _m,
        sourceUrl: _sourceUrl,
        onBeat: _onBeat,
        onError: (msg) {
          if (mounted) setState(() => _videoError = msg);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final done = _m.isCompleted;
    final wait = trainingSecondsUntilConfirm(_m, DateTime.now());
    final showConfirm = !done && !_disabled && trainingCanConfirm(_m);
    final icon = _m.isDocument
        ? Icons.description_outlined
        : (_m.isUploadedVideo ? Icons.videocam_outlined : Icons.smart_display_outlined);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: BlueAppBar(title: _m.title),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          TrainingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!trainingCompact(context)) ...[
                      ApprovalsIconBox(icon, color: done ? AppColors.success : AppColors.primary, size: 40),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_m.title, style: AppTextStyles.label.copyWith(fontSize: 15, fontWeight: FontWeight.w700, height: 1.3)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              TrainingBadge(
                                key: const Key('my-material-hint'),
                                label: trainingMaterialHint(_m),
                                color: done ? AppColors.success : AppColors.info,
                              ),
                              Text('${_m.kindLabel}${_m.isRequired ? '' : ' · optional'}',
                                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_m.description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(_m.description, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.45)),
                ],
              ],
            ),
          ),
          if (_disabled)
            TrainingBanner(
              key: const Key('my-material-closed'),
              text: 'This training is closed — progress is not recorded. HR can reset your attempts.',
              icon: Icons.block,
              color: AppColors.error,
              background: AppColors.errorContainer,
            ),
          if (_openError != null)
            TrainingBanner(
              key: const Key('my-material-open-error'),
              text: _openError!,
              icon: Icons.error_outline,
              color: AppColors.error,
              background: AppColors.errorContainer,
            ),
          _content(context),
          if (_m.isExternal) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('my-material-open-original'),
              style: trainingOutlinedStyle(),
              onPressed: _openOriginal,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(
                _m.isTracked
                    ? 'Video not playing? Open the original (progress is only recorded here)'
                    : 'Video not playing? Open the original',
                textAlign: TextAlign.center,
              ),
            ),
          ],
          if (showConfirm) ...[
            const SizedBox(height: 16),
            if (wait > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Available in ${formatTrainingDuration(wait)}',
                    key: const Key('my-material-wait'),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              ),
            FilledButton.icon(
              key: const Key('my-material-confirm'),
              style: trainingFilledStyle(),
              onPressed: _busy || wait > 0 ? null : _confirm,
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: Text(_m.isDocument ? 'I have read this' : 'I have watched this'),
            ),
          ],
        ],
      ),
    );
  }
}
