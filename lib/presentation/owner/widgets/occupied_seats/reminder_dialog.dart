import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:unicons/unicons.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/reminder_qr_share.dart';
import '../../../../core/utils/whatsapp_launcher.dart';
import '../../../../domain/entities/library.dart';
import '../../../../domain/entities/reminder_template.dart';
import '../../../../domain/usecases/get_occupied_seats.dart';
import '../../../core/app_ui_constants.dart';
import '../../cubit/reminder_template_cubit.dart';
import '../../cubit/reminder_template_state.dart';
import 'reminder_delivery_selector.dart';
import 'reminder_template_actions.dart';
import 'reminder_whatsapp_helper.dart';

void showReminderBottomSheet({
  required BuildContext context,
  required OccupiedSeatInfo seatInfo,
  required Library library,
  required String notificationTitle,
  required String notificationBody,
  required double? amount,
  required ReminderType reminderType,
  required Future<void> Function(String editedBody) onSendPushNotification,
  String? customMessage,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => BlocProvider(
      create: (_) => sl<ReminderTemplateCubit>()..load(),
      child: ReminderBottomSheet(
        seatInfo: seatInfo,
        library: library,
        notificationTitle: notificationTitle,
        notificationBody: notificationBody,
        amount: amount,
        reminderType: reminderType,
        onSendPushNotification: onSendPushNotification,
        customMessage: customMessage,
      ),
    ),
  );
}

/// Bottom sheet for sending a reminder by push notification and/or WhatsApp.
class ReminderBottomSheet extends StatefulWidget {
  const ReminderBottomSheet({
    super.key,
    required this.seatInfo,
    required this.library,
    required this.notificationTitle,
    required this.notificationBody,
    required this.amount,
    required this.reminderType,
    required this.onSendPushNotification,
    this.customMessage,
  });

  final OccupiedSeatInfo seatInfo;
  final Library library;
  final String notificationTitle;
  final String notificationBody;
  final double? amount;
  final ReminderType reminderType;
  final Future<void> Function(String editedBody) onSendPushNotification;
  final String? customMessage;

  @override
  State<ReminderBottomSheet> createState() => _ReminderBottomSheetState();
}

class _ReminderBottomSheetState extends State<ReminderBottomSheet> {
  late final TextEditingController _bodyController;
  late ReminderDeliveryOption _selectedOption;
  Future<File>? _qrFile;
  bool _isSending = false;

  bool get _hasPhone =>
      (widget.seatInfo.studentPhone?.isNotEmpty ?? false) ||
      widget.seatInfo.membership.phoneNumber.isNotEmpty;

  ReminderTemplateValues get _templateValues {
    final endDate = widget.seatInfo.membership.endDate;
    final amount = widget.amount;
    return ReminderTemplateValues(
      studentName: widget.seatInfo.displayName,
      libraryName: widget.library.name,
      expiry: '${endDate.day}/${endDate.month}/${endDate.year}',
      amountText: amount == null ? null : '₹${amount.toStringAsFixed(0)}',
    );
  }

  @override
  void initState() {
    super.initState();
    _bodyController = TextEditingController(
      text: ReminderWhatsAppHelper.buildReminderMessage(
        seatInfo: widget.seatInfo,
        library: widget.library,
        type: widget.reminderType,
        amount: widget.amount,
        customMessage: widget.customMessage,
      ),
    );
    _selectedOption = _hasPhone
        ? ReminderDeliveryOption.both
        : ReminderDeliveryOption.pushOnly;
    final qrUrl = widget.library.ownerUpiQrUrl;
    if (widget.library.hasUpiQr && qrUrl != null) {
      _qrFile = prepareReminderQr(qrUrl)..ignore();
    }
  }

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ReminderTemplateCubit, ReminderTemplateState>(
      listenWhen: (previous, current) =>
          current.template != null && current.template != previous.template,
      listener: (_, state) {
        _bodyController.text = ReminderTemplate.render(
          state.template!,
          _templateValues,
        );
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppUIConstants.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppUIConstants.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 16),
                      _buildRecipientInfo(),
                      const SizedBox(height: 16),
                      _buildNotificationPreview(),
                      if (widget.amount != null) ...[
                        const SizedBox(height: 12),
                        _buildAmountInfo(),
                      ],
                      const SizedBox(height: 20),
                      ReminderDeliverySelector(
                        selected: _selectedOption,
                        hasPhone: _hasPhone,
                        onChanged: (option) =>
                            setState(() => _selectedOption = option),
                      ),
                    ],
                  ),
                ),
              ),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        _IconBadge(icon: UniconsLine.bell, color: AppUIConstants.primary),
        const SizedBox(width: 12),
        Expanded(child: Text('Send Reminder', style: AppUIConstants.headingLg)),
      ],
    );
  }

  Widget _buildRecipientInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusXl),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Row(
        children: [
          Icon(
            UniconsLine.user_circle,
            color: AppUIConstants.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Send reminder to ${widget.seatInfo.displayName}',
              style: AppUIConstants.bodyLg.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationPreview() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusXl),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.notificationTitle, style: AppUIConstants.headingSm),
          const SizedBox(height: 8),
          TextField(
            controller: _bodyController,
            maxLines: 4,
            minLines: 2,
            textInputAction: TextInputAction.done,
            style: AppUIConstants.bodyMd.copyWith(
              color: AppUIConstants.textPrimary,
              height: 1.4,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppUIConstants.background,
              contentPadding: const EdgeInsets.all(12),
              border: _inputBorder(AppUIConstants.border),
              enabledBorder: _inputBorder(AppUIConstants.border),
              focusedBorder: _inputBorder(AppUIConstants.primary),
              hintText: 'Edit message...',
              hintStyle: AppUIConstants.bodyMd.copyWith(
                color: AppUIConstants.textTertiary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          ReminderTemplateActions(
            bodyController: _bodyController,
            values: _templateValues,
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _inputBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
      borderSide: BorderSide(color: color),
    );
  }

  Widget _buildAmountInfo() {
    final isPending = widget.reminderType == ReminderType.pendingPayment;
    final label = isPending ? 'Full payment' : 'Remaining balance';
    final amountText = '₹${widget.amount!.toStringAsFixed(0)}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppUIConstants.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusXl),
        border: Border.all(
          color: AppUIConstants.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          _IconBadge(
            icon: UniconsLine.rupee_sign,
            color: AppUIConstants.warning,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppUIConstants.caption.copyWith(
                    color: AppUIConstants.warning,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  amountText,
                  style: AppUIConstants.statValue.copyWith(fontSize: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppUIConstants.surface,
        border: Border(top: BorderSide(color: AppUIConstants.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppUIConstants.primary,
            foregroundColor: AppUIConstants.surface,
            disabledBackgroundColor: AppUIConstants.disabled,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppUIConstants.radiusXl),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: _isSending ? null : () => _handleSend(context),
          icon: _isSending
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppUIConstants.surface,
                    ),
                  ),
                )
              : const Icon(UniconsLine.message, size: 18),
          label: Text(
            _isSending ? 'Sending...' : 'Send Reminder',
            style: AppUIConstants.headingSm.copyWith(
              color: AppUIConstants.surface,
            ),
          ),
        ),
      ),
    );
  }

  /// Sends the reminder text with the owner's UPI QR image to the resident's chat.
  Future<void> _sendWithQr(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    File? qrFile;
    try {
      qrFile = await (_qrFile ??= prepareReminderQr(
        widget.library.ownerUpiQrUrl!,
      ));
    } catch (_) {
      _qrFile = null;
    }
    final needsPaste = await shareReminderWithQr(
      phone: ReminderWhatsAppHelper.formatPhoneForWhatsApp(
        widget.seatInfo.studentPhone ?? widget.seatInfo.membership.phoneNumber,
      ),
      message: _bodyController.text,
      qrFile: qrFile,
      origin: origin,
    );
    if (!context.mounted || (!needsPaste && qrFile != null)) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          needsPaste
              ? 'QR copied. In WhatsApp, long-press the message box and tap Paste.'
              : 'Could not attach the UPI QR. Message sent without it.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleSend(BuildContext context) async {
    setState(() => _isSending = true);

    try {
      // Send push notification if selected
      if (_selectedOption == ReminderDeliveryOption.pushOnly ||
          _selectedOption == ReminderDeliveryOption.both) {
        await widget.onSendPushNotification(_bodyController.text);
      }

      // Send WhatsApp if selected
      if (_selectedOption == ReminderDeliveryOption.whatsappOnly ||
          _selectedOption == ReminderDeliveryOption.both) {
        final whatsappUrl = ReminderWhatsAppHelper.buildReminderWhatsAppUrl(
          seatInfo: widget.seatInfo,
          library: widget.library,
          type: widget.reminderType,
          amount: widget.amount,
          customMessage: _bodyController.text,
        );

        if (whatsappUrl != null && whatsappUrl.isNotEmpty) {
          try {
            if (widget.library.hasUpiQr) {
              if (context.mounted) await _sendWithQr(context);
            } else {
              await WhatsAppLauncher.launchFromWaUrl(whatsappUrl);
            }
          } catch (e) {
            _qrFile = null;
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to open WhatsApp: $e'),
                  backgroundColor: AppUIConstants.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Phone number not available for WhatsApp'),
                backgroundColor: AppUIConstants.warning,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }

      // Close bottom sheet if context is still mounted
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }
}

/// Rounded icon tile used in the sheet header and cards.
class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}
