import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/notice.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/owner_notice_cubit.dart';
import '../widgets/create_notice/notice_add_link_dialog.dart';
import '../widgets/create_notice/notice_attachment_picker.dart';
import '../widgets/create_notice/notice_audience_selector.dart';
import '../widgets/create_notice/notice_form_parts.dart';
import '../widgets/create_notice/notice_publish_bar.dart';
import '../widgets/create_notice/notice_timing_card.dart';
import '../widgets/create_notice/notice_whatsapp_toggle.dart';

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
      create: (_) => sl<OwnerNoticeCubit>()..loadWhatsAppCredits(ownerId),
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
  final _messageController = TextEditingController();

  NoticeTargetAudience _audience = NoticeTargetAudience.all;
  bool _sendPush = true;
  bool _sendWhatsApp = true;
  DateTime? _scheduledFor;
  DateTime? _expiresAt;
  final List<File> _files = [];
  final List<NoticeLink> _links = [];

  // Matches the daily publishScheduledNotices job (9 AM IST).
  static const _publishHour = 9;

  // Scheduled sends use the credits available at publish time.
  bool _willSendWhatsApp(int? credits) =>
      _sendWhatsApp && (_scheduledFor != null || (credits ?? 0) > 0);

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _onStateChanged(BuildContext context, OwnerNoticeState state) {
    final messenger = ScaffoldMessenger.of(context);
    if (state.status == OwnerNoticeStatus.created) {
      final wa = state.whatsappMessage;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _scheduledFor != null
                ? 'Notice scheduled'
                : wa == null
                ? 'Notice published'
                : 'Notice published • $wa',
          ),
          backgroundColor: AppUIConstants.success,
        ),
      );
      Navigator.pop(context, true);
    } else if (state.status == OwnerNoticeStatus.error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(state.errorMessage ?? 'Failed to create notice'),
          backgroundColor: AppUIConstants.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OwnerNoticeCubit, OwnerNoticeState>(
      listener: _onStateChanged,
      builder: (context, state) {
        final busy = state.status == OwnerNoticeStatus.creating;
        return Scaffold(
          backgroundColor: AppUIConstants.background,
          appBar: AppBar(
            title: const Text('New notice'),
            backgroundColor: AppUIConstants.surface,
            foregroundColor: AppUIConstants.textPrimary,
            elevation: 0,
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(AppUIConstants.spacingLg),
              children: [
                _messageCard(busy),
                const SizedBox(height: AppUIConstants.spacingMd),
                _attachmentsCard(busy),
                const SizedBox(height: AppUIConstants.spacingMd),
                NoticeSectionCard(
                  title: 'Who should see it?',
                  child: NoticeAudienceSelector(
                    value: _audience,
                    onChanged: busy
                        ? null
                        : (v) => setState(() => _audience = v),
                  ),
                ),
                const SizedBox(height: AppUIConstants.spacingMd),
                _deliveryCard(busy, state.whatsappCredits),
                const SizedBox(height: AppUIConstants.spacingMd),
                NoticeTimingCard(
                  scheduledFor: _scheduledFor,
                  expiresAt: _expiresAt,
                  enabled: !busy,
                  onPickSchedule: () => _pickDate(scheduled: true),
                  onPickExpiry: () => _pickDate(scheduled: false),
                  onClearSchedule: () => setState(() => _scheduledFor = null),
                  onClearExpiry: () => setState(() => _expiresAt = null),
                ),
              ],
            ),
          ),
          bottomNavigationBar: NoticePublishBar(
            busy: busy,
            isScheduled: _scheduledFor != null,
            sendingWhatsApp:
                _scheduledFor == null &&
                _willSendWhatsApp(state.whatsappCredits),
            onPressed: _submit,
          ),
        );
      },
    );
  }

  Widget _messageCard(bool busy) {
    return NoticeSectionCard(
      title: 'Message',
      child: TextFormField(
        controller: _messageController,
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        enabled: !busy,
        minLines: 6,
        maxLines: 12,
        maxLength: 1000,
        textCapitalization: TextCapitalization.sentences,
        style: AppUIConstants.bodyLg.copyWith(height: 1.5),
        decoration: InputDecoration(
          hintText: 'Write your announcement for tenants…',
          hintStyle: AppUIConstants.bodyMd,
          filled: true,
          fillColor: AppUIConstants.background,
          contentPadding: const EdgeInsets.all(AppUIConstants.spacingMd),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            borderSide: const BorderSide(color: AppUIConstants.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            borderSide: const BorderSide(color: AppUIConstants.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            borderSide: const BorderSide(color: AppUIConstants.primary),
          ),
        ),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Please write the notice' : null,
      ),
    );
  }

  Widget _attachmentsCard(bool busy) {
    return NoticeSectionCard(
      title: 'Attachments & links',
      caption: 'Optional • images under 5 MB (for WhatsApp), PDFs up to 10 MB',
      child: Column(
        children: [
          for (final (i, file) in _files.indexed)
            NoticeItemRow(
              icon: file.path.toLowerCase().endsWith('.pdf')
                  ? Icons.picture_as_pdf_outlined
                  : Icons.image_outlined,
              title: file.path.split('/').last,
              subtitle: '${(file.lengthSync() / 1024).toStringAsFixed(0)} KB',
              onRemove: busy ? null : () => setState(() => _files.removeAt(i)),
            ),
          for (final (i, link) in _links.indexed)
            NoticeItemRow(
              icon: Icons.link_rounded,
              title: link.title,
              subtitle: link.url,
              onRemove: busy ? null : () => setState(() => _links.removeAt(i)),
            ),
          Row(
            children: [
              Expanded(
                child: _addButton(
                  Icons.attach_file_rounded,
                  'Attach file',
                  busy ? null : _addFiles,
                ),
              ),
              const SizedBox(width: AppUIConstants.spacingSm),
              Expanded(
                child: _addButton(
                  Icons.add_link_rounded,
                  'Add link',
                  busy ? null : _addLink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _addButton(IconData icon, String label, VoidCallback? onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppUIConstants.primary,
        side: const BorderSide(color: AppUIConstants.border),
        padding: const EdgeInsets.symmetric(vertical: AppUIConstants.spacingMd),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
        ),
      ),
    );
  }

  Widget _deliveryCard(bool busy, int? credits) {
    return NoticeSectionCard(
      title: 'Notify tenants',
      padding: const EdgeInsets.fromLTRB(
        AppUIConstants.spacingLg,
        AppUIConstants.spacingLg,
        AppUIConstants.spacingSm,
        AppUIConstants.spacingSm,
      ),
      child: Column(
        children: [
          NoticeSwitchRow(
            icon: Icons.notifications_active_outlined,
            title: 'Push notification',
            subtitle: 'Free • sent when the notice goes live',
            value: _sendPush,
            onChanged: busy ? null : (v) => setState(() => _sendPush = v),
          ),
          NoticeWhatsAppToggle(
            value: _sendWhatsApp,
            credits: credits,
            isScheduled: _scheduledFor != null,
            onChanged: busy ? null : (v) => setState(() => _sendWhatsApp = v),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate({required bool scheduled}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = await showDatePicker(
      context: context,
      initialDate: today.add(Duration(days: scheduled ? 1 : 7)),
      // Scheduled notices go out at 9 AM, so the earliest is tomorrow.
      firstDate: scheduled ? today.add(const Duration(days: 1)) : today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    if (scheduled) {
      setState(() => _scheduledFor = date.copyWith(hour: _publishHour));
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;
    setState(
      () => _expiresAt = date.copyWith(hour: time.hour, minute: time.minute),
    );
  }

  Future<void> _addFiles() async {
    final files = await pickNoticeAttachments(context);
    if (files.isNotEmpty && mounted) setState(() => _files.addAll(files));
  }

  Future<void> _addLink() async {
    final link = await showNoticeAddLinkDialog(context);
    if (link != null && mounted) setState(() => _links.add(link));
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<OwnerNoticeCubit>().createNewNotice(
      libraryId: widget.libraryId,
      ownerId: widget.ownerId,
      description: _messageController.text.trim(),
      targetAudience: _audience,
      attachmentFiles: _files,
      externalLinks: _links,
      scheduledFor: _scheduledFor,
      expiresAt: _expiresAt,
      sendPushNotification: _sendPush,
      sendWhatsApp: _willSendWhatsApp(
        context.read<OwnerNoticeCubit>().state.whatsappCredits,
      ),
    );
  }
}
