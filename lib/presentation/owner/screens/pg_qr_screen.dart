import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/pg_invite_link.dart';
import '../../../domain/entities/library.dart';
import '../../core/app_ui_constants.dart';
import '../widgets/pg_qr/pg_qr_exporter.dart';
import '../widgets/pg_qr/pg_qr_poster.dart';

/// Lets the owner print or share the QR that opens their PG's invite page.
class PgQrScreen extends StatefulWidget {
  const PgQrScreen({super.key, required this.library});

  final Library library;

  @override
  State<PgQrScreen> createState() => _PgQrScreenState();
}

class _PgQrScreenState extends State<PgQrScreen> {
  final _posterKey = GlobalKey();

  String get _link => PgInviteLink.url(widget.library.id);

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? AppUIConstants.error : null,
        ),
      );
  }

  Future<void> _run(Future<void> Function() action, String failure) async {
    try {
      await action();
    } catch (_) {
      _toast(failure, error: true);
    }
  }

  Future<void> _save() => _run(() async {
    await PgQrExporter.saveToGallery(await PgQrExporter.capture(_posterKey));
    _toast('Poster saved to Gallery');
  }, 'Could not save the poster');

  Future<void> _share() => _run(() async {
    final box = context.findRenderObject() as RenderBox?;
    await PgQrExporter.share(
      await PgQrExporter.capture(_posterKey),
      text: 'Request a bed at ${widget.library.name}: $_link',
      origin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
    );
  }, 'Could not share the poster');

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _link));
    _toast('Link copied');
  }

  Future<void> _openLink() =>
      launchUrl(Uri.parse(_link), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(
        title: const Text('Registration QR'),
        actions: [
          IconButton(
            onPressed: _openLink,
            tooltip: 'Preview page',
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppUIConstants.spacingXl),
        child: Column(
          children: [
            const Text(
              'Print this poster for your gate or notice board. Residents '
              'scan it to see your room types and request a bed.',
              textAlign: TextAlign.center,
              style: AppUIConstants.bodySm,
            ),
            const SizedBox(height: AppUIConstants.spacingXl),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
              child: RepaintBoundary(
                key: _posterKey,
                child: PgQrPoster(library: widget.library),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        color: AppUIConstants.background,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppUIConstants.spacingXl,
              AppUIConstants.spacingSm,
              AppUIConstants.spacingXl,
              AppUIConstants.spacingLg,
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _share,
                    icon: const Icon(Icons.share_rounded, size: 20),
                    label: const Text('Share poster'),
                    style: AppUIConstants.primaryButtonStyle.copyWith(
                      minimumSize: const WidgetStatePropertyAll(
                        Size.fromHeight(52),
                      ),
                    ),
                  ),
                ),
                if (!kIsWeb) ...[
                  const SizedBox(width: AppUIConstants.spacingMd),
                  _RoundAction(
                    icon: Icons.download_rounded,
                    tooltip: 'Save to gallery',
                    onPressed: _save,
                  ),
                ],
                const SizedBox(width: AppUIConstants.spacingMd),
                _RoundAction(
                  icon: Icons.link_rounded,
                  tooltip: 'Copy link',
                  onPressed: _copyLink,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, color: AppUIConstants.primaryLight),
      ),
    );
  }
}
