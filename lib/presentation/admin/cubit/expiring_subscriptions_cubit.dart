import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/library.dart';
import '../../../domain/entities/subscription.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/usecases/get_expiring_trials.dart';

part 'expiring_subscriptions_state.dart';

class ExpiringSubscriptionsCubit extends Cubit<ExpiringSubscriptionsState> {
  ExpiringSubscriptionsCubit({
    required GetExpiringTrials getExpiringTrials,
  })  : _getExpiringTrials = getExpiringTrials,
        super(const ExpiringSubscriptionsState());

  final GetExpiringTrials _getExpiringTrials;

  Future<void> loadExpiringData(List<Subscription> allSubscriptions) async {
    if (state.isLoading) return;

    emit(state.copyWith(isLoading: true, error: null));

    final expiringSubscriptions = _filterExpiring(allSubscriptions, 7);

    final result = await _getExpiringTrials(
      GetExpiringTrialsParams(allSubscriptions: expiringSubscriptions),
    );

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (data) => emit(
        state.copyWith(
          isLoading: false,
          expiringSubscriptions: expiringSubscriptions,
          expiringTrials: data.expiringTrials,
          activeTrials: data.activeTrials,
          expiredTrials: data.expiredTrials,
          libraryCache: data.libraryCache,
          ownerCache: data.ownerCache,
        ),
      ),
    );
  }

  Future<void> refresh(List<Subscription> allSubscriptions) async {
    emit(const ExpiringSubscriptionsState());
    await loadExpiringData(allSubscriptions);
  }

  String? getOwnerName(String libraryId) {
    final library = state.libraryCache[libraryId];
    if (library == null) return null;
    return state.ownerCache[library.ownerId]?.displayName;
  }

  String? getOwnerPhone(String libraryId) {
    final library = state.libraryCache[libraryId];
    if (library == null) return null;
    return state.ownerCache[library.ownerId]?.phone;
  }

  List<Subscription> _filterExpiring(
    List<Subscription> subscriptions,
    int daysThreshold,
  ) {
    final now = DateTime.now();
    return subscriptions.where((sub) {
      if (sub.status != SubscriptionStatus.active) return false;
      final days = sub.daysRemaining(now);
      return days > 0 && days <= daysThreshold;
    }).toList();
  }
}
