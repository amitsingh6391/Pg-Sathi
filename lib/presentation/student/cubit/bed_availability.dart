import '../../../domain/entities/custom_slot.dart';
import '../../../domain/entities/membership.dart';

/// Bed availability helpers for resident-facing screens.
abstract class BedAvailability {
  /// Bed labels (e.g. "A1") of [slot] that no active/reserved stay holds.
  static List<String> freeBeds(
    CustomSlot slot,
    List<Membership> activeAndReserved,
  ) {
    final now = DateTime.now();
    final taken = <String>{
      for (final m in activeAndReserved)
        if ((m.status == MembershipStatus.active ||
                m.status == MembershipStatus.pendingPayment) &&
            !m.isExpired(now) &&
            m.assignedSeatId != null)
          m.assignedSeatId!.trim().toUpperCase(),
    };
    return slot.seatLabels
        .where((label) => !taken.contains(label.trim().toUpperCase()))
        .toList();
  }
}
