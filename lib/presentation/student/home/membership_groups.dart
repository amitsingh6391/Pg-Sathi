import '../../../domain/usecases/get_student_memberships.dart';

/// Memberships split for the home dashboard.
class MembershipGroups {
  const MembershipGroups({
    required this.all,
    required this.current,
    required this.past,
    required this.featured,
  });

  final List<StudentMembershipInfo> all;

  /// Non-expired memberships, most urgent first.
  final List<StudentMembershipInfo> current;

  /// Expired memberships other than [featured], newest first.
  final List<StudentMembershipInfo> past;

  /// Membership shown in the header band (null when there are none).
  final StudentMembershipInfo? featured;
}

/// Merges, orders and splits [memberships]. [selectedId] picks the featured
/// membership among the current ones, defaulting to the most urgent.
MembershipGroups groupMemberships(
  List<StudentMembershipInfo> memberships, {
  String? selectedId,
}) {
  final all = mergeMemberships(memberships);
  final current = orderByUrgency(all.where((i) => !i.isExpired).toList());
  final expired = all.where((i) => i.isExpired).toList()
    ..sort((a, b) => b.membership.endDate.compareTo(a.membership.endDate));

  final StudentMembershipInfo? featured = current.isNotEmpty
      ? current.where((i) => i.membership.id == selectedId).firstOrNull ??
            current.first
      : expired.firstOrNull;

  return MembershipGroups(
    all: all,
    current: current,
    past: expired.where((i) => i != featured).toList(),
    featured: featured,
  );
}

/// Most urgent first: pending payment, expiring, active, requested, expired.
List<StudentMembershipInfo> orderByUrgency(List<StudentMembershipInfo> infos) {
  int rank(StudentMembershipInfo i) {
    if (i.isPendingPayment) return 0;
    if (i.isActive && i.daysRemaining <= 7) return 1;
    if (i.isActive) return 2;
    if (i.isPendingApproval) return 3;
    if (i.isExpired) return 4;
    return 5;
  }

  return [...infos]..sort((a, b) => rank(a).compareTo(rank(b)));
}

/// Chip label: PG name, plus the slot when two chips would collide.
String membershipSwitcherLabel(
  StudentMembershipInfo info,
  List<StudentMembershipInfo> current,
) {
  final name = info.libraryName ?? 'PG';
  final duplicate = current.any(
    (i) => i != info && (i.libraryName ?? 'PG') == name,
  );
  return duplicate ? '$name · ${info.slotName}' : name;
}

/// Collapses memberships of the same library and slot into one entry,
/// keeping the active one and attaching the next as the upcoming plan.
List<StudentMembershipInfo> mergeMemberships(
  List<StudentMembershipInfo> memberships,
) {
  final merged = <String, StudentMembershipInfo>{};

  for (final info in memberships) {
    final slot = info.displaySlot;
    final slotKey = slot != null
        ? slot.name
        : (info.customSlot?.id ?? 'unknown');
    final key = '${info.membership.libraryId}_$slotKey';

    if (!merged.containsKey(key)) {
      merged[key] = info;
      continue;
    }

    final existing = merged[key]!;
    StudentMembershipInfo primary = existing;
    StudentMembershipInfo other = info;

    if (!existing.isActive && info.isActive) {
      primary = info;
      other = existing;
    } else if (existing.isActive && !info.isActive) {
      primary = existing;
      other = info;
    } else if (info.membership.startDate.isBefore(
      existing.membership.startDate,
    )) {
      primary = info;
      other = existing;
    }

    var upcoming = primary.upcomingMembership;
    if (upcoming == null) {
      if (other.membership.startDate.isAfter(primary.membership.startDate)) {
        upcoming = other.membership;
      } else if (other.upcomingMembership != null) {
        upcoming = other.upcomingMembership;
      }
    } else {
      final candidate =
          other.upcomingMembership ??
          (other.membership.startDate.isAfter(primary.membership.startDate)
              ? other.membership
              : null);
      if (candidate != null &&
          candidate.startDate.isBefore(upcoming.startDate)) {
        upcoming = candidate;
      }
    }

    merged[key] = StudentMembershipInfo(
      membership: primary.membership,
      library: primary.library,
      libraryName: primary.libraryName,
      customSlot: primary.customSlot,
      daysRemaining: primary.daysRemaining,
      isPendingPayment: primary.isPendingPayment,
      isActive: primary.isActive,
      isExpired: primary.isExpired,
      isPendingApproval: primary.isPendingApproval,
      upcomingMembership: upcoming,
    );
  }

  return merged.values.toList();
}
