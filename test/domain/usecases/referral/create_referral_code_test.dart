import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/referral.dart';
import 'package:pg_manager/domain/entities/subscription.dart';
import 'package:pg_manager/domain/failures/referral_failures.dart';
import 'package:pg_manager/domain/repositories/referral_repository.dart';
import 'package:pg_manager/domain/repositories/subscription_repository.dart';
import 'package:pg_manager/domain/usecases/referral/create_referral_code.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([ReferralRepository, SubscriptionRepository])
import 'create_referral_code_test.mocks.dart';

void main() {
  late CreateReferralCode useCase;
  late MockReferralRepository mockReferralRepo;
  late MockSubscriptionRepository mockSubscriptionRepo;

  setUp(() {
    mockReferralRepo = MockReferralRepository();
    mockSubscriptionRepo = MockSubscriptionRepository();
    useCase = CreateReferralCode(
      referralRepository: mockReferralRepo,
      subscriptionRepository: mockSubscriptionRepo,
    );
  });

  final activeSubscription = Subscription(
    id: 'sub_1',
    ownerId: 'owner_1',
    libraryId: 'lib_1',
    seatCount: 50,
    planId: 'tier_249',
    baseMonthlyPrice: 249,
    durationInMonths: 1,
    discountPercent: 0,
    finalAmount: 249,
    startDate: DateTime.now().subtract(const Duration(days: 10)),
    endDate: DateTime.now().add(const Duration(days: 20)),
    status: SubscriptionStatus.active,
  );

  test('should_fail_when_owner_has_no_active_subscription', () async {
    when(mockSubscriptionRepo.getActiveSubscription('owner_1'))
        .thenAnswer((_) async => const Right(null));

    final result = await useCase(
      const CreateReferralCodeParams(ownerId: 'owner_1'),
    );

    expect(result.isLeft(), isTrue);
    result.fold(
      (f) => expect(f, isA<NoActiveSubscriptionForReferralFailure>()),
      (_) => fail('Expected failure'),
    );
  });

  test('should_return_existing_referral_when_already_exists', () async {
    when(mockSubscriptionRepo.getActiveSubscription('owner_1'))
        .thenAnswer((_) async => Right(activeSubscription));

    const existingReferral = Referral(
      id: 'owner_1_referral',
      ownerId: 'owner_1',
      code: 'LT-OWN-ABCD',
      isActive: true,
    );

    when(mockReferralRepo.getReferralByOwnerId('owner_1'))
        .thenAnswer((_) async => const Right(existingReferral));

    final result = await useCase(
      const CreateReferralCodeParams(ownerId: 'owner_1'),
    );

    expect(result.isRight(), isTrue);
    result.fold(
      (_) => fail('Expected success'),
      (r) => expect(r.code, 'LT-OWN-ABCD'),
    );
    verifyNever(mockReferralRepo.createReferral(any));
  });

  test('should_create_referral_code_when_owner_has_active_subscription',
      () async {
    when(mockSubscriptionRepo.getActiveSubscription('owner_1'))
        .thenAnswer((_) async => Right(activeSubscription));

    when(mockReferralRepo.getReferralByOwnerId('owner_1'))
        .thenAnswer((_) async => const Right(null));

    when(mockReferralRepo.createReferral(any)).thenAnswer(
      (inv) async => Right(inv.positionalArguments[0] as Referral),
    );

    final result = await useCase(
      const CreateReferralCodeParams(
        ownerId: 'owner_1',
        ownerName: 'Amit',
      ),
    );

    expect(result.isRight(), isTrue);
    result.fold(
      (_) => fail('Expected success'),
      (r) {
        expect(r.code, startsWith('LT-AMI-'));
        expect(r.ownerId, 'owner_1');
        expect(r.isActive, isTrue);
      },
    );
    verify(mockReferralRepo.createReferral(any)).called(1);
  });
}
