import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/file_download_helper.dart';

import '../../../core/app_ui_constants.dart';
import '../../../core/widgets/premium_kit.dart';
import '../../cubit/bulk_import_cubit.dart';

/// File picker section for selecting Excel file.
class FilePickerSection extends StatefulWidget {
  const FilePickerSection({super.key});

  @override
  State<FilePickerSection> createState() => _FilePickerSectionState();
}

class _FilePickerSectionState extends State<FilePickerSection> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dropzone-style file picker
          _Dropzone(onTap: () => _pickFile(context)),
          const SizedBox(height: 14),
          _DownloadSampleButton(onTap: () => _downloadSampleFile(context)),
          const PremiumSectionHeader('Before you import'),
          const _InfoCard(
            icon: Icons.table_chart_rounded,
            title: 'Use the template',
            message:
                'Download the sample file to see the exact columns: resident name, phone, bed, dates and rent amount.',
            color: AppUIConstants.primaryLight,
          ),
          const SizedBox(height: 10),
          const _InfoCard(
            icon: Icons.fact_check_rounded,
            title: 'Check your data',
            message:
                'You will review every row on the next step before anything is saved.',
            color: AppUIConstants.warning,
          ),
          const SizedBox(height: 24),
          _CleanupSection(onCleanup: () => _confirmCleanup(context)),
        ],
      ),
    );
  }

  Future<void> _pickFile(BuildContext context) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    if (!context.mounted) return;

    context.read<BulkImportCubit>().parseExcelFile(bytes, file.name);
  }

  Future<void> _downloadSampleFile(BuildContext context) async {
    try {
      if (!context.mounted) return;

      // Show loading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loading sample file...'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Load asset file
      final ByteData data;
      try {
        data = await rootBundle.load('assets/xl_sheet/sample_data.xlsx');
      } catch (e) {
        throw Exception(
          'Sample file not found. Please ensure the asset is included in pubspec.yaml',
        );
      }

      final Uint8List bytes = data.buffer.asUint8List();

      if (bytes.isEmpty) {
        throw Exception('Sample file is empty');
      }

      if (!context.mounted) return;

      // Get button position for iOS share sheet
      // iOS/iPad requires sharePositionOrigin for the share sheet popover
      Rect? sharePositionOrigin;
      try {
        // Get screen size to calculate a valid position
        final mediaQuery = MediaQuery.of(context);
        final screenSize = mediaQuery.size;

        // Try to get the button's position from the context
        final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox.hasSize) {
          final size = renderBox.size;
          final position = renderBox.localToGlobal(Offset.zero);
          // Ensure valid rect with non-zero dimensions and within screen bounds
          if (size.width > 0 &&
              size.height > 0 &&
              position.dx >= 0 &&
              position.dy >= 0 &&
              position.dx + size.width <= screenSize.width &&
              position.dy + size.height <= screenSize.height) {
            sharePositionOrigin = Rect.fromLTWH(
              position.dx,
              position.dy,
              size.width,
              size.height,
            );
          }
        }

        // If we couldn't get button position, use a calculated position based on screen size
        if (sharePositionOrigin == null) {
          // Use center-bottom area (typical for download buttons)
          final centerX = screenSize.width / 2;
          final bottomY = screenSize.height * 0.85; // 85% down the screen
          final buttonWidth = screenSize.width * 0.8; // 80% of screen width
          final buttonHeight = 60.0;

          sharePositionOrigin = Rect.fromLTWH(
            centerX - (buttonWidth / 2),
            bottomY - buttonHeight,
            buttonWidth,
            buttonHeight,
          );
        }
      } catch (_) {
        // If we can't get position, helper will use default
      }

      // Use cross-platform file download helper
      await FileDownloadHelper.downloadFile(
        bytes: bytes,
        fileName: 'bulk_import_sample.xlsx',
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        sharePositionOrigin: sharePositionOrigin,
      );

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sample file downloaded successfully!'),
            backgroundColor: AppUIConstants.success,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download sample file: ${e.toString()}'),
            backgroundColor: AppUIConstants.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _confirmCleanup(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppUIConstants.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
        ),
        title: Row(
          children: [
            Icon(Icons.warning, color: AppUIConstants.error),
            const SizedBox(width: 8),
            const Text('Confirm Cleanup', style: AppUIConstants.headingMd),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will permanently delete:',
              style: AppUIConstants.bodyLg,
            ),
            const SizedBox(height: 12),
            const Text('• All stays for this PG', style: AppUIConstants.bodyMd),
            const Text('• All payment records', style: AppUIConstants.bodyMd),
            const Text('• All invoices', style: AppUIConstants.bodyMd),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppUIConstants.error.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: AppUIConstants.error),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'This action CANNOT be undone!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppUIConstants.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppUIConstants.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<BulkImportCubit>().cleanupLibraryData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppUIConstants.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete All Data'),
          ),
        ],
      ),
    );
  }
}

/// Dropzone-style tap target for picking the Excel file.
class _Dropzone extends StatelessWidget {
  const _Dropzone({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppUIConstants.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppUIConstants.radiusXl),
        side: BorderSide(
          color: AppUIConstants.primaryLight.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppUIConstants.radiusXl),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppUIConstants.primarySoft,
                  boxShadow: [
                    BoxShadow(
                      color: AppUIConstants.primaryLight.withValues(alpha: 0.2),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.upload_file_rounded,
                  size: 38,
                  color: AppUIConstants.primaryLight,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tap to choose an Excel file',
                style: AppUIConstants.headingSm,
              ),
              const SizedBox(height: 6),
              const Text(
                '.xlsx or .xls with your residents list',
                style: AppUIConstants.bodySm,
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppUIConstants.primaryLight,
                  borderRadius: BorderRadius.circular(
                    AppUIConstants.radiusFull,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.folder_open_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Select file',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Download sample file button.
class _DownloadSampleButton extends StatelessWidget {
  const _DownloadSampleButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppUIConstants.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            ),
            child: const Icon(
              Icons.download_rounded,
              color: AppUIConstants.primaryLight,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Download Sample File', style: AppUIConstants.bodyLg),
                Text(
                  'Get the exact Excel template',
                  style: AppUIConstants.bodySm,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppUIConstants.textTertiary,
          ),
        ],
      ),
    );
  }
}

/// Info card widget.
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppUIConstants.surfaceMuted,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            ),
            child: Icon(icon, color: AppUIConstants.textSecondary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppUIConstants.bodyLg),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppUIConstants.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
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

/// Cleanup section widget.
class _CleanupSection extends StatelessWidget {
  const _CleanupSection({required this.onCleanup});

  final VoidCallback onCleanup;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
        border: Border.all(color: AppUIConstants.error.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppUIConstants.error.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
                ),
                child: const Icon(
                  Icons.cleaning_services_rounded,
                  color: AppUIConstants.error,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Danger zone: Data Cleanup',
                style: AppUIConstants.bodyLg,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Need to re-import? Delete all existing stays and payments for this PG first.',
            style: TextStyle(
              color: AppUIConstants.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCleanup,
              icon: const Icon(Icons.delete_sweep_rounded),
              label: const Text('Clear PG/Hostel Data'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppUIConstants.error,
                side: BorderSide(
                  color: AppUIConstants.error.withValues(alpha: 0.5),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
