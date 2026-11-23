import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';

/// Simple PDF viewer screen - opens PDF in external viewer
class PdfViewerScreen extends StatelessWidget {
  const PdfViewerScreen({
    super.key,
    required this.pdfUrl,
    required this.fileName,
  });

  final String pdfUrl;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    // Automatically launch PDF in external viewer
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final uri = Uri.parse(pdfUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (context.mounted) {
        Navigator.pop(context);
      }
    });

    return Scaffold(
      backgroundColor: AppUIConstants.background,
      body: Column(
        children: [
          PremiumHero(
            padding: const EdgeInsets.fromLTRB(8, 4, 20, 22),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppUIConstants.textPrimary,
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppUIConstants.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          const SizedBox(
                            width: 84,
                            height: 84,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: AppUIConstants.primaryLight,
                            ),
                          ),
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: AppUIConstants.error.withValues(
                                alpha: 0.14,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.picture_as_pdf_rounded,
                              color: AppUIConstants.error,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Opening PDF',
                        style: AppUIConstants.headingMd,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Launching your external viewer...',
                        style: AppUIConstants.bodyMd,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
