part of 'admin_analytics_cubit.dart';

/// Status for admin analytics operations.
enum AdminAnalyticsStatus { initial, loading, loaded, error }

/// State for admin analytics dashboard.
class AdminAnalyticsState extends Equatable {
  const AdminAnalyticsState({
    this.status = AdminAnalyticsStatus.initial,
    this.dashboardStats = const AdminDashboardStats.empty(),
    this.librarySummaries = const [],
    this.userActivityStats = const UserActivityStats.empty(),
    this.errorMessage,
    this.librarySearchQuery = '',
    this.expirationDaysFilter,
    this.isSendingNotification = false,
    this.lastNotificationCount,
    this.notificationError,
  });

  final AdminAnalyticsStatus status;
  final AdminDashboardStats dashboardStats;
  final List<LibrarySummary> librarySummaries;
  final UserActivityStats userActivityStats;
  final String? errorMessage;
  final String librarySearchQuery;
  final int? expirationDaysFilter;
  final bool isSendingNotification;
  final int? lastNotificationCount;
  final String? notificationError;

  /// Whether data is currently loading.
  bool get isLoading => status == AdminAnalyticsStatus.loading;

  /// Whether there was an error.
  bool get hasError => status == AdminAnalyticsStatus.error;

  /// Whether data is loaded.
  bool get isLoaded => status == AdminAnalyticsStatus.loaded;

  /// Filtered library summaries based on search query and expiration days filter.
  List<LibrarySummary> get filteredLibraries {
    var filtered = librarySummaries;

    // Apply search filter
    if (librarySearchQuery.isNotEmpty) {
      final query = librarySearchQuery.toLowerCase();
      filtered = filtered.where((library) {
        return library.libraryName.toLowerCase().contains(query) ||
            library.ownerName.toLowerCase().contains(query) ||
            library.ownerPhone.contains(query) ||
            (library.area?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Apply expiration days filter
    if (expirationDaysFilter != null) {
      if (expirationDaysFilter == -1) {
        // Filter for expired subscriptions
        // Only show libraries that have a subscription end date AND it's expired
        filtered = filtered.where((library) {
          return library.subscriptionEndDate != null &&
              library.isSubscriptionExpired;
        }).toList();
      } else {
        // Filter by days remaining
        // Only show libraries that have subscription tracking and days remaining <= threshold
        filtered = filtered.where((library) {
          final daysRemaining = library.daysRemaining;
          if (daysRemaining == null) return false;
          return daysRemaining <= expirationDaysFilter!;
        }).toList();
      }
    }

    return filtered;
  }

  AdminAnalyticsState copyWith({
    AdminAnalyticsStatus? status,
    AdminDashboardStats? dashboardStats,
    List<LibrarySummary>? librarySummaries,
    UserActivityStats? userActivityStats,
    String? errorMessage,
    String? librarySearchQuery,
    int? expirationDaysFilter,
    bool clearExpirationFilter = false,
    bool? isSendingNotification,
    int? lastNotificationCount,
    String? notificationError,
  }) {
    return AdminAnalyticsState(
      status: status ?? this.status,
      dashboardStats: dashboardStats ?? this.dashboardStats,
      librarySummaries: librarySummaries ?? this.librarySummaries,
      userActivityStats: userActivityStats ?? this.userActivityStats,
      errorMessage: errorMessage,
      librarySearchQuery: librarySearchQuery ?? this.librarySearchQuery,
      expirationDaysFilter: clearExpirationFilter
          ? null
          : (expirationDaysFilter ?? this.expirationDaysFilter),
      isSendingNotification:
          isSendingNotification ?? this.isSendingNotification,
      lastNotificationCount: lastNotificationCount,
      notificationError: notificationError,
    );
  }

  @override
  List<Object?> get props => [
    status,
    dashboardStats,
    librarySummaries,
    userActivityStats,
    errorMessage,
    librarySearchQuery,
    expirationDaysFilter,
    isSendingNotification,
    lastNotificationCount,
    notificationError,
  ];
}
