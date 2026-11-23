import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/app_ui_constants.dart';
import 'notice_form_parts.dart';

const _maxPdfBytes = 10 * 1024 * 1024;
// WhatsApp rejects header images above 5 MB.
const _maxImageBytes = 5 * 1024 * 1024;
const _maxSide = 1920;
const _quality = 80;

/// Shrinks images so uploads are fast and fit WhatsApp's 5 MB header limit.
Future<File> _compressImage(File file) async {
  final ext = file.path.split('.').last.toLowerCase();
  if (ext == 'pdf') return file;
  final dir = await getTemporaryDirectory();
  final out = '${dir.path}/notice_${DateTime.now().microsecondsSinceEpoch}.jpg';
  final result = await FlutterImageCompress.compressAndGetFile(
    file.absolute.path,
    out,
    minWidth: _maxSide,
    minHeight: _maxSide,
    quality: _quality,
  );
  return result == null ? file : File(result.path);
}

/// Bottom sheet to pick images / PDFs. Returns [] when cancelled or oversize.
Future<List<File>> pickNoticeAttachments(BuildContext context) async {
  final source = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppUIConstants.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppUIConstants.radiusXl),
      ),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppUIConstants.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add attachment', style: AppUIConstants.headingSm),
            const SizedBox(height: AppUIConstants.spacingSm),
            NoticeRow(
              icon: Icons.photo_library_outlined,
              title: 'Photos',
              subtitle: 'Choose images from gallery',
              onTap: () => Navigator.pop(sheetContext, 'gallery'),
            ),
            NoticeRow(
              icon: Icons.picture_as_pdf_outlined,
              iconColor: AppUIConstants.error,
              title: 'Files',
              subtitle: 'Images under 5 MB, PDFs up to 10 MB',
              onTap: () => Navigator.pop(sheetContext, 'files'),
            ),
          ],
        ),
      ),
    ),
  );
  if (source == null) return [];

  final picked = source == 'gallery'
      ? (await ImagePicker().pickMultiImage()).map((x) => File(x.path)).toList()
      : (await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        )).map((f) => f.path).whereType<String>().map(File.new).toList();
  final files = await Future.wait(picked.map(_compressImage));

  for (final file in files) {
    final isPdf = file.path.toLowerCase().endsWith('.pdf');
    final limit = isPdf ? _maxPdfBytes : _maxImageBytes;
    if (await file.length() > limit) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPdf
                  ? '${file.path.split('/').last} is over 10 MB'
                  : 'Image must be under 5 MB to share on WhatsApp',
            ),
            backgroundColor: AppUIConstants.error,
          ),
        );
      }
      return [];
    }
  }
  return files;
}
