import 'package:equatable/equatable.dart';

/// Platform-wide statistics for admin dashboard.
/// Aggregated data showing overall platform health and growth.
class AdminDashboardStats extends Equatable {
  const AdminDashboardStats({
    required this.totalLibraries,
    required this.librariesToday,
    required this.librariesLast7Days,
    required this.librariesLast30Days,
    required this.totalActiveStudents,
    required this.totalActiveOwners,
    required this.generatedAt,
  });

  /// Empty stats constructor.
  const AdminDashboardStats.empty()
    : totalLibraries = 0,
      librariesToday = 0,
      librariesLast7Days = 0,
      librariesLast30Days = 0,
      totalActiveStudents = 0,
      totalActiveOwners = 0,
      generatedAt = null;

  /// Total number of libraries on the platform.
  final int totalLibraries;

  /// Libraries onboarded today.
  final int librariesToday;

  /// Libraries onboarded in last 7 days.
  final int librariesLast7Days;

  /// Libraries onboarded in last 30 days.
  final int librariesLast30Days;

  /// Total active students with memberships.
  final int totalActiveStudents;

  /// Total active library owners.
  final int totalActiveOwners;

  /// When these stats were generated.
  final DateTime? generatedAt;

  /// Growth percentage for libraries (last 30 days vs previous 30 days).
  double get libraryGrowthPercent {
    if (totalLibraries == 0) return 0.0;
    final previousCount = totalLibraries - librariesLast30Days;
    if (previousCount == 0) return 100.0;
    return ((librariesLast30Days / previousCount) * 100).clamp(0, 999);
  }

  @override
  List<Object?> get props => [
    totalLibraries,
    librariesToday,
    librariesLast7Days,
    librariesLast30Days,
    totalActiveStudents,
    totalActiveOwners,
    generatedAt,
  ];

  AdminDashboardStats copyWith({
    int? totalLibraries,
    int? librariesToday,
    int? librariesLast7Days,
    int? librariesLast30Days,
    int? totalActiveStudents,
    int? totalActiveOwners,
    DateTime? generatedAt,
  }) {
    return AdminDashboardStats(
      totalLibraries: totalLibraries ?? this.totalLibraries,
      librariesToday: librariesToday ?? this.librariesToday,
      librariesLast7Days: librariesLast7Days ?? this.librariesLast7Days,
      librariesLast30Days: librariesLast30Days ?? this.librariesLast30Days,
      totalActiveStudents: totalActiveStudents ?? this.totalActiveStudents,
      totalActiveOwners: totalActiveOwners ?? this.totalActiveOwners,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }
}
