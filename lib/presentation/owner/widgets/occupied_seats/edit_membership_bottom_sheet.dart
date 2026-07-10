import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../domain/entities/custom_slot.dart';
import '../../../../domain/entities/library.dart';
import '../../../../domain/entities/membership.dart';
import '../../../../domain/repositories/user_repository.dart';
import '../../../../domain/usecases/get_occupied_seats.dart';

/// Bottom sheet for editing tenant stay details (bed, dates, etc.).
class EditMembershipBottomSheet extends StatefulWidget {
  const EditMembershipBottomSheet({
    super.key,
    required this.seatInfo,
    required this.library,
    required this.customSlots,
    required this.availableSeats,
    required this.onUpdate,
  });

  final OccupiedSeatInfo seatInfo;
  final Library library;
  final List<CustomSlot> customSlots;
  final List<String> availableSeats;
  final Future<void> Function({
    String? newSeatId,
    DateTime? newStartDate,
    DateTime? newEndDate,
    String? newStudentName,
  })
  onUpdate;

  @override
  State<EditMembershipBottomSheet> createState() =>
      _EditMembershipBottomSheetState();
}

class _EditMembershipBottomSheetState extends State<EditMembershipBottomSheet> {
  late String? _selectedSeatId;
  late DateTime _startDate;
  late DateTime _endDate;
  late TextEditingController _nameController;
  bool _isUpdating = false;
  bool _isLoadingUserData = false;

  @override
  void initState() {
    super.initState();
    final membership = widget.seatInfo.membership;
    _selectedSeatId = widget.seatInfo.seatId;
    _startDate = membership.startDate;
    // Auto-calculate end date based on plan
    _endDate = _calculateEndDate(_startDate, membership);

    // Initialize name controller with current value
    _nameController = TextEditingController(text: widget.seatInfo.displayName);

    // Fetch latest user info if available
    _fetchLatestUserInfo();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Fetches the latest user info from User repository if userId is available.
  /// This ensures we show the current username even if user updated their profile.
  Future<void> _fetchLatestUserInfo() async {
    final membership = widget.seatInfo.membership;

    // Only fetch if we have a userId (registered user)
    if (membership.userId == null || membership.userId!.isEmpty) {
      return;
    }

    setState(() => _isLoadingUserData = true);

    try {
      final userRepo = sl<UserRepository>();
      final result = await userRepo.getUserById(membership.userId!);

      result.fold(
        (failure) {
          // Silently fail - not critical, owner can still edit manually
        },
        (user) {
          if (mounted) {
            // Update name field with latest displayName from user profile
            setState(() {
              _nameController.text = user.displayName;
            });
          }
        },
      );
    } catch (e) {
      // Silently handle errors - not critical
    } finally {
      if (mounted) {
        setState(() => _isLoadingUserData = false);
      }
    }
  }

  /// Calculates end date based on start date and membership plan.
  DateTime _calculateEndDate(DateTime startDate, Membership membership) {
    // Use custom duration if available, otherwise use plan duration
    final durationDays = membership.effectiveDurationInDays;
    return startDate.add(Duration(days: durationDays));
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.grey.shade800,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.grey.shade900,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _startDate = picked;
        // Auto-calculate end date based on plan
        _endDate = _calculateEndDate(_startDate, widget.seatInfo.membership);
      });
    }
  }

  Future<void> _handleUpdate() async {
    if (_isUpdating) return;

    // Validate name
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tenant name cannot be empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isUpdating = true);

    try {
      await widget.onUpdate(
        newSeatId: _selectedSeatId != widget.seatInfo.seatId
            ? _selectedSeatId
            : null,
        newStartDate: _startDate != widget.seatInfo.membership.startDate
            ? _startDate
            : null,
        newEndDate: _endDate != widget.seatInfo.membership.endDate
            ? _endDate
            : null,
        newStudentName: name != widget.seatInfo.displayName ? name : null,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stay updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  bool get _hasChanges {
    return _selectedSeatId != widget.seatInfo.seatId ||
        _startDate != widget.seatInfo.membership.startDate ||
        _endDate != widget.seatInfo.membership.endDate ||
        _nameController.text.trim() != widget.seatInfo.displayName;
  }

  @override
  Widget build(BuildContext context) {
    final membership = widget.seatInfo.membership;
    final slotName = membership.slotId != null
        ? widget.customSlots
              .firstWhere(
                (s) => s.id == membership.slotId,
                orElse: () => widget.customSlots.first,
              )
              .name
        : membership.slot?.displayName ?? 'N/A';

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
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

            // Header - Compact
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Stay',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.seatInfo.displayName,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.grey.shade600,
                      size: 22,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content - Scrollable
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current Info - Compact Horizontal Layout
                    _buildCompactCurrentInfo(membership, slotName),

                    const SizedBox(height: 16),

                    // Tenant Name Field (no section wrapper)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Tenant Name',
                              labelStyle: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                              hintText: 'Enter tenant name',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade900,
                                  width: 1.5,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade900,
                            ),
                            textInputAction: TextInputAction.done,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        if (_isLoadingUserData)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Edit Section - Dates First
                    _buildSection(
                      title: 'Update Dates',
                      children: [
                        // Start Date
                        _buildLabel('Start Date'),
                        const SizedBox(height: 8),
                        _buildDateSelector(date: _startDate, isEditable: true),
                        const SizedBox(height: 16),

                        // End Date (Auto-calculated)
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      _buildLabel('End Date'),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          'Auto',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.seatInfo.membership.hasCustomDuration
                                        ? widget
                                              .seatInfo
                                              .membership
                                              .planDisplayLabel
                                        : 'Based on ${widget.seatInfo.membership.plan.displayLabel} stay',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildDateSelector(date: _endDate, isEditable: false),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Bed Selection Section
                    _buildSection(
                      title: 'Change Bed',
                      children: [_buildSeatSelector()],
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Bottom Actions - Compact
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isUpdating
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isUpdating || !_hasChanges
                            ? null
                            : _handleUpdate,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.grey.shade900,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isUpdating
                            ? SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Update',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                      ),
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

  Widget _buildCompactCurrentInfo(Membership membership, String slotName) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildCompactInfoItem(
              icon: Icons.bed_rounded,
              label: 'Bed',
              value: widget.seatInfo.seatId,
            ),
          ),
          Container(width: 1, height: 30, color: Colors.grey.shade300),
          Expanded(
            child: _buildCompactInfoItem(
              icon: Icons.meeting_room_rounded,
              label: 'Plan',
              value: slotName,
            ),
          ),
          Container(width: 1, height: 30, color: Colors.grey.shade300),
          Expanded(
            child: _buildCompactInfoItem(
              icon: Icons.calendar_today_rounded,
              label: 'Plan',
              value: membership.planDisplayLabel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade900,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade900,
      ),
    );
  }

  Widget _buildSeatSelector() {
    if (widget.availableSeats.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bed_outlined, color: Colors.grey.shade400, size: 20),
              const SizedBox(width: 8),
              Text(
                'No available beds',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    // Compact grid layout (5 columns, smaller items)
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1.1,
      ),
      itemCount: widget.availableSeats.length,
      itemBuilder: (context, index) {
        final seatId = widget.availableSeats[index];
        final isSelected = _selectedSeatId == seatId;
        final isCurrent = seatId == widget.seatInfo.seatId;

        return InkWell(
          onTap: () => setState(() => _selectedSeatId = seatId),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? Colors.grey.shade900 : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? Colors.grey.shade900
                    : (isCurrent ? Colors.grey.shade400 : Colors.grey.shade300),
                width: isCurrent ? 1.5 : 1,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isCurrent)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 12,
                      color: isSelected ? Colors.white : Colors.grey.shade600,
                    ),
                  if (isCurrent) const SizedBox(height: 2),
                  Text(
                    seatId,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.grey.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateSelector({
    required DateTime date,
    required bool isEditable,
  }) {
    return InkWell(
      onTap: isEditable ? () => _selectStartDate(context) : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isEditable ? Colors.grey.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isEditable ? Colors.grey.shade200 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 18,
              color: isEditable ? Colors.grey.shade600 : Colors.grey.shade500,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                DateFormat('MMM dd, yyyy').format(date),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isEditable
                      ? Colors.grey.shade900
                      : Colors.grey.shade700,
                ),
              ),
            ),
            if (isEditable)
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Colors.grey.shade400,
              )
            else
              Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: Colors.grey.shade400,
              ),
          ],
        ),
      ),
    );
  }
}
