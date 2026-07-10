import 'package:flutter/material.dart';

import '../../../../core/utils/whatsapp_launcher.dart';
import '../../../../domain/entities/library.dart';
import '../../../../domain/usecases/get_occupied_seats.dart';
import 'reminder_whatsapp_helper.dart';

/// Shows a bottom sheet for sending reminders with Push Notification and/or WhatsApp options.
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
    builder: (context) => ReminderBottomSheet(
      seatInfo: seatInfo,
      library: library,
      notificationTitle: notificationTitle,
      notificationBody: notificationBody,
      amount: amount,
      reminderType: reminderType,
      onSendPushNotification: onSendPushNotification,
      customMessage: customMessage,
    ),
  );
}

/// Modern bottom sheet for sending reminders.
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

  @override
  void initState() {
    super.initState();
    _bodyController = TextEditingController(text: widget.notificationBody);
  }

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildRecipientInfo(),
                    const SizedBox(height: 20),
                    _buildNotificationPreview(),
                    if (widget.amount != null) ...[
                      const SizedBox(height: 16),
                      _buildAmountInfo(),
                    ],
                    const SizedBox(height: 24),
                    _ReminderOptionsSection(
                      seatInfo: widget.seatInfo,
                      library: widget.library,
                      reminderType: widget.reminderType,
                      amount: widget.amount,
                      notificationTitle: widget.notificationTitle,
                      bodyController: _bodyController,
                      customMessage: widget.customMessage,
                      onSendPushNotification: widget.onSendPushNotification,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.notifications_active_rounded,
            color: Colors.orange.shade700,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Send Reminder',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecipientInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          Icon(
            Icons.person_rounded,
            color: Colors.blue.shade700,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Send reminder to ${widget.seatInfo.displayName}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.preview_rounded,
                size: 18,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                'Notification Preview',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.notificationTitle,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bodyController,
            maxLines: 4,
            minLines: 2,
            textInputAction: TextInputAction.done,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              hintText: 'Edit message...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInfo() {
    final isPending = widget.reminderType == ReminderType.pendingPayment;
    final label = isPending ? 'Full payment' : 'Remaining balance';
    final amountText = '₹${widget.amount!.toStringAsFixed(0)}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.payment_outlined,
              size: 20,
              color: Colors.orange.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  amountText,
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
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

/// Section showing reminder delivery options (Push, WhatsApp, or Both).
class _ReminderOptionsSection extends StatefulWidget {
  const _ReminderOptionsSection({
    required this.seatInfo,
    required this.library,
    required this.reminderType,
    required this.amount,
    required this.notificationTitle,
    required this.bodyController,
    required this.onSendPushNotification,
    this.customMessage,
  });

  final OccupiedSeatInfo seatInfo;
  final Library library;
  final ReminderType reminderType;
  final double? amount;
  final String notificationTitle;
  final TextEditingController bodyController;
  final Future<void> Function(String editedBody) onSendPushNotification;
  final String? customMessage;

  @override
  State<_ReminderOptionsSection> createState() =>
      _ReminderOptionsSectionState();
}

class _ReminderOptionsSectionState extends State<_ReminderOptionsSection> {
  ReminderDeliveryOption _selectedOption = ReminderDeliveryOption.both;
  bool _isSending = false;

  @override
  Widget build(BuildContext context) {
    final hasPhone = (widget.seatInfo.studentPhone?.isNotEmpty ?? false) ||
        (widget.seatInfo.membership.phoneNumber.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose delivery method',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 16),
        _buildOptionTile(
          option: ReminderDeliveryOption.pushOnly,
          icon: Icons.notifications_rounded,
          label: 'Push Notification',
          description: 'Send in-app notification',
        ),
        const SizedBox(height: 12),
        if (hasPhone)
          _buildOptionTile(
            option: ReminderDeliveryOption.whatsappOnly,
            icon: Icons.chat_rounded,
            label: 'WhatsApp',
            description: 'Open WhatsApp chat',
          ),
        if (hasPhone) const SizedBox(height: 12),
        if (hasPhone)
          _buildOptionTile(
            option: ReminderDeliveryOption.both,
            icon: Icons.notifications_active_rounded,
            label: 'Both',
            description: 'Push notification + WhatsApp',
            isRecommended: true,
          ),
        if (!hasPhone) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'WhatsApp not available - phone number not found',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        _buildSendButton(context),
      ],
    );
  }

  Widget _buildOptionTile({
    required ReminderDeliveryOption option,
    required IconData icon,
    required String label,
    required String description,
    bool isRecommended = false,
  }) {
    final isSelected = _selectedOption == option;

    return InkWell(
      onTap: () => setState(() => _selectedOption = option),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.orange.shade700
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.orange.shade100
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? Colors.orange.shade700
                    : Colors.grey.shade600,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: isSelected
                                ? Colors.orange.shade800
                                : Colors.grey.shade800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isRecommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade700,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Recommended',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? Colors.orange.shade700
                      : Colors.grey.shade400,
                  width: 2,
                ),
                color: isSelected ? Colors.orange.shade700 : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange.shade700,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
        ),
        onPressed: _isSending ? null : () => _handleSend(context),
        child: _isSending
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Send Reminder',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }

  Future<void> _handleSend(BuildContext context) async {
    setState(() => _isSending = true);

    try {
      // Send push notification if selected
      if (_selectedOption == ReminderDeliveryOption.pushOnly ||
          _selectedOption == ReminderDeliveryOption.both) {
        await widget.onSendPushNotification(widget.bodyController.text);
      }

      // Send WhatsApp if selected
      if (_selectedOption == ReminderDeliveryOption.whatsappOnly ||
          _selectedOption == ReminderDeliveryOption.both) {
        final whatsappUrl = ReminderWhatsAppHelper.buildReminderWhatsAppUrl(
          seatInfo: widget.seatInfo,
          library: widget.library,
          type: widget.reminderType,
          amount: widget.amount,
          customMessage: widget.customMessage,
        );

        if (whatsappUrl != null && whatsappUrl.isNotEmpty) {
          try {
            await WhatsAppLauncher.launchFromWaUrl(whatsappUrl);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to open WhatsApp: $e'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Phone number not available for WhatsApp'),
                backgroundColor: Colors.orange,
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

/// Reminder delivery options.
enum ReminderDeliveryOption {
  pushOnly,
  whatsappOnly,
  both,
}
