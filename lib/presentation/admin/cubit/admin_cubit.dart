import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/coupon.dart';
import '../../../domain/entities/subscription.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/usecases/approve_subscription.dart';
import '../../../domain/usecases/create_coupon.dart';
import '../../../domain/usecases/delete_subscription.dart';
import '../../../domain/usecases/get_all_coupons.dart';
import '../../../domain/usecases/get_all_subscriptions.dart';
import '../../../domain/usecases/get_pending_subscriptions.dart';
import '../../../domain/usecases/reject_subscription.dart';
import '../../../domain/core/usecase.dart';
import '../../../data/services/subscription_notification_service.dart';

/// State for admin dashboard.
class AdminState extends Equatable {
  const AdminState({
    this.status = AdminStateStatus.initial,
    this.currentUser,
    this.pendingSubscriptions = const [],
    this.allSubscriptions = const [],
    this.coupons = const [],
    this.errorMessage,
  });

  final AdminStateStatus status;
  final User? currentUser;
  final List<Subscription> pendingSubscriptions;
  final List<Subscription> allSubscriptions;
  final List<Coupon> coupons;
  final String? errorMessage;

  bool get isLoading => status == AdminStateStatus.loading;
  bool get hasError => status == AdminStateStatus.error;
  bool get isAuthenticated =>
      currentUser != null && currentUser!.role == UserRole.admin;

  AdminState copyWith({
    AdminStateStatus? status,
    User? currentUser,
    List<Subscription>? pendingSubscriptions,
    List<Subscription>? allSubscriptions,
    List<Coupon>? coupons,
    String? errorMessage,
    bool clearUser = false,
  }) {
    return AdminState(
      status: status ?? this.status,
      currentUser: clearUser ? null : (currentUser ?? this.currentUser),
      pendingSubscriptions: pendingSubscriptions ?? this.pendingSubscriptions,
      allSubscriptions: allSubscriptions ?? this.allSubscriptions,
      coupons: coupons ?? this.coupons,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    currentUser,
    pendingSubscriptions,
    allSubscriptions,
    coupons,
    errorMessage,
  ];
}

/// Status for admin state.
enum AdminStateStatus { initial, loading, authenticated, loaded, error }

/// Cubit for admin operations.
class AdminCubit extends Cubit<AdminState> {
  AdminCubit({
    required this.getPendingSubscriptionsUseCase,
    required this.getAllSubscriptionsUseCase,
    required this.approveSubscriptionUseCase,
    required this.rejectSubscriptionUseCase,
    required this.deleteSubscriptionUseCase,
    required this.getAllCouponsUseCase,
    required this.createCouponUseCase,
    required this.subscriptionNotificationService,
  }) : super(const AdminState());

  final GetPendingSubscriptions getPendingSubscriptionsUseCase;
  final GetAllSubscriptions getAllSubscriptionsUseCase;
  final ApproveSubscription approveSubscriptionUseCase;
  final RejectSubscription rejectSubscriptionUseCase;
  final DeleteSubscription deleteSubscriptionUseCase;
  final GetAllCoupons getAllCouponsUseCase;
  final CreateCoupon createCouponUseCase;
  final SubscriptionNotificationService subscriptionNotificationService;

  /// Sets the authenticated admin user.
  /// Called after Firebase auth completes for admin flow.
  void setAdminUser(User user) {
    if (user.role != UserRole.admin) {
      emit(
        state.copyWith(
          status: AdminStateStatus.error,
          errorMessage: 'User is not an admin',
        ),
      );
      return;
    }

    emit(
      state.copyWith(status: AdminStateStatus.authenticated, currentUser: user),
    );

    // Load dashboard data
    loadDashboard();
  }

  /// Loads admin dashboard data.
  Future<void> loadDashboard() async {
    emit(state.copyWith(status: AdminStateStatus.loading));

    // Load all data in parallel
    final pendingResult = await getPendingSubscriptionsUseCase(NoParams());
    final allResult = await getAllSubscriptionsUseCase(NoParams());
    final couponsResult = await getAllCouponsUseCase(NoParams());

    // Handle failures
    String? error;
    List<Subscription> pending = [];
    List<Subscription> all = [];
    List<Coupon> coupons = [];

    pendingResult.fold(
      (failure) => error = failure.message,
      (data) => pending = data,
    );

    allResult.fold(
      (failure) => error ??= failure.message,
      (data) => all = data,
    );

    couponsResult.fold(
      (failure) => error ??= failure.message,
      (data) => coupons = data,
    );

    if (error != null) {
      emit(state.copyWith(status: AdminStateStatus.error, errorMessage: error));
    } else {
      emit(
        state.copyWith(
          status: AdminStateStatus.loaded,
          pendingSubscriptions: pending,
          allSubscriptions: all,
          coupons: coupons,
        ),
      );
    }
  }

  /// Approves a subscription and sends notification to owner.
  Future<void> approveSubscription(String subscriptionId) async {
    // Don't show loading state - keep UI stable during update
    final result = await approveSubscriptionUseCase(
      ApproveSubscriptionParams(
        subscriptionId: subscriptionId,
        adminId: state.currentUser?.id ?? 'admin',
      ),
    );

    await result.fold(
      (failure) {
        emit(
          state.copyWith(
            status: AdminStateStatus.error,
            errorMessage: failure.message ?? 'Failed to approve subscription',
          ),
        );
      },
      (subscription) async {
        // Send notification to owner
        await subscriptionNotificationService.notifyOwnerPaymentApproved(
          ownerId: subscription.ownerId,
          planName: subscriptionNotificationService.getPlanName(subscription),
          durationMonths: subscription.durationInMonths,
          validUntil: subscription.endDate,
        );

        // Reload dashboard silently
        await loadDashboard();
      },
    );
  }

  /// Rejects a subscription and sends notification to owner.
  Future<void> rejectSubscription(String subscriptionId, String reason) async {
    // Don't show loading state - keep UI stable during update
    final result = await rejectSubscriptionUseCase(
      RejectSubscriptionParams(
        subscriptionId: subscriptionId,
        adminId: state.currentUser?.id ?? 'admin',
        reason: reason,
      ),
    );

    await result.fold(
      (failure) {
        emit(
          state.copyWith(
            status: AdminStateStatus.error,
            errorMessage: failure.message ?? 'Failed to reject subscription',
          ),
        );
      },
      (rejectedSubscription) async {
        try {
          // Send notification to owner using the subscription returned from the use case
          // The use case already fetches the subscription from the repository
          await subscriptionNotificationService.notifyOwnerPaymentRejected(
            ownerId: rejectedSubscription.ownerId,
            reason: reason,
          );
        } catch (e) {
          // Notification failure is non-critical, log but continue
          // The subscription has already been rejected successfully
        }

        // Reload dashboard silently
        await loadDashboard();
      },
    );
  }

  /// Deletes a subscription permanently (admin only).
  Future<void> deleteSubscription(String subscriptionId) async {
    final result = await deleteSubscriptionUseCase(
      DeleteSubscriptionParams(
        subscriptionId: subscriptionId,
        adminId: state.currentUser?.id ?? 'admin',
      ),
    );

    result.fold(
      (failure) {
        emit(
          state.copyWith(
            status: AdminStateStatus.error,
            errorMessage: failure.message ?? 'Failed to delete subscription',
          ),
        );
      },
      (_) async {
        // Reload dashboard silently
        await loadDashboard();
      },
    );
  }

  /// Creates a new coupon.
  Future<void> addCoupon({
    required String code,
    required double discountPercent,
    String? description,
    int? maxUses,
    DateTime? validUntil,
  }) async {
    emit(state.copyWith(status: AdminStateStatus.loading));

    final coupon = Coupon(
      code: code.toUpperCase(),
      discountPercent: discountPercent,
      isActive: true,
      description: description,
      maxUses: maxUses,
      currentUses: 0,
      validUntil: validUntil,
      createdAt: DateTime.now(),
    );

    final result = await createCouponUseCase(
      CreateCouponParams(coupon: coupon),
    );

    result.fold(
      (failure) {
        emit(
          state.copyWith(
            status: AdminStateStatus.error,
            errorMessage: failure.message ?? 'Failed to create coupon',
          ),
        );
      },
      (_) async {
        // Reload coupons
        await loadDashboard();
      },
    );
  }

  /// Clears admin state (logout).
  void logout() {
    emit(const AdminState());
  }
}
