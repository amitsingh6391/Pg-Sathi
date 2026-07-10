import 'package:equatable/equatable.dart';

/// Entity representing an analytics event summary.
class AnalyticsSummary extends Equatable {
  final String eventName;
  final String? userId;
  final String? role;
  final String? libraryId;
  final String? platform;
  final Map<String, dynamic> parameters;
  final DateTime timestamp;

  const AnalyticsSummary({
    required this.eventName,
    this.userId,
    this.role,
    this.libraryId,
    this.platform,
    this.parameters = const {},
    required this.timestamp,
  });

  @override
  List<Object?> get props => [
        eventName,
        userId,
        role,
        libraryId,
        platform,
        parameters,
        timestamp,
      ];
}
