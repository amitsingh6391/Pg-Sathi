part of 'expiring_subscriptions_cubit.dart';

/// State for expiring subscriptions and trials.
class ExpiringSubscriptionsState extends Equatable {
  const ExpiringSubscriptionsState({
    this.isLoading = false,
    this.expiringSubscriptions = const [],
    this.expiringTrials = const [],
    this.activeTrials = const [],
    this.expiredTrials = const [],
    this.libraryCache = const {},
    this.ownerCache = const {},
    this.error,
  });

  final bool isLoading;
  final List<Subscription> expiringSubscriptions;
  final List<ExpiringTrialInfo> expiringTrials;
  final List<ExpiringTrialInfo> activeTrials;
  final List<ExpiringTrialInfo> expiredTrials;
  final Map<String, Library> libraryCache;
  final Map<String, User> ownerCache;
  final String? error;

  bool get hasData =>
      expiringSubscriptions.isNotEmpty ||
      expiringTrials.isNotEmpty ||
      activeTrials.isNotEmpty ||
      expiredTrials.isNotEmpty;

  ExpiringSubscriptionsState copyWith({
    bool? isLoading,
    List<Subscription>? expiringSubscriptions,
    List<ExpiringTrialInfo>? expiringTrials,
    List<ExpiringTrialInfo>? activeTrials,
    List<ExpiringTrialInfo>? expiredTrials,
    Map<String, Library>? libraryCache,
    Map<String, User>? ownerCache,
    String? error,
  }) {
    return ExpiringSubscriptionsState(
      isLoading: isLoading ?? this.isLoading,
      expiringSubscriptions:
          expiringSubscriptions ?? this.expiringSubscriptions,
      expiringTrials: expiringTrials ?? this.expiringTrials,
      activeTrials: activeTrials ?? this.activeTrials,
      expiredTrials: expiredTrials ?? this.expiredTrials,
      libraryCache: libraryCache ?? this.libraryCache,
      ownerCache: ownerCache ?? this.ownerCache,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        expiringSubscriptions,
        expiringTrials,
        activeTrials,
        expiredTrials,
        libraryCache,
        ownerCache,
        error,
      ];
}
