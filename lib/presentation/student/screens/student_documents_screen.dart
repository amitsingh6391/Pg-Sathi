import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/student_document.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';
import '../cubit/student_documents_cubit.dart';
import '../cubit/student_documents_state.dart';
import '../widgets/profile_widgets.dart' show CompletionRing;

/// KYC checklist for residents to upload and track verification documents.
class StudentDocumentsScreen extends StatelessWidget {
  const StudentDocumentsScreen({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<StudentDocumentsCubit>()..loadDocuments(studentId),
      child: Scaffold(
        backgroundColor: AppUIConstants.background,
        body: BlocConsumer<StudentDocumentsCubit, StudentDocumentsState>(
          listener: (context, state) {
            if (state.isError && state.errorMessage != null) {
              _snack(context, state.errorMessage!, isError: true);
            }
          },
          builder: (context, state) {
            return Column(
              children: [
                _Header(state: state),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    child: _buildBody(context, state),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, StudentDocumentsState state) {
    final bottom = MediaQuery.of(context).padding.bottom + 24;

    if (state.isLoading) {
      return const _SkeletonList(key: ValueKey('loading'));
    }

    if (state.isError && state.documents.isEmpty) {
      return Center(
        key: const ValueKey('error'),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconBubble(
                icon: Icons.cloud_off_rounded,
                color: AppUIConstants.error,
              ),
              const SizedBox(height: 20),
              const Text(
                "Couldn't load documents",
                style: AppUIConstants.headingMd,
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  state.errorMessage!,
                  style: AppUIConstants.bodyMd,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () =>
                    context.read<StudentDocumentsCubit>().refresh(studentId),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
                style: AppUIConstants.primaryButtonStyle,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      key: const ValueKey('content'),
      color: AppUIConstants.primaryLight,
      backgroundColor: AppUIConstants.surface,
      onRefresh: () => context.read<StudentDocumentsCubit>().refresh(studentId),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottom),
        children: [
          _Checklist(documents: state.documents),
          const SizedBox(height: 16),
          if (state.canUploadMore)
            _UploadCard(
              isUploading: state.isUploading,
              count: state.documents.length,
              onTap: () => _pickAndUploadDocument(context),
            )
          else
            PremiumCard(
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppUIConstants.success,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Maximum 2 documents uploaded',
                      style: AppUIConstants.bodyLg,
                    ),
                  ),
                  PremiumStatusPill('2/2', color: AppUIConstants.success),
                ],
              ),
            ),
          if (state.documents.isEmpty)
            _EmptyDocumentsView(
              onUpload: state.isUploading
                  ? null
                  : () => _pickAndUploadDocument(context),
            )
          else ...[
            PremiumSectionHeader(
              'Your documents (${state.documents.length})',
              action: 'Refresh',
              onAction: () =>
                  context.read<StudentDocumentsCubit>().refresh(studentId),
            ),
            ...state.documents.asMap().entries.map(
              (e) => _Staggered(
                index: e.key,
                child: _DocumentCard(
                  document: e.value,
                  onView: () => _viewDocument(context, e.value),
                  onEdit: e.value.isPending
                      ? () => _editDocument(context, e.value)
                      : null,
                  onShare: () => _shareDocument(context, e.value),
                  onDelete: e.value.isPending
                      ? () => _showDeleteDocumentDialog(context, e.value)
                      : null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickAndUploadDocument(BuildContext context) async {
    // First, select document category
    final category = await _showCategorySheet(context);

    if (category == null || !context.mounted) return;

    // Then pick file
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    final pickedPath = file?.path;

    if (file != null && pickedPath != null && context.mounted) {
      final filePath = pickedPath;
      final fileName = '${category.displayName}.${file.extension ?? 'pdf'}';

      HapticFeedback.mediumImpact();
      context.read<StudentDocumentsCubit>().uploadNewDocument(
        studentId: studentId,
        filePath: filePath,
        fileName: fileName,
      );
    }
  }

  Future<void> _viewDocument(
    BuildContext context,
    StudentDocument document,
  ) async {
    try {
      // Show loading indicator
      if (context.mounted) {
        _showBusy(context, 'Fetching document...');
      }

      // Download file from Firebase Storage
      final response = await http.get(Uri.parse(document.downloadUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download document');
      }

      // Save to temp directory
      final tempDir = await getTemporaryDirectory();
      final extension = document.fileType == StudentDocumentType.pdf
          ? 'pdf'
          : document.downloadUrl.split('.').last.split('?').first;
      final file = File('${tempDir.path}/doc_${document.id}.$extension');
      await file.writeAsBytes(response.bodyBytes);

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (document.fileType == StudentDocumentType.pdf) {
        // Open PDF using open_filex (like invoices)
        final result = await OpenFilex.open(file.path);
        if (context.mounted && result.type != ResultType.done) {
          _snack(
            context,
            'Failed to open PDF: ${result.message}',
            isError: true,
          );
        }
      } else {
        // Open image in full screen viewer with share option
        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _ImageViewerScreen(
                imageUrl: document.downloadUrl,
                document: document,
                file: file,
              ),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (context.mounted) {
        Navigator.of(context).pop();
        _snack(
          context,
          'Failed to open document: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  Future<void> _editDocument(
    BuildContext context,
    StudentDocument document,
  ) async {
    // First, select new document category
    final category = await _showCategorySheet(context);

    if (category == null || !context.mounted) return;

    // Then pick new file
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    final pickedPath = file?.path;

    if (file != null && pickedPath != null && context.mounted) {
      // Delete old document first
      context.read<StudentDocumentsCubit>().deleteDocument(document.id);

      // Upload new document
      final filePath = pickedPath;
      final fileName = '${category.displayName}.${file.extension ?? 'pdf'}';

      context.read<StudentDocumentsCubit>().uploadNewDocument(
        studentId: studentId,
        filePath: filePath,
        fileName: fileName,
      );
    }
  }

  Future<void> _shareDocument(
    BuildContext context,
    StudentDocument document,
  ) async {
    try {
      // Show loading
      if (context.mounted) {
        _showBusy(context, 'Preparing file...');
      }

      // Download file
      final response = await http.get(Uri.parse(document.downloadUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download document');
      }

      // Save to temp directory
      final tempDir = await getTemporaryDirectory();
      final extension = document.fileType == StudentDocumentType.pdf
          ? 'pdf'
          : document.downloadUrl.split('.').last.split('?').first;
      final file = File('${tempDir.path}/doc_${document.id}.$extension');
      await file.writeAsBytes(response.bodyBytes);

      // Close loading
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Share file
      if (context.mounted) {
        await Share.shareXFiles([
          XFile(file.path),
        ], text: document.documentCategory?.displayName ?? document.fileName);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        _snack(
          context,
          'Failed to share document: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  Future<void> _showDeleteDocumentDialog(
    BuildContext context,
    StudentDocument document,
  ) async {
    final name = document.documentCategory?.displayName ?? document.fileName;
    final result = await _showSheet<bool>(
      context,
      (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconBubble(
            icon: Icons.delete_outline_rounded,
            color: AppUIConstants.error,
          ),
          const SizedBox(height: 16),
          const Text('Delete document?', style: AppUIConstants.headingMd),
          const SizedBox(height: 8),
          Text(
            'Are you sure you want to delete $name? You can upload it again later.',
            textAlign: TextAlign.center,
            style: AppUIConstants.bodyMd,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppUIConstants.textPrimary,
                    side: const BorderSide(color: AppUIConstants.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppUIConstants.radiusMd,
                      ),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppUIConstants.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppUIConstants.radiusMd,
                      ),
                    ),
                  ),
                  child: const Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      context.read<StudentDocumentsCubit>().deleteDocument(document.id);
    }
  }
}

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

void _snack(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? AppUIConstants.error : AppUIConstants.success,
    ),
  );
}

void _showBusy(BuildContext context, String label) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Center(
      child: PremiumCard(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppUIConstants.primaryLight,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: AppUIConstants.bodyMd.copyWith(
                decoration: TextDecoration.none,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<T?> _showSheet<T>(
  BuildContext context,
  Widget Function(BuildContext) builder,
) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: AppUIConstants.surface,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppUIConstants.radiusXl),
      ),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: builder(ctx),
      ),
    ),
  );
}

Future<DocumentCategory?> _showCategorySheet(BuildContext context) {
  return _showSheet<DocumentCategory>(
    context,
    (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Choose document type', style: AppUIConstants.headingMd),
        const SizedBox(height: 4),
        const Text(
          'Pick the ID proof you want to upload (image or PDF)',
          style: AppUIConstants.bodySm,
        ),
        const SizedBox(height: 16),
        ...DocumentCategory.values.map(
          (category) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: AppUIConstants.surfaceMuted,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(sheetContext).pop(category);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppUIConstants.primaryLight.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppUIConstants.radiusSm,
                          ),
                        ),
                        child: Text(
                          category.icon,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          category.displayName,
                          style: AppUIConstants.bodyLg,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppUIConstants.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Color _statusColor(StudentDocument d) => d.isApproved
    ? AppUIConstants.success
    : d.isPending
    ? AppUIConstants.warning
    : AppUIConstants.error;

class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Icon(icon, color: color, size: 34),
    );
  }
}

class _Staggered extends StatelessWidget {
  const _Staggered({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 350 + index * 90),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}

// -----------------------------------------------------------------------------
// Header with completion ring
// -----------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.state});

  final StudentDocumentsState state;

  @override
  Widget build(BuildContext context) {
    final docs = state.documents;
    final approved = docs.where((d) => d.isApproved).length;
    final progress = docs.isEmpty ? 0.0 : approved / docs.length;
    final headline = docs.isEmpty
        ? 'Add your ID proof'
        : approved > 0
        ? 'You are verified'
        : 'Awaiting verification';
    final sub = docs.isEmpty
        ? 'Upload up to 2 documents to complete your KYC'
        : '$approved of ${docs.length} approved by your PG owner';

    return PremiumHero(
      padding: const EdgeInsets.fromLTRB(8, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppUIConstants.textPrimary,
                ),
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 4),
              const Text(
                'KYC Documents',
                style: TextStyle(
                  color: AppUIConstants.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 0, 0),
            child: Row(
              children: [
                CompletionRing(
                  progress: progress,
                  size: 84,
                  strokeWidth: 6,
                  color: AppUIConstants.success,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${docs.length}/2',
                        style: const TextStyle(
                          color: AppUIConstants.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'uploaded',
                        style: TextStyle(
                          color: AppUIConstants.textTertiary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          headline,
                          key: ValueKey(headline),
                          style: const TextStyle(
                            color: AppUIConstants.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sub,
                        style: const TextStyle(
                          color: AppUIConstants.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
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

// -----------------------------------------------------------------------------
// Checklist
// -----------------------------------------------------------------------------

class _Checklist extends StatelessWidget {
  const _Checklist({required this.documents});

  final List<StudentDocument> documents;

  @override
  Widget build(BuildContext context) {
    final uploaded = documents.isNotEmpty;
    final reviewed = documents.any((d) => d.isApproved || !d.isPending);
    final approved = documents.any((d) => d.isApproved);
    final rejected = documents.any(
      (d) => d.approvalStatus == DocumentApprovalStatus.rejected,
    );

    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Verification checklist', style: AppUIConstants.headingSm),
          const SizedBox(height: 12),
          _CheckStep(
            title: 'Upload ID proof',
            subtitle: uploaded
                ? '${documents.length} document(s) submitted'
                : 'Aadhar, PAN, Voter ID and more',
            done: uploaded,
            active: !uploaded,
          ),
          _CheckStep(
            title: 'Owner review',
            subtitle: reviewed
                ? (rejected ? 'Some documents need attention' : 'Reviewed')
                : 'Your PG owner checks your documents',
            done: reviewed && !rejected,
            active: uploaded && !reviewed,
            warn: rejected,
          ),
          _CheckStep(
            title: 'Verified resident',
            subtitle: approved ? 'You are all set' : 'Unlocks full PG access',
            done: approved,
            active: false,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _CheckStep extends StatelessWidget {
  const _CheckStep({
    required this.title,
    required this.subtitle,
    required this.done,
    required this.active,
    this.warn = false,
    this.isLast = false,
  });

  final String title;
  final String subtitle;
  final bool done;
  final bool active;
  final bool warn;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = warn
        ? AppUIConstants.error
        : done
        ? AppUIConstants.success
        : active
        ? AppUIConstants.primaryLight
        : AppUIConstants.textTertiary;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: done ? 1 : 0.14),
                  border: Border.all(color: color, width: 1.5),
                ),
                child: Icon(
                  warn
                      ? Icons.priority_high_rounded
                      : done
                      ? Icons.check_rounded
                      : Icons.circle,
                  size: done || warn ? 16 : 7,
                  color: done ? AppUIConstants.background : color,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: done
                        ? color.withValues(alpha: 0.6)
                        : AppUIConstants.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppUIConstants.bodyLg.copyWith(
                      color: done || active
                          ? AppUIConstants.textPrimary
                          : AppUIConstants.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppUIConstants.bodySm),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Upload card
// -----------------------------------------------------------------------------

class _UploadCard extends StatelessWidget {
  const _UploadCard({
    required this.isUploading,
    required this.count,
    required this.onTap,
  });

  final bool isUploading;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: isUploading ? null : onTap,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppUIConstants.surfaceMuted,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isUploading
                  ? const Padding(
                      key: ValueKey('up'),
                      padding: EdgeInsets.all(15),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppUIConstants.primaryLight,
                      ),
                    )
                  : const Icon(
                      Icons.upload_file_rounded,
                      key: ValueKey('idle'),
                      color: AppUIConstants.primaryLight,
                      size: 26,
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUploading ? 'Uploading...' : 'Upload a document',
                  style: AppUIConstants.headingSm,
                ),
                const SizedBox(height: 2),
                Text(
                  isUploading
                      ? 'Please keep the app open'
                      : '$count of 2 added - image or PDF',
                  style: AppUIConstants.bodySm,
                ),
              ],
            ),
          ),
          if (!isUploading)
            const Icon(
              Icons.add_circle_rounded,
              color: AppUIConstants.primaryLight,
              size: 28,
            ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Document card + action sheet
// -----------------------------------------------------------------------------

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.document,
    required this.onView,
    this.onEdit,
    this.onShare,
    this.onDelete,
  });

  final StudentDocument document;
  final VoidCallback onView;
  final VoidCallback? onEdit;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;

  void _openActions(BuildContext context) {
    HapticFeedback.selectionClick();
    final color = _statusColor(document);
    final name = document.documentCategory?.displayName ?? document.fileName;

    Widget action(
      IconData icon,
      String label,
      VoidCallback? cb, {
      Color c = AppUIConstants.textPrimary,
    }) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
          ),
          child: Icon(icon, size: 20, color: c),
        ),
        title: Text(label, style: AppUIConstants.bodyLg.copyWith(color: c)),
        onTap: () {
          Navigator.of(context).pop();
          cb?.call();
        },
      );
    }

    _showSheet<void>(
      context,
      (_) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(name, style: AppUIConstants.headingMd)),
              PremiumStatusPill(
                document.approvalStatus.displayName,
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 8),
          action(
            Icons.visibility_rounded,
            document.isApproved ? 'View approved document' : 'View document',
            onView,
            c: AppUIConstants.primaryLight,
          ),
          if (onEdit != null)
            action(
              Icons.edit_rounded,
              'Replace',
              onEdit,
              c: AppUIConstants.primaryLight,
            ),
          if (onShare != null) action(Icons.share_rounded, 'Share', onShare),
          if (onDelete != null)
            action(
              Icons.delete_outline_rounded,
              'Delete',
              onDelete,
              c: AppUIConstants.error,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final category = document.documentCategory;
    final categoryName = category?.displayName ?? document.fileName;
    final categoryIcon = category?.icon ?? '📄';
    final color = _statusColor(document);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
        onTap: onView,
        padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(categoryIcon, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    categoryName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppUIConstants.bodyLg.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Uploaded ${_formatDate(document.uploadedAt)}',
                    style: AppUIConstants.bodySm,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      PremiumStatusPill(
                        document.approvalStatus.displayName,
                        color: color,
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        document.fileType == StudentDocumentType.pdf
                            ? Icons.picture_as_pdf_rounded
                            : Icons.image_rounded,
                        size: 16,
                        color: AppUIConstants.textTertiary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.more_horiz_rounded,
                color: AppUIConstants.textSecondary,
              ),
              tooltip: 'Actions',
              onPressed: () => _openActions(context),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// -----------------------------------------------------------------------------
// Image viewer
// -----------------------------------------------------------------------------

/// Image Viewer Screen with share option
class _ImageViewerScreen extends StatelessWidget {
  const _ImageViewerScreen({
    required this.imageUrl,
    required this.document,
    required this.file,
  });

  final String imageUrl;
  final StudentDocument document;
  final File file;

  Future<void> _shareImage(BuildContext context) async {
    try {
      await Share.shareXFiles([
        XFile(file.path),
      ], text: document.documentCategory?.displayName ?? document.fileName);
    } catch (e) {
      if (context.mounted) {
        _snack(
          context,
          'Failed to share image: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(document);
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(
        backgroundColor: AppUIConstants.background,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          document.documentCategory?.displayName ?? document.fileName,
          style: AppUIConstants.headingSm,
        ),
        actions: [
          Center(
            child: PremiumStatusPill(
              document.approvalStatus.displayName,
              color: color,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            onPressed: () => _shareImage(context),
            tooltip: 'Share',
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppUIConstants.primaryLight,
                  ),
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Text(
                  'Failed to load image',
                  style: TextStyle(color: AppUIConstants.textSecondary),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Empty + skeleton
// -----------------------------------------------------------------------------

class _EmptyDocumentsView extends StatelessWidget {
  const _EmptyDocumentsView({required this.onUpload});

  final VoidCallback? onUpload;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 36, 16, 16),
      child: Column(
        children: [
          const _IconBubble(
            icon: Icons.folder_open_rounded,
            color: AppUIConstants.primaryLight,
          ),
          const SizedBox(height: 20),
          const Text('No documents yet', style: AppUIConstants.headingMd),
          const SizedBox(height: 8),
          const Text(
            'Upload an ID proof so your PG owner can verify you and finish your check-in.',
            style: AppUIConstants.bodyMd,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          ElevatedButton.icon(
            onPressed: onUpload,
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Upload first document'),
            style: AppUIConstants.accentButtonStyle,
          ),
        ],
      ),
    );
  }
}

class _SkeletonList extends StatefulWidget {
  const _SkeletonList({super.key});

  @override
  State<_SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<_SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _block(double h) => Container(
    height: h,
    decoration: BoxDecoration(
      color: AppUIConstants.surfaceMuted,
      borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_c),
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          _block(190),
          const SizedBox(height: 16),
          _block(84),
          const SizedBox(height: 24),
          _block(84),
          const SizedBox(height: 12),
          _block(84),
        ],
      ),
    );
  }
}
