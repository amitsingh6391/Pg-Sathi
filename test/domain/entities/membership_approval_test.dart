import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/membership.dart';

void main() {
  final request = Membership(
    id: 'm1',
    libraryId: 'pg1',
    plan: MembershipPlan.monthly,
    startDate: DateTime(2026, 1, 1),
    endDate: DateTime(2026, 1, 31),
    status: MembershipStatus.pendingApproval,
    phoneNumber: '+911234567890',
    assignedSeatId: 'B1',
  );

  test('pendingApproval request is flagged and editable', () {
    expect(request.isPendingApproval, isTrue);
    expect(request.isEditable, isTrue);
    expect(request.isPendingPayment, isFalse);
  });

  test('approve() activates the membership and keeps the bed', () {
    final approved = request.approve();
    expect(approved.status, MembershipStatus.active);
    expect(approved.isPendingApproval, isFalse);
    expect(approved.assignedSeatId, 'B1');
  });

  test('a pending request does not count as occupied', () {
    expect(request.shouldCountAsOccupied(DateTime(2026, 1, 10)), isFalse);
  });
}
