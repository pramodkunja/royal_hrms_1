import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

// Video preview for the Assessments item editor — web ItemsModal.tsx
// toEmbedUrl / VideoPreview / VideoLink. Web embeds YouTube/Vimeo in an iframe
// and plays any other URL in a <video> element. This app has no web-view or
// video-player plugin, so the preview recognises the source exactly as web
// does and "Play video" opens it in the YouTube/Vimeo app or the browser
// (not inline playback — a documented difference). The URL is used as typed;
// nothing is fetched except a YouTube thumbnail image.

/// Web toEmbedUrl, rule for rule (same order, same patterns).
String? assessmentVideoEmbedUrl(String url) {
  if (url.isEmpty) return null;
  final yt1 = RegExp(r'youtu\.be/([^?&/]+)').firstMatch(url);
  if (yt1 != null) return 'https://www.youtube.com/embed/${yt1.group(1)}';
  final yt2 = RegExp(r'[?&]v=([^?&]+)').firstMatch(url);
  if (yt2 != null) return 'https://www.youtube.com/embed/${yt2.group(1)}';
  final vim = RegExp(r'vimeo\.com/(\d+)').firstMatch(url);
  if (vim != null) return 'https://player.vimeo.com/video/${vim.group(1)}';
  return null;
}

enum AssessmentVideoSource { none, youtube, vimeo, file, invalid }

/// The URL as the item will be saved: a link typed without a scheme gets
/// "https://" (AssessmentItemFormData.toJson does the same on save).
String assessmentVideoPlayableUrl(String url) {
  final u = url.trim();
  if (u.isEmpty) return u;
  return RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(u) ? u : 'https://$u';
}

/// What web would render for [url]: nothing (empty), the YouTube / Vimeo
/// player, or a plain video element ("file"). A value that isn't an http(s)
/// link can't play anywhere — shown as invalid here.
AssessmentVideoSource assessmentVideoSource(String url) {
  final u = url.trim();
  if (u.isEmpty) return AssessmentVideoSource.none;
  final embed = assessmentVideoEmbedUrl(u);
  if (embed != null) {
    return embed.contains('youtube.com') ? AssessmentVideoSource.youtube : AssessmentVideoSource.vimeo;
  }
  final uri = Uri.tryParse(assessmentVideoPlayableUrl(u));
  if (uri == null ||
      !(uri.scheme == 'http' || uri.scheme == 'https') ||
      uri.host.isEmpty ||
      RegExp(r'\s').hasMatch(u)) {
    return AssessmentVideoSource.invalid;
  }
  return AssessmentVideoSource.file;
}

/// Web VideoLink label: "Watch video" for an embeddable link, else the URL
/// (shortened to 48 characters + "…").
String assessmentVideoLinkLabel(String url) {
  if (assessmentVideoEmbedUrl(url) != null) return 'Watch video';
  return url.length > 48 ? '${url.substring(0, 48)}…' : url;
}

/// Opens a video outside the app. Tests override it.
final assessmentVideoOpenerProvider = Provider<Future<bool> Function(Uri uri)>(
  (ref) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

Future<void> _open(BuildContext context, WidgetRef ref, String url) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final uri = Uri.tryParse(assessmentVideoPlayableUrl(url));
  var ok = false;
  if (uri != null) {
    try {
      ok = await ref.read(assessmentVideoOpenerProvider)(uri);
    } catch (_) {
      ok = false;
    }
  }
  if (!ok) {
    messenger?.showSnackBar(const SnackBar(
      content: Text('Could not open the video.'),
      behavior: SnackBarBehavior.floating,
    ));
  }
}

/// Shown under the Video URL field while typing (web VideoPreview).
class AssessmentVideoPreview extends ConsumerWidget {
  const AssessmentVideoPreview({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = assessmentVideoSource(url);
    if (source == AssessmentVideoSource.none) return const SizedBox.shrink();
    if (source == AssessmentVideoSource.invalid) {
      return Padding(
        key: const Key('video-preview-invalid'),
        padding: const EdgeInsets.only(top: 8),
        child: Text('This doesn\'t look like a valid video link.',
            style: AppTextStyles.caption.copyWith(color: AppColors.error)),
      );
    }
    final label = switch (source) {
      AssessmentVideoSource.youtube => 'YouTube video',
      AssessmentVideoSource.vimeo => 'Vimeo video',
      _ => 'Video file',
    };
    final ytId = source == AssessmentVideoSource.youtube
        ? assessmentVideoEmbedUrl(url.trim())!.split('/embed/').last
        : null;
    return Container(
      key: Key('video-preview-${source.name}'),
      margin: const EdgeInsets.only(top: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (ytId != null)
              Image.network(
                'https://img.youtube.com/vi/$ytId/hqdefault.jpg',
                key: const Key('video-preview-thumbnail'),
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)),
                // No thumbnail (offline, private video…) — the card still works.
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            Container(color: Colors.black.withValues(alpha: 0.35)),
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                FilledButton.icon(
                  key: const Key('video-preview-play'),
                  onPressed: () => _open(context, ref, url),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Play video'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black87),
                ),
                const SizedBox(height: 6),
                Text(label, style: AppTextStyles.caption.copyWith(color: Colors.white70)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// The link on a video item's row (web VideoLink).
class AssessmentVideoLink extends ConsumerWidget {
  const AssessmentVideoLink({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (url.isEmpty) return const SizedBox.shrink();
    return InkWell(
      onTap: () => _open(context, ref, url),
      child: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.open_in_new, size: 11, color: AppColors.primary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(assessmentVideoLinkLabel(url),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(fontSize: 11.5, color: AppColors.primary)),
          ),
        ]),
      ),
    );
  }
}
