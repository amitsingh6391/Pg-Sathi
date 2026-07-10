import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/custom_slot.dart';
import 'package:pg_manager/domain/entities/library.dart';
import 'package:pg_manager/domain/entities/membership.dart';
import 'package:pg_manager/domain/entities/payment.dart';
import 'package:pg_manager/domain/entities/payment_breakdown.dart';
import 'package:pg_manager/domain/entities/user.dart';
import 'package:pg_manager/domain/failures/membership_failures.dart';
import 'package:pg_manager/domain/failures/seat_failures.dart';
import 'package:pg_manager/domain/repositories/library_repository.dart';
import 'package:pg_manager/domain/repositories/membership_repository.dart';
import 'package:pg_manager/domain/repositories/payment_repository.dart';
import 'package:pg_manager/domain/repositories/seat_repository.dart';
import 'package:pg_manager/domain/repositories/slot_repository.dart';
import 'package:pg_manager/domain/repositories/user_repository.dart';
import 'package:pg_manager/domain/usecases/assign_membership_with_custom_slot.dart';
import 'package:mocktail/mocktail.dart';

class MockMembershipRepository extends Mock implements MembershipRepository {}

class MockSlotRepository extends Mock implements SlotRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockLibraryRepository extends Mock implements LibraryRepository {}

class MockPaymentRepository extends Mock implements PaymentRepository {}

class MockSeatRepository extends Mock implements SeatRepository {}

void main() {
  late AssignMembershipWithCustomSlot useCase;
  late MockMembershipRepository mockMembershipRepository;
  late MockSlotRepository mockSlotRepository;
  late MockUserRepository mockUserRepository;
  late MockLibraryRepository mockLibraryRepository;
  late MockPaymentRepository mockPaymentRepository;
  late MockSeatRepository mockSeatRepository;

  setUpAll(() {
    registerFallbackValue(
      const CustomSlot(
        capacity: 0,
        id: '',
        libraryId: '',
        name: '',
        startTime: 0,
        endTime: 0,
        price: 0,
      ),
    );
    registerFallbackValue(
      Membership(
        id: '',
        libraryId: '',
        plan: MembershipPlan.monthly,
        startDate: DateTime.now(),
        endDate: DateTime.now(),
        status: MembershipStatus.active,
        phoneNumber: '',
      ),
    );
    registerFallbackValue(
      Payment.createCashPayment(
        id: '',
        membershipId: '',
        userId: '',
        libraryId: '',
        amount: 0,
      ),
    );
  });

  setUp(() {
    mockMembershipRepository = MockMembershipRepository();
    mockSlotRepository = MockSlotRepository();
    mockUserRepository = MockUserRepository();
    mockLibraryRepository = MockLibraryRepository();
    mockPaymentRepository = MockPaymentRepository();
    mockSeatRepository = MockSeatRepository();
    useCase = AssignMembershipWithCustomSlot(
      membershipRepository: mockMembershipRepository,
      slotRepository: mockSlotRepository,
      userRepository: mockUserRepository,
      libraryRepository: mockLibraryRepository,
      paymentRepository: mockPaymentRepository,
      seatRepository: mockSeatRepository,
      // Invoice generation is optional, set to null for tests
      generateInvoice: null,
    );
  });

  final testCustomSlot = CustomSlot(
    id: 'slot-1',
    libraryId: 'lib-1',
    name: 'Morning Slot',
    startTime: 360, // 6:00 AM
    endTime: 840, // 2:00 PM
    price: 500.0,
    capacity: 20,
    isActive: true,
  );

  final testUser = User(
    id: 'user-1',
    name: 'Test User',
    phone: '+919876543210',
    role: UserRole.student,
    isProfileComplete: true,
  );

  const testLibrary = Library(
    id: 'lib-1',
    ownerId: 'owner-1',
    name: 'Test Library',
    capacity: 50,
  );

  group('AssignMembershipWithCustomSlot', () {
    test('should create membership with custom slot successfully', () async {
      // Arrange
      final params = AssignMembershipWithCustomSlotParams(
        membershipId: 'mem-1',
        libraryId: 'lib-1',
        studentPhone: '+919876543210',
        seatId: 'S01',
        slotId: 'slot-1',
        expiryDate: DateTime.now().add(const Duration(days: 30)),
        plan: MembershipPlan.monthly,
      );

      when(
        () => mockSlotRepository.getSlotById('lib-1', 'slot-1'),
      ).thenAnswer((_) async => Right(testCustomSlot));
      when(
        () => mockUserRepository.getUserByPhone('+919876543210'),
      ).thenAnswer((_) async => Right(testUser));
      when(
        () => mockMembershipRepository.getMembershipsByPhoneNumber(
          '+919876543210',
        ),
      ).thenAnswer((_) async => const Right([]));
      when(
        () => mockMembershipRepository
            .getActiveAndReservedMembershipsForLibrary('lib-1'),
      ).thenAnswer((_) async => const Right([]));
      when(
        () => mockMembershipRepository.getMembershipsByLibraryId('lib-1'),
      ).thenAnswer((_) async => const Right([]));
      when(() => mockMembershipRepository.createMembership(any())).thenAnswer((
        invocation,
      ) async {
        final membership = invocation.positionalArguments[0] as Membership;
        return Right(membership);
      });

      // Act
      final result = await useCase(params);

      // Assert
      expect(result.isRight(), true);
      verify(() => mockSlotRepository.getSlotById('lib-1', 'slot-1')).called(1);
      verify(() => mockMembershipRepository.createMembership(any())).called(1);
    });

    test('should create membership with partial payment', () async {
      // Arrange
      final paymentBreakdown = PaymentBreakdown(
        amountPaid: 200.0,
        amountRemaining: 300.0,
        notes: 'Partial payment received',
      );

      final params = AssignMembershipWithCustomSlotParams(
        membershipId: 'mem-1',
        libraryId: 'lib-1',
        studentPhone: '+919876543210',
        seatId: 'S01',
        slotId: 'slot-1',
        expiryDate: DateTime.now().add(const Duration(days: 30)),
        plan: MembershipPlan.monthly,
        paymentBreakdown: paymentBreakdown,
      );

      when(
        () => mockSlotRepository.getSlotById('lib-1', 'slot-1'),
      ).thenAnswer((_) async => Right(testCustomSlot));
      when(
        () => mockUserRepository.getUserByPhone('+919876543210'),
      ).thenAnswer((_) async => Right(testUser));
      when(
        () => mockMembershipRepository.getMembershipsByPhoneNumber(
          '+919876543210',
        ),
      ).thenAnswer((_) async => const Right([]));
      when(
        () => mockMembershipRepository
            .getActiveAndReservedMembershipsForLibrary('lib-1'),
      ).thenAnswer((_) async => const Right([]));
      when(
        () => mockMembershipRepository.getMembershipsByLibraryId('lib-1'),
      ).thenAnswer((_) async => const Right([]));
      when(() => mockMembershipRepository.createMembership(any())).thenAnswer((
        invocation,
      ) async {
        final membership = invocation.positionalArguments[0] as Membership;
        expect(membership.paymentBreakdown, isNotNull);
        expect(membership.paymentBreakdown!.amountPaid, 200.0);
        expect(membership.paymentBreakdown!.amountRemaining, 300.0);
        expect(membership.paymentBreakdown!.notes, 'Partial payment received');
        return Right(membership);
      });
      // Mock library repository for payment record creation (partial payment)
      when(
        () => mockLibraryRepository.getLibraryById('lib-1'),
      ).thenAnswer((_) async => const Right(testLibrary));
      // Mock payment repository for payment record creation
      when(() => mockPaymentRepository.createPayment(any())).thenAnswer((
        invocation,
      ) async {
        final payment = invocation.positionalArguments[0] as Payment;
        return Right(payment);
      });

      // Act
      final result = await useCase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold((failure) => fail('Should not return failure'), (membership) {
        expect(membership.paymentBreakdown, isNotNull);
        expect(membership.paymentBreakdown!.isPartial, true);
      });
    });

    test('should return failure when custom slot not found', () async {
      // Arrange
      final params = AssignMembershipWithCustomSlotParams(
        membershipId: 'mem-1',
        libraryId: 'lib-1',
        studentPhone: '+919876543210',
        seatId: 'S01',
        slotId: 'slot-1',
        expiryDate: DateTime.now().add(const Duration(days: 30)),
        plan: MembershipPlan.monthly,
      );

      when(
        () => mockSlotRepository.getSlotById('lib-1', 'slot-1'),
      ).thenAnswer((_) async => const Right(null));

      // Act
      final result = await useCase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold((failure) {
        expect(failure, isA<InvalidMembershipDataFailure>());
      }, (_) => fail('Should return failure'));
    });

    test('should return failure when custom slot is inactive', () async {
      // Arrange
      final inactiveSlot = testCustomSlot.copyWith(isActive: false);
      final params = AssignMembershipWithCustomSlotParams(
        membershipId: 'mem-1',
        libraryId: 'lib-1',
        studentPhone: '+919876543210',
        seatId: 'S01',
        slotId: 'slot-1',
        expiryDate: DateTime.now().add(const Duration(days: 30)),
        plan: MembershipPlan.monthly,
      );

      when(
        () => mockSlotRepository.getSlotById('lib-1', 'slot-1'),
      ).thenAnswer((_) async => Right(inactiveSlot));

      // Act
      final result = await useCase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold((failure) {
        expect(failure, isA<InvalidMembershipDataFailure>());
      }, (_) => fail('Should return failure'));
    });

    test('should return failure when seat+slot is already occupied', () async {
      // Arrange
      final params = AssignMembershipWithCustomSlotParams(
        membershipId: 'mem-1',
        libraryId: 'lib-1',
        studentPhone: '+919876543210',
        seatId: 'S01',
        slotId: 'slot-1',
        expiryDate: DateTime.now().add(const Duration(days: 30)),
        plan: MembershipPlan.monthly,
      );

      final existingMembership = Membership(
        id: 'mem-existing',
        userId: 'user-2',
        libraryId: 'lib-1',
        plan: MembershipPlan.monthly,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
        status: MembershipStatus.active,
        phoneNumber: '+919876543211',
        assignedSeatId: 'S01',
        slotId: 'slot-1',
      );

      when(
        () => mockSlotRepository.getSlotById('lib-1', 'slot-1'),
      ).thenAnswer((_) async => Right(testCustomSlot));
      when(
        () => mockUserRepository.getUserByPhone('+919876543210'),
      ).thenAnswer((_) async => Right(testUser));
      when(
        () => mockMembershipRepository.getMembershipsByPhoneNumber(
          '+919876543210',
        ),
      ).thenAnswer((_) async => const Right([]));
      when(
        () => mockMembershipRepository
            .getActiveAndReservedMembershipsForLibrary('lib-1'),
      ).thenAnswer((_) async => Right([existingMembership]));
      when(
        () => mockMembershipRepository.getMembershipsByLibraryId('lib-1'),
      ).thenAnswer((_) async => Right([existingMembership]));

      // Act
      final result = await useCase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold((failure) {
        expect(failure, isA<SeatAlreadyOccupiedFailure>());
      }, (_) => fail('Should return failure'));
    });

    test('should validate payment breakdown amounts', () async {
      // Arrange
      final invalidPaymentBreakdown = PaymentBreakdown(
        amountPaid: -100.0, // Invalid: negative
        amountRemaining: 200.0,
      );

      final params = AssignMembershipWithCustomSlotParams(
        membershipId: 'mem-1',
        libraryId: 'lib-1',
        studentPhone: '+919876543210',
        seatId: 'S01',
        slotId: 'slot-1',
        expiryDate: DateTime.now().add(const Duration(days: 30)),
        plan: MembershipPlan.monthly,
        paymentBreakdown: invalidPaymentBreakdown,
      );

      // Act
      final result = await useCase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold((failure) {
        expect(failure, isA<InvalidMembershipDataFailure>());
      }, (_) => fail('Should return failure'));
    });
  });
}
