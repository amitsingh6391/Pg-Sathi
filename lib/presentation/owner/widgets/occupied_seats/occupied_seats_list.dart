import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/app_ui_constants.dart';

import '../../../../domain/entities/custom_slot.dart';
import '../../../../domain/entities/library.dart';
import '../../../../domain/usecases/get_occupied_seats.dart';
import '../../cubit/occupied_seats_cubit.dart';
import 'occupied_seats_empty_views.dart';
import 'occupied_seats_student_card.dart';

/// Scrollable list of tenant stays with ads integration.
/// Extracted from occupied_seats_screen.dart for maintainability.
class OccupiedSeatsList extends StatelessWidget {
  const OccupiedSeatsList({
    super.key,
    required this.seats,
    required this.isActionInProgress,
    required this.onCancel,
    required this.onEdit,
    required this.onSendReminder,
    required this.onConvertPending,
    required this.libraryId,
    required this.customSlots,
    required this.library,
    this.emptyMessage,
    this.emptyIcon,
    this.hasActiveSearch = false,
    this.searchQuery = '',
    this.onReassign,
    this.onRefund,
    this.showExpired = false,
  });

  final List<OccupiedSeatInfo> seats;
  final bool isActionInProgress;
  final void Function(OccupiedSeatInfo) onCancel;
  final void Function(OccupiedSeatInfo) onEdit;
  final void Function(OccupiedSeatInfo) onSendReminder;
  final void Function(OccupiedSeatInfo seat, {bool forUpcomingPlan})
  onConvertPending;
  final void Function(OccupiedSeatInfo)? onReassign;
  final void Function(OccupiedSeatInfo)? onRefund;
  final String libraryId;
  final List<CustomSlot> customSlots;
  final Library library;
  final String? emptyMessage;
  final IconData? emptyIcon;
  final bool hasActiveSearch;
  final String searchQuery;
  final bool showExpired;

  @override
  Widget build(BuildContext context) {
    if (seats.isEmpty) {
      if (hasActiveSearch) {
        return OccupiedSeatsSearchEmptyView(searchQuery: searchQuery);
      }
      return OccupiedSeatsEmptyView(
        message: emptyMessage ?? 'No tenants',
        icon: emptyIcon,
      );
    }

    final searchHeaderOffset = hasActiveSearch ? 1 : 0;

    return RefreshIndicator(
      onRefresh: () => context.read<OccupiedSeatsCubit>().refresh(),
      color: AppUIConstants.primary,
      backgroundColor: Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        itemCount: seats.length + searchHeaderOffset,
        itemBuilder: (context, index) {
          if (hasActiveSearch && index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16, top: 8),
              child: Text(
                '${seats.length} ${seats.length == 1 ? 'tenant' : 'tenants'} found',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppUIConstants.textTertiary,
                ),
              ),
            );
          }

          final seat = seats[index - searchHeaderOffset];

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OccupiedSeatsStudentCard(
              seatInfo: seat,
              isActionInProgress: isActionInProgress,
              onCancel: () => onCancel(seat),
              onEdit: () => onEdit(seat),
              onSendReminder: () => onSendReminder(seat),
              onConvertPending: onConvertPending,
              onReassign: onReassign != null ? () => onReassign!(seat) : null,
              onRefund: () => onRefund?.call(seat),
              libraryId: libraryId,
              customSlots: customSlots,
              library: library,
              highlightQuery: hasActiveSearch ? searchQuery : null,
              showExpired: showExpired,
            ),
          );
        },
      ),
    );
  }
}
