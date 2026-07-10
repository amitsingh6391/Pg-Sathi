// Radio deprecation: RadioGroup migration requires significant refactor
// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/notice.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/owner_notice_cubit.dart';

/// Create Notice Screen - for creating new announcements
class CreateNoticeScreen extends StatelessWidget {
  const CreateNoticeScreen({
    super.key,
    required this.libraryId,
    required this.ownerId,
  });

  final String libraryId;
  final String ownerId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<OwnerNoticeCubit>(),
      child: _CreateNoticeView(libraryId: libraryId, ownerId: ownerId),
    );
  }
}

class _CreateNoticeView extends StatefulWidget {
  const _CreateNoticeView({required this.libraryId, required this.ownerId});

  final String libraryId;
  final String ownerId;

  @override
  State<_CreateNoticeView> createState() => _CreateNoticeViewState();
}

class _CreateNoticeViewState extends State<_CreateNoticeView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  NoticeTargetAudience _selectedAudience = NoticeTargetAudience.all;
  bool _sendPushNotification = true;
  bool _sendWhatsApp = false;
  DateTime? _scheduledFor;
  DateTime? _expiresAt;
  final List<File> _attachmentFiles = [];
  final List<NoticeLink> _externalLinks = [];

  @override
  void initState() {
    super.initState();
    // Load remaining monthly WhatsApp quota for the subtitle.
    context.read<OwnerNoticeCubit>().loadWhatsAppQuota(widget.libraryId);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(
        title: const Text('Create Notice'),
        backgroundColor: AppUIConstants.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: BlocConsumer<OwnerNoticeCubit, OwnerNoticeState>(
        listener: (context, state) {
          if (state.status == OwnerNoticeStatus.created) {
            final waMessage = state.whatsAppMessage;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  waMessage == null
                      ? 'Notice created successfully'
                      : 'Notice created • $waMessage',
                ),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, true); // Return true to indicate success
          }

          if (state.status == OwnerNoticeStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage ?? 'Failed to create notice'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          final isCreating = state.status == OwnerNoticeStatus.creating;

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppUIConstants.spacingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title *',
                      hintText: 'Enter notice title',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                    enabled: !isCreating,
                  ),
                  const SizedBox(height: AppUIConstants.spacingMd),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description *',
                      hintText: 'Enter notice description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a description';
                      }
                      return null;
                    },
                    enabled: !isCreating,
                  ),
                  const SizedBox(height: AppUIConstants.spacingLg),
                  const Text(
                    'Target Audience',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppUIConstants.spacingSm),
                  // Only the currently-supported audiences. Slot/seat targeting
                  // is future work and intentionally not shown yet.
                  ...const [
                    NoticeTargetAudience.all,
                    NoticeTargetAudience.activeStudents,
                  ].map((audience) {
                    return RadioListTile<NoticeTargetAudience>(
                      title: Text(_getAudienceLabel(audience)),
                      subtitle: Text(_getAudienceDescription(audience)),
                      value: audience,
                      groupValue: _selectedAudience,
                      onChanged: isCreating
                          ? null
                          : (value) =>
                                setState(() => _selectedAudience = value!),
                    );
                  }),
                  const SizedBox(height: AppUIConstants.spacingLg),
                  SwitchListTile(
                    title: const Text('Send Push Notification'),
                    subtitle: const Text('Notify all students when published'),
                    value: _sendPushNotification,
                    onChanged: isCreating
                        ? null
                        : (value) =>
                              setState(() => _sendPushNotification = value),
                  ),
                  _buildWhatsAppToggle(state, isCreating),
                  const Divider(height: 32),
                  const Text(
                    'Scheduling (Optional)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppUIConstants.spacingSm),
                  ListTile(
                    leading: const Icon(Icons.schedule),
                    title: const Text('Scheduled Publish'),
                    subtitle: Text(
                      _scheduledFor == null
                          ? 'Publish immediately'
                          : 'Publish on ${DateFormat('MMM d, y h:mm a').format(_scheduledFor!)}',
                    ),
                    trailing: _scheduledFor == null
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: isCreating
                                ? null
                                : () => setState(() => _scheduledFor = null),
                          ),
                    onTap: isCreating ? null : _selectScheduledDate,
                  ),
                  ListTile(
                    leading: const Icon(Icons.event_busy),
                    title: const Text('Expiry Date'),
                    subtitle: Text(
                      _expiresAt == null
                          ? 'Never expires'
                          : 'Expires on ${DateFormat('MMM d, y h:mm a').format(_expiresAt!)}',
                    ),
                    trailing: _expiresAt == null
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: isCreating
                                ? null
                                : () => setState(() => _expiresAt = null),
                          ),
                    onTap: isCreating ? null : _selectExpiryDate,
                  ),
                  const Divider(height: 32),
                  const Text(
                    'Attachments (Optional)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Max 10MB per file. Supported: Images & PDFs',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: AppUIConstants.spacingSm),
                  if (_attachmentFiles.isNotEmpty)
                    ..._attachmentFiles.asMap().entries.map((entry) {
                      final index = entry.key;
                      final file = entry.value;
                      final fileName = file.path.split('/').last;
                      final fileSize = (file.lengthSync() / 1024)
                          .toStringAsFixed(1);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0A66C2).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getFileIcon(fileName),
                                color: const Color(0xFF0A66C2),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fileName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$fileSize KB',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: isCreating
                                  ? null
                                  : () => _removeAttachment(index),
                              color: Colors.red,
                            ),
                          ],
                        ),
                      );
                    }),
                  OutlinedButton.icon(
                    onPressed: isCreating ? null : _pickAttachment,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Add Attachment'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0A66C2),
                      side: const BorderSide(color: Color(0xFF0A66C2)),
                    ),
                  ),
                  const SizedBox(height: AppUIConstants.spacingLg),
                  const Text(
                    'External Links (Optional)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppUIConstants.spacingSm),
                  if (_externalLinks.isNotEmpty)
                    ..._externalLinks.asMap().entries.map((entry) {
                      final index = entry.key;
                      final link = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0A66C2).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.link,
                                color: Color(0xFF0A66C2),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    link.title,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    link.url,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: isCreating
                                  ? null
                                  : () => _removeLink(index),
                              color: Colors.red,
                            ),
                          ],
                        ),
                      );
                    }),
                  OutlinedButton.icon(
                    onPressed: isCreating ? null : _addLink,
                    icon: const Icon(Icons.add_link),
                    label: const Text('Add Link'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0A66C2),
                      side: const BorderSide(color: Color(0xFF0A66C2)),
                    ),
                  ),
                  const SizedBox(height: AppUIConstants.spacingXl),
                  ElevatedButton(
                    onPressed: isCreating ? null : _createNotice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppUIConstants.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: isCreating
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('Create Notice'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWhatsAppToggle(OwnerNoticeState state, bool isCreating) {
    final remaining = state.whatsAppQuotaRemaining;
    final quotaText = remaining == null
        ? 'Also deliver to tenants on WhatsApp'
        : '$remaining of 5 free WhatsApp sends left this month';
    final atLimit = remaining != null && remaining <= 0;
    final scheduled = _scheduledFor != null;

    return SwitchListTile(
      secondary: const FaIcon(
        FontAwesomeIcons.whatsapp,
        color: Color(0xFF25D366),
      ),
      title: const Text('Also send on WhatsApp'),
      subtitle: Text(
        scheduled
            ? 'WhatsApp is sent only for notices published immediately'
            : atLimit
                ? 'Monthly WhatsApp limit reached'
                : quotaText,
      ),
      value: _sendWhatsApp && !atLimit && !scheduled,
      onChanged: (isCreating || atLimit || scheduled)
          ? null
          : (value) => setState(() => _sendWhatsApp = value),
    );
  }

  String _getAudienceLabel(NoticeTargetAudience audience) {
    switch (audience) {
      case NoticeTargetAudience.all:
        return 'All Students';
      case NoticeTargetAudience.activeStudents:
        return 'Active Students Only';
      case NoticeTargetAudience.slot:
        return 'Specific Slots (Coming Soon)';
      case NoticeTargetAudience.seat:
        return 'Specific Seats (Coming Soon)';
    }
  }

  String _getAudienceDescription(NoticeTargetAudience audience) {
    switch (audience) {
      case NoticeTargetAudience.all:
        return 'Send to all tenants in your PG';
      case NoticeTargetAudience.activeStudents:
        return 'Send only to students with active memberships';
      case NoticeTargetAudience.slot:
        return 'Target specific time slots';
      case NoticeTargetAudience.seat:
        return 'Target specific seats';
    }
  }

  Future<void> _selectScheduledDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date == null) return;

    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time == null) return;

    setState(() {
      _scheduledFor = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _selectExpiryDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date == null) return;

    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time == null) return;

    setState(() {
      _expiresAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _pickAttachment() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Attachment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Color(0xFF0A66C2),
              ),
              title: const Text('Pick from Gallery'),
              subtitle: const Text('Choose images'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.folder, color: Color(0xFF0A66C2)),
              title: const Text('Pick from Files'),
              subtitle: const Text('Choose images or PDFs'),
              onTap: () => Navigator.pop(context, 'files'),
            ),
          ],
        ),
      ),
    );

    if (choice == null) return;

    if (choice == 'gallery') {
      await _pickFromGallery();
    } else {
      await _pickFromFiles();
    }
  }

  Future<void> _pickFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();

    if (images.isEmpty) return;

    final files = images.map((xFile) => File(xFile.path)).toList();

    // Validate file sizes
    for (final file in files) {
      final size = await file.length();
      if (size > 10 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'File ${file.path.split('/').last} exceeds 10MB limit',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      _attachmentFiles.addAll(files);
    });
  }

  Future<void> _pickFromFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      allowMultiple: true,
    );

    if (result == null) return;

    final files = result.paths
        .where((path) => path != null)
        .map((path) => File(path!))
        .toList();

    // Validate file sizes
    for (final file in files) {
      final size = await file.length();
      if (size > 10 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'File ${file.path.split('/').last} exceeds 10MB limit',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      _attachmentFiles.addAll(files);
    });
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'doc':
      case 'docx':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachmentFiles.removeAt(index);
    });
  }

  Future<void> _addLink() async {
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (context) => _AddLinkDialog(),
    );

    if (result != null &&
        result['title']?.isNotEmpty == true &&
        result['url']?.isNotEmpty == true) {
      setState(() {
        _externalLinks.add(
          NoticeLink(
            id: const Uuid().v4(),
            title: result['title']!,
            url: result['url']!,
          ),
        );
      });
    }
  }

  void _removeLink(int index) {
    setState(() {
      _externalLinks.removeAt(index);
    });
  }

  void _createNotice() {
    if (!_formKey.currentState!.validate()) return;

    context.read<OwnerNoticeCubit>().createNewNotice(
      libraryId: widget.libraryId,
      ownerId: widget.ownerId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      targetAudience: _selectedAudience,
      attachmentFiles: _attachmentFiles,
      externalLinks: _externalLinks,
      scheduledFor: _scheduledFor,
      expiresAt: _expiresAt,
      sendPushNotification: _sendPushNotification,
      sendWhatsApp: _sendWhatsApp,
    );
  }
}

/// Dialog for adding external links with proper controller lifecycle
class _AddLinkDialog extends StatefulWidget {
  @override
  State<_AddLinkDialog> createState() => _AddLinkDialogState();
}

class _AddLinkDialogState extends State<_AddLinkDialog> {
  final _titleController = TextEditingController();
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add External Link'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Link Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppUIConstants.spacingMd),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://example.com',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final title = _titleController.text.trim();
            final url = _urlController.text.trim();

            if (title.isEmpty || url.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please fill in both fields'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }

            Navigator.pop(context, {'title': title, 'url': url});
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
