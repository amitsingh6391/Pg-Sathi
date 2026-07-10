import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/file_download_helper.dart';

import '../../../core/app_ui_constants.dart';
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Action buttons
          Column(
            children: [
              // Download Sample Button
              _DownloadSampleButton(
                onTap: () => _downloadSampleFile(context),
              ),
              const SizedBox(height: 16),
              // Select File Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _pickFile(context),
                  icon: const Icon(Icons.folder_open_rounded, size: 22),
                  label: const Text(
                    'Select Excel File to Import',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppUIConstants.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: AppUIConstants.primary.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Info cards
          Row(
            children: [
              Expanded(
                child: _InfoCard(
                  icon: Icons.lightbulb_outline_rounded,
                  title: 'Quick Tip',
                  message: 'Download sample file to see the exact format',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoCard(
                  icon: Icons.warning_amber_rounded,
                  title: 'Important',
                  message: 'Ensure data accuracy before importing',
                  color: Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Cleanup section
          _CleanupSection(
            onCleanup: () => _confirmCleanup(context),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );

    if (!context.mounted) return;

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes != null) {
        context.read<BulkImportCubit>().parseExcelFile(file.bytes!, file.name);
      }
    }
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
        throw Exception('Sample file not found. Please ensure the asset is included in pubspec.yaml');
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
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        sharePositionOrigin: sharePositionOrigin,
      );

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sample file downloaded successfully!'),
            backgroundColor: Colors.green,
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
            backgroundColor: Colors.red,
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
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text('Confirm Cleanup'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will permanently delete:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('• All memberships for this library'),
            const Text('• All payment records'),
            const Text('• All invoices'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'This action CANNOT be undone!',
                      style: TextStyle(fontWeight: FontWeight.bold),
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
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<BulkImportCubit>().cleanupLibraryData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete All Data'),
          ),
        ],
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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppUIConstants.primary.withValues(alpha: 0.1),
            AppUIConstants.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppUIConstants.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppUIConstants.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.download_rounded,
                    color: AppUIConstants.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Download Sample File',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Get the exact Excel template',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getShade50(color),
            _getShade50(color).withValues(alpha: 0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getShade200(color), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getShade100(color),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: _getShade700(color),
              size: 20,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Color _getShade50(Color color) {
    if (color == Colors.blue) return Colors.blue.shade50;
    if (color == Colors.amber) return Colors.amber.shade50;
    return color.withValues(alpha: 0.05);
  }

  Color _getShade100(Color color) {
    if (color == Colors.blue) return Colors.blue.shade100;
    if (color == Colors.amber) return Colors.amber.shade100;
    return color.withValues(alpha: 0.1);
  }

  Color _getShade200(Color color) {
    if (color == Colors.blue) return Colors.blue.shade200;
    if (color == Colors.amber) return Colors.amber.shade200;
    return color.withValues(alpha: 0.2);
  }

  Color _getShade700(Color color) {
    if (color == Colors.blue) return Colors.blue.shade700;
    if (color == Colors.amber) return Colors.amber.shade700;
    return color;
  }
}

/// Cleanup section widget.
class _CleanupSection extends StatelessWidget {
  const _CleanupSection({required this.onCleanup});

  final VoidCallback onCleanup;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.cleaning_services_rounded,
                  color: Colors.red.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Data Cleanup',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Need to re-import? Delete all existing memberships and payments for this library first.',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCleanup,
              icon: const Icon(Icons.delete_sweep_rounded),
              label: const Text('Clear PG/Hostel Data'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
