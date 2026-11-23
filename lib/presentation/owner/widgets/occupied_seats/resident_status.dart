import 'package:material_ui/material_ui.dart';

import '../../../core/app_ui_constants.dart';
import '../../../../domain/usecases/get_occupied_seats.dart';

/// Visual status of a bed/resident, shared by bed map, cards and profile sheet.
enum ResidentStatus { occupied, reserved, due, expiring, expired }

extension ResidentStatusX on ResidentStatus {
  String get label => switch (this) {
    ResidentStatus.occupied => 'Paid',
    ResidentStatus.reserved => 'Reserved',
    ResidentStatus.due => 'Rent due',
    ResidentStatus.expiring => 'Expiring',
    ResidentStatus.expired => 'Expired',
  };

  Color get color => switch (this) {
    ResidentStatus.occupied => AppUIConstants.primaryLight,
    ResidentStatus.reserved => AppUIConstants.secondary,
    ResidentStatus.due => AppUIConstants.warning,
    ResidentStatus.expiring => AppUIConstants.warning,
    ResidentStatus.expired => AppUIConstants.error,
  };
}

/// Derives the display status of a stay from existing entity getters.
ResidentStatus residentStatusOf(OccupiedSeatInfo seat) {
  if (seat.isReserved) return ResidentStatus.reserved;
  if (seat.isExpired) return ResidentStatus.expired;
  if (seat.membership.hasPartialPayment ||
      seat.hasFuturePendingPlanNeedingPayment) {
    return ResidentStatus.due;
  }
  if (seat.isExpiringSoon) return ResidentStatus.expiring;
  return ResidentStatus.occupied;
}

/// Initials (max 2) for avatar fallbacks.
String residentInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .take(2)
      .map((p) => p[0])
      .join()
      .toUpperCase();
  return parts.isEmpty ? '?' : parts;
}

/// Circular/rounded avatar with photo or initials on a status-tinted fill.
class ResidentAvatar extends StatelessWidget {
  const ResidentAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.color = AppUIConstants.primaryLight,
    this.size = 48,
  });

  final String name;
  final String? avatarUrl;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1.5),
        image: avatarUrl != null
            ? DecorationImage(
                image: NetworkImage(avatarUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: avatarUrl == null
          ? Text(
              residentInitials(name),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.34,
              ),
            )
          : null,
    );
  }
}
