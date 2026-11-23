import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../data/services/subscription_notification_service.dart';
import '../../presentation/owner/cubit/subscription_cubit.dart';
import '../di/injection_container.dart';

/// An App Store subscription product sold in the app.
class AppStorePlan {
  const AppStorePlan({
    required this.title,
    required this.months,
    required this.price,
    required this.badge,
    required this.productId,
  });

  final String title;
  final int months;
  final int price;
  final String badge;
  final String productId;

  static const List<AppStorePlan> all = [
    AppStorePlan(
      title: 'Monthly',
      months: 1,
      price: 499,
      badge: 'Flexible',
      productId: 'pg_sathi_pro_monthly',
    ),
    AppStorePlan(
      title: '3 Months',
      months: 3,
      price: 1499,
      badge: 'Quarterly',
      productId: 'pg_sathi_pro_3month',
    ),
    AppStorePlan(
      title: '6 Months',
      months: 6,
      price: 2999,
      badge: 'Half Yearly',
      productId: 'pg_sathi_pro_6month',
    ),
    AppStorePlan(
      title: '1 Year',
      months: 12,
      price: 4999,
      badge: 'Best Value',
      productId: 'pg_sathi_pro_yearly',
    ),
  ];

  static AppStorePlan? byProductId(String id) {
    for (final p in all) {
      if (p.productId == id) return p;
    }
    return null;
  }
}

enum AppStorePurchaseEventType { pending, recorded, failed, cancelled }

/// Progress of an App Store purchase, for the subscription screen's UI.
class AppStorePurchaseEvent {
  const AppStorePurchaseEvent(this.type, {this.plan, this.message});

  final AppStorePurchaseEventType type;
  final AppStorePlan? plan;
  final String? message;
}

/// App-wide listener for App Store purchases.
///
/// Started at launch so a purchase is recorded even if the owner left the
/// subscription screen or the app was killed mid-purchase: StoreKit
/// redelivers every unfinished transaction on the next launch.
///
/// A transaction is only finished with Apple *after* the subscription has
/// been saved to Firestore, so a failed save is retried instead of lost.
class AppStorePurchaseService {
  AppStorePurchaseService({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required SubscriptionNotificationService notificationService,
  }) : _firestore = firestore,
       _auth = auth,
       _notificationService = notificationService;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final SubscriptionNotificationService _notificationService;

  final InAppPurchase _iap = InAppPurchase.instance;
  final _events = StreamController<AppStorePurchaseEvent>.broadcast();
  final Set<String> _inFlight = {};
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  Stream<AppStorePurchaseEvent> get events => _events.stream;

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Starts listening. Safe to call more than once.
  void start() {
    if (!isSupported || _subscription != null) return;
    _subscription = _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) => log('[IAP] purchase stream error: $e'),
    );
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      final plan = AppStorePlan.byProductId(p.productID);
      if (plan == null) continue;

      switch (p.status) {
        case PurchaseStatus.pending:
          _events.add(AppStorePurchaseEvent(
            AppStorePurchaseEventType.pending,
            plan: plan,
          ));
        case PurchaseStatus.canceled:
          _events.add(AppStorePurchaseEvent(
            AppStorePurchaseEventType.cancelled,
            plan: plan,
          ));
          await _finish(p);
        case PurchaseStatus.error:
          _events.add(AppStorePurchaseEvent(
            AppStorePurchaseEventType.failed,
            plan: plan,
            message: p.error?.message ?? 'App Store purchase failed.',
          ));
          await _finish(p);
        case PurchaseStatus.restored:
          // A restore re-delivers an already-paid transaction (often under a
          // new id); it is not new revenue, so never create a subscription.
          await _finish(p);
        case PurchaseStatus.purchased:
          await _record(p, plan);
      }
    }
  }

  Future<void> _record(PurchaseDetails p, AppStorePlan plan) async {
    final transactionId = p.purchaseID;
    if (transactionId == null || transactionId.isEmpty) {
      log('[IAP] ${p.productID} has no transaction id — leaving unfinished');
      return;
    }
    if (!_inFlight.add(transactionId)) return;

    try {
      if (await _alreadyRecorded(transactionId)) {
        await _finish(p);
        _events.add(AppStorePurchaseEvent(
          AppStorePurchaseEventType.recorded,
          plan: plan,
        ));
        return;
      }

      final owner = await _resolveOwner();
      if (owner == null) {
        // Not signed in yet — leave unfinished so StoreKit redelivers it.
        log('[IAP] No signed-in owner for $transactionId — will retry');
        return;
      }

      final error = await _createAndActivate(owner, plan, transactionId);
      if (error != null) {
        // Leave the transaction unfinished so it is retried next launch.
        _events.add(AppStorePurchaseEvent(
          AppStorePurchaseEventType.failed,
          plan: plan,
          message: '$error We will retry automatically.',
        ));
        return;
      }

      await _finish(p);
      _events.add(AppStorePurchaseEvent(
        AppStorePurchaseEventType.recorded,
        plan: plan,
      ));
    } catch (e) {
      log('[IAP] Recording $transactionId failed: $e');
      _events.add(AppStorePurchaseEvent(
        AppStorePurchaseEventType.failed,
        plan: plan,
        message:
            'Purchase received, but activation failed. We will retry automatically.',
      ));
    } finally {
      _inFlight.remove(transactionId);
    }
  }

  /// Returns an error message, or null when the subscription is active.
  Future<String?> _createAndActivate(
    _Owner owner,
    AppStorePlan plan,
    String transactionId,
  ) async {
    final cubit = sl<SubscriptionCubit>();
    try {
      await cubit.initiatePayment(
        ownerId: owner.ownerId,
        libraryId: owner.libraryId,
        seatCount: 1, // ignored: seatLimitOverride makes App Store plans unlimited
        durationInMonths: plan.months,
        planIdOverride: plan.productId,
        baseMonthlyPriceOverride: plan.price / plan.months,
        finalAmountOverride: plan.price.toDouble(),
        discountPercentOverride: 0,
        seatLimitOverride: 999999,
      );
      final created = cubit.state.createdSubscription;
      if (created == null) {
        return cubit.state.errorMessage ?? 'Subscription could not be created.';
      }

      await cubit.approveInAppPurchasePayment(
        subscriptionId: created.id,
        transactionId: transactionId,
        amount: plan.price.toDouble(),
        durationMonths: plan.months,
      );
      if (!cubit.state.isSuccess) {
        return cubit.state.errorMessage ?? 'Subscription activation failed.';
      }

      await _notificationService.notifyAdminAppStorePayment(
        ownerName: owner.ownerName,
        libraryName: owner.libraryName,
        amount: plan.price.toDouble(),
        durationMonths: plan.months,
        transactionId: transactionId,
      );
      return null;
    } finally {
      await cubit.close();
    }
  }

  Future<bool> _alreadyRecorded(String transactionId) async {
    final snap = await _firestore
        .collection('subscriptions')
        .where('transactionId', isEqualTo: transactionId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<_Owner?> _resolveOwner() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final libs = await _firestore
        .collection('libraries')
        .where('ownerId', isEqualTo: uid)
        .limit(1)
        .get();
    if (libs.docs.isEmpty) return null;
    final lib = libs.docs.first;

    String ownerName = 'Owner';
    try {
      final user = await _firestore.collection('users').doc(uid).get();
      ownerName = (user.data()?['name'] as String?) ?? ownerName;
    } catch (_) {/* non-critical */}

    return _Owner(
      ownerId: uid,
      libraryId: lib.id,
      ownerName: ownerName,
      libraryName: (lib.data()['name'] as String?) ?? 'PG',
    );
  }

  Future<void> _finish(PurchaseDetails p) async {
    if (p.pendingCompletePurchase) {
      await _iap.completePurchase(p);
    }
  }
}

class _Owner {
  const _Owner({
    required this.ownerId,
    required this.libraryId,
    required this.ownerName,
    required this.libraryName,
  });

  final String ownerId;
  final String libraryId;
  final String ownerName;
  final String libraryName;
}
