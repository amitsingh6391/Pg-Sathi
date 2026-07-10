import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
      appBar: AppBar(
        title: Text(
          fileName,
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: const Color(0xFF0A66C2),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Opening PDF in external viewer...'),
          ],
        ),
      ),
    );
  }
}
