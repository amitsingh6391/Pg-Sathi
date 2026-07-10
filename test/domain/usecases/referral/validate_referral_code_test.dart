import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/referral.dart';
import 'package:pg_manager/domain/entities/subscription.dart';
import 'package:pg_manager/domain/failures/referral_failures.dart';
import 'package:pg_manager/domain/repositories/referral_repository.dart';
import 'package:pg_manager/domain/repositories/subscription_repository.dart';
import 'package:pg_manager/domain/usecases/referral/validate_referral_code.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([ReferralRepository, SubscriptionRepository])
import 'validate_referral_code_test.mocks.dart';

void main() {
  late ValidateReferralCode useCase;
  late MockReferralRepository mockReferralRepo;
  late MockSubscriptionRepository mockSubscriptionRepo;

  setUp(() {
    mockReferralRepo = MockReferralRepository();
    mockSubscriptionRepo = MockSubscriptionRepository();
    useCase = ValidateReferralCode(
      referralRepository: mockReferralRepo,
      subscriptionRepository: mockSubscriptionRepo,
    );
  });

  const referral = Referral(
    id: 'ref_1',
    ownerId: 'referrer_owner',
    code: 'LT-ABC-1234',
    isActive: true,
  );

  final activeSubscription = Subscription(
    id: 'sub_1',
    ownerId: 'referrer_owner',
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

  test('should_fail_when_code_is_empty', () async {
    final result = await useCase(
      const ValidateReferralCodeParams(
        code: '',
        refereeOwnerId: 'referee_owner',
      ),
    );

    expect(result.isLeft(), isTrue);
    result.fold(
      (f) => expect(f, isA<InvalidReferralCodeFailure>()),
      (_) => fail('Expected failure'),
    );
  });

  test('should_fail_when_code_not_found', () async {
    when(mockReferralRepo.getReferralByCode('LT-XXX-0000'))
        .thenAnswer((_) async => const Right(null));

    final result = await useCase(
      const ValidateReferralCodeParams(
        code: 'LT-XXX-0000',
        refereeOwnerId: 'referee_owner',
      ),
    );

    expect(result.isLeft(), isTrue);
    result.fold(
      (f) => expect(f, isA<ReferralCodeNotFoundFailure>()),
      (_) => fail('Expected failure'),
    );
  });

  test('should_fail_when_self_referral', () async {
    when(mockReferralRepo.getReferralByCode('LT-ABC-1234'))
        .thenAnswer((_) async => const Right(referral));

    final result = await useCase(
      const ValidateReferralCodeParams(
        code: 'LT-ABC-1234',
        refereeOwnerId: 'referrer_owner',
      ),
    );

    expect(result.isLeft(), isTrue);
    result.fold(
      (f) => expect(f, isA<SelfReferralNotAllowedFailure>()),
      (_) => fail('Expected failure'),
    );
  });

  test('should_fail_when_referee_already_used_a_referral', () async {
    when(mockReferralRepo.getReferralByCode('LT-ABC-1234'))
        .thenAnswer((_) async => const Right(referral));

    final existingRedemption = ReferralRedemption(
      id: 'red_1',
      referralCode: 'LT-OTHER-CODE',
      referrerId: 'other_owner',
      refereeId: 'referee_owner',
      status: ReferralRedemptionStatus.converted,
    );

    when(mockReferralRepo.getRedemptionByReferee('referee_owner'))
        .thenAnswer((_) async => Right(existingRedemption));

    final result = await useCase(
      const ValidateReferralCodeParams(
        code: 'LT-ABC-1234',
        refereeOwnerId: 'referee_owner',
      ),
    );

    expect(result.isLeft(), isTrue);
    result.fold(
      (f) => expect(f, isA<ReferralAlreadyAppliedFailure>()),
      (_) => fail('Expected failure'),
    );
  });

  test('should_fail_when_referrer_has_no_active_subscription', () async {
    when(mockReferralRepo.getReferralByCode('LT-ABC-1234'))
        .thenAnswer((_) async => const Right(referral));

    when(mockReferralRepo.getRedemptionByReferee('referee_owner'))
        .thenAnswer((_) async => const Right(null));

    when(mockSubscriptionRepo.getActiveSubscription('referrer_owner'))
        .thenAnswer((_) async => const Right(null));

    final result = await useCase(
      const ValidateReferralCodeParams(
        code: 'LT-ABC-1234',
        refereeOwnerId: 'referee_owner',
      ),
    );

    expect(result.isLeft(), isTrue);
    result.fold(
      (f) => expect(f, isA<ReferrerNoActiveSubscriptionFailure>()),
      (_) => fail('Expected failure'),
    );
  });

  test('should_succeed_when_all_conditions_met', () async {
    when(mockReferralRepo.getReferralByCode('LT-ABC-1234'))
        .thenAnswer((_) async => const Right(referral));

    when(mockReferralRepo.getRedemptionByReferee('referee_owner'))
        .thenAnswer((_) async => const Right(null));

    when(mockSubscriptionRepo.getActiveSubscription('referrer_owner'))
        .thenAnswer((_) async => Right(activeSubscription));

    final result = await useCase(
      const ValidateReferralCodeParams(
        code: 'LT-ABC-1234',
        refereeOwnerId: 'referee_owner',
      ),
    );

    expect(result.isRight(), isTrue);
    result.fold(
      (_) => fail('Expected success'),
      (r) => expect(r.code, 'LT-ABC-1234'),
    );
  });
}
