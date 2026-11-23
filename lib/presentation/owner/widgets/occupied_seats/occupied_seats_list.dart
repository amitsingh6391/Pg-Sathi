import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/app_ui_constants.dart';

import '../../../../domain/entities/custom_slot.dart';
import '../../../../domain/entities/library.dart';
import '../../../../domain/usecases/get_occupied_seats.dart';
import '../../cubit/occupied_seats_cubit.dart';
import 'occupied_seats_empty_views.dart';
import 'occupied_seats_student_card.dart';

/// Scrollable list of resident stays. An optional [header] (summary, filters,
/// bed map) scrolls together with the cards so the whole screen is one
/// pull-to-refresh surface.
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
    this.header,
    this.onClearSearch,
    this.emptyActionLabel,
    this.onEmptyAction,
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
  final Widget? header;
  final VoidCallback? onClearSearch;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  @override
  Widget build(BuildContext context) {
    final headerOffset = header != null ? 1 : 0;
    final isEmpty = seats.isEmpty;
    // [header] + (empty view | result count + cards)
    final bodyCount = isEmpty ? 1 : seats.length + (hasActiveSearch ? 1 : 0);

    return RefreshIndicator(
      onRefresh: () => context.read<OccupiedSeatsCubit>().refresh(),
      color: AppUIConstants.primaryLight,
      backgroundColor: AppUIConstants.surfaceMuted,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 28),
        itemCount: headerOffset + bodyCount,
        itemBuilder: (context, index) {
          if (header != null && index == 0) return header!;
          final i = index - headerOffset;

          if (isEmpty) {
            return Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 12),
              child: hasActiveSearch
                  ? OccupiedSeatsSearchEmptyView(
                      searchQuery: searchQuery,
                      onClear: onClearSearch,
                    )
                  : OccupiedSeatsEmptyView(
                      message: emptyMessage ?? 'No residents',
                      icon: emptyIcon,
                      actionLabel: emptyActionLabel,
                      onAction: onEmptyAction,
                    ),
            );
          }

          if (hasActiveSearch && i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Text(
                '${seats.length} ${seats.length == 1 ? 'resident' : 'residents'} found',
                style: AppUIConstants.caption,
              ),
            );
          }

          final seat = seats[i - (hasActiveSearch ? 1 : 0)];

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: OccupiedSeatsStudentCard(
              key: ValueKey('${seat.seatId}-${seat.membership.id}'),
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
