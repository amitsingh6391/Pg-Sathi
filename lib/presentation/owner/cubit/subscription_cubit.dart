import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/analytics_service.dart';
import '../../../data/services/subscription_notification_service.dart';
import '../../../domain/entities/coupon.dart';
import '../../../domain/entities/referral.dart';
import '../../../domain/entities/subscription.dart';
import '../../../domain/usecases/auto_approve_razorpay_subscription.dart';
import '../../../domain/usecases/calculate_subscription_price.dart';
import '../../../domain/usecases/create_subscription.dart';
import '../../../domain/usecases/get_owner_subscription.dart';
import '../../../domain/usecases/mark_subscription_paid.dart';
import '../../../domain/usecases/referral/validate_referral_code.dart';
import '../../../domain/usecases/start_owner_trial.dart';
import '../../../domain/usecases/validate_coupon.dart';

/// State for subscription management.
class SubscriptionState extends Equatable {
  const SubscriptionState({
    this.status = SubscriptionStateStatus.initial,
    this.subscriptionStatus,
    this.priceResult,
    this.createdSubscription,
    this.validatedCoupon,
    this.errorMessage,
    this.selectedDuration = 1,
    this.couponCode,
    this.validatedReferral,
    this.referralCode,
  });

  final SubscriptionStateStatus status;
  final OwnerSubscriptionStatus? subscriptionStatus;
  final SubscriptionPriceResult? priceResult;
  final Subscription? createdSubscription;
  final Coupon? validatedCoupon;
  final String? errorMessage;
  final int selectedDuration;
  final String? couponCode;
  final Referral? validatedReferral;
  final String? referralCode;

  bool get isLoading => status == SubscriptionStateStatus.loading;
  bool get hasError => status == SubscriptionStateStatus.error;
  bool get isPriceCalculated =>
      status == SubscriptionStateStatus.priceCalculated;
  bool get isPaymentPending => status == SubscriptionStateStatus.paymentPending;
  bool get isSuccess => status == SubscriptionStateStatus.success;
  bool get isPendingVerification =>
      status == SubscriptionStateStatus.pendingVerification;

  static const double _referralDiscountPercent = 15.0;

  bool get hasReferralApplied => validatedReferral != null;

  /// Calculates final amount with coupon and/or referral discount applied.
  double get finalAmountWithCoupon {
    if (priceResult == null) return 0;
    var amount = priceResult!.finalAmount;

    if (validatedCoupon != null) {
      amount -= amount * (validatedCoupon!.discountPercent / 100);
    }

    if (validatedReferral != null) {
      amount -= amount * (_referralDiscountPercent / 100);
    }

    return amount;
  }

  SubscriptionState copyWith({
    SubscriptionStateStatus? status,
    OwnerSubscriptionStatus? subscriptionStatus,
    SubscriptionPriceResult? priceResult,
    Subscription? createdSubscription,
    Coupon? validatedCoupon,
    String? errorMessage,
    int? selectedDuration,
    String? couponCode,
    bool clearCoupon = false,
    Referral? validatedReferral,
    String? referralCode,
    bool clearReferral = false,
  }) {
    return SubscriptionState(
      status: status ?? this.status,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      priceResult: priceResult ?? this.priceResult,
      createdSubscription: createdSubscription ?? this.createdSubscription,
      validatedCoupon: clearCoupon
          ? null
          : (validatedCoupon ?? this.validatedCoupon),
      errorMessage: errorMessage,
      selectedDuration: selectedDuration ?? this.selectedDuration,
      couponCode: clearCoupon ? null : (couponCode ?? this.couponCode),
      validatedReferral: clearReferral
          ? null
          : (validatedReferral ?? this.validatedReferral),
      referralCode: clearReferral ? null : (referralCode ?? this.referralCode),
    );
  }

  @override
  List<Object?> get props => [
    status,
    subscriptionStatus,
    priceResult,
    createdSubscription,
    validatedCoupon,
    errorMessage,
    selectedDuration,
    couponCode,
    validatedReferral,
    referralCode,
  ];
}

/// Status for subscription state.
enum SubscriptionStateStatus {
  initial,
  loading,
  loaded,
  priceCalculated,
  paymentPending,
  pendingVerification,
  success,
  error,
}

/// Cubit for managing subscription state.
class SubscriptionCubit extends Cubit<SubscriptionState> {
  SubscriptionCubit({
    required this.getOwnerSubscription,
    required this.calculateSubscriptionPrice,
    required this.createSubscription,
    required this.markSubscriptionPaid,
    required this.autoApproveRazorpaySubscription,
    required this.startOwnerTrial,
    required this.validateCoupon,
    required this.validateReferralCode,
    required this.subscriptionNotificationService,
    required this.analyticsService,
  }) : super(const SubscriptionState());

  final GetOwnerSubscription getOwnerSubscription;
  final CalculateSubscriptionPrice calculateSubscriptionPrice;
  final CreateSubscription createSubscription;
  final MarkSubscriptionPaid markSubscriptionPaid;
  final AutoApproveRazorpaySubscription autoApproveRazorpaySubscription;
  final StartOwnerTrial startOwnerTrial;
  final ValidateCoupon validateCoupon;
  final ValidateReferralCode validateReferralCode;
  final SubscriptionNotificationService subscriptionNotificationService;
  final AnalyticsService analyticsService;

  /// Loads current subscription status for owner.
  /// [libraryCreatedAt] is the library creation date for trial calculation.
  /// Trial period starts from when the library was first created.
  Future<void> loadSubscriptionStatus(
    String ownerId, {
    DateTime? libraryCreatedAt,
  }) async {
    emit(state.copyWith(status: SubscriptionStateStatus.loading));

    final result = await getOwnerSubscription(
      GetOwnerSubscriptionParams(
        ownerId: ownerId,
        libraryCreatedAt: libraryCreatedAt,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: SubscriptionStateStatus.error,
          errorMessage: failure.message ?? 'Failed to load subscription',
        ),
      ),
      (subscriptionStatus) => emit(
        state.copyWith(
          status: SubscriptionStateStatus.loaded,
          subscriptionStatus: subscriptionStatus,
        ),
      ),
    );
  }

  /// Calculates price for given seat count and duration.
  /// Supports custom library pricing and admin discounts.
  Future<void> calculatePrice({
    required int seatCount,
    required int durationInMonths,
    double? customLibraryPrice,
    double? adminDiscountPercent,
  }) async {
    emit(
      state.copyWith(
        status: SubscriptionStateStatus.loading,
        selectedDuration: durationInMonths,
      ),
    );

    final result = await calculateSubscriptionPrice(
      CalculateSubscriptionPriceParams(
        seatCount: seatCount,
        durationInMonths: durationInMonths,
        customLibraryPrice: customLibraryPrice,
        adminDiscountPercent: adminDiscountPercent,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: SubscriptionStateStatus.error,
          errorMessage: failure.message ?? 'Failed to calculate price',
        ),
      ),
      (priceResult) => emit(
        state.copyWith(
          status: SubscriptionStateStatus.priceCalculated,
          priceResult: priceResult,
          selectedDuration: durationInMonths,
        ),
      ),
    );
  }

  /// Updates selected duration and recalculates price.
  void selectDuration(
    int durationInMonths,
    int seatCount, {
    double? customLibraryPrice,
    double? adminDiscountPercent,
  }) {
    calculatePrice(
      seatCount: seatCount,
      durationInMonths: durationInMonths,
      customLibraryPrice: customLibraryPrice,
      adminDiscountPercent: adminDiscountPercent,
    );
  }

  /// Validates and applies a coupon code.
  Future<void> applyCoupon(String couponCode) async {
    if (couponCode.trim().isEmpty) {
      emit(
        state.copyWith(
          status: SubscriptionStateStatus.error,
          errorMessage: 'Please enter a coupon code',
        ),
      );
      return;
    }

    emit(state.copyWith(status: SubscriptionStateStatus.loading));

    final result = await validateCoupon(
      ValidateCouponParams(couponCode: couponCode),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: SubscriptionStateStatus.priceCalculated,
          errorMessage: failure.message ?? 'Invalid coupon code',
          clearCoupon: true,
        ),
      ),
      (coupon) => emit(
        state.copyWith(
          status: SubscriptionStateStatus.priceCalculated,
          validatedCoupon: coupon,
          couponCode: couponCode,
        ),
      ),
    );
  }

  /// Removes applied coupon.
  void removeCoupon() {
    emit(
      state.copyWith(
        status: SubscriptionStateStatus.priceCalculated,
        clearCoupon: true,
      ),
    );
  }

  /// Validates and applies a referral code (15% discount for first-time).
  Future<void> applyReferral(String code, String currentOwnerId) async {
    if (code.trim().isEmpty) {
      emit(
        state.copyWith(
          status: SubscriptionStateStatus.error,
          errorMessage: 'Please enter a referral code',
        ),
      );
      return;
    }

    emit(state.copyWith(status: SubscriptionStateStatus.loading));

    final result = await validateReferralCode(
      ValidateReferralCodeParams(code: code, refereeOwnerId: currentOwnerId),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: SubscriptionStateStatus.priceCalculated,
          errorMessage: failure.message ?? 'Invalid referral code',
          clearReferral: true,
        ),
      ),
      (referral) => emit(
        state.copyWith(
          status: SubscriptionStateStatus.priceCalculated,
          validatedReferral: referral,
          referralCode: code.trim().toUpperCase(),
        ),
      ),
    );
  }

  /// Removes applied referral code.
  void removeReferral() {
    emit(
      state.copyWith(
        status: SubscriptionStateStatus.priceCalculated,
        clearReferral: true,
      ),
    );
  }

  /// Creates a subscription and moves to payment pending.
  /// [couponCode] overrides state.couponCode when provided (e.g. when a new
  /// cubit instance is created for the payment screen).
  Future<void> initiatePayment({
    required String ownerId,
    required String libraryId,
    required int seatCount,
    required int durationInMonths,
    double? customLibraryPrice,
    double? adminDiscountPercent,
    String? couponCode,
    String? referralCode,
    String? planIdOverride,
    double? baseMonthlyPriceOverride,
    double? finalAmountOverride,
    double? discountPercentOverride,
    int? seatLimitOverride,
  }) async {
    emit(state.copyWith(status: SubscriptionStateStatus.loading));

    final result = await createSubscription(
      CreateSubscriptionParams(
        ownerId: ownerId,
        libraryId: libraryId,
        seatCount: seatCount,
        durationInMonths: durationInMonths,
        couponCode: couponCode ?? state.couponCode,
        customLibraryPrice: customLibraryPrice,
        adminDiscountPercent: adminDiscountPercent,
        referralCode: referralCode ?? state.referralCode,
        planIdOverride: planIdOverride,
        baseMonthlyPriceOverride: baseMonthlyPriceOverride,
        finalAmountOverride: finalAmountOverride,
        discountPercentOverride: discountPercentOverride,
        seatLimitOverride: seatLimitOverride,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: SubscriptionStateStatus.error,
          errorMessage: failure.message ?? 'Failed to create subscription',
        ),
      ),
      (subscription) => emit(
        state.copyWith(
          status: SubscriptionStateStatus.paymentPending,
          createdSubscription: subscription,
        ),
      ),
    );
  }

  /// Marks subscription payment as done with transaction details.
  /// Also sends notification to admin for verification.
  Future<void> markPaymentAsDone({
    required String subscriptionId,
    required String transactionId,
    String? paymentProofUrl,
    String? ownerName,
    String? libraryName,
  }) async {
    emit(state.copyWith(status: SubscriptionStateStatus.loading));

    final result = await markSubscriptionPaid(
      MarkSubscriptionPaidParams(
        subscriptionId: subscriptionId,
        transactionId: transactionId,
        paymentProofUrl: paymentProofUrl,
      ),
    );

    result.fold(
      (failure) {
        emit(
          state.copyWith(
            status: SubscriptionStateStatus.error,
            errorMessage: failure.message ?? 'Failed to update payment',
          ),
        );
      },
      (subscription) async {
        // Send notification to admin
        await subscriptionNotificationService.notifyAdminPaymentSubmitted(
          ownerName: ownerName ?? 'Owner',
          libraryName: libraryName ?? 'Library',
          amount: subscription.finalAmount,
          subscriptionId: subscription.id,
        );

        emit(
          state.copyWith(
            status: SubscriptionStateStatus.pendingVerification,
            createdSubscription: subscription,
          ),
        );
      },
    );
  }

  /// Auto-approves Razorpay payment and activates subscription immediately.
  /// Razorpay payments are instant and verified, so no manual approval needed.
  /// Sends notification to admin about successful payment.
  Future<void> approveRazorpayPayment({
    required String subscriptionId,
    required String razorpayPaymentId,
    required String ownerName,
    required String libraryName,
    required double amount,
    required int durationMonths,
  }) async {
    emit(state.copyWith(status: SubscriptionStateStatus.loading));

    final result = await autoApproveRazorpaySubscription(
      AutoApproveRazorpaySubscriptionParams(
        subscriptionId: subscriptionId,
        razorpayPaymentId: razorpayPaymentId,
      ),
    );

    await result.fold(
      (failure) {
        emit(
          state.copyWith(
            status: SubscriptionStateStatus.error,
            errorMessage: failure.message ?? 'Failed to activate subscription',
          ),
        );
      },
      (subscription) async {
        // Notify admin about successful Razorpay payment
        await subscriptionNotificationService.notifyAdminRazorpayPayment(
          ownerName: ownerName,
          libraryName: libraryName,
          amount: amount,
          durationMonths: durationMonths,
          razorpayPaymentId: razorpayPaymentId,
        );

        // Notify owner that subscription is now active
        await subscriptionNotificationService.notifyOwnerPaymentApproved(
          ownerId: subscription.ownerId,
          planName: subscriptionNotificationService.getPlanName(subscription),
          durationMonths: subscription.durationInMonths,
          validUntil: subscription.endDate,
        );

        // Track subscription purchased
        await analyticsService.trackSubscriptionPurchased(
          subscriptionPlan: '${subscription.seatCount} seats',
          amount: subscription.finalAmount,
          duration: '${subscription.durationInMonths} months',
        );

        emit(
          state.copyWith(
            status: SubscriptionStateStatus.success,
            createdSubscription: subscription,
          ),
        );
      },
    );
  }

  /// Auto-approves an Apple In-App Purchase subscription.
  Future<void> approveInAppPurchasePayment({
    required String subscriptionId,
    required String transactionId,
    required double amount,
    required int durationMonths,
  }) async {
    emit(state.copyWith(status: SubscriptionStateStatus.loading));

    final result = await autoApproveRazorpaySubscription(
      AutoApproveRazorpaySubscriptionParams(
        subscriptionId: subscriptionId,
        razorpayPaymentId: transactionId,
      ),
    );

    await result.fold(
      (failure) {
        emit(
          state.copyWith(
            status: SubscriptionStateStatus.error,
            errorMessage: failure.message ?? 'Failed to activate subscription',
          ),
        );
      },
      (subscription) async {
        await subscriptionNotificationService.notifyOwnerPaymentApproved(
          ownerId: subscription.ownerId,
          planName: subscriptionNotificationService.getPlanName(subscription),
          durationMonths: subscription.durationInMonths,
          validUntil: subscription.endDate,
        );

        await analyticsService.trackSubscriptionPurchased(
          subscriptionPlan: 'app_store_${subscription.durationInMonths}_months',
          amount: amount,
          duration: '$durationMonths months',
        );

        emit(
          state.copyWith(
            status: SubscriptionStateStatus.success,
            createdSubscription: subscription,
          ),
        );
      },
    );
  }

  /// Starts trial for new owner.
  Future<void> startTrial(String ownerId) async {
    emit(state.copyWith(status: SubscriptionStateStatus.loading));

    final result = await startOwnerTrial(
      StartOwnerTrialParams(ownerId: ownerId),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: SubscriptionStateStatus.error,
          errorMessage: failure.message ?? 'Failed to start trial',
        ),
      ),
      (_) async {
        // Reload subscription status after starting trial
        await loadSubscriptionStatus(ownerId);
      },
    );
  }

  /// Resets to initial state.
  void reset() {
    emit(const SubscriptionState());
  }
}
