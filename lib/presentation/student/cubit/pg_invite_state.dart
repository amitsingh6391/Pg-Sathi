import 'package:equatable/equatable.dart';

import '../../../domain/entities/custom_slot.dart';
import '../../../domain/entities/library.dart';
import '../../../domain/entities/membership.dart';
import '../../../domain/entities/user.dart';

/// Outcome of resolving a PG invite link (QR scan).
enum PgInviteStatus { loading, ready, needsLogin, notFound, error }

class PgInviteState extends Equatable {
  const PgInviteState({
    this.status = PgInviteStatus.loading,
    this.library,
    this.user,
    this.slots = const [],
    this.freeBedsBySlot = const {},
    this.occupied,
    this.pendingRequest,
  });

  final PgInviteStatus status;
  final Library? library;
  final User? user;
  final List<CustomSlot> slots;

  /// Free bed count per slot id.
  final Map<String, int> freeBedsBySlot;

  /// Active and reserved stays at this PG, reused by the bed request screen.
  /// Null when rooms or beds failed to load, so that screen fetches again.
  final List<Membership>? occupied;

  /// This resident's open request at this PG, if any.
  final Membership? pendingRequest;

  int get totalFreeBeds => freeBedsBySlot.values.fold(0, (a, b) => a + b);

  /// Owners cannot request a bed in a PG.
  bool get isOwner => user?.role == UserRole.owner;

  @override
  List<Object?> get props => [
    status,
    library,
    user,
    slots,
    freeBedsBySlot,
    occupied,
    pendingRequest,
  ];
}
