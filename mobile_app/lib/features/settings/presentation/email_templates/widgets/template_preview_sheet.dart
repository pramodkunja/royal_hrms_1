import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../shared/widgets/blue_app_bar.dart';
import '../../../../approvals/presentation/widgets/approvals_kit.dart';
import '../../../../approvals/presentation/widgets/approvals_ui.dart';
import '../../../data/models/email_template_model.dart';
import '../../providers/settings_providers.dart';
import 'email_preview_html.dart';

/// What [TemplatePreviewScreen] pops with when the user taps "Edit Template".
/// Closing (button, back arrow, system back) pops null. The caller (the Email
/// Templates page) opens the editor when it receives [edit].
enum TemplatePreviewResult { edit }

/// Builds the rendered-email view for one HTML document. A provider so widget
/// tests can swap in a stand-in (a real WebView needs the platform).
typedef EmailPreviewViewBuilder = Widget Function(String html);

final emailPreviewViewBuilderProvider = Provider<EmailPreviewViewBuilder>(
  (ref) => (html) => EmailPreviewWebView(html: html),
);

/// The email as a sandboxed WebView: JavaScript off, every navigation after the
/// first load refused (links do nothing), content from [buildEmailPreviewHtml]
/// whose CSP also forbids scripts, frames, forms and external stylesheets.
class EmailPreviewWebView extends StatefulWidget {
  const EmailPreviewWebView({super.key, required this.html});
  final String html;

  @override
  State<EmailPreviewWebView> createState() => _EmailPreviewWebViewState();
}

class _EmailPreviewWebViewState extends State<EmailPreviewWebView> {
  late final WebViewController _controller;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setBackgroundColor(const Color(0xFFF4F4F7))
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (_) => _loaded ? NavigationDecision.prevent : NavigationDecision.navigate,
        onPageFinished: (_) => _loaded = true,
      ))
      ..loadHtmlString(widget.html);
  }

  @override
  void didUpdateWidget(EmailPreviewWebView old) {
    super.didUpdateWidget(old);
    if (old.html != widget.html) {
      // The company details arrived after the first paint: reload the new document.
      _loaded = false;
      _controller.loadHtmlString(widget.html);
    }
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);
}

class TemplatePreviewScreen extends ConsumerStatefulWidget {
  final EmailTemplateModel template;
  const TemplatePreviewScreen({super.key, required this.template});

  @override
  ConsumerState<TemplatePreviewScreen> createState() => _TemplatePreviewScreenState();
}

class _TemplatePreviewScreenState extends ConsumerState<TemplatePreviewScreen> {
  bool _rendered = true;
  bool? _detailsOpen; // null: open on roomy screens, closed on short / large-text ones

  EmailTemplateModel get _t => widget.template;

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text,
          style: AppTextStyles.caption.copyWith(
            fontSize: 11,
            color: AppColors.textHint,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      );

  Widget _nameLine(int? maxLines) => Text(
        _t.displayName,
        key: const Key('et-preview-name'),
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      );

  Widget _details() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _nameLine(null),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ApprovalsChip(_t.category ?? 'Email Template', icon: Icons.folder_outlined),
            ApprovalsBadge(
                _t.isActive ? 'Active' : 'Inactive', _t.isActive ? ApprovalsTone.success : ApprovalsTone.neutral),
            if (_t.isBuiltin) const ApprovalsChip('Built-in', icon: Icons.lock_outline),
          ],
        ),
        const SizedBox(height: 10),
        _label('SUBJECT'),
        SelectableText(
          _t.subject,
          key: const Key('et-preview-subject'),
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        ),
        if (_t.availableVariables.isNotEmpty) ...[
          const SizedBox(height: 10),
          _label('AVAILABLE VARIABLES'),
          Wrap(
            key: const Key('et-preview-variables'),
            spacing: 6,
            runSpacing: 6,
            children: [for (final v in _t.availableVariables) VariableChip(name: v)],
          ),
        ],
        if (_t.attachments.isNotEmpty) ...[
          const SizedBox(height: 10),
          _label('ATTACHMENTS'),
          for (final a in _t.attachments)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.attach_file, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(a.filename,
                      key: Key('et-preview-attachment-${a.id}'),
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                ),
              ]),
            ),
        ],
      ],
    );
  }

  Widget _modeToggle() => SegmentedButton<bool>(
        key: const Key('et-preview-mode'),
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          selectedBackgroundColor: AppColors.primary.withValues(alpha: 0.12),
          selectedForegroundColor: AppColors.primary,
          foregroundColor: AppColors.textSecondary,
          side: BorderSide(color: AppColors.border),
          textStyle: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w600),
        ),
        segments: const [
          ButtonSegment(value: true, label: Text('Rendered', key: Key('et-preview-mode-rendered'))),
          ButtonSegment(value: false, label: Text('Text', key: Key('et-preview-mode-text'))),
        ],
        selected: {_rendered},
        onSelectionChanged: (s) => setState(() => _rendered = s.first),
      );

  Widget _content(EmailPreviewViewBuilder buildView, String html) {
    final Widget inner;
    if (_rendered) {
      inner = KeyedSubtree(key: const Key('et-preview-rendered'), child: buildView(html));
    } else {
      final text = emailPreviewPlainText(_t.body);
      inner = SingleChildScrollView(
        key: const Key('et-preview-text'),
        padding: const EdgeInsets.all(14),
        child: SizedBox(
          width: double.infinity,
          child: SelectableText(
            text.isEmpty ? 'This template has no body.' : text,
            style: AppTextStyles.body.copyWith(height: 1.6, color: text.isEmpty ? AppColors.textHint : null),
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: _rendered ? const Color(0xFFF4F4F7) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: inner,
    );
  }

  Widget _bar(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    final close = OutlinedButton(
      key: const Key('et-preview-close'),
      onPressed: () => Navigator.of(context).pop(),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        foregroundColor: AppColors.textPrimary,
        side: BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      child: const Text('Close'),
    );
    final edit = FilledButton.icon(
      key: const Key('et-preview-edit'),
      onPressed: () => Navigator.of(context).pop(TemplatePreviewResult.edit),
      icon: const Icon(Icons.edit_outlined, size: 18),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      label: const Text('Edit Template'),
    );
    return Material(
      color: AppColors.surface,
      elevation: 4,
      shadowColor: Colors.black12,
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: LayoutBuilder(builder: (context, c) {
                if (c.maxWidth < 300 || scale > 1.3) {
                  return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        edit,
                        const SizedBox(height: 8),
                        close,
                      ]);
                }
                return Row(children: [
                  Expanded(child: close),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: edit),
                ]);
              }),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final company = ref.watch(companyProvider).valueOrNull;
    final html = buildEmailPreviewHtml(_t.body, company: company);
    final buildView = ref.watch(emailPreviewViewBuilderProvider);
    final size = MediaQuery.sizeOf(context);
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    final roomy = size.height >= 700 && scale <= 1.3;
    final open = _detailsOpen ?? roomy;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: BlueAppBar(title: 'Preview — ${_t.displayName}'),
      bottomNavigationBar: _bar(context),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: LayoutBuilder(builder: (context, c) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (open)
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: c.maxHeight * (roomy ? 0.45 : 0.3)),
                      child: SingleChildScrollView(
                        key: const Key('et-preview-details'),
                        child: _details(),
                      ),
                    )
                  else
                    _nameLine(1),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _modeToggle(),
                      TextButton.icon(
                        key: const Key('et-preview-details-toggle'),
                        onPressed: () => setState(() => _detailsOpen = !open),
                        icon: Icon(open ? Icons.expand_less : Icons.expand_more, size: 18),
                        label: Text(open ? 'Hide details' : 'Details'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: AppColors.primary,
                          textStyle: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(child: _content(buildView, html)),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// A `{VARIABLE}` pill that wraps instead of overflowing on long names; tappable
/// when [onTap] is given (the editor inserts the token into the body).
class VariableChip extends StatelessWidget {
  const VariableChip({super.key, required this.name, this.onTap});
  final String name;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(8);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 64),
      child: Material(
        color: AppColors.primary.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: onTap == null ? 5 : 8),
            child: Text(
              '{$name}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
