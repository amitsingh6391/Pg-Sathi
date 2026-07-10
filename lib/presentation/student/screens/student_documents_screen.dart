import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/student_document.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/student_documents_cubit.dart';
import '../cubit/student_documents_state.dart';

/// Screen for students to upload and view verification documents.
class StudentDocumentsScreen extends StatelessWidget {
  const StudentDocumentsScreen({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<StudentDocumentsCubit>()..loadDocuments(studentId),
      child: Scaffold(
        backgroundColor: AppUIConstants.background,
        appBar: AppBar(
          title: const Text('Verification Documents'),
          backgroundColor: AppUIConstants.primary,
          foregroundColor: Colors.white,
        ),
        body: BlocConsumer<StudentDocumentsCubit, StudentDocumentsState>(
          listener: (context, state) {
            if (state.isError && state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.isError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading documents',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      if (state.errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          state.errorMessage!,
                          style: TextStyle(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          context.read<StudentDocumentsCubit>().refresh(
                            studentId,
                          );
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppUIConstants.spacingXl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppUIConstants.divider,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppUIConstants.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Upload up to 2 verification documents (Image or PDF)',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppUIConstants.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Upload button
                  if (state.canUploadMore)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: state.isUploading
                            ? null
                            : () => _pickAndUploadDocument(context),
                        icon: state.isUploading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.upload_file),
                        label: Text(
                          state.isUploading
                              ? 'Uploading...'
                              : 'Upload Document (${state.documents.length}/2)',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppUIConstants.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  if (!state.canUploadMore) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.amber.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Maximum 2 documents uploaded',
                              style: TextStyle(
                                color: Colors.amber.shade900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Documents list
                  if (state.documents.isEmpty)
                    _EmptyDocumentsView()
                  else ...[
                    // Info message for approved documents
                    if (state.documents.any((doc) => doc.isApproved))
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.green.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tap on approved documents (green border) to view them',
                                style: TextStyle(
                                  color: Colors.green.shade900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Uploaded Documents (${state.documents.length})',
                          style: AppUIConstants.headingSm,
                        ),
                        // Debug: Show document count
                        if (state.documents.isNotEmpty)
                          TextButton.icon(
                            onPressed: () {
                              context.read<StudentDocumentsCubit>().refresh(
                                studentId,
                              );
                            },
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Refresh'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...state.documents.map(
                      (doc) => _DocumentCard(
                        document: doc,
                        onView: () => _viewDocument(context, doc),
                        onEdit: doc.isPending
                            ? () => _editDocument(context, doc)
                            : null,
                        onShare: () => _shareDocument(context, doc),
                        onDelete: doc.isPending
                            ? () => _showDeleteDocumentDialog(context, doc)
                            : null,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _pickAndUploadDocument(BuildContext context) async {
    // First, select document category
    final category = await showDialog<DocumentCategory>(
      context: context,
      builder: (dialogContext) => _DocumentCategoryPickerDialog(),
    );

    if (category == null || !context.mounted) return;

    // Then pick file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result != null && result.files.single.path != null && context.mounted) {
      final filePath = result.files.single.path!;
      final fileName =
          '${category.displayName}.${result.files.single.extension ?? 'pdf'}';

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
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to open PDF: ${result.message}'),
              backgroundColor: Colors.red,
            ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open document: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editDocument(
    BuildContext context,
    StudentDocument document,
  ) async {
    // First, select new document category
    final category = await showDialog<DocumentCategory>(
      context: context,
      builder: (dialogContext) => _DocumentCategoryPickerDialog(),
    );

    if (category == null || !context.mounted) return;

    // Then pick new file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result != null && result.files.single.path != null && context.mounted) {
      // Delete old document first
      context.read<StudentDocumentsCubit>().deleteDocument(document.id);

      // Upload new document
      final filePath = result.files.single.path!;
      final fileName =
          '${category.displayName}.${result.files.single.extension ?? 'pdf'}';

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
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share document: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showDeleteDocumentDialog(
    BuildContext context,
    StudentDocument document,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Document?'),
        content: Text(
          'Are you sure you want to delete ${document.documentCategory?.displayName ?? document.fileName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      context.read<StudentDocumentsCubit>().deleteDocument(document.id);
    }
  }
}

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
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
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Text(
                  'Failed to load image',
                  style: TextStyle(color: Colors.white),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    final category = document.documentCategory;
    final categoryName = category?.displayName ?? document.fileName;
    final categoryIcon = category?.icon ?? '📄';

    return InkWell(
      onTap: onView,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppUIConstants.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: document.isApproved
                ? Colors.green.shade300
                : document.isPending
                ? Colors.amber.shade300
                : Colors.red.shade300,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: document.isApproved
                  ? Colors.green.shade50
                  : document.isPending
                  ? Colors.amber.shade50
                  : Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(categoryIcon, style: const TextStyle(fontSize: 24)),
          ),
          title: Text(
            categoryName,
            style: AppUIConstants.bodyLg.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                'Uploaded ${_formatDate(document.uploadedAt)}',
                style: AppUIConstants.bodySm,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: document.isApproved
                      ? Colors.green.shade100
                      : document.isPending
                      ? Colors.amber.shade100
                      : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  document.approvalStatus.displayName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: document.isApproved
                        ? Colors.green.shade700
                        : document.isPending
                        ? Colors.amber.shade700
                        : Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // View icon for approved documents (always visible and prominent)
              if (document.isApproved)
                IconButton(
                  icon: const Icon(Icons.visibility, color: Colors.green),
                  onPressed: onView,
                  tooltip: 'View Approved Document',
                ),
              // View icon for rejected documents (also allow viewing)
              if (document.approvalStatus == DocumentApprovalStatus.rejected)
                IconButton(
                  icon: const Icon(Icons.visibility, color: Colors.red),
                  onPressed: onView,
                  tooltip: 'View Document',
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  switch (value) {
                    case 'view':
                      onView();
                      break;
                    case 'edit':
                      onEdit?.call();
                      break;
                    case 'share':
                      onShare?.call();
                      break;
                    case 'delete':
                      onDelete?.call();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  // View option is always available for all documents
                  PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        Icon(
                          Icons.visibility,
                          size: 20,
                          color: document.isApproved
                              ? Colors.green
                              : document.approvalStatus ==
                                    DocumentApprovalStatus.rejected
                              ? Colors.red
                              : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          document.isApproved
                              ? 'View Approved Document'
                              : 'View Document',
                        ),
                      ],
                    ),
                  ),
                  if (onEdit != null)
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                  if (onShare != null)
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share, size: 20),
                          SizedBox(width: 8),
                          Text('Share'),
                        ],
                      ),
                    ),
                  if (onDelete != null)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Document Category Picker Dialog
class _DocumentCategoryPickerDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Select Document Type'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: DocumentCategory.values.map((category) {
          return ListTile(
            leading: Text(category.icon, style: const TextStyle(fontSize: 24)),
            title: Text(category.displayName),
            onTap: () => Navigator.of(context).pop(category),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _EmptyDocumentsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open_outlined,
              size: 64,
              color: AppUIConstants.disabled,
            ),
            const SizedBox(height: 16),
            Text('No Documents Yet', style: AppUIConstants.headingMd),
            const SizedBox(height: 8),
            Text(
              'Upload verification documents to get started',
              style: AppUIConstants.bodySm,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
