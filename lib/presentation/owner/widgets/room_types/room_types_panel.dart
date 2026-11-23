import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/entities/custom_slot.dart';
import '../../../core/app_ui_constants.dart';
import '../../cubit/slot_management_cubit.dart';
import '../../cubit/slot_management_state.dart';
import 'room_type_sheet.dart';

/// Common PG room types offered as one-tap starting points.
const List<String> _roomTemplates = [
  'Single sharing',
  'Double sharing',
  'Triple sharing',
  'Dormitory',
];

/// Room types & beds editor, styled like Library Manager's slots step:
/// a total-beds row, quick-add chips, and a compact list of room types that
/// open a bottom sheet to edit. Used by onboarding and the Room Types screen.
///
/// Expects a [SlotManagementCubit] above it that has already loaded slots.
class RoomTypesPanel extends StatefulWidget {
  const RoomTypesPanel({
    super.key,
    required this.initialTotalBeds,
    required this.onTotalBedsChanged,
    this.header,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 32),
  });

  /// Value shown in the "Total beds in PG" field on open.
  final int? initialTotalBeds;

  /// Called with the new total (null when cleared).
  final ValueChanged<int?> onTotalBedsChanged;

  /// Optional content shown above everything (e.g. an onboarding title).
  final Widget? header;

  final EdgeInsetsGeometry padding;

  @override
  State<RoomTypesPanel> createState() => _RoomTypesPanelState();
}

class _RoomTypesPanelState extends State<RoomTypesPanel> {
  final _totalBedsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final total = widget.initialTotalBeds;
    if (total != null && total > 0) {
      _totalBedsController.text = total.toString();
    }
  }

  @override
  void dispose() {
    _totalBedsController.dispose();
    super.dispose();
  }

  void _openSheet({CustomSlot? slot, String? templateName}) {
    final cubit = context.read<SlotManagementCubit>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoomTypeSheet(
        slot: slot,
        initialName: templateName,
        onSave:
            (
              name,
              startTime,
              endTime,
              price,
              capacity,
              seatPrefix,
              seatStartNumber,
            ) async {
              if (slot == null) {
                await cubit.createSlotForLibrary(
                  name: name,
                  startTime: startTime,
                  endTime: endTime,
                  price: price,
                  capacity: capacity,
                  seatPrefix: seatPrefix,
                  seatStartNumber: seatStartNumber,
                );
              } else {
                await cubit.updateSlotForLibrary(
                  slot.copyWith(
                    name: name,
                    startTime: startTime,
                    endTime: endTime,
                    price: price,
                    capacity: capacity,
                    seatPrefix: seatPrefix,
                    seatStartNumber: seatStartNumber,
                  ),
                );
              }
            },
        onToggleActive: slot == null
            ? null
            : () => cubit.toggleSlotActive(
                // Use the freshest copy so repeated toggles stay in sync.
                cubit.state.slots.firstWhere(
                  (s) => s.id == slot.id,
                  orElse: () => slot,
                ),
              ),
        onDelete: slot == null ? null : () => _confirmDelete(cubit, slot),
      ),
    );
  }

  Future<void> _confirmDelete(
    SlotManagementCubit cubit,
    CustomSlot slot,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete room type'),
        content: Text(
          'Delete "${slot.name}"? This cannot be undone.',
          style: AppUIConstants.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppUIConstants.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      HapticFeedback.mediumImpact();
      cubit.deleteSlotForLibrary(slot.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SlotManagementCubit, SlotManagementState>(
      listener: (context, state) {
        final cubit = context.read<SlotManagementCubit>();
        if (state.hasSuccess && state.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.successMessage!),
              backgroundColor: AppUIConstants.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
          cubit.resetError();
        } else if (state.hasError && state.failure != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.failure!.message ?? 'An error occurred'),
              backgroundColor: AppUIConstants.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
          cubit.resetError();
        }
      },
      builder: (context, state) {
        final slots = state.slots;
        final bedsInRooms = slots.fold<int>(0, (sum, s) => sum + s.capacity);

        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: ListView(
            padding: widget.padding,
            children: [
              ?widget.header,
              _TotalBedsRow(
                controller: _totalBedsController,
                bedsInRooms: bedsInRooms,
                roomCount: slots.length,
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  widget.onTotalBedsChanged(
                    parsed != null && parsed > 0 ? parsed : null,
                  );
                },
              ),
              const SizedBox(height: 24),
              const _Label('Add a room type'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final name in _roomTemplates)
                    _AddChip(
                      label: name,
                      onPressed: () => _openSheet(templateName: name),
                    ),
                  _AddChip(label: 'Custom', onPressed: () => _openSheet()),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(child: _Label('Your room types')),
                  if (slots.isNotEmpty)
                    Text(
                      '${slots.length} type${slots.length == 1 ? '' : 's'} · '
                      '$bedsInRooms bed${bedsInRooms == 1 ? '' : 's'}',
                      style: AppUIConstants.bodySm,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (state.isLoading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if (slots.isEmpty) ...[
                  const _Notice(
                    'Add at least one room type with its rent so residents '
                    'can be assigned beds.',
                  ),
                  const SizedBox(height: 12),
                ],
                _RoomList(
                  slots: slots,
                  onTap: (s) => _openSheet(slot: s),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: AppUIConstants.textPrimary,
    ),
  );
}

class _TotalBedsRow extends StatelessWidget {
  const _TotalBedsRow({
    required this.controller,
    required this.bedsInRooms,
    required this.roomCount,
    required this.onChanged,
  });

  final TextEditingController controller;
  final int bedsInRooms;
  final int roomCount;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppUIConstants.primarySoft,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            ),
            child: const Icon(
              Icons.bed_rounded,
              size: 20,
              color: AppUIConstants.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total beds in PG', style: AppUIConstants.bodyLg),
                const SizedBox(height: 2),
                Text(
                  roomCount == 0
                      ? 'Optional · your full bed capacity'
                      : '$bedsInRooms set up in room types',
                  style: AppUIConstants.bodySm,
                ),
              ],
            ),
          ),
          SizedBox(
            width: 84,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: onChanged,
              style: AppUIConstants.bodyLg.copyWith(
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(hintText: '—', isDense: true),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  const _AddChip({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(
        Icons.add_rounded,
        size: 16,
        color: AppUIConstants.primary,
      ),
      label: Text(label),
      onPressed: () {
        HapticFeedback.selectionClick();
        onPressed();
      },
      backgroundColor: AppUIConstants.surface,
      side: const BorderSide(color: AppUIConstants.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
      ),
      labelStyle: AppUIConstants.bodySm.copyWith(
        color: AppUIConstants.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppUIConstants.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(
          color: AppUIConstants.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppUIConstants.warning,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: AppUIConstants.bodySm)),
        ],
      ),
    );
  }
}

class _RoomList extends StatelessWidget {
  const _RoomList({required this.slots, required this.onTap});

  final List<CustomSlot> slots;
  final ValueChanged<CustomSlot> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(color: AppUIConstants.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: slots.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(
                    Icons.meeting_room_outlined,
                    size: 28,
                    color: AppUIConstants.textTertiary,
                  ),
                  SizedBox(height: 8),
                  Text('No room types yet', style: AppUIConstants.bodyLg),
                  SizedBox(height: 2),
                  Text(
                    'Tap a chip above to add one',
                    style: AppUIConstants.bodySm,
                  ),
                ],
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < slots.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _RoomRow(slot: slots[i], onTap: () => onTap(slots[i])),
                ],
              ],
            ),
    );
  }
}

/// One room type: name + bed numbers on the left, rent + beds on the right.
class _RoomRow extends StatelessWidget {
  const _RoomRow({required this.slot, required this.onTap});

  final CustomSlot slot;
  final VoidCallback onTap;

  String get _bedRange {
    final labels = slot.seatLabels;
    if (labels.isEmpty) return 'No beds';
    if (labels.length == 1) return 'Bed ${labels.first}';
    return 'Beds ${labels.first} – ${labels.last}';
  }

  @override
  Widget build(BuildContext context) {
    final active = slot.isActive;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          slot.name,
                          style: AppUIConstants.bodyLg.copyWith(
                            fontWeight: FontWeight.w600,
                            color: active
                                ? AppUIConstants.textPrimary
                                : AppUIConstants.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!active) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppUIConstants.surfaceMuted,
                            borderRadius: BorderRadius.circular(
                              AppUIConstants.radiusFull,
                            ),
                          ),
                          child: const Text(
                            'Inactive',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppUIConstants.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(_bedRange, style: AppUIConstants.bodySm),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${slot.price.toStringAsFixed(0)}/mo',
                  style: AppUIConstants.bodyLg.copyWith(
                    fontWeight: FontWeight.w700,
                    color: active
                        ? AppUIConstants.textPrimary
                        : AppUIConstants.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${slot.capacity} bed${slot.capacity == 1 ? '' : 's'}',
                  style: AppUIConstants.bodySm,
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppUIConstants.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
